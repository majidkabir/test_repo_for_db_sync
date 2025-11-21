SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/      
/* Store procedure: rdt_1764SwapUCC04                                         */      
/* Copyright      : LF Logistics                                              */      
/*                                                                            */      
/* Purpose: Swap ucc and update packdetail labelno from pickdetail.case id    */
/*          Only for full case ucc (UOM = 2)                                  */
/*                                                                            */
/* Date       Rev  Author    Purposes                                         */      
/* 2020-04-15 1.0  James     WMS-12480 Created (based on rdt_1764SwapUCC02)   */      
/******************************************************************************/      

CREATE PROCEDURE [RDT].[rdt_1764SwapUCC04]      
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

   DECLARE @tUpdPack TABLE      
   (      
      PickDetailKey NVARCHAR( 10) NOT NULL,      
      PRIMARY KEY CLUSTERED (PickDetailKey)      
   )      

   SET @nTranCount = @@TRANCOUNT      
   SET @cActUCCNo = @cBarcode      
      
   -- Check double scan      
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)      
   BEGIN      
      SET @nErrNo = 159751      
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
      SET @nErrNo = 159752      
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
      SET @nErrNo = 159753      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an UCC      
      GOTO Fail      
   END      
      
   -- Check multi SKU UCC      
   IF @nRowCount > 1      
   BEGIN      
      SET @nErrNo = 159754      
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
      SET @nErrNo = 159755      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status      
      GOTO Fail      
   END      
      
   -- Check UCC LOC match      
   IF @cTaskLOC <> @cActUCCLOC      
   BEGIN      
      SET @nErrNo = 159756      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch      
      GOTO Fail      
   END      
      
   -- Check UCC ID match      
   IF @cTaskID <> @cActUCCID      
   BEGIN      
      SET @nErrNo = 159757      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch      
      GOTO Fail      
   END      
      
   -- Check SKU match      
   IF @cTaskSKU <> @cActUCCSKU      
   BEGIN      
      SET @nErrNo = 159758      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCSKUNotMatch      
      GOTO Fail      
   END      
      
   -- Check UCC QTY match      
   IF @nTaskQTY <> @nActUCCQTY      
   BEGIN      
      SET @nErrNo = 159759      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQTYNotMatch      
      GOTO Fail      
   END      
      
   DECLARE       
      @cChkL01 NVARCHAR(1) = '0', @cTaskL01 NVARCHAR(18), @cUCCL01 NVARCHAR(18),       
      @cChkL02 NVARCHAR(1) = '0', @cTaskL02 NVARCHAR(18), @cUCCL02 NVARCHAR(18),       
      @cChkL03 NVARCHAR(1) = '0', @cTaskL03 NVARCHAR(18), @cUCCL03 NVARCHAR(18),       
      @cChkL04 NVARCHAR(1) = '0', @dTaskL04 DATETIME,     @dUCCL04 DATETIME,       
      @cChkL05 NVARCHAR(1) = '0', @dTaskL05 DATETIME,     @dUCCL05 DATETIME,       
      @cChkL06 NVARCHAR(1) = '0', @cTaskL06 NVARCHAR(18), @cUCCL06 NVARCHAR(18),       
      @cChkL07 NVARCHAR(1) = '0', @cTaskL07 NVARCHAR(18), @cUCCL07 NVARCHAR(18),       
      @cChkL08 NVARCHAR(1) = '0', @cTaskL08 NVARCHAR(18), @cUCCL08 NVARCHAR(18),       
      @cChkL09 NVARCHAR(1) = '0', @cTaskL09 NVARCHAR(18), @cUCCL09 NVARCHAR(18),       
      @cChkL10 NVARCHAR(1) = '0', @cTaskL10 NVARCHAR(18), @cUCCL10 NVARCHAR(18),       
      @cChkL11 NVARCHAR(1) = '0', @cTaskL11 NVARCHAR(18), @cUCCL11 NVARCHAR(18),       
      @cChkL12 NVARCHAR(1) = '0', @cTaskL12 NVARCHAR(18), @cUCCL12 NVARCHAR(18),       
      @cChkL13 NVARCHAR(1) = '0', @dTaskL13 DATETIME,     @dUCCL13 DATETIME,       
      @cChkL14 NVARCHAR(1) = '0', @dTaskL14 DATETIME,     @dUCCL14 DATETIME,       
      @cChkL15 NVARCHAR(1) = '0', @dTaskL15 DATETIME,     @dUCCL15 DATETIME      
      
   -- Get facility      
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile      
      
   -- Get check lottable setting      
   SELECT    
      @cChkL01 = CASE WHEN Code = 'Lottable01' THEN '1' ELSE @cChkL01 END,       
      @cChkL02 = CASE WHEN Code = 'Lottable02' THEN '1' ELSE @cChkL02 END,       
      @cChkL03 = CASE WHEN Code = 'Lottable03' THEN '1' ELSE @cChkL03 END,       
      @cChkL04 = CASE WHEN Code = 'Lottable04' THEN '1' ELSE @cChkL04 END,       
      @cChkL05 = CASE WHEN Code = 'Lottable05' THEN '1' ELSE @cChkL05 END,       
      @cChkL06 = CASE WHEN Code = 'Lottable06' THEN '1' ELSE @cChkL06 END,       
      @cChkL07 = CASE WHEN Code = 'Lottable07' THEN '1' ELSE @cChkL07 END,       
      @cChkL08 = CASE WHEN Code = 'Lottable08' THEN '1' ELSE @cChkL08 END,       
      @cChkL09 = CASE WHEN Code = 'Lottable09' THEN '1' ELSE @cChkL09 END,       
      @cChkL10 = CASE WHEN Code = 'Lottable10' THEN '1' ELSE @cChkL10 END,       
      @cChkL11 = CASE WHEN Code = 'Lottable11' THEN '1' ELSE @cChkL11 END,       
      @cChkL12 = CASE WHEN Code = 'Lottable12' THEN '1' ELSE @cChkL12 END,       
      @cChkL13 = CASE WHEN Code = 'Lottable13' THEN '1' ELSE @cChkL13 END,       
      @cChkL14 = CASE WHEN Code = 'Lottable14' THEN '1' ELSE @cChkL14 END,       
      @cChkL15 = CASE WHEN Code = 'Lottable15' THEN '1' ELSE @cChkL15 END      
   FROM dbo.CodeLKUP WITH (NOLOCK)       
   WHERE ListName = 'SwapUCC'       
      AND StorerKey = @cStorerKey      
      AND Code2 = @cFacility      
      
   -- Get task lottable      
   SELECT       
      @cTaskL01 = Lottable01, @cTaskL02 = Lottable02, @cTaskL03 = Lottable03, @dTaskL04 = Lottable04, @dTaskL05 = Lottable05,      
      @cTaskL06 = Lottable06, @cTaskL07 = Lottable07, @cTaskL08 = Lottable08, @cTaskL09 = Lottable09, @cTaskL10 = Lottable10,      
      @cTaskL11 = Lottable11, @cTaskL12 = Lottable12, @dTaskL13 = Lottable13, @dTaskL14 = Lottable14, @dTaskL15 = Lottable15      
   FROM LotAttribute WITH (NOLOCK)      
   WHERE LOT = @cTaskLOT      
      
   -- Get UCC lottable      
   SELECT       
      @cUCCL01 = Lottable01, @cUCCL02 = Lottable02, @cUCCL03 = Lottable03, @dUCCL04 = Lottable04, @dUCCL05 = Lottable05,      
      @cUCCL06 = Lottable06, @cUCCL07 = Lottable07, @cUCCL08 = Lottable08, @cUCCL09 = Lottable09, @cUCCL10 = Lottable10,      
      @cUCCL11 = Lottable11, @cUCCL12 = Lottable12, @dUCCL13 = Lottable13, @dUCCL14 = Lottable14, @dUCCL15 = Lottable15      
   FROM LotAttribute WITH (NOLOCK)      
   WHERE LOT = @cActUCCLOT      
      
   -- Check all lottables      
   DECLARE @nLottableNo INT = 0      
   IF @nLottableNo = 0 AND @cChkL01= '1' AND @cTaskL01 <> @cUCCL01 SET @nLottableNo =  1 ELSE      
   IF @nLottableNo = 0 AND @cChkL02= '1' AND @cTaskL02 <> @cUCCL02 SET @nLottableNo =  2 ELSE      
   IF @nLottableNo = 0 AND @cChkL03= '1' AND @cTaskL03 <> @cUCCL03 SET @nLottableNo =  3 ELSE      
   IF @nLottableNo = 0 AND @cChkL04= '1' AND @dTaskL04 <> @dUCCL04 SET @nLottableNo =  4 ELSE      
   IF @nLottableNo = 0 AND @cChkL05= '1' AND @dTaskL05 <> @dUCCL05 SET @nLottableNo =  5 ELSE      
   IF @nLottableNo = 0 AND @cChkL06= '1' AND @cTaskL06 <> @cUCCL06 SET @nLottableNo =  6 ELSE      
   IF @nLottableNo = 0 AND @cChkL07= '1' AND @cTaskL07 <> @cUCCL07 SET @nLottableNo =  7 ELSE      
   IF @nLottableNo = 0 AND @cChkL08= '1' AND @cTaskL08 <> @cUCCL08 SET @nLottableNo =  8 ELSE      
   IF @nLottableNo = 0 AND @cChkL09= '1' AND @cTaskL09 <> @cUCCL09 SET @nLottableNo =  9 ELSE      
   IF @nLottableNo = 0 AND @cChkL10= '1' AND @cTaskL10 <> @cUCCL10 SET @nLottableNo = 10 ELSE      
   IF @nLottableNo = 0 AND @cChkL11= '1' AND @cTaskL11 <> @cUCCL11 SET @nLottableNo = 11 ELSE      
   IF @nLottableNo = 0 AND @cChkL12= '1' AND @cTaskL12 <> @cUCCL12 SET @nLottableNo = 12 ELSE      
   IF @nLottableNo = 0 AND @cChkL13= '1' AND @dTaskL13 <> @dUCCL13 SET @nLottableNo = 13 ELSE      
   IF @nLottableNo = 0 AND @cChkL14= '1' AND @dTaskL14 <> @dUCCL14 SET @nLottableNo = 14 ELSE      
   IF @nLottableNo = 0 AND @cChkL15= '1' AND @dTaskL15 <> @dUCCL15 SET @nLottableNo = 15      
      
   -- Validate lottable      
   IF @nLottableNo > 0      
   BEGIN      
      SET @nErrNo = 159760      
      SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --Not match L99      
      GOTO Fail      
   END      
      
   -- Check UCC taken by other (PickDetail)      
   IF EXISTS( SELECT TOP 1 1      
      FROM UCC WITH (NOLOCK)      
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)      
      WHERE UCC.StorerKey = @cStorerkey      
         AND PD.StorerKey = @cStorerkey      
         AND UCC.UCCNo = @cActUCCNo      
         AND PD.Status > '0'      
         AND PD.QTY > 0)      
   BEGIN      
      SET @nErrNo = 159761      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther      
      GOTO Fail      
   END      
      
   -- Check UCC taken by other (TaskDetail)      
   IF EXISTS( SELECT TOP 1 1      
      FROM UCC WITH (NOLOCK)      
         JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.UCCNo = TD.DropID)      
      WHERE UCC.StorerKey = @cStorerkey      
         AND TD.StorerKey = @cStorerkey      
         AND UCC.UCCNo = @cActUCCNo      
         AND TD.Status > '0'      
         AND TD.QTY > 0      
         AND TD.EditWho <> SUSER_SNAME())      
   BEGIN      
      SET @nErrNo = 159762      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther      
      GOTO Fail      
   END      
      
      
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
   SAVE TRAN rdt_1764SwapUCC04      
      
   -- 0. UCC on task = UCC taken, no swap      
   IF @cTaskUCCNo = @cActUCCNo      
   BEGIN      
      -- UCC on PickDetail      
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
               SET @nErrNo = 159763      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
            FETCH NEXT FROM @curPD INTO @cPickDetailKey      
         END      
      END      
            
      GOTO CommitTran      
   END      
            
  -- Get actual task info      
   SET @cActTaskDetailKey = ''      
   SET @nActSystemQTY = ''      
   SET @nActPendingMoveIn = 0      
   SELECT       
      @cActTaskDetailKey = TaskDetailKey,       
      @nActSystemQTY = SystemQTY,       
      @nActPendingMoveIn = PendingMoveIn      
   FROM TaskDetail WITH (NOLOCK)       
   WHERE StorerKey = @cStorerKey       
      AND TaskType = @cTaskType       
      AND CaseID = @cActUCCNo       
      AND Status = '0'      
      
   -- Get task UCC type      
   IF @nTaskSystemQTY > 0      
      SET @cTaskUCCType = 'PICK'      
   ELSE      
      SET @cTaskUCCType = 'REPLEN'      
      
   -- Get actual UCC type      
   SET @cActUCCType = ''      
   IF @cActTaskDetailKey = ''  AND @cActUCCStatus = '1' SET @cActUCCType = 'FREE'   ELSE      
   IF @cActTaskDetailKey <> '' AND @cActUCCStatus = '1' SET @cActUCCType = 'REPLEN' ELSE      
   IF @cActTaskDetailKey <> '' AND @cActUCCStatus = '3' SET @cActUCCType = 'PICK'       
      
   -- Check actual UCC type      
   IF @cActUCCType = ''         
   BEGIN      
      SET @nErrNo = 159764      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ActUCCTypeFail      
      GOTO RollBackTran      
   END      
         
   -- 1. UCC to replenish, swap UCC free      
   IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'FREE'      
   BEGIN      
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         LOT = @cActUCCLOT,       
         CaseID = @cActUCCNo,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME(),       
         TrafficCop = NULL      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159765      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
   END      
      
   -- 2. UCC to replenish, swap UCC with replenish      
   ELSE IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'REPLEN'      
   BEGIN      
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         LOT = @cActUCCLOT,      
         CaseID = @cActUCCNo,      
         TrafficCop = NULL,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159766      
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
         SET @nErrNo = 159767      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
         
   -- 3. UCC to replenish, swap UCC with alloc      
   ELSE IF @cTaskUCCType = 'REPLEN' AND @cActUCCType = 'PICK'      
   BEGIN      
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
      
      -- Get task's PickDetail info      
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tActPD      
      
      -- Check PickDetail changed      
      IF @nQTY <> @nActSystemQTY      
      BEGIN      
         SET @nErrNo = 159768      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed      
         GOTO RollBackTran      
      END      
      
      -- Don't need to swap LOT      
      IF @cTaskLOT = @cActUCCLOT      
      BEGIN      
         SET @curPD = CURSOR FOR      
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey      
         OPEN @curPD      
         FETCH NEXT FROM @curPD INTO @cPickDetailKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            -- Update PickDetail      
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               DropID = @cTaskUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cTaskUCCNo ELSE CaseID END,
               EditDate = GETDATE(),      
               EditWho = 'rdt.' + SUSER_SNAME(),       
               TrafficCop = NULL      
            FROM dbo.PickDetail PD      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 159769      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
            
            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

            FETCH NEXT FROM @curPD INTO @cPickDetailKey      
         END      
      END      
      ELSE      
      BEGIN      
         -- Unallocate      
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
         SET @curPD = CURSOR FOR      
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey      
         OPEN @curPD      
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE PickDetail SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               LOT = @cTaskLOT,      
               DropID = @cTaskUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cTaskUCCNo ELSE CaseID END,
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

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY      
         END      
      END      
      
      -- Task      
      UPDATE UCC WITH (ROWLOCK) SET      
         Status = '3', -- 3=Allocated      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE StorerKey = @cStorerkey      
         AND UCCNo = @cTaskUCCNo      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159770      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail      
         GOTO RollBackTran      
      END      
      
      -- Actual      
      UPDATE UCC WITH (ROWLOCK) SET      
         Status = '1', -- 1=Received      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE StorerKey = @cStorerkey      
         AND UCCNo = @cActUCCNo      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159771      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail      
         GOTO RollBackTran      
      END      
            
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         LOT = @cActUCCLOT,      
         CaseID = @cActUCCNo,      
         TrafficCop = NULL,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159772      
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
         SET @nErrNo = 159773      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
      
   -- 4. UCC to pick, swap UCC free      
   ELSE IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'FREE'      
   BEGIN      
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
      
      -- Check PickDetail changed      
      IF @nQTY <> @nTaskSystemQTY      
      BEGIN      
         SET @nErrNo = 159774      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed      
         GOTO RollBackTran      
      END      
         
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
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               Status = '3', -- Pick in-progress      
               TrafficCop = NULL,      
               EditDate = GETDATE(),      
               EditWho = 'rdt.' + SUSER_SNAME()      
            FROM dbo.PickDetail PD      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 159775      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
               GOTO RollBackTran      
            END      

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

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
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               Status = '3', -- Pick in-progress      
               LOT = @cActUCCLOT,      
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
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

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

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
         SET @nErrNo = 159776      
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
         SET @nErrNo = 159777      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail      
         GOTO RollBackTran      
      END      
      
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         CaseID = @cActUCCNo,      
         LOT = @cActUCCLOT,      
         TrafficCop = NULL,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159778      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
      
      -- Check PickDetail changed      
      IF @nQTY <> @nTaskSystemQTY      
      BEGIN      
         SET @nErrNo = 159779      
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
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               Status = '3', -- Pick in-progress      
               TrafficCop = NULL,      
               EditDate = GETDATE(),      
               EditWho = 'rdt.' + SUSER_SNAME()      
            FROM dbo.PickDetail PD      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 159780      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
               GOTO RollBackTran      
            END      

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

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
      
         -- Reallocate      
         -- Task      
         SET @curPD = CURSOR FOR      
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey      
         OPEN @curPD      
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE PickDetail SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               Status = '3', -- Pick in-progress      
               LOT = @cActUCCLOT,      
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
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

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY      
         END      
      END      
      
      -- ZG01 (Start)
      -- Actual      
      UPDATE UCC WITH (ROWLOCK) SET      
         Status = '3', -- 3=Allocated      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE StorerKey = @cStorerkey      
         AND UCCNo = @cActUCCNo      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159781      
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
         SET @nErrNo = 159782      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail      
         GOTO RollBackTran      
      END      
      -- ZG01 (End)
      
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         LOT = @cActUCCLOT,      
         CaseID = @cActUCCNo,      
         TrafficCop = NULL,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159783      
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
         SET @nErrNo = 159784      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
      
      -- Check PickDetail changed      
      IF @nQTY <> @nTaskSystemQTY      
      BEGIN      
         SET @nErrNo = 159785      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed      
         GOTO RollBackTran      
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
      
      -- Get task's PickDetail info      
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tActPD      
      
      -- Check PickDetail changed      
      IF @nQTY <> @nActSystemQTY      
      BEGIN      
         SET @nErrNo = 159786      
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
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               Status = '3', -- Pick in-progress      
               TrafficCop = NULL,      
               EditDate = GETDATE(),      
               EditWho = 'rdt.' + SUSER_SNAME()      
            FROM dbo.PickDetail PD      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 159787      
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
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               DropID = @cTaskUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cTaskUCCNo ELSE CaseID END,
               Status = '0',      
               TrafficCop = NULL,      
               EditDate = GETDATE(),      
               EditWho = 'rdt.' + SUSER_SNAME()      
            FROM dbo.PickDetail PD      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 159788      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
               GOTO RollBackTran      
            END      

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

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
               --Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               Status = '3', -- Pick in-progress      
               LOT = @cActUCCLOT,      
               DropID = @cActUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
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
               Notes = CASE WHEN UOM = '2' THEN CaseID ELSE Notes END,
               Status = '0',      
               LOT = @cTaskLOT,      
               DropID = @cTaskUCCNo,      
               CaseID = CASE WHEN UOM = '2' THEN @cTaskUCCNo ELSE CaseID END,
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

            IF NOT EXISTS ( SELECT 1 FROM @tUpdPack WHERE PickDetailKey = @cPickDetailKey)
               INSERT INTO @tUpdPack (PickDetailKey) VALUES (@cPickDetailKey)

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY      
         END      
      END      
      
      -- Task      
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET      
         LOT = @cActUCCLOT,      
         CaseID = @cActUCCNo,      
         TrafficCop = NULL,      
         EditDate = GETDATE(),      
         EditWho = 'rdt.' + SUSER_SNAME()      
      WHERE TaskDetailKey = @cTaskDetailKey      
      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 159789      
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
         SET @nErrNo = 159790      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail      
         GOTO RollBackTran      
      END      
      
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
      SET @nErrNo = 159791      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data error      
      GOTO RollBackTran      
   END      
         
CommitTran:      
      -- (james052)
      DECLARE @cOrderKey   NVARCHAR( 10)
      DECLARE @cLoadKey    NVARCHAR( 10)
      DECLARE @cPickSlipNo NVARCHAR( 10)
      DECLARE @cLabelNo    NVARCHAR( 20)
      DECLARE @cNewLabelNo NVARCHAR( 20)
      DECLARE @cNewPickSlipNo NVARCHAR( 10)
      DECLARE @nCartonNo      INT
      DECLARE @nNewCartonNo   INT
      DECLARE @cUpdPack   CURSOR
      SET @cUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PickDetailKey
      FROM @tUpdPack 
      ORDER BY 1
      OPEN @cUpdPack
      FETCH NEXT FROM @cUpdPack INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         
         SELECT @cOrderKey = OrderKey, 
            @cNewLabelNo = CaseID, 
            @cLabelNo = Notes
         FROM dbo.PICKDETAIL WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey
         AND   UOM = '2'
         
         IF ISNULL( @cLabelNo, '') <> ''
         BEGIN
            SELECT @cLoadKey = LoadKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            SELECT @cPickSlipNo = PickheaderKey
            FROM dbo.PICKHEADER WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey 
   
            IF ISNULL( @cPickSlipNo, '') = ''
               SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE LoadKey = @cLoadKey

            IF ISNULL( @cPickSlipNo, '') = ''
               SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
      
            IF ISNULL( @cPickSlipNo, '') = ''
               SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            SELECT @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo

            SELECT @cNewPickSlipNo = PickSlipNo,
                   @nNewCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   LabelNo = @cNewLabelNo
            
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               LabelNo = @cNewLabelNo,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            IF @@ERROR <> 0
               GOTO RollBackTran
             
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               LabelNo = @cLabelNo,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cNewPickSlipNo
            AND   CartonNo = @nNewCartonNo
            IF @@ERROR <> 0
               GOTO RollBackTran
         END
          

             
         UPDATE dbo.PickDetail SET 
            Notes = NULL, 
            TrafficCop = NULL 
         WHERE PickDetailKey = @cPickDetailKey

          IF @@ERROR <> 0
             GOTO RollBackTran

         FETCH NEXT FROM @cUpdPack INTO @cPickDetailKey
      END
      
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
      
   COMMIT TRAN rdt_1764SwapUCC04      
   GOTO Quit      
      
RollBackTran:      
   ROLLBACK TRAN rdt_1764SwapUCC04      
Fail:      
   SET @nUCCQTY = 0       
Quit:      
   WHILE @@TRANCOUNT > @nTranCount      
      COMMIT TRAN      
END 

GO