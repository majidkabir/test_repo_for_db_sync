SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1770SwapID03                                    */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Swap ID base on same LOC,SKU                                */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 19-03-2020  1.0  YeeKung     WMS-12510 Created                       */  
/************************************************************************/  
CREATE PROCEDURE [RDT].[rdt_1770SwapID03]  
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
    
   -- Check blank  
   IF @cNewID = ''  
   BEGIN  
      SET @nErrNo = 149801    
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
      @nTaskQTY = SystemQTY    
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
   IF @@ROWCOUNT = 0    
   BEGIN    
      SET @nErrNo = 149802    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey    
      RETURN    
   END  
  
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
      SET @nErrNo = 149803  
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
      SET @nErrNo = 149805  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match  
      RETURN  
   END  
  
   -- Check SKU match  
   IF @cNewSKU <> @cTaskSKU  
   BEGIN  
      SET @nErrNo = 149806  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match  
      RETURN  
   END  
  
   -- Check QTY match  
   IF @nNewQTY <> @nTaskQTY  
   BEGIN  
      SET @nErrNo = 149807  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match  
      RETURN  
   END  
  
   -- Check ID picked  
   IF EXISTS( SELECT TOP 1 1  
      FROM PickDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cNewSKU  
         AND ID = @cNewID  
         AND Status <> '0'  
         AND QTY > 0)  
   BEGIN  
      SET @nErrNo = 149808  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID picked  
      RETURN  
   END  
  
   -- Check task taken by other  
   IF EXISTS( SELECT TOP 1 1  
      FROM TaskDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND TaskType = @cTaskType  
         AND FromID = @cNewID  
         AND Status NOT IN ('0','9'))  
   BEGIN  
      SET @nErrNo = 149809  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID task taken  
      RETURN  
   END  
  
  
   /*--------------------------------------------------------------------------------------------------  
  
                                                Swap ID  
  
   --------------------------------------------------------------------------------------------------*/  
   /*  
      Scenario:  
      1. Pallet ID that not allocate on any task  
      2. Pallet ID that only allocate to the task which only Pallet Pick  
      3. Pallet ID that allocate to task (FCP)   
      - Provided that does not have any partial pallet id in the location   
      (If that is partial pallet exists in the location, but operator scan full partial pallet id , the system will prompt error)  
  
   */  
  
   /* Scenario 1 */  
   -- Get FCP task info  
   SET @cFCPTaskDetailKey = ''  
   SELECT @cFCPTaskDetailKey = TaskDetailKey  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND TaskType = @cTaskType  
      AND FromID = @cNewID  
      AND Status = '0'  
  
   -- Get FCP PickDetail info  
   SET @cOtherPickDetailKey = ''  
   SELECT @cOtherPickDetailKey = PickDetailKey  
   FROM PickDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cNewSKU  
      AND ID = @cNewID  
      AND Status = '0'  
      AND QTY > 0  
  
   -- Get FPK task info  
   SET @cFPKTaskDetailKey = ''  
   SELECT @cFPKTaskDetailKey = TaskDetailKey  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND TaskType in ('FPK','FPK1')  
      AND FromID = @cNewID  
      AND Status = '0'  
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1770SwapID03  
  
   -- 1. ID is not alloc  
   IF @cFPKTaskDetailKey = '' AND @cFCPTaskDetailKey = '' AND @cOtherPickDetailKey = ''  
   BEGIN  
       -- Loop PickDetail  
      DECLARE @curPD CURSOR  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetailKey, QTY  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE TaskDetailKey = @cTaskDetailKey  
            AND Status = '0'  
            AND QTY > 0  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Update current task PickDetail  
         UPDATE PickDetail SET  
            LOT = @cNewLOT,   
            ID = @cNewID,   
            EditDate = GETDATE(),   
            EditWho = 'rdt.' + SUSER_SNAME()  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
            GOTO RollBackTran  
  
         SET @nNewQTY = @nNewQTY - @nQTY  
         SET @nTaskQTY = @nTaskQTY - @nQTY  
           
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY  
      END  
  
      -- Check balance  
      IF @nTaskQTY <> 0 OR @nNewQTY <> 0  
      BEGIN  
         SET @nErrNo = 149810  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr  
         GOTO RollBackTran  
      END  
  
      -- Update current task  
      UPDATE TaskDetail SET  
         LOT = @cNewLOT,   
         FromID = @cNewID,   
         ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey = @cTaskDetailKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 149811  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
      GOTO CommitTran  
   END  
     
   -- 2. ID on other TaskDetail and PickDetail  
   IF @cFCPTaskDetailKey <> '' AND @cOtherPickDetailKey <> ''  
   BEGIN  
      -- Loop PickDetail  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetailKey, TaskDetailKey, QTY  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE TaskDetailKey IN (@cFCPTaskDetailKey, @cTaskDetailKey)  
            AND Status = '0'  
            AND QTY > 0  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF @cTaskKey = @cFCPTaskDetailKey  
         BEGIN  
            -- Update other task PickDetail  
            UPDATE PickDetail SET  
               LOT = @cTaskLOT,   
               ID = @cTaskID,   
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 149812  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
               GOTO RollBackTran  
            END  
            SET @nNewQTY = @nNewQTY - @nQTY  
         END  
         ELSE  
         BEGIN  
            -- Update current task PickDetail  
            UPDATE PickDetail SET  
               LOT = @cNewLOT,   
               ID = @cNewID,   
               EditDate = GETDATE(),   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 149813  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
               GOTO RollBackTran  
            END  
            SET @nTaskQTY = @nTaskQTY - @nQTY  
         END  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY  
      END  
  
      -- Check balance  
      IF @nTaskQTY <> 0 OR @nNewQTY <> 0  
      BEGIN  
         SET @nErrNo = 149814  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr  
         GOTO RollBackTran  
      END  
        
      -- Update other task  
      UPDATE TaskDetail WITH (ROWLOCK)  
      SET  
         LOT = @cTaskLOT,   
         FromID = @cTaskID,   
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey = @cFCPTaskDetailKey  
         AND Status = '0'  
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
      BEGIN  
         SET @nErrNo = 149815  
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
         SET @nErrNo = 149816  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
      GOTO CommitTran  
   END  
  
   IF @cFPKTaskDetailKey <> '' AND @cOtherPickDetailKey <> ''  
   BEGIN  
      -- Loop PickDetail  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PickDetailKey, TaskDetailKey, QTY  
      FROM dbo.PickDetail WITH (NOLOCK)  
      WHERE TaskDetailKey IN (@cFPKTaskDetailKey)  
         AND Status = '0'  
         AND QTY > 0  
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Update current task PickDetail  
         UPDATE PickDetail SET  
            LOT = @cNewLOT,   
            ID = @cNewID,   
            EditDate = GETDATE(),   
            EditWho = 'rdt.' + SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 149817  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
            GOTO RollBackTran  
         END  
         SET @nTaskQTY = @nTaskQTY - @nQTY  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY  
      END  
  
      -- Check balance  
      IF @nTaskQTY <> 0 OR @nNewQTY <> 0  
      BEGIN  
         SET @nErrNo = 149818  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr  
         GOTO RollBackTran  
      END  
  
        -- Update other task  
      UPDATE TaskDetail WITH (ROWLOCK)  
      SET  
         LOT = @cTaskLOT,   
         FromID = @cTaskID,   
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE TaskDetailKey = @cFPKTaskDetailKey  
         AND Status = '0'  
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
      BEGIN  
         SET @nErrNo = 149819  
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
         SET @nErrNo = 149820  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
         GOTO RollBackTran  
      END  
      GOTO CommitTran  
   END  
  
   -- Check not swap  
   SET @nErrNo = 149821  
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped  
   GOTO RollBackTran  
  
CommitTran:  
   COMMIT TRAN rdt_1770SwapID03  
   GOTO Quit  
RollBackTran:  
      ROLLBACK TRAN rdt_1770SwapID03  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO