SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764SwapID04                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Swap ID base on same LOC, SKU, LOT, QTY                     */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-08-2018  1.0  ChewKP      WMS-5568 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764SwapID04]
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
          ,@cTaskStatus    NVARCHAR(10)

   DECLARE @curPD CURSOR
   DECLARE @tPD TABLE
   (
      PickdetailKey NVARCHAR(10) NOT NULL, 
      TaskDetailKey NVARCHAR(10) NOT NULL, 
      QTY           INT          NOT NULL
   )
   
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Check blank
   IF @cNewID = ''
   BEGIN
      SET @nErrNo = 128051
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
      @nTaskAllocQTY = SystemQTY,
      @cTaskStatus = Status 
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 128052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END
   
   
   IF @cTaskType <> 'RP1'
      RETURN

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

   -- Check LOC match
   IF @cNewLOC <> @cTaskLOC
   BEGIN
      SET @nErrNo = 112855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
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
      AND TaskType = 'RP1' --IN ('RPF', 'FPK') -- @cTaskType
      AND FromID = @cNewID
      AND Status = '0' --'H'

   IF @cOtherTaskDetailKey <> '' 
   BEGIN
      -- Check PickMethod
      IF @cOtherTaskType <> 'RP1' -- NOT IN ('FPK', 'RPF') 
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
   SAVE TRAN rdt_1764SwapID04


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
         --FromID = @cTaskID, 
         --ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END, 
         --ListKey = @cTaskDetailKey, 
         UserKey = SUSER_SNAME(), 
         Status = @cTaskStatus,
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE TaskDetailKey = @cOtherTaskDetailKey
         AND Status = '0' --'H'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 128062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
   END

   -- Update current task
   UPDATE TaskDetail SET
      --FromID = @cNewID, 
      --ToID = CASE WHEN ToID <> '' THEN @cNewID ELSE ToID END, 
      --FinalID = CASE WHEN FinalID <> '' THEN @cNewID ELSE FinalID END, 
      UserKey  = '',
      Status   = '0',
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(), 
      TrafficCop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 128063
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
      GOTO RollBackTran
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

   IF ISNULL(@cOtherTaskDetailKey,'')  <> '' 
      SET @cNewTaskDetailKey = @cOtherTaskDetailKey
   

CommitTran:
   COMMIT TRAN rdt_1764SwapID04
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_1764SwapID04
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO