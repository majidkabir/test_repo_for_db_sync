SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770SwapID02                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Swap ID base on same LOC, SKU, L04, QTY                     */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-12-2014  1.0  Ung         Created SOS327467                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770SwapID02]
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
   DECLARE @cOtherTaskDetailKey NVARCHAR(10)
   
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
      SET @nErrNo = 51051
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
      SET @nErrNo = 51052
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
      SET @nErrNo = 51053
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      RETURN
   END

   -- Check ID multi LOC/LOT
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 51054
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID multi rec
      RETURN
   END

   -- Check LOC match
   IF @cNewLOC <> @cTaskLOC
   BEGIN
      SET @nErrNo = 51055
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      RETURN
   END

   -- Check SKU match
   IF @cNewSKU <> @cTaskSKU
   BEGIN
      SET @nErrNo = 51056
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      RETURN
   END

   -- Check QTY match
   IF @nNewQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 51057
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
      RETURN
   END

   -- Check LOT match
   IF @cNewLOT <> @cTaskLOT
   BEGIN
      DECLARE @cTaskL02 NVARCHAR(18)
      DECLARE @cNewL02  NVARCHAR(18)
      
      -- Get L04
      SELECT @cNewL02  = Lottable02 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cNewLOT
      SELECT @cTaskL02 = Lottable02 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cTaskLOT
      
      -- Check L04 match
      IF @cNewL02 <> @cTaskL02 OR @cNewL02 IS NULL OR @cTaskL02 IS NULL
      BEGIN
         SET @nErrNo = 51058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L04 not match
         RETURN
      END
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
      SET @nErrNo = 51059
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID picked
      RETURN
   END

   -- Check task taken by other
   IF EXISTS( SELECT TOP 1 1
      FROM TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND TaskType = @cTaskType
         AND FromID = @cNewID
         AND Status > '0')
   BEGIN
      SET @nErrNo = 51060
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID task taken
      RETURN
   END

/*--------------------------------------------------------------------------------------------------

                                                Swap ID

--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. ID is not alloc           swap
   2. ID on other PickDetail    swap
*/

   -- Get other task info
   SET @cOtherTaskDetailKey = ''
   SELECT @cOtherTaskDetailKey = TaskDetailKey
   FROM TaskDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskType = @cTaskType
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

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1770SwapID02
   
   -- 1. ID is not alloc
   IF @cOtherTaskDetailKey = '' AND @cOtherPickDetailKey = ''
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
         SET @nErrNo = 51061
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
         SET @nErrNo = 51062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
      GOTO CommitTran
   END

   -- 2. ID on other TaskDetail and PickDetail
   IF @cOtherTaskDetailKey <> '' AND @cOtherPickDetailKey <> ''
   BEGIN
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
         IF @cTaskKey = @cOtherTaskDetailKey
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
               SET @nErrNo = 51063
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
               SET @nErrNo = 51064
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
         SET @nErrNo = 51065
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskOffsetErr
         GOTO RollBackTran
      END
      
      -- Update other task
      UPDATE TaskDetail SET
         LOT = @cTaskLOT, 
         FromID = @cTaskID, 
         ToID = CASE WHEN ToID <> '' THEN @cTaskID ELSE ToID END, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE TaskDetailKey = @cOtherTaskDetailKey
         AND Status = '0'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 51066
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
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
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 51067
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
      GOTO CommitTran
   END

   -- Check not swap
   SET @nErrNo = 51068
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NothingSwapped
   GOTO RollBackTran

CommitTran:
   COMMIT TRAN rdt_1770SwapID02
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_1770SwapID02
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO