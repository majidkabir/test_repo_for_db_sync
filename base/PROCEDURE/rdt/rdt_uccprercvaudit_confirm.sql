SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCPreRCVAudit_Confirm                                */
/* Copyright      : LF Logistics                                              */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 02-06-2014 1.0  Ung         SOS313943 Created                              */
/* 27-10-2021 1.1  Chermaine   WMS-17896 Change @cOrgUCCNo->nvarchar(20) (cc01)*/
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCPreRCVAudit_Confirm] (
   @nMobile     INT,
   @nFunc       INT, 
	@cLangCode	 NVARCHAR( 3),
	@cUserName   NVARCHAR( 15), 
	@cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15), 
   @cUCCType    NVARCHAR( 10), -- RDM or CIQ
   @cExternKey  NVARCHAR( 20), 
   @cOrgUCCNo   NVARCHAR( 20), --(cc01) 
   @cNewUCCNo   NVARCHAR( 20), 
   @cSKU        NVARCHAR(20),
   @nQTY        INT, 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
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
   SAVE TRAN rdt_UCCPreRCVAudit_Confirm -- For rollback or commit only our own transaction

   -- Get PPA info
   DECLARE @nRowRef INT
   SELECT TOP 1
      @nRowRef = RowRef
   FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
   WHERE NewUCCNo = @cNewUCCNo
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND OrgUCCNo = @cOrgUCCNo

   -- Insert PPA
   IF @nRowRef IS NULL
   BEGIN
      INSERT INTO rdt.rdtUCCPreRCVAuditLog (NewUCCNo, StorerKey, SKU, QTY, OrgUCCNo, ExternKey, Status)
      VALUES (@cNewUCCNo, @cStorerKey, @cSKU, @nQTY, @cOrgUCCNo, @cExternKey, '0')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 88801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log Fail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      -- Update PPA
      UPDATE rdt.rdtUCCPreRCVAuditLog WITH (ROWLOCK) SET
         QTY = QTY + @nQTY
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 88802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail
         GOTO RollBackTran
      END
   END
   
   COMMIT TRAN rdt_UCCPreRCVAudit_Confirm

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cSKU          = @cSKU, 
      @nQTY          = @nQTY, 
      @cRefNo1       = @cOrgUCCNo, 
      @cRefNo2       = @cNewUCCNo

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPreRCVAudit_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO