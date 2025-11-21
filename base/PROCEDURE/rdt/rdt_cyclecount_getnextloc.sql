SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_CycleCount_GetNextLOC                           */    
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
/* 29-May-2006 1.0  MaryVong Created                                    */    
/* 12-Jun-2007 1.1  MaryVong Add checking Loc <> SuggestLOC;            */    
/*                           set SuggestLOC = '' if no row found;       */    
/*                           modified SuggestLogiLOC to NVARCHAR(18)    */    
/* 30-Apr-2009 1.2  MaryVong SOS128449 & 133966                         */    
/*                           1) Select ONLY Uncounted locations         */    
/*                           2) Cater for retrieval by SheetNo or       */    
/*                              Zones/Aisle/Level                       */    
/*                           3) Not allowed to skip any location        */    
/*                              (MaryVong01)                            */    
/* 26-Mar-2010 1.3  James    SOS166769 - Performance tuning (james01)   */    
/* 02-Mar-2012 1.4  Shong    Do not use Min(Counted_Ctn)                */  
/* 03-Mar-2012 1.5  Shong    Commented loc > suggested loc              */  
/* 06-Nov-2012 1.6  James    Commented loc > suggested loc (james02)    */
/* 10-Oct-2013 1.7  Chee     User Locking Bug Fix (chee01)              */
/* 20-Apr-2017 1.8  James    Remove ANSI_WARNINGS (james03)             */
/* 02-Nov-2018 1.9  James    WMS6809 Add custom fetch task (james04)    */
/* 21-Mar-2024 2.0  NLT013   UWP-17125 Correct the sorting sequence     */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_CycleCount_GetNextLOC] (    
   @cCCRefNo            NVARCHAR( 10),    
   @cCCSheetNo          NVARCHAR( 10),    
   -- (MaryVong01)    
   --@cStorer             NVARCHAR( 15),    
   @cSheetNoFlag        NVARCHAR( 1),    
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
   @cSuggestLOC         NVARCHAR( 10) OUTPUT,    
   @nCCCountNo          INT = 0,    
   @cUserName           NVARCHAR( 18)   -- james01    
      
)    
AS  
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cExtendedGetNextLocSP      NVARCHAR( 20)
   DECLARE @cStorerKey                 NVARCHAR( 20)
   DECLARE @cSQL                       NVARCHAR( 2000)
   DECLARE @cSQLParam                  NVARCHAR( 2000)
   DECLARE @cLangCode                  NVARCHAR( 3)
   DECLARE @cCurrSuggestLOC            NVARCHAR( 10)
   DECLARE @nFunc                      INT
   DECLARE @nMobile                    INT
   DECLARE @nStep                      INT
   DECLARE @nInputKey                  INT

   SELECT @nMobile = Mobile,
          @nFunc = Func,
          @cLangCode = Lang_Code,
          @nStep = Step,
          @nInputKey = InputKey,
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = @cUserName
   DELETE FROM TRACEINFO WHERE TRACENAME = '6100'
   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES ('6100', GETDATE(), @cCurrSuggestLogiLOC, @cSuggestLogiLOC, @cSuggestLOC)
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
            AND LOC.CCLogicalLOC >= @cCurrSuggestLogiLOC      -- uncomment (james02)                            
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END    
            AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                                     
            -- Uncounted locations - to avoid looping Counted locations    
			-- Uncommit it, to loop all locations with same CCLogicalLOC
            AND CCD.Status = '0'                                       
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
         ORDER BY LOC.CCLogicalLOC, LOC.LocAisle, LOC.LocLevel, LOC.LOC      
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
          ORDER BY LOC.CCLogicalLOC, LOC.LocAisle, LOC.LocLevel, LOC.LOC      
   END    
       
   IF @@ROWCOUNT = 0    
      SET @cSuggestLOC = ''        

   Quit:

END  

GO