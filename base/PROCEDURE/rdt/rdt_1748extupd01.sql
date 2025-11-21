SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************/
/* Store procedure: rdt_1748ExtUpd01                                                */
/* Copyright: LFLogistics                                                           */
/*                                                                                  */
/* Purpose: Send command to Junheinrich direct equipment to location                */
/*                                                                                  */
/* Date       Rev  Author     Purposes                                              */  
/* 2015-04-23 1.0  Ung        SOS340175 Created                                     */  
/************************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1748ExtUpd01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)
   DECLARE @nTranCount  INT

   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cUCC        NVARCHAR( 20)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @cTaskUOM    NVARCHAR( 10)
   DECLARE @cListKey    NVARCHAR( 10)
   -- DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cTransitLOC NVARCHAR( 10)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @nTaskQTY    INT
   DECLARE @nUCCQTY     INT
   DECLARE @curTask     CURSOR

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1748
   BEGIN
      IF @nStep = 0 -- Initial
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
      IF @nStep = 1 -- DropID
      BEGIN
         IF LEFT( @cDropID, 1) <> 'P'
         BEGIN
            SET @nErrNo = 81256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
            GOTO Quit
         END

         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END

      IF @nStep = 2 -- FromLOC
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nStep = 3 -- FromID
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nStep = 5 -- Option. 1=next task 2=close pallet
         IF @nAfterStep = 2 -- FromLOC
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, 1, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT -- Execute as @nStep = 1
      
      IF @nStep = 6 -- ToLOC
      BEGIN
         -- Get task info
         SELECT 
            @cPickMethod = PickMethod, 
            @cStorerKey = StorerKey, 
            -- @cFromLOT = LOT, 
            @cFromLOC = FromLOC, 
            @cFromID = FromID, 
            @cTaskType = TaskType, 
            @cUserKey = UserKey, 
            @cRefTaskKey = RefTaskKey, 
            @cReasonKey = ReasonKey, 
            @cDropID = DropID, 
            @cListKey = ListKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
         
         IF @cRefTaskKey <> '' --@cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdt_1748ExtUpd01
            
            -- Loop other tasks
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE RefTaskKey = @cRefTaskKey
                  AND TaskDetailKey <> @cTaskdetailKey
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Status = '9', -- Closed
                  DropID = @cDropID, 
                  ToID = CASE WHEN PickMethod = 'PP' THEN @cDropID ELSE ToID END, 
                  ReasonKey = @cReasonKey, 
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = @cUserKey, 
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curTask INTO @cTaskKey
            END
            
            COMMIT TRAN rdt_1748ExtUpd01 -- Only commit change made here        
         END
         
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      
      IF @nStep = 9 -- Reason
      BEGIN
         -- Get task info
         SELECT 
            @cUserKey    = UserKey, 
            @cStatus     = Status, 
            @cReasonKey  = ReasonKey, 
            @cPickMethod = PickMethod, 
            @cFromID     = FromID, 
            @cToLOC      = ToLOC, 
            @cTransitLOC = TransitLOC,
            @cFinalLOC   = FinalLOC, 
            @cFinalID    = FinalID, 
            @cRefTaskKey = RefTaskKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
         
         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey
         
         IF @cTaskStatus = ''
            GOTO Quit
         
         DECLARE @tTask TABLE 
         (
            TaskDetailKey NVARCHAR(10), 
            TransitLOC NVARCHAR(10),
            FinalLOC NVARCHAR(10),
            FinalID NVARCHAR(18)
         )
         
         -- Get own task
         INSERT INTO @tTask (TaskDetailKey, TransitLOC, FinalLOC, FinalID)
         SELECT @cTaskDetailKey, @cTransitLOC, @cFinalLOC, @cFinalID
         
         -- Get other tasks that perform at once
         IF @cRefTaskKey <> ''
            INSERT INTO @tTask (TaskDetailKey, TransitLOC, FinalLOC, FinalID)
            SELECT TaskDetailKey, TransitLOC, FinalLOC, FinalID
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE RefTaskKey = @cRefTaskKey
               AND TaskdetailKey <> @cTaskdetailKey

         BEGIN TRAN
         SAVE TRAN rdt_1748ExtUpd01
         
         -- Loop own task and other task
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TaskDetailKey, TransitLOC, FinalLOC, FinalID
            FROM @tTask
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update other tasks
            IF @cTransitLOC = ''
               UPDATE dbo.TaskDetail SET
                   Status = @cStatus
                  ,UserKey = @cUserKey
                  ,ReasonKey = @cReasonKey
                  ,RefTaskKey = ''
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
            ELSE
               UPDATE dbo.TaskDetail SET
                   Status = @cStatus
                  ,UserKey = @cUserKey
                  ,ReasonKey = @cReasonKey
                  ,RefTaskKey = ''
                  ,TransitLOC = ''
                  ,FinalLOC = ''
                  ,FinalID = ''
                  ,ToLOC = @cFinalLOC
                  ,ToID = @cFinalID
                  ,ListKey = ''
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81254
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
         END

         IF @cPickMethod = 'FP'
         BEGIN
            -- Unlock SuggestedLOC
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --@cSuggFromLOC
               ,@cFromID 
               ,'' --@cSuggToLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         IF @cPickMethod = 'PP'
         BEGIN
            -- Unlock  suggested location
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,''      --@cFromLOC
               ,@cFromID--@cFromID
               ,@cToLOC --@cSuggestedLOC
               ,''      --@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         COMMIT TRAN rdt_1748ExtUpd01 -- Only commit change made here        
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1748ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO