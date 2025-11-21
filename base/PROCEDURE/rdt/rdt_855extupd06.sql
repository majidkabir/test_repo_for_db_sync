SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_855ExtUpd06                                        */
/*                                                                         */
/* Purpose: Create Packdetail during PPA                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author      Purposes                                   */
/* 2020-12-15  1.0  James       WMS-15813. Created                         */
/* 2021-07-06  1.1  YeeKung     WMS-17278 Add Reasonkey (yeekung01)        */
/***************************************************************************/

CREATE PROC [RDT].[rdt_855ExtUpd06] (
   @nMobile      INT, 
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT, 
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10), 
   @cPickslipNo  NVARCHAR( 10), 
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

   DECLARE @nTranCount	      INT,
           @cCaseID           NVARCHAR( 20),
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
           @bSuccess          INT,
           @cPickConfirmStatus   NVARCHAR( 1),
           @cSkipChkPSlipMustScanOut NVARCHAR( 1)


   DECLARE @fWeight        FLOAT
   DECLARE @fCube          FLOAT

   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)
   -- Check scan-out, PickDetail.Status must = 5
   IF @cSkipChkPSlipMustScanOut = '0'
      SET @cPickConfirmStatus = '5'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_855ExtUpd06 -- For rollback or commit only our own transaction

   IF @nFunc = 855
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            -- Get Orders info
            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE DropID = @cDropID
            AND   StorerKey = @cStorerKey
            AND   [Status] >= @cPickConfirmStatus
            AND   [Status] < '9'

            IF ISNULL( @cOrderKey, '') = ''
            BEGIN
               SET @nErrNo = 161451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No
               GOTO RollBackTran
            END

            -- 855 is dropid, assume no loadkey key in
            SELECT TOP 1 @cLoadKey = LoadKey
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Check PackHeader exist
            SELECT TOP 1 @cPickslipNo = Pickslipno 
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE LoadKey = @cLoadKey

            IF @@ROWCOUNT = 0
            BEGIN  
               -- Check PickHeader exist
               SELECT @cPickslipNo = PickHeaderKey 
               FROM dbo.PickHeader WITH (NOLOCK) 
               WHERE ExternOrderKey = @cLoadKey

               IF @@ROWCOUNT = 0
                  SELECT @cPickslipNo = PickHeaderKey 
                  FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE LoadKey = @cLoadKey
               
               IF ISNULL( @cPickslipNo, '') = ''
               BEGIN  
                  SET @nErrNo = 0
                  EXECUTE dbo.nspg_GetKey  
                     @KeyName       = 'PICKSLIP',  
                     @fieldlength   = 9,  
                     @keystring     = @cPickslipNo OUTPUT,  
                     @b_Success     = @bSuccess    OUTPUT,  
                     @n_err         = @nErrNo      OUTPUT,  
                     @c_errmsg      = @cErrMsg     OUTPUT  
  
                  IF @nErrNo <> 0
                  BEGIN  
                     SET @nErrNo = 161452
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'  
                     GOTO RollBackTran  
                  END
                  ELSE
                     SET @cPickslipNo = 'P' + @cPickslipNo  

                  INSERT INTO dbo.PICKHEADER 
                     (PickHeaderKey, Storerkey, ExternOrderKey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate, LoadKey)  
                  VALUES 
                     (@cPickslipNo, @cStorerkey, @cLoadKey, '5', '7', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cLoadKey)  

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 161453  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'  
                     GOTO RollBackTran  
                  END  
               END

               -- Insert PackHeader
               INSERT INTO dbo.PackHeader 
                  (PickSlipNo, StorerKey, LoadKey, OrderKey) 
               VALUES
                  (@cPickslipNo, @cStorerKey, @cLoadKey, '')

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161454
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
                  GOTO RollBackTran
               END
            END

            -- Check PickingInfo exist
            IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickslipNo)
            BEGIN
               -- Insert PackHeader
               INSERT INTO dbo.PickingInfo 
                  (PickSlipNo, ScanInDate, PickerID) 
               VALUES 
                  (@cPickslipNo, GETDATE(), SUSER_SNAME())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161455
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
                  GOTO RollBackTran
               END
            END

            /*-------------------------------------------------------------------------------

                                              PackDetail

            -------------------------------------------------------------------------------*/
            -- Check PackDetail exist
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo AND LabelNo = @cDropID)
            BEGIN
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickslipNo, 0, @cDropID, '00000', @cStorerKey, @cSKU, @nQTY, @cDropID,
                  'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161456
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               -- Same pickslip, labelno but different sku
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerKey
                              AND   PickSlipNo = @cPickslipNo 
                              AND   LabelNo = @cDropID
                              AND   SKU = @cSKU)
               BEGIN
                  SET @nCartonNo = 0

                  SELECT TOP 1 @nCartonNo = CartonNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickslipNo
                     AND StorerKey = @cStorerKey
                     AND LabelNo = @cDropID

                  -- Get next Label No
                  SELECT @cLabelLine = 
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickslipNo
                  AND   CartonNo = @nCartonNo
                     
                  -- Insert PackDetail
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cPickslipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID,
                     'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 161457
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     QTY = QTY + @nQTY,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickslipNo
                     AND LabelNo = @cDropID
                     AND SKU = @cSKU

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 161458
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                     GOTO RollBackTran
                  END
               END   -- DropID exists and SKU exists (update qty only)
            END

            -- Insert DropID
            IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
            BEGIN
               -- Insert DropID
               INSERT INTO dbo.DropID 
                  (DropID, LabelPrinted, ManifestPrinted, Status, LoadKey, PickSlipNo) 
               VALUES 
                  (@cDropID, '0', '0', '0', @cLoadKey, @cPickslipNo)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161459
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
                  GOTO RollBackTran
               END
            END

            SET @nExpectedQty = 0
            SELECT @nExpectedQty = ISNULL( SUM( PD.Qty), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @cLoadKey
            AND   PD.Storerkey = @cStorerkey
            AND   PD.Status >= @cPickConfirmStatus
            AND   PD.Status < '9'

            SET @nPackedQty = 0
            SELECT @nPackedQty = ISNULL( SUM( PD.Qty), 0) 
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
            WHERE PH.LoadKey = @cLoadKey
            AND   PH.Storerkey = @cStorerkey

            IF @nExpectedQty = @nPackedQty
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
                  [Status] = '9'
               WHERE PickSlipNo = @cPickslipNo
               AND   [Status] < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161460
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
                  GOTO RollBackTran
               END

               EXEC isp_ScanOutPickSlip
                  @c_PickSlipNo = @cPickslipNo,
                  @n_err = @nErrNo OUTPUT,
                  @c_errmsg = @cErrMsg OUTPUT

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 161461
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Out Fail
                  GOTO RollBackTran
               END
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_855ExtUpd06
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO