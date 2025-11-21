SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_CycleCount_GetNextLOC_V7                        */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 06-May-2019 1.0  James       WMS-8649 Created                        */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_CycleCount_GetNextLOC_V7] (    
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cCCRefNo            NVARCHAR( 10),    
   @cCCSheetNo          NVARCHAR( 10),    
   @cSheetNoFlag        NVARCHAR( 1),    
   @cZone1              NVARCHAR( 10),    
   @cZone2              NVARCHAR( 10),    
   @cZone3              NVARCHAR( 10),    
   @cZone4              NVARCHAR( 10),    
   @cZone5              NVARCHAR( 10),    
   @cAisle              NVARCHAR( 10),    
   @cLevel              NVARCHAR( 10),    
   @cCurrSuggestLogiLOC NVARCHAR( 18),    
   @cSuggestLogiLOC     NVARCHAR( 18) OUTPUT,    
   @cSuggestLOC         NVARCHAR( 10) OUTPUT,    
   @nCCCountNo          INT = 0
      
)    
AS  
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cExtendedGetNextLocSP      NVARCHAR( 20)
   DECLARE @cSQL                       NVARCHAR( 2000)
   DECLARE @cSQLParam                  NVARCHAR( 2000)
   DECLARE @cCurrSuggestLOC            NVARCHAR( 10)
   DECLARE @cUserName                  NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cExtendedGetNextLocSP = rdt.RDTGetConfig( @nFunc, 'ExtendedGetNextLocSP', @cStorerKey)
   IF @cExtendedGetNextLocSP = '0'
      SET @cExtendedGetNextLocSP = ''      

   IF @cExtendedGetNextLocSP <> '' AND 
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedGetNextLocSP AND type = 'P')
   BEGIN
      SET @cCurrSuggestLOC = @cSuggestLOC
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedGetNextLocSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cCCRefNo, @cCCSheetNo, @cSheetNoFlag, ' +
         ' @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, @cCurrSuggestLogiLOC, @cCurrSuggestLOC, ' + 
         ' @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT '

      SET @cSQLParam =
         '@nMobile               INT,           ' +
         '@nFunc                 INT,           ' +
         '@cLangCode             NVARCHAR( 3),  ' +
         '@nStep                 INT,           ' +
         '@nInputKey             INT,           ' +
         '@cFacility             NVARCHAR( 5),  ' +
         '@cCCRefNo              NVARCHAR( 10), ' +
         '@cCCSheetNo            NVARCHAR( 10), ' +
         '@cSheetNoFlag          NVARCHAR( 1),  ' +
         '@nCCCountNo            INT,           ' +
         '@cZone1                NVARCHAR( 10), ' +
         '@cZone2                NVARCHAR( 10), ' +
         '@cZone3                NVARCHAR( 10), ' +
         '@cZone4                NVARCHAR( 10), ' +
         '@cZone5                NVARCHAR( 10), ' +
         '@cAisle                NVARCHAR( 10), ' +
         '@cLevel                NVARCHAR( 10), ' +
         '@cCurrSuggestLogiLOC   NVARCHAR( 10), ' +
         '@cCurrSuggestLOC       NVARCHAR( 10), ' +
         '@cSuggestLogiLOC       NVARCHAR( 10) OUTPUT, ' +
         '@cSuggestLOC           NVARCHAR( 10) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cCCRefNo, @cCCSheetNo, @cSheetNoFlag, 
         @nCCCountNo, @cZone1, @cZone2, @cZone3, @cZone4, @cZone5, @cAisle, @cLevel, @cCurrSuggestLogiLOC, @cCurrSuggestLOC, 
         @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT

      GOTO Quit
   END


   -- (MaryVong01)    
   IF @cSheetNoFlag = 'Y'    
   BEGIN    
      DECLARE     
         @cMinCnt1Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt1    
         @cMinCnt2Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt2    
         @cMinCnt3Ind         NVARCHAR( 1)      -- Minimum Indicator for Counted_Cnt2       
    
      SELECT @cMinCnt1Ind='',     
             @cMinCnt2Ind='',    
             @cMinCnt3Ind=''    
              
      SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),    
             @cMinCnt2Ind = MIN(Counted_Cnt2),    
             @cMinCnt3Ind = MIN(Counted_Cnt3)    
      FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
      WHERE CCD.CCKey = @cCCRefNo    
      AND CCD.CCSheetNo = @cCCSheetNo    
      -- AND CCD.StorerKey = @cStorer    

      delete from traceinfo where tracename = '635'
      insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1) values 
      ('635', getdate(), @cCCRefNo, @cCCSheetNo, @cFacility, @cCurrSuggestLogiLOC, @nCCCountNo, @cUserName)
      -- Get first suggested loc    
      SELECT TOP 1    
         @cSuggestLogiLOC = LOC.CCLogicalLOC,    
         @cSuggestLOC = LOC.LOC    
      FROM dbo.CCDetail CCD (NOLOCK)    
      INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
      WHERE CCD.CCKey = @cCCRefNo    
        AND CCD.CCSheetNo = @cCCSheetNo    
        AND LOC.Facility = @cFacility  
         -- Added just in case CCDetail having same loc for diff id    
         -- Commented - always go back to the Uncounted Location (not allow skip any location)    
        AND LOC.CCLogicalLOC > @cCurrSuggestLogiLOC  --Shong 03-Mar-2012  
        AND 1 =  CASE     
                    WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                    WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                    WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                    ELSE 1   
                 END                 
         -- exclude those LOC that already been locked by other ppl (james01)    
         AND NOT EXISTS (    
            SELECT 1 FROM RDT.RDTCCLock CCL WITH (NOLOCK)     
            WHERE CCD.CCKey = CCL.CCKEY    
               AND CCD.CCSheetNo = CCL.SheetNo 
               AND CCD.LOC = CCL.LOC    
               AND CCL.ADDWHO <> @cUserName    
               AND Status = '0')    
       ORDER BY LOC.CCLogicalLOC, LOC.LOC       
   END    
       
   -- @cSheetNoFlag = 'N' - by Zones/Aisle/Level    
   ELSE    
   BEGIN    
      IF @cZone1 = 'ALL'   --(james01)    
         -- Get first suggested loc    
         SELECT TOP 1    
            @cSuggestLogiLOC = LOC.CCLogicalLOC,    
            @cSuggestLOC = LOC.LOC    
         FROM dbo.CCDetail CCD (NOLOCK)    
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
         WHERE CCD.CCKey = @cCCRefNo    
            AND LOC.Facility = @cFacility    
            -- Added just in case CCDetail having same loc for diff id    
            -- Commented - always go back to the Uncounted Location (not allow skip any location)    
            -- AND LOC.LOC <> @cSuggestLOC    
            AND LOC.CCLogicalLOC > @cCurrSuggestLogiLOC      -- uncomment (james02)                            
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END    
            AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                     
            -- Uncounted locations - to avoid looping Counted locations    
            -- AND CCD.Status = '0'                                       
            AND 1 =  CASE     
                        WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                        WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                        ELSE 1   
                     END    
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
         -- Get first suggested loc    
         SELECT TOP 1    
            @cSuggestLogiLOC = LOC.CCLogicalLOC,    
            @cSuggestLOC = LOC.LOC    
         FROM dbo.CCDetail CCD (NOLOCK)    
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
         WHERE CCD.CCKey = @cCCRefNo    
            AND LOC.Facility = @cFacility    
            AND LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)    
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
                  AND CCD.CCSheetNo = CASE WHEN ISNULL(CCL.SheetNo , '') = '' THEN CCD.CCSheetNo ELSE CCL.SheetNo END   -- (chee01)
                  AND CCD.LOC = CCL.LOC    
                  AND CCL.ADDWHO <> @cUserName    
                  AND Status = '0')    
          ORDER BY LOC.LocAisle, LOC.LocLevel, LOC.CCLogicalLOC, LOC.LOC      
   END    
       
   IF @@ROWCOUNT = 0    
      SET @cSuggestLOC = ''        

   Quit:

END  

GO