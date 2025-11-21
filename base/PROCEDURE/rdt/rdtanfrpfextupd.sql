SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtANFRPFExtUpd                                     */
/* Purpose: TM Replen From, Extended Update for HK ANF                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-01-28   Ung       1.0   SOS296465 Created                       */
/* 2014-06-20   Ung       1.1   SOS314511 RPF for transfer UCC          */
/* 2015-04-03   Ung       1.2   SOS338161 Quick fix not regen PA task   */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtANFRPFExtUpd]
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
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cUCC        NVARCHAR( 20)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
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
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @cTransitLOC NVARCHAR( 10)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @nTaskQTY    INT
   DECLARE @cPickDetailKey  NVARCHAR( 10)
   DECLARE @cPriority       NVARCHAR( 10)
   DECLARE @cSourcePriority NVARCHAR( 10)
   DECLARE @cSourceKey      NVARCHAR( 30)

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR
   DECLARE @curUCC      CURSOR
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

         SELECT @cFacility = Facility
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE username = @cUserKey

         -- Stamp PickDetail.Status for entire pallet
         IF @cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdtANFRPFExtUpd

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
                  SET @nErrNo = 84801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FoundExtraUCC
                  GOTO RollBackTran
               END

               -- Update PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '3', -- Pick in-progress
                  TrafficCop = NULL,
                  EditDate = GETDATE(),
                  EditWho = 'rdt.' + SUSER_SNAME()
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 84802
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
                  SET @nErrNo = 84803
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey
            END

            COMMIT TRAN rdtANFRPFExtUpd -- Only commit change made here
         END
      END

      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cPickSlipNo     NVARCHAR(10)
         DECLARE @cOrderKey       NVARCHAR(10)
         DECLARE @cLoadKey        NVARCHAR(10)
         DECLARE @cFinalLOCPAZone NVARCHAR(10)
         DECLARE @cFromLOCType    NVARCHAR(10)
         DECLARE @cToLOCCategory  NVARCHAR(10)
         DECLARE @cWaveKey        NVARCHAR(10)
         DECLARE @cOrderStatus    NVARCHAR(10)  
         DECLARE @cMessage02      NVARCHAR(20)
         DECLARE @cNewTaskDetailKey NVARCHAR(10)

         -- Get task info
         SELECT
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            @cFromID = FromID,
            @cUserKey = UserKey,
            @cReasonKey = ReasonKey,
            -- @cDropID = DropID, -- Cancel/SKIP might not have DropID
            @cListKey = ListKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         SELECT @cFacility = Facility
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE UserName = SUSER_SNAME()

         -- Check FP without ID
         IF @cPickMethod = 'FP'
         BEGIN
            IF @cFromID = ''
            BEGIN
               SET @nErrNo = 84804
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               GOTO Quit
            END
            SET @cDropID = @cFromID
         END

         -- Get initial task
         INSERT INTO @tTask (TaskDetailKey)
         SELECT TaskDetailKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
            AND TransitCount = 0

         BEGIN TRAN
         SAVE TRAN rdtANFRPFExtUpd

         -- Loop tasks
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT T.TaskDetailKey, TD.Status, TD.DropID, TD.CaseID, TD.FromLOC, TD.ToLOC, TD.ToID, TD.FinalLOC, TD.FinalID, TD.WaveKey, TD.SourceKey, TD.Priority, TD.SourcePriority, Message02
            FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cDropID, @cCaseID, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID, @cWaveKey, @cSourceKey, @cPriority, @cSourcePriority, @cMessage02
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
                  SET @nErrNo = 84805
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
            END

            -- Completed task
            IF @cStatus = '9'
            BEGIN
               -- For PTS
               IF @cWaveKey <> '' 
               BEGIN
                  -- Get PickDetail info
                  SET @cPickSlipNo = ''
                  SET @cOrderKey = ''
                  SELECT TOP 1
                     @cPickSlipNo = PickSlipNo,
                     @cOrderKey = OrderKey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskKey

                  -- Get Order info
                  SET @cOrderStatus = ''
                  SELECT @cOrderStatus = Status FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                  -- Reset Order.Status due to RDT move alloc QTY internally unalloc then realloc. 
                  -- Upon unalloc, pickdetail possible only left status = 5, hence cause order status updated to 5 and triggers pick confirm interface. 
                  -- So reset order status = 3. Pick confirm interface need to check all pickdetail status = 5 then only process. 
                  IF @cOrderStatus = '5' 
                  BEGIN
                     UPDATE Orders SET 
                        Status = '3', 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME()
                     WHERE OrderKey = @cOrderKey
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 84812 
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Order Fail  
                        GOTO RollBackTran  
                     END
                  END

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
                        SET @nErrNo = 84806
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan-in Fail
                        GOTO RollBackTran
                     END
                  END
   
                  -- Create DropID
                  IF NOT EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cDropID)
                  BEGIN
                     -- Get LoadKey
                     SET @cLoadKey = ''
                     SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   
                     -- Get final LOC's PutawayZone
                     SET @cFinalLOCPAZone = ''
                     SELECT @cFinalLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = CASE WHEN @cFinalLOC = '' THEN @cToLOC ELSE @cFinalLOC END
   
                     -- Insert DropID
                     INSERT INTO DropID (DropID, DropIDType, DropLOC, Status, AdditionalLOC, LoadKey, PickSlipNo)
                     VALUES (@cDropID, 'P', @cToLOC, '9', @cFinalLOCPAZone, @cLoadKey, @cPickSlipNo)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 84807
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS DropIDFail
                        GOTO RollBackTran
                     END
                  END
   
                  -- Get UCC (TaskDetail contain the initial assigned UCC. PickDetail contain the actual UCC, after swap UCC)
                  SELECT TOP 1 @cCaseID = DropID FROM dbo.PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskKey
   
                  -- Create Child ID
                  IF NOT EXISTS( SELECT 1 FROM DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID AND ChildID = @cCaseID)
                  BEGIN
                     INSERT INTO DropIDDetail (DropID, ChildID) VALUES (@cDropID, @cCaseID)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 84808
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS DID Fail
                        GOTO RollBackTran
                     END
                  END
               END

               -- For Non PTS
               IF @cWaveKey = ''
               BEGIN
                  DECLARE @cTransferKey NVARCHAR(10)
                  DECLARE @cTransferLineNo NVARCHAR(5)
                  DECLARE @cUCCLOT NVARCHAR( 10) 
                  DECLARE @cUCCLOC NVARCHAR( 10) 
                  DECLARE @cUCCID  NVARCHAR( 18)
                  DECLARE @cUCCSKU NVARCHAR( 20) 
                  DECLARE @nUCCQTY INT
                           
                  -- Get transfer info
                  SET @cTransferKey = LEFT( @cSourceKey, 10)
                  SET @cTransferLineNo = SUBSTRING( @cSourceKey, 11, 5)

                  -- Get UCC info
                  SET @cUCCLOC = ''
                  SET @cUCCID = ''
                  SELECT 
                     @cUCCLOT = LOT, 
                     @cUCCLOC = LOC, 
                     @cUCCID = ID, 
                     @cUCCSKU = SKU, 
                     @nUCCQTY = QTY
                  FROM UCC WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                     AND UCCNo = @cCaseID
                     
                  -- Get LOC info
                  SELECT @cToLOCCategory = LocationCategory FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
                  SELECT @cFromLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

                  -- Transfer for kitting 
                  -- Only apply for bulk to VAS. DPP to VAS, already finalize by schedule job
                  IF @cToLOCCategory = 'VAS' AND @cFromLOCType <> 'DYNPPICK'
                  BEGIN
                     -- TransferDetail
                     IF EXISTS( SELECT TOP 1 1 
                        FROM TransferDetail WITH (NOLOCK) 
                        WHERE TransferKey = @cTransferKey 
                           AND TransferLineNumber = @cTransferLineNo 
                           AND FromStorerKey = @cStorerKey
                           AND UserDefine01 = @cCaseID
                           AND Status <> '9')
                     BEGIN
                        -- Finalize TransferDetail
                        UPDATE TransferDetail SET
                           Status = '9',
                           FromLOC = @cUCCLOC, 
                           FromID = @cUCCID, 
                           ToLOC = @cUCCLOC, 
                           ToID = @cUCCID, 
                           EditWho = SUSER_SNAME(),
                           EditDate = GETDATE()
                        WHERE TransferKey = @cTransferKey
                           AND TransferLineNumber = @cTransferLineNo
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollBackTran
                        END
                     END

                     -- Generate Kit, if all TransferDetail finalized
                     IF NOT EXISTS( SELECT TOP 1 1 FROM TransferDetail WITH (NOLOCK) WHERE TransferKey = @cTransferKey AND Status <> '9')
                     BEGIN
                        DECLARE @c_PostFinalizeTransferSP NVARCHAR( 30)
                        EXEC nspGetRight  
                              @c_Facility  = NULL 
                            , @c_StorerKey = @cStorerKey
                            , @c_sku       = NULL
                            , @c_ConfigKey = 'PostFinalizeTranferSP'  
                            , @b_Success   = @b_Success                  OUTPUT  
                            , @c_authority = @c_PostFinalizeTransferSP   OUTPUT   
                            , @n_err       = @nErrNo                     OUTPUT   
                            , @c_errmsg    = @cErrMsg                    OUTPUT  
            
                        IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeTransferSP AND TYPE = 'P')
                        BEGIN
                           SET @b_Success = 0  
                           EXECUTE dbo.ispPostFinalizeTransferWrapper 
                                   @c_TransferKey             = @cTransferKey
                                 , @c_PostFinalizeTransferSP  = @c_PostFinalizeTransferSP
                                 , @b_Success = @b_Success     OUTPUT  
                                 , @n_Err     = @nErrNo        OUTPUT   
                                 , @c_ErrMsg  = @cErrMsg       OUTPUT  
                                 , @b_debug   = 0 
                           IF @nErrNo <> 0
                              GOTO RollBackTran
                        END
                     END
                  END

                  -- Generate PA task to DPP (those not for PTS, but use conveyor go to DPP)
                  IF @cToLOCCategory = 'INDUCTION' 
                  BEGIN
                     IF NOT EXISTS( SELECT 1 FROM TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'PA' AND CaseID = @cCaseID)
                     BEGIN
                        -- Get new TaskDetailKeys
                     	SET @b_Success = 1
                     	EXECUTE dbo.nspg_getkey
                     		'TASKDETAILKEY'
                     		, 10
                     		, @cNewTaskDetailKey OUTPUT
                     		, @b_Success         OUTPUT
                     		, @nErrNo            OUTPUT
                     		, @cErrMsg           OUTPUT
                        IF @b_Success <> 1
                        BEGIN
                           SET @nErrNo = 84809
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                           GOTO RollBackTran
                        END
      
                        -- Insert final task
                        INSERT INTO TaskDetail (
                           TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, CaseID, QTY, 
                           StorerKey, SKU, LOT, SourceType, SourceKey, Priority, SourcePriority, TrafficCop)
                        VALUES (
                           @cNewTaskDetailKey, 'PA', '0', '', @cUCCLOC, @cUCCID, LEFT( @cMessage02, 10), '', @cCaseID, @nUCCQTY, 
                           @cStorerKey, @cUCCSKU, @cUCCLOT, 'RPF', @cSourceKey, @cPriority, @cSourcePriority, NULL)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 84810
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                           GOTO RollBackTran
                        END
                     END
                  END

                  -- Normal replenish
                  IF @cToLOCCategory NOT IN ('INDUCTION', 'VAS')
                  BEGIN 
                     -- Check RP1 generated (RPF generate RP1 if only 1 case)
                     IF EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND TaskType = 'RP1')
                     BEGIN
                        -- Delete RP1 
                        DELETE TaskDetail WHERE ListKey = @cListKey AND TaskType = 'RP1'
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollBackTran
                        END
                     END
                     
                     -- Check RPT generated
                     IF NOT EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) WHERE TaskType = 'RPT' AND CaseID = @cCaseID AND SourceKey = @cTaskKey)  
                     BEGIN
                        -- Get new TaskDetailKeys
                     	SET @b_Success = 1
                     	EXECUTE dbo.nspg_getkey
                     		'TASKDETAILKEY'
                     		, 10
                     		, @cNewTaskDetailKey OUTPUT
                     		, @b_Success         OUTPUT
                     		, @nErrNo            OUTPUT
                     		, @cErrMsg           OUTPUT
                        IF @b_Success <> 1
                        BEGIN
                           SET @nErrNo = 84814
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                           GOTO RollBackTran
                        END
                     
                        -- Insert RPT
                        INSERT INTO TaskDetail (
                           TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, CaseID, 
                           PickMethod, StorerKey, SKU, LOT, SourceType, SourceKey, WaveKey, Priority, SourcePriority, TrafficCop)
                        VALUES (
                           @cNewTaskDetailKey, 'RPT', '0', '', @cUCCLOC, @cUCCID, 
                           CASE WHEN @cFinalLOC <> '' THEN @cFinalLOC ELSE @cToLOC END, 
                           CASE WHEN @cFinalID  <> '' THEN @cFinalID  ELSE @cToID  END, 
                           @nUCCQTY, @cCaseID, 
                           'PP', @cStorerKey, @cUCCSKU, @cUCCLOT, 'rdtANFRPFExtUpd', @cTaskKey, @cWaveKey, @cPriority, @cSourcePriority, NULL)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 84815
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                           GOTO RollBackTran
                        END
                     END
                  END
               END

               -- Route each UCC
               IF @cWaveKey = '' -- Non PTS  
               BEGIN  
                  EXEC [dbo].[ispWCSRO01]    
                       @c_StorerKey     =  @cStorerKey    
                     , @c_Facility      =  @cFacility    
                     , @c_ToteNo        =  @cCaseID    
                     , @c_TaskType      =  'RPF'    
                     , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
                     , @c_TaskDetailKey =  @cNewTaskDetailKey     
                     , @c_Username      =  @cUserKey    
                     , @c_RefNo01       =  ''    
                     , @c_RefNo02       =  ''    
                     , @c_RefNo03       =  ''    
                     , @c_RefNo04       =  ''    
                     , @c_RefNo05       =  ''    
                     , @b_debug         =  '0'    
                     , @c_LangCode      =  'ENG'    
                     , @n_Func          =  0    
                     , @b_Success       = @b_Success OUTPUT    
                     , @n_ErrNo         = @nErrNo    OUTPUT    
                     , @c_ErrMsg        = @cErrMSG   OUTPUT    
               END  
               ELSE  
               BEGIN
                  EXEC [dbo].[ispWCSRO01]
                       @c_StorerKey     =  @cStorerKey
                     , @c_Facility      =  @cFacility
                     , @c_ToteNo        =  @cCaseID
                     , @c_TaskType      =  'RPF'
                     , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                     , @c_TaskDetailKey =  @cTaskKey
                     , @c_Username      =  @cUserKey
                     , @c_RefNo01       =  ''
                     , @c_RefNo02       =  ''
                     , @c_RefNo03       =  ''
                     , @c_RefNo04       =  ''
                     , @c_RefNo05       =  ''
                     , @b_debug         =  '0'
                     , @c_LangCode      =  'ENG'
                     , @n_Func          =  0
                     , @b_Success       = @b_Success OUTPUT
                     , @n_ErrNo         = @nErrNo    OUTPUT
                     , @c_ErrMsg        = @cErrMSG   OUTPUT
               END
               IF @nErrNo <> 0
                  GOTO RollBackTran
            END

            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cDropID, @cCaseID, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID, @cWaveKey, @cSourceKey, @cPriority, @cSourcePriority, @cMessage02
         END

         COMMIT TRAN rdtANFRPFExtUpd -- Only commit change made here
      END

      IF @nStep = 9 -- Reason
      BEGIN
         -- Get task info
         SELECT
            @cUserKey    = UserKey,
            @cStatus     = Status,
            @cReasonKey  = ReasonKey,
            @cPickMethod = PickMethod,
            @cRefTaskKey = RefTaskKey,
            @cListKey    = ListKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         SELECT @cFacility = Facility
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE username = @cUserKey

         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey

         IF @cTaskStatus = ''
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
               AND PickMethod = 'FP' -- Task perform at once in nspTTMEvaluateRPFTasks, for FP only

         BEGIN TRAN
         SAVE TRAN rdtANFRPFExtUpd

         -- Loop task
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TD.TaskDetailKey, TD.LOT, TD.FromLOC, TD.FromID, TD.StorerKey, TD.SKU, TD.QTY, TD.CaseID
            FROM @tTask t
               JOIN TaskDetail TD WITH (NOLOCK) ON (t.TaskDetailKey = TD.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cFromLOT, @cFromLOC, @cFromID, @cStorerKey, @cSKU, @nTaskQTY, @cUCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update other tasks
            UPDATE dbo.TaskDetail SET
                Status = @cStatus
               ,UserKey = @cUserKey
               ,ReasonKey = @cReasonKey
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_SNAME()
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @cTaskKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 84811
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
               , @c_Storerkey        = @cStorerKey
               , @c_SKU              = @cSKU
               , @c_UOM              = ''
               , @c_UOMQty           = ''
               , @c_Qty              = @nTaskQTY
               , @c_Lot              = @cFromLOT
               , @c_Loc              = @cFromLOC
               , @c_ID               = @cFromID
               , @c_TaskDetailKey    = @cTaskKey
               , @c_UCCNo            = @cUCC
            
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cFromLOT, @cFromLOC, @cFromID, @cStorerKey, @cSKU, @nTaskQTY, @cUCC
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
               SET @nErrNo = 84813
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         COMMIT TRAN rdtANFRPFExtUpd -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtANFRPFExtUpd -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO