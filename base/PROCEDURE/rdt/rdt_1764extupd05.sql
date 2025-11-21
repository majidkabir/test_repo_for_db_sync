SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtUpd05                                          */
/* Purpose: TM Replen From, Extended Update for KR                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-05-30   ChewKP    1.0   WMS-5223 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd05]
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
   
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cSerialNoKey   NVARCHAR( 10)
   DECLARE @cLoseID        NVARCHAR( 1)
          ,@cFromLoc       NVARCHAR( 10) 
          ,@cType          NVARCHAR( 10)
          ,@cVNAMessage    NVARCHAR(MAX)
          ,@cDeviceID      NVARCHAR(10)
          ,@nInputKey      INT
          ,@cFacility      NVARCHAR(5) 
          ,@cWaveKey       NVARCHAR(10) 
          ,@cLocAisle      NVARCHAR(10) 
          ,@cNewTaskDetailKey NVARCHAR(10)
          ,@bSuccess          INT
          ,@cAreaKey          NVARCHAR(10) 
          ,@nPDQty            INT
          ,@cPnDLoc           NVARCHAR(10) 
          ,@cPickDetailKey    NVARCHAR(10)
          ,@cFinalLoc         NVARCHAR(10)
          ,@cPutawayZone      NVARCHAR(10) 
          ,@cLot              NVARCHAR(10) 
          ,@cTaskType         NVARCHAR(10) 
          ,@cListKey          NVARCHAR(10) 
          ,@cLSKU             NVARCHAR(20)
          ,@cLLot             NVARCHAR(10) 
          ,@cLUOM             NVARCHAR(5)
          ,@nLUOMQty          INT
          ,@cLocationCategory NVARCHAR(10)
   
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @nTaskQTY    INT

   DECLARE @curTask     CURSOR

   DECLARE @tTask TABLE  
   (  
      TaskDetailKey NVARCHAR(10)  
   )  
   
          
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_1764ExtUpd05
   
   SET @cType = 'VNA'
   

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      SELECT
            @cSKU = SKU, 
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            --@cFromID = FromID, 
            @cLot    = Lot,
            --@cToID = ToID, 
            @cToLOC = ToLOC, 
            --@cStatus = Status
            @cFinalLoc = FinalLoc,
            @cFromLoc = FromLoc, 
            @cWaveKey = WaveKey,
            @cTaskType = TaskType,
            @cListKey = ListKey 
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskdetailKey = @cTaskdetailKey
      
      SELECT @cFacility = Facility 
            ,@cLocAisle = LocAisle
      FROM dbo.Loc WITH (NOLOCK) 
      WHERE Loc = @cFromLoc 
      
      SELECT @nInputKey = InputKey
            ,@cDeviceID = DeviceID
      FROM rdt.RDTMobRec WITH (NOLOCK) 
      WHERE Mobile = @nMobile
      AND Func = @nFunc 
      
      IF @nStep = 0 -- ToLOC
      BEGIN
         IF ISNULL(@cDeviceID,'')  <> '' 
         BEGIN
            SET @cVNAMessage = 'STXGETPL;'  + @cFromLoc + 'ETX'
            
            EXEC [RDT].[rdt_GenericSendMsg]
                @nMobile      = @nMobile      
               ,@nFunc        = @nFunc        
               ,@cLangCode    = @cLangCode    
               ,@nStep        = @nStep        
               ,@nInputKey    = @nInputKey    
               ,@cFacility    = @cFacility    
               ,@cStorerKey   = @cStorerKey   
               ,@cType        = @cType       
               ,@cDeviceID    = @cDeviceID
               ,@cMessage     = @cVNAMessage     
               ,@nErrNo       = @nErrNo       OUTPUT
               ,@cErrMsg      = @cErrMsg      OUTPUT  
            
            IF @nErrNo <> 0 
               GOTO RollBackTran
            
         END
        
            -- Full pallet single SKU
            --IF @cFromID <> '' AND @cPickMethod = 'FP' AND @cSKU <> ''
            --BEGIN
               -- Serial no
               --IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture = '1')
               --BEGIN
               --   -- Get LOC info
               --   SELECT @cLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
               
               --   -- ID changed
               --   IF @cLoseID = '1' OR @cFromID <> @cToID
               --   BEGIN
               --      -- Lose ID
               --      IF @cLoseID = '1' 
               --         SET @cToID = ''
                     
               --      BEGIN TRAN
               --      SAVE TRAN rdt_1764ExtUpd05

               --      -- Loop serial no on ID
               --      DECLARE @curSNO CURSOR 
               --      SET @curSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               --         SELECT SerialNoKey
               --         FROM dbo.SerialNo WITH (NOLOCK)
               --         WHERE StorerKey = @cStorerKey
               --            AND SKU = @cSKU
               --            AND ID = @cFromID
               --      OPEN @curSNO
               --      FETCH NEXT FROM @curSNO INTO @cSerialNoKey
               --      WHILE @@FETCH_STATUS = 0
               --      BEGIN
               --         -- Update SerialNo ID
               --         UPDATE dbo.SerialNo SET
               --            ID = @cToID,
               --            EditDate = GETDATE(),
               --            EditWho  = SUSER_SNAME(),
               --            Trafficcop = NULL
               --         WHERE SerialNoKey = @cSerialNoKey
               --         IF @@ERROR <> 0
               --         BEGIN
               --            SET @nErrNo = 116052
               --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd SNO Fail
               --            GOTO RollBackTran
               --         END
            
               --         FETCH NEXT FROM @curSNO INTO @cSerialNoKey
               --      END

               --      COMMIT TRAN rdt_1764ExtUpd05 -- Only commit change made here
               --   END
               --END
            --END
          
      END
      
      IF @nStep = 3 
      BEGIN
         IF ISNULL(@cDeviceID,'')  <> '' 
         BEGIN
            SET @cVNAMessage = 'STXPUTPL;'  + @cToLOC + 'ETX'
            
            EXEC [RDT].[rdt_GenericSendMsg]
                @nMobile      = @nMobile      
               ,@nFunc        = @nFunc        
               ,@cLangCode    = @cLangCode    
               ,@nStep        = @nStep        
               ,@nInputKey    = @nInputKey    
               ,@cFacility    = @cFacility    
               ,@cStorerKey   = @cStorerKey   
               ,@cType        = @cType       
               ,@cDeviceID    = @cDeviceID
               ,@cMessage     = @cVNAMessage     
               ,@nErrNo       = @nErrNo       OUTPUT
               ,@cErrMsg      = @cErrMsg      OUTPUT  
            
            IF @nErrNo <> 0 
               GOTO RollBackTran
            
         END
      END
      
      
--      IF @nStep = 6 
--      BEGIN
--         SELECT @cLocationCategory = LocationCategory
--         FROM dbo.Loc WITH (NOLOCK) 
--         WHERE Facility = @cFacility
--         AND Loc = @cToLOC
--         
--
--         IF @cTaskType = 'RP1' OR @cLocationCategory <> 'VNA_IN'
--         BEGIN
--            -- Generete FCP Task for Replen Location
--            SET @cNewTaskDetailKey = ''  
--            SET @bSuccess = 1  
--            EXECUTE dbo.nspg_getkey  
--             'TASKDETAILKEY'  
--             , 10  
--             , @cNewTaskDetailKey OUTPUT  
--             , @bSuccess          OUTPUT  
--             , @nErrNo            OUTPUT  
--             , @cErrMsg           OUTPUT  
--            IF @bSuccess <> 1  
--            BEGIN  
--               SET @nErrNo = 125701  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
--               GOTO RollBackTran  
--            END  
--         
--            SELECT TOP 1 @cAreaKey = A.AreaKey
--            FROM dbo.AreaDetail A WITH (NOLOCK) 
--            INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON P.PutawayZone = A.PutawayZone
--            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
--            WHERE Loc.Facility = @cFacility
--            AND Loc.Loc = @cFromLoc
--         
--            --SELECT @cWaveKey '@cWaveKey' , @cFromLoc '@cFromLoc' , @cSKU '@cSKU'
--
--            SELECT @nPDQty = SUM(Qty)
--            FROM dbo.PickDetail WITH (NOLOCK) 
--            WHERE StorerKey = @cStorerKey
--            AND WaveKey = @cWaveKey
--            AND TaskDetailKey = @cListKey
--            --AND Loc = @cFromLoc 
--            --AND SKU = @cSKU 
--
--            SELECT @cPutawayZone  = PutawayZone
--            FROM dbo.Loc WITH (NOLOCK) 
--            WHERE Loc = @cToLoc
--            AND Facility = @cFacility
--         
--            SELECT Top 1 @cPnDLoc = Loc 
--            FROM dbo.Loc WITH (NOLOCK) 
--            WHERE PutawayZone = @cPutawayZone
--            AND Facility = @cFacility 
--            AND LocationCategory = 'VNA_Out'
--
--
--            IF ISNULL(@cPnDLoc , '') = ''
--            BEGIN
--               SET @nErrNo = 125704
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPnDLoc  
--               GOTO RollBackTran  
--            END
--
--            SELECT @cLSKU = SKU
--                 , @cLLot = Lot
--                 , @cLUOM = UOM
--                 , @nLUOMQty = UOMQty 
--            FROM dbo.TaskDetail WITH (NOLOCK) 
--            WHERE TaskDetailKey = @cListKey 
--         
--         
--            --Hold the Task with Status = 'H'  
--            INSERT INTO dbo.TaskDetail (  
--               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, SKU, Qty,  AreaKey, SystemQty, Lot, UOM , UOMQty, 
--               PickMethod, StorerKey, Message01, Message02, OrderKey, WaveKey, SourceType, GroupKey, Priority, SourcePriority, TrafficCop, SourceKey)  
--            VALUES (  
--               @cNewTaskDetailKey, 'FCP', '0', '', @cToLoc, '', @cPnDLoc, '', @cLSKU, @nPDQty,  ISNULL(@cAreaKey,'') , @nPDQty, @cLLot, @cLUOM, 1,
--               'PP', @cStorerKey, '', '', '', @cWaveKey, 'rdt_1764ExtUpd05', @cWaveKey, '9', '9', NULL, @cWaveKey)  
--           
--          
--            IF @@ERROR <> 0  
--            BEGIN  
--               SET @nErrNo = 125702  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail  
--               GOTO RollBackTran  
--            END  
--         
--            -- Update Pickdetail with new TaskDetailKey 
--            DECLARE @curPickTD CURSOR
--
--            SET @curPickTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--            SELECT PickDetailKey  
--            FROM dbo.PickDetail WITH (NOLOCK) 
--            WHERE StorerKey = @cStorerKey
--            AND WaveKey = @cWaveKey
--            AND TaskDetailKey = @cTaskDetailKey 
--            AND SKU = @cSKU 
--         
--                 
--            OPEN @curPickTD  
--            FETCH NEXT FROM @curPickTD INTO @cPickDetailKey  
--            WHILE @@FETCH_STATUS = 0  
--            BEGIN  
--                 
--               -- Confirm PickDetail  
--               UPDATE PickDetail SET  
--                  TaskDetailKey = @cNewTaskDetailKey,  
--                  --CaseID = @cCartonID,  
--                  EditWho = SUSER_SNAME(),  
--                  EditDate = GETDATE(),  
--                  TrafficCop = NULL   
--               WHERE PickDetailKey = @cPickDetailKey  
--              
--               IF @@ERROR <> 0  
--               BEGIN  
--                  SET @nErrNo = 125703  
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
--                  GOTO RollBackTran  
--               END  
--              
--               FETCH NEXT FROM @curPickTD INTO @cPickDetailKey  
--           
--            END  
--         
--         END
--      END
      
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
                     ,ListKey = ''  
                     ,EditDate = GETDATE()  
                     ,EditWho  = SUSER_SNAME()  
                     ,TrafficCop = NULL  
                  WHERE TaskDetailKey = @cTaskKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 125705  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail  
                  GOTO RollBackTran  
               END  
                 
               -- Generate alert  
               EXEC nspLogAlert  
                    @c_modulename       = 'RPF'  
                  , @c_AlertMessage     = 'UCC SHORT/CANCEL'  
                  , @n_Severity         = '5'  
                  , @b_Success          = @bSuccess      OUTPUT  
                  , @n_err              = @nErrNo        OUTPUT  
                  , @c_errmsg           = @cErrMsg       OUTPUT  
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
--            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
--               SELECT PickDetailKey  
--               FROM dbo.PickDetail WITH (NOLOCK)  
--               WHERE TaskdetailKey IN (SELECT TaskdetailKey FROM @tTask)  
--            OPEN @curPD  
--            FETCH NEXT FROM @curPD INTO @cPickDetailKey  
--            WHILE @@FETCH_STATUS = 0  
--            BEGIN  
--               -- Reset Status  
--               UPDATE dbo.PickDetail SET  
--                   Status = '0'  
--                  ,EditDate = GETDATE()  
--                  ,EditWho  = SUSER_SNAME()  
--                  ,TrafficCop = NULL  
--               WHERE PickDetailKey = @cPickDetailKey  
--               IF @@ERROR <> 0  
--               BEGIN  
--                  SET @nErrNo = 125706  
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
--                  GOTO RollBackTran  
--               END  
--               FETCH NEXT FROM @curPD INTO @cPickDetailKey  
--            END  
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
           
         
      END  
      
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd05 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO