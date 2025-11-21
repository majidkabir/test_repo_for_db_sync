SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855ExtUpd04                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 14-02-2019 1.0  Ung        WMS-8467 Created                          */
/* 02-05-2019 1.1  Shong      Bug Fixing                                */
/* 07-05-2019 1.2  Ung        WMS-8467 Add Lose UCC                     */
/* 29-03-2019 1.3  James      WMS-8002 Add TaskDetailKey param (james01)*/
/* 22-07-2019 1.4  LZG        INC0778485 - Check Pack against Pick      */
/*                                       - Reset @nPack_QTY (ZG01)      */
/* 06-07-2021 1.5  YeeKung     WMS-17278 Add Reasonkey (yeekung01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_855ExtUpd04] (
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLoadKey     NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20),  
   @nQty         INT,  
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT, 
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	   INT
   DECLARE @cLastCarton    NVARCHAR( 1)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nCartonNo      INT
   DECLARE @nPPA_QTY       INT
   DECLARE @nPick_QTY      INT
   DECLARE @nPack_QTY      INT
   DECLARE @cPickConfirmStatus       NVARCHAR( 1)
   DECLARE @cSkipChkPSlipMustScanOut NVARCHAR( 1)
   DECLARE @cPrintShipLabel          NVARCHAR( 1)
   DECLARE @cPrintCartonManifest     NVARCHAR( 1)
   DECLARE @cPrintPackList           NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 855 -- PPA (carton ID)
   BEGIN
      IF @nStep = 1 -- DropID 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            /*-------------------------------------------------------------------------------
                                       PickDetail (full carton only)
            -------------------------------------------------------------------------------*/
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_855ExtUpd04 -- For rollback or commit only our own transaction

            DECLARE @cPickDetailKey NVARCHAR( 10)
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
                  AND QTY > 0
                  AND Status <> '4' -- Not short
                  AND UOM = '2'     -- Full carton
                  AND Status = '3'  -- Replen From Completed
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PickDetail SET
                  Status = '5', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134359
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END

            -- Lose UCC
            IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cDropID AND Status < '5')
            BEGIN
               UPDATE UCC SET
                  Status = '5', -- Picked
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE StorerKey = @cStorerKey 
                  AND UCCNo = @cDropID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134360
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
                  GOTO RollBackTran
               END
            END
            
            COMMIT TRAN rdt_855ExtUpd04
         END
      END

      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Storer configure
            SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
            IF @cPickConfirmStatus = '0'
               SET @cPickConfirmStatus = '5'
            SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)
            IF @cSkipChkPSlipMustScanOut = '0'
               SET @cPickConfirmStatus = '5'

            -- Get session info
            SELECT 
               @cFacility = Facility, 
               @cLabelPrinter = Printer,
               @cPaperPrinter = Printer_Paper
             FROM RDT.RDTMobRec WITH (NOLOCK) 
             WHERE Mobile = @nMobile

            -- Get PPA QTY
            SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE DropID = @cDropID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU

            -- Get PickDetail QTY
            SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE DropID = @cDropID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND [Status] <> '4'
               AND [Status] >= @cPickConfirmStatus

            -- Check exceed tolerance
            IF @nPPA_QTY > @nPick_QTY
               GOTO Quit

            -- Get Orders info
            SET @cLoadKey = ''
            SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE DropID = @cDropID AND StorerKey = @cStorerKey
            SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            -- Get PickHeader info
            SET @cPickSlipNo = ''
            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
            IF @cPickSlipNo = '' AND @cLoadKey <> ''
               SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey

            -- Check pick slip
            IF @cPickSlipNo = ''
            BEGIN
               SET @nErrNo = 134351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No
               GOTO Quit
            END

            -- Get PackDetail QTY  
            SET @nPack_QTY = 0
            SELECT @nPack_QTY = ISNULL( SUM( QTY), 0)    -- ZG01
            FROM dbo.PackDetail WITH (NOLOCK)   
            WHERE PickSlipNo = @cPickSlipNo  
               AND LabelNo = @cDropID  
               AND SKU = @cSKU  
               AND StorerKey = @cStorerKey  
           
            IF ((@nPack_QTY + @nQTY) > @nPick_QTY)                   -- ZG01
            BEGIN  
               SET @nErrNo = 134360  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Overpacked
               GOTO Quit  
            END  

            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_855ExtUpd04 -- For rollback or commit only our own transaction

            -- PackHeader
            IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
            BEGIN
               -- Insert PackHeader
               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey) 
               VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134352
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
                  GOTO RollBackTran
               END
            END

            -- PickingInfo
            IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
            BEGIN
               -- Insert PackHeader
               INSERT INTO dbo.PickingInfo 
                  (PickSlipNo, ScanInDate, PickerID) 
               VALUES 
                  (@cPickSlipNo, GETDATE(), SUSER_SNAME())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPickInfFail
                  GOTO RollBackTran
               END
            END

            /*-------------------------------------------------------------------------------
                                              PackDetail
            -------------------------------------------------------------------------------*/
            -- Check PackDetail exist
            SET @nCartonNo = 0
            SELECT TOP 1 
               @nCartonNo = CartonNo
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND LabelNo = @cDropID
            
            IF @nCartonNo = 0
            BEGIN
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cDropID, '00001', @cStorerKey, @cSKU, @nQTY, @cDropID,
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134354
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END

               -- If insert cartonno = 0, system will auto assign max cartonno
               SELECT TOP 1 
                  @nCartonNo = CartonNo
               FROM PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND AddWho = 'rdt.' + SUSER_SNAME()
               ORDER BY CartonNo DESC -- max cartonno
            END
            ELSE
            BEGIN
               -- Same carton, different SKU
               SET @cLabelLine = '' 
               SELECT TOP 1 
                  @cLabelLine = LabelLine
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cDropID
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- New SKU
               IF @cLabelLine = '' 
               BEGIN
                  -- Get next Label No
                  SELECT @cLabelLine = 
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                        
                  -- Insert PackDetail
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID,
                     'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 134355
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     QTY = QTY + @nQTY,
                     EditWho = 'rdt.' + SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cDropID
                     AND LabelLine = @cLabelLine
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 134356
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                     GOTO RollBackTran
                  END
               END   -- DropID exists and SKU exists (update qty only)
            END

            -- PackInfo
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
            BEGIN
               -- Insert PackInfo
               INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)
               VALUES (@cPickSlipNo, @nCartonNo, 0, 0, '')
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 134357
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfFail
                  GOTO RollBackTran
               END
            END

            -- Get Total PickDetail Qty Added by (SHONG) on 12/05/2019 (Start)
            SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE DropID = @cDropID
               AND PickSlipNo = @cPickSlipNo
               AND [Status] <> '4'
               AND [Status] >= @cPickConfirmStatus            
            -- (End)
                      
            -- Get Packdetail QTY
            SET @nPack_QTY = 0      -- ZG01     
            SELECT @nPack_QTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
               AND LabelNo = @cDropID

            -- Carton pick and pack tally, print ship label and carton manifest
            IF @nPick_QTY = @nPack_QTY
            BEGIN
               SET @cPrintShipLabel = 'Y'
               SET @cPrintCartonManifest = 'Y'
            END

            -- Check last carton
            /*
            Last carton logic:
            1. If PickDetail is outstanding (PickDetail.Status = 0 or 4), definitely not last carton
            2. If pick QTY tally pack QTY, all cartons packed, it is last carton
            */
            SET @cLastCarton = 'Y' 

            -- 1. Check outstanding PickDetail
            -- Discrete 
            IF @cOrderKey <> ''
            BEGIN
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                     AND Status IN ('0', '4'))
                  SET @cLastCarton = 'N'
            END 
            
            -- Conso
            ELSE IF @cLoadKey <> ''
            BEGIN
               IF EXISTS( SELECT TOP 1 1 
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE O.LoadKey = @cLoadKey
                      AND PD.Status IN ('0', '4'))
                  SET @cLastCarton = 'N'
            END 

            -- 2. If pick QTY tally pack QTY, all cartons packed, it is last carton
            IF @cLastCarton = 'Y' 
            BEGIN
               -- Get Pickdetail QTY
               -- Discreate
               IF @cOrderKey <> '' 
                  SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)
                  FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                     AND Status NOT IN ('0', '4')

               -- Conso
               ELSE IF @cLoadKey <> ''
                  SELECT @nPick_QTY = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE O.LoadKey = @cLoadKey
                      AND PD.Status NOT IN ('0', '4')

               -- Get Packdetail QTY
               SET @nPack_QTY = 0      -- ZG01     
               SELECT @nPack_QTY = ISNULL( SUM( QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
               
               -- Pickslip pick and pack tally, print pack list
               IF @nPick_QTY <> @nPack_QTY
                  SET @cLastCarton = 'N'
            END  

            -- Last carton
            IF @cLastCarton = 'Y'
            BEGIN
               -- Pack confirm
               IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] < '9')  
               BEGIN  
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
                     [Status] = '9', 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME()
                  WHERE PickSlipNo = @cPickSlipNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 134358
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
                     GOTO RollBackTran
                  END
               END
               
               -- Print pack list
               SET @cPrintPackList = 'Y'
            END

            COMMIT TRAN rdt_855ExtUpd04
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            -- Print ship label
            IF @cPrintShipLabel = 'Y'
            BEGIN
               DECLARE @cShipLabel NVARCHAR( 10)
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
               IF @cShipLabel = '0'
                  SET @cShipLabel = ''

               -- Ship label
               IF @cShipLabel <> '' 
               BEGIN
                  -- Common params
                  DECLARE @tShipLabel AS VariableTable
                  INSERT INTO @tShipLabel (Variable, Value) VALUES 
                     ( '@cStorerKey',     @cStorerKey), 
                     ( '@cPickSlipNo',    @cPickSlipNo), 
                     ( '@cLabelNo',       @cDropID), 
                     ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cShipLabel, -- Report type
                     @tShipLabel, -- Report params
                     'rdt_855ExtUpd04', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 0 -- To let parent commit
                     GOTO Quit
                  END
               END
            END
            
            -- Print carton manifest
            IF @cPrintCartonManifest = 'Y'
            BEGIN
               DECLARE @cCartonManifest NVARCHAR( 10)
               SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
               IF @cCartonManifest = '0'
                  SET @cCartonManifest = ''

               -- Carton manifest
               IF @cCartonManifest <> ''
               BEGIN
                  -- Common params
                  DECLARE @tCartonManifest AS VariableTable
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES 
                     ( '@cStorerKey',     @cStorerKey), 
                     ( '@cPickSlipNo',    @cPickSlipNo), 
                     ( '@cLabelNo',       @cDropID), 
                     ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cCartonManifest, -- Report type
                     @tCartonManifest, -- Report params
                     'rdt_855ExtUpd04', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 0 -- To let parent commit
                     GOTO Quit
                  END
               END
            END

            -- Print pack list
            IF @cPrintPackList = 'Y'
            BEGIN
               DECLARE @cPackList NVARCHAR( 10)
               SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PACKLIST', @cStorerKey)
               IF @cPackList = '0'
                  SET @cPackList = ''
               
               IF @cPackList <> ''
               BEGIN
                  -- Common params
                  DECLARE @tPackList AS VariableTable
                  INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cPackList, -- Report type
                     @tPackList, -- Report params
                     'rdt_855ExtUpd04', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 0 -- To let parent commit
                     GOTO Quit
                  END
               END
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_855ExtUpd04
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO