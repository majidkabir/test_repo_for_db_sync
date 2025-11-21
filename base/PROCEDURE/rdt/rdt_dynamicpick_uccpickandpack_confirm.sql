SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_UCCPickAndPack_Confirm              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-04-2013 1.0  Ung         SOS262114 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_UCCPickAndPack_Confirm] (
   @nMobile        INT,
   @nFunc          INT, 
	@cLangCode	    NVARCHAR( 3),
	@cUserName      NVARCHAR( 15), 
	@cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cLOC           NVARCHAR( 10), 
   @cPickDetailKey NVARCHAR( 10), 
   @cUCCNo         NVARCHAR( 20), 
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

   /*-------------------------------------------------------------------------------

                                  Orders, PickDetail, UCC

   -------------------------------------------------------------------------------*/
   -- Get Orders info
   DECLARE @cOrderKey NVARCHAR(10)
   SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey

   -- Update Orders
   IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '3')
   BEGIN
      UPDATE dbo.Orders SET 
         Status = '3' --Pick in progress
      WHERE OrderKey = @cOrderKey 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 65601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDOrdersFail
         GOTO RollBackTran
      END
   END

   -- Update PickDetail
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
      Status = '3', 
      DropID = @cUCCNo 
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 65602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
      GOTO RollBackTran
   END

   -- Update UCC
   IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo AND Status < '5') --5=Picked
   BEGIN
      UPDATE dbo.UCC SET
         Status = '5' -- Picked
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
         AND Status < '5' --5=Picked
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 65603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCC Fail
         GOTO RollBackTran
      END
   END


   /*-------------------------------------------------------------------------------

                                  PackHeader, PickingInfo

   -------------------------------------------------------------------------------*/
   -- Get PickDetail info
   DECLARE @cPickSlipNo NVARCHAR( 10)
   SELECT @cPickSlipNo = PickSlipNo FROM dbo.PickDetail WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey

   -- Get PickHeader info
   DECLARE @cLoadKey  NVARCHAR( 10)
   SELECT
      @cOrderKey = OrderKey, 
      @cLoadKey = ExternOrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo
   
   -- Check PackHeader exist
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      -- Insert PackHeader
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 65604
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
         SET @nErrNo = 65605
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
         (@cPickSlipNo, 0, @cUCCNo, '00000', @cStorerKey, @cUCCSKU, @nUCCQTY, @cUCCNo, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign
         'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 65606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
         GOTO RollBackTran
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
      @cLocation     = @cLOC, 
      @cRefNo1       = @cUCCNo, 
      @cPickSlipNo   = @cPickSlipNo

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPickAndPack_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO