SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764SwapUCC09                                         */
/* Copyright      : Maersk                                                    */
/* Customer: Levis                                                            */
/*                                                                            */
/* Date       Rev  Author    Purposes                                         */
/* 2024-12-06 1.0  JCH507    FCR-1157 for levis (based on rdt_1764SwapUCC07)  */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1764SwapUCC09
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

   DECLARE @bDebugFlag     BINARY = 0

   DECLARE @nRowCount      INT
   DECLARE @nTranCount     INT

   DECLARE @cActUCCNo            NVARCHAR( 20)
   DECLARE @cActUCCSKU           NVARCHAR( 20)
   DECLARE @cActUCCLOT           NVARCHAR( 10)
   DECLARE @cActUCCLOC           NVARCHAR( 10)
   DECLARE @cActUCCID            NVARCHAR( 18)
   DECLARE @cActUCCStatus        NVARCHAR( 1)
   DECLARE @cActTaskDetailKey    NVARCHAR( 10)
   DECLARE @nActUCCQTY           INT
   DECLARE @nActSystemQTY        INT
   DECLARE @nActPendingMoveIn    INT
   DECLARE @cActUOM              NVARCHAR( 5)
   DECLARE @cActSuggestedLOC     NVARCHAR( 10)

   DECLARE @cTaskType            NVARCHAR( 10)
   DECLARE @cTaskUCCNo           NVARCHAR( 20)
   DECLARE @cTaskUOM             NVARCHAR( 5)
   DECLARE @cTaskLOT             NVARCHAR( 10)
   DECLARE @cTaskLOC             NVARCHAR( 10)
   DECLARE @cTaskID              NVARCHAR( 18)
   DECLARE @cTaskSKU             NVARCHAR( 20)
   DECLARE @nTaskQTY             INT
   DECLARE @nTaskSystemQTY       INT
   DECLARE @nTaskPendingMoveIn   INT
   DECLARE @cTaskSuggestedLOC    NVARCHAR( 10)

   DECLARE @cStorerKey     NVARCHAR( 20)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cDocType       NVARCHAR( 1)
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

   IF @bDebugFlag = 1
      SELECT '1764SwapUCC09', @cActUCCNo AS ActUCCNo, @cTaskdetailKey AS OriginalTaskKey 

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @nErrNo = 230351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
      GOTO Fail
   END

   -- Check double scan when same task already have ucc scanned
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) 
              WHERE TaskDetailKey = @cTaskDetailKey 
              AND   UCCNo <> '')
   BEGIN
      SET @nErrNo = 230351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
      GOTO Fail
   END
   
   -- Get task info
   SELECT
      @cStorerKey = StorerKey,
      @cTaskType = TaskType,
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
      SET @nErrNo = 230352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey
      GOTO Fail
   END

   IF @bDebugFlag = 1
      SELECT 'Get Original Task', @cTaskUCCNo AS TaskUCCNo

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check label scanned is UCC
 IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 230353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an UCC
      GOTO Fail
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 230354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
      GOTO Fail
   END

   -- Get scanned UCC info
   SELECT
      @cActUCCSKU = SKU,
      @nActUCCQTY = QTY,
      @cActUCCLOT = LOT,
      @cActUCCLOC = LOC,
      @cActUCCID = ID,
      @cActUCCStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check UCC status
   IF @cActUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @nErrNo = 230355
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status
      GOTO Fail
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cActUCCLOC
   BEGIN
      SET @nErrNo = 230356
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch
      GOTO Fail
   END

   -- Check UCC ID match
   IF @cTaskID <> @cActUCCID
   BEGIN
      SET @nErrNo = 230357
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch
      GOTO Fail
   END

   -- Check SKU match
   IF @cTaskSKU <> @cActUCCSKU
   BEGIN
      SET @nErrNo = 230358
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCSKUNotMatch
      GOTO Fail
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nActUCCQTY
   BEGIN
      SET @nErrNo = 230359
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQTYNotMatch
      GOTO Fail
   END

   --v1.0
   -- Check UCC Lot Match
   IF @cTaskLOT <> @cActUCCLOT
   BEGIN
      SET @nErrNo = 230363
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLotNotMatch
      GOTO Fail
   END
   --v1.0 end

   --DECLARE
   --   @cChkL01 NVARCHAR(1) = '0', @cTaskL01 NVARCHAR(18), @cUCCL01 NVARCHAR(18),
   --   @cChkL02 NVARCHAR(1) = '0', @cTaskL02 NVARCHAR(18), @cUCCL02 NVARCHAR(18),
   --   @cChkL03 NVARCHAR(1) = '0', @cTaskL03 NVARCHAR(18), @cUCCL03 NVARCHAR(18),
   --   @cChkL04 NVARCHAR(1) = '0', @dTaskL04 DATETIME,     @dUCCL04 DATETIME,
   --   @cChkL05 NVARCHAR(1) = '0', @dTaskL05 DATETIME,     @dUCCL05 DATETIME,
   --   @cChkL06 NVARCHAR(1) = '0', @cTaskL06 NVARCHAR(18), @cUCCL06 NVARCHAR(18),
   --   @cChkL07 NVARCHAR(1) = '0', @cTaskL07 NVARCHAR(18), @cUCCL07 NVARCHAR(18),
   --   @cChkL08 NVARCHAR(1) = '0', @cTaskL08 NVARCHAR(18), @cUCCL08 NVARCHAR(18),
   --   @cChkL09 NVARCHAR(1) = '0', @cTaskL09 NVARCHAR(18), @cUCCL09 NVARCHAR(18),
   --   @cChkL10 NVARCHAR(1) = '0', @cTaskL10 NVARCHAR(18), @cUCCL10 NVARCHAR(18),
   --   @cChkL11 NVARCHAR(1) = '0', @cTaskL11 NVARCHAR(18), @cUCCL11 NVARCHAR(18),
   --   @cChkL12 NVARCHAR(1) = '0', @cTaskL12 NVARCHAR(18), @cUCCL12 NVARCHAR(18),
   --   @cChkL13 NVARCHAR(1) = '0', @dTaskL13 DATETIME,     @dUCCL13 DATETIME,
   --   @cChkL14 NVARCHAR(1) = '0', @dTaskL14 DATETIME,     @dUCCL14 DATETIME,
   --   @cChkL15 NVARCHAR(1) = '0', @dTaskL15 DATETIME,     @dUCCL15 DATETIME

   -- Get facility
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   ---- Get check lottable setting
   --SELECT
   --   @cChkL01 = CASE WHEN Code = 'Lottable01' THEN '1' ELSE @cChkL01 END,
   --   @cChkL02 = CASE WHEN Code = 'Lottable02' THEN '1' ELSE @cChkL02 END,
   --   @cChkL03 = CASE WHEN Code = 'Lottable03' THEN '1' ELSE @cChkL03 END,
   --   @cChkL04 = CASE WHEN Code = 'Lottable04' THEN '1' ELSE @cChkL04 END,
   --   @cChkL05 = CASE WHEN Code = 'Lottable05' THEN '1' ELSE @cChkL05 END,
   --   @cChkL06 = CASE WHEN Code = 'Lottable06' THEN '1' ELSE @cChkL06 END,
   --   @cChkL07 = CASE WHEN Code = 'Lottable07' THEN '1' ELSE @cChkL07 END,
   --   @cChkL08 = CASE WHEN Code = 'Lottable08' THEN '1' ELSE @cChkL08 END,
   --   @cChkL09 = CASE WHEN Code = 'Lottable09' THEN '1' ELSE @cChkL09 END,
   --   @cChkL10 = CASE WHEN Code = 'Lottable10' THEN '1' ELSE @cChkL10 END,
   --   @cChkL11 = CASE WHEN Code = 'Lottable11' THEN '1' ELSE @cChkL11 END,
   --   @cChkL12 = CASE WHEN Code = 'Lottable12' THEN '1' ELSE @cChkL12 END,
   --   @cChkL13 = CASE WHEN Code = 'Lottable13' THEN '1' ELSE @cChkL13 END,
   --   @cChkL14 = CASE WHEN Code = 'Lottable14' THEN '1' ELSE @cChkL14 END,
   --   @cChkL15 = CASE WHEN Code = 'Lottable15' THEN '1' ELSE @cChkL15 END
   --FROM dbo.CodeLKUP WITH (NOLOCK)
   --WHERE ListName = 'SwapUCC'
   --   AND StorerKey = @cStorerKey
   --   AND Code2 = @cFacility

   ---- Get task lottable
   --SELECT
   --   @cTaskL01 = Lottable01, @cTaskL02 = Lottable02, @cTaskL03 = Lottable03, @dTaskL04 = Lottable04, @dTaskL05 = Lottable05,
   --   @cTaskL06 = Lottable06, @cTaskL07 = Lottable07, @cTaskL08 = Lottable08, @cTaskL09 = Lottable09, @cTaskL10 = Lottable10,
   --   @cTaskL11 = Lottable11, @cTaskL12 = Lottable12, @dTaskL13 = Lottable13, @dTaskL14 = Lottable14, @dTaskL15 = Lottable15
   --FROM LotAttribute WITH (NOLOCK)
   --WHERE LOT = @cTaskLOT

   ---- Get UCC lottable
   --SELECT
   --   @cUCCL01 = Lottable01, @cUCCL02 = Lottable02, @cUCCL03 = Lottable03, @dUCCL04 = Lottable04, @dUCCL05 = Lottable05,
   --   @cUCCL06 = Lottable06, @cUCCL07 = Lottable07, @cUCCL08 = Lottable08, @cUCCL09 = Lottable09, @cUCCL10 = Lottable10,
   --   @cUCCL11 = Lottable11, @cUCCL12 = Lottable12, @dUCCL13 = Lottable13, @dUCCL14 = Lottable14, @dUCCL15 = Lottable15
   --FROM LotAttribute WITH (NOLOCK)
   --WHERE LOT = @cActUCCLOT

   -- Check all lottables
   --DECLARE @nLottableNo INT = 0
   --IF @nLottableNo = 0 AND @cChkL01= '1' AND @cTaskL01 <> @cUCCL01 SET @nLottableNo =  1 ELSE
   --IF @nLottableNo = 0 AND @cChkL02= '1' AND @cTaskL02 <> @cUCCL02 SET @nLottableNo =  2 ELSE
   --IF @nLottableNo = 0 AND @cChkL03= '1' AND @cTaskL03 <> @cUCCL03 SET @nLottableNo =  3 ELSE
   --IF @nLottableNo = 0 AND @cChkL04= '1' AND @dTaskL04 <> @dUCCL04 SET @nLottableNo =  4 ELSE
   --IF @nLottableNo = 0 AND @cChkL05= '1' AND @dTaskL05 <> @dUCCL05 SET @nLottableNo =  5 ELSE
   --IF @nLottableNo = 0 AND @cChkL06= '1' AND @cTaskL06 <> @cUCCL06 SET @nLottableNo =  6 ELSE
   --IF @nLottableNo = 0 AND @cChkL07= '1' AND @cTaskL07 <> @cUCCL07 SET @nLottableNo =  7 ELSE
   --IF @nLottableNo = 0 AND @cChkL08= '1' AND @cTaskL08 <> @cUCCL08 SET @nLottableNo =  8 ELSE
   --IF @nLottableNo = 0 AND @cChkL09= '1' AND @cTaskL09 <> @cUCCL09 SET @nLottableNo =  9 ELSE
   --IF @nLottableNo = 0 AND @cChkL10= '1' AND @cTaskL10 <> @cUCCL10 SET @nLottableNo = 10 ELSE
   --IF @nLottableNo = 0 AND @cChkL11= '1' AND @cTaskL11 <> @cUCCL11 SET @nLottableNo = 11 ELSE
   --IF @nLottableNo = 0 AND @cChkL12= '1' AND @cTaskL12 <> @cUCCL12 SET @nLottableNo = 12 ELSE
   --IF @nLottableNo = 0 AND @cChkL13= '1' AND @dTaskL13 <> @dUCCL13 SET @nLottableNo = 13 ELSE
   --IF @nLottableNo = 0 AND @cChkL14= '1' AND @dTaskL14 <> @dUCCL14 SET @nLottableNo = 14 ELSE
   --IF @nLottableNo = 0 AND @cChkL15= '1' AND @dTaskL15 <> @dUCCL15 SET @nLottableNo = 15

   ---- Validate lottable
   --IF @nLottableNo > 0
   --BEGIN
   --   SET @nErrNo = 166410
   --   SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --Not match L99
   --   GOTO Fail
   --END

   ---- Check UCC taken by other (PickDetail)
   --IF EXISTS( SELECT TOP 1 1
   --   FROM UCC WITH (NOLOCK)
   --      JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
   --   WHERE UCC.StorerKey = @cStorerkey
   --      AND PD.StorerKey = @cStorerkey
   --      AND UCC.UCCNo = @cActUCCNo
   --      AND PD.Status > '0'
   --      AND PD.QTY > 0)
   --BEGIN
   --   SET @nErrNo = 166411
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther
   --   GOTO Fail
   --END

   ---- Check UCC taken by other (TaskDetail)
   --IF EXISTS( SELECT TOP 1 1
   --   FROM UCC WITH (NOLOCK)
   --   JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.UCCNo = TD.DropID)
   --   WHERE UCC.StorerKey = @cStorerkey
   --      AND TD.StorerKey = @cStorerkey
   --      AND UCC.UCCNo = @cActUCCNo
   --      AND TD.Status > '0'
   --      AND TD.QTY > 0
   --      AND TD.EditWho <> SUSER_SNAME())
   --BEGIN
   --   SET @nErrNo = 166412
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther
   --   GOTO Fail
   --END


/*--------------------------------------------------------------------------------------------------

                                                Swap UCC

--------------------------------------------------------------------------------------------------*/
/*
   Task dispatched:
   UCC to replenish (without PickDetail)
   UCC to pick (with PickDetail)

   Actual UCC scanned:
   UCC free from replenish and alloc
   UCC with replenish
   UCC with alloc

   All scenarios:
   0. UCC on task = UCC taken, no swap
   1. UCC to replenish, swap UCC free
   2. UCC to replenish, swap UCC with replenish
   3. UCC to replenish, swap UCC with alloc
   4. UCC to pick, swap UCC free
   5. UCC to pick, swap UCC with replenish
   6. UCC to pick, swap UCC with alloc
*/

   DECLARE @cTaskUCCType   NVARCHAR(10)
   DECLARE @cActUCCType    NVARCHAR(10)

   BEGIN TRAN
   SAVE TRAN rdt_1764SwapUCC09

   ---- 0. UCC on task = UCC taken, no swap
   IF @cTaskUCCNo = @cActUCCNo
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Same UCC, Quit'

      GOTO CommitTran
   END

   -- Get actual task info
   SET @cActTaskDetailKey = ''
   SET @nActSystemQTY = ''
   SET @nActPendingMoveIn = 0
   SET @cActUOM = ''
   SELECT
      @cActTaskDetailKey = TaskDetailKey,
      @nActSystemQTY = SystemQTY,
      @nActPendingMoveIn = PendingMoveIn,
      @cActUOM = UOM
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskType = @cTaskType
      AND CaseID = @cActUCCNo
      AND Status = '0'

   -- Get task UCC type
   IF @nTaskSystemQTY > 0
      SET @cTaskUCCType = 'PICK'   -- means with PickDetail
   ELSE
      SET @cTaskUCCType = 'REPLEN' -- means no PickDetail

   IF @bDebugFlag = 1
      SELECT 'TaskUCCType', @nTaskSystemQTY AS TaskSystemQty, @cTaskUCCType AS TaskUCCType

   -- Get actual UCC type
   SET @cActUCCType = ''
   IF @cActTaskDetailKey = ''  AND @cActUCCStatus = '1' SET @cActUCCType = 'FREE'   ELSE  -- means no TaskDetail
   IF @cActTaskDetailKey <> '' AND @cActUCCStatus = '1' SET @cActUCCType = 'REPLEN' ELSE  -- means no PickDetail
   IF @cActTaskDetailKey <> '' AND @cActUCCStatus = '3' SET @cActUCCType = 'PICK'         -- means with PickDetail

   IF @bDebugFlag = 1
      SELECT 'ActUCCType', @cActTaskDetailKey AS ActTaskKey, @cActUCCStatus AS ActUCCStatus, @cActUCCType AS ActUCCType

   -- Check actual UCC type
   IF @cActUCCType = ''
   BEGIN
      SET @nErrNo = 230364
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ActUCCTypeFail
      GOTO RollBackTran
   END

   -- 1. UCC to replenish, swap UCC free
   IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'FREE'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'TaskUCCType = REPL and ActUCCType = FREE'

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cActUCCLOT,
            CaseID = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME(),
            TrafficCop = NULL
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230365
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Swap Lot'
         IF @nTaskPendingMoveIn > 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'TaskPendingMoveIn>0, Lock & unlock locs'

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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END
   END

   -- 2. UCC to replenish, swap UCC with replenish
   ELSE IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'REPLEN'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'TaskUCCType = REPLEN and ACTUCCType = REPLEN'

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cActUCCLOT,
            CaseID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Actual
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cTaskLOT,
            CaseID = @cTaskUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cActTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230367
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Swap lot'
         IF @nTaskPendingMoveIn > 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'TaskPendingMoveIn>0, Lock & unlock locs'

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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'ActTaskPendingMoveIn>0, Lock & unlock locs'

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
               ,@cActUCCLOC --FromLOC
               ,@cActUCCID  --FromID
               ,@cActSuggestedLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- 3. UCC to replenish, swap UCC with alloc
   ELSE IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'PICK'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'TaskUCCType = REPLEN and ActUCCType = PICK'

      -- Get actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND UCC.Status = '3'
         --AND PD.Status = '0'
         AND PD.QTY > 0

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tActPD

      IF @bDebugFlag = 1
      BEGIN
         SELECT '@tActPD'
         SELECT * FROM @tActPD
         SELECT 'Compare PKD Qty', @nQTY AS Qty, @nActSystemQTY AS ActSystemQty
      END

      -- Check PickDetail changed
      IF @nQTY <> @nActSystemQTY
      BEGIN
         SET @nErrNo = 230368
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'No lot swaping'
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Update ActUCC PKD', @cPickDetailKey

            -- Update PickDetail
            UPDATE dbo.PickDetail SET
               DropID = @cTaskUCCNo,
               --CaseID = CASE WHEN @cActUOM = '2' THEN @cTaskUCCNo ELSE CaseID END, --v1.0
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME(),
               TrafficCop = NULL
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 230369
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Swap lot'

         -- Unallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Unallocate ActUCCNo PKD', @cPickDetailKey

            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
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
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'reallocate ActUCCNo PKD', @cPickDetailKey, @nQTY

            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               LOT = @cTaskLOT,
               DropID = @cTaskUCCNo,
               --CaseID = CASE WHEN @cActUOM = '2' THEN @cTaskUCCNo ELSE CaseID END, --v1.0
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

      --V1.0
      -- No PackData in Levis automation
      /*
      -- PackDetail
      IF @cActUOM = '2' -- Full carton to outbound
         AND EXISTS (SELECT 1
                     FROM @tActPD A
                     JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                     JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE PD.Storerkey = @cStorerKey
                     AND O.DocType = 'N') --Only required for B2B Full carton
      BEGIN
         SELECT
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo,
            @cLabelLine = LabelLine
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cActUCCNo
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 166442
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingPackDtl
            GOTO RollBackTran
         END

         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 166443
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DUP PackDtl
            GOTO RollBackTran
         END

         UPDATE PackDetail SET
            LabelNo = @cTaskUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cActUCCNo
            AND LabelLine = @cLabelLine
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      */
      --V1.0 end

      -- Task
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '3', -- 3=Allocated
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cTaskUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230370
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH

      -- Actual
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '1', -- 1=Received
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cActUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230371
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cActUCCLOT,
            CaseID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230372
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Actual
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cTaskLOT,
            CaseID = @cTaskUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cActTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230373
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Rebook Locs due to switch lot'
         
         IF @nTaskPendingMoveIn > 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Rebook Original Task'

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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Rebook ActTask'
               
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
               ,@cActUCCLOC --FromLOC
               ,@cActUCCID  --FromID
               ,@cActSuggestedLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- 4. UCC to pick, swap UCC free
   ELSE IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'FREE'
   BEGIN
      -- Get task's PickDetail
      INSERT INTO @tTaskPD (PickDetailKey, QTY)
      SELECT PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.LOT = @cTaskLOT
         AND PD.LOC = @cTaskLOC
         AND PD.ID = @cTaskID
         AND PD.DropID = @cTaskUCCNo
         --AND PD.Status = '0'
         AND PD.QTY > 0

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty
      /*
      -- Check PickDetail changed
      IF @nQTY <> @nTaskSystemQTY
      BEGIN
         SET @nErrNo = 230374
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END
      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty end
      */

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail SET
               DropID = @cActUCCNo,
               --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END, --v1.0
               --Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 230375
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
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  QTY = 0,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  --Status = '3', -- Pick in-progress
                  LOT = @cActUCCLOT,
                  DropID = @cActUCCNo,
                  --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END,-- V1.0
                  QTY = @nQTY,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      --V1.0 No Pack data for levis
      -- PackDetail
      /*
      IF @cTaskUOM = '2' -- Full carton to outbound
         AND EXISTS (SELECT 1
                     FROM @tTaskPD A
                     JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                     JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE PD.Storerkey = @cStorerKey
                     AND O.DocType = 'N') --Only required for B2B Full carton
      BEGIN
         SELECT
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo,
            @cLabelLine = LabelLine
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cTaskUCCNo
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 230394
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingPackDtl
            GOTO RollBackTran
         END

         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 230395
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DUP PackDtl
            GOTO RollBackTran
         END

         UPDATE PackDetail SET
            LabelNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cTaskUCCNo
            AND LabelLine = @cLabelLine
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      */
      --v1.0 end

      -- Actual
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '3', -- 3=Allocated
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cActUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230376
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH

      -- Task
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '1', -- 1=Received
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cTaskUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230377
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            CaseID = @cActUCCNo,
            LOT = @cActUCCLOT,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230378
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   --5. UCC to pick, swap UCC with replenish
   ELSE IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'REPLEN'
   BEGIN
      -- Get task's PickDetail
      INSERT INTO @tTaskPD (PickDetailKey, QTY)
      SELECT PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.LOT = @cTaskLOT
         AND PD.LOC = @cTaskLOC
         AND PD.ID = @cTaskID
         AND PD.DropID = @cTaskUCCNo
         --AND PD.Status = '0'
         AND PD.QTY > 0

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

      -- Check PickDetail changed
      IF @nQTY <> @nTaskSystemQTY
      BEGIN
         SET @nErrNo = 230379
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               DropID = @cActUCCNo,
               --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END, --v1.0
               --Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 230380
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
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  QTY = 0,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
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
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  --Status = '3', -- Pick in-progress
                  LOT = @cActUCCLOT,
                  DropID = @cActUCCNo,
                  --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END, --v1.0
                  QTY = @nQTY,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      --V1.0 No Pack data for levis
      /*
      -- PackDetail
      IF @cTaskUOM = '2' -- Full carton to outbound
      AND EXISTS (SELECT TOP 1 1
                  FROM @tTaskPD A
                  JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                  JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.Storerkey = @cStorerKey
                  AND O.DocType = 'N') --Only required for B2B Full carton
      BEGIN
         SELECT
            @cPickSlipNo = PickSlipNo,
            @nCartonNo = CartonNo,
            @cLabelLine = LabelLine
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cTaskUCCNo
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 230396
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingPackDtl
            GOTO RollBackTran
         END

         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 230397
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DUP PackDtl
            GOTO RollBackTran
         END

         UPDATE PackDetail SET
            LabelNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cTaskUCCNo
            AND LabelLine = @cLabelLine
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      */
      --V1.0 end

      -- ZG01 (Start)
      -- Actual
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '3', -- 3=Allocated
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cActUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230390
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH

      -- Task
      BEGIN TRY
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '1', -- 1=Received
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE StorerKey = @cStorerkey
            AND UCCNo = @cTaskUCCNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230391
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END CATCH
      -- ZG01 (End)

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cActUCCLOT,
            CaseID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230381
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Actual
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cTaskLOT,
            CaseID = @cTaskUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cActTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230382
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
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
               ,@cActUCCLOC --FromLOC
               ,@cActUCCID  --FromID
               ,@cActSuggestedLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- 6. UCC to pick, swap UCC with alloc
   ELSE IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'PICK'
   BEGIN
      -- Get task's PickDetail
      INSERT INTO @tTaskPD (PickDetailKey, QTY)
      SELECT PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.LOT = @cTaskLOT
         AND PD.LOC = @cTaskLOC
         AND PD.ID = @cTaskID
         AND PD.DropID = @cTaskUCCNo
         --AND PD.Status = '0'
         AND PD.QTY > 0

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty
      /*
      -- Check PickDetail changed
      IF @nQTY <> @nTaskSystemQTY
      BEGIN
         SET @nErrNo = 230383
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END
      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty END
      */

      -- Get actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND UCC.Status = '3'
         --AND PD.Status = '0'
         AND PD.QTY > 0

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tActPD

      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty
      /*
      -- Check PickDetail changed
      IF @nQTY <> @nActSystemQTY
      BEGIN
         SET @nErrNo = 230384
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END
      --V1.0 Remove the check since Levi's RPF tasy systm qty <> PickDetail Qty END
      */

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               DropID = @cActUCCNo,
               --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END,--v1.0
               --Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 230385
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
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               DropID = @cTaskUCCNo,
               --CaseID = CASE WHEN @cActUOM = '2' THEN @cTaskUCCNo ELSE CaseID END, --v1.0
               Status = '0',
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 230386
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
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  QTY = 0,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  QTY = 0,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
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
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  --Status = '3', -- Pick in-progress
                  LOT = @cActUCCLOT,
                  DropID = @cActUCCNo,
                  --CaseID = CASE WHEN @cTaskUOM = '2' THEN @cActUCCNo ELSE CaseID END, --v1.0
                  QTY = @nQTY,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            BEGIN TRY
               UPDATE dbo.PickDetail WITH(ROWLOCK) SET
                  Status = '0',
                  LOT = @cTaskLOT,
                  DropID = @cTaskUCCNo,
                  --CaseID = CASE WHEN @cActUOM = '2' THEN @cTaskUCCNo ELSE CaseID END, --v1.0
                  QTY = @nQTY,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
            END TRY
            BEGIN CATCH
               SET @nErrNo = @@ERROR
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END CATCH
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      --V1.0 No Pack data for levis
      /*
      -- PackDetail
      IF @cTaskUOM = '2' OR -- Full carton to outbound
         @cActUOM  = '2'
      BEGIN
         -- Task (find out which PackDetail line)
         IF @cTaskUOM = '2'
          AND EXISTS (SELECT TOP 1 1
                  FROM @tTaskPD A
          JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                  JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.Storerkey = @cStorerKey
                  AND O.DocType = 'N') --Only required for B2B Full carton
         BEGIN
            SELECT
               @cPickSlipNo = PickSlipNo,
               @nCartonNo = CartonNo,
               @cLabelLine = LabelLine
            FROM PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LabelNo = @cTaskUCCNo
            SET @nRowCount = @@ROWCOUNT

            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 230398
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingPackDtl
               GOTO RollBackTran
            END

            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 230399
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DUP PackDtl
               GOTO RollBackTran
            END
         END

         -- Actual (find out which PackDetail line)
         IF @cActUOM = '2'
         AND EXISTS (SELECT TOP 1 1
                  FROM @tActPD A
                  JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                  JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.Storerkey = @cStorerKey
                  AND O.DocType = 'N') --Only required for B2B Full carton
         BEGIN
            DECLARE @cActPickSlipNo NVARCHAR(10)
            DECLARE @nActCartonNo   INT
            DECLARE @cActLabelLine  NVARCHAR(5)
            SELECT
               @cActPickSlipNo = PickSlipNo,
               @nActCartonNo = CartonNo,
               @cActLabelLine = LabelLine
            FROM PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LabelNo = @cActUCCNo
            SET @nRowCount = @@ROWCOUNT

            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 230400
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissingPackDtl
               GOTO RollBackTran
            END

            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 230402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DUP PackDtl
               GOTO RollBackTran
            END
         END

         -- Task (swap base on PackDetail found)
         IF @cTaskUOM = '2'
         AND EXISTS (SELECT TOP 1 1
                  FROM @tTaskPD A
                  JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                  JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.Storerkey = @cStorerKey
                  AND O.DocType = 'N') --Only required for B2B Full carton
         BEGIN
            UPDATE PackDetail SET
               LabelNo = @cActUCCNo,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cTaskUCCNo
               AND LabelLine = @cLabelLine
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END

         -- Actual
         IF @cActUOM = '2'
         AND EXISTS (SELECT TOP 1 1
                  FROM @tActPD A
                  JOIN pickDetail PD WITH (NOLOCK) ON (A.PickDetailKey = PD.PickDetailKey)
                  JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.Storerkey = @cStorerKey
                  AND O.DocType = 'N') --Only required for B2B Full carton
         BEGIN
            UPDATE PackDetail SET
               LabelNo = @cTaskUCCNo,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickSlipNo = @cActPickSlipNo
               AND CartonNo = @nActCartonNo
               AND LabelNo = @cActUCCNo
               AND LabelLine = @cActLabelLine
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END
      END
      */
      --V1.0 end

      -- Task
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cActUCCLOT,
            CaseID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230387
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Actual
      BEGIN TRY
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            LOT = @cTaskLOT,
            CaseID = @cTaskUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE TaskDetailKey = @cActTaskDetailKey
      END TRY
      BEGIN CATCH
         SET @nErrNo = 230388
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END CATCH

      -- Booking
      IF @cTaskLOT <> @cActUCCLOT
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
               ,@cFromLOT = @cActUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
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
               ,@cActUCCLOC --FromLOC
               ,@cActUCCID  --FromID
               ,@cActSuggestedLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- Data error (not in the 7 scenarios)
   ELSE
   BEGIN
      SET @nErrNo = 230389
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data error
      GOTO RollBackTran
   END

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @cStorerkey

      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cTaskUCCNo, @cActUCCNo, @cTaskDetailKey, @cTaskUCCStatus, @cActUCCStatus)
   END

   SET @cSKU = @cActUCCSKU
   SET @nUCCQTY = @nActUCCQTY
   SET @cUCC = @cActUCCNo

   COMMIT TRAN rdt_1764SwapUCC09
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764SwapUCC09
Fail:
   SET @nUCCQTY = 0
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO