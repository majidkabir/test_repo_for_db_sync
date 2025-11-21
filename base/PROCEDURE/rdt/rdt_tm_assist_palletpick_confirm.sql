SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Assist_PalletPick_Confirm                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm pick pallet                                         */
/*                                                                      */
/* Date       Ver. Author   Purposes                                    */
/* 2017-11-15 1.0  Ung      WMS-3272 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_TM_Assist_PalletPick_Confirm]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC NVARCHAR(10)
   DECLARE @cFromID  NVARCHAR(18)

   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_Assist_PalletPick_Confirm -- For rollback or commit only our own transaction

   -- Move by ID
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdt_TM_Assist_PalletPick_Confirm', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cToLOC      = @cFinalLoc, 
      @cFromID     = @cFromID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc 
   IF @nErrNo <> 0
      GOTO RollbackTran
   
   -- Update task
   UPDATE dbo.TaskDetail SET
      Status = '9',
      ToLOC = @cFinalLoc,
      UserKey = SUSER_SNAME(),
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 116851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
      GOTO RollbackTran
   END

   COMMIT TRAN rdt_TM_Assist_PalletPick_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_Assist_PalletPick_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO