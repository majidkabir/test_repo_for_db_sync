SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764SwapUCC03                                         */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Swap UCC with same Loc, ID, SKU, L02, L03, L04, L07, L10 & Qty    */
/*                                                                            */
/* Called from:                                                               */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 2020-06-24  1.0  James       WMS-13219. Created                            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764SwapUCC03]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cTaskdetailKey   NVARCHAR( 10),
   @cBarcode         NVARCHAR( 60),
   @cSKU             NVARCHAR( 20)  OUTPUT, 
   @cUCC             NVARCHAR( 20)  OUTPUT, 
   @nUCCQTY          INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
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

   DECLARE @cStorerKey     NVARCHAR( 20)
   DECLARE @cTaskUCCNo     NVARCHAR( 20)
   DECLARE @cTaskUOM       NVARCHAR( 5)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @nTaskPendingMoveIn INT
   DECLARE @cTaskSuggestedLOC  NVARCHAR( 10)

   DECLARE @cActUOM        NVARCHAR( 5)
   DECLARE @cActTaskDetailKey NVARCHAR( 10)
   DECLARE @nActPendingMoveIn INT

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cActPickSlipNo NVARCHAR( 10)
   DECLARE @nActCartonNo   INT
   DECLARE @cActLabelNo    NVARCHAR( 20)
   DECLARE @cActLabelLine  NVARCHAR( 5)

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
   SET @cActUCCNo = @cBarcode

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @nErrNo = 154151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
      GOTO Fail
   END

   -- Get task info
   SELECT
      @cStorerKey = StorerKey, 
      @cTaskUCCNo = CaseID,
      @cTaskUOM = UOM,
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID,
      @cTaskSKU = SKU,
      @nTaskQTY = QTY,
      @nTaskSystemQTY = SystemQTY, 
      @nTaskPendingMoveIn = PendingMoveIn
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 154152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey
      GOTO Fail
   END

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check label scanned is UCC
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 154153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
      GOTO Fail
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 154154
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
      GOTO Fail
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
      AND StorerKey = @cStorerkey

   DECLARE @cTaskL02 NVARCHAR(18)
   DECLARE @cTaskL03 NVARCHAR(18)
   DECLARE @dTaskL04 DATETIME
   DECLARE @cTaskL07 NVARCHAR(30)
   DECLARE @cTaskL10 NVARCHAR(30)
   DECLARE @cUCCL02  NVARCHAR(18)
   DECLARE @cUCCL03  NVARCHAR(18)
   DECLARE @dUCCL04  DATETIME
   DECLARE @cUCCL07  NVARCHAR(30)
   DECLARE @cUCCL10  NVARCHAR(30)

   -- Check UCC status
   IF @cUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @nErrNo = 154155
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status
      GOTO Fail
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cUCCLOC 
   BEGIN
      SET @nErrNo = 154156
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch
      GOTO Fail
   END

   -- Check UCC ID match
   IF @cTaskID <> @cUCCID 
   BEGIN
      SET @nErrNo = 154157
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch
      GOTO Fail
   END

   -- Check SKU match
   IF @cTaskSKU <> @cUCCSKU 
   BEGIN
      SET @nErrNo = 154158
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCSKUNotMatch
      GOTO Fail
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nUCCQTY
   BEGIN
      SET @nErrNo = 154159
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQTYNotMatch
      GOTO Fail
   END

   -- Get L07
   SELECT @cTaskL02 = Lottable02,
          @cTaskL03 = Lottable03,
          @dTaskL04 = Lottable04,
          @cTaskL07 = Lottable07,
          @cTaskL10 = Lottable10
   FROM LotAttribute WITH (NOLOCK)
   WHERE LOT = @cTaskLOT

   SELECT @cUCCL02 = Lottable02,
          @cUCCL03 = Lottable03,
          @dUCCL04 = Lottable04,
          @cUCCL07 = Lottable07,
          @cUCCL10 = Lottable10
   FROM LotAttribute WITH (NOLOCK)
   WHERE LOT = @cUCCLOT

   -- Check UCC L02 match 
   IF @cTaskL02 <> @cUCCL02 
   BEGIN
      SET @nErrNo = 154160
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL02NotMatch
      GOTO Fail
   END

   -- Check UCC L03 match
   IF @cTaskL03 <> @cUCCL03 
   BEGIN
      SET @nErrNo = 154161
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL03NotMatch
      GOTO Fail
   END

   -- Check UCC L04 match
   IF CONVERT( NVARCHAR( 8), @dTaskL04, 112) <> CONVERT( NVARCHAR( 8), @dUCCL04, 112) 
   BEGIN
      SET @nErrNo = 154162
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL04NotMatch
      GOTO Fail
   END

   -- Check UCC L07 match
   IF @cTaskL07 <> @cUCCL07 
   BEGIN
      SET @nErrNo = 154163
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL07NotMatch
      GOTO Fail
   END

   -- Check UCC L10 match
   IF @cTaskL10 <> @cUCCL10 
   BEGIN
      SET @nErrNo = 154164
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL10NotMatch
      GOTO Fail
   END

   -- Check UCC taken by other task
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0)
   BEGIN
      SET @nErrNo = 154165
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther
      GOTO Fail
   END


/*--------------------------------------------------------------------------------------------------

                                                Swap UCC

--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. UCC on own PickDetail      not swap
   2. UCC is not alloc           swap
   3. UCC on other PickDetail    swap
*/
   DECLARE @cUCCToBeSwap   NVARCHAR(20)
   DECLARE @cUCCToBeSwapStatus NVARCHAR(1)
   SET @cUCCToBeSwap = ''
   SET @cUCCToBeSwapStatus = ''

   BEGIN TRAN
   SAVE TRAN rdt_1764SwapUCC03

   -- 1. UCC on own PickDetail
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND DropID = @cActUCCNo AND Status = '0' AND QTY > 0)
   BEGIN
      -- Loop PickDetail
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey
         FROM PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
            AND DropID = @cActUCCNo
            AND Status = '0'
            AND QTY > 0
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '3', -- Pick in-progress
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0 OR @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 154166
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
      GOTO CommitTran
   END

   -- Get task's PickDetail
   INSERT INTO @tTaskPD (PickDetailKey, QTY)
   SELECT PD.PickDetailKey, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
      AND PD.LOT = @cTaskLOT
      AND PD.LOC = @cTaskLOC
      AND PD.ID = @cTaskID
      AND PD.DropID = @cTaskUCCNo
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get task's PickDetail info
   SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

   -- Get task's PackDetail
   SET @cPickSlipNo = ''
   IF @cTaskUOM = '2'
      SELECT
         @cPickSlipNo = PickSlipNo,
         @nCartonNo = CartonNo,
         @cLabelNo = LabelNo,
         @cLabelLine = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND RefNo = @cTaskUCCNo

   -- Check PickDetail changed
   IF @nQTY <> @nTaskSystemQTY
   BEGIN
      SET @nErrNo = 154167
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
      GOTO RollBackTran
   END

   -- 2. UCC is not allocated
   IF EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerkey AND UCCNo = @cActUCCNo AND Status = '1')
   BEGIN
      -- Don't need to swap LOT
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
               Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 154168
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
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
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
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
               Status = '3', -- Pick in-progress
               LOT = @cUCCLOT,
               DropID = @cActUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 154169
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1', -- 1=Received
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 154170
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
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
         SET @nErrNo = 154171
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Booking
      IF @cTaskLOT <> @cUCCLOT
      BEGIN
         IF @nTaskPendingMoveIn > 0
         BEGIN
            SELECT @cTaskSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cTaskDetailKey
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cTaskLOC --FromLOC  
               ,@cTaskID  --FromID  
               ,@cTaskSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cTaskSKU
               ,@nPutawayQTY = @nTaskQTY
               ,@cFromLOT = @cUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END
      END

      -- Task
      IF @cPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail SET
            RefNo = @cActUCCNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 154172
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- Get actual PickDetail
   INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
   SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
      JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
   WHERE UCC.StorerKey = @cStorerkey
      AND PD.StorerKey = @cStorerkey
      AND UCC.UCCNo = @cActUCCNo
      AND UCC.Status = '3'
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get actual PickDetail info
   SET @nRowCount = @@ROWCOUNT
   SELECT @cActTaskDetailKey = TaskDetailKey FROM @tActPD

   -- Get actual task
   SELECT 
      @cActUOM = UOM, 
      @nActPendingMoveIn = PendingMoveIn
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cActTaskDetailKey

   -- Get actual PackDetail
   SET @cActPickSlipNo = ''
   IF @cActUOM = '2'
      SELECT
         @cActPickSlipNo = PickSlipNo,
         @nActCartonNo = CartonNo,
         @cActLabelNo = LabelNo,
         @cActLabelLine = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND RefNo = @cActUCCNo

   -- 3. UCC on other PickDetail
   IF @nRowCount > 0
   BEGIN
      -- Don't need to swap LOT
      IF @cTaskLOT = @cUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cActUCCNo,
               Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 154173
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cTaskUCCNo,
               Status = '0',
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 154174
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
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
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
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
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
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
               Status = '3', -- Pick in-progress
               LOT = @cUCCLOT,
               DropID = @cActUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
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
               Status = '0',
               LOT = @cTaskLOT,
               DropID = @cTaskUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         LOT = @cUCCLOT,
         CaseID = @cActUCCNo,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 154175
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         LOT = @cTaskLOT,
         CaseID = @cTaskUCCNo,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cActTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 154176
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Booking
      IF @cTaskLOT <> @cUCCLOT
      BEGIN
         IF @nTaskPendingMoveIn > 0
         BEGIN
            SELECT @cTaskSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cTaskDetailKey
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cTaskLOC --FromLOC  
               ,@cTaskID  --FromID  
               ,@cTaskSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cTaskSKU
               ,@nPutawayQTY = @nTaskQTY
               ,@cFromLOT = @cUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
            DECLARE @cActSuggestedLOC NVARCHAR( 10)
            SELECT @cActSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cActTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cActTaskDetailKey  
            IF @nErrNo <> 0
               GOTO RollbackTran
               
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cUCCLOC --FromLOC  
               ,@cUCCID  --FromID  
               ,@cActSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cUCCSKU
               ,@nPutawayQTY = @nUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END
      END

      -- Task
      IF @cPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail WITH (ROWLOCK) SET
            RefNo = @cActUCCNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 154177
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      -- Actual
      IF @cActPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail WITH (ROWLOCK) SET
            RefNo = @cTaskUCCNo
         WHERE PickSlipNo = @cActPickSlipNo
            AND CartonNo = @nActCartonNo
            AND LabelNo = @cActLabelNo
            AND LabelLine = @cActLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 154178
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- PickDetail not found
   SET @nErrNo = 154179
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PKDtl Found
   GOTO RollBackTran

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @cStorerkey

      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cTaskUCCNo, @cActUCCNo, @cTaskDetailKey, @cTaskUCCStatus, @cUCCStatus)
   END

   SET @cSKU = @cUCCSKU
   SET @nUCCQTY = @nUCCQTY
   SET @cUCC = @cActUCCNo

   COMMIT TRAN rdt_1764SwapUCC03
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764SwapUCC03
Fail:
   SET @nUCCQTY = 0 
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO