SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UCCPostPickAudit_ConfirmXDock                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2014-04-30  1.1  Ung      SOS309811. Support XDock                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_UCCPostPickAudit_ConfirmXDock] (
   @nMobile        INT,
   @nFunc          INT, 
	@cLangCode	    NVARCHAR( 3),
	@cUserName      NVARCHAR( 15), 
	@cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cUCCNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLOT        NVARCHAR(10)
   DECLARE @cLOC        NVARCHAR(10)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cPickSlipNo NVARCHAR(10)

   -- Get UCC info
   SET @cLOT = ''
   SELECT TOP 1
      @cLOT = LOT
   FROM UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo

   -- Check UCC LOT
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 87401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing UCCLOT
      GOTO Quit
   END
   
   -- Get Order info
   SET @cOrderKey = ''
   SET @cPickSlipNo = ''
   SELECT TOP 1 
      @cOrderKey = OrderKey, 
      @cPickSlipNo = PickSlipNo, 
      @cLOC = LOC
   FROM PickDetail WITH (NOLOCK)
   WHERE LOT = @cLOT

   -- Check allocated
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 87402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Alloc
      GOTO Quit
   END   

   -- Check release task
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 87403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl no PSNO
      GOTO Quit
   END   

   DECLARE @nTranCount	INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_UCCPostPickAudit_CfmXDock -- For rollback or commit only our own transaction


   /*-------------------------------------------------------------------------------

                             PickHeader, PackHeader, PickingInfo

   -------------------------------------------------------------------------------*/
   -- Check PackHeader exist
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
   BEGIN
      -- Insert PackHeader
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey)
      VALUES (@cPickSlipNo, @cStorerKey, '', @cOrderKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 87404
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
         SET @nErrNo = 87405
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
      DECLARE @cUCCSKU NVARCHAR( 20)
      DECLARE @nUCCQTY INT
      DECLARE @nCartonNo INT
      DECLARE @cLabelLine NVARCHAR( 5)

      SET @nCartonNo = 0
      
      -- Loop UCC info
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR FOR 
         SELECT SKU, QTY
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND UCCNo = @cUCCNo
         ORDER BY SKU
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN         
         -- Calc LabelLine
         IF @nCartonNo = 0
            SET @cLabelLine = '00000'
         ELSE
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cUCCNo
         
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cUCCNo, @cLabelLine, @cStorerKey, @cUCCSKU, @nUCCQTY, @cUCCNo, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign
            'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 87406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
            GOTO RollBackTran
         END
      
         -- Get auto assigned carton
         IF @nCartonNo = 0
            SELECT TOP 1 @nCartonNo = CartonNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cUCCNo
            
         FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQTY
      END
   END

   COMMIT TRAN rdt_UCCPostPickAudit_CfmXDock

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
   ROLLBACK TRAN rdt_UCCPostPickAudit_CfmXDock
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO