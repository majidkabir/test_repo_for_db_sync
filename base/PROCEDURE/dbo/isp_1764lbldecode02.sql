SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_1764LblDecode02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-05-2018  1.0  Ung         WMS-4890 Created                        */
/* 02-04-2019  1.1  Ung         WMS-8537 Add QTYReplen                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_1764LblDecode02]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @nTranCount     INT

   DECLARE @cActUCCNo      NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 1)
   DECLARE @nUCCQTY        INT
   DECLARE @dUCCL04        DATETIME

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @nTaskQTYReplen INT
   DECLARE @dTaskL04       DATETIME

   DECLARE @cActTaskDetailKey NVARCHAR( 10)
   DECLARE @nActSystemQTY INT
   DECLARE @nActQTYReplen INT

   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @curPD          CURSOR

   DECLARE @tTaskPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   DECLARE @tActPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      TaskDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   SET @nTranCount = @@TRANCOUNT
   
   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cActUCCNo = @c_LabelNo
   SET @cTaskDetailKey = @c_oFieled10

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @n_ErrNo = 124151
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
      RETURN
   END

   -- Get task info
   SELECT
      @cTaskType = TaskType, 
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID, 
      @cTaskSKU = SKU, 
      @nTaskQTY = QTY, 
      @nTaskSystemQTY = SystemQTY, 
      @nTaskQTYReplen = QTYReplen
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 124152
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      GOTO Quit
   END

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @c_Storerkey
      AND Status <> '6' -- Exclude shipped out and re-received

   -- Check label scanned is UCC
   IF @nRowCount = 0
   BEGIN
      SET @c_oFieled01 = '' -- SKU
      SET @c_oFieled05 = 0  -- UCC QTY
      SET @c_oFieled08 = '' -- UCC

      SET @n_ErrNo = 124153
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
      GOTO Quit
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 124154
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
      GOTO Quit
   END

   -- Get scanned UCC info
   SELECT
      @cUCCSKU = SKU,
      @nUCCQTY = QTY,
      @cUCCLOT = LOT,
      @cUCCLOC = LOC,
      @cUCCID = ID,
      @cUCCStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @c_Storerkey
      AND Status <> '6' -- Exclude shipped out and re-received

   -- Check UCC status
   IF @cUCCStatus <> '1'
   BEGIN
      SET @n_ErrNo = 124155
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status
      GOTO Quit
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 124156
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      GOTO Quit
   END

   -- Check UCC ID match
   IF @cTaskID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 124157
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      GOTO Quit
   END

   -- Check SKU match
   IF @cTaskSKU <> @cUCCSKU
   BEGIN
      SET @n_ErrNo = 124158
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCSKUNotMatch
      GOTO Quit
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nUCCQTY
   BEGIN
      SET @n_ErrNo = 124159
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCQTYNotMatch
      GOTO Quit
   END

   -- Get L07
   SELECT @dTaskL04 = Lottable04 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cTaskLOT
   SELECT @dUCCL04 = Lottable04 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cUCCLOT

   -- Check UCC L04 match
   IF @dTaskL04 <> @dUCCL04
   BEGIN
      SET @n_ErrNo = 124160
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCL04NotMatch
      GOTO Quit
   END
/*
   -- Check UCC taken by other task
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @c_StorerKey
         AND PD.StorerKey = @c_StorerKey
         AND UCC.UCCNo = @cActUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0)
   BEGIN
      SET @n_ErrNo = 124161
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCTookByOther
      RETURN
   END
*/

