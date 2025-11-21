SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_864ExtUpd01                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 07-Jun-2018 1.0  James       WMS4127. Created                        */
/* 07-Aug-2018 1.1  James       Pick confirm when ASN is closed for     */
/*                              xdock (james01)                         */
/* 28-Aug-2018 1.2  James       Change to gen discrete pickslip(james02)*/
/* 24-Oct-2018 1.3  James       Change the way to get pickslip (james03)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_864ExtUpd01] (
   @nMobile         INT,
   @nFunc           INT,
   @nStep           INT,
   @nInputKey       INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerkey      NVARCHAR( 15),
   @cID             NVARCHAR( 18),
   @cConsigneeKey   NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cDropID         NVARCHAR( 20),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	      INT,
           @cLabelNo          NVARCHAR( 20),
           @cLabelLine        NVARCHAR( 5),
           @cPickSlipNo       NVARCHAR( 10),
           @cLoadKey          NVARCHAR( 10),
           @cOrderKey         NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @bSuccess          INT,
           @nCartonNo         INT,
           @nPD_QTY           INT,
           @nPAD_QTY          INT,
           @cPKSlipNo         NVARCHAR( 10),
           @cPickDetailKey    NVARCHAR( 10),
           @cOrderLineNumber  NVARCHAR( 5)

      SELECT @cOrderKey = V_String22,
             @cUserName = UserName
      FROM RDT.RDTMOBREC WITH (NOLOCK) 
      WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_864ExtUpd01 -- For rollback or commit only our own transaction

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cLoadKey = LoadKey
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         IF ISNULL( @cLoadKey, '') = ''
         BEGIN  
            SET @nErrNo = 124951  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No LoadKey
            GOTO RollBackTran  
         END 
         
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey   -- (james02)
         
         IF ISNULL( @cPickSlipNo, '') = ''
            SELECT @cPickSlipNo = PickSlipNo
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey   

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
			   EXECUTE nspg_GetKey
				   'PICKSLIP',
				   9,
				   @cPickSlipNo   OUTPUT,
				   @bSuccess      OUTPUT,
               @nErrNo        OUTPUT,  
               @cErrMsg       OUTPUT  

            IF @bSuccess <> 1  
            BEGIN  
               SET @nErrNo = 124952  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
               GOTO RollBackTran  
            END  

			   SELECT @cPickSlipNo = 'P' + @cPickSlipNo
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.PICKHEADER WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PICKHEADER 
            (PickHeaderKey, ExternOrderkey, Zone, PickType, LoadKey, OrderKey) 
            VALUES
            (@cPickSlipNo, @cLoadKey, 'XD', '0',  @cLoadKey, @cOrderKey)  

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 124953  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPKSlip Fail  
               GOTO RollBackTran  
            END  
         END

         DECLARE CUR_REFKEYINS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PICKDETAILKEY, OrderLineNumber 
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND NOT EXISTS ( SELECT 1 FROM RefKeyLookup REF WITH (NOLOCK) WHERE PD.PickDetailKey = REF.PickDetailkey)
         ORDER BY 1 
         OPEN CUR_REFKEYINS
         FETCH NEXT FROM CUR_REFKEYINS INTO @cPickDetailKey, @cOrderLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN

            INSERT INTO dbo.RefKeyLookup 
            (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, LoadKey) 
            VALUES
            (@cPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadKey)  

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 124963  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRefKey Fail  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM CUR_REFKEYINS INTO @cPickDetailKey, @cOrderLineNumber
         END
         CLOSE CUR_REFKEYINS
         DEALLOCATE CUR_REFKEYINS

         -- Get Pickdetail QTY
         SELECT @nPD_QTY = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   [Status] < '9'

         -- Get Packdetail QTY
         SELECT @nPAD_QTY = ISNULL( SUM( QTY), 0)
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND   LabelNo = @cDropID
         AND   SKU = @cSKU

         IF ( @nPAD_QTY + 1) > @nPD_QTY
         BEGIN  
            SET @nErrNo = 124954  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack  
            GOTO RollBackTran  
         END  

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
               SET @nErrNo = 124955
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
               SET @nErrNo = 124956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
               GOTO RollBackTran
            END
         END

         /*-------------------------------------------------------------------------------

                                           PackDetail

         -------------------------------------------------------------------------------*/
         -- Check PackDetail exist
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cDropID)
         BEGIN
            /*
            -- Get new LabelNo
            EXECUTE isp_GenUCCLabelNo
                     @cStorerKey,
                     @cLabelNo     OUTPUT,
                     @bSuccess     OUTPUT,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 124957
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO RollBackTran
            END
            */

            SET @cLabelNo = @cDropID

            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, '0', @cLabelNo, '00000', @cStorerKey, @cSKU, 1, @cDropID,
               'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 124958
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Same pickslip, dropid but different sku
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND   PickSlipNo = @cPickSlipNo 
                           AND   DropID = @cDropID
                           AND   SKU = @cSKU)
            BEGIN
               SET @nCartonNo = 0

               SELECT TOP 1 @nCartonNo = CartonNo, @cLabelNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE Pickslipno = @cPickSlipNo
                  AND StorerKey = @cStorerKey
                  AND DropID = @cDropID

               -- Get next Label No
               SELECT @cLabelLine = 
                  RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
                     
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, 1, @cDropID,
                  'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 124959
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                  QTY = QTY + 1,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND DropID = @cDropID
                  AND SKU = @cSKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 124960
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                  GOTO RollBackTran
               END
            END   -- DropID exists and SKU exists (update qty only)
         END

         -- Check if ASN closed. If yes then confirm pack thus confirm pick (james01)
         IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   UserDefine03 = @cLoadKey
                         AND   [Status] = '0' )
         BEGIN
            -- Make sure everything picked for this loadkey
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
                            WHERE PD.StorerKey = @cStorerkey
                            AND   PD.Status = '0'
                            AND   LPD.LoadKey = @cLoadKey)
            BEGIN
               DECLARE CUR_PackCfm CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK)
               WHERE LoadKey = @cLoadKey
               OPEN CUR_PackCfm
               FETCH NEXT FROM CUR_PackCfm INTO @cPKSlipNo
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                              WHERE PickSlipNo = @cPKSlipNo
                              AND   [Status] = '0')
                  BEGIN
                     -- Pack confirm
                     UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
                        [Status] = '9'
                     WHERE PickSlipNo = @cPKSlipNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 124961
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm fail
                        CLOSE CUR_PackCfm
                        DEALLOCATE CUR_PackCfm
                        GOTO RollBackTran
                     END
                  END

                  FETCH NEXT FROM CUR_PackCfm INTO @cPKSlipNo
               END
               CLOSE CUR_PackCfm
               DEALLOCATE CUR_PackCfm

               DECLARE CUR_PickCfm CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PD.PickDetailKey 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
               WHERE PD.StorerKey = @cStorerkey
               AND   PD.Status = '3'
               AND   LPD.LoadKey = @cLoadKey
               OPEN CUR_PickCfm
               FETCH NEXT FROM CUR_PickCfm INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     EditDate = GETDATE(),
                     EditWho = @cUserName,
                     [Status] = '5'
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 124962
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickCfm fail
                     CLOSE CUR_PickCfm
                     DEALLOCATE CUR_PickCfm
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM CUR_PickCfm INTO @cPickDetailKey
               END
               CLOSE CUR_PickCfm
               DEALLOCATE CUR_PickCfm
            END
         END
      END   -- @nStep = 4
   END   -- @nInputKey = 1


   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_864ExtUpd01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO