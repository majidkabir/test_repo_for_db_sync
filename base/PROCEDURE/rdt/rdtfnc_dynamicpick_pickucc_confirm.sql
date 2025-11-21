SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_PickUCC_Confirm                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-03-2022 1.0  yeekung  WMS-19154. Created                          */ 
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_PickUCC_Confirm] (
   @nMobile        INT,
   @nFunc          INT, 
	@cLangCode	    NVARCHAR( 3),
	@cUserName      NVARCHAR( 15), 
	@cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cSuggLOC       NVARCHAR( 10), 
   @cPickSlipNo    NVARCHAR( 20), 
   @cSuggSKU       NVARCHAR( 20),
   @cUCCNo         NVARCHAR( 20),
   @cDropID        NVARCHAR( 20),
   @nSuggQTY       INT,
   @nErrNo         INT          OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_UCCPickAndPack_Confirm -- For rollback or commit only our own transaction

   DECLARE @cPickConfirmStatus NVARCHAR(1)
   DECLARE @cOrderKey NVARCHAR(10)
   DECLARE @cLoadKey  NVARCHAR( 10)

   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    

   /*-------------------------------------------------------------------------------

                                  Orders, PickDetail, UCC

   -------------------------------------------------------------------------------*/
   -- Get Orders info

   SELECT TOP 1 @cOrderKey = OrderKey 
   FROM dbo.PICKHEADER WITH (NOLOCK) 
   WHERE pickheaderkey = @cPickSlipNo 

   IF @nSuggQTY=0
   BEGIN
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         Status = '4'
      WHERE PickSlipNo = @cPickSlipNO
         AND dropid=@cUccNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
         GOTO RollBackTran
      END

      GOTO QUIT
   END
   ELSE
   BEGIN
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         Status = '5'
      WHERE PickSlipNo = @cPickSlipNO
        AND dropid=@cuccno
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
         GOTO RollBackTran
      END
   END

   -- Update UCC
   IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo AND Status < '5') --5=Picked
   BEGIN
      UPDATE dbo.UCC WITH (ROWLOCK)
      SET
         Status = '5' -- Picked
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
         AND Status < '5' --5=Picked
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 184904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCC Fail
         GOTO RollBackTran
      END
   END


   /*-------------------------------------------------------------------------------

                                  PackHeader, PickingInfo

   -------------------------------------------------------------------------------*/



   
   -- Check PackHeader exist
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      -- Insert PackHeader
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
         GOTO RollBackTran
      END
   END

   -- Check PickingInfo exist
   IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      -- Insert PackHeader
      INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
      VALUES (@cPickSlipNo, GETDATE(), @cUserName)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
         GOTO RollBackTran
      END
   END

   /*-------------------------------------------------------------------------------

                                        PackDetail

   -------------------------------------------------------------------------------*/
   -- Check PackDetail exist
   IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cUCCNo)
   BEGIN
      -- Get UCC info
      DECLARE @cUCCSKU NVARCHAR( 20)
      DECLARE @nUCCQTY INT
      SELECT 
         @cUCCSKU = SKU, 
         @nUCCQTY = QTY
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cUCCNo
         
      -- Insert PackDetail
      INSERT INTO dbo.PackDetail
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
      VALUES
         (@cPickSlipNo, 0, @cUCCNo, '00000', @cStorerKey, @cUCCSKU, @nUCCQTY, @cDropID, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign
         'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
         GOTO RollBackTran
      END
   END

   DECLARE @nPickQTY INT,
           @nPackQTY INT,
           @bSuccess INT

   SELECT @nPickQTY=SUM(qty)
   FROM PICKDETAIL (NOLOCK)
   WHERE orderkey=@corderkey
   AND status<>'4'
   AND storerkey=@cStorerKey

   SELECT @nPackQTY= SUM(qty)
   FROM packdetail (nolock) 
   where pickslipno=@cPickSlipNo

   IF @nPickQTY=@nPackQTY AND  NOT EXISTS ( SELECT 1
                                          FROM PICKDETAIL (NOLOCK)
                                          WHERE orderkey=@corderkey
                                          AND status='4'
                                          AND storerkey=@cStorerKey)
   BEGIN
      UPDATE PACKHEADER WITH (ROWLOCK)
      set status=9
      where pickslipno=@cPickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPHFail
         GOTO RollBackTran
      END

      -- Get storer config  
      DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)  
      EXECUTE nspGetRight    
         @cFacility,  
         @cStorerKey,    
         '', --@c_sku    
         'AssignPackLabelToOrdCfg',    
         @bSuccess                 OUTPUT,    
         @cAssignPackLabelToOrdCfg OUTPUT,    
         @nErrNo                   OUTPUT,    
         @cErrMsg                  OUTPUT    

         IF @nErrNo <>0
            GOTO Rollbacktran
  
         IF @cAssignPackLabelToOrdCfg = '1'  
         BEGIN  
            -- Update PickDetail, base on PackDetail.DropID  
            EXEC isp_AssignPackLabelToOrderByLoad   
                @cPickSlipNo  
               ,@bSuccess OUTPUT  
               ,@nErrNo   OUTPUT  
               ,@cErrMsg  OUTPUT  

            IF @nErrNo <>0
               GOTO Rollbacktran
         END  
   END

   COMMIT TRAN rdt_UCCPickAndPack_Confirm

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cLocation     = @cSuggLOC, 
      @cRefNo1       = @cUCCNo, 
      @cPickSlipNo   = @cPickSlipNo,
      @nQTY          = @nUCCQTY

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPickAndPack_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO