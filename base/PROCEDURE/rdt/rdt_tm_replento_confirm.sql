SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_TM_ReplenTo_Confirm                                   */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Modifications log:                                                         */  
/* Date        Rev  Author   Purposes                                         */  
/* 24-08-2016  1.0  Ung      WMS-5740 Created                                 */  
/* 21-08-2020  1.1  James    WMS-14152 Reduce pendingmovein qty for tasktype  */
/*                           ASTRP1 (james01)                                 */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_ReplenTo_Confirm] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cTaskDetailKey NVARCHAR( 10),  
   @cToLOC         NVARCHAR( 10),   
   @cUCCNo         NVARCHAR( 20),   
   @nQTY           INT,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @bSuccess          INT  
   DECLARE @nTrancount        INT  
   DECLARE @cUserName         NVARCHAR(15)  
   DECLARE @cMoveQTYAlloc     NVARCHAR(1)  
  
   DECLARE @cFromLOC          NVARCHAR(10)  
   DECLARE @cFromID           NVARCHAR(18)  
   DECLARE @cLOT              NVARCHAR(10)  
   DECLARE @cSKU              NVARCHAR(20)  
   DECLARE @cToID             NVARCHAR(18)  
   DECLARE @cOrgTaskDetailKey NVARCHAR(10)  
   DECLARE @nTaskQTY          INT  
  
   SET @nTranCount = @@TRANCOUNT  
  
   -- Storer configure  
   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)  
  
   -- Get task info  
   SELECT  
      @cFromLOC = FromLOC,   
      @cFromID = FromID,   
      @cSKU = SKU,   
      @cLOT = LOT,   
      @nTaskQTY = QTY,   
      @cToID = ToID,   
      @cOrgTaskDetailKey = SourceKey -- RPF task / own task (if splitted)  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
  
   BEGIN TRAN  
   SAVE TRAN rdt_TM_ReplenTo_Confirm  
  
   /***********************************************************************************************  
                       Partial replen (split TaskDetail, PickDetail, PendingMoveIn)  
   ***********************************************************************************************/  
   -- Partial replen   
   IF @nQTY < @nTaskQTY   
   BEGIN  
      /*------------------------------------ Split TaskDetail -----------------------------------*/  
      DECLARE @cPickDetailKey    NVARCHAR( 10)  
      DECLARE @cNewTaskDetailKey NVARCHAR( 10)  
      DECLARE @nQTY_PD           INT  
      DECLARE @nQTY_Bal          INT  
      DECLARE @nQTYAlloc         INT  
  
      -- Get new TaskDetailKey  
      SET @bSuccess = 1  
      EXECUTE dbo.nspg_getkey  
         'TaskDetailKey'  
         , 10  
         , @cNewTaskDetailKey OUTPUT  
         , @bSuccess  OUTPUT  
         , @nErrNo    OUTPUT  
         , @cErrMsg   OUTPUT  
      IF @bSuccess <> 1  
      BEGIN  
         SET @nErrNo = 128201  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
         GOTO RollBackTran  
      END  
           
      -- Insert TaskDetail to carry the balance  
      INSERT INTO TaskDetail (  
         TaskDetailKey, RefTaskKey, QTY, SourceKey,   
         TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, ToLOC, LogicalToLOC, ToID, CaseID, PickMethod, Status, StatusMsg, Priority, SourcePriority, HoldKey, UserKey, UserPosition, UserKeyOverRide, SourceType, PickDetailKey, 
         OrderKey, OrderLineNumber, ListKey, WaveKey, ReasonKey, Message01, Message02, Message03, SystemQTY, LoadKey, AreaKey, DropID, GroupKey)  
      SELECT  
         @cNewTaskDetailKey, @cTaskDetailKey, QTY - @nQTY, @cNewTaskDetailKey,   
         TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, ToLOC, LogicalToLOC, ToID, CaseID, PickMethod, Status, StatusMsg, Priority, SourcePriority, HoldKey, UserKey, UserPosition, UserKeyOverRide, SourceType, PickDetailKey, 
         OrderKey, OrderLineNumber, ListKey, WaveKey, ReasonKey, Message01, Message02, Message03, SystemQTY, LoadKey, AreaKey, DropID, GroupKey  
      FROM TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskDetailKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 128202  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskdetFail  
         GOTO RollBackTran  
      END  
  
      /*------------------------------------ Split PickDetail -----------------------------------*/  
      IF @cMoveQTYAlloc  = '1'  
      BEGIN  
         -- Get from PickDetail  
         SELECT @nQTYAlloc = ISNULL( SUM( QTY), 0)  
         FROM PickDetail WITH (NOLOCK)  
         WHERE TaskDetailKey = @cOrgTaskDetailKey  
            AND Status <> '4'  
           
         IF @nQTYAlloc > 0 AND  -- PickDetail exist  
            @nQTYAlloc > @nQTY  -- Some PickDetail fall under new task  
         BEGIN  
            -- Calc PD QTY for new task  
            SET @nQTY_Bal = @nQTYAlloc - @nQTY  
              
            -- Loop PickDetail for original task    
            DECLARE @curPD CURSOR    
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT PD.PickDetailKey, PD.QTY  
               FROM dbo.PickDetail PD WITH (NOLOCK)    
               WHERE PD.TaskDetailKey = @cOrgTaskDetailKey    
                  AND PD.QTY > 0    
                  AND PD.Status <> '4'    
            OPEN @curPD    
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               -- PickDetail have less or exact match    
               IF @nQTY_PD <= @nQTY_Bal    
               BEGIN    
                  -- Confirm PickDetail  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                     TaskDetailKey = @cNewTaskDetailKey,      
                     EditWho  = SUSER_SNAME(),     
                     EditDate = GETDATE(),    
                     Trafficcop = NULL    
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 128203    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                     GOTO RollBackTran    
                  END  
  
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD  
               END  
                
               -- PickDetail have more, need to split    
               ELSE IF @nQTY_PD > @nQTY_Bal    
               BEGIN    
                  -- Get new PickDetailkey    
                  DECLARE @cNewPickDetailKey NVARCHAR( 10)    
                  EXECUTE dbo.nspg_GetKey    
                     'PICKDETAILKEY',    
                     10 ,    
                     @cNewPickDetailKey OUTPUT,    
                     @bSuccess          OUTPUT,    
                     @nErrNo            OUTPUT,    
                     @cErrMsg           OUTPUT    
                  IF @bSuccess <> 1    
                  BEGIN    
                     SET @nErrNo = 128204    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail    
                     GOTO RollBackTran    
                  END    
             
                  -- Create a new PickDetail to hold the balance    
                  INSERT INTO dbo.PickDetail (    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,    
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,     
                     PickDetailKey,    
                     Status,     
                     QTY,    
                     TrafficCop,    
                     OptimizeCop)    
                  SELECT    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,    
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,     
                     @cNewPickDetailKey,   
                     Status,     
                     @nQTY_PD - @nQTY_Bal, -- QTY    
                     NULL, --TrafficCop    
                     '1'   --OptimizeCop    
                  FROM dbo.PickDetail WITH (NOLOCK)    
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 128205    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail    
                     GOTO RollBackTran    
                  END    
             
                  -- Change original PickDetail with exact QTY (with TrafficCop)    
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                     QTY = @nQTY_Bal,    
                     TaskDetailKey = @cNewTaskDetailKey,  
                     EditWho  = SUSER_SNAME(),     
                     EditDate = GETDATE(),    
                     Trafficcop = NULL    
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 128206    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                     GOTO RollBackTran    
                  END    
                    
                  SET @nQTY_Bal = 0  
               END    
                
               IF @nQTY_Bal = 0    
                  BREAK   
                   
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD   
            END    
         END  
      END  
  
      /*------------------------------------ Split PendingMoveIn -----------------------------------*/  
      DECLARE @nRowRef INT  
      DECLARE @nNewRowRef INT  
      DECLARE @nPendingMoveIn INT  
        
      -- Get booking  
      SET @nPendingMoveIn = 0  
      SELECT   
         @nRowRef = RowRef,   
         @nPendingMoveIn = QTY  
      FROM RFPutaway WITH (NOLOCK)  
      WHERE TaskDetailKey = @cOrgTaskDetailKey  
        
      IF @nPendingMoveIn > 0 AND  -- PendingMoveIn exist  
         @nPendingMoveIn > @nQTY  -- Some PendingMoveIn fall under new task  
      BEGIN  
         -- Calc PendingMoveIn for new task  
         SET @nQTY_Bal = @nPendingMoveIn - @nQTY  
           
         -- Insert new booking to carry the balance  
         INSERT INTO dbo.RFPutaway (  
            Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, CaseID, TaskDetailKey, Func, PABookingKey, QTY)  
         SELECT   
            Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, CaseID, TaskDetailKey, Func, PABookingKey, QTY - @nQTY_Bal  
         FROM RFPutaway WITH (NOLOCK)  
         WHERE TaskDetailKey = @cOrgTaskDetailKey  
         SET @nNewRowRef = SCOPE_IDENTITY()  
           
         -- Change original booking with exact QTY  
         UPDATE RFPutaway SET  
            QTY = @nQTY_Bal,   
            TaskDetailKey = @cNewTaskDetailKey  
         WHERE RowRef = @nRowRef   
         IF @@ERROR <> 0  
            GOTO RollBackTran  
      END  
   END  
     
   /***********************************************************************************************  
                                             Confirm replen  
   ***********************************************************************************************/  
   -- Calc QTYAlloc  
   IF @cMoveQTYAlloc = '1'  
   BEGIN  
      -- Get from PickDetail  
      SELECT @nQTYAlloc = ISNULL( SUM( QTY), 0)  
      FROM PickDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cOrgTaskDetailKey  
         AND Status <> '4'  
   END  
   ELSE  
      SET @nQTYAlloc = 0  
  
   SET @cUserName = SUSER_SNAME()  
  
   -- Move inventory  
   IF @cUCCNo <> ''  
   BEGIN  
      -- Move by UCC  
      EXECUTE rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT,  
         @cSourceType = 'rdt_TM_ReplenTo_Confirm',  
         @cStorerKey  = @cStorerKey,  
         @cFacility   = @cFacility,  
         @cFromLOC    = @cFromLOC,  
         @cToLOC      = @cToLOC,  
         @cFromID     = @cFromID,  
         @cToID       = @cToID,  
         @cUCC        = @cUCCNo,  
         @nQTYAlloc   = @nQTYAlloc,  
         @nFunc       = @nFunc,  
         @cDropID     = @cUCCNo  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType    = '5', -- Replenish  
         @cUserID        = @cUserName,  
         @nMobileNo      = @nMobile,  
         @nFunctionID    = @nFunc,  
         @cFacility      = @cFacility,  
         @cStorerKey     = @cStorerKey,  
         @cLocation      = @cFromLOC,  
         @cToLocation    = @cToLOC,  
         @cID            = @cFromID,  
         @cToID          = @cToID,  
         @cRefNo1        = @cUCCNo,  
         @cTaskDetailKey = @cTaskDetailKey  
   END  
   ELSE  
   BEGIN  
      -- Move by SKU  
      EXECUTE rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT,  
         @cSourceType = 'rdt_TM_ReplenTo_Confirm',  
         @cStorerKey  = @cStorerKey,  
         @cFacility   = @cFacility,  
         @cFromLOC    = @cFromLOC,  
         @cToLOC      = @cToLOC,  
         @cFromID     = @cFromID,  
         @cToID       = @cToID,  
         @cSKU        = @cSKU,  
         @nQTY        = @nQTY,  
         @nQTYAlloc   = @nQTYAlloc,  
         @cFromLOT    = @cLOT,  
         @nFunc       = @nFunc,  
         @cTaskDetailKey = @cOrgTaskDetailKey  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType    = '5', -- Replenish  
         @cUserID        = @cUserName,  
         @nMobileNo      = @nMobile,  
         @nFunctionID    = @nFunc,  
         @cFacility      = @cFacility,  
         @cStorerKey     = @cStorerKey,  
         @cLocation      = @cFromLOC,  
         @cToLocation    = @cToLOC,  
         @cID            = @cFromID,  
         @cToID          = @cToID,  
         @cSKU           = @cSKU,  
         @nQTY           = @nQTY,  
         @cLOT           = @cLOT,  
         @cTaskDetailKey = @cTaskDetailKey  
   END  
  
   -- Cancel booking  
   IF EXISTS( SELECT 1 FROM RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cOrgTaskDetailKey)  
   BEGIN  
      -- Unlock by RPF task  
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
         ,'' --FromLOC  
         ,'' --FromID  
         ,'' --cSuggLOC  
         ,'' --Storer  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
         ,@cTaskDetailKey = @cOrgTaskDetailKey  
   END  
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cOrgTaskDetailKey AND TaskType = 'ASTRP1' AND [Status] = '9')
      BEGIN
         UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET 
            PendingMoveIn = CASE WHEN PendingMoveIn - @nTaskQTY >= 0 THEN PendingMoveIn - @nTaskQTY ELSE 0 END
         WHERE Lot = @cLOT
            AND Loc = @cFromLOC
            AND ID  = @cFromID
      END
   END
     
   -- Update Task  
   UPDATE dbo.TaskDetail SET  
      Status = '9',   
      QTY = @nQTY,   
      ToLOC = @cToLOC,   
      EditDate = GETDATE(),   
      EditWho  = SUSER_SNAME(),       
      TrafficCop = NULL    
   WHERE TaskDetailKey = @cTaskDetailKey    
   IF @@ERROR <> 0    
   BEGIN    
      SET @nErrNo = 128207    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail  
      GOTO RollBackTran    
   END   
  
   COMMIT TRAN rdt_TM_ReplenTo_Confirm    
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_TM_ReplenTo_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_TM_ReplenTo_Confirm  
END  

GO