SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CycleCount_SkuSingle                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cycle Count for SOS#190291                                  */
/*          1. SKU/UPC Single                                           */
/*          Copied from original rdtfnc_CycleCount                      */
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
/* 12-10-2010  1.1  ChewKP   Get ComponentSKU                           */
/*                           Clear Variable   (ChewKP01)                */
/* 30-09-2016  1.2  Ung      Performance tuning                         */
/* 28-10-2016  1.3  James    Change isDate to rdtIsValidDate (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CycleCount_SkuSingle] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET ANSI_DEFAULTS OFF
SET ANSI_WARNINGS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
                      
   @cLotLabel01       NVARCHAR( 20),  -- labels
   @cLotLabel02       NVARCHAR( 20),
   @cLotLabel03       NVARCHAR( 20),
   @cLotLabel04       NVARCHAR( 20),
   @cLotLabel05       NVARCHAR( 20)
                     
-- RDT.RDTMobRec variables
DECLARE              
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
   @nMenu             INT,
                     
   @cStorer           NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cFacility         NVARCHAR( 5),
   @cLOC              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
   @cLOT              NVARCHAR( 10),
   @cSKU              NVARCHAR( 20),
   @nQTY              INT,
   @cLottable01       NVARCHAR( 18),
   @cLottable02       NVARCHAR( 18),
   @cLottable03       NVARCHAR( 18),
   @dLottable04       DATETIME,
   @dLottable05       DATETIME,
                     
   @cCCRefNo          NVARCHAR( 10),
   @cCCSheetNo        NVARCHAR( 10),
   @nCCCountNo        INT,
   @cSuggestLOC       NVARCHAR( 10),
   @cSuggestLogiLOC   NVARCHAR( 18),
   @cLastLocFlag      NVARCHAR( 1),
   @cSheetNoFlag      NVARCHAR( 1),   
   @cLocType          NVARCHAR( 10),
   @cCCDetailKey      NVARCHAR( 10),
   @cWithQtyFlag      NVARCHAR( 1),
   @cNewSKU           NVARCHAR( 20),
   @cNewSKUDescr      NVARCHAR( 60),
   @cNewSKUDescr1     NVARCHAR( 20),
   @cNewSKUDescr2     NVARCHAR( 20),
   @cNewLottable01    NVARCHAR( 18),
   @cNewLottable02    NVARCHAR( 18),
   @cNewLottable03    NVARCHAR( 18),
   @cNewLottable04    NVARCHAR( 18),
   @cNewLottable05    NVARCHAR( 18),
   @dNewLottable04    DATETIME,
   @dNewLottable05    DATETIME,
   @cAddNewLocFlag    NVARCHAR( 1),   
   @cID_In            NVARCHAR( 18),  
   @cRecountFlag      NVARCHAR( 1),   
   @nRowRef           INT,
   @cSkuScanned       NVARCHAR(20),
   @nTranCount        INT

DECLARE  @cLottable01_Code    NVARCHAR( 20),
		   @cLottable02_Code    NVARCHAR( 20),
		   @cLottable03_Code    NVARCHAR( 20),
 		   @cLottable04_Code    NVARCHAR( 20),
         @cLottable05_Code    NVARCHAR( 20), 
   	   @cLottableLabel      NVARCHAR( 20),
		   @cTempLottable01     NVARCHAR( 18),
		   @cTempLottable02     NVARCHAR( 18),
		   @cTempLottable03     NVARCHAR( 18),
		   @cLottable04         NVARCHAR( 16),
		   @cLottable05         NVARCHAR( 16),
		   @dTemplottable04     DATETIME,
		   @dTempLottable05     DATETIME,
         @cLockSku            NVARCHAR( 20),
         @cLockLottable01     NVARCHAR( 18),
         @cLockLottable02     NVARCHAR( 18),
         @cLockLottable03     NVARCHAR( 18),
         @dLockLottable04     DATETIME,

         @cHasLottable        NVARCHAR( 1),
         @cZone1              NVARCHAR( 10),
         @cZone2              NVARCHAR( 10),
         @cZone3              NVARCHAR( 10),
         @cZone4              NVARCHAR( 10),
         @cZone5              NVARCHAR( 10),
         @cAisle              NVARCHAR( 10),
         @cLevel              NVARCHAR( 10),
         @nCCDLinesPerLOC     INT,        -- Total CCDetail Lines (LOC)
         @cOption             NVARCHAR( 1),
         @cOverrideLOCConfig  NVARCHAR( 1),
         @dtNewLottable04     DATETIME,
         @dtNewLottable05     DATETIME,
         @nSetFocusField      INT,
         @cLockedByDiffUser   NVARCHAR( 1),
         @cFoundLockRec       NVARCHAR( 1),
         @cMinCnt1Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt1
         @cMinCnt2Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt2
         @cMinCnt3Ind         NVARCHAR( 1),     -- Minimum Indicator for Counted_Cnt2   

         @cAttr07  NVARCHAR( 1), 
         @cAttr09  NVARCHAR( 1), 
         @cAttr11  NVARCHAR( 1), 
         @cAttr13  NVARCHAR( 1),
         @cOField02   NVARCHAR(60),
         @cOField03   NVARCHAR(60),
         @cOField04   NVARCHAR(60),
         @cOField05   NVARCHAR(60),
         @cOField06   NVARCHAR(60),
         @cOField07   NVARCHAR(60),
         @cOField08   NVARCHAR(60),
         @cOField09   NVARCHAR(60),
         @cOField10   NVARCHAR(60),
         @cOField11   NVARCHAR(60),
         @cOField12   NVARCHAR(60),
         @cOField13   NVARCHAR(60),
         @cUseLottable  NVARCHAR( 1),


   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorer           = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cLOC              = V_LOC,
   @cID               = V_ID,
   @cLOT              = V_LOT,
   @cSKU      = V_SKU,
   @nQTY              = CASE WHEN rdt.rdtIsValidQTY( V_QTY, 0) = 1 THEN V_QTY ELSE 0 END,
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @dLottable05       = V_Lottable05,

   @cCCRefNo          = V_String1,
   @cCCSheetNo        = V_String2,
   @nCCCountNo        = CASE WHEN rdt.rdtIsValidQTY( V_String3, 0) = 1 THEN V_String3 ELSE 0 END,
   @cSuggestLOC       = V_String4,
   @cSuggestLogiLOC   = V_String5,
   @cSheetNoFlag      = V_String6,
   @cLocType          = V_String7,
   @cCCDetailKey      = V_String8,
   @cWithQtyFlag      = V_String9,

   @cNewSKU           = V_String10,
   @cNewSKUDescr1     = V_String11,
   @cNewSKUDescr2     = V_String12,
   @cNewLottable01    = V_String13,
   @cNewLottable02    = V_String14,
   @cNewLottable03    = V_String15,
   @dNewLottable04    = CASE WHEN rdt.rdtIsValidDate (V_String16) = 1 THEN V_String16 ELSE NULL END,
   @dNewLottable05    = CASE WHEN rdt.rdtIsValidDate (V_String17) = 1 THEN V_String17 ELSE NULL END,
   @cAddNewLocFlag    = V_String18,
   @cID_In            = V_String19,
   @cRecountFlag      = V_String20,
   @cLastLocFlag      = V_String21,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01 = FieldAttr01,     @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CCRef                    INT,  @nScn_CCRef                    INT,
   @nStep_SheetNo_Criteria         INT,  @nScn_SheetNo_Criteria         INT, 
   @nStep_CountNo                  INT,  @nScn_CountNo                  INT,
   @nStep_LOC                      INT,  @nScn_LOC                      INT,
   @nStep_LOC_Option               INT,  @nScn_LOC_Option               INT, 
   @nStep_LAST_LOC_Option          INT,  @nScn_LAST_LOC_Option          INT, 
   @nStep_RECOUNT_LOC_Option       INT,  @nScn_RECOUNT_LOC_Option       INT, 
   @nStep_ID                       INT,  @nScn_ID                       INT,
   @nStep_SingleSKU                INT,  @nScn_SingleSKU                INT,
   @nStep_SingleSKU_Change         INT,  @nScn_SingleSKU_Change         INT

SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 2580,
   @nStep_SheetNo_Criteria         = 2,  @nScn_SheetNo_Criteria         = 2581, 
   @nStep_CountNo                  = 3,  @nScn_CountNo                  = 2582,
   @nStep_LOC                      = 4,  @nScn_LOC                      = 2583,
   @nStep_LOC_Option               = 5,  @nScn_LOC_Option               = 2584, 
   @nStep_LAST_LOC_Option          = 6,  @nScn_LAST_LOC_Option          = 2585, 
   @nStep_RECOUNT_LOC_Option       = 7,  @nScn_RECOUNT_LOC_Option       = 2586, 
   @nStep_ID                       = 8,  @nScn_ID                       = 2587,
   @nStep_SingleSKU                = 9,  @nScn_SingleSKU                = 2588,
   @nStep_SingleSKU_Change         =10,  @nScn_SingleSKU_Change         = 2589

IF @nFunc = 611 -- RDT Cycle Count - Single SKU
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 611
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 2580. CCREF
   IF @nStep = 2  GOTO Step_SheetNo_Criteria         -- Scn = 2581. SHEET NO OR Selection Criteria
   IF @nStep = 3  GOTO Step_CountNo                  -- Scn = 2582. COUNT NO
   IF @nStep = 4  GOTO Step_LOC                      -- Scn = 2583. LOC
   IF @nStep = 5  GOTO Step_LOC_Option               -- Scn = 2584. LOC - Option
   IF @nStep = 6  GOTO Step_LAST_LOC_Option          -- Scn = 2585. Last LOC - Option
   IF @nStep = 7  GOTO Step_RECOUNT_LOC_Option       -- Scn = 2586. Re-Count LOC - Option
   IF @nStep = 8  GOTO Step_ID                       -- Scn = 2587. ID
   IF @nStep = 9  GOTO Step_SingleSKU                -- Scn = 2588. SingleSKU
   IF @nStep = 10 GOTO Step_SingleSKU_Change         -- Scn = 2589. SingleSKU - changed
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 611. Screen 0.
********************************************************************************/
Step_Start:
BEGIN
   -- Clear the incomplete task for the same login
   DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
   WHERE StorerKey = @cStorer
   AND AddWho = @cUserName
   AND Status = '0'

   SELECT
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
 
      SET @cCCRefNo        = ''
      SET @cCCSheetNo      = ''
      SET @nCCCountNo      = 1 
      SET @cSuggestLOC     = ''
      SET @cSuggestLogiLOC = ''
      SET @cSheetNoFlag    = ''
      SET @cLocType        = ''
      SET @cCCDetailKey    = ''
      SET @cRecountFlag    = ''
      SET @cLastLocFlag    = ''
      SET @cSkuScanned     = ''
      SET @cSKU            = ''
      SET @cNewSKU         = ''
      SET @cNewSKUDescr1   = ''
      SET @cnewSKUDEscr2   = ''

      SET @nScn = @nScn_CCRef   -- 2580
      SET @nStep = @nStep_CCRef -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 2580. Screen 1.
   CCREF (field01)   - Input field
************************************************************************************/
Step_CCRef:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCCRefNo = @cInField01

       -- Retain the key-in value
       SET @cOutField01 = @cCCRefNo

      -- Validate CCKey
      IF @cCCRefNo = '' OR @cCCRefNo IS NULL
      BEGIN
         SET @nErrNo = 71366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CCREF required'
         GOTO CCRef_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS (SELECT 1 --TOP 1 CCKey
                  FROM dbo.CCDETAIL (NOLOCK)
                     WHERE CCKey = @cCCRefNo
                     AND StorerKey = @cStorer)
      BEGIN
         SET @nErrNo = 71367
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid CCREF'
         GOTO CCRef_Fail
      END

      -- Validate with StockTakeSheetParameters
      IF NOT EXISTS (SELECT TOP 1 StockTakeKey
                     FROM dbo.StockTakeSheetParameters (NOLOCK)
                     WHERE StockTakeKey = @cCCRefNo
                     AND   StorerKey = @cStorer
                     AND   Facility = @cFacility)
      BEGIN
         SET @nErrNo = 71368
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF'
         GOTO CCRef_Fail
      END

      EXEC rdt.rdtSetFocusField @nMobile, 2

      SET @nCCCountNo=1  
      SELECT @nCCCountNo = CASE WHEN ISNULL(STSP.FinalizeStage,0) = 0 THEN 1    
                                WHEN STSP.FinalizeStage = 1 THEN 2  
                                WHEN STSP.FinalizeStage = 2 THEN 3   
                           END    
      FROM dbo.StockTakeSheetParameters STSP (NOLOCK)  
      WHERE StockTakeKey = @cCCRefNo  
        
      IF ISNULL(@nCCCountNo,0) = 0   
      BEGIN  
         SET @nErrNo = 71369  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF'  
         GOTO CCRef_Fail  
      END        

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = ''         -- SheetNo
      SET @cOutField03 = 'ALL'      -- Zone1
      SET @cOutField04 = ''         -- Zone2
      SET @cOutField05 = ''         -- Zone3
      SET @cOutField06 = ''         -- Zone4
      SET @cOutField07 = ''         -- Zone5
      SET @cOutField08 = 'ALL'      -- Aisle
      SET @cOutField09 = 'ALL'      -- Level

      -- Go to next screen
      SET @nScn = @nScn_SheetNo_Criteria
      SET @nStep = @nStep_SheetNo_Criteria
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
      
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
   END
   GOTO Quit

   CCRef_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
   END
END
GOTO Quit

/************************************************************************************
Step_SheetNo_Criteria. Scn = 2581. Screen 2.
   CCREF (field01)
   SHEET (field02)   - Input field
   ZONE1 (field03)   - Input field
   ZONE2 (field04)   - Input field
   ZONE3 (field05)   - Input field
   ZONE4 (field06)   - Input field
   ZONE5 (field07)   - Input field
   AISLE (field08)   - Input field
   LEVEL (field09)   - Input field
************************************************************************************/
Step_SheetNo_Criteria:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCCSheetNo = @cInField02
      SET @cZone1     = @cInField03
      SET @cZone2     = @cInField04
      SET @cZone3     = @cInField05
      SET @cZone4     = @cInField06
      SET @cZone5     = @cInField07
      SET @cAisle     = @cInField08
      SET @cLevel     = @cInField09

      -- Retain the key-in value
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = @cZone1
      SET @cOutField04 = @cZone2
      SET @cOutField05 = @cZone3
      SET @cOutField06 = @cZone4
      SET @cOutField07 = @cZone5
      SET @cOutField08 = @cAisle
      SET @cOutField09 = @cLevel

      -- SheetNo and Zones/Aisle/Level are blank
      IF (@cCCSheetNo = '' OR @cCCSheetNo IS NULL) AND
         (@cZone1 = '' OR @cZone1 IS NULL) AND
         (@cZone2 = '' OR @cZone2 IS NULL) AND
         (@cZone3 = '' OR @cZone3 IS NULL) AND
         (@cZone4 = '' OR @cZone4 IS NULL) AND
         (@cZone5 = '' OR @cZone5 IS NULL) AND
         (@cAisle = '' OR @cAisle IS NULL) AND
         (@cLevel = '' OR @cLevel IS NULL)
      BEGIN
         SET @nErrNo = 71370
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SHEET required'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SheetNo_Criteria_Fail
      END

      -- ONLY allow SheetNo or Criteria
      IF (@cCCSheetNo <> '' AND @cCCSheetNo IS NOT NULL) AND
         ( (@cZone1 <> 'ALL' AND @cZone1 <> '' AND @cZone1 IS NOT NULL) OR
           (@cZone2 <> '' AND @cZone2 IS NOT NULL) OR
           (@cZone3 <> '' AND @cZone3 IS NOT NULL) OR
           (@cZone4 <> '' AND @cZone4 IS NOT NULL) OR
           (@cZone5 <> '' AND @cZone5 IS NOT NULL) OR
           (@cAisle <> 'ALL' AND @cAisle <> '' AND @cAisle IS NOT NULL) OR
           (@cLevel <> 'ALL' AND @cLevel <> '' AND @cLevel IS NOT NULL) )
      BEGIN
         SET @nErrNo = 71371
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Sheet/Criteria'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SheetNo_Criteria_Fail
      END

      -- Among 5 Zones, ONLY Zone1 allowed 'ALL'
      IF ( (@cZone2 = 'ALL' AND @cZone2 <> '' AND @cZone2 IS NOT NULL) OR
           (@cZone3 = 'ALL' AND @cZone3 <> '' AND @cZone3 IS NOT NULL) OR
           (@cZone4 = 'ALL' AND @cZone4 <> '' AND @cZone4 IS NOT NULL) OR
           (@cZone5 = 'ALL' AND @cZone5 <> '' AND @cZone5 IS NOT NULL) )
      BEGIN
         SET @nErrNo = 71372
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Wrong Zone'
         IF @cZone2 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 4
         IF @cZone3 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 5
         IF @cZone4 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 6
         IF @cZone5 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO SheetNo_Criteria_Fail
      END

      -- Initialize indicator
      SET @cMinCnt1Ind = '0'
      SET @cMinCnt2Ind = '0'
      SET @cMinCnt3Ind = '0'

      IF @cCCSheetNo <> '' AND @cCCSheetNo IS NOT NULL
      BEGIN
         SET @cSheetNoFlag = 'Y'

         -- Validate with CCDETAIL
         IF NOT EXISTS (SELECT TOP 1 CCDETAIL.CCKey
                        FROM dbo.CCDETAIL CCDETAIL (NOLOCK)
                        JOIN dbo.StockTakeSheetParameters STK (NOLOCK)
                           ON STK.StockTakeKey = CCDETAIL.CCKEY
                        WHERE CCDETAIL.CCKey = @cCCRefNo
                        AND   CCDETAIL.CCSheetNo = @cCCSheetNo
                        AND   STK.StorerKey = @cStorer)
         BEGIN
            SET @nErrNo = 71373
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid SHEET'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO SheetNo_Criteria_Fail
         END

         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
         AND StorerKey = @cStorer
         AND AddWho = @cUserName
        
         -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
         SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
               @cMinCnt2Ind = MIN(Counted_Cnt2),
               @cMinCnt3Ind = MIN(Counted_Cnt3)
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)
         WHERE CCD.CCKey = @cCCRefNo
         AND CCD.CCSheetNo = @cCCSheetNo
         AND CCD.StorerKey = @cStorer

         -- If configkey not turned on then proceed with insert CCDetail record to lock 
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
         BEGIN
            -- Insert into RDTCCLock
            INSERT INTO RDT.RDTCCLock
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
               Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
               StorerKey,  Sku,        Lot,         Loc, Id, 
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
               SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
            SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @nCCCountNo, 
               @cZone1,        @cZone2,        @cZone3,         @cZone4,        @cZone5,       @cAisle, @cLevel,
               CCD.StorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID, 
               CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05, 
               CCD.SystemQty,  
               --   CASE WHEN @nCCCountNo = 1 THEN CCD.Qty  
               --        WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2  
               --        WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3  
               --   END,          
               CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty  
                    WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2  
                    WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3  
               END,        
               '0',             '',             @cUserName,     GETDATE()
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            WHERE CCD.CCKey = @cCCRefNo
            AND CCD.CCSheetNo = @cCCSheetNo
            AND CCD.StorerKey = @cStorer
            -- Only select uncounted record
            AND 1 = CASE 
                       WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                       WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                       WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                    ELSE 0 
                    END            
     
            IF @@ROWCOUNT = 0 -- No data in CCDetail
            BEGIN
               SET @nErrNo = 71374
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'
               GOTO QUIT
            END
         END

        -- Prepare next screen var
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = @nCCCountNo -- CNT NO 
      END
      ELSE -- Key-in Zones/Aisle/Level
      BEGIN
         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
         AND StorerKey = @cStorer
         AND AddWho = @cUserName

         -- Performance tuning
         IF @cZone1 = 'ALL'
            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
            WHERE CCD.CCKey = @cCCRefNo
            AND CCD.StorerKey = @cStorer 
            AND LOC.Facility = @cFacility
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
            AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END                 
         ELSE
            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
            WHERE CCD.CCKey = @cCCRefNo
            AND CCD.StorerKey = @cStorer 
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)
            AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
            AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END    

         -- If configkey not turned on then proceed with insert CCDetail record to lock 
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
         BEGIN      
            IF @cZone1 = 'ALL'
               -- Insert RDTCCLock
               INSERT INTO RDT.RDTCCLock
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,   Level, 
                  StorerKey,  Sku,        Lot,         Loc,        Id, 
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey,  @cCCSheetNo,    0, 
                  @cZone1,        @cZone2,        @cZone3, @cZone4, @cZone5,        @cAisle,        @cLevel, 
                  CCD.StorerKey,  CCD.SKU,        CCD.LOT,          CCD.LOC,        CCD.ID, 
                  CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,   CCD.Lottable04, CCD.Lottable05, 
                  CCD.SystemQty,  
--                  CASE WHEN @nCCCountNo = 1 THEN CCD.Qty  
--                       WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2  
--                       WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3  
--                  END,          
                  CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty  
                       WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2  
                       WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3  
                  END,        
                  '0',             '',              @cUserName,     GETDATE()
               FROM dbo.CCDETAIL CCD WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
               WHERE CCD.CCKey = @cCCRefNo
               AND CCD.StorerKey = @cStorer
               AND LOC.Facility = @cFacility
               AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
               AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
               -- Only select uncounted record
               AND 1 = CASE 
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                       END
            ELSE
               -- Insert RDTCCLock
               INSERT INTO RDT.RDTCCLock
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,   Level, 
                  StorerKey,  Sku,        Lot,         Loc,        Id, 
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey,  @cCCSheetNo,    0, 
                  @cZone1,        @cZone2,        @cZone3, @cZone4, @cZone5,        @cAisle,        @cLevel, 
                  CCD.StorerKey,  CCD.SKU,        CCD.LOT,          CCD.LOC,        CCD.ID, 
                  CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,   CCD.Lottable04, CCD.Lottable05, 
                  CCD.SystemQty,  
                  --CASE WHEN @nCCCountNo = 1 THEN CCD.Qty  
                  --     WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2  
                  --     WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3  
                  --END,          
                  CASE WHEN @cMinCnt1Ind = '0' THEN CCD.Qty  
                       WHEN @cMinCnt2Ind = '0' THEN CCD.Qty_Cnt2  
                       WHEN @cMinCnt3Ind = '0' THEN CCD.Qty_Cnt3  
                  END,        
                  '0',             '',              @cUserName,     GETDATE()
               FROM dbo.CCDETAIL CCD WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
               WHERE CCD.CCKey = @cCCRefNo
               AND CCD.StorerKey = @cStorer
               AND LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)
               AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
               AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
               -- Only select uncounted record
               AND 1 = CASE 
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                       END
            
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 71375
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank record'
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO SheetNo_Criteria_Fail
            END
         END

         -- Prepare next screen var
         SET @cOutField02 = ''  -- Blank SHEET
         SET @cOutField03 = ''  -- CNT NO
      END

      -- Go to next screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Release locked record
      -- To Store those SystemQty <> CountedQty
      UPDATE RDT.RDTCCLock WITH (ROWLOCK)
         SET Status = '9'
      WHERE Mobile = @nMobile 
      AND StorerKey = @cStorer
      AND AddWho = @cUserName
      AND Status =  '1'

      DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
      WHERE Mobile = @nMobile 
      AND StorerKey = @cStorer
      AND AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 71376
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReleaseMobFail'
         ROLLBACK TRAN
         GOTO Quit
      END

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SHEET

      -- Reset this screen var
      SET @cOutField02 = @cCCSheetNo -- SHEET
      
      -- Back to previous screen
      SET @nScn = @nScn_CCRef
      SET @nStep = @nStep_CCRef
   END
   GOTO Quit

   SheetNo_Criteria_Fail:
   --BEGIN
      -- Reset this screen var
      -- SET @cOutField02 = '' -- SHEET
   --END
END
GOTO Quit

/************************************************************************************
Step_CountNo. Scn = 2582. Screen 3.
   CCREF    (field01)
   SHEET    (field02)
   COUNT NO (field03)   - Input field
************************************************************************************/
Step_CountNo:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cCCCountNo NVARCHAR( 10)

      -- Screen mapping
      SET @cCCCountNo = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cCCCountNo

      -- Validate CountNo
      IF @cCCCountNo = '' OR @cCCCountNo IS NULL
      BEGIN
         SET @nErrNo = 71377
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CNT NO required'
         GOTO CountNo_Fail
      END

      IF @cCCCountNo <> '1' AND @cCCCountNo <> '2' AND @cCCCountNo <> '3'
      BEGIN
         SET @nErrNo = 71378
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid CNT NO'
         GOTO CountNo_Fail
      END

      SET @nCCCountNo = CAST( @cCCCountNo AS INT)

      DECLARE @nFinalizeStage INT

      -- Generate countsheet with or without qty
      SET @cWithQtyFlag = 'N'

      -- Get finalized stage
      -- If FinalizeStage = 1 means 1st cnt already finalized.
      SELECT TOP 1
         @nFinalizeStage = FinalizeStage,
         @cWithQtyFlag = WithQuantity
      FROM dbo.StockTakeSheetParameters (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo
      AND   StorerKey = @cStorer
      AND   Facility = @cFacility

      -- Already counted 3 times, not allow to count again
      IF @nFinalizeStage = 3
      BEGIN
         SET @nErrNo = 71379
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Finalized Cnt3'
         GOTO CountNo_Fail
      END

      -- Entered CountNo must equal to FinalizeStage + 1, ie. if cnt1 not finalized, cannot go to cnt2
      IF @nCCCountNo <> @nFinalizeStage + 1
      BEGIN
         SET @nErrNo = 71380
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Wrong CNT NO'
         GOTO CountNo_Fail
      END

      -- If configkey not turned on 
      IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
      BEGIN
         SELECT TOP 1
            @cZone1 = Zone1,
            @cZone2 = Zone2,
            @cZone3 = Zone3,
            @cZone4 = Zone4,
            @cZone5 = Zone5,
            @cAisle = Aisle,
            @cLevel = Level
         FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND AddWho = @cUserName

         -- Update qty according to count no
         UPDATE CCL WITH (ROWLOCK) SET 
               CCL.Lottable01 = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable01
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable01_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable01_Cnt3 END, 
               CCL.Lottable02 = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable02
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable02_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable02_Cnt3 END, 
               Lottable03 = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable03
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable03_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable03_Cnt3 END, 
               Lottable04 = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable04
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable04_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable04_Cnt3 END, 
               Lottable05 = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Lottable05
                    WHEN @nCCCountNo = 2 THEN CCD.Lottable05_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Lottable05_Cnt3 END,       
               CountedQty = CASE 
                    WHEN @nCCCountNo = 1 THEN CCD.Qty
                    WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
                    WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3 END 
         FROM dbo.CCDetail CCD
         JOIN RDT.RDTCCLock CCL ON (CCD.StorerKey = CCL.StorerKey AND CCD.CCDetailkey = CCL.CCDetailKey)
         WHERE CCL.Mobile = @nMobile 
         AND CCL.CCKey = @cCCRefNo
         AND CCL.SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND CCL.StorerKey = @cStorer
         AND CCL.AddWho = @cUserName

         -- Get first suggested loc (sort by CCLogicalLOC)
         SET @cSuggestLOC = ''
         SET @cSuggestLogiLOC = ''

         EXECUTE rdt.rdt_CycleCount_GetNextLOC
            @cCCRefNo,
            @cCCSheetNo,
            @cSheetNoFlag,
            @cZone1,
            @cZone2,
            @cZone3,
            @cZone4,
            @cZone5,
            @cAisle,
            @cLevel,
            @cFacility,
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo, 
            @cUserName  

         -- Update RDTCCLock data with CountNo
         UPDATE RDT.RDTCCLock WITH (ROWLOCK) SET
            CountNo = @nCCCountNo
         WHERE Mobile = @nMobile
            AND CCKey = @cCCRefNo
            AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND StorerKey = @cStorer
            AND AddWho = @cUserName
            AND Status = '0'
            AND (CountNo = 0 OR ISNULL(CountNo, '') = '')
      END
      ELSE
      BEGIN
         -- Get first suggested loc (sort by CCLogicalLOC)
         SET @cSuggestLOC = ''
         SET @cSuggestLogiLOC = ''

         EXECUTE rdt.rdt_CycleCount_GetNextLOC
            @cCCRefNo,
            @cCCSheetNo,
            @cSheetNoFlag,
            'ALL',
            '',
            '',
            '',
            '',
            'ALL',
            'ALL',
            @cFacility,
            '',   -- current CCLogicalLOC is blank
            @cSuggestLogiLOC OUTPUT,
            @cSuggestLOC OUTPUT,
            @nCCCountNo, 
            @cUserName  
      END

      -- Get StorerConfig 'OverrideLOC' 
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorer)

      -- cater for recount
      IF @cOverrideLOCConfig <> '1' AND (@cSuggestLOC = '' OR @cSuggestLOC IS NULL)
      BEGIN
         SET @nErrNo = 71381
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC Not Found'
         GOTO CountNo_Fail
      END

      -- Get No. Of CCDetail Lines
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND LOC = @cSuggestLOC

       -- Reset LastLocFlag
      SET @cLastLocFlag = ''

      -- Prepare next screen var
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR(5))

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
    SELECT TOP 1
         @cZone1 = Zone1,
         @cZone2 = Zone2,
         @cZone3 = Zone3,
         @cZone4 = Zone4,
         @cZone5 = Zone5,
         @cAisle = Aisle,
         @cLevel = Level,
         @cCCSheetNo = SheetNo -- (Vicky03)
      FROM RDT.RDTCCLock WITH (ROWLOCK)
      WHERE Mobile = @nMobile
      AND CCKey = @cCCRefNo
      AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND StorerKey = @cStorer
      AND AddWho = @cUserName
      -- Get from latest record, not necessary status = '1'
      ORDER BY EditDate DESC

      -- Reset variables
      --SET @nCCCountNo = 0 
      SET @cSheetNoFlag = ''

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = @cZone1
      SET @cOutField04 = @cZone2
      SET @cOutField05 = @cZone3
      SET @cOutField06 = @cZone4
      SET @cOutField07 = @cZone5
      SET @cOutField08 = @cAisle
      SET @cOutField09 = @cLevel

    
      -- Go to previous screen
      SET @nScn = @nScn_SheetNo_Criteria
      SET @nStep = @nStep_SheetNo_Criteria
   END
   GOTO Quit

   CountNo_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- CNT NO
   END
END
GOTO Quit

/************************************************************************************
Step_LOC. Scn = 2583. Screen 4.
   CCREF         (field01)
   SHEET         (field02)
   CNT NO        (field03)
   LOC           (field04)   - Suggested LOC
   LOC           (field05)   - Input field
   TOTAL RECORDS (field06)
************************************************************************************/
Step_LOC:
BEGIN

   Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3)
   Values ('rdtfnc_CycleCount_SkuSingle', GetDate(), '2583 Scn4', '1', @cUserName, @cCCRefNo, @cCCSheetNo)

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField05

      -- Retain the key-in value
      SET @cOutField05 = @cLOC

      -- Get StorerConfig 'OverrideLOC' 
      SET @cOverrideLOCConfig = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorer)

      -- Check if the LOC scanned already locked by other ppl 
      IF ISNULL(@cLOC, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTCCLock WITH (NOLOCK) 
            WHERE StorerKey = @cStorer
               AND CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND Status = '0'
               AND AddWho <> @cUserName)
         BEGIN
            SET @nErrNo = 71382
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC is Locked'
            GOTO LOC_Fail
         END
      END

      -- If LOC is Blank and <Enter>, skip current LOC and get next LOC
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         -- If configkey not turned on 
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) <> '1'
         BEGIN
            SELECT TOP 1 
               @cZone1 = Zone1, 
               @cZone2 = Zone2, 
               @cZone3 = Zone3, 
               @cZone4 = Zone4, 
               @cZone5 = Zone5, 
               @cAisle = Aisle,
               @cLevel = Level
            FROM RDT.RDTCCLock WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
               AND   CountNo = @nCCCountNo
               AND   StorerKey = @cStorer
               AND   AddWho = @cUserName

            -- Get next suggested LOC         
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               @cZone1,
               @cZone2,
               @cZone3,
               @cZone4,
               @cZone5,
               @cAisle,
               @cLevel,
               @cFacility,
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo, 
               @cUserName  
         END
         ELSE
         BEGIN
            -- Get next suggested LOC         
            EXECUTE rdt.rdt_CycleCount_GetNextLOC
               @cCCRefNo,
               @cCCSheetNo,
               @cSheetNoFlag,
               'ALL',
               '',
               '',
               '',
               '',
               'ALL',
               'ALL',
               @cFacility,
               @cSuggestLogiLOC, -- current CCLogicalLOC
               @cSuggestLogiLOC OUTPUT,
               @cSuggestLOC OUTPUT,
               @nCCCountNo, 
               @cUserName 
         END

         -- Get No. Of CCDetail Lines
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND LOC = @cSuggestLOC

         IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
         BEGIN
            SET @cLastLocFlag = 'Y'
            SET @nErrNo = 71383
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Last LOC'
            GOTO LOC_Fail
         END

         -- Reset var with suggested LOC and Total Records
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField06 = CAST (@nCCDLinesPerLOC AS NVARCHAR( 5))

         -- Quit and remain at current screen
         GOTO Quit
      END

      -- LOC is NOT Blank
      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
         IF @cLOC = @cSuggestLOC AND @cAddNewLocFlag <> 'Y' -- If add new LOC, do not check
         BEGIN
            -- Check if all counted, get min(counted_cnt)
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND StorerKey = @cStorer
            AND LOC = @cLOC

            IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND StorerKey = @cStorer
               AND LOC = @cLOC
               AND 1 = CASE 
                   WHEN @nCCCountNo = 1 AND @cMinCnt1Ind = 0 THEN 1 
                   WHEN @nCCCountNo = 2 AND @cMinCnt2Ind = 0 THEN 1
                   WHEN @nCCCountNo = 3 AND @cMinCnt3Ind = 0 THEN 1 
                   ELSE 0 END) -- All Counted
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '1'   -- Option (Default to "YES")

               EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION 

               -- Go to Screen 4C. ReCount_LOC - Option
               SET @nScn = @nScn_RECOUNT_LOC_Option
               SET @nStep = @nStep_RECOUNT_LOC_Option

               GOTO Quit
            END
         END

         -- LOC not equal to suggested LOC
         IF @cLOC <> @cSuggestLOC
         BEGIN
            IF @cOverrideLOCConfig <> '1' -- Not allow override loc
            BEGIN
               SET @nErrNo = 71384
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC Not Match'
               GOTO LOC_Fail
            END

            IF @cOverrideLOCConfig = '1' -- Allow override loc
            BEGIN
               DECLARE @cChkFacility NVARCHAR( 5)
               SELECT TOP 1
                  @cChkFacility = Facility
               FROM dbo.LOC (NOLOCK)
               WHERE LOC = @cLOC

               IF @cChkFacility <> @cFacility
               BEGIN
                  SET @nErrNo = 71385
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Facility Diff'
                  GOTO LOC_Fail
               END

               -- Get CCLogicalLOC from entered LOC
               SELECT @cSuggestLogiLOC = LOC.CCLogicalLOC
               FROM dbo.LOC LOC (NOLOCK)
               WHERE LOC.LOC = @cLOC
               AND LOC.Facility = @cFacility

               IF @cSuggestLogiLOC = '' OR @cSuggestLogiLOC IS NULL
               BEGIN
                  SET @nErrNo = 71386
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup LogiLOC'
                  GOTO LOC_Fail
               END

               IF @cLastLocFlag = 'Y'
               BEGIN
                  -- Prepare next screen var
                  SET @cOutField01 = '1' -- Option (Default to "YES")

                  -- Go to next screen
                  SET @nScn = @nScn_LAST_LOC_Option
                  SET @nStep = @nStep_LAST_LOC_Option

                  GOTO Quit
               END
               -- IF @cLastLocFlag <> 'Y'
               ELSE
               BEGIN
                  -- Check if LOC found in CCDetail
                  IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
                             WHERE CCKey = @cCCRefNo
                             AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                             AND LOC = @cLOC)

                  BEGIN
                     -- Check if it is a valid loc within the same facility
                     IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                        WHERE LOC = @cLOC
                           AND Facility = @cFacility)
                     BEGIN
                        SET @nErrNo = 71387
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC Not Found'
                        GOTO LOC_Fail
                     END
                     ELSE
                     BEGIN
                        SET @cAddNewLocFlag = 'Y'
                     END

                     -- Prepare next screen var
                     SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4a. LOC - Option
                     SET @nScn = @nScn_LOC_Option
                     SET @nStep = @nStep_LOC_Option

                     GOTO Quit
                  END

                  -- Check if all counted, get min(counted_cnt)
                  SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                         @cMinCnt2Ind = MIN(Counted_Cnt2),
                         @cMinCnt3Ind = MIN(Counted_Cnt3)
                  FROM dbo.CCDETAIL WITH (NOLOCK)
                  WHERE CCKey = @cCCRefNo
                  AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                  AND StorerKey = @cStorer
                  AND LOC = @cLOC

                  -- Check if Counted location
                  IF NOT EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK)
                             WHERE CCKey = @cCCRefNo
                             AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
                             AND LOC = @cLOC
                             AND 1 = CASE 
                                 WHEN @nCCCountNo = 1 AND @cMinCnt1Ind = 0 THEN 1 
                                 WHEN @nCCCountNo = 2 AND @cMinCnt2Ind = 0 THEN 1
                                 WHEN @nCCCountNo = 3 AND @cMinCnt3Ind = 0 THEN 1 
                                 ELSE 0 END) -- All Counted
                  BEGIN
                     -- Prepare next screen var
                     SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4c. ReCount_LOC - Option
                     SET @nScn = @nScn_RECOUNT_LOC_Option
                     SET @nStep = @nStep_RECOUNT_LOC_Option

                     GOTO Quit
                  END
                  ELSE
                  -- Get StorerConfig 'SkipOverrideLOCScn'
                  IF rdt.RDTGetConfig( @nFunc, 'SkipOverrideLOCScn', @cStorer) <> '1'
                  BEGIN
                     -- Prepare next screen var
                     SET @cOutField01 = '1'   -- Option (Default to "YES")

                     EXEC rdt.rdtSetFocusField @nMobile, 1   -- OPTION

                     -- Go to Screen 4a. LOC - Option
                     SET @nScn = @nScn_LOC_Option
                     SET @nStep = @nStep_LOC_Option

                     GOTO Quit
                  END
               END
            END -- @cOverrideLOCConfig = 'Y'
         END -- IF @cLOC <> @cSuggestLOC

         -- Get any SKU in the particular LOC and ID (if any)
         SET @cSKU = ''
         SELECT TOP 1
            @cSKU = SKU
         FROM dbo.CCDETAIL (NOLOCK)
         WHERE CCKey = @cCCRefNo
         --AND   CCSheetNo = @cCCSheetNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND LOC = @cLOC
         AND StorerKey = @cStorer

         -- If Empty LOC generated in CCDetail, no SKU found.
         -- Get first LocType found in SKUxLOC
         IF @cSKU = '' OR @cSKU IS NULL
         BEGIN
            SELECT TOP 1 @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cStorer
            AND LOC = @cLOC
         END
         ELSE
         BEGIN
            -- With pre-requisite: SKUxLOC.LocationType must be correctly setup
            -- Assumption: Same storer and sku having same SKUxLOC.LocationType
            SELECT @cLocType = LocationType
            FROM dbo.SKUxLOC (NOLOCK)
            WHERE StorerKey = @cStorer
            AND SKU = @cSKU
            AND LOC = @cLOC
         END
      END

      -- If configkey turned on, start insert CCLock 
      IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
      BEGIN
         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
            AND StorerKey = @cStorer
            AND AddWho = @cUserName

         -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
         SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
               @cMinCnt2Ind = MIN(Counted_Cnt2),
               @cMinCnt3Ind = MIN(Counted_Cnt3)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND LOC = @cLOC
            AND StorerKey = @cStorer

         -- Insert into RDTCCLock
         INSERT INTO RDT.RDTCCLock
            (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
            Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
            StorerKey,  Sku,        Lot,         Loc, Id, 
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
            SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
         SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo, 
            'ALL',        '',        '',         '',         '',         'ALL',   'ALL',
            StorerKey,  SKU,        LOT,         LOC,        ID, 
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
            SystemQty,  
            CASE WHEN @nCCCountNo = 1 THEN Qty
                 WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                 WHEN @nCCCountNo = 3 THEN Qty_Cnt3
            END,        
            '0',         '',         @cUserName,  GETDATE()
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
            AND StorerKey = @cStorer
            AND LOC = @cLOC
            -- Only select uncounted record
            AND 1 = CASE 
                       WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                       WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                       WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                    ELSE 0 END            
  
         IF @@ROWCOUNT = 0 -- No data in CCDetail
         BEGIN
            SET @nErrNo = 71388
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'
            GOTO QUIT
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 6   -- ID

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))      
      SET @cOutField04 = '' -- Suggested LOC
      SET @cOutField05 = '' -- LOC
      SET @cOutField06 = '' -- Total Records

      -- Go to previous screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END
   GOTO Quit

   LOC_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField05 = '' -- LOC
   END
END
GOTO Quit

/************************************************************************************
Step_LOC_Option. Scn = 2584. Screen 4a.
   OPTION (field01)   - Input field
************************************************************************************/
Step_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 71389
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 71390
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LOC_Option_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = '' -- ID

         EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

         -- If configkey turned on, start insert CCLock
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
         BEGIN
            -- Release locked record
            DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
            WHERE Mobile = @nMobile 
               AND StorerKey = @cStorer
               AND AddWho = @cUserName

            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND StorerKey = @cStorer

            -- Insert into RDTCCLock
            IF @cAddNewLocFlag <> 'Y'
            BEGIN
               INSERT INTO RDT.RDTCCLock
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
                  StorerKey,  Sku,        Lot,         Loc, Id, 
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)
               SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo, 
                  'ALL',        '',        '',         '',         '',         'ALL',   'ALL',
                  StorerKey,  SKU,        LOT,         LOC,        ID, 
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
                  SystemQty,  
                  CASE WHEN @nCCCountNo = 1 THEN Qty
                       WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                       WHEN @nCCCountNo = 3 THEN Qty_Cnt3
                  END,                
                  '0',         '',         @cUserName,  GETDATE()
               FROM dbo.CCDETAIL WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
                  AND StorerKey = @cStorer
                  AND LOC = @cLOC
                 -- Only select uncounted record
                  AND 1 = CASE 
                             WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                             WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                             WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                          ELSE 0 
                          END            

               IF @@ROWCOUNT = 0 -- No data in CCDetail
               BEGIN
                  SET @nErrNo = 71391
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'
                  GOTO QUIT
               END
            END
         END

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END

      IF @cOption = '2'
      BEGIN
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND LOC = @cSuggestLOC

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR( 5))

         -- Go to previous screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND StorerKey = @cStorer
      AND LOC = @cSuggestLOC

      -- Reset this screen var (Retain all values)
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR( 5))

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_LAST_LOC_Option. Scn = 2585. Screen 4b.
   OPTION (field01)   - Input field
************************************************************************************/
Step_LAST_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 71392
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LAST_LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 71393
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO LAST_LOC_Option_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         SET @cAddNewLocFlag = 'Y'

         -- Set SuggestLOC equal to key-in LOC
         SET @cSuggestLOC = @cLOC

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = 0

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END

      IF @cOption = '2' -- NO
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CNT NO

         -- Go to next screen
         SET @nScn = @nScn_CountNo
         SET @nStep = @nStep_CountNo
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var (Retain all values)
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

      -- Go to previous screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END
   GOTO Quit

   LAST_LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_RECOUNT_LOC_Option. Scn = 2586. Screen 4c.
   OPTION (field01)   - Input field
************************************************************************************/
Step_RECOUNT_LOC_Option:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Retain the key-in value
      -- SET @cOutField01 = @cOption

      -- 1=YES, 2=NO
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 71394
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Option req'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO RECOUNT_LOC_Option_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 71395
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OPTION
         GOTO RECOUNT_LOC_Option_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         SET @cRecountFlag = 'Y'
         
         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = ''   -- ID

         EXEC rdt.rdtSetFocusField @nMobile, 6   -- ID

         -- If configkey turned on, start insert CCLock (james05)
         IF rdt.RDTGetConfig( @nFunc, 'InsCCLockAtLOCScn', @cStorer) = '1'
         BEGIN
            -- Release locked record
            DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
            WHERE Mobile = @nMobile 
            AND StorerKey = @cStorer
            AND AddWho = @cUserName

            -- Minimum counted_cnt1/2/3 = '0', means there are uncounted records
            SELECT @cMinCnt1Ind = MIN(Counted_Cnt1),
                  @cMinCnt2Ind = MIN(Counted_Cnt2),
                  @cMinCnt3Ind = MIN(Counted_Cnt3)
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND LOC = @cLOC
               AND StorerKey = @cStorer

            -- Insert into RDTCCLock
            INSERT INTO RDT.RDTCCLock
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo, 
               Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,
               StorerKey,  Sku,        Lot,         Loc, Id, 
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
               SystemQty,  CountedQty, Status,      RefNo,    AddWho,     AddDate)
            SELECT @nMobile,   CCKey,      CCDetailKey, CCSheetNo,  @nCCCountNo, 
               'ALL',        '',        '',         '',         '',         'ALL',   'ALL',
               StorerKey,  SKU,        LOT,         LOC,        ID, 
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05, 
               SystemQty,  
               CASE WHEN @nCCCountNo = 1 THEN Qty
                    WHEN @nCCCountNo = 2 THEN Qty_Cnt2
                    WHEN @nCCCountNo = 3 THEN Qty_Cnt3
               END,        
               '0',         '',         @cUserName,  GETDATE()
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCRefNo
               AND StorerKey = @cStorer
               AND LOC = @cLOC
               -- Only select uncounted record
               AND 1 = CASE 
                          WHEN @cMinCnt1Ind = '0' AND Counted_Cnt1 = '0' THEN 1
                          WHEN @cMinCnt2Ind = '0' AND Counted_Cnt2 = '0' THEN 1
                          WHEN @cMinCnt3Ind = '0' AND Counted_Cnt3 = '0' THEN 1
                       ELSE 0 
                       END            
     
            IF @@ROWCOUNT = 0 -- No data in CCDetail
            BEGIN
               SET @nErrNo = 71396
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'
               GOTO QUIT
            END
         END

         -- Go to next screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END

      IF @cOption = '2' -- NO
      BEGIN
         SELECT @nCCDLinesPerLOC = COUNT(1)
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND LOC = @cSuggestLOC

         -- Prepare next screen var
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
         SET @cOutField04 = @cSuggestLOC
         SET @cOutField05 = @cLOC
         SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR( 5))

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND StorerKey = @cStorer
      AND LOC = @cSuggestLOC

      -- Reset this screen var (Retain all values)
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = CAST( @nCCDLinesPerLOC AS NVARCHAR(5))

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   RECOUNT_LOC_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/************************************************************************************
Step_ID. Scn = 2587. Screen 5.
   CCREF  (field01)
   SHEET  (field02)
   COUNT  (field03)
   LOC    (field04)   - Suggested LOC
   LOC    (field05)
   ID     (field06)   - Input field
************************************************************************************/
Step_ID:
BEGIN

   Insert Into TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3, Col4)
   Values ('rdtfnc_CycleCount_SkuSingle', GetDate(), '2587 Scn5', '4', @cUserName, @cCCRefNo, @cCCSheetNo, @cInField06)

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cID_In = @cInField06

      -- Retain the key-in value
      SET @cOutField06 = @cID_In

      -- SINGLE SCAN screen
      SET @cID = @cID_In

      -- Prepare SINGLE SCAN screen var
      SET @nQty = 0
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '0'
      SET @cOutField03 = ''   -- SKU/UPC
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = 'Lottable01;'
      SET @cOutField07 = ''
      SET @cOutField08 = 'Lottable02:'
      SET @cOutField09 = ''
      SET @cOutField10 = 'Lottable03:'
      SET @cOutField11 = ''
      SET @cOutField12 = 'Lottable04:'
      SET @cOutField13 = ''
      SET @cFieldAttr07 = 'O'
      SET @cFieldAttr09 = 'O'
      SET @cFieldAttr11 = 'O'
      SET @cFieldAttr13 = 'O'
      

      
      

      EXEC rdt.rdtSetFocusField @nMobile, 3   -- SKU/UPC

      -- Go to SINGLE SCAN screen
      SET @nScn = @nScn_SingleSKU
      SET @nStep = @nStep_SingleSKU
      
      -- Skip insert to RDTCCLock, only insert at SKU SINGLE screen (Scn 6)
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset Flags
      SET @cRecountFlag   = ''
      SET @cLastLocFlag = ''
      SET @cAddNewLocFlag = ''

      -- Get No. Of CCDetail Lines
      SELECT @nCCDLinesPerLOC = COUNT(1)
      FROM dbo.CCDETAIL WITH (NOLOCK)
      WHERE CCKey = @cCCRefNo
      AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
      AND StorerKey = @cStorer
      AND LOC = @cSuggestLOC

      -- Reset this screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = ''   -- LOC
      SET @cOutField06 = CAST (@nCCDLinesPerLOC AS NVARCHAR( 5))

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

END
GOTO Quit

/************************************************************************************
Step_SingleSKU. Scn = 2588. Screen 6.
   LOC             (field01)
   COUNTER         (Field02)
   SKU/UPC         (field03) - Input
   SKU DESC1       (field04) 
   SKU DESC2       (field05)
   Lottable01Label (field06)
   Lottable01      (field07) -Input
   Lottable02Label (field08)
   Lottable02      (field09) -Input
   Lottable03Label (field10)
   Lottable03      (field11) -Input
   Lottable04Label (field12)
   Lottable04      (field13) -Input
   -- this is iterative screen
   -- 1st step --> Scan SKU --> system retrieves sku descr and lottablelabels
   -- 2nd step --> Scan lottables --> system increase counted qty and reset all fields
************************************************************************************/
Step_SingleSKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewSKU = @cInField03
      SET @cSkuScanned = @cNewSKUDescr1


--      -- Get ComponentSKU Values (Start) -- (ChewKP01)
--      SET @nErrNo = 0
      
--      EXEC [RDT].[rdt_GETSKU]  
--         @cStorerKey  = @cStorer, 
--         @cSKU        = @cNewSKU       OUTPUT,  
--         @bSuccess    = @b_success     OUTPUT, 
--         @nErr        = @nErrNo        OUTPUT, 
--         @cErrMsg     = @cErrMsg       OUTPUT
--      
--      IF @nErrNo <> 0
--      BEGIN
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
--            GOTO Step_SingleSKU_Fail
--      END     
--      -- Get ComponentSKU Values (End) -- (ChewKP01)
      
      -- Retain the key-in value
      SET @cOutField03 = @cNewSKU
      
      
      IF ISNULL(@cSkuScanned,'') = ''
      BEGIN
         -- 1st step scan sku
         SET @cFieldAttr06 = ''
         SET @cFieldAttr07 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr09 = ''
       SET @cFieldAttr10 = ''
         SET @cFieldAttr11 = ''
         SET @cFieldAttr12 = ''
         SET @cFieldAttr13 = ''
         SET @cFieldAttr14 = ''
         SET @cFieldAttr15 = ''

         -- Validate SKU
         IF @cNewSKU = '' OR @cNewSKU IS NULL
         BEGIN
            SET @nErrNo = 71397
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU/UPC req'
            GOTO Step_SingleSKU_Fail
         END

         IF (@cNewSKU <> @cSKU)  AND ISNULL(RTRIM(@cSKU),'') <> ''
         BEGIN
            -- Goto SKU changed screen
            IF rdt.RDTGetConfig( @nFunc, 'SkipSKUChangedScn', @cStorer) <> 1
            BEGIN
               SET @cOutField01 = @cNewSKU
               SET @cOutField02 = @cSKU
               SET @nScn = @nScn_SingleSKU_Change
               SET @nStep = @nStep_SingleSKU_Change
               GOTO Quit
            END
         END --IF @cNewSKU <> @cSKU

         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXEC rdt.rdt_CycleCount_CheckSKU 
            @cStorer,       
            @cNewSKU,      
            @cLoc,
            @cID,         
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,   
            @cUserName,   
            @nMobile,    
            @cLangCode,
            @cAttr07    OUTPUT, 
            @cAttr09    OUTPUT, 
            @cAttr11    OUTPUT, 
            @cAttr13    OUTPUT,
            @cOField02  OUTPUT,
            @cOField03  OUTPUT,
            @cOField04  OUTPUT,
            @cOField05  OUTPUT,
            @cOField06  OUTPUT,
            @cOField07  OUTPUT,
            @cOField08  OUTPUT,
            @cOField09  OUTPUT,
            @cOField10  OUTPUT,
            @cOField11  OUTPUT,
            @cOField12  OUTPUT,
            @cOField13  OUTPUT,
            @nSetFocusField OUTPUT,
            @cUseLottable  OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT 
         
         IF @nErrNo <> 0
         BEGIN 
            SET @cErrMsg = @cErrMsg
            EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
            GOTO Step_SingleSKU_Fail
         END

         SET @cNewSKUDescr1 = @cOField04
         SET @cNewSKUDescr2 = @cOField05
         SET @cFieldAttr03 = 'O'
         SET @cInField03 =  @cOField03 --(Kc02)
         SET @cOutField03 = @cOField03 --(Kc02)

         IF @cUseLottable = '1'
         BEGIN
            SET @cHasLottable = '1'
--            SET @cOutField02 = @cOField02
            SET @cOutField04 = @cOField04
            SET @cOutField05 = @cOField05
            SET @cOutField06 = @cOField06
            SET @cOutField07 = @cOField07
            SET @cOutField08 = @cOField08
            SET @cOutField09 = @cOField09
            SET @cOutField10 = @cOField10
            SET @cOutField11 = @cOField11
            SET @cOutField12 = @cOField12
            SET @cOutField13 = @cOField13
            SET @cFieldAttr07 = @cAttr07
            SET @cFieldAttr09 = @cAttr09
            SET @cFieldAttr11 = @cAttr11
            SET @cFieldAttr13 = @cAttr13
            
            EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
            GOTO QUIT
         END -- End of @cHasLottable = '1'
         ELSE
         BEGIN
            SET @cHasLottable = '0'
            SET @cOutField04 = @cOField04
            SET @cOutField05 = @cOField05
            SET @cNewLottable01 = ''
            SET @cNewLottable02 = ''
            SET @cNewLottable03 = ''
            SET @cNewLottable04 = ''
            SET @dNewLottable04 = NULL 
            SET @cFieldAttr07 = @cAttr07
            SET @cFieldAttr09 = @cAttr09
            SET @cFieldAttr11 = @cAttr11
            SET @cFieldAttr13 = @cAttr13

         END
      END -- if @skuscanned = ''
      ELSE
      BEGIN
         -- 2nd step - lottables keyed in
         SET @cNewLottable01 = @cInField07
         SET @cNewLottable02 = @cInField09
         SET @cNewLottable03 = @cInField11
         SET @cNewLottable04 = @cInField13

         -- Retain the key-in value
         SET @cOutField07 = @cNewLottable01
         SET @cOutField09 = @cNewLottable02
         SET @cOutField11 = @cNewLottable03
         SET @cOutField13 = @cNewLottable04

         SET @cErrMsg = ''

         IF rdt.rdtIsValidDate(@cNewLottable04) = 1 --valid date
            SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME)
         ELSE
            SET @dNewLottable04 = NULL

         -- Get Lottables Details
         EXECUTE rdt.rdt_CycleCount_GetLottables
            @cCCRefNo, @cStorer, @cNewSKU, 'POST', -- Codelkup.Short
            @cNewLottable01,
            @cNewLottable02,
            @cNewLottable03,
            @dNewLottable04,
            @dNewLottable05,
            @cLotLabel01      OUTPUT,
            @cLotLabel02      OUTPUT,
            @cLotLabel03      OUTPUT,
            @cLotLabel04      OUTPUT,
            @cLotLabel05      OUTPUT,
            @cLottable01_Code OUTPUT,
            @cLottable02_Code OUTPUT,
            @cLottable03_Code OUTPUT,
            @cLottable04_Code OUTPUT,
            @cLottable05_Code OUTPUT, 
            @cTempLottable01  OUTPUT,  --@cLottable01      OUTPUT,
            @cTempLottable02  OUTPUT,  --@cLottable02      OUTPUT,
            @cTempLottable03  OUTPUT,  --@cLottable03      OUTPUT,
            @dTempLottable04  OUTPUT,  --@dLottable04      OUTPUT,
            @dTempLottable05  OUTPUT,  --@dLottable05      OUTPUT,
            @cHasLottable     OUTPUT,
            @nSetFocusField   OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField
            SET @cErrMsg = @cErrMsg
            GOTO SINGLE_SKU_LOTTABLES_Fail
         END

         SET @cOutField07 = CASE WHEN ISNULL(@cTempLottable01,'') <> '' THEN @cTempLottable01 ELSE @cNewLottable01 END
         SET @cOutField09 = CASE WHEN ISNULL(@cTempLottable02,'') <> '' THEN @cTempLottable02 ELSE @cNewLottable02 END
         SET @cOutField11 = CASE WHEN ISNULL(@cTempLottable03,'') <> '' THEN @cTempLottable03 ELSE @cNewLottable03 END
         SET @cOutField13 = CASE WHEN @dTempLottable04 IS NOT NULL THEN rdt.rdtFormatDate( @dTempLottable04) ELSE rdt.rdtFormatDate( @dNewLottable04) END

         SET @cNewLottable01 = ISNULL(@cOutField07, '')
         SET @cNewLottable02 = ISNULL(@cOutField09, '')
         SET @cNewLottable03 = ISNULL(@cOutField11, '')
         SET @cNewLottable04 = ISNULL(@cOutField13, '')

         -- Validate lottable01
         IF @cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL
         BEGIN
            IF @cNewLottable01 = '' OR @cNewLottable01 IS NULL
            BEGIN
               SET @nErrNo = 71401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Lottable1 req'
               EXEC rdt.rdtSetFocusField @nMobile, 7
               GOTO SINGLE_SKU_LOTTABLES_Fail
            END
         END

         -- Validate Lottable02
         IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
         BEGIN
            IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
            BEGIN
               SET @nErrNo = 71402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Lottable2 req'
               EXEC rdt.rdtSetFocusField @nMobile, 9
               GOTO SINGLE_SKU_LOTTABLES_Fail
            END
         END

         -- Validate Lottable03
         IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
         BEGIN
            IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
            BEGIN
               SET @nErrNo = 71403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Lottable3 req'
               EXEC rdt.rdtSetFocusField @nMobile, 11
               GOTO SINGLE_SKU_LOTTABLES_Fail
            END
         END

         -- Validate Lottable04
         IF @cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL
         BEGIN
            -- Validate empty
            IF @cNewLottable04 = '' OR @cNewLottable04 IS NULL
            BEGIN
               SET @nErrNo = 71404
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Lottable4 req'
               EXEC rdt.rdtSetFocusField @nMobile, 13
               GOTO SINGLE_SKU_LOTTABLES_Fail
            END
            -- Validate date
            IF rdt.rdtIsValidDate( @cNewLottable04) = 0
            BEGIN
               SET @nErrNo = 71405
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid date'
               EXEC rdt.rdtSetFocusField @nMobile, 13
               GOTO SINGLE_SKU_LOTTABLES_Fail
            END
         END

         IF @cNewLottable04 <> '' AND @cNewLottable04 IS NOT NULL
            SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME)
         ELSE
            SET @dNewLottable04 = NULL
      END --if @cSkuScanned <> ''

      CONFIRM_SCAN:
      SET @cLockedByDiffUser = ''
      SET @cFoundLockRec     = ''

--      -- if any of the lottable values has changed, trigger write into CCDetail
--      -- for previous scanned records
--      IF (@cNewLottable01 <> @cLottable01 OR @cNewLottable02 <> @cLottable02 
--      OR @cNewLottable03 <> @cLottable03 OR @dNewLottable04 <> @dLottable04 
--      OR @cSKU <> @cNewSKU) AND ISNULL(RTRIM(@cSKU),'') <> ''
--      BEGIN
--         SET @nErrNo = 0
--         SET @cErrMsg = ''
--         -- Confirm Task for Single Scan
--         EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
--            @cCCRefNo,
--            @cCCSheetNo,
--            @nCCCountNo,
--            @cStorer,
--            @cSKU,
--            @cLOC,
--            @cID,        
--            @cSheetNoFlag,
--            @cWithQtyFlag,
--            @cUserName,
--            @cLottable01,
--            @cLottable02,
--            @cLottable03,
--            @dLottable04,
--            @cLangCode,
--            @nErrNo  OUTPUT,
--            @cErrMsg OUTPUT  -- screen limitation, 20 char max
--         
--         IF @nErrNo <> 0
--         BEGIN
--            SET @cErrMsg = @cErrMsg
--            EXEC rdt.rdtSetFocusField @nMobile, 7
--            GOTO SINGLE_SKU_LOTTABLES_Fail
--         END
--
--         SET @cLottable01 = @cNewLottable01
--         SET @cLottable02 = @cNewLottable02
--         SET @cLottable03 = @cNewLottable03
--         SET @dLottable04 = @dNewLottable04
--         SET @cSKU        = @cNewSKU
--      END

      -- lock current record into CCLock
      EXECUTE rdt.rdt_CycleCount_FindCCLock
         @nMobile, @cCCRefNo, @cCCSheetNo, @cStorer, @cUserName,
         @cNewSKU,
         @cLOC,
         @cID,
         @cNewLottable01,      -- Lottable01
         @cNewLottable02,      -- Lottable02
         @cNewLottable03,      -- Lottable03
         @dNewLottable04,      -- Lottable04
         @cWithQtyFlag,
         @cFoundLockRec     OUTPUT,
         @nRowRef           OUTPUT

         
      IF @cFoundLockRec = 'Y'
      BEGIN
         UPDATE RDT.RDTCCLock WITH (ROWLOCK)
         SET   CountedQty = CountedQty + 1
         WHERE RowRef = @nRowRef
      END
      ELSE
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXECUTE rdt.rdt_CycleCount_InsertCCLock
            @nMobile, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @cStorer, @cUserName,
            @cNewSKU,    -- @cSKU,
            '',          -- @cLOT,
            @cLOC,
            @cID,
            1,                -- CountedQTY
            @cNewLottable01,  -- @cLottable01
            @cNewLottable02,  -- @cLottable02
            @cNewLottable03,  -- @cLottable03
            @dNewLottable04,  -- @dLottable04
            NULL,          -- @dLottable05
            '',               -- @cRefNo 
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_SingleSKU_Fail   
      END

      SET @nQty = @nQty + 1
      SET @cNewSKUDescr1 = ''
      SET @cNewSKUDescr2 = ''
      SET @cSKU = @cNewSKU
      SET @cOutField02 = CAST(@nQty AS NVARCHAR(3))
      SET @cOutField03 = ''
      SET @cFieldAttr03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = 'Lottable01:'
      SET @cOutField07 = ''
      SET @cOutField08 = 'Lottable02:'
      SET @cOutField09 = ''
      SET @cOutField10 = 'Lottable03:'
      SET @cOutField11 = ''
      SET @cOutField12 = 'Lottable04:'
      SET @cOutField13 = ''

      SET @cFieldAttr07 = 'O'
      SET @cFieldAttr09 = 'O'
      SET @cFieldAttr11 = 'O'
      SET @cFieldAttr13 = 'O'
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''


      SET @cInField07 = '' -- (ChewKP01)     
      SET @cInField09 = '' -- (ChewKP01)
      SET @cInField11 = '' -- (ChewKP01)
      SET @cInField13 = '' -- (ChewKP01)

      SET @cNewLottable01 = '' -- (ChewKP01)
      SET @cNewLottable02 = '' -- (ChewKP01)
      SET @cNewLottable03 = '' -- (ChewKP01)
      SET @dNewLottable04 = '' -- (ChewKP01)

         
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- when esc out of the screen, make sure to confirm
      -- all pending scanned CC
      SET @nErrNo = 0
      SET @cErrMsg = ''
      SET @cLockSku = ''
      SET @cLockLottable01 = ''
      SET @cLockLottable02 = ''
      SET @cLockLottable03 = ''
      SET @dLockLottable04 = NULL
      IF @nQty <> 0
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         DECLARE C_PENDING_CCLOCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT SKU, Lottable01, Lottable02, Lottable03, Lottable04
         FROM   RDT.RDTCCLock WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND CCKey = @cCCRefNo
         AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
         AND StorerKey = @cStorer
         AND AddWho = @cUserName
         AND Loc = CASE WHEN @cLOC = '' THEN Loc ELSE @cLOC END
         AND Id  = CASE WHEN @cID  = '' THEN Id  ELSE @cID  END 
         AND Status <> '9' 
         AND CountedQty > 0

         OPEN C_PENDING_CCLOCK
         FETCH NEXT FROM C_PENDING_CCLOCK INTO  @cLockSku , @cLockLottable01, @cLockLottable02, 
                        @cLockLottable03, @dLockLottable04
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            -- Confirm Task for Single Scan
            EXECUTE rdt.rdt_CycleCount_ConfirmSingleScan
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cLockSku,
               @cLOC,
               @cID,        
               @cSheetNoFlag,
               @cWithQtyFlag,
               @cUserName,
               @cLockLottable01,
               @cLockLottable02,
               @cLockLottable03,
               @dLockLottable04,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max
            
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = @cErrMsg
               EXEC rdt.rdtSetFocusField @nMobile, 3
               ROLLBACK TRAN
               GOTO Step_SingleSKU_Fail
            END

            FETCH NEXT FROM C_PENDING_CCLOCK INTO  @cLockSku , @cLockLottable01, @cLockLottable02, 
                        @cLockLottable03, @dLockLottable04
         END --while
         WHILE @@TRANCOUNT > @nTranCount 
            COMMIT TRAN
         CLOSE C_PENDING_CCLOCK
         DEALLOCATE C_PENDING_CCLOCK
      END
      -- Re-initialize lottables
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      -- Set back values
      SET @cNewSKU       = ''
      SET @cSKU          = ''
      SET @cNewSKUDescr1 = ''
      SET @cNewSKUDescr2 = ''
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = ''                -- ID
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 6 -- ID

      -- Go to ID screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   Step_SingleSKU_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- SKU/UPC
      GOTO QUIT
   END

   SINGLE_SKU_LOTTABLES_Fail:
   BEGIN
      SET @cFieldAttr07 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr13 = ''

      -- Initiate next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr07 = 'O'
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr09 = 'O'
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            SET @cFieldAttr11 = 'O'
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr13 = 'O'
         END
      END
   END
END
GOTO Quit

/************************************************************************************
Step_SingleSKU_Change. Scn = 2589. Screen 7.
   NEWSKU          (field01)
   OLDSKU          (Field02)
************************************************************************************/
Step_SingleSKU_Change:
BEGIN
   IF @nInputKey = 0 -- only allow ESC
   BEGIN
      SET @cNewSKU = @cNewSKU
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXEC rdt.rdt_CycleCount_CheckSKU 
         @cStorer,       
         @cNewSKU,      
         @cLoc,
         @cID,         
         @cCCRefNo,
         @cCCSheetNo,
         @nCCCountNo,   
         @cUserName,   
         @nMobile,    
         @cLangCode,
         @cAttr07    OUTPUT, 
         @cAttr09    OUTPUT, 
         @cAttr11    OUTPUT, 
         @cAttr13    OUTPUT,
         @cOField02  OUTPUT,
         @cOField03  OUTPUT,
         @cOField04  OUTPUT,
         @cOField05  OUTPUT,
         @cOField06  OUTPUT,
         @cOField07  OUTPUT,
         @cOField08  OUTPUT,
         @cOField09  OUTPUT,
         @cOField10  OUTPUT,
         @cOField11  OUTPUT,
         @cOField12  OUTPUT,
         @cOField13  OUTPUT,
         @nSetFocusField OUTPUT,
         @cUseLottable  OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT 

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_SingleSKU_Change_Fail
      END

      SET @cNewSKUDescr1 = @cOField04
      SET @cNewSKUDescr2 = @cOField05

      IF @cUseLottable = '1'
      BEGIN
         SET @cHasLottable = '1'
         SET @cOutField01 = @cLoc
         SET @cOutField02 = CAST(@nQty as NVARCHAR(3))
         SET @cOutField03 = @cNewSKU
         SET @cOutField04 = @cOField04
         SET @cOutField05 = @cOField05
         SET @cOutField06 = @cOField06
         SET @cOutField07 = @cOField07
         SET @cOutField08 = @cOField08
         SET @cOutField09 = @cOField09
         SET @cOutField10 = @cOField10
         SET @cOutField11 = @cOField11
         SET @cOutField12 = @cOField12
         SET @cOutField13 = @cOField13
         SET @cFieldAttr07 = @cAttr07
         SET @cFieldAttr09 = @cAttr09
         SET @cFieldAttr11 = @cAttr11
         SET @cFieldAttr13 = @cAttr13

         EXEC rdt.rdtSetFocusField @nMobile, @nSetFocusField

      END -- End of @cHasLottable = '1'
      ELSE
      BEGIN
         SET @cHasLottable = '0'
         SET @cOutField01 = @cLoc
         SET @cOutField02 = CAST(@nQty as NVARCHAR(3))
         SET @cOutField03 = @cNewSKU
         SET @cOutField04 = @cOField04
         SET @cOutField05 = @cOField05
         SET @cNewLottable01 = ''
         SET @cNewLottable02 = ''
         SET @cNewLottable03 = ''
         SET @cNewLottable04 = ''
         SET @dNewLottable04 = NULL 
         SET @cOutField06 = 'Lottable01:'
         SET @cOutField07 = @cNewLottable01
         SET @cOutField08 = 'Lottable02:'
         SET @cOutField09 = @cNewLottable02
         SET @cOutField10 = 'Lottable03;'
         SET @cOutField11 = @cNewLottable03
         SET @cOutField12 = 'Lottable04:'
         SET @cOutField13 = @cNewLottable04

         SET @cFieldAttr07 = @cAttr07
         SET @cFieldAttr09 = @cAttr09
         SET @cFieldAttr11 = @cAttr11
         SET @cFieldAttr13 = @cAttr13
      END

      -- Go to SINGLE SCAN screen
      SET @cFieldAttr03 = 'O'
      SET @cInField03 = @cNewSKU
      SET @nScn = @nScn_SingleSKU
      SET @nStep = @nStep_SingleSKU
      GOTO QUIT

      Step_SingleSKU_Change_Fail:
      SET @cFieldAttr03 = ''
      SET @cOutField01 = @cLoc
      SET @cOutField02 = CAST(@nQty as NVARCHAR(3))
      SET @cOutField03 = @cNewSKU
   --   SET @cInField03 = @cNewSKU
      SET @nScn = @nScn_SingleSKU
      SET @nStep = @nStep_SingleSKU

   END

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorer,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_LOT          = @cLOT,
      V_SKU          = @cSKU,
      V_QTY          = @nQTY,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,

      V_String1      = @cCCRefNo,
      V_String2      = @cCCSheetNo,
      V_String3      = @nCCCountNo,
      V_String4      = @cSuggestLOC,
      V_String5      = @cSuggestLogiLOC,
      V_String6      = @cSheetNoFlag,  
      V_String7      = @cLocType,
      V_String8      = @cCCDetailKey,
      V_String9      = @cWithQtyFlag,
      V_String10     = @cNewSKU,
      V_String11     = @cNewSKUDescr1,
      V_String12     = @cNewSKUDescr2,
      V_String13     = @cNewLottable01,
      V_String14     = @cNewLottable02,
      V_String15     = @cNewLottable03,
      V_String16     = @dNewLottable04,
      V_String17     = @dNewLottable05,
      V_String18     = @cAddNewLocFlag,   
      V_String19     = @cID_In,  
      V_String20     = @cRecountFlag,
      V_String21     = @cLastLocFlag,
      
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,       
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,       
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,       
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,       
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,       
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,       
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,       
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,       
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,       
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,       
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,       
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,       
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,       
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,       
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,      

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
   
END



GO