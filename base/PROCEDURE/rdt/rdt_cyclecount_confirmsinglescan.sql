SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_ConfirmSingleScan                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Single SKU Scanning                                 */
/*                                                                      */
/* Called from: rdtfnc_CycleCount                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 11-May-2009 1.0  MaryVong    Created                                 */
/* 24-Sep-2010 1.1  AQSKC       Issue with lottable04 comparison when   */
/*                              date = null (Kc01)                      */
/* 22-Dec-2011 1.2  Ung         SOS235351 Handle empty LOC no StorerKey */
/* 20-Apr-2017 1.3  James       Remove ANSI_WARNINGS (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_ConfirmSingleScan] (
   @cCCRefNo      NVARCHAR( 10),
   @cCCSheetNo    NVARCHAR( 10),
   @nCCCountNo    INT,
   @cStorer       NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSheetNoFlag  NVARCHAR( 1),
   @cWithQtyFlag  NVARCHAR( 1),
   @cUserName     NVARCHAR( 18),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @cLangCode     NVARCHAR( 3),
   @nErrNo        INT          OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max

)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_success        INT,
      @n_err            INT,
      @c_errmsg         NVARCHAR( 250),
      @cCCDetailKey     NVARCHAR( 10),
      @cNewCCDetailKey  NVARCHAR( 10),
      @cLockCCDetKey    NVARCHAR( 10),
      @nCountedQty      INT,
      @nSystemQTY       INT,
      @nRecountQty      INT,
      @nRowRef          INT,
      @cNoMatchingCCD   NVARCHAR( 1),
      @nNoOfRecountRec  INT,
      @cRefNo           NVARCHAR( 20),
      @nTranCount       INT,
      @dLottable05      DATETIME,
      @cLottableFlag    NVARCHAR( 1),
      @cLOTTABLE01LABEL NVARCHAR( 20),
      @cLOTTABLE02LABEL NVARCHAR( 20),
      @cLOTTABLE03LABEL NVARCHAR( 20),
      @cLOTTABLE04LABEL NVARCHAR( 20),
      @nQty             INT

   SET @nTranCount = @@TRANCOUNT
   SET @cNewCCDetailKey  = ''
   SET @cNoMatchingCCD   = ''
   SET @nRecountQty      = 0
   SET @nNoOfRecountRec  = 0
   SET @dLottable05      = NULL
   SET @cLOTTABLE01LABEL = ''
   SET @cLOTTABLE02LABEL = ''
   SET @cLOTTABLE03LABEL = ''
   SET @cLOTTABLE04LABEL = ''

   -- Check any Lottable label setup for the SKU
   SELECT
      @cLOTTABLE01LABEL = ISNULL(LOTTABLE01LABEL, ''),
      @cLOTTABLE02LABEL = ISNULL(LOTTABLE02LABEL, ''),
      @cLOTTABLE03LABEL = ISNULL(LOTTABLE03LABEL, ''),
      @cLOTTABLE04LABEL = ISNULL(LOTTABLE04LABEL, '')
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorer
   AND   SKU = @cSKU

   IF @cLOTTABLE01LABEL <> '' OR @cLOTTABLE02LABEL <> '' OR
      @cLOTTABLE03LABEL <> '' OR @cLOTTABLE04LABEL <> ''
   BEGIN
      SET @cLottableFlag = 'Y'
   END

   BEGIN TRAN
   SAVE TRAN CycleCount_ConfirmSingleScan

   /*************************************************************************************************/
   /* With Lottable Labels - Start                                                                  */
   /*************************************************************************************************/
   IF @cLottableFlag = 'Y'
   BEGIN
      -- Check if any available data
      IF EXISTS ( SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
                  AND   CountNo = @nCCCountNo
                  AND   AddWho = @cUserName
                  AND   SKU = @cSKU
                  AND   LOC = @cLOC
                  AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
                  AND   CountedQty > 0
                  AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
                  AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
                  AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
                  AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
                  AND   (Status = '0' OR Status = '1') )
      BEGIN
         -- Look 4 the non empty LOT first and order by LOT asc
         DECLARE cur_WithLotLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, CCDetailKey, CountedQty
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
            AND   CountNo = @nCCCountNo
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   CountedQty > 0
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
            AND   (Status = '0' OR Status = '1')
            AND   LOT <> ''
         ORDER BY LOT, CCDetailKey
         OPEN cur_WithLotLabel
         FETCH NEXT FROM cur_WithLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY
         WHILE (@@FETCH_STATUS = 0)
         BEGIN
            IF ISNULL(@cLockCCDetKey, '') <> '' -- exists in ccdetail table
            BEGIN
               -- Update CCDetail
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cLockCCDetKey,
                  @nCountedQTY,
                  @cUserName,
                  @cLangCode,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
            ELSE -- New line (no ccdetail matched)
            BEGIN
               -- Find any new inserted line (status = '4')
               -- If found, update qty; else insert new line
               SET @cCCDetailKey = ''
               SELECT @cCCDetailKey = CCDetailKey,
                      @nQTY = CASE WHEN @nCCCountNo = 1 THEN Qty
                                   WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                                   WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                              END
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE CCSheetNo END
               AND   SKU = @cSKU
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   Lottable01 = @cLottable01
               AND   Lottable02 = @cLottable02
               AND   Lottable03 = @cLottable03
               AND   Lottable04 = @dLottable04
               AND   Status = '4' -- Newly inserted line

               IF ISNULL(@cCCDetailKey, '') <> ''
               BEGIN
                  SET @nCountedQTY = @nCountedQTY + @nQTY
                  -- Update CCDetail
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cCCDetailKey,
                     @nCountedQTY,
                     @cUserName,
                     @cLangCode,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Get max ccsheetno if it is blank
                  IF ISNULL(@cCCSheetNo, '') = ''
                  BEGIN
                     SELECT @cCCSheetNo = MAX(CCSheetNo)
                     FROM dbo.CCDETAIL WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                  END

                  -- Get the oldest lot
                  SELECT @dLottable05 = MIN(LA.Lottable05)
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.StorerKey = @cStorer
                     AND LLI.SKU = @cSKU
                     AND LLI.LOC = @cLOC
                     AND LLI.ID = CASE WHEN ISNULL(@cID, '') <> '' THEN @cID ELSE LLI.ID END

                  -- Insert a record into CCDETAIL
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cStorer,
                     @cSKU,
                     '',            -- No UCC
                     '',            -- No LOT generated yet
                     @cLOC,         -- Current LOC
                     @cID,          -- Entered ID, it can be blank
                     @nCountedQTY,
                     @cLottable01,
                     @cLottable02,
                     @cLottable03,
                     @dLottable04,
                     @dLottable05,
                     @cUserName,
                     @cLangCode,
                     @cNewCCDetailKey OUTPUT,
                     @nErrNo          OUTPUT,
                     @cErrMsg         OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END

            -- Stamp RDTCCLock's candidate to '9'
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               -- '1'=allow to continue update; '9'=Done
               Status = CASE WHEN CountedQty < SystemQty THEN '1' ELSE '9' END
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66851
               SET @cErrMsg = rdt.rdtgetmessage( 66851, @cLangCode, 'DSP') --'UPDCCLockFail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM cur_WithLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY
         END
         CLOSE cur_WithLotLabel
         DEALLOCATE cur_WithLotLabel

         -- Now look for remaining empty LOT
         DECLARE cur_WithLotLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, CCDetailKey, CountedQty
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
            AND   CountNo = @nCCCountNo
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   CountedQty > 0
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
            AND   (Status = '0' OR Status = '1')
         ORDER BY CCDetailKey
         OPEN cur_WithLotLabel
         FETCH NEXT FROM cur_WithLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY
         WHILE (@@FETCH_STATUS = 0)
         BEGIN
            IF ISNULL(@cLockCCDetKey, '') <> '' -- exists in ccdetail table
            BEGIN
               -- Update CCDetail
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cLockCCDetKey,
                  @nCountedQTY,
                  @cUserName,
                  @cLangCode,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
            ELSE -- New line (no ccdetail matched)
            BEGIN
               -- Find any new inserted line (status = '4')
               -- If found, update qty; else insert new line
               SET @cCCDetailKey = ''
               SELECT @cCCDetailKey = CCDetailKey,
                      @nQTY = CASE WHEN @nCCCountNo = 1 THEN Qty
                                   WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                                   WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                              END
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE CCSheetNo END
               AND   SKU = @cSKU
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   Lottable01 = @cLottable01
               AND   Lottable02 = @cLottable02
               AND   Lottable03 = @cLottable03
               AND   Lottable04 = @dLottable04
               AND   Status = '4' -- Newly inserted line

               IF ISNULL(@cCCDetailKey, '') <> ''
               BEGIN
                  SET @nCountedQTY = @nCountedQTY + @nQTY
                  -- Update CCDetail
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cCCDetailKey,
                     @nCountedQTY,
                     @cUserName,
                     @cLangCode,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Get max ccsheetno if it is blank
                  IF ISNULL(@cCCSheetNo, '') = ''
                  BEGIN
                     SELECT @cCCSheetNo = MAX(CCSheetNo)
                     FROM dbo.CCDETAIL WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                  END

                  -- Get the oldest lot
                  SELECT @dLottable05 = MIN(LA.Lottable05)
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.StorerKey = @cStorer
                     AND LLI.SKU = @cSKU
                     AND LLI.LOC = @cLOC
                     AND LLI.ID = CASE WHEN ISNULL(@cID, '') <> '' THEN @cID ELSE LLI.ID END

                  -- Insert a record into CCDETAIL
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cStorer,
                     @cSKU,
                     '',            -- No UCC
                     '',            -- No LOT generated yet
                     @cLOC,         -- Current LOC
                     @cID,          -- Entered ID, it can be blank
                     @nCountedQTY,
                     @cLottable01,
                     @cLottable02,
                     @cLottable03,
                     @dLottable04,
                     @dLottable05,
                     @cUserName,
                     @cLangCode,
                     @cNewCCDetailKey OUTPUT,
                     @nErrNo          OUTPUT,
                     @cErrMsg         OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END

            -- Stamp RDTCCLock's candidate to '9'
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               -- '1'=allow to continue update; '9'=Done
               Status = CASE WHEN CountedQty < SystemQty THEN '1' ELSE '9' END
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66851
               SET @cErrMsg = rdt.rdtgetmessage( 66851, @cLangCode, 'DSP') --'UPDCCLockFail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM cur_WithLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY
         END
         CLOSE cur_WithLotLabel
         DEALLOCATE cur_WithLotLabel
      END
   END
   /*************************************************************************************************/
   /* With Lottable Labels - End                                                                    */
   /*************************************************************************************************/

   /*************************************************************************************************/
   /* Without Lottable Labels - Start                                                               */
   /*************************************************************************************************/
   ELSE -- @cLottableFlag = 'N'
   BEGIN
      -- Check if any available data
      IF EXISTS ( SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
                  AND   CountNo = @nCCCountNo
                  AND   AddWho = @cUserName
                  AND   SKU = @cSKU
                  AND   LOC = @cLOC
                  AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
                  AND   CountedQty > 0
                  AND   (Status = '0' OR Status = '1') )
      BEGIN
         -- Look 4 the non empty LOT first and order by LOT asc
         DECLARE cur_WithoutLotLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, CCDetailKey, CountedQty, Lottable05 -- receipt date
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
            AND   CountNo = @nCCCountNo
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   CountedQty > 0
            AND   (Status = '0' OR Status = '1')
            AND   LOT <> ''
         ORDER BY LOT, CCDetailKey
         OPEN cur_WithoutLotLabel
         FETCH NEXT FROM cur_WithoutLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY, @dLottable05
         WHILE (@@FETCH_STATUS = 0)
         BEGIN
            IF ISNULL(@cLockCCDetKey, '') <> '' -- exists in ccdetail table
            BEGIN
               -- Update CCDetail
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cLockCCDetKey,
                  @nCountedQTY,
                  @cUserName,
                  @cLangCode,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
            ELSE -- New line (no ccdetail matched)
            BEGIN
               -- Find any new inserted line (status = '4')
               -- If found, update qty; else insert new line
               SET @cCCDetailKey = ''
               SELECT @cCCDetailKey = CCDetailKey,
                      @nQTY = CASE WHEN @nCCCountNo = 1 THEN Qty
                                   WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                                   WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                              END
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE CCSheetNo END
               AND   SKU = @cSKU
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   Status = '4' -- Newly inserted line

               IF ISNULL(@cCCDetailKey, '') <> ''
               BEGIN
                  SET @nCountedQTY = @nCountedQTY + @nQTY
                  -- Update CCDetail
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cCCDetailKey,
                     @nCountedQTY,
                     @cUserName,
                     @cLangCode,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Get max ccsheetno if it is blank
                  IF ISNULL(@cCCSheetNo, '') = ''
                  BEGIN
                     SELECT @cCCSheetNo = MAX(CCSheetNo)
                     FROM dbo.CCDETAIL WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                  END

                  -- Get the oldest lot
                  SELECT @dLottable05 = MIN(LA.Lottable05)
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.StorerKey = @cStorer
                     AND LLI.SKU = @cSKU
                     AND LLI.LOC = @cLOC
                     AND LLI.ID = CASE WHEN ISNULL(@cID, '') <> '' THEN @cID ELSE LLI.ID END

                  -- Insert a record into CCDETAIL
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cStorer,
                     @cSKU,
                     '',            -- No UCC
                     '',            -- No LOT generated yet
                     @cLOC,         -- Current LOC
                     @cID,          -- Entered ID, it can be blank
                     @nCountedQTY,
                     '',            -- Lottable01
                     '',            -- Lottable02
                     '',            -- Lottable03
                     NULL,          -- Lottable04
                     @dLottable05,  -- Lottable05
                     @cUserName,
                     @cLangCode,
                     @cNewCCDetailKey OUTPUT,
                     @nErrNo          OUTPUT,
                     @cErrMsg         OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END

            -- Stamp RDTCCLock's candidate to '9'
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               -- '1'=allow to continue update; '9'=Done
               Status = CASE WHEN CountedQty < SystemQty THEN '1' ELSE '9' END
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66852
               SET @cErrMsg = rdt.rdtgetmessage( 66852, @cLangCode, 'DSP') --'UPDCCLockFail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM cur_WithoutLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY, @dLottable05
         END
         CLOSE cur_WithoutLotLabel
         DEALLOCATE cur_WithoutLotLabel

         -- Now look for remaining empty LOT
         DECLARE cur_WithoutLotLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, CCDetailKey, CountedQty, Lottable05 -- receipt date
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE SheetNo END
            AND   CountNo = @nCCCountNo
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   LOC = @cLOC
            AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   CountedQty > 0
            AND   (Status = '0' OR Status = '1')
         ORDER BY CCDetailKey
         OPEN cur_WithoutLotLabel
         FETCH NEXT FROM cur_WithoutLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY, @dLottable05
         WHILE (@@FETCH_STATUS = 0)
         BEGIN
            IF ISNULL(@cLockCCDetKey, '') <> '' -- exists in ccdetail table
            BEGIN
               -- Update CCDetail
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                  @cCCRefNo,
                  @cCCSheetNo,
                  @nCCCountNo,
                  @cLockCCDetKey,
                  @nCountedQTY,
                  @cUserName,
                  @cLangCode,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
            ELSE -- New line (no ccdetail matched)
            BEGIN
               -- Find any new inserted line (status = '4')
               -- If found, update qty; else insert new line
               SET @cCCDetailKey = ''
               SELECT @cCCDetailKey = CCDetailKey,
                      @nQTY = CASE WHEN @nCCCountNo = 1 THEN Qty
                                   WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                                   WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                              END
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   CCSheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN @cCCSheetNo ELSE CCSheetNo END
               AND   SKU = @cSKU
               AND   LOC = @cLOC
               AND   ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND   Status = '4' -- Newly inserted line

               IF ISNULL(@cCCDetailKey, '') <> ''
               BEGIN
                  SET @nCountedQTY = @nCountedQTY + @nQTY
                  -- Update CCDetail
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cCCDetailKey,
                     @nCountedQTY,
                     @cUserName,
                     @cLangCode,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Get max ccsheetno if it is blank
                  IF ISNULL(@cCCSheetNo, '') = ''
                  BEGIN
                     SELECT @cCCSheetNo = MAX(CCSheetNo)
                     FROM dbo.CCDETAIL WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                  END

                  -- Get the oldest lot
                  SELECT @dLottable05 = MIN(LA.Lottable05)
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.StorerKey = @cStorer
                     AND LLI.SKU = @cSKU
                     AND LLI.LOC = @cLOC
                     AND LLI.ID = CASE WHEN ISNULL(@cID, '') <> '' THEN @cID ELSE LLI.ID END

                  -- Insert a record into CCDETAIL
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  EXECUTE rdt.rdt_CycleCount_InsertCCDetail
                     @cCCRefNo,
                     @cCCSheetNo,
                     @nCCCountNo,
                     @cStorer,
                     @cSKU,
                     '',            -- No UCC
                     '',            -- No LOT generated yet
                     @cLOC,         -- Current LOC
                     @cID,          -- Entered ID, it can be blank
                     @nCountedQTY,
                     '',            -- Lottable01
                     '',            -- Lottable02
                     '',            -- Lottable03
                     NULL,          -- Lottable04
                     @dLottable05,  -- Lottable05
                     @cUserName,
                     @cLangCode,
                     @cNewCCDetailKey OUTPUT,
                     @nErrNo          OUTPUT,
                     @cErrMsg         OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END

            -- Stamp RDTCCLock's candidate to '9'
            UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
               -- '1'=allow to continue update; '9'=Done
               Status = CASE WHEN CountedQty < SystemQty THEN '1' ELSE '9' END
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66852
               SET @cErrMsg = rdt.rdtgetmessage( 66852, @cLangCode, 'DSP') --'UPDCCLockFail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM cur_WithoutLotLabel INTO @nRowRef, @cLockCCDetKey, @nCountedQTY, @dLottable05
         END
         CLOSE cur_WithoutLotLabel
         DEALLOCATE cur_WithoutLotLabel
      END
   END
   /*************************************************************************************************/
   /* Without Lottable Labels - End                                                                 */
   /*************************************************************************************************/


   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN CycleCount_ConfirmSingleScan

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN CycleCount_ConfirmSingleScan
END

GO