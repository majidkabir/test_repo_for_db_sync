SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_732ExtGetLoc03                                  */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Based on rdt_SimpleCC_GetNextLOC, without lock by aisle     */
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-10-12  1.0  Ung      WMS-6163 Created                           */
/************************************************************************/ 
CREATE PROC [RDT].[rdt_732ExtGetLoc03] (  
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cCCKey                    NVARCHAR( 10), 
   @cCCSheetNo                NVARCHAR( 10), 
   @cStorerkey                NVARCHAR( 15), 
   @cFacility                 NVARCHAR( 5),  
   @cCurrSuggestLogiLOC       NVARCHAR( 10), 
   @cCurrSuggestSKU           NVARCHAR( 20), 
   @cCountNo                  NVARCHAR( 1), 
   @cUserName                 NVARCHAR( 18),        
   @cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, 
   @cSuggestLOC               NVARCHAR( 10) OUTPUT, 
   @cSuggestSKU               NVARCHAR( 20) OUTPUT, 
   @nErrNo                    INT           OUTPUT, 
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)  
AS
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @nCCCountNo INT

   SET @cSuggestLogiLOC = ''
   SET @cSuggestLoc     = ''
   SET @cSuggestSKU     = ''
   SET @nCCCountNo      = @cCountNo

   IF @cCurrSuggestLogiLOC = ''
   BEGIN
      -- Get first suggested loc
      SELECT TOP 1
               @cSuggestLogiLOC = Loc.CCLogicalLoc
             , @cSuggestLoc = Loc.Loc
             , @cSuggestSKU = CCD.SKU
      FROM dbo.CCDetail CCD (NOLOCK)
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
      WHERE CCD.CCKey   = @cCCKey
      AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))
      AND LOC.Facility  = @cFacility
      AND CCD.StorerKey = @cStorerKey
      AND ( (@nCCCountNo = 1 AND Counted_Cnt1 = 0) OR
            (@nCCCountNo = 2 AND Counted_Cnt2 = 0) OR
            (@nCCCountNo = 3 AND Counted_Cnt3 = 0))
      -- exclude ccsheet currently in used by other user
      AND NOT EXISTS ( SELECT 1 FROM rdt.rdtCCLock CCD2 WITH (NOLOCK)
                     WHERE CCKey = @cCCKey
                     AND Status = '3'
                     AND CCD2.SheetNo = @cCCSheetNo)
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
      WHERE CCD.CCKey   = @cCCKey
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
         WHERE CCD.CCKey   = @cCCKey
         AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))
         AND LOC.Facility  = @cFacility
         AND CCD.StorerKey = @cStorerKey
         AND LOC.CCLogicalLoc > @cCurrSuggestLogiLOC
         AND ( (@nCCCountNo = 1 AND Counted_Cnt1 = 0) OR
               (@nCCCountNo = 2 AND Counted_Cnt2 = 0) OR
               (@nCCCountNo = 3 AND Counted_Cnt3 = 0))
         -- exclude ccsheet currently in used by other user
         AND NOT EXISTS ( SELECT 1 FROM rdt.rdtCCLock CCD2 WITH (NOLOCK)
                        WHERE CCKey = @cCCKey
                        AND Status = '3'
                        AND CCD2.SheetNo = @cCCSheetNo
                        AND AddWho <> @cUserName)
         ORDER BY Loc.CCLogicalLoc, SKU
      END
   END

Quit:  

END

GO