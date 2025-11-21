SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_BOM_GetNextLOC                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next location from CCDetail                             */
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
/* Date        Rev  Author   Purposes                                   */
/* 30-Nov-2006 1.0  James    Created                                    */
/* 20-Apr-2017 1.1  James    Remove ANSI_WARNINGS (james01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_BOM_GetNextLOC] (
   @cCCRefNo            NVARCHAR( 10),
   @cCCSheetNo          NVARCHAR( 10),
   @cSheetNoFlag        NVARCHAR( 1),
   @nCCCountNo          INT,
   @cZone1              NVARCHAR( 10),
   @cZone2              NVARCHAR( 10),
   @cZone3              NVARCHAR( 10),
   @cZone4              NVARCHAR( 10),
   @cZone5              NVARCHAR( 10),
   @cAisle              NVARCHAR( 10),
   @cLevel              NVARCHAR( 10),
   @cFacility           NVARCHAR( 5),
   @cCurrSuggestLogiLOC NVARCHAR( 18),
   @cSuggestLogiLOC     NVARCHAR( 18) OUTPUT,
   @cSuggestLOC         NVARCHAR( 10) OUTPUT   
  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- (MaryVong01)
   IF @cSheetNoFlag = 'Y'
   BEGIN
      -- Get first suggested loc
      SELECT TOP 1
         @cSuggestLogiLOC = LOC.CCLogicalLOC,
         @cSuggestLOC = LOC.LOC
      FROM dbo.CCDetail CCD (NOLOCK)
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
      WHERE CCD.CCKey = @cCCRefNo
         AND CCD.CCSheetNo = @cCCSheetNo
         AND LOC.Facility = @cFacility
         AND 1 =  CASE 
                  WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                  WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                  ELSE 1 
            END
       ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC   
   END
   
   -- @cSheetNoFlag = 'N' - by Zones/Aisle/Level
   ELSE
   BEGIN
      -- Get first suggested loc
      SELECT TOP 1
         @cSuggestLogiLOC = LOC.CCLogicalLOC,
         @cSuggestLOC = LOC.LOC
      FROM dbo.CCDetail CCD (NOLOCK)
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
      WHERE CCD.CCKey = @cCCRefNo
         AND LOC.Facility = @cFacility
         AND ( (LOC.PutawayZone = CASE WHEN @cZone1 = 'ALL' THEN LOC.PutawayZone END) OR
               (LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)) )
         AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
         AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                 
         AND 1 =  CASE 
                  WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                  WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                  ELSE 1 
            END
       ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC  
   END
   
   IF @@ROWCOUNT = 0
      SET @cSuggestLOC = ''

END

GO