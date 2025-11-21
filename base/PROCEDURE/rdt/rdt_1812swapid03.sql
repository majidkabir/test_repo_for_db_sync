SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1812SwapID03                                    */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Swap ID base on same LOC,SKU                                */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 19-03-2020  1.0  YeeKung     WMS-12082 Created                       */  
/************************************************************************/  
CREATE PROCEDURE [RDT].[rdt_1812SwapID03]  
   @nMobile           INT,  
   @nFunc             INT,  
   @cLangCode         NVARCHAR( 3),  
   @cTaskDetailKey    NVARCHAR( 10),  
   @cNewID            NVARCHAR( 18),  
   @cNewTaskDetailKey NVARCHAR( 10) OUTPUT,  
   @nErrNo            INT           OUTPUT,  
   @cErrMsg           NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount      INT    
    
   DECLARE @cOtherPickDetailKey NVARCHAR(10)    
   DECLARE @cFCPTaskDetailKey NVARCHAR(10)      
   DECLARE @cFPKTaskDetailKey NVARCHAR(10)    
       
   DECLARE @cNewSKU        NVARCHAR( 20)    
   DECLARE @cNewLOT        NVARCHAR( 10)    
   DECLARE @cNewLOC        NVARCHAR( 10)    
   DECLARE @nNewQTY        INT    
    
   DECLARE @cPickDetailKey NVARCHAR(10)    
   DECLARE @cStorerKey     NVARCHAR( 15)    
   DECLARE @cTaskKey       NVARCHAR( 10)    
   DECLARE @cTaskType      NVARCHAR( 10)    
   DECLARE @cTaskSKU       NVARCHAR( 20)    
   DECLARE @cTaskLOT       NVARCHAR( 10)    
   DECLARE @cTaskLOC       NVARCHAR( 10)    
   DECLARE @cTaskID        NVARCHAR( 18)    
   DECLARE @nTaskQTY       INT    
   DECLARE @nQTY           INT    
   DECLARE @nTaskDropID    NVARCHAR( 20)   
   DECLARE @cUnallocQty      NVARCHAR( 1)  
   DECLARE @c_newpickdetailkey NVARCHAR(10)   
   DECLARE @c_taskdetailkey  NVARCHAR(20)  
   DECLARE @b_success INT  
   DECLARE @n_err INT    
   DECLARE @c_errmsg NVARCHAR(20)  
   DECLARE @cRemainQty INT  
  
   DECLARE @cNewAllID        NVARCHAR( 20)    
   DECLARE @cNewAllLOT        NVARCHAR( 10)    
   DECLARE @cNewAllLOC        NVARCHAR( 10)    
   DECLARE @nNewAllQTY        INT  
   DECLARE @cFPKQTY           INT    
   DECLARE @cFCPQTY           INT    
   DECLARE @nUOM              NVARCHAR(2)  
  
   DECLARE @tPD table  
   (  
      pickdetailkey NVARCHAR(20),  
      taskdetailkey NVARCHAR(20),  
      QTY INT  
   )  
  
   DECLARE @tTD table  
   (   
      taskdetailkey NVARCHAR(20),  
      TaskType    NVARCHAR(5)  
   )  
  
   -- Check blank  
   IF @cNewID = ''  
   BEGIN  
      SET @nErrNo = 148701   
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID  
      RETURN  
   END  
  
   -- Get task info    
   SELECT    
      @cStorerKey = StorerKey,     
      @cTaskType = TaskType,     
      @cTaskSKU = SKU,     
      @cTaskLOT = LOT,    
      @cTaskLOC = FromLOC,    
      @cTaskID = FromID,     
      @nTaskQTY = SystemQTY,  
      @nTaskDropID=Dropid   
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
   IF @@ROWCOUNT = 0    
   BEGIN    
      SET @nErrNo = 148702    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey    
      RETURN    
   END  
  
   INSERT INTO @tTD(taskdetailkey,TaskType)  
   VALUES(@cTaskDetailKey,'')  
  
   -- Get new ID info  
   SELECT  
      @cNewSKU = SKU,  
      @nNewQTY = QTY-QTYPicked,  
      @cNewLOT = LOT,  
      @cNewLOC = LOC  
   FROM dbo.LOTxLOCxID WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND ID = @cNewID  
      AND QTY-QTYPicked > 0  
     
   SET @nRowCount = @@ROWCOUNT   
  
   -- Check ID valid  
   IF @nRowCount = 0  
   BEGIN  
      SET @nErrNo = 148703  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID  
   RETURN  
   END  
  
   -- Check ID multi LOC/LOT  
   IF @nRowCount > 1  
   BEGIN  
      SET @nErrNo = 148704  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec  
      RETURN  
   END  
  
   -- Check LOC match  
   IF @cNewLOC <> @cTaskLOC  
   BEGIN  
      SET @nErrNo = 148705  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match  
      RETURN  
   END  
  
   -- Check SKU match  
   IF @cNewSKU <> @cTaskSKU  
   BEGIN  
      SET @nErrNo = 148706  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match  
      RETURN  
   END  
  
   -- Check task taken by other  
   IF EXISTS( SELECT TOP 1 1  
      FROM TaskDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND TaskType = @cTaskType  
         AND FromID = @cNewID  
         AND Status NOT IN ('0','9'))AND @nNewQTY =0  
   BEGIN  
      SET @nErrNo = 148708  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID task taken  
      RETURN  
   END  
  
    IF EXISTS( SELECT TOP 1 1  
      FROM TaskDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND TaskType IN ('FPK','FPK1')  
         AND FromID = @cNewID  
         AND SKU =@cNewSKU  
         AND QTY <4 )  
   BEGIN  
      SET @nErrNo = 148736  
      SET @cErrMsg =@cNewID-- rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID task taken  
      RETURN   
   END  
  
  
   /*--------------------------------------------------------------------------------------------------  
  
                                                Swap ID  
  
   --------------------------------------------------------------------------------------------------*/  
   /*  
      Scenario:  
      1. Pallet ID that not allocate on any task  
      2. Pallet ID that only allocate to the task which only Case Pick  
      3. Pallet ID that allocate to task (FPK)   
         Provided that does not have any partial pallet id in the location (If that is partial pallet exists in the location,  
         but operator scan full pallet id , the system   
         will prompt error)  
         Provided that does not  enough full pallet for FPK task (ie. If that the loc had three full pallet   
         , two full pallet is assign to FPK task, operation allows to   
         do swap ID)  
   */  
  
  
   /* Check the new id qty is less than original qty  
      If the new id qty is less than original qty, will create a new line for pickdetail and taskdetail  
      This only apply to teh id which not allocated or allocated to tasktype FCP  
   */  
   IF (@nNewQTY < @nTaskQTY)  
   BEGIN  
      SET @cUnallocQty ='1'  
      SET @cRemainQty =@nNewQTY  
   END  
  
  
   /* Scenario 1 */  
   -- Get FCP task info  
   INSERT INTO @tTD(taskdetailkey,TaskType)  
   SELECT TaskDetailKey,'FCP'  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND TaskType = @cTaskType  
      AND SKU = @cNewSKU  
      AND FromID = @cNewID  
      AND Status = '0'  
  
   SELECT @cFCPQTY=sum(QTY)  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND TaskType = @cTaskType  
      AND SKU = @cNewSKU  
      AND FromID = @cNewID  
      AND Status = '0'  
  
   -- Get other PickDetail info  
   SET @cOtherPickDetailKey = ''  
   SELECT @cOtherPickDetailKey = PickDetailKey  
   FROM PickDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cNewSKU  
      AND ID = @cNewID  
      AND Status = '0'  
      AND QTY > 0  
  
   -- Get FPK task info  
   INSERT INTO @tTD(taskdetailkey,TaskType)  
   SELECT @cFPKTaskDetailKey,'FPK'  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND TaskType in ('FPK','FPK1')  
      AND SKU = @cNewSKU  
      AND FromID = @cNewID  
      AND Status = '0'  
  
   /* Get the new id and lot for swapping for the task especially tasktype FPK and FCP*/  
   SELECT TOP 1   
      @cNewAllID = ID,  
      @nNewAllQTY = QTY,  
      @cNewAllLOT = LOT,  
      @cNewAllLOC = LOC  
   FROM dbo.LOTxLOCxID WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cNewSKU  
      AND LOC = @cNewLOC  
      AND QtyAllocated=0  
      AND QTY>=case when isnuLL(@cFCPQTY,'') = '' then QTY ELSE '3' END  
      AND QTY>= case when isnull(@cFPKQTY,'') = '' then QTY ELSE @cFPKQTY END  
      ORDER BY QTY  
  
   /* Apply to Drum loc only*/  
   IF EXISTS ( SELECT 1 FROM LOTXLOCXID WITH (NOLOCK)   
      WHERE LOC = @cTaskLOC  
         AND SKU = @cTaskSKU  
         AND QTY-QTYPicked <4  
         AND QTY-QTYPicked<>0  
         AND QTY <>0  
         AND (ID not in (select fromid FROM taskdetail (nolock)   
                        WHERE qty<4   
                           AND fromloc=@cTaskLOC   
                           AND sku=@cTaskSKU   
                           AND tasktype IN ('FPK','FPK1')) OR  ID not in(@cNewID)))  
          AND EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC=@cTaskLOC AND LocationCategory='BULK')  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM LOTXLOCXID LLI WITH (NOLOCK)   
         WHERE LOC = @cTaskLOC  
            AND SKU = @cTaskSKU  
            AND QTY-QTYPicked =4  
            AND QTY <>0  
            AND ID = (@cNewID))   
      BEGIN   
         SET @nErrNo = 148715  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickCasefirst  
         RETURN  
      END  
   END  
  
   INSERT INTO @tPD (pickdetailkey,taskdetailkey,qty)  
   SELECT PD.PickDetailKey,pd.taskdetailkey,pd.qty  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      WHERE PD.TaskDetailKey IN (SELECT taskdetailkey FROM @tTD WHERE ISNULL(taskdetailkey,'')<>'')  
         AND PD.Status = '0'  
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1812SwapID03  
  
   /*1. ID is not allocated in lotxlocxid   
  
      2 Scenario  
      1. If the task qty is same as new id qty or task qty is less than new id qty do nothing  
      2. If the task qty is less than new id qty create a new line pickdetail and taskdetail  for remaining qty  
   */  
   IF @cOtherPickDetailKey = ''  
   BEGIN  
  
      UPDATE PickDetail WITH (ROWLOCK)  
      SET QTY=0  
      WHERE TaskDetailKey = @cTaskDetailKey  
         AND Status = '0'  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 148737  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
         GOTO RollBackTran  
      END  
  
       -- Loop PickDetail  
      DECLARE @curPD CURSOR  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT pickdetailkey,qty  
         FROM @tPD  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF @cUnallocQty = '1'  
         BEGIN  
  
            -- Update current task PickDetail  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET  
               LOT = @cNewLOT,   
               ID = @cNewID,  
               Qty = CASE WHEN @cRemainQty <=0 THEN 0 WHEN @cRemainQty>@nQTY THEN @nQTY ELSE @cRemainQty END,   
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 148720  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
            GOTO RollBackTran  
            END  
  
            SET @cRemainQty = @cRemainQty-@nQTY   
  
         END  
         ELSE  
         BEGIN  
            -- Update current task PickDetail  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET  
               LOT = @cNewLOT,   
               ID = @cNewID,   
               QTY= @nQTY,  
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
             IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 148720  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
               GOTO RollBackTran  
            END  
         END  
           
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      END  
      --Create new line  
      IF(@cUnallocQty = '1')   
      BEGIN  
  
          EXECUTE nspg_GetKey    
            'PICKDETAILKEY',    
            10,    
            @c_newpickdetailkey OUTPUT,    
            @b_success OUTPUT,    
            @n_err OUTPUT,    
            @c_errmsg OUTPUT    
  
            IF @n_err <> 0  
            BEGIN  
               SET @nErrNo = 148721  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPDKeyFail  
               GOTO RollBackTran  
            END  
              
  
          INSERT PICKDETAIL    
         (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,    
            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,    
            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,    
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,    
            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo     
         , TaskDetailKey                                                
                  )    
         SELECT @c_newpickdetailkey  , CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @cTaskLOT,    
                  Storerkey, Sku, AltSku, UOM,UOMQty,@nTaskQty-@nNewQTY, 0, 0,    
                  DropId,Loc, @cTaskID, PackKey, UpdateSource, CartonGroup, CartonType,    
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,    
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo    
               , TaskDetailKey                                                 
         FROM PICKDETAIL (NOLOCK)    
         WHERE PickdetailKey = @cPickDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148722  
            SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPDFail  
            GOTO RollBackTran  
         END  
         -- Update current task  
         UPDATE TaskDetail WITH (ROWLOCK)  
         SET  
            LOT = @cNewLOT,   
            FromID = @cNewID,   
            ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,   
            QTY = @nNewQty,  
            SystemQty=@nNewQty,  
            DropID = @nTaskDropID,  
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148724  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTDFail  
            GOTO RollBackTran  
         END  
  
         EXECUTE nspg_getkey      
         "TaskDetailKey"      
         , 10      
         , @c_taskdetailkey OUTPUT      
         , @b_success OUTPUT      
         , @n_err OUTPUT      
         , @c_errmsg OUTPUT      
                   
         IF @b_success <> 1      
         BEGIN      
            SET @nErrNo = 148725  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetTDKeyFail  
            GOTO RollBackTran     
         END    
  
          INSERT TASKDETAIL      
          (      
            TaskDetailKey ,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc     
           ,FromID,ToLoc,LogicalToLoc,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority     
           ,Holdkey,UserKey,UserPosition,UserKeyOverRide,StartTime,EndTime            
           ,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber    
           ,ListKey,WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,SystemQty,RefTaskKey,LoadKey ,AreaKey,DropID ,TransitCount ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,QtyReplen ,PendingMoveIn            
          )      
         SELECT   
          @c_taskdetailkey ,TaskType,Storerkey,Sku,@cTaskLOT,UOM,UOMQty,@nTaskQTY-@nNewQty,FromLoc,LogicalFromLoc     
           ,@cTaskID,ToLoc,LogicalToLoc,'',Caseid,PickMethod,0,StatusMsg,Priority,SourcePriority     
           ,'','','1','',getdate(),getdate()           
           ,SourceType,SourceKey,'',OrderKey,OrderLineNumber    
           ,'',WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,@nTaskQTY-@nNewQty,RefTaskKey,LoadKey ,AreaKey,DropID ,TransitCount ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,0 ,PendingMoveIn          
         FROM TASKDETAIL (NOLOCK)  
         WHERE TASKDetailKEY=@cTaskDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148726  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTDFail  
            GOTO RollBackTran  
         END  
           
         UPDATE PICKDETAIL WITH (ROWLOCK)  
         SET taskdetailkey=@c_taskdetailkey  
         WHERE pickdetailkey=@c_newpickdetailkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148709  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
            GOTO RollBackTran  
         END  
  
         DELETE PICKDETAIL WHERE qty=0 AND ID=@cTaskID AND taskdetailkey=@cTaskDetailKey AND LOC=@cTaskLOC  
      END  
      ELSE  
      BEGIN  
         -- Update current task  
         UPDATE TaskDetail WITH (ROWLOCK)  
         SET  
            LOT = @cNewLOT,   
            FromID = @cNewID,   
            ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,   
            DropID = @nTaskDropID,  
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148709  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
            GOTO RollBackTran  
         END  
      END  
      GOTO CommitTran  
   END  
     
   /*1. ID is allocated in lotxlocxid which tasktype =FCP  
  
      2 Scenario  
      1. If the task qty is same as new id qty or task qty is less than new id qty do nothing  
      2. If the task qty is less than new id qty create a new line pickdetail and taskdetail  for remaining qty  
   */  
   IF EXISTS (SELECT 1 FROM @tTD WHERE TaskType in ('FCP') and ISNULL(taskdetailkey,'')<>'') AND @cOtherPickDetailKey <> ''  
   BEGIN  
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET QTY=0  
      where pickdetailkey IN (SELECT pickdetailkey FROM @tPD) 
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 148738  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
         GOTO RollBackTran  
      END   
        
      -- Loop PickDetail  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT pickdetailkey,QTY  
        FROM @tPD  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF (@cPickDetailKey in (SELECT pickdetailkey from @tPD   
                                 where taskdetailkey in(select taskdetailkey   
                                                        FROM @tTD  
                                                        WHERE TaskType='FCP'  
                                                        AND ISNULL(taskdetailkey,'')<>'')))  
         BEGIN  
            -- Update other task PickDetail  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET  
               LOT = @cNewAllLot,   
               ID = @cNewAllID,  
               QTY = @nQTY  
            WHERE PickDetailKey = @cPickDetailKey  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 148739  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
               GOTO RollBackTran  
            END   
         END  
         ELSE  
         BEGIN  
            IF @cUnallocQty = '1'  
            BEGIN   
  
               -- Update current task PickDetail  
               UPDATE PickDetail WITH (ROWLOCK)  
               SET  
                  LOT = @cNewLOT,   
                  ID = @cNewID,  
                  Qty = CASE WHEN @cRemainQty <=0 THEN 0 WHEN @cRemainQty>@nQTY THEN @nQTY ELSE @cRemainQty END,   
                  EditDate = GETDATE(),   
                  EditWho = 'rdt.' + SUSER_SNAME(),   
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 148729  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
                  GOTO RollBackTran  
               END  
  
               SET @cRemainQty = @nQTY-@cRemainQty   
            END  
            ELSE  
            BEGIN  
  
               -- Update current task PickDetail  
               UPDATE PickDetail WITH (ROWLOCK)  
               SET  
                  LOT = @cNewLOT,   
                  ID = @cNewID,  
                  QTY =@nQTY,  
                  EditDate = GETDATE(),   
                  EditWho = 'rdt.' + SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 148740  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
                  GOTO RollBackTran  
               END  
  
               SET @nNewQTY = @nNewQTY - @nQTY  
  
            END  
         END  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      END  
        
      -- Update other task  
      UPDATE TaskDetail WITH (ROWLOCK)  
      SET  
         LOT = @cNewAllLot,   
         FromID = @cNewAllID,   
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey IN (SELECT taskdetailkey FROM @tTD WHERE TaskType='FCP' AND ISNULL(taskdetailkey,'')<>'')  
         AND Status = '0'  
  
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 148712  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
  
      IF(@cUnallocQty = '1')  
      BEGIN  
         EXECUTE nspg_GetKey    
         'PICKDETAILKEY',    
         10,    
         @c_newpickdetailkey OUTPUT,    
         @b_success OUTPUT,    
         @n_err OUTPUT,    
         @c_errmsg OUTPUT    
  
         IF @n_err <> 0  
         BEGIN  
            SET @nErrNo = 148730  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPDKeyFail  
            GOTO RollBackTran  
         END  
              
          INSERT PICKDETAIL    
         (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,    
            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,    
            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,    
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,    
            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo     
         , TaskDetailKey                                                
                  )    
         SELECT @c_newpickdetailkey  , CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @cTaskLOT,    
                  Storerkey, Sku, AltSku, UOM,UOMQty,@nTaskQty-@nNewQTY, 0, 0,    
                  DropId,Loc, @cTaskID, PackKey, UpdateSource, CartonGroup, CartonType,    
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,    
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo    
               , TaskDetailKey                                                 
         FROM PICKDETAIL (NOLOCK)    
         WHERE PickdetailKey = @cPickDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148731  
            SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPDFail  
            GOTO RollBackTran  
         END  
           
         -- Update current task  
         UPDATE TaskDetail WITH (ROWLOCK)  
         SET  
            LOT = @cNewLOT,   
            FromID = @cNewID,   
            ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,   
            QTY = @nNewQty,  
            SystemQty=@nNewQty,  
            DropID = @nTaskDropID,  
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148732  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTDFail  
            GOTO RollBackTran  
         END  
  
         EXECUTE nspg_getkey      
         "TaskDetailKey"      
         , 10      
         , @c_taskdetailkey OUTPUT      
         , @b_success OUTPUT      
         , @n_err OUTPUT      
         , @c_errmsg OUTPUT      
                   
         IF @b_success <> 1      
         BEGIN      
            SET @nErrNo = 148733  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetTDKeyFail  
            GOTO RollBackTran     
         END    
  
          INSERT TASKDETAIL      
          (      
            TaskDetailKey ,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc     
           ,FromID,ToLoc,LogicalToLoc,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority     
           ,Holdkey,UserKey,UserPosition,UserKeyOverRide,StartTime,EndTime            
           ,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber    
           ,ListKey,WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,SystemQty,RefTaskKey,LoadKey ,AreaKey,DropID ,TransitCount ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,QtyReplen ,PendingMoveIn            
          )      
         SELECT   
          @c_taskdetailkey ,TaskType,Storerkey,Sku,@cTaskLOT,UOM,UOMQty,@nTaskQTY-@nNewQty,FromLoc,LogicalFromLoc     
           ,@cTaskID,ToLoc,LogicalToLoc,'',Caseid,PickMethod,0,StatusMsg,Priority,SourcePriority     
           ,'','','1','',getdate(),getdate()           
           ,SourceType,SourceKey,'',OrderKey,OrderLineNumber    
           ,'',WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,@nTaskQTY-@nNewQty,RefTaskKey,LoadKey ,AreaKey,DropID ,TransitCount ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,0 ,PendingMoveIn          
         FROM TASKDETAIL (NOLOCK)  
         WHERE TASKDetailKEY=@cTaskDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148734  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTDFail  
            GOTO RollBackTran  
         END  
           
         UPDATE PICKDETAIL WITH (ROWLOCK)  
         SET taskdetailkey=@c_taskdetailkey  
         WHERE pickdetailkey=@c_newpickdetailkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148735  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
            GOTO RollBackTran  
         END  
  
         DELETE PICKDETAIL WHERE qty=0 AND ID=@cTaskID AND taskdetailkey=@cTaskDetailKey AND LOC=@cTaskLOC  
  
      END  
      ELSE  
      BEGIN  
         -- Update current task  
         UPDATE TaskDetail WITH (ROWLOCK)  
          SET  
            LOT = @cNewLOT,   
            FromID = @cNewID,   
            ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,   
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey  
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
         BEGIN  
            SET @nErrNo = 148713  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
            GOTO RollBackTran  
         END  
      END  
      GOTO CommitTran  
   END  
  
   IF EXISTS (SELECT 1 FROM @tTD WHERE TaskType in ('FPK') and ISNULL(taskdetailkey,'')<>'') AND @cOtherPickDetailKey <> ''  
   BEGIN  
  
     -- Unallocate  
      UPDATE PickDetail WITH (ROWLOCK)  
      SET QTY =0  
      where pickdetailkey IN (SELECT pickdetailkey FROM @tPD)  

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 148741  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
         GOTO RollBackTran  
      END  
  
      -- Loop PickDetail  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT pickdetailkey,QTY  
        FROM @tPD  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF @cPickDetailKey <> @cOtherPickDetailKey  
         BEGIN  
  
            -- Update other task PickDetail  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET  
               LOT = @cNewLOT,   
               ID = @cNewID,  
               QTY = CASE WHEN @cRemainQty<@nQTY THEN @cRemainQty ELSE @nQTY END,  
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 148742  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
               GOTO RollBackTran  
            END  
  
            SET @nTaskQTY = @nTaskQTY - @nQTY  
         END  
         ELSE  
         BEGIN  
  
            -- Update current task PickDetail  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET  
               LOT = @cNewAllLOT,   
               ID = @cNewAllID,  
               QTY =  @nQTY ,  
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 148743  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPDFail  
               GOTO RollBackTran  
            END  

            SET @nNewAllQTY = @nNewAllQTY - @nQTY  
         END  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      END  
  
      -- Update other task  
      UPDATE TaskDetail WITH (ROWLOCK)  
      SET  
         LOT = @cNewAllLOT,   
         FromID = @cNewAllID,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey IN (SELECT taskdetailkey FROM @tTD WHERE TaskType='FPK' AND ISNULL(taskdetailkey,'')<>'')  
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
      BEGIN  
         SET @nErrNo = 148718  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
  
      -- Update current task  
      UPDATE TaskDetail WITH (ROWLOCK)  
       SET  
         LOT = @cNewLOT,   
         FromID = @cNewID,   
         ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,  
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey = @cTaskDetailKey  
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
      BEGIN  
         SET @nErrNo = 148716  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
      GOTO CommitTran  
   END  
  
   -- Check not swap  
   SET @nErrNo = 148717  
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped  
   GOTO RollBackTran  
  
CommitTran:  
   COMMIT TRAN rdt_1812SwapID03  
   GOTO Quit  
RollBackTran:  
      ROLLBACK TRAN rdt_1812SwapID03  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO