SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_FindCCLock                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Verify existance of RDTCCLock Recods                        */
/*                                                                      */
/* Called from: rdtfnc_CycleCount                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-May-2009 1.0  MaryVong    Created                                 */
/* 24-Sep-2010 1.1  AQSKC       Fix Lottable04 comparison issue when    */
/*                              date = NULL (kc01)                      */
/* 22-Dec-2011 1.27 Ung         SOS235351 Handle empty LOC no StorerKey */
/* 20-Apr-2017 1.3  James       Remove ANSI_WARNINGS (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_FindCCLock] (
   @nMobile        INT,
   @cCCRefNo       NVARCHAR( 10),
   @cCCSheetNo     NVARCHAR( 10),
   @cStorer        NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @cWithQtyFlag   NVARCHAR( 1),
   @cFound         NVARCHAR( 1)  OUTPUT,
   @nRowRef        INT       OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nRecCnt          INT,
      @cLottableFlag    NVARCHAR( 1),
      @cLOTTABLE01LABEL NVARCHAR( 20),
      @cLOTTABLE02LABEL NVARCHAR( 20),
      @cLOTTABLE03LABEL NVARCHAR( 20),
      @cLOTTABLE04LABEL NVARCHAR( 20)

   SET @nRecCnt          = 0
   SET @cLottableFlag    = 'N'
   SET @cLOTTABLE01LABEL = ''
   SET @cLOTTABLE02LABEL = ''
   SET @cLOTTABLE03LABEL = ''
   SET @cLOTTABLE04LABEL = ''
   SET @cFound = 'N'  -- (Vicky03)

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

   /*************************************************************************************************/
   /* With Lottable Labels - Start                                                                  */
   /*************************************************************************************************/
   IF @cLottableFlag = 'Y'
   BEGIN
      SELECT @nRecCnt = COUNT(1)
      FROM RDT.RDTCCLock WITH (NOLOCK)
      WHERE Mobile = @nMobile
      AND   CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND   AddWho = @cUserName
      AND   SKU = @cSKU
      AND   Loc = @cLOC
      AND   Id  = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
      AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
      AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
      AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
      AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
      AND   (Status = '0' OR Status = '1')

      IF @nRecCnt > 0
      BEGIN
         SET @cFound = 'Y'

         SET @nRowRef = 0
         SELECT TOP 1 @nRowRef = RowRef
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND   CCKey = @cCCRefNo
         AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND   AddWho = @cUserName
         AND   SKU = @cSKU
         AND   Loc = @cLOC
         AND   Id  = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
         AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
         -- Status: '1'=CountedQty > 0 but less than SystemQty, allow to continue update
         AND   (Status = '0' OR Status = '1')
         -- SystemQty = 0 means newly added rdtCCLock record, ccdetailkey = <blank>
--         AND   (SystemQty = 0 OR CountedQty < SystemQty)
         -- Look 4 non empty LOT first and order by LOT asc
         AND   LOT <> ''
         ORDER BY -- update status = 1' first, if found in RDTCCLock table
            LOT,
            CASE WHEN Status = '1'  THEN 1
                 WHEN Status = '0'  THEN 2
                 WHEN @cWithQtyFlag = 'Y' AND SystemQty = 0 THEN 3 -- Newly inserted line
            END

         IF @nRowRef = 0 OR @nRowRef IS NULL
         BEGIN
            SELECT TOP 1 @nRowRef = RowRef
            FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE Mobile = @nMobile
            AND   CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   Loc = @cLOC
            AND   Id  = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
            AND   Lottable01 = CASE WHEN ISNULL(@cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL(@cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL(@cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL(Lottable04,'') = CASE WHEN ISNULL(@dLottable04, '') <> '' THEN @dLottable04 ELSE ISNULL(Lottable04,'') END    --(Kc01)
            -- Status: '1'=CountedQty > 0 but less than SystemQty, allow to continue update
            AND   (Status = '0' OR Status = '1')
            -- SystemQty = 0 means newly added rdtCCLock record, ccdetailkey = <blank>
--            AND   (SystemQty = 0 OR CountedQty < SystemQty)
            ORDER BY -- update status = 1' first, if found in RDTCCLock table
               CASE WHEN Status = '1'  THEN 1
                    WHEN Status = '0'  THEN 2
                    WHEN @cWithQtyFlag = 'Y' AND SystemQty = 0 THEN 3 -- Newly inserted line
               END

            IF @nRowRef = 0 OR @nRowRef IS NULL
               SET @cFound = 'N'
         END

         GOTO QUIT
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
      SELECT @nRecCnt = COUNT(1)
      FROM RDT.RDTCCLock WITH (NOLOCK)
      WHERE Mobile = @nMobile
      AND   CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND   AddWho = @cUserName
      AND   SKU = @cSKU
      AND   Loc = @cLOC
      AND   Id  = CASE WHEN ISNULL(@cID, '') = '' THEN Id ELSE @cID END
      AND   (Status = '0' OR Status = '1')

      IF @nRecCnt <= 0
         SELECT @nRecCnt = COUNT(1)
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND   CCKey = @cCCRefNo
         AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND   AddWho = @cUserName
         AND   SKU = @cSKU
         AND   Loc = @cLOC
         AND   Id  = CASE WHEN ISNULL(@cID, '') = '' THEN Id ELSE @cID END
         AND   (Status = '0' OR Status = '1')
         AND   SystemQTY > CountedQty

      IF @nRecCnt > 0
      BEGIN
         SET @cFound = 'Y'

         SET @nRowRef = 0
         SELECT TOP 1 @nRowRef = RowRef
         FROM RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND   CCKey = @cCCRefNo
         AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND   AddWho = @cUserName
         AND   SKU = @cSKU
         AND   Loc = @cLOC
         AND   Id  = @cID
         -- Status = '1' means CountedQty > 0 but less than SystemQty, allow to continue update
         AND   (Status = '0' OR Status = '1')
         -- SystemQty = 0 means newly added rdtCCLock record, ccdetailkey = <blank>
         AND   (SystemQty = 0 OR CountedQty < SystemQty)
         AND   LOT <> ''
         ORDER BY -- update status = 1' first, if found in RDTCCLock table
            LOT,
            CASE WHEN Status = '1'  THEN 1
                 WHEN Status = '0'  THEN 2
                 WHEN @cWithQtyFlag = 'Y' AND SystemQty = 0 THEN 3 -- Newly inserted line
            END

         IF @nRowRef = 0 OR @nRowRef IS NULL
         BEGIN
            SELECT TOP 1 @nRowRef = RowRef
            FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE Mobile = @nMobile
            AND   CCKey = @cCCRefNo
            AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND   AddWho = @cUserName
            AND   SKU = @cSKU
            AND   Loc = @cLOC
            AND   Id  = @cID
            -- Status = '1' means CountedQty > 0 but less than SystemQty, allow to continue update
            AND   (Status = '0' OR Status = '1')
            -- SystemQty = 0 means newly added rdtCCLock record, ccdetailkey = <blank>
            AND   (SystemQty = 0 OR CountedQty < SystemQty)
            AND   LOT = ''
            ORDER BY -- update status = 1' first, if found in RDTCCLock table
               CASE WHEN Status = '1'  THEN 1
                    WHEN Status = '0'  THEN 2
                    WHEN @cWithQtyFlag = 'Y' AND SystemQty = 0 THEN 3 -- Newly inserted line
               END

            IF @nRowRef = 0 OR @nRowRef IS NULL
               SET @cFound = 'N'
         END

         GOTO QUIT
      END
   END
   /*************************************************************************************************/
   /* Without Lottable Labels - End                                                                 */
   /*************************************************************************************************/

   QUIT:

END

GO