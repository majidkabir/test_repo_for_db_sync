SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764SwapID02                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Swap ID base on same LOC, SKU, QTY                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-12-2017  1.0  Ung         WMS-3179 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764SwapID02]
   @nMobile           INT,
   @nFunc             INT,
   @cLangCode         NVARCHAR( 3),
   @cTaskDetailKey    NVARCHAR( 10),
   @cNewID            NVARCHAR( 18),
   @cNewTaskDetailKey NVARCHAR( 10) OUTPUT,
   @nErrNo            INT           OUTPUT,
   @cErrMsg           NVARCHAR( 20) OUTPUT, 
   @cDebug            NVARCHAR( 1) = ''
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
      SET @nErrNo = 117851
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
      SET @nErrNo = 117852
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
      SET @nErrNo = 117853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      RETURN
   END

   -- Check ID multi LOC/LOT
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 117854
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
      RETURN
   END

   -- Check LOC match
   IF @cNewLOC <> @cTaskLOC
   BEGIN
      SET @nErrNo = 117855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      RETURN
   END

   -- Check SKU match
   IF @cNewSKU <> @cTaskSKU
   BEGIN
      SET @nErrNo = 117856
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      RETURN
   END

   -- Check QTY match
   IF @nNewQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 117857
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
      RETURN
   END

   -- Check LOT match
   IF @cNewLOT <> @cTaskLOT
   BEGIN
      DECLARE @dTaskL04 DATETIME
      DECLARE @dNewL04  DATETIME
      
      -- Get L04
      SELECT @dNewL04  = Lottable04 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cNewLOT
      SELECT @dTaskL04 = Lottable04 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cTaskLOT
      
      -- Check L04 match
      IF @dNewL04 <> @dTaskL04 OR @dNewL04 IS NULL OR @dTaskL04 IS NULL
      BEGIN
         SET @nErrNo = 117872
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L04 not match
         RETURN
      END
   END

   -- Check task taken by other
   IF EXISTS( SELECT TOP 1 1
      FROM TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND TaskType IN ('RPF', 'FPK') -- @cTaskType
         AND FromID = @cNewID
         AND Status > '0' AND Status < '9')
   BEGIN
      SET @nErrNo = 117859
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
      -- Check full pallet
      IF @cOtherPickMethod <> 'FP' 
      BEGIN
         SET @nErrNo = 117861
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
   -- IF @cOtherTaskDetailKey <> ''
      SELECT TOP 1 
         @cOtherPickDetailKey = PickDetailKey
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         -- AND TaskDetailKey = @cOtherTaskDetailKey
         AND LOC = @cNewLOC
         AND SKU = @cNewSKU
         AND ID = @cNewID
         AND Status = '0'
         AND QTY > 0

   -- Check pallet allocated but not yet release task
   IF @cOtherTaskDetailKey = '' AND @cOtherPickDetailKey <> ''
   BEGIN
      SET @nErrNo = 117873
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID locked
      RETURN
   END

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
   SAVE TRAN rdt_1764SwapID02


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
         LOT = @cTaskLOT, 
         FromID = @cTaskID, 
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE TaskDetailKey = @cOtherTaskDetailKey
         AND Status = '0' --'H'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 117862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
   END

   -- Update current task
   UPDATE TaskDetail SET
      LOT = @cNewLOT, 
      FromID = @cNewID, 
      ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END, 
      FinalID = CASE WHEN FinalID <> '' THEN @cNewID ELSE FinalID END, 
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(), 
      TrafficCop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 117863
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
      GOTO RollBackTran
   END

   -- Both task have PickDetail
   IF @cCurrPickDetailKey <> '' AND @cOtherPickDetailKey <> ''
   BEGIN
      -- Check if can bypass unalloc, for performance
      DECLARE @nUnAlloc INT
      IF @nTaskAllocQTY = @nNewAllocQTY AND @cTaskLOT = @cNewLOT
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
               SET @nErrNo = 117864
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
                  LOT = @cTaskLOT, 
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
               SET @nErrNo = 117865
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
                  LOT = @cNewLOT, 
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
               SET @nErrNo = 117866
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
         SET @nErrNo = 117867
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
            LOT = @cNewLOT, 
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
         SET @nErrNo = 117868
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
         -- Update other task PickDetail
         UPDATE PickDetail SET
            LOT = @cTaskLOT, 
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
         SET @nErrNo = 117869
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
      WHERE LOT = @cNewLOT
         AND LOC = @cTaskLOC
         AND ID = @cNewID
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 117870
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
         SET @nErrNo = 117871
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
         GOTO RollBackTran
      END
   END   

CommitTran:
   COMMIT TRAN rdt_1764SwapID02
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_1764SwapID02
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO