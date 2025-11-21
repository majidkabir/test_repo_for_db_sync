SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ASRSCC_GetCCDetail                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes: SOS#315031 Retrieve CCDetail for rdtfnc_ASRS_CycleCount    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-Apr-2015 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_ASRSCC_GetCCDetail] (
   @cCCRefNo      NVARCHAR( 10),
   @cCCSheetNo    NVARCHAR( 10),
   @nCCCountNo    INT,
   @cStorerKey    NVARCHAR( 15),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cCCDetailKey  NVARCHAR( 10)  OUTPUT,
   @cCountedFlag  NVARCHAR( 3)   OUTPUT,
   @cSKU          NVARCHAR( 20)  OUTPUT,
   @cLOT          NVARCHAR( 10)  OUTPUT,
   @cLottable01   NVARCHAR( 18)  OUTPUT,
   @cLottable02   NVARCHAR( 18)  OUTPUT,
   @cLottable03   NVARCHAR( 18)  OUTPUT,
   @dLottable04   DATETIME       OUTPUT,
   @dLottable05   DATETIME       OUTPUT,
   @cLottable06   NVARCHAR( 30)  OUTPUT, 
   @cLottable07   NVARCHAR( 30)  OUTPUT, 
   @cLottable08   NVARCHAR( 30)  OUTPUT, 
   @cLottable09   NVARCHAR( 30)  OUTPUT, 
   @cLottable10   NVARCHAR( 30)  OUTPUT, 
   @cLottable11   NVARCHAR( 30)  OUTPUT, 
   @cLottable12   NVARCHAR( 30)  OUTPUT, 
   @dLottable13   DATETIME       OUTPUT, 
   @dLottable14   DATETIME       OUTPUT, 
   @dLottable15   DATETIME       OUTPUT, 
   @nCaseCnt      INT            OUTPUT,
   @nCaseQTY      INT            OUTPUT,
   @cCaseUOM      NVARCHAR( 3)   OUTPUT,
   @nEachQTY      INT            OUTPUT,
   @cEachUOM      NVARCHAR( 3)   OUTPUT,
   @cSKUDescr     NVARCHAR( 60)  OUTPUT,
   @cPPK          NVARCHAR( 6)   OUTPUT,
   @nRecCnt       INT            OUTPUT, 
   @cLottableCode NVARCHAR( 30)  OUTPUT  
) AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON

   DECLARE
      @nQTY          INT, 
      @cWithQtyFlag  NVARCHAR( 1)

   SET @nQTY = 0
   SET @cWithQtyFlag = ''

   SELECT @cWithQtyFlag = WithQuantity
   FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
   WHERE StockTakeKey = @cCCRefNo

   SELECT TOP 1
      @cSKU = SKU,
      @cLOT = LOT,
      @cCCDetailKey = CCDetailKey,
      @cCountedFlag =
         CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
              WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
              WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
         ELSE '[ ]' END,
      @nQTY = CASE WHEN @nCCCountNo = 1 THEN
                   CASE WHEN Counted_Cnt1 = 0 THEN
                        CASE WHEN @cWithQtyFlag = 'Y' THEN QTY
                             WHEN @cWithQtyFlag = 'N' THEN 0
                        END
                        WHEN Counted_Cnt1 = 1 THEN QTY
                   END
                   WHEN @nCCCountNo = 2 THEN QTY_Cnt2
                   WHEN @nCCCountNo = 3 THEN QTY_Cnt3
               END,
      @cLottable01 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable01
              WHEN @nCCCountNo = 2 THEN Lottable01_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable01_Cnt3
         ELSE '' END,
      @cLottable02 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable02
              WHEN @nCCCountNo = 2 THEN Lottable02_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable02_Cnt3
         ELSE '' END,
      @cLottable03 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable03
              WHEN @nCCCountNo = 2 THEN Lottable03_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable03_Cnt3
         ELSE '' END,
      @dLottable04 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable04
              WHEN @nCCCountNo = 2 THEN Lottable04_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable04_Cnt3
         ELSE NULL END,
      @dLottable05 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable05
              WHEN @nCCCountNo = 2 THEN Lottable05_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable05_Cnt3
         ELSE NULL END, 
      @cLottable06 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable06
              WHEN @nCCCountNo = 2 THEN Lottable06_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable06_Cnt3
         ELSE '' END,
      @cLottable07 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable07
              WHEN @nCCCountNo = 2 THEN Lottable07_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable07_Cnt3
         ELSE '' END,
      @cLottable08 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable08
              WHEN @nCCCountNo = 2 THEN Lottable08_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable08_Cnt3
         ELSE '' END,
      @cLottable09 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable09
              WHEN @nCCCountNo = 2 THEN Lottable09_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable09_Cnt3
         ELSE NULL END,
      @cLottable10 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable10
              WHEN @nCCCountNo = 2 THEN Lottable10_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable10_Cnt3
         ELSE NULL END, 
      @cLottable11 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable11
              WHEN @nCCCountNo = 2 THEN Lottable11_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable11_Cnt3
         ELSE '' END,
      @cLottable12 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable12
              WHEN @nCCCountNo = 2 THEN Lottable12_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable12_Cnt3
         ELSE '' END,
      @dLottable13 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable13
              WHEN @nCCCountNo = 2 THEN Lottable13_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable13_Cnt3
         ELSE '' END,
      @dLottable14 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable14
              WHEN @nCCCountNo = 2 THEN Lottable14_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable14_Cnt3
         ELSE NULL END,
      @dLottable15 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable15
              WHEN @nCCCountNo = 2 THEN Lottable15_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable15_Cnt3
         ELSE NULL END 
   FROM dbo.CCDETAIL (NOLOCK)
   WHERE CCKey = @cCCRefNo
   AND CCSheetNo = @cCCSheetNo
   AND ID = @cID 
   AND 1 = CASE WHEN @cCCDetailKey = '' AND CCDetailKey > @cCCDetailKey THEN 1   -- 1st Time
                  WHEN @cSKU = SKU AND CCDetailKey > @cCCDetailKey THEN 1
                  WHEN SKU > @cSKU THEN 1
            ELSE 0 END
   AND Status < '9'
   ORDER BY SKU, CCDetailKey

   SET @nRecCnt = @@ROWCOUNT

   IF @nRecCnt = 1
   BEGIN
      -- Get CaseCnt, SKUDESCR, CS/EA Qty, CS/EA UOM, PPK
      -- Display Qty in CS and EA

      SELECT TOP 1
         @nCaseCnt = PAC.CaseCnt,
         @cSKUDescr = SKU.Descr,
         @nCaseQty = CASE WHEN PAC.CaseCnt > 0 AND @nQTY > 0
                             THEN FLOOR( @nQTY / PAC.CaseCnt)
                          ELSE 0 END,
         @cCaseUOM = CASE WHEN PAC.CaseCnt > 0
                             THEN SUBSTRING( PAC.PACKUOM1, 1, 3)
                          ELSE '' END,
         @nEachQty = CASE WHEN PAC.CaseCnt > 0
                             THEN @nQTY % CAST (PAC.CaseCnt AS INT)
                          WHEN PAC.CaseCnt = 0
                             THEN @nQTY
                          ELSE 0 END,
         @cEachUOM = SUBSTRING( PAC.PACKUOM3, 1, 3),
         @cPPK     = CASE WHEN SKU.PrePackIndicator = '2'
                             THEN 'PPK:' + CAST( SKU.PackQtyIndicator AS NVARCHAR( 2))
                          ELSE '' END, 
         @cLottableCode = LottableCode 
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU
   END
END

GO