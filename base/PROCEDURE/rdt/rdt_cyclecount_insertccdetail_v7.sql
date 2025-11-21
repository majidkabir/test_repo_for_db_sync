SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_InsertCCDetail_V7                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 06-May-2019 1.0  James       WMS-8649 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_InsertCCDetail_V7] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cCCRefNo         NVARCHAR( 10),
   @cCCSheetNo       NVARCHAR( 10),
   @nCCCountNo       INT,
   @cSKU             NVARCHAR( 20),
   @cUCC             NVARCHAR( 20),
   @cLOT             NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @nQTY             INT,
   @cLottable01      NVARCHAR( 18),
   @cLottable02      NVARCHAR( 18),
   @cLottable03      NVARCHAR( 18),
   @dLottable04      DATETIME,
   @dLottable05      DATETIME,
   @cLottable06      NVARCHAR( 30), 
   @cLottable07      NVARCHAR( 30), 
   @cLottable08      NVARCHAR( 30), 
   @cLottable09      NVARCHAR( 30), 
   @cLottable10      NVARCHAR( 30), 
   @cLottable11      NVARCHAR( 30),
   @cLottable12      NVARCHAR( 30),
   @dLottable13      DATETIME,
   @dLottable14      DATETIME,
   @dLottable15      DATETIME,
   @cNewCCDetailKey   NVARCHAR( 10) OUTPUT,
   @nErrNo            INT           OUTPUT, 
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   
   DECLARE 
      @b_success        INT,
      @n_err            INT,
      @c_errmsg         NVARCHAR( 255), 
      @nTranCount       INT,
      @cUserName        NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- (MaryVong01)
   IF ISNULL(@cCCSheetNo, '') = ''
   BEGIN
      SELECT @cCCSheetNo = MAX(CCSheetNo)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
   END
   
   SET @b_success = 0

   EXECUTE dbo.nspg_GetKey
      'CCDETAILKEY', 
      10 ,
      @cNewCCDetailKey  OUTPUT,
      @b_success        OUTPUT,
      @n_err            OUTPUT,
      @c_errmsg         OUTPUT
   
   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 62161
      SET @cErrMsg = rdt.rdtgetmessage( 62161, @cLangCode, 'DSP') -- GetDetKey fail
      GOTO Fail 
   END

   -- Default Lottable05 if RCP_DATE
   IF (SELECT Lottable05Label FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU) = 'RCP_DATE' AND @dLottable05 IS NULL
      SET @dLottable05 = CONVERT( NVARCHAR(8), GETDATE(), 112)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_CycleCount_InsertCCDetail_V7

   INSERT INTO dbo.CCDETAIL
      (CCKey,           CCDetailKey,     CCSheetNo,       StorerKey,      SKU,              LOT, 
      LOC,              ID,              RefNo,           Status,         Qty,           
      Lottable01,       Lottable02,      Lottable03,      Lottable04,      Lottable05, 
      Lottable06,       Lottable07,      Lottable08,      Lottable09,      Lottable10, 
      Lottable11,       Lottable12,      Lottable13,      Lottable14,      Lottable15, 
      EditDate_Cnt1,    EditWho_Cnt1,    Counted_Cnt1,    Qty_Cnt2,      
      Lottable01_Cnt2,  Lottable02_Cnt2, Lottable03_Cnt2, Lottable04_Cnt2, Lottable05_Cnt2, 
      Lottable06_Cnt2,  Lottable07_Cnt2, Lottable08_Cnt2, Lottable09_Cnt2, Lottable10_Cnt2, 
      Lottable11_Cnt2,  Lottable12_Cnt2, Lottable13_Cnt2, Lottable14_Cnt2, Lottable15_Cnt2, 
      EditDate_Cnt2,    EditWho_Cnt2,    Counted_Cnt2,    Qty_Cnt3,      
      Lottable01_Cnt3,  Lottable02_Cnt3, Lottable03_Cnt3, Lottable04_Cnt3, Lottable05_Cnt3,
      Lottable06_Cnt3,  Lottable07_Cnt3, Lottable08_Cnt3, Lottable09_Cnt3, Lottable10_Cnt3,
      Lottable11_Cnt3,  Lottable12_Cnt3, Lottable13_Cnt3, Lottable14_Cnt3, Lottable15_Cnt3,
      EditDate_Cnt3,    EditWho_Cnt3,    Counted_Cnt3)
   VALUES (
      @cCCRefNo, @cNewCCDetailKey, @cCCSheetNo, @cStorerKey, @cSKU, @cLOT, 
      @cLOC, @cID, @cUCC, '4',
      CASE WHEN @nCCCountNo = 1 THEN @nQty ELSE 0 END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable01 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable02 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable03 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable06 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable07 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable08 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN @cLottable09 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable10 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable11 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cLottable12 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN GetDate() ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 THEN '1' ELSE '0' END,
      CASE WHEN @nCCCountNo = 2 THEN @nQty ELSE 0 END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable01 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable02 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable03 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END, 
      CASE WHEN @nCCCountNo = 2 THEN @cLottable06 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable07 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable08 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 THEN @cLottable09 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable10 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable11 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cLottable12 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
      CASE WHEN @nCCCountNo = 1 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN GetDate() ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE NULL END,
      CASE WHEN @nCCCountNo = 2 THEN '1' ELSE '0' END,         
      CASE WHEN @nCCCountNo = 3 THEN @nQty ELSE 0 END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable01 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable02 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable03 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END, 
      CASE WHEN @nCCCountNo = 3 THEN @cLottable06 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable07 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable08 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 THEN @cLottable09 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable10 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable11 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cLottable12 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN GetDate() ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE NULL END,
      CASE WHEN @nCCCountNo = 3 THEN '1' ELSE '0' END)
   IF @@ERROR <> 0 
   BEGIN
      SET @nErrNo = 62162
      SET @cErrMsg = rdt.rdtgetmessage( 62162, @cLangCode, 'DSP') -- Add CCDET fail
      GOTO RollBackTran
   END
   
   -- If empty LOC CCDetail exist, update it as counted
   DECLARE @cCCDetailKey NVARCHAR( 10)
   SET @cCCDetailKey = ''
   SELECT TOP 1
      @cCCDetailKey = CCDetailKey
   FROM dbo.CCDetail WITH (NOLOCK) 
   WHERE CCKey = @cCCRefNo 
      AND LOC = @cLOC
      AND SKU = '' -- Empty LOC without any SKU
   IF @cCCDetailKey <> ''
   BEGIN
      -- Get count no
      DECLARE @nFinalizeStage INT  
      SELECT @nFinalizeStage = FinalizeStage
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)  
      WHERE StockTakeKey = @cCCRefNo
      
      SET @nFinalizeStage = @nFinalizeStage + 1  
      UPDATE dbo.CCDetail SET
         Counted_CNT1 = CASE WHEN @nFinalizeStage = 1 THEN 1 ELSE Counted_CNT1 END, 
         Counted_CNT2 = CASE WHEN @nFinalizeStage = 2 THEN 1 ELSE Counted_CNT2 END, 
         Counted_CNT3 = CASE WHEN @nFinalizeStage = 3 THEN 1 ELSE Counted_CNT3 END
      WHERE CCDetailKey = @cCCDetailKey
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 62162
         SET @cErrMsg = rdt.rdtgetmessage( 62162, @cLangCode, 'DSP') -- Add CCDET fail
         GOTO RollBackTran
      END
   END

   -- (james01)
   -- Check if cckey + loc update before loc.cyclecounter
   -- Only need update loc.cyclecounter 1 time per cckey + loc
   IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                   WHERE CCKey = @cCCRefNo
                   AND   Storerkey = @cStorerKey  
                   AND   LOC = @cLoc
                   AND   StatusMsg = '1')
   BEGIN
      SELECT @cFacility = Facility
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE UserName = @cUserName
      
      UPDATE dbo.LOC WITH (ROWLOCK) SET 
         CycleCounter = ISNULL( CycleCounter, 0) + 1
      WHERE LOC = @cLoc
      AND   Facility = @cFacility
      
      IF @@ERROR <> 0
      BEGIN    
         SET @nErrNo = 77724  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  -- UpdCounterFail  
         GOTO RollBackTran
      END      

      UPDATE TOP (1) dbo.CCDetail WITH (ROWLOCK) SET 
         StatusMsg = '1'
      WHERE CCKey = @cCCRefNo
      AND   Storerkey = @cStorerKey  
      AND   LOC = @cLoc
      AND   StatusMsg <> '1'
      AND   ( Qty + Qty_Cnt2 + Qty_Cnt3) > 0 -- something counted

      IF @@ERROR <> 0
      BEGIN    
         SET @nErrNo = 77725  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  -- UpdCCDtlFail  
         GOTO RollBackTran
      END      
   END

   COMMIT TRAN rdt_CycleCount_InsertCCDetail_V7 -- Only commit change made in rdt_MoveByDropID_Pack
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_CycleCount_InsertCCDetail_V7 -- Only rollback change made in rdt_MoveByDropID_Pack
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:
END

GO