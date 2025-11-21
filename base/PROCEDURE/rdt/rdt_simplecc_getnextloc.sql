SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_SimpleCC_GetNextLOC                             */
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
/* 11-07-2013  1.0  ChewKP   SOS#283253 Created                         */
/* 20-01-2015  1.1  James    Change sorting to CCLogicalLoc (james01)   */
/* 27-02-2017  1.2  James    Performance tuning (james02)               */
/* 19-04-2017  1.3  James    Performance tuning (james03)               */
/* 19-04-2017  1.4  Ung      Fix recompile issue                        */
/* 08-08-2018  1.5  Ung      WMS-5664 Rename confusing param name       */
/* 19-19-2018  1.6  Ung      WMS-6268 Fix CCSheetNo filter              */
/************************************************************************/

CREATE PROC [RDT].[rdt_SimpleCC_GetNextLOC] (
   @cCCRefNo            NVARCHAR( 10),
   @cCCSheetNo          NVARCHAR( 10),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cCurrSuggestLogiLOC NVARCHAR( 18),
   @cCurrSuggestSKU     NVARCHAR( 20),
   @cSuggestLogiLOC     NVARCHAR( 18) OUTPUT,
   @cSuggestLOC         NVARCHAR( 10) OUTPUT,
   @cSuggestSKU         NVARCHAR( 20) OUTPUT,
   @nCCCountNo          INT = 0,
   @cUserName           NVARCHAR( 18)
)
AS
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @cAisle AS NVARCHAR(10)
         , @cLogicalLoc AS NVARCHAR(18)
         , @cCurrLocAisle AS NVARCHAR(10)

   SET @cSuggestLogiLOC = ''
   SET @cSuggestLoc     = ''
   SET @cSuggestSKU     = ''

   IF @cCurrSuggestLogiLOC = ''
   BEGIN
      -- Get first suggested loc
      SELECT TOP 1
               @cSuggestLogiLOC = Loc.CCLogicalLoc
             , @cSuggestLoc = Loc.Loc
             , @cSuggestSKU = CCD.SKU
      FROM dbo.CCDetail CCD (NOLOCK)
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
      WHERE CCD.CCKey   = @cCCRefNo
      AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))
      AND LOC.Facility  = @cFacility
      AND CCD.StorerKey = @cStorerKey
      AND ( (@nCCCountNo = 1 AND Counted_Cnt1 = 0) OR
            (@nCCCountNo = 2 AND Counted_Cnt2 = 0) OR
            (@nCCCountNo = 3 AND Counted_Cnt3 = 0))
      -- exclude aisle currently in used by other user
      AND NOT EXISTS ( SELECT 1 FROM rdt.rdtCCLock CCD2 WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                     AND Status = '3'
                     AND CCD2.Aisle = LOC.LocAisle)
      ORDER BY Loc.CCLogicalLoc, SKU
   END
   ELSE
   BEGIN
       -- Get Same Loc for Different SKU loc
      SELECT TOP 1
               @cSuggestLogiLOC = Loc.CCLogicalLoc
             , @cSuggestLoc = Loc.Loc
             , @cSuggestSKU = CCD.SKU
      FROM dbo.CCDetail CCD (NOLOCK)
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
      WHERE CCD.CCKey   = @cCCRefNo
      AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))
      AND LOC.Facility  = @cFacility
      AND CCD.StorerKey = @cStorerKey
      AND LOC.CCLogicalLOC = @cCurrSuggestLogiLOC
      AND CCD.SKU > @cCurrSuggestSKU
      AND ( (@nCCCountNo = 1 AND Counted_Cnt1 = 0) OR
            (@nCCCountNo = 2 AND Counted_Cnt2 = 0) OR
            (@nCCCountNo = 3 AND Counted_Cnt3 = 0))
      ORDER BY Loc.CCLogicalLoc, SKU

      -- Get Another Loc
      IF ISNULL(@cSuggestLoc,'') = ''
      BEGIN
         SELECT TOP 1
                  @cSuggestLogiLOC = Loc.CCLogicalLoc
                , @cSuggestLoc = Loc.Loc
                , @cSuggestSKU = CCD.SKU
         FROM dbo.CCDetail CCD (NOLOCK)
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
         WHERE CCD.CCKey   = @cCCRefNo
         AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))
         AND LOC.Facility  = @cFacility
         AND CCD.StorerKey = @cStorerKey
         AND LOC.CCLogicalLoc > @cCurrSuggestLogiLOC
         AND ( (@nCCCountNo = 1 AND Counted_Cnt1 = 0) OR
               (@nCCCountNo = 2 AND Counted_Cnt2 = 0) OR
               (@nCCCountNo = 3 AND Counted_Cnt3 = 0))
         -- exclude aisle currently in used by other user
         AND NOT EXISTS ( SELECT 1 FROM rdt.rdtCCLock CCD2 WITH (NOLOCK)
                        WHERE CCKey = @cCCRefNo
                        AND Status = '3'
                        AND CCD2.Aisle = LOC.LocAisle
                        AND AddWho <> @cUserName)
         ORDER BY Loc.CCLogicalLoc, SKU
      END
   END
END

GO