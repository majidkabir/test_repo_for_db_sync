SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_MoveToID_Lottable07                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2021-08-01 1.0  yeekung  WMS-17527 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_MoveToID_Lottable07] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cChkFacility  NVARCHAR( 5),
   @nSKUCnt       INT,
   @b_success     INT,
   @n_err         INT,
   @c_errmsg      NVARCHAR( 20), 
   @cSQL          NVARCHAR(1000),
   @cSQLParam     NVARCHAR(1000)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,
   @nBeforeScn  INT,

   @cUserName   NVARCHAR(18),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cFromLOC    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cSKU        NVARCHAR( 20),
   @cSKUDescr   NVARCHAR( 60),
   @cExtendedValidateSP      NVARCHAR( 20), 

   @cPUOM       NVARCHAR( 1), -- Pref UOM
   @cPUOM_Desc  NVARCHAR( 5), -- Pref UOM desc
   @cMUOM_Desc  NVARCHAR( 5), -- Master UOM desc
   @nQTY_Avail  INT,      -- QTY avail in master UOM
   @nPQTY_Avail INT,      -- QTY avail in pref UOM
   @nMQTY_Avail INT,      -- Remaining QTY in master UOM
   @nQTY        INT,      -- QTY to move, in master UOM
   @nPQTY       INT,      -- QTY to move, in pref UOM
   @nMQTY       INT,      -- Remining QTY to move, in master UOM
   @nPUOM_Div   INT,
   @nIDQTY      INT, 

   @cToLOC            NVARCHAR( 10),
   @cToID             NVARCHAR( 18),
   @cDecodeLabelNo    NVARCHAR( 20),
   @cDisableQTYField  NVARCHAR( 1),
   @cDefaultToLOC     NVARCHAR( 10),
   @cExtendedUpdateSP NVARCHAR( 20),
   @cDecodeSP         NVARCHAR( 20), 
   @cSKUValidated     NVARCHAR( 1), -- (james01)
   @cDefaultSKU2Move     NVARCHAR( 20),  
   @cDefaultAvlQty2Move  NVARCHAR( 1),
   @cMoveAllSKUWithinSameLottable NVARCHAR(1),
   @cLottableCode     NVARCHAR( 30),  
   @nMorePage         INT,  
   @cLottable01       NVARCHAR( 18),  
   @cLottable02       NVARCHAR( 18),  
   @cLottable03       NVARCHAR( 18),  
   @dLottable04       DATETIME,  
   @dLottable05       DATETIME,  
   @cLottable06       NVARCHAR( 30),  
   @cLottable07       NVARCHAR( 30),  
   @cLottable08       NVARCHAR( 30),  
   @cLottable09       NVARCHAR( 30),  
   @cLottable10       NVARCHAR( 30),  
   @cLottable11       NVARCHAR( 30),  
   @cLottable12       NVARCHAR( 30),  
   @dLottable13       DATETIME,  
   @dLottable14       DATETIME,  
   @dLottable15       DATETIME, 
   @cWhere            NVARCHAR( MAX), 
   @cPQTY    NVARCHAR( 5),
   @cMQTY    NVARCHAR( 5),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cUserName   = UserName,
   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cFromLOC    = V_String1,
   @cFromID     = V_String2,
   @cSKU        = V_String3,
   @cSKUDescr   = V_SKUDescr,

   @cPUOM       = V_UOM,     -- Pref UOM
   @cPUOM_Desc  = V_String4, -- Pref UOM desc
   @cMUOM_Desc  = V_String5, -- Master UOM desc
   @nPQTY       = V_PQTY,
   @nMQTY       = V_MQTY,
   @nPUOM_Div   = V_PUOM_Div,

   @cLottable01       = V_Lottable01,  
   @cLottable02       = V_Lottable02,  
   @cLottable03       = V_Lottable03,  
   @dLottable04       = V_Lottable04,  
   @dLottable05       = V_Lottable05,  
   @cLottable06       = V_Lottable06,  
   @cLottable07       = V_Lottable07,  
   @cLottable08       = V_Lottable08,  
   @cLottable09       = V_Lottable09,  
   @cLottable10       = V_Lottable10,  
   @cLottable11       = V_Lottable11,  
   @cLottable12       = V_Lottable12,  
   @dLottable13       = V_Lottable13,  
   @dLottable14       = V_Lottable14,  
   @dLottable15       = V_Lottable15,
   
   @nQTY_Avail  = V_Integer1,
   @nPQTY_Avail = V_Integer2,
   @nMQTY_Avail = V_Integer3,
   @nQTY        = V_Integer4,
   @nIDQTY      = V_Integer5,
   @nBeforeScn  = V_integer6, 

   @cToLOC            = V_String14,
   @cToID             = V_String15,
   @cDecodeLabelNo    = V_String16,
   @cDisableQTYField  = V_String17,
   @cDefaultToLOC     = V_String18,
   @cExtendedUpdateSP = V_String19,
   @cDecodeSP         = V_String20,
   @cSKUValidated     = V_String21,
   @cLottableCode     = V_String22,
   @cExtendedValidateSP = V_String23, 
   @cDefaultAvlQty2Move = V_String24, 
   @cDefaultSKU2Move    = V_String25,  
   @cMoveAllSKUWithinSameLottable = V_String26, 

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

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 648 -- Move to ID
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move to ID
   IF @nStep = 1 GOTO Step_1   -- Scn = 5961. ToID
   IF @nStep = 2 GOTO Step_2   -- Scn = 5962. FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 5963. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 3990. Dynamice Lottable
   IF @nStep = 5 GOTO Step_5   -- Scn = 5964. QTY
   IF @nStep = 6 GOTO Step_6   -- Scn = 5965. Message. Close To ID?
   IF @nStep = 7 GOTO Step_7   -- Scn = 5966. ToLOC

END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 513. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get storer config
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''  
   SET @cMoveAllSKUWithinSameLottable = rdt.RDTGetConfig( @nFunc, 'MoveAllSKUWithinSameLottable', @cStorerKey)    
    
   
   SET @cDefaultSKU2Move = rdt.RDTGetConfig( @nFunc, 'DefaultSKU2Move', @cStorerKey)    
   IF @cDefaultSKU2Move = '0'    
      SET @cDefaultSKU2Move = ''    
    
   SET @cDefaultAvlQty2Move = rdt.RDTGetConfig( @nFunc, 'DefaultAvlQty2Move', @cStorerKey)    
   IF @cDefaultAvlQty2Move = '0'    
      SET @cDefaultAvlQty2Move = ''     
      
    -- EventLog sign In
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Enable all fields
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

   -- Prep next screen var
   SET @cOutField01 = '' -- ToID

   -- Set the entry point
   SET @nScn = 5960
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3390. ToID
   ToID    (field11, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField01

      -- Check blank
      IF @cToID = ''
      BEGIN
         SET @nErrNo = 173401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID needed
         GOTO Step_1_Fail
      END

      -- Check ToID in use
      IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ToID = @cToID AND AddWho <> @cUserName)
      BEGIN
         SET @nErrNo = 173402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID in-used
         GOTO Step_1_Fail
      END

      -- Check ToID with QTY
      IF EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND LLI.ID = @cToID
            AND LLI.QTY-LLI.QTYPicked > 0)
      BEGIN
         SET @nErrNo = 173403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To ID with QTY
         GOTO Step_1_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' -- FromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- EventLog - Sign Out
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField01 = '' -- ToID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3391. FromLOC
   FromLOC (field01, input)
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
         SET @nErrNo = 173404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
         GOTO Step_2_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 173405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 173406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_2_Fail
      END

      IF @cExtendedValidateSP <> ''    
      BEGIN    
         SET @nErrNo = 0    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +         
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +     
            ' @cFromLOC, @cFromID, @cSKU, @nQty, @cToID, @cToLOC, @cLottableCode, ' +     
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +     
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
    
         SET @cSQLParam =        
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +    
            '@cFacility       NVARCHAR( 5),  ' +    
            '@cStorerkey      NVARCHAR( 15), ' +    
            '@cFromLOC        NVARCHAR( 10), ' +    
            '@cFromID         NVARCHAR( 18), ' +    
            '@cSKU            NVARCHAR( 20), ' +    
            '@nQty            INT, '           +    
            '@cToID           NVARCHAR( 18), ' +    
            '@cToLoc          NVARCHAR( 10), ' +    
            '@cLottableCode   NVARCHAR( 30), ' +    
            '@cLottable01     NVARCHAR( 18), ' +     
            '@cLottable02     NVARCHAR( 18), ' +     
            '@cLottable03     NVARCHAR( 18), ' +     
            '@dLottable04     DATETIME,      ' +     
            '@dLottable05     DATETIME,      ' +     
            '@cLottable06     NVARCHAR( 30), ' +     
            '@cLottable07     NVARCHAR( 30), ' +     
            '@cLottable08     NVARCHAR( 30), ' +     
            '@cLottable09     NVARCHAR( 30), ' +     
            '@cLottable10     NVARCHAR( 30), ' +     
            '@cLottable11     NVARCHAR( 30), ' +     
            '@cLottable12     NVARCHAR( 30), ' +     
            '@dLottable13     DATETIME,      ' +     
            '@dLottable14     DATETIME,      ' +     
            '@dLottable15     DATETIME,      ' +     
            '@nErrNo          INT           OUTPUT,  ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '     
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,     
            @cFromLOC, @cFromID, @cSKU, @nMQTY, @cToID, @cToLOC, @cLottableCode,     
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,     
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,     
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,     
            @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO quit    
      END   

      -- Prep next screen var
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cPUOM_Desc = ''
      SET @cMUOM_Desc = ''
      SET @nIDQTY = 0
      
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKU desc 1
      SET @cOutField05 = '' -- SKU desc 2
      SET @cOutField06 = '' -- PUOM_Desc
      SET @cOutField07 = '' -- PQTY_Avail
      SET @cOutField08 = '' -- PQTY
      SET @cOutField09 = '' -- MUOM_Desc
      SET @cOutField10 = '' -- MQTY_Avail
      SET @cOutField11 = '' -- MQTY
      SET @cOutField12 = '' -- PUOM_DIV
      SET @cOutField13 = '' -- IDQTY

      -- Disable and default QTY field
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr08 = 'O' -- PQTY
         SET @cFieldAttr11 = 'O' -- MQTY
      END
      IF @cPUOM = '6'
         SET @cFieldAttr08 = 'O' -- PQTY      

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU

      SET @cSKUValidated = '0'   -- (james01)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cToID = ''
      SET @cOutField01 = '' --ToID

      -- Go to next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField02 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 1032. SKU screen
   FromLOC (field01)
   SKU/UPC (field02, input)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)
      DECLARE @cUPC     NVARCHAR( 30)

      -- Screen mapping
      SET @cBarcode = @cInField02
      SET @cUPC = LEFT( @cInField02, 30)


      IF @cBarcode = ''  
      BEGIN  
         -- Check if close ToID  
         IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ToID = @cToID)  
         BEGIN  
            -- Go to close ToID screen  
            SET @cOutField01 = '' --Option  
  
            SET @cFieldAttr08 = '' -- PQTY  
            SET @cFieldAttr11 = '' -- MQTY  
  
            SET @nScn = @nScn + 2 
            SET @nStep = @nStep + 3  
            GOTO Quit  
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 173407  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed  
            GOTO Step_3_Fail  
         END  
      END

      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUPC    = @cUPC     OUTPUT, 
               @nQTY    = @cMQTY    OUTPUT, 
               @nErrNo  = @nErrNo   OUTPUT, 
               @cErrMsg = @cErrMsg  OUTPUT,
               @cType = 'UPC'
            -- IF @nErrNo <> 0
            --    GOTO Step_3_Fail
            SET @cInField11 = @cMQty  
         END
         ELSE -- (ChewKP01) 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  '  @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cFromLoc, @cToID, @cBarcode, @cUPC OUTPUT, @nQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '  @nMobile      INT                     '+
                  ' ,@nFunc        INT                     '+
                  ' ,@nStep        INT                     '+
                  ' ,@nInputKey    INT                     '+
                  ' ,@cLangCode    NVARCHAR( 3)            '+
                  ' ,@cStorerKey   NVARCHAR( 15)           '+
                  ' ,@cFacility    NVARCHAR( 5)            '+
                  ' ,@cFromLoc     NVARCHAR( 10)           '+
                  ' ,@cToID        NVARCHAR( 18)           '+
                  ' ,@cBarcode     NVARCHAR( 20)           '+
                  ' ,@cUPC         NVARCHAR( 20) OUTPUT    '+
                  ' ,@nQTY         INT           OUTPUT    '+
                  ' ,@nErrNo       INT           OUTPUT    '+
                  ' ,@cErrMsg      NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cFromLoc, @cToID, @cBarcode, @cUPC OUTPUT, @cMQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

               IF @nErrNo <> 0
               BEGIN
                  GOTO Step_3_Fail 
               END

               IF ISNULL( @cMQty, 0) <> 0
                  SET @cInField11 = @cMQty 
            END
         END

      END

      -- Get SKU count
      EXEC [RDT].[rdt_GETSKUCNT]
            @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 173408
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_3_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 173409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Step_3_Fail
      END

      -- Get SKU code
      EXEC [RDT].[rdt_GETSKU]
            @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT
      IF @n_Err <> 0
         GOTO Step_3_Fail
      
      SET @cSKU = @cUPC

      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR,
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
            END AS INT),  
         @cLottableCode = LottableCode  
      FROM dbo.SKU S WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Get QTY avail
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND SKU = @cSKU

      -- Validate no QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 173410
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move
         GOTO Step_3_Fail
      END

      SELECT   
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,  
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',  
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL     
  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,   
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,  
         @nMorePage   OUTPUT,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT,  
         '',  
         @nFunc  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      IF @nMorePage = 1 -- Yes  
      BEGIN  
         -- Go to dynamic lottable screen 
         SET @nBeforeScn = @nScn 
         SET @nScn = 3990  
         SET @nStep = @nStep+1  
      END  
      ELSE
      BEGIN
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nMQTY_Avail = @nQTY_Avail
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prep next screen var
         SET @cOutField02 = @cSKU
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField06 = '' -- @cPUOM_Desc
            SET @cOutField07 = '' -- @nPQTY_Avail
            SET @cOutField08 = '' -- @nPQTY
            SET @cFieldAttr08 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField06 = @cPUOM_Desc
            SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
            SET @cOutField08 = '' -- @nPQTY
         END
         SET @cOutField09 = @cMUOM_Desc
         SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
         SET @cOutField11 = CASE WHEN @cDefaultAvlQty2Move = '' THEN '' ELSE @nQTY_Avail END -- @nMQTY_Move  
         
         -- Go to next screen  
         SET @nScn = @nScn+2  
         SET @nStep = @nStep+2  
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' --FromLOC

      SET @cFieldAttr08 = '' -- PQTY
      SET @cFieldAttr11 = '' -- MQTY

      -- Go to FromLOC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField03 = CASE WHEN @cDefaultSKU2Move = '' THEN '' ELSE @cDefaultSKU2Move END -- SKU 
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
   END
END
GOTO Quit

/********************************************************************************  
Step 4. scn = 5193. Lottables  
   SKU             (field01)  
   SKUDesc         (field02)  
   SKUDesc         (field03)  
   LottableLabel01 (field04)  
   Lottable01      (field05)  
   LottableLabel02 (field06)  
   Lottable02      (field07)  
   LottableLabel03 (field08)  
   Lottable03      (field09)  
   LottableLabel04 (field10)  
   Lottable04      (field11)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1,   
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,  
         @nMorePage   OUTPUT,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT,  
         '',  
         @nFunc  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      IF @nMorePage = 1 -- Yes  
         GOTO Quit  
  
      -- Get lottable filter  
      EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 5, 'LA',   
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
         @cWhere   OUTPUT,  
         @nErrNo   OUTPUT,  
         @cErrMsg  OUTPUT  
  
         -- Get SKU QTY  
         SET @nQTY_Avail = 0  

         IF @cMoveAllSKUWithinSameLottable = '1'    
            SET @cSQL =     
            ' SELECT @nQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) ' +    
            ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +    
            ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +    
            ' WHERE LLI.StorerKey = @cStorerKey ' +    
            ' AND   LLI.LOC = @cFromLOC ' +    
            ' AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +    
            ' AND   LLI.ID = CASE WHEN ISNULL( @cFromID, '''') = '''' THEN LLI.ID ELSE @cFromID END ' +    
            CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END     
            ELSE    
               SET @cSQL =     
               ' SELECT TOP 1 ' +        
               '    @cSKU = LLI.SKU,' +    
               '    @nQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) ' +    
               ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +    
               ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +    
               ' WHERE LLI.StorerKey = @cStorerKey ' +    
               ' AND   LLI.SKU = @cSKU ' +    
               ' AND   LLI.LOC = @cFromLOC ' +    
               ' AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +       
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END +     
               ' GROUP BY LLI.ID, LLI.SKU ' +     
               ' ORDER BY LLI.ID, LLI.SKU '  
  
      SET @cSQLParam =   
         ' @cStorerKey  NVARCHAR( 15), ' +   
         ' @cFromLOC    NVARCHAR( 10), ' +   
         ' @cFromID     NVARCHAR( 18), ' +   
         ' @cSKU        NVARCHAR( 20), ' +   
         ' @cLottable01 NVARCHAR( 18), ' +   
         ' @cLottable02 NVARCHAR( 18), ' +   
         ' @cLottable03 NVARCHAR( 18), ' +   
         ' @dLottable04 DATETIME,      ' +   
         ' @dLottable05 DATETIME,      ' +   
         ' @cLottable06 NVARCHAR( 30), ' +   
         ' @cLottable07 NVARCHAR( 30), ' +   
         ' @cLottable08 NVARCHAR( 30), ' +   
         ' @cLottable09 NVARCHAR( 30), ' +   
         ' @cLottable10 NVARCHAR( 30), ' +   
         ' @cLottable11 NVARCHAR( 30), ' +   
         ' @cLottable12 NVARCHAR( 30), ' +   
         ' @dLottable13 DATETIME,      ' +   
         ' @dLottable14 DATETIME,      ' +   
         ' @dLottable15 DATETIME,      ' +   
         ' @cToID         NVARCHAR( 18) OUTPUT, ' +   
         ' @nQTY_Avail  INT           OUTPUT '  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU,   
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
         @cToID OUTPUT,  @nQTY_Avail OUTPUT  
  
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL  
      BEGIN  
         SET @nErrNo = 173411  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'  
         GOTO Step_4_Fail  
      END  

      -- Enable field  
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr10 = ''  
  
      -- Convert to prefer UOM QTY  
      IF @cPUOM = '6' OR -- When preferred UOM = master unit  
         @nPUOM_Div = 0 -- UOM not setup  
      BEGIN  
         SET @cPUOM_Desc = ''  
         SET @nPQTY_Avail = 0  
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007  
      END  
      ELSE  
      BEGIN  
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM  
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit  
      END  
  
      SET @cOutField01 = @cToID  
      --SET @cOutField02 = @cLottable01  
      --SET @cOutField03 = @cLottable02  
      --SET @cOutField04 = @cLottable03  
      --SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)  
  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
  
      IF @cPUOM_Desc = ''  
      BEGIN  
         SET @cOutField06 = '' -- @cPUOM_Desc  
         SET @cOutField07 = '' -- @nPQTY_Avail  
         SET @cOutField08 = '' -- @nPQTY_Move  
         SET @cFieldAttr08 = 'O'  
      END  
      ELSE  
      BEGIN  
         SET @cOutField06 = @cPUOM_Desc  
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))  
         SET @cOutField08 = '' -- @nPQTY_Move  
      END  
      SET @cOutField09 = @cMUOM_Desc  
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cDefaultAvlQty2Move = '' THEN '' ELSE @nQTY_Avail END -- @nMQTY_Move    

      IF @cDisableQTYField = '1'  
      BEGIN  
         SET @cPQTY = ''  
         SET @cMQTY = '1'  
           
         -- Retain the key-in value  
         SET @cInField08 = @cPQTY -- Pref QTY  
         SET @cInField11 = @cMQTY -- Master QTY   
      END  

      SET @nScn = @nBeforeScn+1
      SET @nStep = @nStep+1  
  
      GOTO Quit  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      SET @cSKU = ''  
      SET @cSKUDescr = ''  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = @cFromID  
      SET @cOutField04 = '' -- SKU desc 1  
      SET @cOutField05 = '' -- SKU desc 2  
  
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
  
      -- Go back to prev screen  
      SET @nScn = @nBeforeScn
      SET @nStep = @nStep-1 
   END  
   GOTO Quit  
  
   Step_4_Fail:  
END  
GOTO Quit  

/********************************************************************************  
Step 5. Scn = 5194. QTY screen  
   ID              (field01)  
   Lottable01      (field02)  
   Lottable02      (field03)  
   Lottable03      (field04)  
   Lottable04      (field05)  
   UOM             (field08, field11)  
   QTY AVL         (field09, field12)  
   QTY MV          (field10, field13, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  

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
  
      SET @cPQTY = IsNULL( @cInField08, '')  
      SET @cMQTY = IsNULL( @cInField11, '')  

      -- Retain the key-in value  
      SET @cOutField08 = @cInField08 -- Pref QTY  
      SET @cOutField11 = @cInField11 -- Master QTY 

            -- Blank to iterate lottables    
      IF @cPQTY = '' AND @cMQTY = '' AND @cMoveAllSKUWithinSameLottable <> '1'    
      BEGIN    
         DECLARE @cNextID NVARCHAR( 18)    
         DECLARE @nNextQTY_Avail INT    
    
         -- Get lottable filter    
         EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 5, 'LA',     
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
            @cWhere   OUTPUT,    
            @nErrNo   OUTPUT,    
            @cErrMsg  OUTPUT    
    
         SET @cSQL = ''    
    
         -- Get SKU QTY    
         SET @cSQL =     
         ' SELECT TOP 1 ' +    
         '    @cNextSKU = LLI.SKU, ' +    
         '    @nNextQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) ' +    
         ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +    
         ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +    
         ' WHERE LLI.StorerKey = @cStorerKey ' +    
         ' AND   LLI.LOC = @cFromLOC ' +    
         ' AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +    
         ' AND   LLI.ID = CASE WHEN ISNULL( @cFromID, '''') = '''' THEN LLI.ID ELSE @cFromID END ' +    
         ' AND  (LLI.ID + LLI.SKU) > (@cID + @cSKU ) ' +    
         CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END +     
         ' GROUP BY LLI.ID, LLI.SKU ' +    
         ' ORDER BY LLI.ID, LLI.SKU '    
    
      SET @cSQLParam =     
         ' @cStorerKey  NVARCHAR( 15), ' +     
         ' @cFromLOC    NVARCHAR( 10), ' +     
         ' @cFromID     NVARCHAR( 18), ' +     
         ' @cSKU        NVARCHAR( 20), ' +     
         ' @cID         NVARCHAR( 18), ' +     
         ' @cLottable01 NVARCHAR( 18), ' +     
         ' @cLottable02 NVARCHAR( 18), ' +     
         ' @cLottable03 NVARCHAR( 18), ' +     
         ' @dLottable04 DATETIME,      ' +     
         ' @dLottable05 DATETIME,      ' +     
         ' @cLottable06 NVARCHAR( 30), ' +     
         ' @cLottable07 NVARCHAR( 30), ' +     
         ' @cLottable08 NVARCHAR( 30), ' +     
         ' @cLottable09 NVARCHAR( 30), ' +     
         ' @cLottable10 NVARCHAR( 30), ' +     
         ' @cLottable11 NVARCHAR( 30), ' +     
         ' @cLottable12 NVARCHAR( 30), ' +     
         ' @dLottable13 DATETIME,      ' +     
         ' @dLottable14 DATETIME,      ' +     
         ' @dLottable15 DATETIME,      ' +         
         ' @cNextSKU    NVARCHAR( 20) OUTPUT, ' +     
         ' @nNextQTY_Avail  INT       OUTPUT '    
    
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU, @cToID,    
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
         @cSKU OUTPUT, @nNextQTY_Avail OUTPUT    
    
         -- Validate if any result    
         IF IsNULL( @nNextQTY_Avail, 0) = 0    
         BEGIN    
            SET @nErrNo = 173412    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'    
            GOTO quit    
         END    
    
         SET @nQTY_Avail = @nNextQTY_Avail    
    
         -- Convert to prefer UOM QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0 -- UOM not setup    
         BEGIN    
            SET @cPUOM_Desc = ''    
            SET @nPQTY_Avail = 0    
            SET @nPQTY  = 0    
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007    
         END    
         ELSE    
         BEGIN    
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM    
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit    
         END    
    
         -- Prepare next screen var    
         SET @nPQTY = 0    
         SET @nMQTY = 0    
         SET @cOutField01 = @cToID    
    
         SET @cOutField02 = @cSKU    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)    
             
         IF @cPUOM_Desc = ''    
         BEGIN    
            SET @cOutField08 = '' -- @cPUOM_Desc    
            SET @cOutField09 = '' -- @nPQTY_Avail    
            SET @cOutField10 = '' -- @nPQTY_Move    
            SET @cFieldAttr10 = 'O'    
         END    
         ELSE    
         BEGIN    
            SET @cOutField08 = @cPUOM_Desc    
            SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))    
            SET @cOutField10 = '' -- @nPQTY_Move    
         END    
         SET @cOutField11 = @cMUOM_Desc    
         SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))    
         SET @cOutField13 = CASE WHEN @cDefaultAvlQty2Move = '' THEN '' ELSE @nQTY_Avail END -- @nMQTY_Move    
    
         GOTO Quit    
      END    
      -- Validate PQTY  
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero  
      BEGIN
         IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0  
         BEGIN  
            SET @nErrNo = 173413  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY  
            GOTO Step_5_Fail  
         END  
      END
  
      -- Validate MQTY  
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero  
      BEGIN
         IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0  
         BEGIN  
            SET @nErrNo = 173414  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
            EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY  
            GOTO Step_5_Fail  
         END  
      END

      -- Calc total QTY in master UOM  
      SET @nPQTY = CAST( @cPQTY AS INT)  
      SET @nMQTY = CAST( @cMQTY AS INT)  
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM  
      SET @nQTY = @nQTY + @nMQTY  

      -- Validate QTY to move more than QTY avail  
      IF @nQTY > @nQTY_Avail  
      BEGIN  
         SET @nErrNo = 173415  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAVL NotEnuf  
         GOTO Quit  
      END 

      IF @cExtendedValidateSP <> ''    
      BEGIN    
         SET @nErrNo = 0    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +         
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +     
            ' @cFromLOC, @cFromID, @cSKU, @nQty, @cToID, @cToLOC, @cLottableCode, ' +     
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +     
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
    
         SET @cSQLParam =        
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +    
            '@cFacility       NVARCHAR( 5),  ' +    
            '@cStorerkey      NVARCHAR( 15), ' +    
            '@cFromLOC        NVARCHAR( 10), ' +    
            '@cFromID         NVARCHAR( 18), ' +    
            '@cSKU            NVARCHAR( 20), ' +    
            '@nQty            INT, '           +    
            '@cToID           NVARCHAR( 18), ' +    
            '@cToLoc          NVARCHAR( 10), ' +    
            '@cLottableCode   NVARCHAR( 30), ' +    
            '@cLottable01     NVARCHAR( 18), ' +     
            '@cLottable02     NVARCHAR( 18), ' +     
            '@cLottable03     NVARCHAR( 18), ' +     
            '@dLottable04     DATETIME,      ' +     
            '@dLottable05     DATETIME,      ' +     
            '@cLottable06     NVARCHAR( 30), ' +     
            '@cLottable07     NVARCHAR( 30), ' +     
            '@cLottable08     NVARCHAR( 30), ' +     
            '@cLottable09     NVARCHAR( 30), ' +     
            '@cLottable10     NVARCHAR( 30), ' +     
            '@cLottable11     NVARCHAR( 30), ' +     
            '@cLottable12     NVARCHAR( 30), ' +     
            '@dLottable13     DATETIME,      ' +     
            '@dLottable14     DATETIME,      ' +     
            '@dLottable15     DATETIME,      ' +     
            '@nErrNo          INT           OUTPUT,  ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '     
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,     
            @cFromLOC, @cFromID, @cSKU, @nMQTY, @cToID, @cToLOC, @cLottableCode,     
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,     
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,     
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,     
            @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO quit    
      END    

      -- Confirm  
      EXEC rdt.rdt_MoveToID_Confirm  
         @nMobile     = @nMobile,  
         @nFunc       = @nFunc,  
         @cLangCode   = @cLangCode,  
         @cType       = 'Y', --Undo  
         @cStorerKey  = @cStorerKey,   
         @cToID       = @cToID,  
         @cFromLOC    = @cFromLOC,  
         @cSKU        = @cSKU,  
         @cUCC        = @cBarcode,  
         @nQTY        = @nQTY,   
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Step_5_Fail

      -- Get ID QTY  
      SELECT @nIDQTY = ISNULL( SUM( QTY), 0)   
      FROM rdt.rdtMoveToIDLog WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND ToID = @cToID  
  
      -- Update QTY AVL  
      SET @nPQTY_Avail = @nPQTY_Avail - @nPQTY  
      SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY

      -- Prep ToID screen var  
      SET @cOutField01 = @cFromLOC  
      SET @cOutField02 = ''  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
  
      -- Go to ToID screen  
      SET @nScn = @nScn-1 
      SET @nStep = @nStep-2
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Unconfirm  
      EXEC rdt.rdt_MoveToID_Confirm  
         @nMobile     = @nMobile,  
         @nFunc       = @nFunc,  
         @cLangCode   = @cLangCode,  
         @cType       = 'N', --Undo  
         @cStorerKey  = @cStorerKey,   
         @cToID       = @cToID,  
         @cFromLOC    = '',  
         @cSKU        = '',   
         @cUCC        = '',  
         @nQTY        = 0,   
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Step_5_Fail  

      SELECT   
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,  
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',  
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL     
  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,   
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,  
         @nMorePage   OUTPUT,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT,  
         '',  
         @nFunc  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      IF @nMorePage = 1 -- Yes  
      BEGIN  
         -- Go to dynamic lottable screen  
         SET @nScn = 3990  
         SET @nScn=@nBeforeScn
         SET @nStep = @nStep-1  
      END  
      ELSE  
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1  
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2  
  
         -- Go to QTY screen  
         SET @nScn = @nScn-1  
         SET @nStep = @nStep-2  
      END  
   END  
   GOTO Quit  
  
   Step_5_Fail:  
      SET @cFieldAttr10 = ''  
  
      IF @cPUOM_Desc = ''  
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot  
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition  
         -- Disable pref QTY field  
         SET @cFieldAttr10 = 'O'  
  
END  
GOTO Quit  


/********************************************************************************
Step 6. scn = 1038. Close To ID?
   1=YES
   2=NO
   OPTION (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 173416
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_6_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 173417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Go to ToLOC screen
         SET @cToLOC = ''
         SET @cOutField01 = @cDefaultToLOC
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN
         -- Go to FromLOC screen
         SET @cOutField01 = @cToID
         SET @cOutField02 = '' -- FromLOC
         
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 4
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cOutField08 = '' -- @nPQTY
         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField08 = CAST( @nPQTY AS NVARCHAR( 5))
      END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField11 = CASE WHEN @cDisableQTYField = '1' THEN '1' ELSE '' END -- @nMQTY
      SET @cOutField12 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField13 = CAST( @nIDQTY AS NVARCHAR( 5))

      -- Enable disable QTY
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr08 = 'O' -- PQTY
         SET @cFieldAttr11 = 'O' -- MQTY
      END

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 3
   END
   
   GOTO Quit

   Step_6_Fail:
      SET @cOutField01 = '' -- Option
END
GOTO Quit


/********************************************************************************
Step 7. Scn = 3394. ToLOC
   ToLOC   (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField01

      --SET @cToLoc = 'NI-PALLET'

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 173418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
         GOTO Step_5_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 173419
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_5_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
      BEGIN
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 173420
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Step_7_Fail
         END
      END

      IF @cExtendedValidateSP <> ''    
      BEGIN    
         SET @nErrNo = 0    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +         
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +     
            ' @cFromLOC, @cFromID, @cSKU, @nQty, @cToID, @cToLOC, @cLottableCode, ' +     
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +     
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
    
         SET @cSQLParam =        
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +    
            '@cFacility       NVARCHAR( 5),  ' +    
            '@cStorerkey      NVARCHAR( 15), ' +    
            '@cFromLOC        NVARCHAR( 10), ' +    
            '@cFromID         NVARCHAR( 18), ' +    
            '@cSKU            NVARCHAR( 20), ' +    
            '@nQty            INT, '           +    
            '@cToID           NVARCHAR( 18), ' +    
            '@cToLoc          NVARCHAR( 10), ' +    
            '@cLottableCode   NVARCHAR( 30), ' +    
            '@cLottable01     NVARCHAR( 18), ' +     
            '@cLottable02     NVARCHAR( 18), ' +     
            '@cLottable03     NVARCHAR( 18), ' +     
            '@dLottable04     DATETIME,      ' +     
            '@dLottable05     DATETIME,      ' +     
            '@cLottable06     NVARCHAR( 30), ' +     
            '@cLottable07     NVARCHAR( 30), ' +     
            '@cLottable08     NVARCHAR( 30), ' +     
            '@cLottable09     NVARCHAR( 30), ' +     
            '@cLottable10     NVARCHAR( 30), ' +     
            '@cLottable11     NVARCHAR( 30), ' +     
            '@cLottable12     NVARCHAR( 30), ' +     
            '@dLottable13     DATETIME,      ' +     
            '@dLottable14     DATETIME,      ' +     
            '@dLottable15     DATETIME,      ' +     
            '@nErrNo          INT           OUTPUT,  ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '     
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,     
            @cFromLOC, @cFromID, @cSKU, @nMQTY, @cToID, @cToLOC, @cLottableCode,     
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,     
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,     
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,     
            @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO quit    
      END   

      -- Move
      EXEC rdt.rdt_MoveToID_Close
         @nMobile     = @nMobile,
         @nFunc       = @nFunc,
         @cLangCode   = @cLangCode,
         @nStep       = @nStep, 
         @cStorerKey  = @cStorerKey, 
         @cToID       = @cToID,
         @cToLOC      = @cToLOC,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_7_Fail

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cFromLOC, @cSKU, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,        ' +
               '@nFunc      INT,        ' +
               '@cLangCode  NVARCHAR( 3),   ' +
               '@nStep      INT,        ' + 
               '@cStorerKey NVARCHAR( 15),  ' + 
               '@cToID      NVARCHAR( 18),  ' +
               '@cFromLOC   NVARCHAR( 10),  ' +
               '@cSKU       NVARCHAR( 20),  ' +
               '@nQTY       INT,        ' +
               '@cToLOC     NVARCHAR( 10),  ' +
               '@nErrNo     INT OUTPUT, ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cFromLOC, @cSKU, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
    
      -- Go to To ID screen
      SET @cOutField01 = '' 
        
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 6  
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Go to close To ID screen
      SET @cOutField01 = '' -- Option
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField01 = '' -- ToLOC
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      -- UserName  = @cUserName,

      V_String1  = @cFromLOC,
      V_String2  = @cFromID,
      V_String3  = @cSKU,
      V_SKUDescr = @cSKUDescr,

      V_UOM      = @cPUOM,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_PQTY     = @nPQTY,
      V_MQTY     = @nMQTY,
      V_PUOM_Div = @nPUOM_Div,
      
      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nQTY,
      V_Integer5 = @nIDQTY,
      V_Integer6 = @nBeforeScn, 

      V_Lottable01 = @cLottable01,  
      V_Lottable02 = @cLottable02,  
      V_Lottable03 = @cLottable03,  
      V_Lottable04 = @dLottable04,  
      V_Lottable05 = @dLottable05,  
      V_Lottable06 = @cLottable06,  
      V_Lottable07 = @cLottable07,  
      V_Lottable08 = @cLottable08,  
      V_Lottable09 = @cLottable09,  
      V_Lottable10 = @cLottable10,  
      V_Lottable11 = @cLottable11,  
      V_Lottable12 = @cLottable12,  
      V_Lottable13 = @dLottable13,  
      V_Lottable14 = @dLottable14,  
      V_Lottable15 = @dLottable15,  

      V_String14 = @cToLOC,
      V_String15 = @cToID,
      V_String16 = @cDecodeLabelNo,
      V_String17 = @cDisableQTYField,
      V_String18 = @cDefaultToLOC,
      V_String19 = @cExtendedUpdateSP, 
      V_String20 = @cDecodeSP,
      V_String21 = @cSKUValidated,
      V_String22 = @cLottableCode, 
      V_String23 = @cExtendedValidateSP,
      V_String24 = @cDefaultAvlQty2Move,
      V_String25 = @cDefaultSKU2Move,
      V_String26 = @cMoveAllSKUWithinSameLottable,

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