/*--------------------------------------------------------------------------------------------------

                                                Swap UCC

--------------------------------------------------------------------------------------------------*/
/*
   PickDetail does not specify which UCC, only alloc by LOT
   UCC.Status = 3 after allocation
   1 TaskDetail = 1 UCC
   
   Scenario:
   LOT 1, 2, 3 same expiry date

   UCC1, LOT1
   UCC2, LOT2
   UCC3, LOT3
   
   Task1, LOT1
   Task2, LOT2
   
   Scenario:
   1. Task1, LOT1, scan UCC1     not swap, same LOT
   2. Task2, LOT2, scan UCC3     swap, with LOT not alloc
   3. Task3, LOT3, scan UCC2     swap, with LOT alloc
*/

   DECLARE @cUCCToBeSwap NVARCHAR(20)
   DECLARE @cUCCToBeSwapStatus NVARCHAR(1)
   SET @cUCCToBeSwap = ''
   SET @cUCCToBeSwapStatus = ''

   -- Get task's PickDetail
   INSERT INTO @tTaskPD (PickDetailKey, QTY)
   SELECT PD.PickDetailKey, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
      AND PD.LOT = @cTaskLOT
      AND PD.LOC = @cTaskLOC
      AND PD.ID = @cTaskID
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get task's PickDetail info
   SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

   -- Check PickDetail changed
   IF @nQTY <> @nTaskSystemQTY
   BEGIN
      SET @n_ErrNo = 124162
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --PKDtl changed
      GOTO Quit
   END

   BEGIN TRAN
   SAVE TRAN isp_1764LblDecode02

   -- 1. Same LOT, don't need to swap
   IF @cTaskLOT = @cUCCLOT
   BEGIN
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cActUCCNo,
            -- Status = '3', -- Pick in-progress
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         FROM dbo.PickDetail PD
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0 OR @@ROWCOUNT = 0
         BEGIN
            SET @n_ErrNo = 124163
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cActUCCNo
         AND Status <> '6' -- Exclude shipped out and re-received
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 124164
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         CaseID = @cActUCCNo,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 124171
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END
      GOTO CommitTran
   END

   -- 2. UCC LOT is not fully allocated
   IF EXISTS( SELECT TOP 1 1 
      FROM LOTxLOCxID WITH (NOLOCK) 
      WHERE LOT = @cUCCLOT
         AND LOC = @cUCCLOC
         AND ID = @cUCCID 
         AND (QTY-QTYAllocated-QTYPicked) >= @nUCCQTY)
   BEGIN
      -- Unallocate
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET
            QTY = 0, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SET @n_ErrNo = @@ERROR
         IF @n_ErrNo <> 0
         BEGIN
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- Reallocate
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET
            -- Status = '3', -- Pick in-progress
            LOT = @cUCCLOT,
            DropID = @cActUCCNo, 
            QTY = @nQTY, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SET @n_ErrNo = @@ERROR
         IF @n_ErrNo <> 0
         BEGIN
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END         

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cActUCCNo
         AND Status <> '6' -- Exclude shipped out and re-received
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 124165
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         CaseID = @cActUCCNo,
         LOT = @cUCCLOT,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 124166
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Booking
      IF @nTaskQTYReplen > 0
      BEGIN
         -- Actual
         UPDATE LOTxLOCxID SET
            QTYReplen = QTYReplen + @nTaskQTYReplen
         WHERE LOT = @cUCCLOT
            AND LOC = @cUCCLOC
            AND ID = @cUCCID 
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 124166
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END
               
         -- Task
         UPDATE LOTxLOCxID SET
            QTYReplen = CASE WHEN (QTYReplen - @nTaskQTYReplen) >= 0 THEN (QTYReplen - @nTaskQTYReplen) ELSE 0 END
         WHERE LOT = @cTaskLOT
            AND LOC = @cTaskLOC
            AND ID = @cTaskID
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 124166
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END
      END
      
      GOTO CommitTran
   END

   -- 3. UCC LOT is fully allocated
   ELSE
   BEGIN
      -- Get actual TaskDetail
      SELECT 
         @cActTaskDetailKey = TaskDetailKey, 
         @nActSystemQTY = SystemQTY, 
         @nActQTYReplen = QTYReplen
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskType = @cTaskType
         AND StorerKey = @c_StorerKey
         AND LOT = @cUCCLOT
         AND FromLOC = @cTaskLOC
         AND FromID = @cTaskID
         AND QTY = @nTaskQTY
         AND Status = '0'
      
      IF @@ROWCOUNT > 0
      BEGIN
         INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
         SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
         FROM PickDetail PD WITH (NOLOCK)
         WHERE PD.TaskDetailKey = @cActTaskDetailKey

         -- Unallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               -- Status = '3', -- Pick in-progress
               LOT = @cUCCLOT,
               DropID = @cActUCCNo, 
               QTY = @nQTY, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END         

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               -- Status = '0', 
               LOT = @cTaskLOT,
               DropID = '', 
               QTY = @nQTY, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END 

         -- Task
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cUCCLOT, 
            CaseID = @cActUCCNo,
            SystemQTY = @nActSystemQTY, 
            QTYReplen = @nActQTYReplen, 
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 124167
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
            GOTO RollBackTran
         END
         
         -- Actual
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cTaskLOT, 
            CaseID = '',
            SystemQTY = @nTaskSystemQTY, 
            QTYReplen = @nTaskQTYReplen, 
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cActTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 124168
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
            GOTO RollBackTran
         END
         
         -- Actual
         UPDATE UCC WITH (ROWLOCK) SET
            Status = '3', -- 3=Allocated
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @c_StorerKey
            AND UCCNo = @cActUCCNo
            AND Status <> '6' -- Exclude shipped out and re-received
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 124169
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
            GOTO RollBackTran
         END

         -- Task
         IF @nActQTYReplen > 0
         BEGIN
            UPDATE LOTxLOCxID SET
               QTYReplen = QTYReplen - @nTaskQTYReplen + @nActQTYReplen 
            WHERE LOT = @cTaskLOT
               AND LOC = @cTaskLOC
               AND ID = @cTaskID
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 124174
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD LLI Fail
               GOTO RollBackTran
            END
         END

         -- Actual
         IF @nTaskQTYReplen > 0
         BEGIN
            UPDATE LOTxLOCxID SET
               QTYReplen = QTYReplen - @nActQTYReplen + @nTaskQTYReplen
            WHERE LOT = @cUCCLOT
               AND LOC = @cUCCLOC
               AND ID = @cUCCID 
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 124175
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD LLI Fail
               GOTO RollBackTran
            END
         END         

         GOTO CommitTran
      END

      -- PickDetail not found
      SET @n_ErrNo = 124170
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --No task ToSwap
      GOTO RollBackTran
   END
   
CommitTran:

   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cActUCCNo

   COMMIT TRAN isp_1764LblDecode02
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_1764LblDecode02
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END -- End Procedure


GO