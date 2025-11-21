SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_610GetNextLOC01                                 */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Get next location from CCDetail. If end of record then      */    
/*          go back to 1st record                                       */
/*                                                                      */    
/* Called from: rdt_CycleCount_GetNextLOC                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 02-Nov-2018 1.0  James    WMS6809 Created                            */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_610GetNextLOC01] (    
   @nMobile               INT,           
   @nFunc                 INT,           
   @cLangCode             NVARCHAR( 3),  
   @nStep                 INT,           
   @nInputKey             INT,           
   @cFacility             NVARCHAR( 5),  
   @cCCRefNo              NVARCHAR( 10), 
   @cCCSheetNo            NVARCHAR( 10), 
   @cSheetNoFlag          NVARCHAR( 1),  
   @nCCCountNo            INT,           
   @cZone1                NVARCHAR( 10), 
   @cZone2                NVARCHAR( 10), 
   @cZone3                NVARCHAR( 10), 
   @cZone4                NVARCHAR( 10), 
   @cZone5                NVARCHAR( 10), 
   @cAisle                NVARCHAR( 10), 
   @cLevel                NVARCHAR( 10), 
   @cCurrSuggestLogiLOC   NVARCHAR( 10), 
   @cCurrSuggestLOC       NVARCHAR( 10), 
   @cSuggestLogiLOC       NVARCHAR( 10) OUTPUT, 
   @cSuggestLOC           NVARCHAR( 10) OUTPUT 
)    
AS  
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cUserName      NVARCHAR( 18)
   --DELETE FROM TRACEINFO WHERE TRACENAME = '610'
   --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5, STEP1, STEP2) VALUES 
   --('610', GETDATE(), @cSheetNoFlag, @cZone1, @cAisle, @cLevel, @cCurrSuggestLogiLOC, @cSuggestLogiLOC, @cSuggestLOC)

   SET @cSuggestLogiLOC = ''
   SET @cSuggestLOC = ''

   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE MOBILE = @nMobile

   -- Get first suggested loc    
   SELECT TOP 1    
      @cSuggestLogiLOC = LOC.CCLogicalLOC,    
      @cSuggestLOC = LOC.LOC    
   FROM dbo.CCDetail CCD (NOLOCK)    
   INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
   WHERE CCD.CCKey = @cCCRefNo    
      AND LOC.Facility = @cFacility    
      AND LOC.CCLogicalLOC = @cCurrSuggestLogiLOC      
      AND LOC.LOC > @cCurrSuggestLOC
      AND ( ( ISNULL( @cSheetNoFlag, '') = 'Y' AND CCD.CCSheetNo = @cCCSheetNo))
      AND ( ( ISNULL( @cZone1, '') = 'ALL') OR ( LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5))) 
      AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END    
      AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                     
   -- Uncounted locations - to avoid looping Counted locations    
   AND 1 =  CASE     
            WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
            WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
            WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
            ELSE 1 END    
   -- exclude those LOC that already been locked by other ppl (james01)    
   AND NOT EXISTS (    
      SELECT 1 FROM RDT.RDTCCLock CCL WITH (NOLOCK)     
      WHERE CCD.CCKey = CCL.CCKEY    
         AND CCD.CCSheetNo = CASE WHEN ISNULL(CCL.SheetNo , '') = '' THEN CCD.CCSheetNo ELSE CCL.SheetNo END     -- (chee01)
         AND CCD.LOC = CCL.LOC    
         AND CCL.ADDWHO <> @cUserName    
         AND Status = '0')    
   ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC      

   IF @cSuggestLOC = ''
      SELECT TOP 1    
         @cSuggestLogiLOC = LOC.CCLogicalLOC,    
         @cSuggestLOC = LOC.LOC    
      FROM dbo.CCDetail CCD (NOLOCK)    
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
      WHERE CCD.CCKey = @cCCRefNo    
         AND LOC.Facility = @cFacility    
         AND LOC.CCLogicalLOC > @cCurrSuggestLogiLOC      
         AND ( ( ISNULL( @cSheetNoFlag, '') = 'Y' AND CCD.CCSheetNo = @cCCSheetNo))
         AND ( ( ISNULL( @cZone1, '') = 'ALL') OR ( LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5))) 
         AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END    
         AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                     
      -- Uncounted locations - to avoid looping Counted locations    
      AND 1 =  CASE     
               WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
               WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
               WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
               ELSE 1 END    
      -- exclude those LOC that already been locked by other ppl (james01)    
      AND NOT EXISTS (    
         SELECT 1 FROM RDT.RDTCCLock CCL WITH (NOLOCK)     
         WHERE CCD.CCKey = CCL.CCKEY    
            AND CCD.CCSheetNo = CASE WHEN ISNULL(CCL.SheetNo , '') = '' THEN CCD.CCSheetNo ELSE CCL.SheetNo END     -- (chee01)
            AND CCD.LOC = CCL.LOC    
            AND CCL.ADDWHO <> @cUserName    
            AND Status = '0')    
      ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC  
   ELSE 
      GOTO Quit

   IF @cSuggestLOC = ''
      -- Get first suggested loc    
      SELECT TOP 1    
         @cSuggestLogiLOC = LOC.CCLogicalLOC,    
         @cSuggestLOC = LOC.LOC    
      FROM dbo.CCDetail CCD (NOLOCK)    
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
      WHERE CCD.CCKey = @cCCRefNo    
         AND LOC.Facility = @cFacility    
         AND ( ( ISNULL( @cSheetNoFlag, '') = 'Y' AND CCD.CCSheetNo = @cCCSheetNo))
         AND ( ( ISNULL( @cZone1, '') = 'ALL') OR ( LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5))) 
         AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END    
         AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                     
      -- Uncounted locations - to avoid looping Counted locations    
      AND 1 =  CASE     
               WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
               WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
               WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
               ELSE 1 END    
      -- exclude those LOC that already been locked by other ppl (james01)    
      AND NOT EXISTS (    
         SELECT 1 FROM RDT.RDTCCLock CCL WITH (NOLOCK)     
         WHERE CCD.CCKey = CCL.CCKEY    
            AND CCD.CCSheetNo = CASE WHEN ISNULL(CCL.SheetNo , '') = '' THEN CCD.CCSheetNo ELSE CCL.SheetNo END     -- (chee01)
            AND CCD.LOC = CCL.LOC    
            AND CCL.ADDWHO <> @cUserName    
            AND Status = '0')    
      ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC    

   Quit:
END  

GO