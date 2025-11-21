SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd16                                    */
/* Purpose: TM Replen From, Extended Update for HK ANF                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-10-08   Chermaine 1.0   WMS-17383 Created (dup rdt_1764ExtUpd)  */
/* 2022-04-06   ChewKP    1.1   Bug Fixes (ChewKP01)                    */
/* 2022-05-26   Ung       1.2   WMS-19721 Add short pick                */
/*                              Add AutoPackConfirm                     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtUpd16]
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
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @cDocType     NVARCHAR( 1)
   DECLARE @nTaskQTY    INT
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @cLabelGenCode  NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @cPkSlipNo      NVARCHAR( 10) -- (james02)
   DECLARE @cPD_CaseID     NVARCHAR( 20) -- (james02)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cAutoPackConfirm   NVARCHAR( 1)
   DECLARE @cLocationGroup     NVARCHAR( 30)

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
            BEGIN TRAN
            SAVE TRAN rdt_1764ExtUpd16

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
               -- Check extra UCC
               IF EXISTS( SELECT TOP 1 1
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND LOT = @cFromLOT
                     AND LOC = @cFromLOC
                     AND ID = @cFromID
                     AND Status IN ('1', '3')
                     AND NOT EXISTS( SELECT TOP 1 1
                        FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND LOT = @cFromLOT
                           AND LOC = @cFromLOC
                           AND ID = @cFromID
                           AND DropID = UCC.UCCNo   -- Exclude taken UCC, due to FromID can scan multiple times
                           AND Status < '9'))       -- Exclude cancel order, shipped UCC and put back
               BEGIN
                  SET @nErrNo = 176751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FoundExtraUCC
                  GOTO RollBackTran
               END

               -- Update PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                   Status = '3' -- Pick in-progress
                  ,EditDate = GETDATE()
                  ,EditWho = 'rdt.' + SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176752
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
                  SET @nErrNo = 176753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey
            END

            COMMIT TRAN rdt_1764ExtUpd16 -- Only commit change made here
         END
      END

      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR(10)
         DECLARE @cUOM        NVARCHAR(10)
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
            -- @cDropID = DropID, -- Cancel/SKIP might not have DropID
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
               SET @nErrNo = 176754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               GOTO Quit
            END
            SET @cDropID = @cFromID
         END

         -- Get wave info
         DECLARE @cDispatchPiecePickMethod NVARCHAR(10)
         SELECT @cDispatchPiecePickMethod = DispatchPiecePickMethod FROM Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey

         SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
         IF @cPickConfirmStatus = '0'
            SET @cPickConfirmStatus = '5'

         -- Get initial task
         IF @cListKey <> ''  -- For protection, in case ListKey is blank
            INSERT INTO @tTask (TaskDetailKey)
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd16

         -- Loop tasks
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT T.TaskDetailKey, TD.Status, TD.CaseID, TD.QTY, TD.ToLOC
            FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cCaseID, @nTaskQTY, @cToLOC
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
                  SET @nErrNo = 176755
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
            END

            -- Completed task
            IF @cStatus = '9'
            BEGIN
               -- Get PickDetail info
               SET @cPickSlipNo = ''
               SELECT TOP 1
                  @cPickSlipNo = PickSlipNo,
                  @cUOM = UOM
               FROM PickDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskKey

               -- Scan-in
               IF EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanInDate IS NULL)
               BEGIN
                  UPDATE PickingInfo WITH (ROWLOCK) SET
                     ScanInDate = GETDATE(),
                     PickerID = SUSER_SNAME(),
                     EditWho = SUSER_SNAME(),
                     TrafficCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 176756
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan-in Fail
                     GOTO RollBackTran
                  END
               END

               -- PickDetail
               BEGIN
                  -- Loop PickDetail
                  SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                     SELECT PD.PickDetailKey, PD.CaseID, PD.PickSlipNo, O.DocType, L.LocationGroup, PD.OrderKey
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN Orders O WITH (NOLOCK) ON (O.orderKey = PD.OrderKey)
                     JOIN TaskDetail TD WITH (NOLOCK) ON (TD.taskDetailKey = PD.TaskDetailKey)
                     JOIN Loc L WITH (NOLOCK) ON (TD.toLoc = L.Loc)
                     WHERE PD.TaskdetailKey = @cTaskKey
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPD_CaseID, @cPkSlipNo, @cDocType, @cLocationGroup, @cOrderKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF @nTaskQTY = 0 -- Short replen (1 task 1 UCC)
                     BEGIN
                        UPDATE dbo.PickDetail SET
                           Status = '4'
                          ,EditDate = GETDATE()
                          ,EditWho  = SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 176761
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                     END
                     
                     ELSE IF @cDocType = 'N' AND @cUOM = '2'
                     BEGIN
                        UPDATE dbo.PickDetail SET
                           Status = '5'
                          ,EditDate = GETDATE()
                          ,EditWho  = SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 176757
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                     END
                     
                     ELSE IF @cDocType = 'E' AND @cLocationGroup = 'PACKING' AND @cUOM IN ( '2', '6')
                     BEGIN
                        UPDATE dbo.PickDetail SET
                            Status = @cPickConfirmStatus
                           ,CaseID = ''
                           ,EditDate = GETDATE()
                           ,EditWho  = SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 176758
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                     END
                     
                     -- Pack confirm
                     IF @cAutoPackConfirm = '1'
                     BEGIN
                        -- PPA location
                        IF EXISTS( SELECT 1 
                           FROM dbo.LOC WITH (NOLOCK) 
                           WHERE LOC = @cToLOC 
                              AND LocationType = 'OTHER' 
                              AND LocationCategory = 'OTHER'
                              AND Loc.LocationHandling = '2' 
                              AND Loc.LocationFlag = 'HOLD')
                        BEGIN
                           DECLARE @cPackConfirm NVARCHAR( 1)
                           DECLARE @nPickQTY INT
                           DECLARE @nPackQTY INT

                           -- Check outstanding PickDetail  
                           IF EXISTS( SELECT TOP 1 1  
                              FROM dbo.PickDetail PD WITH (NOLOCK)  
                              WHERE PD.OrderKey = @cOrderKey  
                                 AND PD.Status < '5'  
                                 AND PD.QTY > 0  
                                 AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick  
                              SET @cPackConfirm = 'N'  
                           ELSE  
                              SET @cPackConfirm = 'Y'  
                             
                           -- Check fully packed  
                           IF @cPackConfirm = 'Y'  
                           BEGIN
                              SET @nPickQTY = 0
                              SET @nPackQTY = 0
                              
                              SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
                              FROM dbo.PickDetail PD WITH (NOLOCK)   
                              WHERE PD.OrderKey = @cOrderKey  

                              SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
                              FROM PackDetail WITH (NOLOCK) 
                              WHERE PickSlipNo = @cPickSlipNo  
                                
                              IF @nPickQTY <> @nPackQTY  
                                 SET @cPackConfirm = 'N'  
                           END 

                           -- Pack confirm  
                           IF @cPackConfirm = 'Y'  
                           BEGIN  
                              -- Pack confirm  
                              UPDATE PackHeader SET   
                                 Status = '9', 
                                 EditDate = GETDATE(),   
                                 EditWho = SUSER_SNAME()
                              WHERE PickSlipNo = @cPickSlipNo  
                                 AND Status <> '9'  
                              SET @nErrNo = @@ERROR   
                              IF @nErrNo <> 0  
                              BEGIN  
                                 -- SET @nErrNo = 100251  
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail  
                                 GOTO RollBackTran  
                              END 
                           END
                        END  
                     END
                     
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPD_CaseID, @cPkSlipNo, @cDocType, @cLocationGroup, @cOrderKey
                  END
               END
            END

            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cCaseID, @nTaskQTY, @cToLOC
         END

         COMMIT TRAN rdt_1764ExtUpd16 -- Only commit change made here
      END

      IF @nStep = 9 -- Reason
      BEGIN
         -- Get task info
         SELECT
            @cUserKey    = UserKey,
            @cStatus     = Status,
            @cReasonKey  = ReasonKey,
            @cTaskType   = TaskType,
            @cFromID     = FromID,
            @cToLOC      = ToLOC,
            @cRefTaskKey = RefTaskKey,
            @cPickMethod = PickMethod,     -- (james01)
            @cWaveKey    = WaveKey,
            @cStorerKey  = StorerKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey

         -- IF Skip TaSK Update ListKey of Current Task = '' -- (ChewKP01)
         IF @cStatus = '0'
         BEGIN
            UPDATE dbo.TaskDetail SET
                ListKey = ''
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_SNAME()
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @cTaskdetailKey

            IF @@ERROR <> 0
            BEGIN
                  SET @nErrNo = 176759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
            END
         END

         IF @cTaskStatus = ''
            GOTO Quit

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd16

         IF @cTaskType = 'RPF'
         BEGIN
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

            -- Loop own task and other task
           SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TD.TaskDetailKey, TD.LOT, TD.FromLOC, TD.FromID, TD.StorerKey, TD.SKU, TD.QTY, TD.CaseID, TD.TransitLOC, TD.FinalLOC, TD.FinalID
               FROM @tTask t
                  JOIN TaskDetail TD WITH (NOLOCK) ON (t.TaskDetailKey = TD.TaskDetailKey)
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, @cTaskUCC,
               @cTransitLOC, @cFinalLOC, @cFinalID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update other tasks
               UPDATE dbo.TaskDetail SET
                   Status = @cStatus
                  ,UserKey = @cUserKey
                  ,ReasonKey = @cReasonKey
                  ,RefTaskKey = ''
                  --,ListKey = ''
                  ,ToLOC = @cFinalLOC
                  ,ToID = @cFinalID
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
               END

               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerkey
                           AND WaveKey = @cWaveKey
                           AND TaskType = 'CPK'
                           AND SKU = @cTaskSKU
                           AND FromLoc = @cFinalLOC
                           AND Status = 'H')
               BEGIN
                   UPDATE dbo.TaskDetail WITH (ROWLOCK)
                     SET  ReasonKey = @cReasonKey
                         ,EditDate = GETDATE()
                         ,EditWho  = SUSER_SNAME()
                         ,TrafficCop = NULL
                   WHERE StorerKey = @cStorerkey
                   AND WaveKey = @cWaveKey
                   AND TaskType = 'CPK'
                   AND SKU = @cTaskSKU
                   AND FromLoc = @cFinalLOC
                   AND Status = 'H'

                   IF @@ERROR <> 0
                   BEGIN
                        SET @nErrNo = 176759
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                        GOTO RollBackTran
                   END
               END

               -- Generate alert
               EXEC nspLogAlert
                    @c_modulename       = 'RPF'
                  , @c_AlertMessage     = 'UCC SHORT/CANCEL'
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
                  , @c_UCCNo            = @cTaskUCC

               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY, @cTaskUCC,
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
                  --,TrafficCop = NULL        -- ZG01
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176760
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

         COMMIT TRAN rdt_1764ExtUpd16 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd16 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO