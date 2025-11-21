SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_PutawayFrom_SwapTask                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 14-01-2013  1.0  Ung      SOS256104. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_PutawayFrom_SwapTask] (
   @nMobile           INT,
   @nFunc             INT,
   @cLangCode         NVARCHAR( 3),
   @cUserName         NVARCHAR( 18),
   @cTaskDetailKey    NVARCHAR( 10),
   @cNewID            NVARCHAR( 18),
   @cNewTaskDetailKey NVARCHAR( 10) OUTPUT,
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cTaskType         NVARCHAR( 10)
   DECLARE @cSuggFromLOC      NVARCHAR( 10)
   DECLARE @cSuggID           NVARCHAR( 18)
   DECLARE @cSuggToLOC        NVARCHAR( 10)
   DECLARE @cPickAndDropLOC   NVARCHAR( 10)
   DECLARE @cFitCasesInAisle  NVARCHAR( 1)
   DECLARE @nTransitCount     INT

   DECLARE @cNewFromLOC        NVARCHAR( 10)
   DECLARE @cNewSuggToLOC      NVARCHAR( 10)
   DECLARE @nNewTransitCount   INT
   DECLARE @cNewPickAndDropLOC NVARCHAR( 10)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get existing task info
   SELECT
      @cStorerKey = StorerKey,
      @cTaskType = TaskType,
      @cSuggFromLOC = FromLOC,
      @cSuggID = FromID, 
      @cSuggToLOC = ToLOC, 
      @nTransitCount = TransitCount,
      @cPickAndDropLOC = TransitLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get new task info
   SET @cNewTaskDetailKey = ''
   IF @cSuggID = @cNewID AND @cSuggToLOC = ''
      SELECT TOP 1
         @cNewTaskDetailKey = TaskDetailKey, 
         @cNewFromLOC = FromLOC,
         @cNewSuggToLOC = ToLOC,
         @nNewTransitCount = TransitCount,
         @cNewPickAndDropLOC = TransitLOC
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   ELSE
      SELECT TOP 1
         @cNewTaskDetailKey = TaskDetailKey, 
         @cNewFromLOC = FromLOC,
         @cNewSuggToLOC = ToLOC,
         @nNewTransitCount = TransitCount,
         @cNewPickAndDropLOC = TransitLOC
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskType = @cTaskType
         AND FromLOC = @cSuggFromLOC
         AND FromID = @cNewID
         AND (Status = '0' OR (Status = '3' AND UserKey = @cUserName))

   -- Check new task exist
   IF @cNewTaskDetailKey = ''
   BEGIN
      -- Check if other user taken this task
      DECLARE @cOtherUserName NVARCHAR(18)
      SET @cOtherUserName = ''
      SELECT TOP 1 
         @cOtherUserName = UserKey 
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskType = @cTaskType
         AND FromLOC = @cSuggFromLOC
         AND FromID = @cNewID
         AND Status = '3' 
         AND UserKey <> @cUserName
      IF @cOtherUserName <> ''
      BEGIN
         SET @nErrNo = 80104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LCK:
         SET @cErrMsg = RTRIM( @cErrMsg) + RTRIM( @cOtherUserName) 
      END
      ELSE
      BEGIN
         SET @nErrNo = 80101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoTaskOnThisID
      END
      GOTO Quit
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_PutawayFrom_SwapTask -- For rollback or commit only our own transaction

   -- Release current task
   IF @cTaskType = 'PAF'
   BEGIN
      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cSuggID 
         ,'' --@cSuggToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      UPDATE dbo.TaskDetail SET
          UserKey = ''
         ,ReasonKey = ''
         ,Status = '0'
         ,ToLOC = ''
         ,ToID = ''
         ,ListKey = ''
         ,TransitLOC = ''
         ,FinalLOC = ''
         ,FinalID = ''
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
   END
   ELSE
      UPDATE dbo.TaskDetail SET
          UserKey = ''
         ,ReasonKey = ''
         ,Status = '0'
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 80103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Get new suggest LOC
   IF @cNewSuggToLOC = ''
   BEGIN
      EXEC rdt.rdt_TM_PutawayFrom_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @cUserName
         ,@cStorerKey
         ,@cNewFromLOC
         ,@cNewID
         ,@cNewSuggToLOC      OUTPUT
         ,@cNewPickAndDropLOC OUTPUT
         ,@nErrNo             OUTPUT
         ,@cErrMsg            OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
   END

   -- Take new task
   IF @cNewPickAndDropLOC = ''
      UPDATE dbo.TaskDetail SET
          ToLOC      = @cNewSuggToLOC
         ,UserKey    = @cUserName
         ,Status     = '3'
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cNewTaskDetailKey
   ELSE
      UPDATE dbo.TaskDetail SET
          FinalLOC   = @cNewSuggToLOC
         ,FinalID    = @cNewID
         ,ToLOC      = @cNewPickAndDropLOC
         ,ToID       = @cNewID
         ,TransitLOC = @cNewPickAndDropLOC
         ,ListKey    = @cNewTaskDetailKey
         ,UserKey    = @cUserName
         ,Status     = '3'
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cNewTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 80102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Log swapped task
   IF @cTaskDetailKey <> @cNewTaskDetailKey
   BEGIN
      INSERT INTO rdt.rdtPAFSwapTaskLog (FromTaskKey, FromLOC, FromID, NewTaskKey, NewFromLOC, NewFromID)
      VALUES (@cTaskDetailKey, @cSuggFromLOC, @cSuggID, @cNewTaskDetailKey, @cNewFromLOC, @cNewID)
   END

   COMMIT TRAN rdt_TM_PutawayFrom_SwapTask -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_PutawayFrom_SwapTask -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO