SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Inventory QC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2020-11-30 1.1  James    WMS-15709 Rework & enhance script (james01) */
/* 2021-07-01 1.2  Chermain WMS-17343 Step_11 logic to next scn  and    */
/*                          exec ispFinalizeIQC to finalize(cc01)       */
/* 2021-11-01 1.3  James    JSM-30011 Clear field attribute (james02)   */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_IQC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- Misc variable
DECLARE 
   @i             INT, 
   @nRowCount     INT, 
   @cChkFacility  NVARCHAR( 5) ,
   @nSKUCnt       INT,
   @cXML          NVARCHAR( 4000), -- To allow double byte data for e.g. SKU desc
   @cFinalizeFlag NVARCHAR(1),  
   @bSuccess      INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cUserName       NVARCHAR( 18),

   @cQCKey      NVARCHAR(10),
   @cFromLOC   NVARCHAR( 10), 
   @cFromID    NVARCHAR( 18), 
   @cSKU       NVARCHAR( 20), 
   @cSKUDescr  NVARCHAR( 60), 
   @cPUOM       NVARCHAR( 1),  -- Prefer UOM 
   @cPUOM_Desc  NVARCHAR( 5),  -- Prefer UOM desc
   @cMUOM_Desc  NVARCHAR( 5),  -- Master UOM desc
   @cToLOC     NVARCHAR( 10), 
   @cQCLine    NVARCHAR( 5), 
   @cQCLine2   NVARCHAR( 5), 
   @nIQCQty    INT,
   @cFROMLot   NVARCHAR(10), 
   @cPackkey   NVARCHAR(10), 
   @cReason    NVARCHAR(10),
   @cReason2   NVARCHAR(10),
   @cLottable02  NVARCHAR(18),
   @cLottable03  NVARCHAR(18),
   @dLottable04  Datetime,
   @cCallSource   NVARCHAR(2),
   @nPUOM_Div      INT,     -- UOM divider
   @nPIQC_QTY      INT,
   @nMIQC_QTY      INT,
   @nACT_QTY       INT,  -- SUM of @nPACT_QTY * @nPUOM_Div + @nMACT_QTY
   @nPACT_QTY      INT,
   @nMACT_QTY      INT,
   @cPACT_QTY      NVARCHAR(5),
   @cMACT_QTY      NVARCHAR(5),
   @cNext_QCLine   NVARCHAR(1),     -- Flag indicate SAme Line or Next Line
   @cConfigValue   NVARCHAR(1),
   @cToID          NVARCHAR( 18),    
   @cToID2         NVARCHAR( 18),    -- actual display column, bcos @cToID alway refresh from db
   @cACTToID       NVARCHAR( 18), 
   @cOption        NVARCHAR(1), 
   @cActToLoc      NVARCHAR(10),
   @cFrom_Facility NVARCHAR(5),
   @cTo_Facility   NVARCHAR(5),
   @cUPC           NVARCHAR( 30),
   @cDefaultQty    NVARCHAR( 5),
   @cDefaultReason NVARCHAR( 10),
   @cMatchSuggestLoc NVARCHAR( 1),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),

   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5    NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),
   @cErrMsg7    NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),
   @cErrMsg9    NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),
   @cErrMsg11   NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),
   @cErrMsg13   NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),
   @cErrMsg15   NVARCHAR( 20) 

SET @cNext_QCLine = '1'   -- YEs Default alway Next Line

-- Load RDT.RDTMobRec
SELECT 
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,
   @nACT_QTY   = V_Qty,   
   
   @nPUOM_Div  = V_Integer1, 
 
   @cSKU       = V_SKU, 
   @cSKUDescr  = V_SKUDescr, 
   @cFromLot   = V_Lot, 
   @cFromLOC   = V_Loc, 
   @cFromID    = V_ID,
   @cLottable02 = V_Lottable02, 
   @cLottable03 = V_Lottable03, 
   @dLottable04 = V_Lottable04, 
   @cPUOM       = V_UOM,     -- Pref UOM
   
   @cQCKey      = V_String1, 
   @cQCLine     = V_String2, 
   @cReason2    = V_String3,
   @cToID2      = V_String4,
   @cActToLoc   = V_String5,
   @cPUOM_Desc  = V_String6, -- Pref UOM desc
   @cMUOM_Desc  = V_String7, -- Master UOM desc
   @cDefaultQty = V_String8,
   @cDefaultReason = V_String9,
   @cMatchSuggestLoc = V_String10,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1730 -- IQC (generic)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = IQC
   IF @nStep = 1 GOTO Step_1   -- Scn = 1730. QC Key
   IF @nStep = 2 GOTO Step_2   -- Scn = 1731. QC Key, FROM LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1732. FROM LOC, FROM ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 1733. FROM LOC, FROM ID, SKU/UPC
   IF @nStep = 5 GOTO Step_5   -- Scn = 1734. QC LINE No, SKU, Lottables 2/3/4, IQC QTY, ACT Qty
   IF @nStep = 6 GOTO Step_6   -- Scn = 1735. SKU,	IQC Qty, Act Qty, Reason
   IF @nStep = 7 GOTO Step_7   -- Scn = 1736. SKU, IQC QTY, ACT QTY, Reason, ToID
   IF @nStep = 8 GOTO Step_8   -- Scn = 1737. IQC to different ID 	Proceed?		Yes/No
   IF @nStep = 9 GOTO Step_9   -- Scn = 1738. SKU, IQC QTY, ACT QTY, Reason, ToID, ToLOC
   IF @nStep = 10 GOTO Step_10   -- Scn = 1739. IQC to different location 	Proceed?		Yes/No
   IF @nStep = 11 GOTO Step_11   -- Scn = 1740. IQC successfully

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1730. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1730
   SET @nStep = 1

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get storer configure
   SET @cDefaultQty = rdt.rdtGetConfig( @nFunc, 'DefaultQty', @cStorerKey)
   SET @cDefaultReason = rdt.rdtGetConfig( @nFunc, 'DefaultReason', @cStorerKey)
   IF @cDefaultReason = '0'
    SET @cDefaultReason = ''
   SET @cMatchSuggestLoc = rdt.rdtGetConfig( @nFunc, 'MatchSuggestLoc', @cStorerKey)

   -- Initialize Variable
   SET @cFromLoc = ''
   SET @cFromID = ''
   SET @cQCLine = ''
   SET @cToID2 = ''
   SET @cActToID = ''
   SET @cActToLoc = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cFromLot = ''
   SET @cFromLOC = ''
   SET @cFromID = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = NULL
   SET @cPUOM_Desc = ''
   SET @cMUOM_Desc = ''
   SET @nPUOM_Div = ''
   SET @cReason2 = ''
   SET @nACT_QTY = ''

   -- Prep next screen var
   -- Init screen
   SET @cOutField01 = '' -- FromID

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1730. 
   QC KEY
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQCKey = @cInField01
      
      -- Validate blank
      IF @cQCKey = '' OR @cQCKey IS NULL
      BEGIN
         SET @nErrNo = 64051
         SET @cErrMsg = rdt.rdtgetmessage( 64051, @cLangCode, 'DSP') --'QC REF needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Get IQC Exist?
      IF NOT EXISTS( SELECT 1
         FROM dbo.InventoryQC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND QC_Key = @cQCKey )
      BEGIN
         SET @nErrNo = 64065
         SET @cErrMsg = rdt.rdtgetmessage( 64065, @cLangCode, 'DSP') --'Bad IQCKey'
         GOTO Step_1_Fail
      END

      -- Check IQC finalised?
      IF  EXISTS( SELECT 1
         FROM dbo.InventoryQC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND QC_Key = @cQCKey
            AND FinalizeFlag = 'Y' )
      BEGIN
         SET @nErrNo = 64052
         SET @cErrMsg = rdt.rdtgetmessage( 64052, @cLangCode, 'DSP') --'IQC finalized'
         GOTO Step_1_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cQCKey
      SET @cOutField02 = ''
      SET @cFromLoc = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cQCKey  = ''
      SET @cOutField01 = '' -- QC Key
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1731. 
   QC Key      (field01)
   FROM LOC    (field02, input)  
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField02
      
      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 64053
         SET @cErrMsg = rdt.rdtgetmessage( 64053, @cLangCode, 'DSP') --'Need FROM LOC'
         GOTO Step_2_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility, @cFromLOC = LOC
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 64054
         SET @cErrMsg = rdt.rdtgetmessage( 64054, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END
      
      SELECT 
         @cFrom_facility = From_facility
      FROM dbo.InventoryQC WITH (NOLOCK)
      WHERE QC_Key = @cQCKey

      IF ISNULL(RTRIM(@cFrom_facility), '') = ''
         SET @cFrom_facility = ''

      -- Validate LOC's facility
      IF @cChkFacility <> @cFrom_facility
      BEGIN
         SET @nErrNo = 64055
         SET @cErrMsg = rdt.rdtgetmessage( 64055, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_2_Fail
      END

      IF NOT EXISTS( SELECT 1
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key        = @cQCKey
            AND FromLOC      = @cFromLOC
            AND FinalizeFlag = 'N' )
      BEGIN
         SET @nErrNo = 64056
         SET @cErrMsg = rdt.rdtgetmessage( 64056, @cLangCode, 'DSP') --'NO task in LOC'
         GOTO Step_2_Fail
      END      
      
      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = ''
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cQCKey = ''
      SET @cOutField01 = '' -- QC Key
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromLOC  = ''
      SET @cOutField02 = @cQCKey
      SET @cOutField02 = '' -- FromLOC
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1732.  
   FROM LOC     (field01)
   FROM ID      (field02, input)  
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromID = ISNULL(@cInField02, '')
      
      -- Validate Exist
      IF NOT EXISTS( SELECT 1
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_KEY        = @cQCKey
            AND FromLOC      = @cFromLOC
            AND FromID       = @cFromID
            AND FinalizeFlag = 'N' )
      BEGIN
         SET @nErrNo = 64057
         SET @cErrMsg = rdt.rdtgetmessage( 64057, @cLangCode, 'DSP') --'ID not on IQC'
         GOTO Step_3_Fail
      END      

      SELECT @cFromID = FromID
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_KEY        = @cQCKey
         AND FromLOC      = @cFromLOC
         AND FromID       = @cFromID
         AND FinalizeFlag = 'N' 

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cFromLOC = ''
      SET @cOutField01 = @cQCKey
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField02 = @cFromLOC
      SET @cOutField02 = '' -- FromID
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 1733.  
   FROM LOC     (field01)
   FROM ID      (field02)  
   SKU/UPC:     (field03 input)  
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSku = ISNULL(@cInField03, '')
      SET @cUPC = ISNULL(@cInField03, '')

      -- Validate blank
      IF @cSku = '' OR @cSku IS NULL
      BEGIN
         SET @nErrNo = 64058
         SET @cErrMsg = rdt.rdtgetmessage( 64058, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_4_Fail
      END

      -- Get SKU count
      --DECLARE @bSuccess INT
      SET @nSKUCnt = 0
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 64059
         SET @cErrMsg = rdt.rdtgetmessage( 64059, @cLangCode, 'DSP') -- 'Invalid SKU'
         GOTO Step_4_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 64060
         SET @cErrMsg = rdt.rdtgetmessage( 64060 , @cLangCode, 'DSP') -- 'MultiSKUBarcod'
         GOTO Step_4_Fail
      END      

      EXEC rdt.rdt_GetSKU
            @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT
         
      SET @cSKU = @cUPC
         
      IF NOT EXISTS( SELECT 1
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_KEY        = @cQCKey
            AND FromLOC      = @cFromLOC
            AND FromID       = @cFromID
            AND sku          = @csku
            AND FinalizeFlag = 'N' )
      BEGIN
         SET @nErrNo = 64061
         SET @cErrMsg = rdt.rdtgetmessage( 64061, @cLangCode, 'DSP') --'SKU not on IQC'
         GOTO Step_4_Fail
      END  

      IF rdt.rdtIsValidQTY(@cDefaultQty, 1) = 1
         SET @nACT_QTY = CAST( @cDefaultQty AS INT)

      SET @cQCLine = ''
      Set @cQCLine2 = ''
   
      SELECT TOP 1 @cQCLine2 = QCLineNo
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo > @cQCLine
      AND FinalizeFlag = 'N'
      AND FromLOc  = @cFromLOc
      AND FromID   = @cFromID 
      AND SKU = @cSKU
      ORDER BY QCLineNo

      IF ISNULL(@cQCLine2 , '') = ''
      BEGIN
         SET @cQCLine = ''
         --GOTO Refresh_QCLine 

         Set @cQCLine2 = ''
   
         SELECT TOP 1 @cQCLine2    = QCLineNo
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo > @cQCLine
         AND FinalizeFlag = 'N'
         AND FromLOc  = @cFromLOc
         AND FromID   = @cFromID 
         ORDER BY QCLineNo
   
         IF ISNULL(@cQCLine2 , '') = ''
         BEGIN
            SET @cQCLine = ''
            --GOTO Refresh_QCLine   
         END
         ELSE
            SET @cQCLine = @cQCLine2

         IF @cNext_QCLine = '0'
         BEGIN
            SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
         END 

         Set @nIQCQty =0
         Set @cFROMLot = ''
         Set @cPackkey = ''

         SELECT @nIQCQty     = ToQty, 
               @cFROMLot     = FROMLot, 
               @cPackkey     = PackKey
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key      = @cQCKey
         AND QCLineNo      = @cQCLine
         AND FinalizeFlag = 'N'

            -- Get SKU info
         SELECT   @cSKUDescr = S.Descr, 
                  @cMUOM_Desc = Pack.PackUOM3, 
                  @cPUOM_Desc = 
                     CASE @cPUOM
                        WHEN '2' THEN Pack.PackUOM1 -- Case
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                     END, 
                  @nPUOM_Div = CAST( 
                     CASE @cPUOM
                        WHEN '2' THEN Pack.CaseCNT
                        WHEN '3' THEN Pack.InnerPack
                        WHEN '6' THEN Pack.QTY
                        WHEN '1' THEN Pack.Pallet
                        WHEN '4' THEN Pack.OtherUnit1
                        WHEN '5' THEN Pack.OtherUnit2
                     END AS INT)
         FROM dbo.SKU S WITH (NOLOCK) 
            INNER JOIN dbo.Pack Pack WITH (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

        -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cFieldAttr11 = 'O'
            SET @cFieldAttr13 = 'O'

            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = @nACT_QTY
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

       --     SET @nPQTY_Avail = 0
       --     SET @nPQTY_Move  = 0
       --     SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
              SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
              SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

      --      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
      --      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         Select @cLottable02  = Lottable02,
               @cLottable03   = Lottable03,
               @dLottable04  = Lottable04
         FROM dbo.Lotattribute WITH (NOLOCK)
         WHERE Lot  = @cFROMLot

         -- Prep next screen var
         SET @cOutField01 = @cQCLine
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

         SET @cOutField08 = @nPUOM_Div
         SET @cOutField09 = @cPUOM_Desc
         SET @cOutField10 = @cMUOM_Desc
         SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField12 = @nMIQC_QTY
         SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END
      END
      ELSE
         SET @cQCLine = @cQCLine2

      IF @cNext_QCLine = '0'
      BEGIN
         SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
      END 

      Set @nIQCQty =0
      Set @cFROMLot = ''
      Set @cPackkey = ''

      SELECT 
         @nIQCQty = ToQty, 
         @cFROMLot = FROMLot, 
         @cPackkey = PackKey
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key      = @cQCKey
      AND QCLineNo      = @cQCLine
      AND FinalizeFlag = 'N'

      -- Get SKU info
      SELECT   
         @cSKUDescr = S.Descr, 
         @cMUOM_Desc = Pack.PackUOM3, 
         @cPUOM_Desc = 
            CASE @cPUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END, 
         @nPUOM_Div = CAST( 
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END AS INT)
      FROM dbo.SKU S WITH (NOLOCK) 
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

     -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cFieldAttr11 = 'O'
         SET @cFieldAttr13 = 'O'

         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = @nACT_QTY
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END
      END
      ELSE
      BEGIN
           SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
           SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END
      END

      SELECT 
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04
      FROM dbo.Lotattribute WITH (NOLOCK)
      WHERE Lot = @cFROMLot

      -- Prep next screen var
      SET @cOutField01 = @cQCLine
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField08 = @nPUOM_Div
      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField12 = @nMIQC_QTY
      SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = '' -- FROMID
      SET @cOutField03 = '' -- Sku

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cSKU  = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- Sku
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1734. 
   QC LINE No (field01)
   SKU        (field02)
   Desc1      (field03)
   Desc2      (field04)
   LOTTABLE02 (field05)
   LOTTABLE03 (field06)
   LOTTABLE04 (field07)
   P UOM Factor (field08)
   PUOM_Desc  (filed09)
   MUOM_Desc  (field10)
   PIQC QTY   (field11)
   MIQC QTY   (field12)
   PACT QTY   (field13 - input) - may disable 
   MACT QTY   (field14 - input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cPACT_QTY = ISNULL(@cInField13, '')
      SET @cMACT_QTY = ISNULL(@cInField14, '')
      SET @nACT_QTY = 0

      IF @nPUOM_Div <= 1  -- no prefer UOM/ perfer UOM = UOM
      BEGIN
         SET @cPACT_QTY = ''
      END

      -- IF blank, Next QC Line / same line  
      IF @cPACT_QTY = '' AND @cMACT_QTY = ''
      BEGIN
         IF @cNext_QCLine = '1'
         BEGIN
            Set @cQCLine2 = ''
   
            SELECT TOP 1 @cQCLine2    = QCLineNo
            FROM dbo.InventoryQCDetail WITH (NOLOCK)
            WHERE QC_Key = @cQCKey
            AND QCLineNo > @cQCLine
            AND FinalizeFlag = 'N'
            AND FromLOc  = @cFromLOc
            AND FromID   = @cFromID 
            ORDER BY QCLineNo
   
            IF ISNULL(@cQCLine2 , '') = ''
            BEGIN
               SET @cQCLine = ''
               --GOTO Refresh_QCLine   
            END
            ELSE
               SET @cQCLine = @cQCLine2
         END

         IF @cNext_QCLine = '0'
         BEGIN
            SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
         END 

         Set @nIQCQty =0
         Set @cFROMLot = ''
         Set @cPackkey = ''

         SELECT @nIQCQty     = ToQty, 
               @cFROMLot     = FROMLot, 
               @cPackkey     = PackKey
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key      = @cQCKey
         AND QCLineNo      = @cQCLine
         AND FinalizeFlag = 'N'

         -- Get SKU info
         SELECT   @cSKUDescr = S.Descr, 
            @cMUOM_Desc = Pack.PackUOM3, 
            @cPUOM_Desc = 
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END, 
            @nPUOM_Div = CAST( 
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END AS INT)
         FROM dbo.SKU S WITH (NOLOCK) 
            INNER JOIN dbo.Pack Pack WITH (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

        -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cFieldAttr11 = 'O'
            SET @cFieldAttr13 = 'O'

            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = @nACT_QTY
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

       --     SET @nPQTY_Avail = 0
       --     SET @nPQTY_Move  = 0
       --     SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
              SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
              SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

      --      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
      --      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         Select @cLottable02  = Lottable02,
               @cLottable03   = Lottable03,
               @dLottable04  = Lottable04
         FROM dbo.Lotattribute WITH (NOLOCK)
         WHERE Lot  = @cFROMLot

         -- Prep next screen var
         SET @cOutField01 = @cQCLine
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

         SET @cOutField08 = @nPUOM_Div
         SET @cOutField09 = @cPUOM_Desc
         SET @cOutField10 = @cMUOM_Desc
         SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField12 = @nMIQC_QTY
         SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END
         --SET @cCallSource = '2'
         --GOTO Show_QCLine 
         --Show_QCLine2:
         GOTO Quit
      END
   
      IF @cPACT_QTY <> '' AND @nPUOM_Div > 1
      BEGIN
         IF rdt.rdtIsValidQTY(@cPACT_QTY, 0) = 0
         BEGIN
            SET @nErrNo = 64062
            SET @cErrMsg = rdt.rdtgetmessage( 64062 , @cLangCode, 'DSP') -- 'Invalid Qty'
            GOTO Step_5_Fail
         END
         
         SET @nPACT_QTY = CAST( @cPACT_QTY AS INT)  

         IF @nPUOM_Div > 0
         BEGIN
             SET @nACT_QTY  = @nPACT_QTY * @nPUOM_Div
         END
         ELSE
         BEGIN
            SET @nACT_QTY  = @nPACT_QTY 
         END
      END  
      
      IF @cMACT_QTY <> ''
      BEGIN
         IF rdt.rdtIsValidQTY(@cMACT_QTY, 0) = 0
         BEGIN
            SET @nErrNo = 64063
            SET @cErrMsg = rdt.rdtgetmessage( 64063 , @cLangCode, 'DSP') -- 'Invalid Qty'
            GOTO Step_5_Fail
         END
         
         SET @nMACT_QTY = CAST( @cMACT_QTY AS INT)

         IF @nMACT_QTY > 0
         BEGIn
            SET @nACT_QTY = @nACT_QTY + @nMACT_QTY
         END
      END
      
      IF ISNULL(( SELECT SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LLI.LOT = @cFromLot
            AND LLI.LOC   = @cFromLoc
            AND LLI.ID    = @cFromID ), 0) < 
         ISNULL((SELECT SUM(ToQTY)         -- Othrer QC LIne may have same Lotxlocxid
            FROM dbo.InventoryQCDetail WITH (NOLOCK)
            WHERE QC_Key     = @cQCKey
            AND QCLineNo     <> @cQCLine
            AND FromLOT      = @cFromLot
            AND FromLOC      = @cFromLOC
            AND FromID       = @cFromID
            AND FinalizeFlag <> 'Y' ), 0) + @nACT_QTY
      BEGIN
         SET @nErrNo = 64064
         SET @cErrMsg = rdt.rdtgetmessage( 64064 , @cLangCode, 'DSP') -- 'QTY too much'
         GOTO Step_5_Fail
      END

       IF @nACT_QTY > 0 
       BEGIN 
         Set @cReason2 = ''
         Set @nIQCQty =0
         Set @cReason = ''
         Set @cToID = ''
         Set @cToLoc = ''

         SELECT @nIQCQty      = ISNULL(ToQty, 0), 
                @cReason      = ISNULL(Reason, ''),
                @cToID        = ISNULL(ToID, ''),
                @cToLoc       = ISNULL(ToLoc, '') 
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo = @cQCLine
         AND SKU      = @cSKU
         AND FROMLoc  = @cFROMLoc
         AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            SET @nPACT_QTY = 0
            SET @nMACT_QTY = @nACT_QTY

         END
         ELSE
         BEGIN
            SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField04 = @nPUOM_Div
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = @cMUOM_Desc
         SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
         SET @cOutField08 = @nMIQC_QTY 
         SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
         SET @cOutField10 = @nMACT_QTY  
         -- Get Next screen
         --SET @cCallSource = '1'
         --GOTO Show_SKUUpdate 
         --Show_SKUUpdate1:      
   
         SET @cFieldAttr11 = ''
         SET @cOutField11 = CASE WHEN @cDefaultReason = '' THEN @cReason ELSE @cDefaultReason END

         -- Goto Next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         UPDATE dbo.InventoryQCDetail WITH (ROWLOCK)
         SET QTY    = 0,
            ToQTY   = 0,
            TrafficCop = NULL
         WHERE QC_Key     = @cQCKey
         AND QCLineNo     = @cQCLine
         AND FromLOC      = @cFromLOC
         AND FromID       = @cFromID
         AND FinalizeFlag = 'N'
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 64075
            SET @cErrMsg = rdt.rdtgetmessage( 64075, @cLangCode, 'DSP') --'Upd QCDtl Fail'
            GOTO Step_5_Fail
         END

      -- Prep next screen var
         -- Screen Set in  Show_QCLine 
         SET @nACT_QTY = 0 
         IF @cNext_QCLine = '1'
         BEGIN
            --Refresh_QCLine:
            Set @cQCLine2 = ''
   
            SELECT TOP 1 @cQCLine2    = QCLineNo
            FROM dbo.InventoryQCDetail WITH (NOLOCK)
            WHERE QC_Key = @cQCKey
            AND QCLineNo > @cQCLine
            AND FinalizeFlag = 'N'
            AND FromLOc  = @cFromLOc
            AND FromID   = @cFromID 
            ORDER BY QCLineNo
   
            IF ISNULL(@cQCLine2 , '') = ''
            BEGIN
               SET @cQCLine = ''
               --GOTO Refresh_QCLine   
            END
            ELSE
               SET @cQCLine = @cQCLine2
         END

         IF @cNext_QCLine = '0'
         BEGIN
            SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
         END 

         Set @nIQCQty =0
         Set @cFROMLot = ''
         Set @cPackkey = ''

         SELECT @nIQCQty     = ToQty, 
               @cFROMLot     = FROMLot, 
               @cPackkey     = PackKey
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key      = @cQCKey
         AND QCLineNo      = @cQCLine
         AND FinalizeFlag = 'N'

            -- Get SKU info
         SELECT   @cSKUDescr = S.Descr, 
                  @cMUOM_Desc = Pack.PackUOM3, 
                  @cPUOM_Desc = 
                     CASE @cPUOM
                        WHEN '2' THEN Pack.PackUOM1 -- Case
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                     END, 
                  @nPUOM_Div = CAST( 
                     CASE @cPUOM
                        WHEN '2' THEN Pack.CaseCNT
                        WHEN '3' THEN Pack.InnerPack
                        WHEN '6' THEN Pack.QTY
                        WHEN '1' THEN Pack.Pallet
                        WHEN '4' THEN Pack.OtherUnit1
                        WHEN '5' THEN Pack.OtherUnit2
                     END AS INT)
         FROM dbo.SKU S WITH (NOLOCK) 
            INNER JOIN dbo.Pack Pack WITH (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

        -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cFieldAttr11 = 'O'
            SET @cFieldAttr13 = 'O'

            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = @nACT_QTY
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

       --     SET @nPQTY_Avail = 0
       --     SET @nPQTY_Move  = 0
       --     SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
              SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
              SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

            IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
            BEGIN
               SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
            END
            ELSE
            BEGIN
               SET @nPAct_QTY = 0
               SET @nMAct_QTY = 0
            END

      --      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
      --      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         Select @cLottable02  = Lottable02,
               @cLottable03   = Lottable03,
               @dLottable04  = Lottable04
         FROM dbo.Lotattribute WITH (NOLOCK)
         WHERE Lot  = @cFROMLot

         -- Prep next screen var
         SET @cOutField01 = @cQCLine
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

         SET @cOutField08 = @nPUOM_Div
         SET @cOutField09 = @cPUOM_Desc
         SET @cOutField10 = @cMUOM_Desc
         SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField12 = @nMIQC_QTY
         SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
         SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END
         --SET @cCallSource = '3'
         --GOTO Show_QCLine 
         --Show_QCLine3:
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @nACT_QTY = 0
      SET @cQCLine  = ''

      SET @cSKU  = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- Sku

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cNext_QCLine = '0'
      IF @cNext_QCLine = '1'
      BEGIN
         --Refresh_QCLine:
         Set @cQCLine2 = ''
   
         SELECT TOP 1 @cQCLine2    = QCLineNo
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo > @cQCLine
         AND FinalizeFlag = 'N'
         AND FromLOc  = @cFromLOc
         AND FromID   = @cFromID 
         ORDER BY QCLineNo
   
         IF ISNULL(@cQCLine2 , '') = ''
         BEGIN
            SET @cQCLine = ''
            --GOTO Refresh_QCLine   
         END
         ELSE
            SET @cQCLine = @cQCLine2
      END

      IF @cNext_QCLine = '0'
      BEGIN
         SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
      END 

      Set @nIQCQty =0
      Set @cFROMLot = ''
      Set @cPackkey = ''

      SELECT @nIQCQty     = ToQty, 
            @cFROMLot     = FROMLot, 
            @cPackkey     = PackKey
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key      = @cQCKey
      AND QCLineNo      = @cQCLine
      AND FinalizeFlag = 'N'

         -- Get SKU info
      SELECT   @cSKUDescr = S.Descr, 
               @cMUOM_Desc = Pack.PackUOM3, 
               @cPUOM_Desc = 
                  CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END, 
               @nPUOM_Div = CAST( 
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END AS INT)
      FROM dbo.SKU S WITH (NOLOCK) 
         INNER JOIN dbo.Pack Pack WITH (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

     -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cFieldAttr11 = 'O'
         SET @cFieldAttr13 = 'O'

         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = @nACT_QTY
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END

    --     SET @nPQTY_Avail = 0
    --     SET @nPQTY_Move  = 0
    --     SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
      END
      ELSE
      BEGIN
           SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
           SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END

   --      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
   --      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

      Select @cLottable02  = Lottable02,
            @cLottable03   = Lottable03,
            @dLottable04  = Lottable04
      FROM dbo.Lotattribute WITH (NOLOCK)
      WHERE Lot  = @cFROMLot

      -- Prep next screen var
      SET @cOutField01 = @cQCLine
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

      SET @cOutField08 = @nPUOM_Div
      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField12 = @nMIQC_QTY
      SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END
      --SET @cCallSource = '4'
      --GOTO Show_QCLine 
      --Show_QCLine4:      
   END
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1735. 
   SKU        (field01)
   Desc1      (field02)
   Desc2      (field03)
   P UOM Factor  (field04)
   PUOM_Desc  (field05)
   MUOM_Desc  (field06)
   PIQC QTY   (field07)
   MIQC QTY   (field08)
   PACT QTY   (filed09)
   MACT QTY   (field10)
   REASON     (field11 - input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReason = ISNULL(@cInField11, '')

      -- IF blank, Next QC Line / same line  
      IF @cReason = '' Or @cReason is NULL
      BEGIN
         SET @nErrNo = 64066
         SET @cErrMsg = rdt.rdtgetmessage( 64066 , @cLangCode, 'DSP') -- 'Reason needed'
         GOTO Step_6_Fail
      END
         
      IF NOT EXISTS ( SELECT 1
         FROM dbo.CodeLKup CL WITH (NOLOCK)
         WHERE CL.ListName = 'ASNREASON'
         AND   CL.Code     = @cReason  ) 
      BEGIN
         SET @nErrNo = 64067
         SET @cErrMsg = rdt.rdtgetmessage( 64067 , @cLangCode, 'DSP') -- 'Invalid reason'
         GOTO Step_6_Fail
      END

      SELECT @cReason = CL.Code
      FROM dbo.CodeLKup CL WITH (NOLOCK)
      WHERE CL.ListName = 'ASNREASON'
      AND   CL.Code     = @cReason 

      SET @cReason2 = @cReason

      --SET @cCallSource = '3'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate3:  
      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- (james02)
      -- Clear previous field attribute
      SET @cFieldAttr11 = ''
      SET @cFieldAttr13 = ''
      
      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
      
      -- Prep next screen var
      SET @cOutField11 = @cReason2
      SET @cACTToID = ''
      SET @cOutField12 = @cToID
      SET @cOutField13 = ''

      -- Go to Next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      Set @cReason  = ''
      SET @cReason2 = ''
      SET @cToID   = ''
      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cNext_QCLine = '0'     -- do not jump to next line flag
      IF @cNext_QCLine = '1'
      BEGIN
         --Refresh_QCLine:
         Set @cQCLine2 = ''
   
         SELECT TOP 1 @cQCLine2    = QCLineNo
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo > @cQCLine
         AND FinalizeFlag = 'N'
         AND FromLOc  = @cFromLOc
         AND FromID   = @cFromID 
         ORDER BY QCLineNo
   
         IF ISNULL(@cQCLine2 , '') = ''
         BEGIN
            SET @cQCLine = ''
            --GOTO Refresh_QCLine   
         END
         ELSE
            SET @cQCLine = @cQCLine2
      END

      IF @cNext_QCLine = '0'
      BEGIN
         SET @cNext_QCLine = '1'  -- Set as alway get Next QCLine
      END 

      Set @nIQCQty =0
      Set @cFROMLot = ''
      Set @cPackkey = ''

      SELECT @nIQCQty     = ToQty, 
            @cFROMLot     = FROMLot, 
            @cPackkey     = PackKey
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key      = @cQCKey
      AND QCLineNo      = @cQCLine
      AND FinalizeFlag = 'N'

         -- Get SKU info
      SELECT   @cSKUDescr = S.Descr, 
               @cMUOM_Desc = Pack.PackUOM3, 
               @cPUOM_Desc = 
                  CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END, 
               @nPUOM_Div = CAST( 
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END AS INT)
      FROM dbo.SKU S WITH (NOLOCK) 
         INNER JOIN dbo.Pack Pack WITH (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

     -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cFieldAttr11 = 'O'
         SET @cFieldAttr13 = 'O'

         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = @nACT_QTY
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END

    --     SET @nPQTY_Avail = 0
    --     SET @nPQTY_Move  = 0
    --     SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
      END
      ELSE
      BEGIN
           SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
           SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit
 

         IF @nACT_QTY > 0    -- Normal Bqck/Esc from previous screen (reason), show QTY
         BEGIN
            SET @nPAct_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMAct_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit 
         END
         ELSE
         BEGIN
            SET @nPAct_QTY = 0
            SET @nMAct_QTY = 0
         END

   --      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
   --      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

      Select @cLottable02  = Lottable02,
            @cLottable03   = Lottable03,
            @dLottable04  = Lottable04
      FROM dbo.Lotattribute WITH (NOLOCK)
      WHERE Lot  = @cFROMLot

      -- Prep next screen var
      SET @cOutField01 = @cQCLine
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

      SET @cOutField08 = @nPUOM_Div
      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @nPUOM_Div > 1 THEN Cast( @nPIQC_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField12 = @nMIQC_QTY
      SET @cOutField13 = CASE WHEN @nPUOM_Div > 1 AND @nACT_QTY > 0  THEN Cast( @nPAct_QTY as NVARCHAR(5)) ELSE ''  END
      SET @cOutField14 = CASE WHEN @nACT_QTY > 0 THEN @nMAct_QTY END
      --SET @cCallSource = '5'
      --GOTO Show_QCLine 
      --Show_QCLine5:    
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      Set @cReason2  = ''
      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
      --SET @cCallSource = '2'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate2:      
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 1736. 
   SKU        (field01)
   Desc1      (field02)
   Desc2      (field03)
   P UOM Factor  (field04)
   PUOM_Desc  (field05)
   MUOM_Desc  (field06)
   PIQC QTY   (field07)
   MIQC QTY   (field08)
   PACT QTY   (filed09)
   MACT QTY   (field10)
   REASON     (field11)
   To ID      (field12)
   To ID      (field13 - Input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cACTToID = ISNULL(@cInField13, '')
      SET @cToID    = ISNULL(@cOutField12, '')  

      SET @cToID2 = @cACTToID

      IF @cToID <> @cActToID   -- IF change ToID  
            AND ISNULL(@cToID , '') <> ''
      BEGIn
       -- Prep next screen var
         -- Option - IQC to different ID   Proceed?
         SET @cOutField01 = ''

         -- Go to Next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END  --    END -- IF change ToID 
      
      --SET @cCallSource = '4'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate4:  

      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID
      --INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5, Step1) VALUES
      --('123', GETDATE(), @cQCKey, @cQCLine, @cSKU, @cFROMLoc, @cFROMID, @cToLoc)
         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
      SET @cOutField11 = @cReason2   
      SET @cOutField12 = @cToID2
      SET @cOutField13 = @cTOLoc
      SET @cOutField14 = ''

      -- Go to Next screen
      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2
   END   -- 

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cToID2 = ''

      --SET @cCallSource = '5'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate5:  
      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
      SET @cOutField11 = CASE WHEN @cDefaultReason = '' THEN @cReason ELSE @cDefaultReason END   --  db value

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      --SET @cCallSource = '6'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate6:      
      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
      SET @cACTToID = ''
      SET @cToID2 = ''
      SET @cOutField11 = @cReason2
      SET @cOutField12 = @cToID2          -- this is actual display and set it in V_string3 use for next 
      SET @cOutField13 = ''

   END
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 1737. 
   IQC to different ID 
   Proceed?   
   1=YES   2=NO
   OPTION:   (field01 - input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = ISNULL(@cInField01, '')
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 64068
         SET @cErrMsg = rdt.rdtgetmessage( 64068, @cLangCode, 'DSP') --Option needed 
         GOTO Step_8_Fail
      END
     
      IF Not ( @cOption = '1' OR @cOption = '2' )
      BEGIN
         SET @nErrNo = 64069  
         SET @cErrMsg = rdt.rdtgetmessage( 64069, @cLangCode, 'DSP') --Invalid Option         
         GOTO Step_8_Fail  
      END

      IF @cOption = '1'
      BEGIN
         --SET @cCallSource = '8'
         --GOTO Show_SKUUpdate 
         --Show_SKUUpdate8:     

         Set @nIQCQty =0
         Set @cReason = ''
         Set @cToID = ''
         Set @cToLoc = ''

         SELECT @nIQCQty      = ISNULL(ToQty, 0), 
                @cReason      = ISNULL(Reason, ''),
                @cToID        = ISNULL(ToID, ''),
                @cToLoc       = ISNULL(ToLoc, '') 
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo = @cQCLine
         AND SKU      = @cSKU
         AND FROMLoc  = @cFROMLoc
         AND FROMID   = @cFROMID

            SET @cConfigValue = ''
            SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
            IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
            BEGIN
               Set @cToID = @cFromID
            END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            SET @nPACT_QTY = 0
            SET @nMACT_QTY = @nACT_QTY

         END
         ELSE
         BEGIN
            SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField04 = @nPUOM_Div
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = @cMUOM_Desc
         SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
         SET @cOutField08 = @nMIQC_QTY 
         SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
         SET @cOutField10 = @nMACT_QTY  
   
         -- Prep next screen var
         SET @cOutField11 = @cReason2   
         SET @cOutField12 = @cToID2
         SET @cOutField13 = @cTOLoc
         SET @cOutField14 = ''

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN
         --SET @cCallSource = '7'
         --GOTO Show_SKUUpdate 
         --Show_SKUUpdate7:      

         Set @nIQCQty =0
         Set @cReason = ''
         Set @cToID = ''
         Set @cToLoc = ''

         SELECT @nIQCQty      = ISNULL(ToQty, 0), 
                @cReason      = ISNULL(Reason, ''),
                @cToID        = ISNULL(ToID, ''),
                @cToLoc       = ISNULL(ToLoc, '') 
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo = @cQCLine
         AND SKU      = @cSKU
         AND FROMLoc  = @cFROMLoc
         AND FROMID   = @cFROMID

            SET @cConfigValue = ''
            SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
            IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
            BEGIN
               Set @cToID = @cFromID
            END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            SET @nPACT_QTY = 0
            SET @nMACT_QTY = @nACT_QTY

         END
         ELSE
         BEGIN
            SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField04 = @nPUOM_Div
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = @cMUOM_Desc
         SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
         SET @cOutField08 = @nMIQC_QTY 
         SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
         SET @cOutField10 = @nMACT_QTY  

         -- Prepare prev screen var
         SET @cOutField11 = @cReason2   

         SET @cACTToID = ''
         SET @cToID2 = ''
         SET @cOutField12 = @cToID 
         SET @cOutField13 = ''

         -- Back to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END
   END

--    IF @nInputKey = 0 -- Esc or No
--    BEGIN
--       
--       SET @cCallSource = '8'
--       GOTO Show_SKUUpdate 
--       Show_SKUUpdate8:      
-- 
--       -- Prepare prev screen var
--          SET @cOutField11 = @cReason2   
-- 
--          SET @cACTToID = ''
--          SET @cToID2 = ''
-- --         SET @cOutField12 = @cToID2          -- this is actual display and set it in V_string3 use for next 
--          SET @cOutField13 = ''
-- 
-- 
--       -- Go back to prev screen
--       SET @nScn  = @nScn - 1
--       SET @nStep = @nStep - 1
--    END
--    GOTO Quit

   Step_8_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''  -- Option
   END
END
GOTO Quit

/********************************************************************************
Step 9. Scn = 1738. 
   SKU        (field01)
   Desc1      (field02)
   Desc2      (field03)
   P UOM Factor  (field04)
   PUOM_Desc  (field05)
   MUOM_Desc  (field06)
   PIQC QTY   (field07)
   MIQC QTY   (field08)
   PACT QTY   (filed09)
   MACT QTY   (field10)
   REASON     (field11)
   To ID      (field12)
   To LOC     (field13)
   To LOC     (field14 - Input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cACTToLoc = ISNULL(@cInField14, '')
      SET @cToLoc = ISNULL(@cOutField13, '')

      -- Validate blank
      IF @cACTToLoc = '' OR @cACTToLoc IS NULL
      BEGIN
         SET @nErrNo = 64070
         SET @cErrMsg = rdt.rdtgetmessage( 64070, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_9_Fail
      END

      IF @cACTToLoc <> @cToLoc AND @cMatchSuggestLoc = 0
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = 'WRONG LOC.'
         SET @cErrMsg2 = 'PLS HOLD THE SKU.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END

         -- Prep next screen var
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = ''
      
         -- Go to next screen
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
         GOTO Quit
      END

      Set @cChkFacility = ''
      -- Get LOC info
      SELECT @cChkFacility = Facility, @cACTToLoc = LOC 
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cACTToLoc

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 64071
         SET @cErrMsg = rdt.rdtgetmessage( 64071, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_9_Fail
      END
      
      SELECT @cTo_facility = To_facility
      FROM dbo.InventoryQC WITH (NOLOCK)
      WHERE QC_Key        = @cQCKey

      IF ISNULL(RTRIM(@cTo_facility), '') = ''
         SET @cTo_facility = ''

      -- Validate LOC's facility
      IF ISNULL(@cChkFacility, '') <> @cTo_facility
      BEGIN
         SET @nErrNo = 64072
         SET @cErrMsg = rdt.rdtgetmessage( 64072, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_9_Fail
      END

     
      IF @cACTToLoc <> @cToLoc AND ISNULL(@cToLoc , '') <> ''   -- dispaly ToLoc is blank
      BEGIn
       -- Prep next screen var
         -- Option - IQC to different location   Proceed?
         SET @cOutField01 = ''
   
         -- Go to Next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''

         --SET @cCallSource = '1'
         --GOTO Check_Finalize 
         --Check_Finalize1:     
         -- Get WMS 'FinalizeIQC' Configuration
         SET @cFinalizeFlag = 0

         IF EXISTS( SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey  
                     AND ConfigKey = 'FinalizeIQC' AND sValue = '1' )
         BEGIN
            SET    @cFinalizeFlag = '1'
         END   
         ELSE
         BEGIN
            SET    @cFinalizeFlag = '0'
         END

         IF @cFinalizeFlag = '1'
         BEGIN
            -- Only ConfigKey = 'NotFinalizeInventoryQCDetail' AND sValue = '0' , then will finalize

            IF EXISTS ( SELECT 1 FROM RDT.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey  
                     AND ConfigKey = 'NotFinalizeInventoryQCDetail' AND sValue = '0' )
            BEGIN
               SET @cFinalizeFlag = '0'
            END
         END

         --IF @cFinalizeFlag = '1'
         --BEGIN
         --   Update dbo.InventoryQCDetail WITH (ROWLOCK)
         --   SET QTY    = @nACT_QTY,
         --       TOQty  = @nACT_QTY, 
         --       Reason = @cReason2,
         --       ToID   = @cToID2,
         --       ToLoc  = @cActToLoc,
         --       FinalizeFlag = 'Y'
         --   WHERE QC_KEY        = @cQCKey
         --      AND QCLineNo     = @cQCLine
         --      AND FinalizeFlag = 'N'
         --   IF @@ROWCOUNT = 0
         --   BEGIN
         --      SET @nErrNo = 64076
         --      SET @cErrMsg = rdt.rdtgetmessage( 64076, @cLangCode, 'DSP') --'Upd QCDtl Fail'
         --      GOTO Step_10_Fail
         --   END

         --END
         --ELSE
         --BEGIN
         --   Update dbo.InventoryQCDetail WITH (ROWLOCK)
         --   SET QTY    = @nACT_QTY,
         --       TOQty  = @nACT_QTY, 
         --       Reason = @cReason2,
         --       ToID   = @cToID2,
         --       ToLoc  = @cActToLoc,
         --       TrafficCop = NULL  
         --   WHERE QC_KEY        = @cQCKey
         --      AND QCLineNo     = @cQCLine
         --      AND FinalizeFlag = 'N'
         --   IF @@ROWCOUNT = 0
         --   BEGIN
         --      SET @nErrNo = 64077
         --      SET @cErrMsg = rdt.rdtgetmessage( 64077, @cLangCode, 'DSP') --'Upd QCDtl Fail'
         --      GOTO Step_10_Fail
         --   END
         --END
         
         --(cc01)
         Update dbo.InventoryQCDetail WITH (ROWLOCK) SET
            QTY    = @nACT_QTY,
            TOQty  = @nACT_QTY, 
            Reason = @cReason2,
            ToID   = @cToID2,
            ToLoc  = @cActToLoc,
            TrafficCop = NULL  
         WHERE QC_KEY        = @cQCKey
            AND QCLineNo     = @cQCLine
            AND FinalizeFlag = 'N'
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 64076
            SET @cErrMsg = rdt.rdtgetmessage( 64077, @cLangCode, 'DSP') --'Upd QCDtl Fail'
            GOTO Step_10_Fail
         END
         
         IF @cFinalizeFlag = '1'
         BEGIN
         	EXEC ispFinalizeIQC
         	   @c_qc_key     = @cQCKey,                                                            
               @b_Success    = @bSuccess  OUTPUT,        
               @n_err        = @nErrNo    OUTPUT,        
               @c_errmsg     = @cErrMsg   OUTPUT,
               @c_QC_LineNo  = @cQCLine
               
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 64077
               SET @cErrMsg = rdt.rdtgetmessage( 64077, @cLangCode, 'DSP') --'Upd QCDtl Fail'
               GOTO Step_10_Fail
            END
         END
         

         -- Go to Next screen   -- skip confirm update screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      --SET @cCallSource = '9'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate9:  

         Set @nIQCQty =0
         Set @cReason = ''
         Set @cToID = ''
         Set @cToLoc = ''

         SELECT @nIQCQty      = ISNULL(ToQty, 0), 
                @cReason      = ISNULL(Reason, ''),
                @cToID        = ISNULL(ToID, ''),
                @cToLoc       = ISNULL(ToLoc, '') 
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo = @cQCLine
         AND SKU      = @cSKU
         AND FROMLoc  = @cFROMLoc
         AND FROMID   = @cFROMID

            SET @cConfigValue = ''
            SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
            IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
            BEGIN
               Set @cToID = @cFromID
            END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            SET @nPACT_QTY = 0
            SET @nMACT_QTY = @nACT_QTY

         END
         ELSE
         BEGIN
            SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField04 = @nPUOM_Div
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = @cMUOM_Desc
         SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
         SET @cOutField08 = @nMIQC_QTY 
         SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
         SET @cOutField10 = @nMACT_QTY  
   
      -- Prepare prev screen var
      SET @cActToLoc = ''
      SET @cOutField11 = @cReason2   

      SET @cToID2 = ''
      SET @cOutField12 = @cToID

      -- Go back to prev screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit


   Step_9_Fail:
   BEGIN
      --SET @cCallSource = '10'
      --GOTO Show_SKUUpdate 
      --Show_SKUUpdate10:      

      Set @nIQCQty =0
      Set @cReason = ''
      Set @cToID = ''
      Set @cToLoc = ''

      SELECT @nIQCQty      = ISNULL(ToQty, 0), 
             @cReason      = ISNULL(Reason, ''),
             @cToID        = ISNULL(ToID, ''),
             @cToLoc       = ISNULL(ToLoc, '') 
      FROM dbo.InventoryQCDetail WITH (NOLOCK)
      WHERE QC_Key = @cQCKey
      AND QCLineNo = @cQCLine
      AND SKU      = @cSKU
      AND FROMLoc  = @cFROMLoc
      AND FROMID   = @cFROMID

         SET @cConfigValue = ''
         SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
         IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
         BEGIN
            Set @cToID = @cFromID
         END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit 
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPIQC_QTY = 0
         SET @nMIQC_QTY = @nIQCQty

         SET @nPACT_QTY = 0
         SET @nMACT_QTY = @nACT_QTY

      END
      ELSE
      BEGIN
         SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

         SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
      SET @cOutField04 = @nPUOM_Div
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc
      SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
      SET @cOutField08 = @nMIQC_QTY 
      SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
      SET @cOutField10 = @nMACT_QTY  
   
      -- Prepare prev screen var
      SET @cActToLoc = ''

      SET @cOutField11 = @cReason2
      SET @cOutField12 = @cToID    
      SET @cACTToID    = ''
      SET @cOutField13 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 10. Scn = 1739. 
   IQC to different location 
   Proceed?   
   1=YES   2=NO
   OPTION:   (field01 - input)
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
       SET @cOption = ISNULL(@cInField01, '')
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 64073
         SET @cErrMsg = rdt.rdtgetmessage( 64073, @cLangCode, 'DSP') --Option needed 
         GOTO Step_10_Fail
      END
     
      IF Not ( @cOption = '1' OR @cOption = '2' )
      BEGIN
         SET @nErrNo = 64074  
         SET @cErrMsg = rdt.rdtgetmessage( 64074, @cLangCode, 'DSP') --Invalid Option         
         GOTO Step_10_Fail  
      END

      IF @cOption = '1'
      BEGIN
         --SET @cCallSource = '2'
         --GOTO Check_Finalize 
         --Check_Finalize2:     

         -- Get WMS 'FinalizeIQC' Configuration
         SET @cFinalizeFlag = 0

         IF EXISTS( SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey  
                     AND ConfigKey = 'FinalizeIQC' AND sValue = '1' )
         BEGIN
            SET    @cFinalizeFlag = '1'
         END   
         ELSE
         BEGIN
            SET    @cFinalizeFlag = '0'
         END

         IF @cFinalizeFlag = '1'
         BEGIN
            -- Only ConfigKey = 'NotFinalizeInventoryQCDetail' AND sValue = '0' , then will finalize

            IF EXISTS ( SELECT 1 FROM RDT.StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey  
                     AND ConfigKey = 'NotFinalizeInventoryQCDetail' AND sValue = '0' )
            BEGIN
               SET @cFinalizeFlag = '0'
            END
         END

         --IF @cFinalizeFlag = '1'
         --BEGIN
         --   Update dbo.InventoryQCDetail WITH (ROWLOCK)
         --   SET QTY    = @nACT_QTY,
         --       TOQty  = @nACT_QTY, 
         --       Reason = @cReason2,
         --       ToID   = @cToID2,
         --       ToLoc  = @cActToLoc,
         --       FinalizeFlag = 'Y'
         --   WHERE QC_KEY        = @cQCKey
         --      AND QCLineNo     = @cQCLine
         --      AND FinalizeFlag = 'N'
         --   IF @@ROWCOUNT = 0
         --   BEGIN
         --      SET @nErrNo = 64078
         --      SET @cErrMsg = rdt.rdtgetmessage( 64078, @cLangCode, 'DSP') --'Upd QCDtl Fail'
         --      GOTO Step_10_Fail
         --   END

         --END
         --ELSE
         --BEGIN
         --   Update dbo.InventoryQCDetail WITH (ROWLOCK)
         --   SET QTY    = @nACT_QTY,
         --       TOQty  = @nACT_QTY, 
         --       Reason = @cReason2,
         --       ToID   = @cToID2,
         --       ToLoc  = @cActToLoc,
         --       TrafficCop = NULL  
         --   WHERE QC_KEY        = @cQCKey
         --      AND QCLineNo     = @cQCLine
         --      AND FinalizeFlag = 'N'
         --   IF @@ROWCOUNT = 0
         --   BEGIN
         --      SET @nErrNo = 64079
         --      SET @cErrMsg = rdt.rdtgetmessage( 64079, @cLangCode, 'DSP') --'Upd QCDtl Fail'
         --      GOTO Step_10_Fail
         --   END
         --END
         
         --(cc01)
         Update dbo.InventoryQCDetail WITH (ROWLOCK) SET
            QTY    = @nACT_QTY,
            TOQty  = @nACT_QTY, 
            Reason = @cReason2,
            ToID   = @cToID2,
            ToLoc  = @cActToLoc,
            TrafficCop = NULL  
         WHERE QC_KEY        = @cQCKey
            AND QCLineNo     = @cQCLine
            AND FinalizeFlag = 'N'
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 64078
            SET @cErrMsg = rdt.rdtgetmessage( 64077, @cLangCode, 'DSP') --'Upd QCDtl Fail'
            GOTO Step_10_Fail
         END
         
         IF @cFinalizeFlag = '1'
         BEGIN
         	EXEC ispFinalizeIQC
         	   @c_qc_key     = @cQCKey,                                                            
               @b_Success    = @bSuccess  OUTPUT,        
               @n_err        = @nErrNo    OUTPUT,        
               @c_errmsg     = @cErrMsg   OUTPUT,
               @c_QC_LineNo  = @cQCLine
               
            IF @nErrNo <> 0  
            BEGIN
               SET @nErrNo = 64079
               SET @cErrMsg = rdt.rdtgetmessage( 64077, @cLangCode, 'DSP') --'Upd QCDtl Fail'
               GOTO Step_10_Fail
            END
         END
         
         -- Prep next screen var
         
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      IF @cOption = '2'
      BEGIN
         --SET @cCallSource = '11'
         --GOTO Show_SKUUpdate 
         --Show_SKUUpdate11:      
         Set @nIQCQty =0
         Set @cReason = ''
         Set @cToID = ''
         Set @cToLoc = ''

         SELECT @nIQCQty      = ISNULL(ToQty, 0), 
                @cReason      = ISNULL(Reason, ''),
                @cToID        = ISNULL(ToID, ''),
                @cToLoc       = ISNULL(ToLoc, '') 
         FROM dbo.InventoryQCDetail WITH (NOLOCK)
         WHERE QC_Key = @cQCKey
         AND QCLineNo = @cQCLine
         AND SKU      = @cSKU
         AND FROMLoc  = @cFROMLoc
         AND FROMID   = @cFROMID

            SET @cConfigValue = ''
            SET @cConfigValue = rdt.RDTGetConfig( 0, 'IQCNotCopyFromIDWhenToIDBlank', @cStorerKey)  
   
            IF ISNULL(@cConfigValue, '') <> '1' AND ISNULL(@cToID , '') = ''
            BEGIN
               Set @cToID = @cFromID
            END

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit 
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPIQC_QTY = 0
            SET @nMIQC_QTY = @nIQCQty

            SET @nPACT_QTY = 0
            SET @nMACT_QTY = @nACT_QTY

         END
         ELSE
         BEGIN
            SET @nPIQC_QTY = @nIQCQty / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMIQC_QTY = @nIQCQty % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPACT_QTY = @nACT_QTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMACT_QTY = @nACT_QTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)   -- SKU descr 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 40)   -- SKU descr 2
         SET @cOutField04 = @nPUOM_Div
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField06 = @cMUOM_Desc
         SET @cOutField07 = CASE WHEN @nPIQC_QTY = 0 THEN '' ELSE Cast( @nPIQC_QTY as NVARCHAR(5)) END
         SET @cOutField08 = @nMIQC_QTY 
         SET @cOutField09 = CASE WHEN @nPACT_QTY = 0 THEN '' ELSE Cast( @nPACT_QTY as NVARCHAR(5)) END
         SET @cOutField10 = @nMACT_QTY  
         -- Prepare prev screen var

         SET @cOutField11 = @cReason2
         SET @cOutField12 = @cToID2
         SET @cOutField13 = @cToLoc
         SET @cActToLoc   = ''
         SET @cOutField14 = ''

         -- Back to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
       END
   END

   Step_10_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''  -- Option
   END
END
GOTO Quit

/********************************************************************************
Step 11. Scn = 1740. 

Message screen
   IQC successfully
   Press ENTER ir ESC to continue
********************************************************************************/
Step_11:
BEGIN
   ---- If only 1 fromloc, goto Sku screen
   --IF EXISTS (SELECT 1 FROM dbo.InventoryQCDetail (NOLOCK) 
   --           WHERE QC_Key = @cQCKey 
   --           GROUP BY QC_Key 
   --           HAVING COUNT( DISTINCT FromLoc) = 1)
   --BEGIN
   --   SELECT TOP 1 
   --      @cFromLoc = FromLoc, 
   --      @cFromID = FromID  
   --   FROM dbo.InventoryQCDetail WITH (NOLOCK)
   --   WHERE QC_KEY = @cQCKey
   --   AND   FinalizeFlag = 'N' 
   --   ORDER BY 1
      
   --   IF ISNULL( @cFromID, '') = ''
   --   BEGIN
   --      -- Prep next screen var
   --      SET @cOutField01 = @cFromLOC
   --      SET @cOutField02 = @cFromID
   --      SET @cOutField03 = ''
      
   --      -- Go to Sku screen
   --      SET @nScn = @nScn - 7
   --      SET @nStep = @nStep - 7
   --   END
   --   ELSE
   --   BEGIN
   --      -- Prep next screen var
   --      SET @cOutField01 = @cFromLOC
   --      SET @cOutField02 = ''
      
   --      -- Go to iD screen
   --      SET @nScn = @nScn - 8
   --      SET @nStep = @nStep - 8
   --   END
         
   --   GOTO Quit
   --END
   --(cc01)
   IF EXISTS (SELECT 1 FROM dbo.InventoryQCDetail (NOLOCK) 
              WHERE QC_Key = @cQCKey 
              AND FromLoc = @cFromLOC
              AND FromID   = @cFromID 
              AND FinalizeFlag = 'N')
   BEGIN
   	 --Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''
      
      -- Go to Sku screen
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
      
      GOTO Quit
   END
   ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryQCDetail (NOLOCK) 
                    WHERE QC_Key = @cQCKey 
                    AND FromLoc = @cFromLOC
                    AND FinalizeFlag = 'N')
   BEGIN
   	-- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = ''
      
      -- Go to iD screen
      SET @nScn = @nScn - 8
      SET @nStep = @nStep - 8
      
      GOTO Quit
   END
   ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryQCDetail (NOLOCK) 
                  WHERE QC_Key = @cQCKey 
                  AND FinalizeFlag = 'N')
   BEGIN
   	-- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      
      -- Go to Loc screen
      SET @nScn = @nScn - 9
      SET @nStep = @nStep - 9
      
      GOTO Quit
   END
   	

   -- Go back to 1st screen
   SET @nScn  = 1730
   SET @nStep = 1
   
   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cFromLoc = ''
   SET @cFromID = ''
   SET @cQCLine = ''
   SET @cToID2 = ''
   SET @cActToID = ''
   SET @cActToLoc = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cFromLot = ''
   SET @cFromLOC = ''
   SET @cFromID = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = NULL
   SET @cPUOM_Desc = ''
   SET @cMUOM_Desc = ''
   SET @nPUOM_Div = ''
   SET @cReason2 = ''
   SET @nACT_QTY = ''
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      V_Qty      = @nACT_QTY,
      
      V_Integer1 = @nPUOM_Div, 

      V_SKU      = @cSKU, 
      V_SKUDescr = @cSKUDescr, 
      V_Lot      = @cFromLot, 
      V_Loc      = @cFromLOC, 
      V_ID       = @cFromID, 
      V_Lottable02 = @cLottable02, 
      V_Lottable03 = @cLottable03, 
      V_Lottable04 = @dLottable04, 
      V_UOM      = @cPUOM, 

      V_String1  = @cQCKey, 
      V_String2  = @cQCLine,
      V_String3  = @cReason2,
      V_String4  = @cToID2,
      V_String5  = @cActToLoc,
      V_String6  = @cPUOM_Desc, 
      V_String7  = @cMUOM_Desc, 
      V_String8  = @cDefaultQty,
      V_String9  = @cDefaultReason,
      V_String10 = @cMatchSuggestLoc,
         
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END


GO