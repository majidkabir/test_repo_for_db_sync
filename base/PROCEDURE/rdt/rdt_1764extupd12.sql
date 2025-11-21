SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd12                                    */
/* Purpose: TM Replen From, Extended Update for HK ANF                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-06-24   James     1.0   WMS-13219. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd12]
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
   DECLARE @nTaskQTY    INT
   DECLARE @cPickDetailKey  NVARCHAR( 10)
   DECLARE @cLabelGenCode   NVARCHAR( 10)
   DECLARE @nQTY            INT
   DECLARE @cOrderKey       NVARCHAR( 10)
   DECLARE @cLoadKey        NVARCHAR( 10)
   DECLARE @cFacility       NVARCHAR( 5)
   DECLARE @bSuccess        INT
   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10)
   )

   DECLARE @cFinalLoc               NVARCHAR( 10)
   DECLARE @curClearPendingMoveIn   CURSOR
                     
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
            SAVE TRAN rdt_1764ExtUpd12

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
            BEGIN/*
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
                  SET @nErrNo = 154201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FoundExtraUCC
                  GOTO RollBackTran
               END
               */
               -- Update PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                   Status = '3' -- Pick in-progress
                  ,EditDate = GETDATE()
                  ,EditWho = 'rdt.' + SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 154202
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
                  SET @nErrNo = 154203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey
            END

            COMMIT TRAN rdt_1764ExtUpd12 -- Only commit change made here
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
               SET @nErrNo = 154204
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               GOTO Quit
            END
            SET @cDropID = @cFromID
         END

         -- Get wave info
         DECLARE @cDispatchPiecePickMethod NVARCHAR(10)
         SELECT @cDispatchPiecePickMethod = DispatchPiecePickMethod FROM Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey

         -- Get initial task
         IF @cListKey <> ''  -- For protection, in case ListKey is blank
            INSERT INTO @tTask (TaskDetailKey)
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd12

         -- Loop tasks
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT T.TaskDetailKey, TD.Status, TD.CaseID
            FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cCaseID
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
                  SET @nErrNo = 154205
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
                  @cUOM = UOM,
                  @cOrderKey = OrderKey
               FROM PickDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskKey

               SELECT @cLoadKey = LoadKey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
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
                     SET @nErrNo = 154206
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan-in Fail
                     GOTO RollBackTran
                  END
               END

               -- Create PackDetail for full case
               IF @cUOM = '2' AND @cTaskType = 'RPF' AND @cDispatchPiecePickMethod = 'SEPB2BPTS'
               BEGIN
                  -- PackHeader
                  IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
                  BEGIN
                     INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
                     VALUES (@cPickSlipNo, @cStorerKey, '', @cLoadKey)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 154207
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
                        GOTO RollBackTran
                     END
                  END

                  -- Get LabelNo
                  SET @cLabelNo = ''  
                  EXEC isp_GLBL08   
                     @c_PickSlipNo = @cPickSlipNo, 
                     @n_CartonNo   = 0, -- Not used 
                     @c_LabelNo    = @cLabelNo OUTPUT

                  IF @cLabelNo = ''  
                  BEGIN
                     SET @nErrNo = 154208
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetLabelNoFail
                     GOTO RollBackTran
                  END
                  
                  -- Create PackDetail
                  IF NOT EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo)
                  BEGIN
                     -- Get UCC info
                     SELECT 
                        @nQTY = QTY, 
                        @cSKU = SKU
                     FROM UCC WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                        AND UCCNo = @cCaseID
                     
                     INSERT INTO PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, DropID)  
                     VALUES  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nQTY, @cCaseID, @cCaseID)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 154209
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END
                  END
                  
                  -- Get carton no
                  SELECT @nCartonNo = CartonNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo
                  
                  -- Update PickDetail
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM PickDetail WITH (NOLOCK)
                     WHERE TaskDetailKey = @cTaskKey
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Update PickDetail
                     UPDATE dbo.PickDetail SET
                         CaseID = @cLabelNo
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME()
                        ,TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 154210
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END
            END

            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cCaseID
         END

         -- Get task info
         SELECT @cToLOC = ToLOC 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         SELECT @cFacility = FACILITY
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         SELECT @cLocationType = LocationType, 
                @cLocationCategory = LocationCategory
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE Loc = @cToLOC 
         AND   Facility = @cFacility
         
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE LISTNAME = 'AGVSTG'
                     AND   Code = @cLocationType
                     AND   Storerkey = @cStorerKey) AND 
            EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE LISTNAME = 'AGVCAT'
                     AND   Code = @cLocationCategory
                     AND   Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 0
            EXEC dbo.isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound 
               @c_StorerKey= @cStorerKey,
               @c_PalletId = @cDropID,
               @c_Facility = @cFacility,
               @b_Debug    = 0,
               @b_Success  = @bSuccess   OUTPUT,
               @n_Err      = @nErrNo     OUTPUT,
               @c_ErrMsg   = @cErrMsg     OUTPUT 
               
            IF @nErrNo <> 0    
            BEGIN
               SET @nErrNo = 154211
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WSITF Fail
               GOTO RollBackTran
            END
         END

         SET @cListKey = ''
         SET @cFromID = ''
         SET @cFinalLoc = ''

         SELECT @cListKey = ListKey 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskdetailKey
         AND   StorerKey = @cStorerKey
         AND   TaskType = 'RP1'
         AND   TransitCount = 1
         AND   [Status] = '9'
         
         IF @cListKey <> ''
         BEGIN
            SET @curClearPendingMoveIn = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT FromID, FinalLoc
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
            AND   [Status] = '9'
            AND   TaskType = 'RPF'
            AND   TransitCount = '0'
            AND   PendingMoveIn > 0
            OPEN @curClearPendingMoveIn
            FETCH NEXT FROM @curClearPendingMoveIn INTO @cFromID, @cFinalLoc 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Unlock  suggested location    
               EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
                  ,''      --@cFromLOC    
                  ,@cFromID--@cFromID    
                  ,@cFinalLoc --@cSuggestedLOC    
                  ,''      --@cStorerKey    
                  ,@nErrNo  OUTPUT    
                  ,@cErrMsg OUTPUT    
               IF @nErrNo <> 0    
                  GOTO RollBackTran    
         
               FETCH NEXT FROM @curClearPendingMoveIn INTO @cFromID, @cFinalLoc
            END
         END
         
         COMMIT TRAN rdt_1764ExtUpd12 -- Only commit change made here
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
            @cPickMethod = PickMethod     -- (james01)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey

         IF @cTaskStatus = ''
            GOTO Quit

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd12   

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
                  SET @nErrNo = 154212
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                  GOTO RollBackTran
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
                  SET @nErrNo = 154213
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
         
         COMMIT TRAN rdt_1764ExtUpd12 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd12 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO