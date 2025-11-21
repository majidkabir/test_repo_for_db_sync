SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtUpd01                                          */
/* Purpose: TM Replen From, Extended Update for HK Pearson                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2016-07-12   Ung       1.0   SOS372531 Created                             */
/* 2017-06-06   Ung       1.1   WMS-2111 Scan-in for task with multi PSNO     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd01]
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
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   DECLARE @cWaveKey    NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
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
   DECLARE @cListKey    NVARCHAR( 10)
   DECLARE @nTaskQTY    INT
   DECLARE @cPickDetailKey  NVARCHAR( 10)
   DECLARE @cLabelGenCode   NVARCHAR( 10)
   DECLARE @nQTY            INT

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
      IF @nStep = 3 -- FromID
      BEGIN
         -- Get task info
         SELECT
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            @cFromLOT = LOT,
            @cFromLOC = FromLOC,
            @cFromID = FromID,
            @cTaskType = TaskType,
            @cUserKey = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Stamp PickDetail.Status for entire pallet
         IF @cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            DECLARE @nTotalTaskQTY INT
            SELECT @nTotalTaskQTY = SUM( QTY)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskType = 'RPF'
               AND PickMethod = 'FP'
               AND FromLOC = @cFromLOC
               AND FromID = @cFromID
               AND UserKey = @cUserKey
               AND Status = '3'
                  
            DECLARE @nTotalInvQTY INT
            SELECT @nTotalInvQTY = SUM( QTY-QTYPicked)
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE LOC = @cFromLOC
               AND ID = @cFromID
            
            -- Check extra carton
            IF @nTotalTaskQTY <> @nTotalInvQTY
            BEGIN
               SET @nErrNo = 102301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FoundExtra
               GOTO Quit
            END

/*
            BEGIN TRAN
            SAVE TRAN rdt_1764ExtUpd01

            -- Loop tasks
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskType = 'RPF'
                  AND PickMethod = 'FP'
                  AND FromLOC = @cFromLOC
                  AND FromID = @cFromID
                  AND UserKey = @cUserKey
                  AND Status = '3'
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '5', 
                  DropID = @cDropID,
                  EditDate = GETDATE(),
                  EditWho = 'rdt.' + SUSER_SNAME()
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 102302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END

               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Status = '5', -- Picked
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = @cUserKey,
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 102303
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey
            END

            COMMIT TRAN rdt_1764ExtUpd01 -- Only commit change made here
*/
         END
      END

      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR(10)
         DECLARE @cLabelNo    NVARCHAR(20)
         DECLARE @nCartonNo   INT
         DECLARE @fWeight     FLOAT
         DECLARE @fCube       FLOAT

         -- Get task info
         SELECT
            @cWaveKey = WaveKey, 
            @cTaskType = TaskType, 
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            @cFromID = FromID,
            @cDropID = DropID, -- Cancel/SKIP might not have DropID
            @cListKey = ListKey -- Cancel/SKIP might not have ListKey (e.g. last carton SKIP)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Get list key (quick fix)
         IF @cListKey = ''
            SELECT @cListKey = V_String7 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Check FP without ID
         IF @cPickMethod = 'FP'
         BEGIN
            IF @cFromID = ''
            BEGIN
               SET @nErrNo = 102304
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               GOTO Quit
            END
            SET @cDropID = @cFromID
         END

         -- Get initial task
         IF @cListKey <> ''  -- For protection, in case ListKey is blank
            INSERT INTO @tTask (TaskDetailKey)
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd01

         -- Loop tasks
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT T.TaskDetailKey, TD.Status
            FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Cancel/skip task
            IF @cStatus IN ('X', '0')
            BEGIN
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  ListKey = '',
                  DropID = '',
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 102305
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
            END

            -- Completed task
            IF @cStatus = '9'
            BEGIN
               DECLARE @dScanInDate DATETIME
               DECLARE @curPSNO CURSOR

               -- Loop PickSlipNo
               SET @curPSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT DISTINCT PickSlipNo
                  FROM PickDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskKey
               OPEN @curPSNO
               FETCH NEXT FROM @curPSNO INTO @cPickSlipNo
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Get PickingInfo info
                  SELECT @dScanInDate = ScanInDate FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

                  IF @@ROWCOUNT = 0
                  BEGIN
                     INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
                     VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME())
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 102309
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN
                     IF @dScanInDate IS NULL
                     BEGIN
                        UPDATE PickingInfo WITH (ROWLOCK) SET
                           ScanInDate = GETDATE(),
                           PickerID = SUSER_SNAME(),
                           EditWho = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickSlipNo = @cPickSlipNo
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 102306
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                           GOTO RollBackTran
                        END
                     END
                  END
                  FETCH NEXT FROM @curPSNO INTO @cPickSlipNo
               END
               
               -- Loop PickDetail
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PickDetailKey
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskKey
                     AND Status = '0'
                     AND QTY > 0
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Update PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Status = '5', 
                     DropID = @cDropID, 
                     EditDate = GETDATE(),
                     EditWho = 'rdt.' + SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 59511
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END

               /*
               -- Update PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '5', 
                  DropID = @cDropID, 
                  EditDate = GETDATE(),
                  EditWho = 'rdt.' + SUSER_SNAME()
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0 OR @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 59511
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               */
            END

            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
         END

         COMMIT TRAN rdt_1764ExtUpd01 -- Only commit change made here
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
         SAVE TRAN rdt_1764ExtUpd01

         IF @cTaskType = 'RPF'
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
                  SET @nErrNo = 102307
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
               END
               
               -- Generate alert
               EXEC nspLogAlert
                    @c_modulename       = 'RPF'
                  , @c_AlertMessage     = 'SHORT/CANCEL'
                  , @n_Severity         = '5'
                  , @b_Success          = @b_Success      OUTPUT
                  , @n_err              = @n_Err          OUTPUT
                  , @c_errmsg           = @c_ErrMsg       OUTPUT
                  , @c_Activity         = 'RPF'
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
   
            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickDetailKey
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE TaskdetailKey IN (SELECT TaskdetailKey FROM @tTask)
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Reset Status
               UPDATE dbo.PickDetail SET
                   Status = '0'
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 102308
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
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

         COMMIT TRAN rdt_1764ExtUpd01 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO