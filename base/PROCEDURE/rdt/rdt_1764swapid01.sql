SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764SwapID01                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Swap ID base on same LOC, SKU, LOT, QTY                     */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-07-2017  1.0  Ung         WMS-2440 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764SwapID01]
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

   DECLARE @cCurrPickDetailKey  NVARCHAR( 10)
   DECLARE @cCurrSuggLOC        NVARCHAR( 10)
   DECLARE @nCurrPendingMoveIn  INT
   DECLARE @nCurrQTYReplen      INT

   DECLARE @cOtherPickDetailKey NVARCHAR( 10)
   DECLARE @cOtherTaskDetailKey NVARCHAR( 10)
   DECLARE @cOtherPickMethod    NVARCHAR( 10)
   DECLARE @cOtherTaskType      NVARCHAR( 10)
   DECLARE @cOtherSuggLOC       NVARCHAR( 10)
   DECLARE @nOtherPendingMoveIn INT
   DECLARE @nOtherQTYReplen     INT
   
   DECLARE @cNewSKU        NVARCHAR( 20)
   DECLARE @cNewLOT        NVARCHAR( 10)
   DECLARE @cNewLOC        NVARCHAR( 10)
   DECLARE @nNewQTY        INT
   DECLARE @nNewAllocQTY   INT

   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cTaskKey       NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskAllocQTY  INT
   DECLARE @nQTY           INT
   DECLARE @nCurrRowRef    INT  
   DECLARE @nOtherRowRef   INT

   DECLARE @curPD CURSOR
   DECLARE @tPD TABLE
   (
      PickdetailKey NVARCHAR(10) NOT NULL, 
      TaskDetailKey NVARCHAR(10) NOT NULL, 
      QTY           INT          NOT NULL
   )

   -- Check blank
   IF @cNewID = ''
   BEGIN
      SET @nErrNo = 112851
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
      @nTaskQTY = QTY, 
      @nTaskAllocQTY = SystemQTY
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 112852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END

   -- Get new ID info
   SELECT
      @cNewSKU = SKU,
      @nNewQTY = QTY-QTYPicked,
      @nNewAllocQTY = QTYAllocated,
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
      SET @nErrNo = 112853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      RETURN
   END

   -- Check ID multi LOC/LOT
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 112854
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
      RETURN
   END

   -- Check LOC match
   IF @cNewLOC <> @cTaskLOC
   BEGIN
      SET @nErrNo = 112855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      RETURN
   END

   -- Check SKU match
   IF @cNewSKU <> @cTaskSKU
   BEGIN
      SET @nErrNo = 112856
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      RETURN
   END

   -- Check QTY match
   IF @nNewQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 112857
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
      RETURN
   END

   -- Check LOT match
   IF @cNewLOT <> @cTaskLOT
   BEGIN
      SET @nErrNo = 112858
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT not match
      RETURN
   END

   -- Check task taken by other
   IF EXISTS( SELECT TOP 1 1
      FROM TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND TaskType IN ('RPF', 'FPK') -- @cTaskType
         AND FromID = @cNewID
         AND Status > '0' AND Status < '9')
   BEGIN
      SET @nErrNo = 112859
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID task taken
      RETURN
   END

   -- Get other task info
   SET @cOtherTaskDetailKey = ''
   SELECT 
      @cOtherTaskDetailKey = TaskDetailKey, 
      @cOtherPickMethod = PickMethod, 
      @cOtherTaskType = TaskType
   FROM TaskDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskType IN ('RPF', 'FPK') -- @cTaskType
      AND FromID = @cNewID
      AND Status = '0' --'H'

   IF @cOtherTaskDetailKey <> '' 
   BEGIN
      -- Check PickMethod
      IF @cOtherTaskType NOT IN ('FPK', 'RPF') 
      BEGIN
         SET @nErrNo = 112860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap FPK/RPF
         RETURN
      END
      
      -- Check full pallet
      IF @cOtherPickMethod <> 'FP' 
      BEGIN
         SET @nErrNo = 112861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap FP only
         RETURN
      END
   END

   -- Get current PickDetail info
   SET @cCurrPickDetailKey = ''
   SELECT TOP 1 
      @cCurrPickDetailKey = PickDetailKey
   FROM PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskDetailKey = @cTaskDetailKey
      AND Status = '0'
      AND QTY > 0

   -- Get other PickDetail info
   SET @cOtherPickDetailKey = ''
   IF @cOtherTaskDetailKey <> ''
      SELECT TOP 1 
         @cOtherPickDetailKey = PickDetailKey
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND TaskDetailKey = @cOtherTaskDetailKey
         AND SKU = @cNewSKU
         AND ID = @cNewID
         AND Status = '0'
         AND QTY > 0

   -- Get current RFPutaway info
   SET @nCurrRowRef = 0
   SET @nCurrPendingMoveIn = 0
   SET @cCurrSuggLOC = ''
   SELECT 
      @nCurrRowRef  = RowRef, 
      @nCurrPendingMoveIn = QTY, 
      @cCurrSuggLOC = SuggestedLOC
   FROM RFPutaway WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get other RFPutaway info
   SET @nOtherRowRef = 0
   SET @nOtherPendingMoveIn = 0 
   SET @cOtherSuggLOC = ''
   IF @cOtherTaskDetailKey <> ''
      SELECT 
         @nOtherRowRef = RowRef, 
         @nOtherPendingMoveIn = QTY, 
         @cOtherSuggLOC = SuggestedLOC
      FROM RFPutaway WITH (NOLOCK) 
      WHERE TaskDetailKey = @cOtherTaskDetailKey

   -- Get current LOTxLOCxID info
   SET @nCurrQTYReplen = 0
   SELECT @nCurrQTYReplen = QTYReplen
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE LOT = @cTaskLOT
      AND LOC = @cTaskLOC
      AND ID = @cTaskID

   -- Get other LOTxLOCxID info
   SET @nOtherQTYReplen = 0
   IF @cOtherTaskDetailKey <> ''
      SELECT @nOtherQTYReplen = QTYReplen
      FROM LOTxLOCxID WITH (NOLOCK)
      WHERE LOT = @cTaskLOT
         AND LOC = @cTaskLOC
         AND ID = @cNewID

/*--------------------------------------------------------------------------------------------------

                                                Swap ID

--------------------------------------------------------------------------------------------------*/
/*
   Pallet A and pallet B. System dispatched pallet A, user scanned pallet B

   Scenario:
   1. B no task, swap with A (RPF)
   2. B is FPK task, swap with A (RPF)
   3. B is RPF task, swap with A (RPF)   
*/

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1764SwapID01


   IF @nCurrRowRef > 0
   BEGIN
      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
         ,''        --@cLOC      
         ,''        --@cID       
         ,''        --@cSuggLOC 
         ,''        --@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cTaskDetailKey = @cTaskDetailKey
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   
   IF @nOtherRowRef > 0
   BEGIN
      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
         ,''        --@cLOC      
         ,''        --@cID       
         ,''        --@cSuggLOC 
         ,''        --@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cTaskDetailKey = @cOtherTaskDetailKey
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END

   -- Update other task
   IF @cOtherTaskDetailKey <> ''
   BEGIN
      UPDATE TaskDetail SET
         FromID = @cTaskID, 
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE TaskDetailKey = @cOtherTaskDetailKey
         AND Status = '0' --'H'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 112862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
   END

   -- Update current task
   UPDATE TaskDetail SET
      FromID = @cNewID, 
      ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END, 
      FinalID = CASE WHEN FinalID <> '' THEN @cNewID ELSE FinalID END, 
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(), 
      TrafficCop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 112863
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
      GOTO RollBackTran
   END

   -- Both task have PickDetail
   IF @cCurrPickDetailKey <> '' AND @cOtherPickDetailKey <> ''
   BEGIN
      -- Check if can bypass unalloc, for performance
      DECLARE @nUnAlloc INT
      IF @nTaskAllocQTY = @nNewAllocQTY
         SET @nUnAlloc = 0 -- No
      ELSE
         SET @nUnAlloc = 1 -- Yes
      
      -- Unalloc
      IF @nUnAlloc = 1 -- Yes
      BEGIN
         -- Save a copy
         INSERT INTO @tPD (PickDetailKey, TaskDetailKey, QTY)
         SELECT PickDetailKey, TaskDetailKey, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey IN (@cOtherTaskDetailKey, @cTaskDetailKey)
            AND Status = '0'
            AND QTY > 0
         
         -- Loop PickDetail
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey, TaskDetailKey, QTY
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE TaskDetailKey IN (@cOtherTaskDetailKey, @cTaskDetailKey)
               AND Status = '0'
               AND QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = 'rdt.' + SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112864
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY
         END
      END         
      
      -- Loop PickDetail
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, TaskDetailKey, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey IN (@cOtherTaskDetailKey, @cTaskDetailKey)
            AND Status = '0'
            AND QTY > 0
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nUnAlloc = 1
            SELECT @nQTY = QTY FROM @tPD WHERE PickDetailKey = @cPickDetailKey

         IF @cTaskKey = @cOtherTaskDetailKey
         BEGIN
            -- Update other task PickDetail
            IF @nUnAlloc = 1
               UPDATE PickDetail SET
                  ID = @cTaskID, 
                  QTY = @nQTY, 
                  EditDate = GETDATE(), 
                  EditWho = 'rdt.' + SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            ELSE
               UPDATE PickDetail SET
                  ID = @cTaskID, 
                  EditDate = GETDATE(), 
                  EditWho = 'rdt.' + SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112865
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            SET @nNewAllocQTY = @nNewAllocQTY - @nQTY
         END
         ELSE
         BEGIN
            -- Update current task PickDetail
            IF @nUnAlloc = 1
               UPDATE PickDetail SET
                  ID = @cNewID, 
                  QTY = @nQTY, 
                  EditDate = GETDATE(), 
                  EditWho = 'rdt.' + SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            ELSE
               UPDATE PickDetail SET
                  ID = @cNewID, 
                  EditDate = GETDATE(), 
                  EditWho = 'rdt.' + SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112866
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            SET @nTaskAllocQTY = @nTaskAllocQTY - @nQTY
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cTaskKey, @nQTY
      END
      
      -- Check balance
      IF @nTaskAllocQTY <> 0 OR @nNewAllocQTY <> 0
      BEGIN
         SET @nErrNo = 112867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
         GOTO RollBackTran
      END
   END

   -- Current task have PickDetail
   ELSE IF @cCurrPickDetailKey <> '' AND @cOtherPickDetailKey = ''
   BEGIN
      -- Loop PickDetail
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
            ID = @cNewID, 
            EditDate = GETDATE(), 
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
            GOTO RollBackTran

         SET @nTaskAllocQTY = @nTaskAllocQTY - @nQTY
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END

      -- Check balance
      IF @nTaskAllocQTY <> 0
      BEGIN
         SET @nErrNo = 112868
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
         GOTO RollBackTran
      END
   END
   
   -- Other task have PickDetail
   ELSE IF @cCurrPickDetailKey = '' AND @cOtherPickDetailKey <> ''
   BEGIN
      -- Loop PickDetail
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cOtherTaskDetailKey
            AND Status = '0'
            AND QTY > 0      
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update current task PickDetail
         UPDATE PickDetail SET
            -- LOT = @cNewLOT, 
            ID = @cTaskID, 
            EditDate = GETDATE(), 
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
            GOTO RollBackTran

         SET @nNewAllocQTY = @nNewAllocQTY - @nQTY
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END

      -- Check balance
      IF @nNewAllocQTY <> 0
      BEGIN
         SET @nErrNo = 112869
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
         GOTO RollBackTran
      END
   END
   
   IF @nCurrRowRef > 0
   BEGIN
      -- Booking
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK' 
         ,@cTaskLOC
         ,@cNewID       
         ,@cCurrSuggLOC 
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cFromLOT = @cTaskLOT
         ,@cTaskDetailKey = @cTaskDetailKey
         ,@cMoveQTYAlloc = '1' -- Just to bypass QTYReplen
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   
   IF @nOtherRowRef > 0
   BEGIN
      -- Booking
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK' 
         ,@cTaskLOC     
         ,@cTaskID       
         ,@cOtherSuggLOC 
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cFromLOT = @cTaskLOT
         ,@cTaskDetailKey = @cOtherTaskDetailKey
         ,@cMoveQTYAlloc = '1' -- Just to bypass QTYReplen
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   
   -- IF @nCurrQTYReplen > 0
   BEGIN
      UPDATE LOTxLOCxID SET
         QTYReplen = @nCurrQTYReplen, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE LOT = @cTaskLOT
         AND LOC = @cTaskLOC
         AND ID = @cNewID
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 112870
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
         GOTO RollBackTran
      END
   END
   
   -- IF @nOtherQTYReplen > 0
   BEGIN
      UPDATE LOTxLOCxID SET
         QTYReplen = @nOtherQTYReplen, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE LOT = @cTaskLOT
         AND LOC = @cTaskLOC
         AND ID = @cTaskID
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 112871
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
         GOTO RollBackTran
      END
   END   
   
   -- Swap FCP task (overalloc in pick face, waiting for RPF task that had swapped to complete)
   IF EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND FromID IN ( @cTaskID, @cNewID)
         AND TaskType = 'FCP'
         AND Status = '0') --'H'
   BEGIN
      DECLARE @cFCPTaskDetailKey NVARCHAR(10)
      DECLARE @cFCPFromID NVARCHAR( 18)
      DECLARE @nFCPRowRef INT
      DECLARE @cPDLOT NVARCHAR( 10)
      DECLARE @cPDLOC NVARCHAR( 10)
      DECLARE @cID NVARCHAR( 18)
      
      DECLARE @curTask CURSOR
      SET @curTask = CURSOR FOR
         SELECT TaskDetailKey, FromID
         FROM TaskDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND TaskType = 'FCP'
            AND LOT = @cTaskLOT
            -- AND FromLOC = @cTaskLOC -- FCP overalloc in pick face
            AND FromID IN ( @cTaskID, @cNewID)
            AND Status = '0' --'H'
      OPEN @curTask
      FETCH NEXT FROM @curTask INTO @cFCPTaskDetailKey, @cFCPFromID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cFCPFromID = @cTaskID 
            SET @cID = @cNewID 
         ELSE
            SET @cID = @cTaskID 

         -- Update FCP task 
         UPDATE TaskDetail SET
            FromID = @cID, 
            ToID = CASE WHEN ToID <> '' THEN @cID ELSE ToID END,
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE TaskDetailKey = @cFCPTaskDetailKey
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 112872
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
            GOTO RollBackTran
         END

         -- Update FCP PickDetail
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, LOT, LOC, QTY
            FROM PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND TaskDetailKey = @cFCPTaskDetailKey
               AND Status = '0'
               AND QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPDLOT, @cPDLOC, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Unalloc
            UPDATE PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 112873
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END

            -- Insert blank LOTxLOCxID (to overcome FK_PICKDETAIL_LOTLOCID_01)
            IF NOT EXISTS( SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
               WHERE LOT = @cPDLOT
                  AND LOC = @cPDLOC
                  AND ID = @cID)
            BEGIN
               INSERT INTO LOTxLOCxID (LOT, LOC, ID, StorerKey, SKU) 
               VALUES (@cPDLOT, @cPDLOC, @cID, @cStorerKey, @cTaskSKU)
               IF @@ERROR <> 0 --OR @@ROWCOUNT <> 1
               BEGIN
                  SET @nErrNo = 112874
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
                  GOTO RollBackTran
               END
            END

            -- Realloc and change ID
            UPDATE PickDetail SET
               ID = @cID, 
               QTY = @nQTY, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 112875
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPDLOT, @cPDLOC, @nQTY
         END

         SET @nFCPRowRef = 0
         SELECT @nFCPRowRef = RowRef FROM RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cFCPTaskDetailKey

         -- Update RFPutaway
         IF @nFCPRowRef > 0
         BEGIN
            UPDATE RFPutaway SET
               ID     = CASE WHEN ID <> '' THEN @cID ELSE ID END, 
               FromID = CASE WHEN FromID <> '' THEN @cID ELSE FromID END
            FROM RFPutaway WITH (NOLOCK)
            WHERE RowRef = @nFCPRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112876
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RFPA Fail
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM @curTask INTO @cFCPTaskDetailKey, @cFCPFromID
      END
   END

CommitTran:
   COMMIT TRAN rdt_1764SwapID01
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_1764SwapID01
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO