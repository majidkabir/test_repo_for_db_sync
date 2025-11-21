SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TM_NMVFrom_Confirm                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev   Author   Purposes                                        */
/* 07-05-2014  1.0   Ung      SOS309834. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_TM_NMVFrom_Confirm] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 18), 
   @cTaskDetailKey NVARCHAR( 10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cTransitLOC NVARCHAR( 10)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get task info
   SELECT 
      @cFromID = FromID, 
      @cToLOC = ToLOC, 
      @cTransitLOC = TransitLOC, 
      @cFinalLOC = FinalLOC
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_NMVFrom_Confirm -- For rollback or commit only our own transaction

   -- Execute move process
   UPDATE dbo.DropID SET
      DropLOC = @cToLOC, 
      EditDate = GETDATE(),
      EditWho  = @cUserName, 
      Trafficcop = NULL
   WHERE DropID = @cFromID
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 88001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail
      GOTO RollBackTran
   END

   -- Update Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Status = '9',
      EndTime = GETDATE(),
      EditDate = GETDATE(),
      EditWho  = @cUserName, 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 88002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Unlock SuggestedLOC
   EXEC rdt.rdt_NMV_PendingMoveIn @nMobile, @nFunc, @cLangCode, '', 'UNLOCK' 
      ,''       --@cTaskDetailKey
      ,''       --@cLOC      
      ,@cFromID --@cID       
      ,@cToLOC  --@cFinalLOC 
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Create next task
   IF @cTransitLOC <> ''
   BEGIN
      EXEC rdt.rdt_TM_NMVFrom_CreateNextTask @nMobile, @nFunc, @cLangCode,
         @cUserName,
         @cTaskDetailKey,
         @cFinalLOC, 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
   END

   COMMIT TRAN rdt_TM_NMVFrom_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_NMVFrom_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO