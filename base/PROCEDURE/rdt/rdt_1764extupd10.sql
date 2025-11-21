SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd10                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-05-11   Ung       1.0   WMS-8537 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd10]
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

   DECLARE @nTranCount  INT
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @nTaskQTY    INT
   DECLARE @cPickDetailKey  NVARCHAR( 10)
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @nRowRef     INT

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10)
   )

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 9 -- Reason
      BEGIN
         -- Get task info
         SELECT
            @cTaskType   = TaskType,
            @cUserKey    = UserKey,
            @cStatus     = Status,
            @cReasonKey  = ReasonKey,
            @cPickMethod = PickMethod,
            @cFromID     = FromID, 
            @cToLOC      = ToLOC, 
            @cRefTaskKey = RefTaskKey, 
            @cCaseID     = CaseID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey

         /* TaskManagerReason must setup as:

            TaskManagerReasonKey RemoveTaskFromUserQueue TaskStatus ContinueProcessing
            -------------------- ----------------------- ---------- ------------------
            SKIP                 1                       0          0                 
            SHORT                0                                  1                 
            CANCEL               1                       X          0                 
         */


         IF @cTaskStatus = '' -- For short pick
            GOTO Quit

         -- Get own task
         INSERT INTO @tTask (TaskDetailKey)
         SELECT @cTaskDetailKey

         -- Get other tasks that perform at once
         IF @cRefTaskKey <> ''
            INSERT INTO @tTask (TaskDetailKey)
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE RefTaskKey = @cRefTaskKey
               AND TaskdetailKey <> @cTaskdetailKey
               AND TaskType = 'RPF'
               AND PickMethod = 'FP' -- Task perform at once in nspTTMEvaluateRPFTasks, for FP only

         DECLARE @cTaskFromLOT   NVARCHAR( 10)
         DECLARE @cTaskFromLOC   NVARCHAR( 10) 
         DECLARE @cTaskFromID    NVARCHAR( 18)
         DECLARE @cTaskStorerKey NVARCHAR( 15)
         DECLARE @cTaskSKU       NVARCHAR( 20)
         DECLARE @cTaskUCC       NVARCHAR( 20)
         DECLARE @cTransitLOC    NVARCHAR( 10)
         DECLARE @cFinalLOC      NVARCHAR( 10)
         DECLARE @cFinalID       NVARCHAR( 18)

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd10

         IF @cTaskType = 'RPF'
         BEGIN
            -- Loop task
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TD.TaskDetailKey, TD.LOT, TD.FromLOC, TD.FromID, TD.StorerKey, TD.SKU, TD.QTY, 
                  TD.TransitLOC, TD.FinalLOC, TD.FinalID, TD.CaseID
               FROM @tTask t
                  JOIN TaskDetail TD WITH (NOLOCK) ON (t.TaskDetailKey = TD.TaskDetailKey)
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, 
               @cTransitLOC, @cFinalLOC, @cFinalID, @cCaseID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update other tasks
               IF @cTransitLOC = ''
                  UPDATE dbo.TaskDetail SET
                      Status = @cStatus
                     ,UserKey = @cUserKey
                     ,ReasonKey = @cReasonKey
                     ,CaseID = ''
                     ,RefTaskKey = ''
                     ,ListKey = ''
                     ,EditDate = GETDATE()
                     ,EditWho  = SUSER_SNAME()
                     ,TrafficCop = NULL
                  WHERE TaskDetailKey = @cTaskKey
               ELSE
                  UPDATE dbo.TaskDetail SET
                      Status = @cStatus
                     ,UserKey = @cUserKey
                     ,ReasonKey = @cReasonKey
                     ,CaseID = ''
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
                  SET @nErrNo = 138701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
               END
               
               -- Reverse the update from DeocdeLabelNo (PickDetail, UCC)
               IF @cCaseID <> ''
               BEGIN
                  -- Update PickDetail
                  SET @curPD = CURSOR FOR
                     SELECT PickDetailKey FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskKey
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Update PickDetail
                     UPDATE dbo.PickDetail SET
                        DropID = '',
                        EditDate = GETDATE(),
                        EditWho = SUSER_SNAME(), 
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0 OR @@ROWCOUNT = 0
                     BEGIN
                        SET @nErrNo = 138702
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
                  
                  -- Update UCC
                  IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cTaskStorerKey AND UCCNo = @cCaseID AND Status = '3')
                  BEGIN
                     UPDATE UCC SET 
                        Status = '1', 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME(), 
                        TrafficCop = NULL
                     WHERE StorerKey = @cTaskStorerKey 
                        AND UCCNo = @cCaseID 
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 138703
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
                        GOTO RollBackTran
                     END
                  END
                  
                  -- Remove UCC from log
                  SET @nRowRef = 0
                  SELECT @nRowRef = RowRef FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskKey
                  IF @nRowRef > 0
                  BEGIN
                     DELETE rdt.rdtRPFLog WHERE RowRef = @nRowRef 
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 138704
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL RPFLogFail
                        GOTO RollBackTran
                     END
                  END
               END
               
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, 
                  @cTransitLOC, @cFinalLOC, @cFinalID, @cCaseID
            END
         END
/*
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
*/
         COMMIT TRAN rdt_1764ExtUpd10 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd10 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO