SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_732ExtGetLoc01                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next location from CCDetail. For count 2 & 3, skip loc  */  
/*          with no variance                                            */  
/*                                                                      */  
/* Called from: rdtfnc_SimpleCC                                         */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-04-21  1.0  James    SOS370878 - Created                        */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_732ExtGetLoc01] (  
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cCCKey                    NVARCHAR( 10), 
   @cCCSheetNo                NVARCHAR( 10), 
   @cStorerkey                NVARCHAR( 15), 
   @cFacility                 NVARCHAR( 5),  
   @cCurrSuggestLOC           NVARCHAR( 10), 
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
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cAisle            NVARCHAR(10)
         , @cLogicalLoc       NVARCHAR(18)
         , @cCurrLocAisle     NVARCHAR(10)
         , @cCurrSuggestLogicLOC    NVARCHAR(10)
   
--   DECLARE @t_Aisle_InUsed TABLE (LocAIsle NVARCHAR(10), UserKey NVARCHAR(18))
   
   SELECT @cCurrLocAisle = LocAisle, @cCurrSuggestLogicLOC = CCLogicalLoc
   FROM dbo.Loc WITH (NOLOCK)
   WHERE Loc = @cCurrSuggestLOC
   AND   Facility = @cFacility

--   INSERT INTO @t_Aisle_InUsed (LocAisle, UserKey)
--   SELECT ISNULL(Aisle,'') , EditWho 
--   FROM rdt.RDTCCLock WITH (NOLOCK)
--   WHERE CCKey = @cCCKey
--   AND Status = '3'
--   AND Aisle <> @cCurrLocAisle

   SET @cSuggestLogiLOC = ''
   SET @cSuggestLoc     = ''
   SET @cSuggestSKU     = ''

   IF @cCurrSuggestLOC = ''
   BEGIN
      -- Get first suggested loc  
      -- Always count all for count 1
      -- For count #2 onwards, only fetch those ccdetail with variances in previous count
      -- For example, count #2 need compare systemqty with qty; count #3 need compare systemqty with qty_cnt2
      SELECT TOP 1
               @cSuggestLogiLOC = Loc.CCLogicalLoc
             , @cSuggestLoc = Loc.Loc
             , @cSuggestSKU = CCD.SKU
      FROM dbo.CCDetail CCD WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (CCD.LOC = LOC.LOC)  
      WHERE CCD.CCKey   = @cCCKey               
      AND   CCD.CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCD.CCSheetNo END
      AND   LOC.Facility  = @cFacility
      AND   CCD.StorerKey = @cStorerKey
      AND   1 =  CASE   
                    WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0  
                    WHEN @cCountNo = 2 AND ( Counted_Cnt2 = 1 OR SYSTEMQTY = Qty) THEN 0  
                    WHEN @cCountNo = 3 AND ( Counted_Cnt3 = 1 OR SYSTEMQTY = Qty_Cnt2) THEN 0  
                    ELSE 1 
                 END  
--      AND NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU     
--                      WHERE AIU.LocAisle = LOC.LocAisle )	
      ORDER BY Loc.CCLogicalLoc, Loc.Loc, SKU                               
   END
   ELSE
   BEGIN
       -- Get Same Loc for Different SKU loc  
      SELECT TOP 1
               @cSuggestLogiLOC = Loc.CCLogicalLoc
             , @cSuggestLoc = Loc.Loc
             , @cSuggestSKU = CCD.SKU
      FROM dbo.CCDetail CCD WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (CCD.LOC = LOC.LOC)  
      WHERE CCD.CCKey   = @cCCKey               
      AND   CCD.CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCD.CCSheetNo END
      AND   CCD.StorerKey = @cStorerKey
      AND   LOC.Facility  = @cFacility 
      AND   LOC.CCLogicalLoc = @cCurrSuggestLogicLOC     
      AND   LOC.Loc = @cCurrSuggestLOC 
      AND   CCD.SKU > @cCurrSuggestSKU
      AND   1 =  CASE   
                    WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0  
                    WHEN @cCountNo = 2 AND ( Counted_Cnt2 = 1 OR SYSTEMQTY = Qty) THEN 0  
                    WHEN @cCountNo = 3 AND ( Counted_Cnt3 = 1 OR SYSTEMQTY = Qty_Cnt2) THEN 0  
                    ELSE 1 
                 END  
      ORDER BY CCD.SKU                                 
      
      -- Get Another Loc in same cclogicalloc
      IF ISNULL(@cSuggestLoc,'') = ''
      BEGIN
         SELECT TOP 1
                  @cSuggestLogiLOC = Loc.CCLogicalLoc
                , @cSuggestLoc = Loc.Loc
                , @cSuggestSKU = CCD.SKU
         FROM dbo.CCDetail CCD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (CCD.LOC = LOC.LOC)  
         WHERE CCD.CCKey   = @cCCKey      
         AND   CCD.CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCD.CCSheetNo END
         AND   CCD.StorerKey = @cStorerKey
         AND   LOC.Facility  = @cFacility
         AND   LOC.CCLogicalLoc = @cCurrSuggestLogicLOC     
         AND   LOC.Loc > @cCurrSuggestLOC 
         AND   1 =  CASE   
                       WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0  
                       WHEN @cCountNo = 2 AND ( Counted_Cnt2 = 1 OR SYSTEMQTY = Qty) THEN 0  
                       WHEN @cCountNo = 3 AND ( Counted_Cnt3 = 1 OR SYSTEMQTY = Qty_Cnt2) THEN 0  
                       ELSE 1 
                    END  
--         AND NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU     
--                         WHERE AIU.LocAisle = LOC.LocAisle AND AIU.USERKEY = CCD.ADDWHO)	
         ORDER BY Loc.Loc, SKU                               
      END
      
      -- Get Another Loc in different cclogicalloc
      IF ISNULL(@cSuggestLoc,'') = ''
      BEGIN
         SELECT TOP 1
                  @cSuggestLogiLOC = Loc.CCLogicalLoc
                , @cSuggestLoc = Loc.Loc
                , @cSuggestSKU = CCD.SKU
         FROM dbo.CCDetail CCD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (CCD.LOC = LOC.LOC)  
         WHERE CCD.CCKey   = @cCCKey      
         AND   CCD.CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCD.CCSheetNo END
         AND   CCD.StorerKey = @cStorerKey
         AND   LOC.Facility  = @cFacility
         AND   LOC.CCLogicalLoc > @cCurrSuggestLogicLOC     
         AND   1 =  CASE   
                       WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0  
                       WHEN @cCountNo = 2 AND ( Counted_Cnt2 = 1 OR SYSTEMQTY = Qty) THEN 0  
                       WHEN @cCountNo = 3 AND ( Counted_Cnt3 = 1 OR SYSTEMQTY = Qty_Cnt2) THEN 0  
                       ELSE 1 
                    END  
--         AND NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU     
--                         WHERE AIU.LocAisle = LOC.LocAisle AND AIU.USERKEY = CCD.ADDWHO)	
         ORDER BY Loc.CCLogicalLoc, Loc.Loc, SKU                               
      END
   END

END
Quit:  

GO