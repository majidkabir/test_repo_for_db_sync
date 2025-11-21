SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCPreRCVAudit_Reset                                  */
/* Copyright      : LF Logistics                                              */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 02-06-2014 1.0  Ung         SOS?????? Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCPreRCVAudit_Reset] (
   @nMobile     INT,
   @nFunc       INT, 
	@cLangCode	 NVARCHAR( 3),
	@cUserName   NVARCHAR( 15), 
	@cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15),
   @cOrgUCCNo   NVARCHAR( 20), 
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
   SAVE TRAN rdt_UCCPreRCVAudit_Reset -- For rollback or commit only our own transaction

   DECLARE @nRowRef INT
   DECLARE @curLog CURSOR
   SET @curLog = CURSOR FOR 
      SELECT RowRef
      FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
      WHERE OrgUCCNo = @cOrgUCCNo
         AND StorerKey = @cStorerKey
   OPEN @curLog
   FETCH NEXT FROM @curLog INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Delete
      DELETE rdt.rdtUCCPreRCVAuditLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 88851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curLog INTO @nRowRef
   END
   
   COMMIT TRAN rdt_UCCPreRCVAudit_Reset

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cRefNo1       = @cOrgUCCNo, 
      @cRefNo2       = 'RESET'

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPreRCVAudit_Reset
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO