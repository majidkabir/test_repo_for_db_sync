SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtUpd07                                          */
/* Purpose: TM Replen From, Extended Update for                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-07-04   ChewKP    1.0   WMS-5568 Created                              */
/* 2019-06-11   Ung       1.1   WMS-9350 Update PickDetail.DropID             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd07]
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
   
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cUCCNo      NVARCHAR( 20)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @cListKey    NVARCHAR( 10)
   DECLARE @nTaskQTY    INT
   DECLARE @nUCCQTY     INT
   DECLARE @nSystemQTY  INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nQTYAlloc      INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
         , @bSuccess       INT
         , @nInputKey      INT
         , @bDebug         INT
         

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR

   DECLARE @tTask TABLE  
   (  
      TaskDetailKey NVARCHAR(10)  
   )
   
   SET @nTranCount = @@TRANCOUNT
  
   BEGIN TRAN
   SAVE TRAN rdt_1764ExtUpd07
   
   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         -- Get session info
         SELECT 
            @cStorerKey = StorerKey, 
            @cFacility  = Facility 
         FROM rdt.rdtmobrec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 

         -- Get task info  
         SELECT  
            @cTaskType   = TaskType, 
            @cUserKey    = UserKey,  
            @cStatus     = Status,  
            @cReasonKey  = ReasonKey,  
            @cFromID     = FromID,   
            @cToLOC      = ToLOC,   
            @cRefTaskKey = RefTaskKey, 
            @cDropID = DropID, -- Cancel/SKIP might not have DropID
            @cListKey = ListKey -- Cancel/SKIP might not have ListKey (e.g. last carton SKIP)
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            
         -- Call to Sent Web Services
         IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                     WHERE Loc = @cToLoc
                     AND LocationType = 'ROBOTSTG')
         BEGIN
           --SELECT @cDropID '@cDropID' 
           IF @cStatus = '9'
           BEGIN
              -- Call to Sent Web Services
              EXEC  [dbo].[isp_WSITF_GeekPlusRBT_RECEIVING_Outbound]
                   @cStorerKey  
                 , @cFromID 
                 , @cFacility
                 , @bDebug                 
                 , @bSuccess               OUTPUT  
                 , @nErrNo                 OUTPUT  
                 , @cErrMsg                OUTPUT  
               
              IF @bSuccess = 0 
              BEGIN
                   SET @nErrNo = 125901
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WSSendingFail 
                   GOTO RollBackTran
              END
           END
         END
        
         IF @cTaskType = 'RPF'
         BEGIN
            -- Get list key (quick fix)
            IF @cListKey = ''
               SELECT @cListKey = V_String7 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            -- Get initial task
            IF @cListKey <> ''  -- For protection, in case ListKey is blank
               INSERT INTO @tTask (TaskDetailKey)
               SELECT TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE ListKey = @cListKey
                  AND TransitCount = 0

            -- Loop tasks (for B2C orders only)
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT T.TaskDetailKey, TD.Status
               FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
               WHERE TD.Message03 = 'PACKSTATION'
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Completed task
               IF @cStatus = '9'
               BEGIN
                  IF EXISTS( SELECT TOP 1 1 
                     FROM Orders O WITH (NOLOCK)
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE PD.TaskDetailKey = @cTaskKey
                        AND PD.Status <> '4'
                        AND PD.QTY > 0
                        AND O.DocType = 'E')
                  BEGIN
                     -- Loop PickDetail
                     SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PD.PickDetailKey
                        FROM Orders O WITH (NOLOCK)
                           JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                        WHERE PD.TaskDetailKey = @cTaskKey
                           AND PD.Status <> '4'
                           AND PD.QTY > 0
                           AND O.DocType = 'E'
                     OPEN @curPD
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- Update PickDetail
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                           Status = '3', 
                           DropID = @cDropID, 
                           EditDate = GETDATE(),
                           EditWho = 'rdt.' + SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 125904
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                           GOTO RollBackTran
                        END

                        FETCH NEXT FROM @curPD INTO @cPickDetailKey
                     END
                  END
               END
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
            END
         END
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
            --DECLARE @cFinalLOC      NVARCHAR( 10)  
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
                     ,DropID = ''  
                     ,ListKey = ''  
                     ,EditDate = GETDATE()  
                     ,EditWho  = SUSER_SNAME()  
                     ,TrafficCop = NULL  
                  WHERE TaskDetailKey = @cTaskKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 125902  
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
                  ,TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 125903  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
               FETCH NEXT FROM @curPD INTO @cPickDetailKey  
            END  
         END  
  
         IF @cPickMethod = 'FP'  
         BEGIN  
            -- Get session info
            SELECT @cStorerKey = StorerKey FROM rdt.rdtmobrec WITH (NOLOCK) WHERE Mobile = @nMobile 

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
           
         
      END  
   END  
   

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd07 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO