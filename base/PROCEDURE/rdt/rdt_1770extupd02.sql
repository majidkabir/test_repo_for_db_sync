SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1770ExtUpd02                                          */
/* Purpose: Process reason code                                               */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2017-11-20   Ung       1.0   WMS-3007 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtUpd02]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nQTY            INT
   ,@cToLOC          NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
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
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @nTaskQTY    INT

   DECLARE @curTask     CURSOR
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10)
   )

   SET @nTranCount = @@TRANCOUNT

   -- TM pallet pick
   IF @nFunc = 1770
   BEGIN
      IF @nStep = 6 -- Reason
      BEGIN
         -- Get task info
         SELECT
            @cTaskType   = TaskType, 
            @cStorerKey  = StorerKey, 
            @cUserKey    = UserKey,
            @cStatus     = Status,
            @cReasonKey  = ReasonKey,
            @cPickMethod = PickMethod,
            @cFromID     = FromID, 
            @cToLOC      = ToLOC, 
            @cRefTaskKey = RefTaskKey
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
               AND TaskType = 'FPK'
               AND PickMethod = 'FP' -- Task perform at once in nspTTMEvaluateRPFTasks, for FP only

         DECLARE @cTaskFromLOT   NVARCHAR( 10)
         DECLARE @cTaskFromLOC   NVARCHAR( 10) 
         DECLARE @cTaskFromID    NVARCHAR( 18)
         DECLARE @cTaskStorerKey NVARCHAR( 15)
         DECLARE @cTaskSKU       NVARCHAR( 20)
         DECLARE @cTaskUCC       NVARCHAR( 20)
         DECLARE @cTransitLOC    NVARCHAR( 10)
         DECLARE @cFinalID       NVARCHAR( 18)

         BEGIN TRAN
         SAVE TRAN rdt_1770ExtUpd02

         IF @cTaskType = 'FPK'
         BEGIN
            -- Loop task
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TD.TaskDetailKey, TD.LOT, TD.FromLOC, TD.FromID, TD.StorerKey, TD.SKU, TD.QTY, TD.TransitLOC, TD.FinalLOC, TD.FinalID
               FROM @tTask t
                  JOIN TaskDetail TD WITH (NOLOCK) ON (t.TaskDetailKey = TD.TaskDetailKey)
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, 
               @cTransitLOC, @cFinalLOC, @cFinalID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update other tasks
               IF @cTransitLOC = ''
                  UPDATE dbo.TaskDetail SET
                      Status = @cStatus
                     ,UserKey = @cUserKey
                     ,ReasonKey = @cReasonKey
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
                  SET @nErrNo = 117001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
               END
               
               -- Generate alert
               EXEC nspLogAlert
                    @c_modulename       = 'FPK'
                  , @c_AlertMessage     = 'SKIP/CANCEL'
                  , @n_Severity         = '5'
                  , @b_Success          = @b_Success      OUTPUT
                  , @n_err              = @n_Err          OUTPUT
                  , @c_errmsg           = @c_ErrMsg       OUTPUT
                  , @c_Activity         = 'FPK'
                  , @c_Storerkey        = @cTaskStorerKey
                  , @c_SKU              = @cTaskSKU
                  , @c_UOM              = ''
                  , @c_UOMQty           = ''
                  , @c_Qty              = @nTaskQTY
                  , @c_Lot              = @cTaskFromLOT
                  , @c_Loc              = @cTaskFromLOC
                  , @c_ID               = @cTaskFromID
                  , @c_TaskDetailKey    = @cTaskKey
               
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, 
                  @cTransitLOC, @cFinalLOC, @cFinalID
            END
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

         COMMIT TRAN rdt_1770ExtUpd02 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1770ExtUpd02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO