SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CycleCount_GetCCDetail                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) If CCDetailKey is blank                                           */
/*    (1st time or after reset CCDetailKey with blank)                  */
/*    -- Get next record from CCDetail in current LOC and ID            */
/* 2) If CCDetailKey is passed-in,                                      */
/*    -- Get same SKU with CCDetailKey greater than current CCDetailKey */
/*    -- Get diff SKU with CCDetailKey either greater or smaller than   */
/*       current CCDetailKey                                            */
/* NOTE: One record is refer to LOC+ID+SKU+CCDetailKey in CCDETAIL      */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 01-Jun-2006 1.0  MaryVong    Created                                 */
/* 15-Dec-2006 1.1  MaryVong    Always show Qty for 2nd & 3rd count     */
/* 05-Jul-2007 1.2  MaryVong    SOS79743 Cater double deep location:    */
/*                              If ID is blank, retrieve all data in    */
/*                              the particular location                 */
/* 20-May-2009 1.3  MaryVong    Enhancement:                            */
/*                              1. Allow empty CCSheetNo                */
/*                              2. Differentiate empy record for ID/LOC */
/* 22-Dec-2011 1.4  Ung         SOS231818 Handle empty LOC no StorerKey */
/* 07-Jan-2012 1.5  Shong001    Allow RDT Count by Multiple Storer      */
/* 11-May-2012 1.6  Shong002    Default StorerKey if it's Blank         */
/*                              (SOS244131)                             */
/* 16-Dec-2015 1.7  Richard     SOS359218 - Bug fix.                    */
/* 05-Sep-2016 1.8  James       IN00137901 - Bug fix.                   */
/* 06-Nov-2017 1.9  James       Fix ansi option (james01)               */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_GetCCDetail] (
   @cCCRefNo      NVARCHAR( 10),
   @cCCSheetNo    NVARCHAR( 10),
   @nCCCountNo    INT,
   @cStorer       NVARCHAR( 15)   OUTPUT,  -- Shong001
   @cLOC          NVARCHAR( 10),
   @cID_In        NVARCHAR( 18),
   @cWithQtyFlag  NVARCHAR( 1),
   @cCCDetailKey  NVARCHAR( 10)   OUTPUT,
   @cCountedFlag  NVARCHAR( 3)    OUTPUT,
   @cSKU          NVARCHAR( 20)   OUTPUT,
   @cLOT          NVARCHAR( 10)   OUTPUT,
   @cID           NVARCHAR( 18)   OUTPUT,
   @cLottable1    NVARCHAR( 18)   OUTPUT,
   @cLottable2    NVARCHAR( 18)   OUTPUT,
   @cLottable3    NVARCHAR( 18)   OUTPUT,
   @dLottable4    DATETIME    OUTPUT,
   @dLottable5    DATETIME    OUTPUT,
   @nCaseCnt      INT         OUTPUT,
   @nCaseQTY      INT         OUTPUT,
   @cCaseUOM      NVARCHAR( 3)    OUTPUT,
   @nEachQTY      INT         OUTPUT,
   @cEachUOM      NVARCHAR( 3)    OUTPUT,
   @cSKUDescr     NVARCHAR( 60) OUTPUT,
   @cPPK          NVARCHAR( 6)    OUTPUT,
   @nRecCnt       INT         OUTPUT,
   @cEmptyRecFlag NVARCHAR( 1)    OUTPUT   -- 'L' = LOC, 'D' = ID
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nQTY      INT

   SET @nQTY = 0
   SET @cEmptyRecFlag = ''

   SELECT TOP 1
      @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END, -- Shong002
      @cSKU = SKU,
      @cLOT = LOT,
      @cID  = ID, -- CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END, -- SOS79743 -- SOS359218
      @cCCDetailKey = CCDetailKey,
      @cCountedFlag =
         CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN '[C]'
              WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN '[C]'
              WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN '[C]'
         ELSE '[ ]' END,
--       @nQTY =
--          CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '0' THEN SystemQty
--               WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN QTY
--               WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN QTY_Cnt2
--               WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN QTY_Cnt3
--          END,

--       @nQTY = CASE WHEN @cWithQtyFlag = 'Y' THEN
--                      CASE WHEN @nCCCountNo = 1 THEN QTY
--                           WHEN @nCCCountNo = 2 THEN QTY_Cnt2
--                           WHEN @nCCCountNo = 3 THEN QTY_Cnt3
--                      END
--                    WHEN @cWithQtyFlag = 'N' THEN
--                      CASE WHEN @nCCCountNo = 1 AND Counted_Cnt1 = '1' THEN QTY
--                           WHEN @nCCCountNo = 2 AND Counted_Cnt2 = '1' THEN QTY_Cnt2
--                           WHEN @nCCCountNo = 3 AND Counted_Cnt3 = '1' THEN QTY_Cnt3
--                      ELSE 0 END
--                END,

      -- Always show Qty for 2nd & 3rd count
      -- i.e. At Cnt1 => if counted then display qty; if not counted then display qty based on WithQtyFlag
      --      At Cnt2 => always with qty populated from Cnt1 displayed in Cnt2, or
      --      At Cnt3 => always with qty populated from Cnt2 displayed in Cnt3
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

      @cLottable1 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable01
              WHEN @nCCCountNo = 2 THEN Lottable01_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable01_Cnt3
         ELSE '' END,
      @cLottable2 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable02
              WHEN @nCCCountNo = 2 THEN Lottable02_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable02_Cnt3
         ELSE '' END,
      @cLottable3 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable03
              WHEN @nCCCountNo = 2 THEN Lottable03_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable03_Cnt3
         ELSE '' END,
      @dLottable4 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable04
              WHEN @nCCCountNo = 2 THEN Lottable04_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable04_Cnt3
         ELSE NULL END,
      @dLottable5 =
         CASE WHEN @nCCCountNo = 1 THEN Lottable05
              WHEN @nCCCountNo = 2 THEN Lottable05_Cnt2
              WHEN @nCCCountNo = 3 THEN Lottable05_Cnt3
         ELSE NULL END
   FROM dbo.CCDETAIL (NOLOCK)
   WHERE CCKey = @cCCRefNo
      -- AND CCSheetNo = @cCCSheetNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
      AND LOC = @cLOC
      -- SOS79743
      -- AND ID = @cID
      AND ID = CASE WHEN @cID_In = '' OR @cID_In IS NULL THEN ID ELSE @cID_In END
--       AND 1 = CASE WHEN @cType = 'CURR' AND CCDetailKey = @cCCDetailKey THEN 1
--                    -- When 'NEXT', 3 conditions to setup:
--                    -- 1) 1st time or after reset CCDetailKey with blank
--                    -- 2) Same SKU with CCDetailKey greater than curr CCDetailKey
--                    -- 3) Diff SKU with CCDetailKey either greater or smaller than curr CCDetailKey
--                    -- Purpose is to make sure looping always sorted in seq of SKU, CCDetailKey
--                    WHEN @cType = 'NEXT' THEN
--                         CASE WHEN @cCCDetailKey = '' AND CCDetailKey > @cCCDetailKey THEN 1   -- 1st Time
--                              WHEN @cSKU = SKU AND CCDetailKey > @cCCDetailKey THEN 1
--                              WHEN SKU > @cSKU THEN 1
--                         END
--               ELSE 0 END

      -- 3 conditions to setup:
      -- 1) 1st time or after reset CCDetailKey with blank
      -- 2) Same SKU with CCDetailKey greater than curr CCDetailKey
      -- 3) Diff SKU with CCDetailKey either greater or smaller than curr CCDetailKey
      -- Purpose is to make sure looping always sorted in seq of SKU, CCDetailKey
      AND 1 = CASE WHEN @cCCDetailKey = '' AND CCDetailKey > @cCCDetailKey THEN 1   -- 1st Time
                   WHEN @cSKU = SKU AND CCDetailKey > @cCCDetailKey THEN 1
                   WHEN SKU > @cSKU THEN 1
              ELSE 0 END
      AND Status < '9'
      AND 1 = CASE WHEN @nCCCountNo = 1 AND Counted_CNT1 = 1 THEN 0 -- IN00137901
                   WHEN @nCCCountNo = 2 AND Counted_CNT2 = 1 THEN 0
                   WHEN @nCCCountNo = 3 AND Counted_CNT3 = 1 THEN 0
                   ELSE 1 END
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
                          ELSE '' END
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND SKU.SKU = @cSKU
   END

   -- (MaryVong01)
   ELSE IF @nRecCnt = 0
   BEGIN
      -- Check again from LOC itself
      SELECT TOP 1
         @cStorer = CASE WHEN ISNULL(RTRIM(StorerKey),'') = '' THEN @cStorer ELSE StorerKey END, -- Shong002
         @cSKU = SKU
      FROM dbo.CCDETAIL (NOLOCK)
      WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cLOC
         -- 3 conditions to setup:
         -- 1) 1st time or after reset CCDetailKey with blank
         -- 2) Same SKU with CCDetailKey greater than curr CCDetailKey
         -- 3) Diff SKU with CCDetailKey either greater or smaller than curr CCDetailKey
         -- Purpose is to make sure looping always sorted in seq of SKU, CCDetailKey
         AND 1 = CASE WHEN @cCCDetailKey = '' AND CCDetailKey > @cCCDetailKey THEN 1   -- 1st Time
                      WHEN @cSKU = SKU AND CCDetailKey > @cCCDetailKey THEN 1
                      WHEN SKU > @cSKU THEN 1
                 ELSE 0 END
         AND Status < '9'
         AND 1 = CASE WHEN @nCCCountNo = 1 AND Counted_CNT1 = 1 THEN 0 -- IN00137901
                      WHEN @nCCCountNo = 2 AND Counted_CNT2 = 1 THEN 0
                      WHEN @nCCCountNo = 3 AND Counted_CNT3 = 1 THEN 0
                      ELSE 1 END
      ORDER BY SKU, CCDetailKey

      IF @@ROWCOUNT = 0
         SET @cEmptyRecFlag = 'L' -- LOC
      ELSE
         SET @cEmptyRecFlag = 'D' -- ID
   END
END

GO