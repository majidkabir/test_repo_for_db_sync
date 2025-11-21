SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855ExtUpd05                                     */
/*                                                                      */
/* Purpose: Generate packing (update packdetail.upc)                    */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-06-17  1.0  James       WMS13216. Created                       */
/* 2020-09-14  1.1  James       Adhoc fix. Remove pack confirm (james01)*/
/* 2021-07-03  1.2  YeeKung     WMS-17278 Add Reasonkey (yeekung01)     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_855ExtUpd05] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),  
   @cRefNo           NVARCHAR( 10), 
   @cPickSlipNo      NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20),  
   @nQty             INT,  
   @cOption          NVARCHAR( 1),  
   @nErrNo           INT OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT,
   @cID              NVARCHAR( 18),
   @cTaskDetailKey   NVARCHAR( 10),
   @cReasonCode  NVARCHAR(20) OUTPUT       
       
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	      INT,
           @cLastCarton       NVARCHAR( 1),
           @cCartonNo         NVARCHAR( 10),
           @cWeight           NVARCHAR( 10),
           @cCube             NVARCHAR( 10),
           @cCartonType       NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cPaperPrinter     NVARCHAR( 10),
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cPickDetailKey    NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cLabelNo          NVARCHAR( 20),
           @cLabelLine        NVARCHAR( 5),
           @nCartonNo         INT,
           @nPPA_QTY          INT,
           @nPD_QTY           INT,
           @nPAD_QTY          INT,
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @cUPC              NVARCHAR( 30),
           @cShipLabel        NVARCHAR( 10),
           @cDelNotes         NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @nUPCCnt           INT,
           @nRowCount         INT,
           @cPackDtlUPC       NVARCHAR( 30),
           @cPackDtlLabelLine NVARCHAR( 5)


   DECLARE @fWeight        FLOAT
   DECLARE @fCube          FLOAT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_855ExtUpd05 -- For rollback or commit only our own transaction

   IF @nFunc = 855
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cUserName = UserName,
                   @cLabelPrinter = Printer,
                   @cPaperPrinter = Printer_Paper,
                   @cFacility = Facility
             FROM RDT.RDTMobRec WITH (NOLOCK) 
             WHERE Mobile = @nMobile

            /*-------------------------------------------------------------------------------

                                           Orders, PickDetail

            -------------------------------------------------------------------------------*/
            SELECT @cUPC = UPC
            FROM dbo.UPC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cSKU
            SET @nUPCCnt = @@ROWCOUNT

            IF @nUPCCnt > 1
               SELECT @cUPC = I_Field01
               FROM RDT.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile

    -- Get Orders info
            SELECT TOP 1 @cOrderKey = OrderKey, 
                         @cPickDetailKey = PickDetailKey,
                         @cPickSlipNo = PickSlipNo 
            FROM dbo.PickDetail PickD WITH (NOLOCK) 
            WHERE PickD.StorerKey = @cStorerKey
            AND   PickD.[Status] < '9'
            AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PackD WITH (NOLOCK) 
                           WHERE PackD.DropID = @cDropID 
                           AND   PickD.Storerkey = PackD.StorerKey 
                           AND   PickD.CaseID = PackD.LabelNo
                           AND   PickD.Sku = PackD.SKU)
            ORDER BY 1

            SELECT @cLoadKey = LoadKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            IF ISNULL( @cPickSlipNo, '') = ''
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
               IF ISNULL( @cPickSlipNo, '') = ''
                  SELECT @cPickSlipNo = PickHeaderKey
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE ExternOrderKey = @cLoadKey

               IF ISNULL( @cPickSlipNo, '') = ''
                  SELECT TOP 1 @cPickSlipNo = RKL.PickSlipNo
                  FROM dbo.PickDetail PickD WITH (NOLOCK)
                  JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON ( PickD.PickDetailKey = RKL.PickDetailKey)
                  WHERE PickD.StorerKey = @cStorerKey
                  AND   PickD.[Status] < '9'
                  AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PackD WITH (NOLOCK) 
                                 WHERE PackD.DropID = @cDropID 
                                 AND   PickD.Storerkey = PackD.StorerKey 
                                 AND   PickD.CaseID = PackD.LabelNo
                                 AND   PickD.Sku = PackD.SKU)
                  ORDER BY 1
                  
               IF ISNULL( @cPickSlipNo, '') = ''
                  SELECT TOP 1 @cPickSlipNo = PickD.PickSlipNo
                  FROM dbo.PICKDETAIL PickD WITH (NOLOCK)
                  WHERE PickD.Storerkey = @cStorerKey
                  AND   PickD.[Status] < '9'
                  AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PackD WITH (NOLOCK) 
                                 WHERE PackD.DropID = @cDropID 
                                 AND   PickD.Storerkey = PackD.StorerKey 
                                 AND   PickD.CaseID = PackD.LabelNo
                                 AND   PickD.Sku = PackD.SKU)
                  ORDER BY 1

               IF ISNULL( @cPickSlipNo, '') = ''
               BEGIN
                  SET @nErrNo = 106751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No
                  GOTO RollBackTran
               END
            END

            -- Get PickHeader info
            SELECT
               @cOrderKey = OrderKey, 
               @cLoadKey = ExternOrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Check PackHeader exist
            IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
            BEGIN
               -- Insert PackHeader
               INSERT INTO dbo.PackHeader 
                  (PickSlipNo, StorerKey, LoadKey, OrderKey) 
               VALUES
                  (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106752
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
                  GOTO RollBackTran
               END
            END

            -- Check PickingInfo exist
            IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
            BEGIN
               -- Insert PackHeader
               INSERT INTO dbo.PickingInfo 
                  (PickSlipNo, ScanInDate, PickerID) 
               VALUES 
                  (@cPickSlipNo, GETDATE(), @cUserName)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
                  GOTO RollBackTran
               END
            END

            /*-------------------------------------------------------------------------------

                                              PackDetail

            -------------------------------------------------------------------------------*/
            SET @cPackDtlUPC = ''
            SELECT @cPackDtlUPC = UPC 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
            AND   DropID = @cDropID
            AND   SKU = @cSKU
            SET @nRowCount = @@ROWCOUNT

            -- Sku not exists
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 106754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Sku Not Exists
               GOTO RollBackTran
            END

            -- Check if it is new UPC or need update this UPC to existing line
            -- Update to existing packdetail
            IF ISNULL( @cPackDtlUPC, '') = ''
            BEGIN
               UPDATE dbo.PackDetail SET 
                  UPC = @cUPC,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID
               AND   SKU = @cSKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106755
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               -- New UPC, insert new line
               IF NOT EXISTS ( SELECT 1 
                               FROM dbo.PackDetail WITH (NOLOCK) 
                               WHERE PickSlipNo = @cPickSlipNo 
                               AND   DropID = @cDropID
                               AND   SKU = @cSKU
                               AND   UPC = @cUPC)
               BEGIN
                  SET @nCartonNo = 0

                  SELECT TOP 1 @nCartonNo = CartonNo,
                               @cLabelNo = LabelNo,
                               @cPackDtlLabelLine = LabelLine
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                  AND   DropID = @cDropID
                  AND   SKU = @cSKU

                  -- Get next Label No
                  SELECT @cLabelLine = 
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo

                  -- Insert PackDetail
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, UPC, AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, @cDropID, @cUPC, 
                     'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 106756
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                     GOTO RollBackTran
                  END
           
                  -- Deduct qty from original line
                  UPDATE dbo.PackDetail SET 
                     Qty = Qty - @nQty,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo
                  AND   LabelNo = @cLabelNo
                  AND   LabelLine = @cPackDtlLabelLine

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 106757
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                     GOTO RollBackTran
                  END
               END
               ELSE  -- Existing UPC
               BEGIN
                  DECLARE @nOri_CartonNo  INT
                  DECLARE @cOri_LabelNo   NVARCHAR( 20)
                  DECLARE @cOri_LabelLine NVARCHAR( 5)
                  DECLARE @nNew_CartonNo  INT
                  DECLARE @cNew_LabelNo   NVARCHAR( 20)
                  DECLARE @cNew_LabelLine NVARCHAR( 5)
                  
                  SELECT @nRowCount = COUNT( DISTINCT UPC)
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo 
                  AND   DropID = @cDropID
                  AND   SKU = @cSKU
                  
                  -- If rowcount = 1 then no need update anything
                  IF @nRowCount > 1
                  BEGIN
                     SELECT @nNew_CartonNo = CartonNo,
                            @cNew_LabelNo = LabelNo,
                            @cNew_LabelLine = LabelLine
                     FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo 
                     AND   DropID = @cDropID
                     AND   SKU = @cSKU
                     AND   UPC = @cUPC

                     -- Add qty to new upc line
                     UPDATE dbo.PackDetail SET 
                        Qty = Qty + @nQty,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nNew_CartonNo
                     AND   LabelNo = @cNew_LabelNo
                     AND   LabelLine = @cNew_LabelLine

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 106758
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                        GOTO RollBackTran
                     END
                  
                     SELECT TOP 1 
                            @nOri_CartonNo = CartonNo,
                            @cOri_LabelNo = LabelNo,
                            @cOri_LabelLine = LabelLine
                     FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo 
                     AND   DropID = @cDropID
                     AND   SKU = @cSKU
                     ORDER BY LabelLine
                  
                     -- Deduct qty from original line
                     UPDATE dbo.PackDetail SET 
                        Qty = Qty - @nQty,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nOri_CartonNo
                     AND   LabelNo = @cOri_LabelNo
                     AND   LabelLine = @cOri_LabelLine

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 106759
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                        GOTO RollBackTran
                     END
                  END
               END
            END

            -- Get Pickdetail QTY
            SELECT @nPD_QTY = ISNULL( SUM( PickD.QTY), 0)
            FROM dbo.PickDetail PickD WITH (NOLOCK) 
            WHERE PickD.StorerKey = @cStorerKey
            AND   PickD.[Status] < '9'
            AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PackD WITH (NOLOCK) 
                           WHERE PackD.DropID = @cDropID 
                           AND   PickD.Storerkey = PackD.StorerKey 
                           AND   PickD.CaseID = PackD.LabelNo
                           AND   PickD.Sku = PackD.SKU)

            -- Get Packdetail QTY
            SELECT @nPAD_QTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
            AND   DropID = @cDropID

            IF @nPAD_QTY <> @nPD_QTY
            BEGIN
               SET @nErrNo = 106760
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPack Err'
               GOTO RollBackTran
            END

            -- Get PPA QTY
            SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   DropID = @cDropID

            -- Insert DropID
            IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
            BEGIN
               -- Insert DropID
               INSERT INTO dbo.DropID 
                  (DropID, LabelPrinted, ManifestPrinted, Status) 
               VALUES 
                  (@cDropID, '0', '0', '9')

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106761
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
                  GOTO RollBackTran
               END
            END

            IF @nPPA_QTY = @nPD_QTY
            BEGIN
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
               IF @cShipLabel = '0'
                  SET @cShipLabel = ''

               IF @cShipLabel <> ''
               BEGIN
                  SELECT TOP 1 
                     @nCartonNo = CartonNo, 
                     @cLabelNo = LabelNo
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   DropID = @cDropID
                  ORDER BY 1
                     
                  DECLARE @tSHIPPLABEL AS VariableTable
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',      @cStorerKey)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',       @nCartonNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLabelNo',        @cLabelNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                     @cShipLabel, -- Report type
                     @tSHIPPLABEL, -- Report params
                     'rdt_855ExtUpd05', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO RollBackTran

                  -- Update DropID
                  UPDATE dbo.DropID WITH (ROWLOCK) SET
                     LabelPrinted = '1'
                  WHERE DropID = @cDropID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 106762
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
                     GOTO RollBackTran
                  END
               END
            END

            -- Check last carton
            /*
            Last carton logic:
            1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton
            2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton
            */
            -- 1. Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1 
                        FROM dbo.PickDetail PickD WITH (NOLOCK) 
                        WHERE PickD.StorerKey = @cStorerKey 
                        AND   PickD.Status IN ('0', '4')
                        AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PackD WITH (NOLOCK) 
                                       WHERE PackD.DropID = @cDropID 
                                       AND   PickD.Storerkey = PackD.StorerKey 
                                       AND   PickD.CaseID = PackD.LabelNo
                                       AND   PickD.Sku = PackD.SKU))

               SET @cLastCarton = 'N' 
            ELSE
            BEGIN
               -- 2. Check manifest printed
               -- discrete pickslip, 1 ordes 1 pickslipno
               SET @nPackedQty = 0
               SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   Storerkey = @cStorerkey
               AND   DropID = @cDropID

               -- Get PPA QTY
               SET @nPPA_QTY = 0
               SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)
               FROM rdt.rdtPPA WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   DropID = @cDropID
            
               IF @nPackedQty <> @nPPA_QTY
                  SET @cLastCarton = 'N' 
               ELSE
                  SET @cLastCarton = 'Y' 
            END

            -- Insert print job
            IF @cLastCarton = 'Y'
            BEGIN
               SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
               IF @cDelNotes = '0'
                  SET @cDelNotes = ''

               IF @cDelNotes <> ''
               BEGIN
                  DECLARE @tDELNOTES AS VariableTable
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)
                  INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                     @cDelNotes, -- Report type
                     @tDELNOTES, -- Report params
                     'rdt_855ExtUpd05', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO RollBackTran

                  -- Prompt message
                  SET @nErrNo = 106764
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackLstPrinted
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
                  SET @nErrNo = 0
                  SET @cErrMsg = ''

                  -- Update DropID
                  UPDATE dbo.DropID SET
                     ManifestPrinted = '1'
                  WHERE DropID = @cDropID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 106765
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
                     GOTO RollBackTran
                  END
               END
            END
         END
      END
   END
   --COMMIT TRAN rdt_855ExtUpd05

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_855ExtUpd05
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO