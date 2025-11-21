SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_CycleCount_BOM                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cycle Count for BOM                                         */
/*                                                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 30-Nov-2006 1.0  James    Created (Modified from rdtfnc_CycleCount)  */
/* 04-Jan-2010 1.1  James    Bug fix (james01)                          */
/* 02-Jun-2010 1.2  Shong    Cater for Normal SKU as well               */
/* 30-Sep-2016 1.3  Ung      Performance tuning                         */
/* 28-Oct-2016 1.4  James    Change isDate to rdtIsValidDate (james02)  */
/* 06-Nov-2017 1.5  James    Fix ansi option (james03)                  */
/* 30-Oct-2018 1.6  TungGH   Performance                                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CycleCount_BOM] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variables
DECLARE
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
                      
   @cNewLottable04    NVARCHAR( 18),
   @cNewLottable05    NVARCHAR( 18),
   @cLotLabel01       NVARCHAR( 20),  
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
                     
   @cStorerKey        NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cFacility         NVARCHAR( 5),
   @cLOC              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
   @cLOT              NVARCHAR( 10),
   @cSKU              NVARCHAR( 20),
   @cBOM              NVARCHAR( 20),
   @cSKUDescr         NVARCHAR( 60),
   @cUOM              NVARCHAR( 3),   
   @cPackKey          NVARCHAR( 10),   
   @cColor            NVARCHAR( 10),   
   @cNextColor        NVARCHAR( 10),   
   @nQTY              INT,
   @cQty              NVARCHAR( 5),
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
   @cSheetNoFlag      NVARCHAR( 1),   
   @cCCDetailKey      NVARCHAR( 10),
   @cNewLottable01    NVARCHAR( 18),
   @cNewLottable02    NVARCHAR( 18),
   @cNewLottable03    NVARCHAR( 18),
   @dNewLottable04    DATETIME,
   @dNewLottable05    DATETIME,
   @cID_In            NVARCHAR( 18),  
   @cSize1            NVARCHAR( 5), 
   @cSize2            NVARCHAR( 5), 
   @cSize3            NVARCHAR( 5), 
   @cSize4            NVARCHAR( 5), 
   @cSize5            NVARCHAR( 5), 
   @cSize6            NVARCHAR( 5), 
   @cBOM_Size         NVARCHAR( 5), 
   @nQty1             INT, 
   @nQty2             INT, 
   @nQty3             INT, 
   @nQty4             INT, 
   @nQty5             INT, 
   @nQty6             INT, 
   @nBOM_Qty          INT, 
   @nDummyCount       INT, 
   @nPackValue        INT,
   @cMinCnt1Ind       NVARCHAR( 1),
   @cMinCnt2Ind       NVARCHAR( 1),
   @cMinCnt3Ind       NVARCHAR( 1),
   @cParentSKU        NVARCHAR( 20),
   @cComponentSKU     NVARCHAR( 20),
   @nCountLot         INT,
   @cListName         NVARCHAR( 20),
   @cShort            NVARCHAR( 10),
   @cStoredProd       NVARCHAR( 250),
   @cAddNew_BOM       NVARCHAR( 20), 
   @nParentSKUEntered INT, 
   @cSKUStorerKey     NVARCHAR(15), 
   @nSKUCount         INT 

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

         @cHasLottable        NVARCHAR( 1),
         @cZone1              NVARCHAR( 10),
         @cZone2              NVARCHAR( 10),
         @cZone3              NVARCHAR( 10),
         @cZone4              NVARCHAR( 10),
         @cZone5              NVARCHAR( 10),
         @cAisle              NVARCHAR( 10),
         @cLevel              NVARCHAR( 10),
         @cOption             NVARCHAR( 1),
         @dtNewLottable04     DATETIME,
         @dtNewLottable05     DATETIME,
         @nSetFocusField      INT,
         @cLockedByDiffUser   NVARCHAR( 1),
         @cFoundLockRec       NVARCHAR( 1),
         @cLockCCDetailKey    NVARCHAR( 10),

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

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
   -- (Vicky02) - End

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorerKey        = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cLOC              = V_LOC,
   @cID               = V_ID,
   @cLOT              = V_LOT,
   @cSKU              = V_SKU,
   @cSKUDescr         = V_SKUDescr,
   @cUOM              = V_UOM,
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @dLottable05       = V_Lottable05,

   @nQTY              = V_QTY,
      
   @cCCRefNo          = V_String1,
   @cCCSheetNo        = V_String2,
   @cSuggestLOC       = V_String4,
   @cSuggestLogiLOC   = V_String5,
   @cParentSKU        = V_String6,
   @cComponentSKU     = V_String7,
   @cSheetNoFlag      = V_String8, 
   @cCCDetailKey      = V_String9,
   @cZone1            = V_String10,
   @cZone2            = V_String11,
   @cZone3            = V_String12,
   @cZone4            = V_String13,
   @cZone5            = V_String14,
   @cAisle            = V_String15,
   @cLevel            = V_String16,
   @nPackValue        = V_String17,
   @cBOM              = V_String18,
   @cSKUStorerKey     = V_String20, 

   @nCCCountNo        = V_Integer1,
   @nParentSKUEntered = V_Integer2,
      
   @cNewLottable01    = V_String34,
   @cNewLottable02    = V_String35,
   @cNewLottable03    = V_String36,
   @dNewLottable04    = CASE WHEN rdt.rdtIsValidDate (V_String37) = 1 THEN V_String37 ELSE NULL END,
   @dNewLottable05    = CASE WHEN rdt.rdtIsValidDate (V_String38) = 1 THEN V_String38 ELSE NULL END,
   @cID_In            = V_String40,     

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

   -- (Vicky02) - Start
   @cFieldAttr01 = FieldAttr01,     @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CCRef                    INT,  @nScn_CCRef                    INT,
   @nStep_SheetNo_Criteria         INT,  @nScn_SheetNo_Criteria         INT, 
   @nStep_CountNo                  INT,  @nScn_CountNo                  INT,
   @nStep_LOC                      INT,  @nScn_LOC                      INT,
   @nStep_ID                       INT,  @nScn_ID                       INT,
   @nStep_BOM                      INT,  @nScn_BOM                      INT,
   @nStep_BOM_Count_Qty            INT,  @nScn_BOM_Count_Qty            INT,
   @nStep_BOM_Add_NEWBOM           INT,  @nScn_BOM_Add_NEWBOM           INT,
   @nStep_BOM_Add_Lottables        INT,  @nScn_BOM_Add_Lottables        INT,
   @nStep_BOM_ADD_Qty              INT,  @nScn_BOM_Add_Qty              INT,
   @nStep_BOM_LOOKUP               INT,  @nScn_BOM_LOOKUP               INT 

SELECT
   @nStep_CCRef                    = 1,  @nScn_CCRef                    = 730,
   @nStep_SheetNo_Criteria         = 2,  @nScn_SheetNo_Criteria         = 731, 
   @nStep_CountNo                  = 3,  @nScn_CountNo                  = 732,
   @nStep_LOC                      = 4,  @nScn_LOC                      = 733,
   @nStep_ID                       = 5,  @nScn_ID                       = 734, 
   @nStep_BOM                      = 6,  @nScn_BOM                      = 735, 
   @nStep_BOM_Count_Qty            = 7,  @nScn_BOM_Count_Qty            = 736, 
   @nStep_BOM_Add_NEWBOM           = 8,  @nScn_BOM_Add_NEWBOM           = 737,
   @nStep_BOM_ADD_Qty              = 9,  @nScn_BOM_Add_Qty              = 738,
   @nStep_BOM_Add_Lottables        = 10, @nScn_BOM_Add_Lottables        = 739,
   @nStep_BOM_LOOKUP               = 11, @nScn_BOM_LOOKUP               = 740

IF @nFunc = 730 -- RDT BOM Cycle Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start                    -- Menu. Func = 730
   IF @nStep = 1  GOTO Step_CCRef                    -- Scn = 730. CCREF
   IF @nStep = 2  GOTO Step_SheetNo_Criteria         -- Scn = 731. SHEET NO OR Selection Criteria
   IF @nStep = 3  GOTO Step_CountNo                  -- Scn = 732. COUNT NO
   IF @nStep = 4  GOTO Step_LOC                      -- Scn = 733. LOC
   IF @nStep = 5  GOTO Step_ID                       -- Scn = 734. ID
   IF @nStep = 6  GOTO Step_BOM                      -- Scn = 735. BOM
   IF @nStep = 7  GOTO Step_BOM_Count_Qty            -- Scn = 736. BOM - Count Qty
   IF @nStep = 8  GOTO Step_BOM_Add_NEWBOM           -- Scn = 737. BOM - Add New BOM
   IF @nStep = 9  GOTO Step_BOM_ADD_Qty              -- Scn = 738. BOM - Add Qty
   IF @nStep = 10 GOTO Step_BOM_Add_Lottables        -- Scn = 739. BOM - Add Lottable
   IF @nStep = 11 GOTO Step_BOM_LOOKUP               -- Scn = 740. BOM Lookup
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 610. Screen 0.
********************************************************************************/
Step_Start:
BEGIN
   -- Clear the incomplete task for the same login
   DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
   WHERE Mobile = @nMobile
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

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
 
      -- (Vicky03) - Start
      SET @cCCRefNo = ''
      SET @cCCSheetNo = ''
      SET @nCCCountNo = 0
      SET @cSuggestLOC = ''
      SET @cSuggestLogiLOC = ''
      SET @cSheetNoFlag = ''
      -- (Vicky03) - End

      SET @nScn = @nScn_CCRef   -- 730
      SET @nStep = @nStep_CCRef -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 660. Screen 1.
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
         SET @nErrNo = 68441
         SET @cErrMsg = rdt.rdtgetmessage( 68441, @cLangCode, 'DSP') -- 'CCREF required'
         GOTO CCRef_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS (SELECT TOP 1 CCKey
                     FROM dbo.CCDETAIL (NOLOCK)
                     WHERE CCKey = @cCCRefNo)
      BEGIN
         SET @nErrNo = 68442
         SET @cErrMsg = rdt.rdtgetmessage( 68442, @cLangCode, 'DSP') -- 'Invalid CCREF'
         GOTO CCRef_Fail
      END

      -- Validate with StockTakeSheetParameters
      IF NOT EXISTS (SELECT TOP 1 StockTakeKey
                     FROM dbo.StockTakeSheetParameters (NOLOCK)
                     WHERE StockTakeKey = @cCCRefNo
                     AND   Facility = @cFacility)
      BEGIN
         SET @nErrNo = 68443
         SET @cErrMsg = rdt.rdtgetmessage( 68443, @cLangCode, 'DSP') -- 'Setup CCREF'
         GOTO CCRef_Fail
      END

      EXEC rdt.rdtSetFocusField @nMobile, 2

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

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
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
Step_SheetNo_Criteria. Scn = 661. Screen 2.
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

      -- (MaryVong01)
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
         SET @nErrNo = 68444
         SET @cErrMsg = rdt.rdtgetmessage( 68444, @cLangCode, 'DSP') -- 'SHEET required'
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
         SET @nErrNo = 68445
         SET @cErrMsg = rdt.rdtgetmessage( 68445, @cLangCode, 'DSP') -- 'Sheet/Criteria'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SheetNo_Criteria_Fail
      END

      -- Among 5 Zones, ONLY Zone1 allowed 'ALL'
      IF ( (@cZone2 = 'ALL' AND @cZone2 <> '' AND @cZone2 IS NOT NULL) OR
           (@cZone3 = 'ALL' AND @cZone3 <> '' AND @cZone3 IS NOT NULL) OR
           (@cZone4 = 'ALL' AND @cZone4 <> '' AND @cZone4 IS NOT NULL) OR
           (@cZone5 = 'ALL' AND @cZone5 <> '' AND @cZone5 IS NOT NULL) )
      BEGIN
         SET @nErrNo = 68446
         SET @cErrMsg = rdt.rdtgetmessage( 62138, @cLangCode, 'DSP') -- 'Wrong Zone'
         IF @cZone2 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 4
         IF @cZone3 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 5
         IF @cZone4 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 6
         IF @cZone5 = 'ALL'   EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO SheetNo_Criteria_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefno  -- CCKey
      SET @cOutField02 = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN '' ELSE @cCCSheetNo END  -- CC SHEET No
      SET @cOutField03 = ''  -- CNT NO

      -- Go to next screen
      SET @nScn = @nScn_CountNo
      SET @nStep = @nStep_CountNo
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Release locked record
      -- (Vicky03) - Start - To Store those SystemQty <> CountedQty
      UPDATE RDT.RDTCCLock WITH (ROWLOCK)
         SET Status = '9' 
      WHERE Mobile = @nMobile 
      AND AddWho = @cUserName
      AND Status =  '1'
      -- (Vicky03) - End

      DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
      WHERE Mobile = @nMobile 
      AND AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62140
         SET @cErrMsg = rdt.rdtgetmessage( 62140, @cLangCode, 'DSP') --'ReleaseMobFail'
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
Step_CountNo. Scn = 662. Screen 3.
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
         SET @nErrNo = 62086
         SET @cErrMsg = rdt.rdtgetmessage( 62086, @cLangCode, 'DSP') -- 'CNT NO required'
         GOTO CountNo_Fail
      END

      IF @cCCCountNo <> '1' AND @cCCCountNo <> '2' AND @cCCCountNo <> '3'
      BEGIN
         SET @nErrNo = 62087
         SET @cErrMsg = rdt.rdtgetmessage( 62087, @cLangCode, 'DSP') -- 'Invalid CNT NO'
         GOTO CountNo_Fail
      END

      SET @nCCCountNo = CAST( @cCCCountNo AS INT)

      DECLARE @nFinalizeStage INT

      -- Get finalized stage
      -- If FinalizeStage = 1 means 1st cnt already finalized.
      SELECT TOP 1
         @nFinalizeStage = FinalizeStage 
      FROM dbo.StockTakeSheetParameters (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo
      AND   Facility = @cFacility

      -- Already counted 3 times, not allow to count again
      IF @nFinalizeStage = 3
      BEGIN
         SET @nErrNo = 62088
         SET @cErrMsg = rdt.rdtgetmessage( 62088, @cLangCode, 'DSP') -- 'Finalized Cnt3'
         GOTO CountNo_Fail
      END

      -- Entered CountNo must equal to FinalizeStage + 1, ie. if cnt1 not finalized, cannot go to cnt2
      IF @nCCCountNo <> @nFinalizeStage + 1
      BEGIN
         SET @nErrNo = 62089
         SET @cErrMsg = rdt.rdtgetmessage( 62089, @cLangCode, 'DSP') -- 'Wrong CNT NO'
         GOTO CountNo_Fail
      END

      IF @cCCSheetNo <> '' AND @cCCSheetNo IS NOT NULL
      BEGIN
         -- (MaryVong01)
         SET @cSheetNoFlag = 'Y'

         -- Validate with CCDETAIL
         IF NOT EXISTS (SELECT TOP 1 CCDETAIL.CCKey
                        FROM dbo.CCDETAIL CCDETAIL (NOLOCK)
                        JOIN dbo.StockTakeSheetParameters STK (NOLOCK)
                           ON STK.StockTakeKey = CCDETAIL.CCKEY
                        WHERE CCDETAIL.CCKey = @cCCRefNo
                        AND   CCDETAIL.CCSheetNo = @cCCSheetNo)
         BEGIN
            SET @nErrNo = 68447
            SET @cErrMsg = rdt.rdtgetmessage( 68447, @cLangCode, 'DSP') -- 'Invalid SHEET'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO SheetNo_Criteria_Fail
         END

         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
         AND AddWho = @cUserName
        
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
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable01
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable01_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable01_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable02
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable02_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable02_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable03
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable03_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable03_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable04
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable04_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable04_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable05
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable05_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable05_Cnt3 END,             
            CCD.SystemQty,  
            CASE WHEN @nCCCountNo = 1 THEN CCD.Qty
                 WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3 END,              
            '0',             '',             @cUserName,     GETDATE()
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)
         WHERE CCD.CCKey = @cCCRefNo
         AND CCD.CCSheetNo = @cCCSheetNo
         -- Only select uncounted record
         AND 1 =  CASE 
                  WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                  WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                  ELSE 1 
            END

         IF @@ROWCOUNT = 0 -- No data in CCDetail
         BEGIN
            SET @nErrNo = 68448
            SET @cErrMsg = rdt.rdtgetmessage( 68448, @cLangCode, 'DSP') -- 'Blank Record'
            GOTO QUIT
         END
      END
 ELSE -- Key-in Zones/Aisle/Level
      BEGIN
         -- Release locked record
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)
         WHERE Mobile = @nMobile 
         AND AddWho = @cUserName
         -- AND Status = '0'     -- (Vicky03)      

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
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable01
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable01_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable01_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable02
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable02_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable02_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable03
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable03_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable03_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable04
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable04_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable04_Cnt3 END, 
            CASE WHEN @nCCCountNo = 1 THEN CCD.Lottable05
                 WHEN @nCCCountNo = 2 THEN CCD.Lottable05_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Lottable05_Cnt3 END, 
            CCD.SystemQty,  
            CASE WHEN @nCCCountNo = 1 THEN CCD.Qty
                 WHEN @nCCCountNo = 2 THEN CCD.Qty_Cnt2
                 WHEN @nCCCountNo = 3 THEN CCD.Qty_Cnt3 END, 
            '0',             '',              @cUserName,     GETDATE()
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)
         WHERE CCD.CCKey = @cCCRefNo
         AND LOC.Facility = @cFacility
         AND ( (LOC.PutawayZone = CASE WHEN @cZone1 = 'ALL' THEN LOC.PutawayZone END) OR
               (LOC.PutawayZone IN (@cZone1, @cZone2, @cZone3, @cZone4, @cZone5)) )
         AND LOC.LocAisle = CASE WHEN ISNULL(@cAisle,'') = '' OR RTRIM(@cAisle) = 'ALL' THEN LOC.LocAisle ELSE @cAisle END
         AND LOC.LocLevel = CASE WHEN ISNULL(@cLevel,'') = '' OR RTRIM(@cLevel) = 'ALL' THEN LOC.LocLevel ELSE @cLevel END
         -- Only select uncounted record
         AND 1 =  CASE 
                  WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                  WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                  WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                  ELSE 1 
            END
         
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 68449
            SET @cErrMsg = rdt.rdtgetmessage( 68449, @cLangCode, 'DSP') -- 'Blank record'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO SheetNo_Criteria_Fail
         END
      END

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
      AND AddWho = @cUserName
      -- AND Status = '0'  (Vicky03)

      -- Get first suggested loc (sort by CCLogicalLOC)
   SET @cSuggestLOC = ''
      SET @cSuggestLogiLOC = ''

      EXECUTE rdt.rdt_CycleCount_BOM_GetNextLOC
         @cCCRefNo,
         @cCCSheetNo,
         @cSheetNoFlag,
         @nCCCountNo,
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
         @cSuggestLOC OUTPUT

      IF ISNULL(@cSuggestLOC, '') = ''
      BEGIN
         SET @nErrNo = 68455
         SET @cErrMsg = rdt.rdtgetmessage( 68455, @cLangCode, 'DSP') -- 'LOC Not Found'
         GOTO CountNo_Fail
      END

      -- Update RDTCCLock data with CountNo
      UPDATE RDT.RDTCCLock WITH (ROWLOCK)
      SET   CountNo = @nCCCountNo
      WHERE Mobile = @nMobile
      AND CCKey = @cCCRefNo
      AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
      AND AddWho = @cUserName
      AND Status = '0'
      AND (CountNo = 0 OR ISNULL(CountNo, '') = '')

      -- Prepare next screen var
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField06 = ''

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
      AND AddWho = @cUserName
      -- Get from latest record, not necessary status = '1'
      ORDER BY EditDate DESC

      -- Reset variables
      SET @nCCCountNo = 0
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
Step_LOC. Scn = 663. Screen 4.
   CCREF         (field01)
   SHEET         (field02)
   CNT NO        (field03)
   LOC           (field04)   - Suggested LOC
   LOC           (field05)   - Input field
************************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSuggestLOC = @cOutField04
      SET @cLOC = @cInField05

      -- Retain the key-in value
      SET @cOutField05 = @cLOC

      -- If LOC is Blank 
      IF ISNULL(@cLOC, '') = '' 
      BEGIN
         SET @nErrNo = 68456
         SET @cErrMsg = rdt.rdtgetmessage( 68456, @cLangCode, 'DSP') -- 'LOC REQ'
         GOTO LOC_Fail
      END

      -- If LOC not same with Suggested LOC
      IF @cLOC <> @cSuggestLOC OR @cLOC = 'LAST LOC'
      BEGIN
         SET @nErrNo = 68457
         SET @cErrMsg = rdt.rdtgetmessage( 68457, @cLangCode, 'DSP') -- 'LOC REQ'
         GOTO LOC_Fail
      END

--      -- Get next suggested LOC         
--      EXECUTE rdt.rdt_CycleCount_GetNextLOC
--         @cCCRefNo,
--         @cCCSheetNo,
--         @cSheetNoFlag,
--         @cZone1,
--         @cZone2,
--         @cZone3,
--         @cZone4,
--    @cZone5,
--         @cAisle,
--         @cLevel,
--         @cFacility,
--         @cSuggestLogiLOC, -- current CCLogicalLOC
--         @cSuggestLogiLOC OUTPUT,
--         @cSuggestLOC OUTPUT
--
--      IF @cSuggestLOC = '' OR @cSuggestLOC IS NULL
--      BEGIN
--         SET @nErrNo = 68458
--         SET @cErrMsg = rdt.rdtgetmessage( 68458, @cLangCode, 'DSP') -- 'Last LOC'
--         GOTO LOC_Fail
--      END

      -- Prepare next screen var
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = ''
      SET @cOutField07 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 7   -- ID

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

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
Step_ID. Scn = 667. Screen 5.
   CCREF  (field01)
   SHEET  (field02)
   COUNT  (field03)
   LOC    (field04)   - Suggested LOC
   LOC    (field05)
   OPTION (field06)   - Input field
   ID     (field07)   - Input field
************************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField06
      SET @cID_In = @cInField07

      -- Retain the key-in value
      SET @cOutField06 = @cOption
      SET @cOutField07 = @cID_In

      -- If Opt keyed in, value must be 1
      IF ISNULL(@cOption, '') <> '' AND @cOption <> '1' 
      BEGIN
         SET @nErrNo = 68459
         SET @cErrMsg = rdt.rdtgetmessage( 68459, @cLangCode, 'DSP') -- 'Invalid Opt'
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
         GOTO ID_Fail
      END

      -- If OPT = 1, that is mean the LOC is an empty location. 
      -- At this point, update the RDTCCLock Status as counted, with QTY remain as 0
      -- Direct the screen back to LOC screen (Screen 4) and suggest the next LOC
      IF @cOption = '1'
      BEGIN
         BEGIN TRAN

         UPDATE RDT.RDTCCLOCK WITH (ROWLOCK) SET 
            Status = '9', 
            CountedQty = 0,
            EditWho = @cUserName, 
            EditDate = GETDATE()
         WHERE Mobile = @nMobile
            AND CCKey = @cCCRefNo
            AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND AddWho = @cUserName
            AND LOC = @cLOC

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 68460
            SET @cErrMsg = rdt.rdtgetmessage( 68460, @cLangCode, 'DSP') -- 'UPDEmpLoc Fail'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         -- Check if it is generated empty LOC
-- james01
--         IF EXISTS (SELECT 1 FROM dbo.CCDETAIL WITH (NOLOCK) 
--            WHERE CCKey = @cCCRefNo
--               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--               AND LOC = @cLOC
--               AND (SKU = '' OR (SYSTEMQTY = 0 AND QTY = 0 AND QTY_CNT2 = 0 AND QTY_CNT3 = 0))  -- lau, find sku <>'', status 4 and qty='0'
--               AND Status = '4')
--            UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
--               Qty = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE Qty END, 
--               Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE Qty_Cnt2 END, 
--               Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE Qty_Cnt3 END, 
--               EditWho_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE EditWho_Cnt1 END, 
--               EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END, 
--               EditWho_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE EditWho_Cnt2 END, 
--               EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END, 
--               EditWho_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE EditWho_Cnt3 END, 
--               EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END,
--               Counted_Cnt1 =  CASE WHEN @nCCCountNo = 1 THEN 1 ELSE Counted_Cnt1 END,
--               Counted_Cnt2 =  CASE WHEN @nCCCountNo = 2 THEN 1 ELSE Counted_Cnt2 END,
--               Counted_Cnt3 =  CASE WHEN @nCCCountNo = 3 THEN 1 ELSE Counted_Cnt3 END 
--            WHERE CCKey = @cCCRefNo
--               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
--               AND LOC = @cLOC
----               AND SKU = ''     -- lau (update those sku <>'' and system qty=0 as well)
--               AND (SKU = '' OR (SYSTEMQTY = 0 AND QTY = 0 AND QTY_CNT2 = 0 AND QTY_CNT3 = 0))  -- lau (update those sku <>'' and system qty=0 as well)
--               AND Status = '4'
--         ELSE
            UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
               Status = CASE WHEN Status = '0' THEN '2' ELSE Status END,
               Qty = CASE WHEN @nCCCountNo = 1 THEN 0 ELSE Qty END, 
               Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 0 ELSE Qty_Cnt2 END, 
               Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 0 ELSE Qty_Cnt3 END, 
               EditWho_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE EditWho_Cnt1 END, 
               EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END, 
               EditWho_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE EditWho_Cnt2 END, 
               EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END, 
               EditWho_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE EditWho_Cnt3 END, 
               EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END,
               Counted_Cnt1 =  CASE WHEN @nCCCountNo = 1 THEN 1 ELSE Counted_Cnt1 END,
               Counted_Cnt2 =  CASE WHEN @nCCCountNo = 2 THEN 1 ELSE Counted_Cnt2 END,
               Counted_Cnt3 =  CASE WHEN @nCCCountNo = 3 THEN 1 ELSE Counted_Cnt3 END 
            WHERE CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND LOC = @cLOC
--               AND Status = '0'
               AND 1 =  CASE 
                        WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 1 THEN 0
                        WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 1 THEN 0
                        WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 1 THEN 0
                        ELSE 1 
                  END

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 68460
            SET @cErrMsg = rdt.rdtgetmessage( 68460, @cLangCode, 'DSP') -- 'UPDEmpLoc Fail'
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- OPT
            GOTO ID_Fail
         END

         COMMIT TRAN

         -- Get next suggested LOC         
         EXECUTE rdt.rdt_CycleCount_BOM_GetNextLOC
            @cCCRefNo,
            @cCCSheetNo,
            @cSheetNoFlag,
            @nCCCountNo,
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
            @cSuggestLOC OUTPUT
   
         SET @cOutField01 = @cCCRefNo
         SET @cOutField02 = @cCCSheetNo
         SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1)) 
         SET @cOutField04 = CASE WHEN ISNULL(@cSuggestLOC, '') = '' THEN 'LAST LOC' ELSE @cSuggestLOC END -- Suggested LOC
         SET @cOutField05 = '' -- LOC

         -- Go to next screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC

         GOTO Quit
      END   -- IF @cOption = '1'

      SET @cID = @cID_In
            
      -- Prepare BOM screen var
      SET @cOutField01 = @cLOC
 SET @cOutField02 = @cID
      SET @cOutField03 = ''

      -- Go to BOM (Main) screen
      SET @nScn  = @nScn_BOM
      SET @nStep = @nStep_BOM
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR( 1)) 
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = '' -- LOC

      -- Go to previous screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   ID_Fail:
   BEGIN
      SET @cOutField07= '' -- ID
   END
END
GOTO Quit

/************************************************************************************
Step_BOM. Scn = 735. Screen 6.
   LOC        (field01) 
   ID         (field02) 
   ENTER BOM  (field03, input) 
************************************************************************************/
Step_BOM:
BEGIN
   SET @nParentSKUEntered = 1 

   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBOM = @cInField03

      -- Retain the key-in value
      SET @cOutField01 = @cBOM

      IF ISNULL(@cBOM, '') = ''
      BEGIN
         SET @nErrNo = 68461
         SET @cErrMsg = rdt.rdtgetmessage( 68461, @cLangCode, 'DSP') -- 'BOM REQ'
         GOTO BOM_Fail
      END

      -- Check if BOM exists in UPC table
      IF NOT EXISTS (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = @cBOM)
      BEGIN
         SET @nParentSKUEntered = 0

         IF @cStorerKey <> 'ALL'
            SET @cSKUStorerKey = @cStorerKey
         
         SELECT @nSKUCount = COUNT(*) 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE SKU = @cBOM
         
         IF @nSKUCount = 0 
         BEGIN
            SET @nErrNo = 68462
            SET @cErrMsg = rdt.rdtgetmessage( 68462, @cLangCode, 'DSP') -- 'Invalid BOM/SKU'
            GOTO BOM_Fail            
         END         
         ELSE IF @nSKUCount > 1
         BEGIN
            SET @nErrNo = 68462
            SET @cErrMsg = rdt.rdtgetmessage( 68462, @cLangCode, 'DSP') -- 'Multi Strorer'
            GOTO BOM_Fail            
         END         
         SELECT @cSKUStorerKey = STORERKEY 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE SKU = @cBOM
         
      END
      ELSE
      BEGIN
         SET @nParentSKUEntered = 1
      END 


      IF @nParentSKUEntered = 1
      BEGIN
         -- Check if UPC.SKU exists in BOM table
         IF NOT EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
            JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (UPC.StorerKey = BOM.StorerKey AND UPC.SKU = BOM.SKU)
            WHERE UPC = @cBOM)
         BEGIN
            SET @nErrNo = 68463
            SET @cErrMsg = rdt.rdtgetmessage( 68463, @cLangCode, 'DSP') -- 'No BOM Setup'
            GOTO BOM_Fail
         END         
         -- Check if UPC.PackKey exists in Pack table
         IF NOT EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON (UPC.PackKey = PACK.PackKey)
            WHERE UPC = @cBOM)
         BEGIN
            SET @nErrNo = 68464
            SET @cErrMsg = rdt.rdtgetmessage( 68464, @cLangCode, 'DSP') -- 'Invalid Pack'
            GOTO BOM_Fail
         END         
      END
      ELSE
      BEGIN

            
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
            WHERE SKU.StorerKey = @cSKUStorerKey AND SKU.SKU = @cBOM)
         BEGIN
            SET @nErrNo = 68464
            SET @cErrMsg = rdt.rdtgetmessage( 68464, @cLangCode, 'DSP') -- 'Invalid Pack'
            GOTO BOM_Fail
         END         
      END


      IF @nParentSKUEntered = 1
      BEGIN
         
         -- Note: Lottable03 field stored ParentSKU for the Component SKU. UPC.SKU is the ParentSKU code. 
         -- This validation is to check whether ParentSKU exists in the range of populated CCDetail
         IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
            JOIN RDT.RDTCCLOCK RCL WITH (NOLOCK) ON (UPC.StorerKey = RCL.StorerKey AND UPC.SKU = RCL.Lottable03)
            WHERE RCL.Mobile = @nMobile
            AND RCL.CCKey = @cCCRefNo
            AND RCL.SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND RCL.AddWho = @cUserName
            AND UPC.UPC = @cBOM
            AND RCL.Status = '0'
            AND LOC = @cLOC
            AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END)
         -- If there are records exists with Status = '0' (not counted before)
         -- Goto BOM - Count QTY (Screen 7) and allow to enter QTY
         BEGIN
            SELECT @cSKU = @cBOM

            SELECT TOP 1 
                  @cSKUStorerKey = UPC.StorerKey, 
                  @cParentSKU = UPC.SKU, 
                  @cPackKey = UPC.PackKey, 
                  @cUOM = UPC.UOM, 
                  @cSKUDescr = SKU.Descr 
            FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
            WHERE UPC.UPC = @cSKU

            SELECT @nPackValue = CASE 
               WHEN @cUOM = 'CS' THEN CaseCnt 
               WHEN @cUOM = 'IP' THEN InnerPack 
               WHEN @cUOM = 'SH' THEN OtherUnit1 
               WHEN @cUOM = 'PL' THEN Pallet 
            END 
            FROM dbo.Pack WITH (NOLOCK) 
            WHERE PackKey = @cPackKey

            IF @nPackValue = 0 
            BEGIN
               IF @cUOM = 'CS'
               BEGIN
                  SET @nErrNo = 68465
                  SET @cErrMsg = rdt.rdtgetmessage( 68465, @cLangCode, 'DSP') -- 'Invalid CaseCnt'
               END

               IF @cUOM = 'IP'
               BEGIN
                  SET @nErrNo = 68466
                  SET @cErrMsg = rdt.rdtgetmessage( 68466, @cLangCode, 'DSP') -- 'Invalid InnerPack'
               END

               IF @cUOM = 'SH'
               BEGIN
                  SET @nErrNo = 68467
                  SET @cErrMsg = rdt.rdtgetmessage( 68467, @cLangCode, 'DSP') -- 'Invalid Shipper'
               END

               IF @cUOM = 'PL'
               BEGIN
                  SET @nErrNo = 68468
                  SET @cErrMsg = rdt.rdtgetmessage( 68468, @cLangCode, 'DSP') -- 'Invalid Pallet'
               END

               GOTO BOM_Fail
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK) 
            WHERE StorerKey = @cSKUStorerKey
               AND CCKey = @cCCRefNo
               AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND Lottable03 = @cParentSKU
               AND LOC = @cLOC
               AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END)
            BEGIN
               SET @nErrNo = 68487
               SET @cErrMsg = rdt.rdtgetmessage( 68487, @cLangCode, 'DSP') -- 'BOM not in CCD'
               GOTO BOM_Fail
            END

            SELECT TOP 1  
               @cLottable01 = Lottable01, 
               @cLottable02 = Lottable02, 
               @cLottable03 = Lottable03, 
               @dLottable04 = Lottable04, 
               @dLottable05 = Lottable05 
            FROM RDT.RDTCCLOCK WITH (NOLOCK)
            WHERE Mobile = @nMobile
               AND CCKey = @cCCRefNo
               AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
               AND AddWho = @cUserName
               AND Lottable03 = @cParentSKU
               AND LOC = @cLOC
               AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND Status = 0
            GROUP BY Lottable01, Lottable02, Lottable03, Lottable04, Lottable05

            SET @cOutField01 = ''   -- OPT
            SET @cOutField02 = @cParentSKU
            SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
            SET @cOutField04 = ''   -- Qty
            SET @cOutField05 = @cUOM
            SET @cOutField06 = @cID
            SET @cOutField07 = @cLottable01
            SET @cOutField08 = @cLottable02
            SET @cOutField09 = @cLottable03
            SET @cOutField10 = rdt.rdtFormatDate( @dLottable04)
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable05)

            EXEC rdt.rdtSetFocusField @nMobile, 4

            -- Go to next screen
            SET @nScn = @nScn_BOM_Count_Qty
            SET @nStep = @nStep_BOM_Count_Qty

            GOTO Quit
         END
         -- If BOM scanned not exists in RDTCCLock, direct to ADD BOM (Screen 8)
         ELSE
         BEGIN
            -- Prepare Add new BOM screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID
            SET @cOutField03 = @cBOM   -- Retail scanned BOM value

            -- Go to Add new BOM screen
            SET @nScn  = @nScn_BOM_Add_NEWBOM
            SET @nStep = @nStep_BOM_Add_NEWBOM

            GOTO Quit
         END
      END -- @nParentSKUEntered = 1
      ELSE
      BEGIN
         
         -- Note: Lottable03 field stored ParentSKU for the Component SKU. UPC.SKU is the ParentSKU code. 
         -- This validation is to check whether ParentSKU exists in the range of populated CCDetail
         IF EXISTS (SELECT 1 FROM RDT.RDTCCLOCK RCL WITH (NOLOCK) 
            WHERE RCL.Mobile = @nMobile
            AND RCL.CCKey = @cCCRefNo
            AND RCL.SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
            AND RCL.AddWho = @cUserName 
            AND RCL.Storerkey = @cSKUStorerKey 
            AND RCL.SKU = @cBOM
            AND RCL.Lottable03 = ''
            AND RCL.Status = '0'
            AND LOC = @cLOC
            AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END) 
         BEGIN
            -- If there are records exists with Status = '0' (not counted before)
            -- Goto BOM - Count QTY (Screen 7) and allow to enter QTY
            
            SELECT @cSKU = @cBOM

            SELECT TOP 1 
                  @cSKUStorerKey = SKU.StorerKey, 
                  @cParentSKU = SKU.SKU, 
                  @cPackKey = SKU.PackKey, 
                  @cUOM = PACK.PACKUOM3, 
                  @cSKUDescr = SKU.Descr 
            FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON PACK.PACKKey = SKU.PACKKey  
            WHERE SKU.StorerKey = @cSKUStorerKey 
            AND   SKU.SKU = @cSKU

            SELECT TOP 1  
               @cLottable01 = Lottable01, 
               @cLottable02 = Lottable02, 
               @cLottable03 = Lottable03, 
               @dLottable04 = Lottable04, 
               @dLottable05 = Lottable05 
            FROM RDT.RDTCCLOCK WITH (NOLOCK)
            WHERE Mobile = @nMobile
               AND CCKey = @cCCRefNo
               AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
               AND AddWho = @cUserName
               AND StorerKey = @cSKUStorerKey
               AND SKU = @cSKU
               AND LOC = @cLOC
               AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END
               AND Status = 0
            GROUP BY Lottable01, Lottable02, Lottable03, Lottable04, Lottable05

            SET @cOutField01 = ''   -- OPT
            SET @cOutField02 = @cSKU
            SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
            SET @cOutField04 = ''   -- Qty
            SET @cOutField05 = @cUOM
            SET @cOutField06 = @cID
            SET @cOutField07 = @cLottable01
            SET @cOutField08 = @cLottable02
            SET @cOutField09 = @cLottable03
            SET @cOutField10 = rdt.rdtFormatDate( @dLottable04)
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable05)

            EXEC rdt.rdtSetFocusField @nMobile, 4

            -- Go to next screen
            SET @nScn = @nScn_BOM_Count_Qty
            SET @nStep = @nStep_BOM_Count_Qty

            GOTO Quit
         END
         -- If BOM scanned not exists in RDTCCLock, direct to ADD BOM (Screen 8)
         ELSE
         BEGIN
            -- Prepare Add new BOM screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = @cID
            SET @cOutField03 = @cBOM   -- Retail scanned BOM value

        -- Go to Add new BOM screen
            SET @nScn  = @nScn_BOM_Add_NEWBOM
            SET @nStep = @nStep_BOM_Add_NEWBOM

            GOTO Quit
         END         
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      DELETE FROM RDT.RDTCCLock
      WHERE CCKey = @cCCRefNo
      AND   SheetNo = CASE WHEN @cSheetNoFlag = 'Y' THEN SheetNo ELSE @cCCSheetNo END
      AND   CountNo = @nCCCountNo
      AND   AddWho = @cUserName
      AND   Status = '1'
      AND   Loc = @cLOC
      AND   Id = @cID
      
      -- Set back previous values
      SET @cOutField01 = @cCCRefNo
      SET @cOutField02 = @cCCSheetNo
      SET @cOutField03 = CAST( @nCCCountNo AS NVARCHAR(1))
      SET @cOutField04 = @cSuggestLOC
      SET @cOutField05 = @cLOC
      SET @cOutField06 = ''
      SET @cOutField07 = '' -- ID

      EXEC rdt.rdtSetFocusField @nMobile, 7 -- ID

      -- Go to previous screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   BOM_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- BOM
   END
END
GOTO Quit

/************************************************************************************
Step_BOM_Count_Qty. Scn = 736. Screen 7.
   OPT         (field01, input)
   BOM         (field02)
   Descr       (field03) 
   Qty         (field04, input) UOM    (field05)
   ID          (field06) 
   Lottable 1/2/3/4/5   (field07, field08, field09, field10, field11) 
   1 = BOM Lookup
************************************************************************************/
Step_BOM_Count_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01
      SET @cQty = @cInField04

      -- Retain the key-in value
      SET @cOutField01 = @cOption
      SET @cOutField04 = @cQty

      -- Must key in either Qty/Opt
      IF ISNULL(@cOption, '') = '' AND ISNULL(@cQty, '') = ''
      BEGIN
         SET @nErrNo = 68469
         SET @cErrMsg = rdt.rdtgetmessage( 68469, @cLangCode, 'DSP') -- 'QTY/OPT REQ'
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      -- If key in Opt
      IF ISNULL(@cOption, '') <> ''
      BEGIN
         IF @cOption NOT IN ('1')
         BEGIN
            SET @nErrNo = 68470
            SET @cErrMsg = rdt.rdtgetmessage( 68470, @cLangCode, 'DSP') -- 'Invalid Option'
            SET @cOutField01 = ''
            SET @cOutField04 = @cQty
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         ELSE
         BEGIN
            --Reinitialise            
            SELECT @cSize1 = '' SELECT @nQty1 = 0       
            SELECT @cSize2 = '' SELECT @nQty2 = 0
            SELECT @cSize3 = '' SELECT @nQty3 = 0       
            SELECT @cSize4 = '' SELECT @nQty4 = 0
            SELECT @cSize5 = '' SELECT @nQty5 = 0       
            SELECT @cSize6 = '' SELECT @nQty6 = 0               
            
            IF @nParentSKUEntered = 1
            BEGIN
               SELECT TOP 1 @cColor = SKU.COLOR 
               FROM dbo.SKU SKU WITH (NOLOCK) 
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
               WHERE BOM.SKU = @cParentSKU
                 AND SKU.StorerKey = @cSKUStorerKey
               ORDER BY SKU.COLOR               
            END
            ELSE
            BEGIN               
               SELECT TOP 1 
                  @cColor = SKU.COLOR, 
                  @cSize1 = SKU.[Size],
                  @nQty1  = 1 
               FROM dbo.SKU SKU WITH (NOLOCK) 
               WHERE SKU.SKU = @cSKU
                 AND SKU.StorerKey = @cSKUStorerKey              
            END

            IF @nParentSKUEntered = 1
            BEGIN
               SET @nDummyCount = 1

               DECLARE CUR_BOM_LK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT SKU.Size, BOM.Qty FROM dbo.SKU SKU WITH (NOLOCK) 
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
               WHERE BOM.SKU = @cParentSKU
                  AND SKU.StorerKey = @cSKUStorerKey
                  AND SKU.Color = @cColor

               OPEN CUR_BOM_LK
               FETCH NEXT FROM CUR_BOM_LK INTO @cBOM_Size, @nBOM_Qty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @nDummyCount = 1
                  BEGIN
                     SET @cSize1 = @cBOM_Size
                     SET @nQty1 = @nBOM_Qty
                  END
                  IF @nDummyCount = 2
                  BEGIN
                     SET @cSize2 = @cBOM_Size
                     SET @nQty2 = @nBOM_Qty
                  END
                  IF @nDummyCount = 3
                  BEGIN
                     SET @cSize3 = @cBOM_Size
                     SET @nQty3 = @nBOM_Qty
                  END
                  IF @nDummyCount = 4
                  BEGIN
                     SET @cSize4 = @cBOM_Size
                     SET @nQty4 = @nBOM_Qty
                  END
                  IF @nDummyCount = 5
                  BEGIN
                     SET @cSize5 = @cBOM_Size
                     SET @nQty5 = @nBOM_Qty
                  END
                  IF @nDummyCount = 6
                  BEGIN
                     SET @cSize6 = @cBOM_Size
                     SET @nQty6 = @nBOM_Qty
                  END

                  SET @nDummyCount = @nDummyCount + 1

                  FETCH NEXT FROM CUR_BOM_LK INTO @cBOM_Size, @nBOM_Qty
               END
               CLOSE CUR_BOM_LK
               DEALLOCATE CUR_BOM_LK               
            END


            SET @cOutField01 = @cSKU
            SET @cOutField02 = @cUOM
            SET @cOutField03 = @cColor
            SET @cOutField04 = CASE WHEN ISNULL(@cSize1, '') <> '' THEN @cSize1 + ' = ' + CAST(@nQty1 AS NVARCHAR( 5)) ELSE '' END
            SET @cOutField05 = CASE WHEN ISNULL(@cSize2, '') <> '' THEN @cSize2 + ' = ' + CAST(@nQty2 AS NVARCHAR( 5)) ELSE '' END
            SET @cOutField06 = CASE WHEN ISNULL(@cSize3, '') <> '' THEN @cSize3 + ' = ' + CAST(@nQty3 AS NVARCHAR( 5)) ELSE '' END
            SET @cOutField07 = CASE WHEN ISNULL(@cSize4, '') <> '' THEN @cSize4 + ' = ' + CAST(@nQty4 AS NVARCHAR( 5)) ELSE '' END
            SET @cOutField08 = CASE WHEN ISNULL(@cSize5, '') <> '' THEN @cSize5 + ' = ' + CAST(@nQty5 AS NVARCHAR( 5)) ELSE '' END
            SET @cOutField09 = CASE WHEN ISNULL(@cSize6, '') <> '' THEN @cSize6 + ' = ' + CAST(@nQty6 AS NVARCHAR( 5)) ELSE '' END

            -- Go to BOM Lookup screen
            SET @nScn  = @nScn_BOM_LOOKUP
            SET @nStep = @nStep_BOM_LOOKUP

            GOTO Quit
         END
      END

      -- Validate blank Qty
      IF ISNULL(@cQty, '') = ''
      BEGIN
         SET @nErrNo = 68471
         SET @cErrMsg = rdt.rdtgetmessage( 68471, @cLangCode, 'DSP') -- 'QTY REQ'
         SET @cOutField01 = @cOption
         SET @cOutField04 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      IF rdt.rdtIsValidQTY( @cQty, 0) = 0 -- 0=not check for 0 QTY, 1=check for 0 QTY
      BEGIN
         SET @nErrNo = 68472
         SET @cErrMsg = rdt.rdtgetmessage( 68472, @cLangCode, 'DSP') -- 'Invalid Qty'
         SET @cOutField01 = @cOption
         SET @cOutField04 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      SET @nQty = CAST(@cQty AS INT)

      SET @nErrNo = 0
      SET @cErrMsg = ''
      
      IF @nParentSKUEntered = 1
      BEGIN
         -- Confirm Task for BOM scanned
         EXECUTE rdt.rdt_CycleCount_BOM_Confirm
            @nMobile,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cSKUStorerKey,
            @cSKU,
            @cLOC,
            @cID,       
            @nQty, 
            @nPackValue,
            @cUserName,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @dLottable05,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  -- screen limitation, 20 char max         
      END
      ELSE
      BEGIN
         -- Confirm Task for BOM scanned
         EXECUTE rdt.rdt_CycleCount_SKU_Confirm
            @nMobile,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cSKUStorerKey,
            @cSKU,
            @cLOC,
            @cID,       
            @nQty, 
            @nPackValue,
            @cUserName,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @dLottable05,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  -- screen limitation, 20 char max                  
      END

      IF @nErrNo <> 0
      GOTO Quit

      -- Prepare BOM screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

      -- Go to BOM (Main) screen
      SET @nScn  = @nScn_BOM
      SET @nStep = @nStep_BOM
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare BOM screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

      -- Go to BOM (Main) screen
      SET @nScn  = @nScn_BOM
     SET @nStep = @nStep_BOM
   END
   GOTO Quit
END
GOTO Quit

/************************************************************************************
Step_BOM_Add_NEWBOM. Scn = 737. Screen 8.
   LOC         (field01)
   ID          (field02)
   BOM/SKU     (field03, input)
************************************************************************************/
Step_BOM_Add_NEWBOM:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cAddNew_BOM = @cInField03

      -- Retain the key-in value
      SET @cOutField03 = @cAddNew_BOM

      IF ISNULL(@cAddNew_BOM, '') = ''
      BEGIN
         SET @nErrNo = 68473
         SET @cErrMsg = rdt.rdtgetmessage( 68473, @cLangCode, 'DSP') -- 'BOM REQ'
         GOTO BOM_Add_NEWBOM_Fail
      END

      IF @cAddNew_BOM <> @cBOM
      BEGIN
         SET @nErrNo = 68488
         SET @cErrMsg = rdt.rdtgetmessage( 68488, @cLangCode, 'DSP') -- 'Invalid BOM'
         GOTO BOM_Add_NEWBOM_Fail
      END

      IF @nParentSKUEntered = 1
      BEGIN
         -- Check if BOM exists in UPC table
         IF NOT EXISTS (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = @cBOM) 
         BEGIN
            SET @nErrNo = 68474
            SET @cErrMsg = rdt.rdtgetmessage( 68474, @cLangCode, 'DSP') -- 'Invalid BOM/SKU'
            GOTO BOM_Add_NEWBOM_Fail
         END
         -- Check if UPC.SKU exists in BOM table
         IF NOT EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
            JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (UPC.StorerKey = BOM.StorerKey AND UPC.SKU = BOM.SKU)
            WHERE UPC = @cBOM)
         BEGIN
            SET @nErrNo = 68475
            SET @cErrMsg = rdt.rdtgetmessage( 68475, @cLangCode, 'DSP') -- 'No BOM Setup'
            GOTO BOM_Add_NEWBOM_Fail
         END

         -- Check if UPC.PackKey exists in Pack table
         IF NOT EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON (UPC.PackKey = PACK.PackKey)
            WHERE UPC = @cBOM)
         BEGIN
            SET @nErrNo = 68476
            SET @cErrMsg = rdt.rdtgetmessage( 68476, @cLangCode, 'DSP') -- 'Invalid Pack'
            GOTO BOM_Add_NEWBOM_Fail
         END
         SELECT @cSKU = @cBOM

         SELECT TOP 1 
               @cSKUStorerKey = UPC.StorerKey, 
               @cParentSKU = UPC.SKU, 
               @cPackKey = UPC.PackKey, 
               @cUOM = UPC.UOM, 
               @cSKUDescr = SKU.Descr 
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
         WHERE UPC.UPC = @cSKU

         SELECT @nPackValue = CASE 
            WHEN @cUOM = 'CS' THEN CaseCnt 
            WHEN @cUOM = 'IP' THEN InnerPack 
            WHEN @cUOM = 'SH' THEN OtherUnit1 
            WHEN @cUOM = 'PL' THEN Pallet 
         END 
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE PackKey = @cPackKey

         IF @nPackValue = 0 
         BEGIN
            IF @cUOM = 'CS'
            BEGIN
               SET @nErrNo = 68465
               SET @cErrMsg = rdt.rdtgetmessage( 68465, @cLangCode, 'DSP') -- 'Invalid CaseCnt'
               GOTO BOM_Fail
            END

            IF @cUOM = 'IP'
            BEGIN
               SET @nErrNo = 68466
               SET @cErrMsg = rdt.rdtgetmessage( 68466, @cLangCode, 'DSP') -- 'Invalid InnerPack'
               GOTO BOM_Fail
            END

            IF @cUOM = 'SH'
            BEGIN
               SET @nErrNo = 68467
               SET @cErrMsg = rdt.rdtgetmessage( 68467, @cLangCode, 'DSP') -- 'Invalid Shipper'
               GOTO BOM_Fail
            END

            IF @cUOM = 'PL'
            BEGIN
               SET @nErrNo = 68468
               SET @cErrMsg = rdt.rdtgetmessage( 68468, @cLangCode, 'DSP') -- 'Invalid Pallet'
               GOTO BOM_Fail
            END
         END
                           
      END   
      ELSE
      BEGIN
         SELECT @cSKU = @cBOM
         
         -- Check if BOM exists in UPC table
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cSKUStorerKey 
                        AND SKU = @cSKU) 
         BEGIN
            SET @nErrNo = 68474
            SET @cErrMsg = rdt.rdtgetmessage( 68474, @cLangCode, 'DSP') -- 'Invalid BOM/SKU'
            GOTO BOM_Add_NEWBOM_Fail
         END                  
      END   


      SET @cOutField01 = @cLOC   -- OPT
      SET @cOutField02 = @cID
      SET @cOutField03 = @cParentSKU
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 1, 20)   
      SET @cOutField05 = ''
      SET @cOutField06 = @cUOM

      -- Go to next screen
      SET @nScn = @nScn_BOM_Add_Qty
      SET @nStep = @nStep_BOM_Add_Qty

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- bom

      -- Go to previous screen
      SET @nScn  = @nScn_BOM
      SET @nStep = @nStep_BOM
   END
   GOTO Quit

   BOM_Add_NEWBOM_Fail:
   BEGIN
      SET @cOutField03 = ''
   END
END
GOTO Quit

/************************************************************************************
Step_BOM_Add_Qty. Scn = 738. Screen 9.
   LOC         (field01)
   ID          (field02)
   BOM         (field03, input)
************************************************************************************/
Step_BOM_Add_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQty = @cInField05

      -- Retain the key-in value
      SET @cOutField05 = @cQty

      IF ISNULL(@cQty, '') = ''
      BEGIN
         SET @nErrNo = 68477
         SET @cErrMsg = rdt.rdtgetmessage( 68477, @cLangCode, 'DSP') -- 'Qty REQ'
         GOTO BOM_Add_Qty_Fail
      END

      -- Note: Zero qty is not allowed here
      IF rdt.rdtIsValidQTY( @cQty, 1) = 0 -- 0=not check for 0 QTY, 1=check for 0 QTY
      BEGIN
         SET @nErrNo = 68478
         SET @cErrMsg = rdt.rdtgetmessage( 68478, @cLangCode, 'DSP') -- 'Invalid Qty'
         GOTO BOM_Add_Qty_Fail
      END

      SET @nQty = CAST(@cQty AS INT)

      IF @nParentSKUEntered = 1
      
      -- Get 1st Component SKU
      SELECT @cComponentSKU = ComponentSku 
      FROM dbo.BillOfMaterial WITH (NOLOCK) 
      WHERE SKU = @cParentSKU
        AND StorerKey = @cSKUStorerKey
      ORDER BY Sequence

      --Assumption: All component SKU which belong to same Parent SKU should have same lottable setup
      SELECT TOP 1 
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''), 
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''), 
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''), 
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),
         @cLottable01_Code = IsNULL(SKU.Lottable01Label, ''),  
         @cLottable02_Code = IsNULL(SKU.Lottable02Label, ''),  
         @cLottable03_Code = IsNULL(SKU.Lottable03Label, ''),  
         @cLottable04_Code = IsNULL(SKU.Lottable04Label, '')  
      FROM dbo.SKU SKU WITH (NOLOCK) 
      WHERE SKU = @cComponentSKU
         AND StorerKey = @cSKUStorerKey

      -- Reinitialise variable
      SET @cHasLottable = '0'
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) 
         SET @cHasLottable = '1'

      IF @cHasLottable = '1'
      BEGIN
			--initiate @nCounter = 1
			SET @nCountLot = 1

         --retrieve value for pre lottable01 - 04
         WHILE @nCountLot <=4 --break the loop when @nCount >4
         BEGIN
				 IF @nCountLot = 1 
             BEGIN
                SET @cListName = 'Lottable01'
                SET @cLottableLabel = @cLottable01_Code
             END
             ELSE
				 IF @nCountLot = 2 
             BEGIN
                SET @cListName = 'Lottable02'
                SET @cLottableLabel = @cLottable02_Code
             END
             ELSE
				 IF @nCountLot = 3 
             BEGIN
                SET @cListName = 'Lottable03'
                SET @cLottableLabel = @cLottable03_Code
             END
             ELSE
				 IF @nCountLot = 4 
             BEGIN
                SET @cListName = 'Lottable04'
                  SET @cLottableLabel = @cLottable04_Code
             END
             ELSE

             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''
             SELECT @cShort = ISNULL(RTRIM(C.Short),''), 
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')
             FROM dbo.CodeLkUp C WITH (NOLOCK) 
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
         
             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN
               IF @cListName = 'Lottable01'
                  SET @cLottable01 = ''
               ELSE IF @cListName = 'Lottable02'
                  SET @cLottable02 = ''
               ELSE IF @cListName = 'Lottable03'
                  SET @cLottable03 = ''
               ELSE IF @cListName = 'Lottable04'
                  SET @dLottable04 = ''

               EXEC dbo.ispLottableRule_Wrapper
                  @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cSKUStorerKey,
                  @c_Sku               = @cComponentSKU,
                  @c_LottableLabel     = @cLottableLabel,
                  @c_Lottable01Value   = '',
                  @c_Lottable02Value   = '',
                  @c_Lottable03Value   = '',
                  @dt_Lottable04Value  = '',
                  @dt_Lottable05Value  = '',
                  @c_Lottable01        = @cLottable01 OUTPUT,
                  @c_Lottable02        = @cLottable02 OUTPUT,
                  @c_Lottable03        = @cLottable03 OUTPUT,
                  @dt_Lottable04       = @dLottable04 OUTPUT,
                  @dt_Lottable05       = @dLottable05 OUTPUT,
                  @b_Success           = @b_Success   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg            = @cErrMsg     OUTPUT,
                  @c_Sourcekey         = @cCCRefNo,
                  @c_Sourcetype        = 'RDTBOMCycleCount'

                IF ISNULL(@cErrMsg, '') <> ''  
					 BEGIN
  			          SET @cErrMsg = @cErrMsg
						 GOTO BOM_Add_Qty_Fail
					 END  

					 SET @cLottable01 = IsNULL( @cLottable01, '')
					 SET @cLottable02 = IsNULL( @cLottable02, '')
					 SET @cLottable03 = IsNULL( @cLottable03, '')
					 SET @dLottable04 = IsNULL( @dLottable04, 0)
              
                IF @dLottable04 > 0
                BEGIN
                   SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                END
			   END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
         END -- nCount

         -- Short - 'PRE'
         -- Verify Labels for Lotables
         -- Enable/Disable Lottables for data entry
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

         -- Clear all outfields
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cOutField13 = ''

         -- Initiate labels
         SELECT
            @cOutField01 = 'Lottable01:',
            @cOutField03 = 'Lottable02:',
            @cOutField05 = 'Lottable03:',
            @cOutField07 = 'Lottable04:',
            @cOutField09 = 'Lottable05:'

         -- Populate labels and lottables
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLotLabel01
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLotLabel02
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
             SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField05 = @cLotLabel03
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SELECT @cOutField07 = @cLotLabel04
         END

         EXEC rdt.rdtSetFocusField @nMobile, 1   -- Lottable01 value

         -- Go to next screen
         SET @nScn  = @nScn_BOM_Add_Lottables  
         SET @nStep = @nStep_BOM_Add_Lottables

         GOTO Quit
      END -- End of @cHasLottable = '1'
      ELSE
      BEGIN
         -- Insert a record into CCDETAIL
         SET @nErrNo = 0
         SET @cErrMsg = ''

         IF @nParentSKUEntered = 1
         BEGIN
            EXECUTE rdt.rdt_CycleCount_BOM_Insert
               @nMobile,
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cSKUStorerKey,
               @cSKU,
               @cLOC,
               @cID,    
               @nQty,    
               @nPackValue,
               @cUserName,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @dLottable05,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max            
         END
         ELSE
         BEGIN
             EXECUTE rdt.rdt_CycleCount_SKU_Insert
               @nMobile,
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cSKUStorerKey,
               @cSKU,
               @cLOC,
               @cID,    
               @nQty,    
               @nPackValue,
               @cUserName,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @dLottable05,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT  -- screen limitation, 20 char max           
         END


         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''   -- bom

      -- Go to previous screen
      SET @nScn  = @nScn_BOM_ADD_NEWBOM
      SET @nStep = @nStep_BOM_ADD_NEWBOM
   END
   GOTO Quit

   BOM_Add_Qty_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField05 = '' -- QTY
   END
END
GOTO Quit

/************************************************************************************
Step_BOM_Add_Lottables. Scn = 739. Screen 10.
   LOTTABLE01Label (field01)     LOTTABLE01 (field02) - Input field
   LOTTABLE02Label (field03)     LOTTABLE02 (field04) - Input field
   LOTTABLE03Label (field05)     LOTTABLE03 (field06) - Input field
   LOTTABLE04Label (field07)     LOTTABLE04 (field08) - Input field
*************************************************************************************/
Step_BOM_Add_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cNewLottable01 = @cInField02
      SET @cNewLottable02 = @cInField04
      SET @cNewLottable03 = @cInField06
      SET @cNewLottable04 = @cInField08

      -- Retain the key-in value
      SET @cOutField02 = @cNewLottable01
      SET @cOutField04 = @cNewLottable02
      SET @cOutField06 = @cNewLottable03
      SET @cOutField08 = @cNewLottable04

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
      
		--initiate @nCounter = 1
		SET @nCountLot = 1

		WHILE @nCountLot < = 4
		BEGIN
		  IF @nCountLot = 1 
	     BEGIN
	          SET @cListName = 'Lottable01'
	          SET @cLottableLabel = @cLottable01_Code
	     END
	     ELSE
		  IF @nCountLot = 2 
	     BEGIN
	          SET @cListName = 'Lottable02'
	          SET @cLottableLabel = @cLottable02_Code
	     END
	     ELSE
		  IF @nCountLot = 3 
	     BEGIN
	          SET @cListName = 'Lottable03'
	          SET @cLottableLabel = @cLottable03_Code
	     END
	     ELSE
		  IF @nCountLot = 4 
	     BEGIN
	          SET @cListName = 'Lottable04'
	            SET @cLottableLabel = @cLottable04_Code
	     END
	     ELSE

        SET @cShort = '' 
        SET @cStoredProd = ''

		  SELECT @cShort = C.Short, 
				   @cStoredProd = IsNULL( C.Long, '')
		  FROM dbo.CodeLkUp C WITH (NOLOCK) 
		  WHERE C.Listname = @cListName
		  AND   C.Code = @cLottableLabel

 
		  IF @cShort = 'POST' AND @cStoredProd <> ''
		  BEGIN
           IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date           
   			  SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

		     EXEC dbo.ispLottableRule_Wrapper
					  @c_SPName            = @cStoredProd,
					  @c_ListName          = @cListName,
					  @c_Storerkey         = @cSKUStorerKey,
					  @c_Sku               = @cComponentSku,
					  @c_LottableLabel     = @cLottableLabel,
					  @c_Lottable01Value   = @cLottable01,
					  @c_Lottable02Value   = @cLottable02,
					  @c_Lottable03Value   = @cLottable03,
					  @dt_Lottable04Value  = @dLottable04,
					  @dt_Lottable05Value  = @dLottable05,
					  @c_Lottable01        = @cTempLottable01 OUTPUT,
					  @c_Lottable02        = @cTempLottable02 OUTPUT,
					  @c_Lottable03        = @cTempLottable03 OUTPUT,
					  @dt_Lottable04       = @dTempLottable04 OUTPUT,
					  @dt_Lottable05       = @dTempLottable05 OUTPUT,
					  @b_Success           = @b_Success   OUTPUT,
					  @n_Err               = @nErrNo      OUTPUT,
					  @c_Errmsg            = @cErrMsg     OUTPUT,
                 @c_Sourcekey         = @cCCRefNo,
                 @c_Sourcetype        = 'RDTBOMCycleCount'

                 IF ISNULL(@cErrMsg, '') <> ''  
                 BEGIN
  				        SET @cErrMsg = @cErrMsg

                    IF @cListName = 'Lottable01' 
                       EXEC rdt.rdtSetFocusField @nMobile, 2 
                    ELSE IF @cListName = 'Lottable02' 
                       EXEC rdt.rdtSetFocusField @nMobile, 4 
                    ELSE IF @cListName = 'Lottable03' 
                       EXEC rdt.rdtSetFocusField @nMobile, 6 
                    ELSE IF @cListName = 'Lottable04' 
                       EXEC rdt.rdtSetFocusField @nMobile, 8 

                    GOTO BOM_Add_Lottables_Fail
                 END

					  SET @cTempLottable01 = IsNULL( @cTempLottable01, '')
					  SET @cTempLottable02 = IsNULL( @cTempLottable02, '')
					  SET @cTempLottable03 = IsNULL( @cTempLottable03, '')
					  SET @dTempLottable04 = IsNULL( @dTempLottable04, 0)

					  SET @cOutField02 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cLottable01 END
					  SET @cOutField04 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cLottable02 END
					  SET @cOutField06 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cLottable03 END
					  SET @cOutField08 = CASE WHEN @dTempLottable04 <> 0  THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cLottable04 END

                 SET @cLottable01 = IsNULL(@cOutField02, '')
                 SET @cLottable02 = IsNULL(@cOutField04, '')
					  SET @cLottable03 = IsNULL(@cOutField06, '')
                 SET @cLottable04 = IsNULL(@cOutField08, '')
         END -- Short

			--increase counter by 1
			SET @nCountLot = @nCountLot + 1

      END -- end of while

      SET @cOutField02 = CASE WHEN ISNULL(@cTempLottable01,'') <> '' THEN @cTempLottable01 ELSE @cNewLottable01 END
      SET @cOutField04 = CASE WHEN ISNULL(@cTempLottable02,'') <> '' THEN @cTempLottable02 ELSE @cNewLottable02 END
      SET @cOutField06 = CASE WHEN ISNULL(@cTempLottable03,'') <> '' THEN @cTempLottable03 ELSE @cNewLottable03 END
      SET @cOutField08 = CASE WHEN @dTempLottable04 IS NOT NULL THEN rdt.rdtFormatDate( @dTempLottable04) ELSE rdt.rdtFormatDate( @dNewLottable04) END

      SET @cNewLottable01 = ISNULL(@cOutField02, '')
      SET @cNewLottable02 = ISNULL(@cOutField04, '')
      SET @cNewLottable03 = ISNULL(@cOutField06, '')
      SET @cNewLottable04 = ISNULL(@cOutField08, '')

      -- Validate lottable01
      IF @cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL
         IF @cNewLottable01 = '' OR @cNewLottable01 IS NULL
         BEGIN
            SET @nErrNo = 68479
            SET @cErrMsg = rdt.rdtgetmessage( 68479, @cLangCode, 'DSP') --'Lottable1 req'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO BOM_Add_Lottables_Fail
         END

      -- Validate lottable02
      IF @cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL
      BEGIN
         IF @cNewLottable02 = '' OR @cNewLottable02 IS NULL
         BEGIN
            SET @nErrNo = 68480
            SET @cErrMsg = rdt.rdtgetmessage( 68480, @cLangCode, 'DSP') --'Lottable2 req'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO BOM_Add_Lottables_Fail
         END
      END

      -- Validate lottable03
      IF @cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL
         IF @cNewLottable03 = '' OR @cNewLottable03 IS NULL
         BEGIN
            SET @nErrNo = 68481
            SET @cErrMsg = rdt.rdtgetmessage( 68481, @cLangCode, 'DSP') --'Lottable3 req'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO BOM_Add_Lottables_Fail
         END

      -- Validate lottable04
      IF @cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cNewLottable04 = '' OR @cNewLottable04 IS NULL
         BEGIN
            SET @nErrNo = 68482
            SET @cErrMsg = rdt.rdtgetmessage( 68482, @cLangCode, 'DSP') --'Lottable4 req'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO BOM_Add_Lottables_Fail
         END
         -- Validate date
         IF rdt.rdtIsValidDate( @cNewLottable04) = 0
         BEGIN
            SET @nErrNo = 68483
            SET @cErrMsg = rdt.rdtgetmessage( 68483, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO BOM_Add_Lottables_Fail
         END
      END

      IF @cNewLottable04 <> '' AND @cNewLottable04 IS NOT NULL
         SET @dNewLottable04 = CAST( @cNewLottable04 AS DATETIME)
      ELSE
         SET @dNewLottable04 = NULL

      -- Insert a record into CCDETAIL
      SET @nErrNo = 0
      SET @cErrMsg = ''

      IF @nParentSKUEntered=1
      BEGIN
         EXECUTE rdt.rdt_CycleCount_BOM_Insert
            @nMobile,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cSKUStorerKey,
            @cSKU,   -- BOM SKU scanned in
            @cLOC,
            @cID,    
            @nQty,    
            @nPackValue,
            @cUserName,
            @cNewLottable01,
            @cNewLottable02,
            @cNewLottable03,
            @dNewLottable04,
            NULL,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  -- screen limitation, 20 char max         
      END
      ELSE
      BEGIN
         EXECUTE rdt.rdt_CycleCount_SKU_Insert
            @nMobile,
            @cCCRefNo,
            @cCCSheetNo,
            @nCCCountNo,
            @cSKUStorerKey,
            @cSKU,   -- BOM SKU scanned in
            @cLOC,
            @cID,    
            @nQty,    
            @nPackValue,
            @cUserName,
            @cNewLottable01,
            @cNewLottable02,
            @cNewLottable03,
            @dNewLottable04,
            NULL,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT  -- screen limitation, 20 char max         
         
      END


      IF @nErrNo <> 0
         GOTO BOM_Add_Lottables_Fail

      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

      -- Go to UCC (Main) screen
      SET @nScn  = @nScn_BOM
      SET @nStep = @nStep_BOM
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare previous screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField05 = ''
      SET @cOutField06 = @cUOM

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Go to previous screen
      SET @nScn  = @nScn_BOM_Add_Qty
      SET @nStep = @nStep_BOM_Add_Qty
   END
   GOTO Quit

   BOM_Add_Lottables_Fail:
   BEGIN
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''

      IF @nParentSKUEntered <> 1
      BEGIN
         SET @cComponentSKU = @cSKU
      END
      
      SELECT TOP 1 
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''), 
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''), 
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''), 
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),
         @cLottable01_Code = IsNULL(SKU.Lottable01Label, ''),  
         @cLottable02_Code = IsNULL(SKU.Lottable02Label, ''),  
         @cLottable03_Code = IsNULL(SKU.Lottable03Label, ''),  
         @cLottable04_Code = IsNULL(SKU.Lottable04Label, '')  
      FROM dbo.SKU SKU WITH (NOLOCK) 
      WHERE SKU = @cComponentSKU
         AND StorerKey = @cSKUStorerKey

      -- Reinitialise variable
      SET @cHasLottable = '0'
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) 
         SET @cHasLottable = '1'

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O'
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O'
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            SET @cFieldAttr06 = 'O'
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O'
         END

      END
   END
END
GOTO Quit

/************************************************************************************
Step_BOM_LOOKUP. Scn = 740. Screen 11.         
   SKU              (field01)           
   UOM              (field02)           
   COLOR            (field03)           
   SIZE = 99999     (field04) 
*************************************************************************************/
Step_BOM_LOOKUP:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cColor = @cOutField03

      SELECT TOP 1 @cNextColor = SKU.COLOR 
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
      WHERE BOM.SKU = @cSKU
         AND SKU.StorerKey = @cSKUStorerKey
         AND SKU.Color > @cColor

      IF ISNULL(@cNextColor, '') = ''
      BEGIN
         SET @nErrNo = 68486
         SET @cErrMsg = rdt.rdtgetmessage( 68486, @cLangCode, 'DSP') --'End Of Rec'
         GOTO Quit
      END

      SET @cColor = @cNextColor

      --Reinitialise
      SELECT @cSize1 = '' SELECT @nQty1 = 0       
      SELECT @cSize2 = '' SELECT @nQty2 = 0
      SELECT @cSize3 = '' SELECT @nQty3 = 0       
      SELECT @cSize4 = '' SELECT @nQty4 = 0
      SELECT @cSize5 = '' SELECT @nQty5 = 0       
      SELECT @cSize6 = '' SELECT @nQty6 = 0

      SET @nDummyCount = 1

      DECLARE CUR_BOM_LK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT SKU.Size, BOM.Qty FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
      WHERE BOM.SKU = @cSKU
         AND SKU.StorerKey = @cSKUStorerKey
         AND SKU.Color = @cColor
      ORDER BY SKU.Size
      OPEN CUR_BOM_LK
      FETCH NEXT FROM CUR_BOM_LK INTO @cBOM_Size, @nBOM_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nDummyCount = 1
         BEGIN
            SET @cSize1 = @cBOM_Size
            SET @nQty1 = @nBOM_Qty
         END
         IF @nDummyCount = 2
         BEGIN
            SET @cSize2 = @cBOM_Size
            SET @nQty2 = @nBOM_Qty
         END
         IF @nDummyCount = 3
         BEGIN
            SET @cSize3 = @cBOM_Size
            SET @nQty3 = @nBOM_Qty
         END
         IF @nDummyCount = 4
         BEGIN
            SET @cSize4 = @cBOM_Size
            SET @nQty4 = @nBOM_Qty
         END
         IF @nDummyCount = 5
         BEGIN
            SET @cSize5 = @cBOM_Size
            SET @nQty5 = @nBOM_Qty
         END
         IF @nDummyCount = 6
         BEGIN
            SET @cSize6 = @cBOM_Size
            SET @nQty6 = @nBOM_Qty
         END

         SET @nDummyCount = @nDummyCount + 1

         FETCH NEXT FROM CUR_BOM_LK INTO @cBOM_Size, @nBOM_Qty
      END
      CLOSE CUR_BOM_LK
      DEALLOCATE CUR_BOM_LK

      SET @cOutField01 = @cSKU
      SET @cOutField02 = @cUOM
      SET @cOutField03 = @cColor
      SET @cOutField04 = CASE WHEN ISNULL(@cSize1, '') <> '' THEN @cSize1 + ' = ' + CAST(@nQty1 AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField05 = CASE WHEN ISNULL(@cSize2, '') <> '' THEN @cSize2 + ' = ' + CAST(@nQty2 AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField06 = CASE WHEN ISNULL(@cSize3, '') <> '' THEN @cSize3 + ' = ' + CAST(@nQty3 AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField07 = CASE WHEN ISNULL(@cSize4, '') <> '' THEN @cSize4 + ' = ' + CAST(@nQty4 AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField08 = CASE WHEN ISNULL(@cSize5, '') <> '' THEN @cSize5 + ' = ' + CAST(@nQty5 AS NVARCHAR( 5)) ELSE '' END
      SET @cOutField09 = CASE WHEN ISNULL(@cSize6, '') <> '' THEN @cSize6 + ' = ' + CAST(@nQty6 AS NVARCHAR( 5)) ELSE '' END

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''   -- OPT
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = ''   -- Qty
      SET @cOutField05 = @cUOM
      SET @cOutField06 = @cID
      SET @cOutField07 = @cLottable01
      SET @cOutField08 = @cLottable02
      SET @cOutField09 = @cLottable03
      SET @cOutField10 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField11 = rdt.rdtFormatDate( @dLottable05)

      -- Go to next screen
      SET @nScn = @nScn_BOM_Count_Qty
      SET @nStep = @nStep_BOM_Count_Qty
   END
   GOTO Quit
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_LOT          = @cLOT,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      
      V_QTY          = @nQTY,

      V_String1      = @cCCRefNo,
      V_String2      = @cCCSheetNo,
      V_String4      = @cSuggestLOC,
      V_String5      = @cSuggestLogiLOC,
      V_String6      = @cParentSKU,
      V_String7      = @cComponentSKU,
      V_String8      = @cSheetNoFlag,  
      V_String9      = @cCCDetailKey,
      V_String10     = @cZone1,
      V_String11     = @cZone2,
      V_String12     = @cZone3,
      V_String13     = @cZone4,
      V_String14     = @cZone5,
      V_String15     = @cAisle,
      V_String16     = @cLevel,
      V_String17     = @nPackValue,
      V_String18     = @cBOM,
      V_String20     = @cSKUStorerKey, 

      V_Integer1     = @nCCCountNo,
      V_Integer2     = @nParentSKUEntered,
      
      V_String34     = @cNewLottable01,
      V_String35     = @cNewLottable02,
      V_String36     = @cNewLottable03,
      V_String37     = @dNewLottable04,
      V_String38     = @dNewLottable05,
      V_String40     = @cID_In,  
      
      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15,

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
   
END


GO