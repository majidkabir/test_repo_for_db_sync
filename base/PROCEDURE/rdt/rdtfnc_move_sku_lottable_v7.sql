SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_Move_SKU_Lottable_V7                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/* Move partial or full QTY of a SKU from a LOC/ID to another LOC/ID    */
/* Support dynamic lottable                                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 26-Jun-2018 1.0  James    WMS2430 Created                            */
/* 19-Apr-2019 1.1  James    Bug fix (james01)                          */
/* 06-Jan-2020 1.2  YeeKung  WMS-11540 Add MultiBarcode (yeekung01)     */
/* 15-03-2021  1.3  James    WMS-16464 Add suggested loc sp (james02)   */
/* 12-Aug-2021 1.4  YeeKung  WMS-17528 Add extendedvalidate (yeekung02) */
/* 17-Aug-2022 1.5  YeeKung  WMS-20075 Fix fromID (yeekung03)           */
/* 17-Apr-2023 1.6  Ung      WMS-22217 Add ConfirmSP                    */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Move_SKU_Lottable_V7] (
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
   @nRowCount         INT,
   @cChkFacility      NVARCHAR( 5),
   @b_Success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250)


-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cFromLOC          NVARCHAR( 10),
   @cFromID           NVARCHAR( 18),
   @cSKU              NVARCHAR( 20),
   @cSKUDescr         NVARCHAR( 60),
   @cLottableCode     NVARCHAR( 30),
   @nMorePage         INT,
   @cSQL              NVARCHAR( MAX),
   @cSQLParam         NVARCHAR( MAX),
   @cWhere            NVARCHAR( MAX),
   @curLLI            CURSOR,
   @cGroupBy          NVARCHAR( MAX),
   @cNextSKU          NVARCHAR( 20),

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
   @cID         NVARCHAR( 18), -- Actual moved ID
   @cPUOM       NVARCHAR( 1),  -- Pref UOM
   @cPUOM_Desc  NVARCHAR( 5),  -- Pref UOM desc
   @cMUOM_Desc  NVARCHAR( 5),  -- Master UOM desc
   @nQTY_Avail  INT,       -- QTY avail in master UOM
   @nPQTY_Avail INT,       -- QTY avail in pref UOM
   @nMQTY_Avail INT,       -- Remaining QTY in master UOM
   @nQTY_Move   INT,       -- QTY to move, in master UOM
   @nPQTY_Move  INT,       -- QTY to move, in pref UOM
   @nMQTY_Move  INT,       -- Remining QTY to move, in master UOM
   @nPUOM_Div   INT,
   @nSKUCnt     INT,

   @cToLOC      NVARCHAR( 10),
   @cToID       NVARCHAR( 18),
   @cUserName   NVARCHAR( 18),
   @cMoveAllSKUWithinSameLottable   NVARCHAR( 1),
   @cExtendedValidateSP             NVARCHAR( 20),
   @cDefaultSKU2Move                NVARCHAR( 20),
   @cDefaultAvlQty2Move             NVARCHAR( 1),
   @cSKU2Move  NVARCHAR( 20),
   @cMultiSKUBarcode       NVARCHAR( 1),  -- (yeekung01)
   @nFromScn               INT,    -- (yeekung01)
   @nFromStep              INT,
   @cSuggestedLOC          NVARCHAR( 10), -- (james02)
   @cSuggestLocSP          NVARCHAR( 20), -- (james02)
   @cMatchSuggestedLoc     NVARCHAR( 1),  -- (james02)
   @nPABookingKey          INT,           -- (james02)
   @nFlowThruToIDScn       INT,           -- (james02)
   @cPrevOutField15        NVARCHAR(20),  --(yeekung03)

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

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,

   @cID               = V_ID,
   @cSKUDescr         = V_SKUDescr,
   @cPUOM             = V_UOM,     -- Pref UOM
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

   @nQTY_Avail        = V_Integer1,
   @nPQTY_Avail       = V_Integer2,
   @nMQTY_Avail       = V_Integer3,
   @nQTY_Move         = V_Integer4,
   @nPQTY_Move        = V_Integer5,
   @nMQTY_Move        = V_Integer6,
   @nPUOM_Div         = V_Integer7,
   @nFlowThruToIDScn  = V_Integer8,

   @cFromLOC          = V_String1,
   @cFromID           = V_String2,
   @cSKU              = V_String3,
   @cPUOM_Desc        = V_String4, -- Pref UOM desc
   @cMUOM_Desc        = V_String5, -- Master UOM desc
   @cSuggestLocSP     = V_String6, -- (james02)
   @cMatchSuggestedLoc= V_String7, -- (james02)
   @cToLOC            = V_String13,
   @cToID             = V_String14,
   @cLottableCode     = V_String15,
   @cMoveAllSKUWithinSameLottable = V_String16,
   @cExtendedValidateSP = V_String17,
   @cDefaultSKU2Move    = V_String18,
   @cDefaultAvlQty2Move = V_String19,
   @cMultiSKUBarcode    = V_String20, -- (yeekung01)
   @cPrevOutField15     = V_String21,

   @nFromStep           = V_FromStep,  --(yeekung01)
   @nFromScn            = V_FromScn,   --(yeekung01)

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_FromLOC    INT,  @nScn_FromLOC     INT,
   @nStep_FromID     INT,  @nScn_FromID      INT,
   @nStep_SKU        INT,  @nScn_SKU         INT,
   @nStep_Lottables  INT,  @nScn_Lottables   INT,
   @nStep_Qty        INT,  @nScn_Qty         INT,
   @nStep_ToID       INT,  @nScn_ToID        INT,
   @nStep_ToLOC      INT,  @nScn_ToLOC       INT,
   @nStep_Message    INT,  @nScn_Message     INT,
   @nStep_MultiSKUBarcode    INT,  @nScn_MultiSKUBarcode     INT

SELECT
   @nStep_FromLOC    = 1,  @nScn_FromLOC     = 5190,
   @nStep_FromID     = 2,  @nScn_FromID      = 5191,
   @nStep_SKU        = 3,  @nScn_SKU         = 5192,
   @nStep_Lottables  = 4,  @nScn_Lottables   = 3990,
   @nStep_Qty        = 5,  @nScn_Qty         = 5194,
   @nStep_ToID       = 6,  @nScn_ToID        = 5195,
   @nStep_ToLOC      = 7,  @nScn_ToLOC       = 5196,
   @nStep_Message    = 8,  @nScn_Message     = 5197,
   @nStep_MultiSKUBarcode = 9,  @nScn_MultiSKUBarcode     = 3570

IF @nFunc = 629 -- Move SKU (lottable)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start       -- Func = Move SKU (lottable)
   IF @nStep = 1 GOTO Step_FromLOC     -- Scn = 5190. FromID
   IF @nStep = 2 GOTO Step_FromID      -- Scn = 5191. FromLOC
   IF @nStep = 3 GOTO Step_SKU         -- Scn = 5192. SKU, desc1, desc2
   IF @nStep = 4 GOTO Step_Lottables   -- Scn = 5193. Dynamic Lottable
   IF @nStep = 5 GOTO Step_Qty         -- Scn = 5194. UOM, QTY
   IF @nStep = 6 GOTO Step_ToID        -- Scn = 5195. ToID
   IF @nStep = 7 GOTO Step_ToLOC       -- Scn = 5196. ToLOC
   IF @nStep = 8 GOTO Step_Message     -- Scn = 5197. Message
   IF @nStep = 9 GOTO Step_MultiSKUBarcode -- Scn = 3570. Multi SKU Barcode
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 629. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = @nScn_FromLOC
   SET @nStep = @nStep_FromLOC

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cMoveAllSKUWithinSameLottable = rdt.RDTGetConfig( @nFunc, 'MoveAllSKUWithinSameLottable', @cStorerKey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cDefaultSKU2Move = rdt.RDTGetConfig( @nFunc, 'DefaultSKU2Move', @cStorerKey)
   IF @cDefaultSKU2Move = '0'
      SET @cDefaultSKU2Move = ''

   SET @cDefaultAvlQty2Move = rdt.RDTGetConfig( @nFunc, 'DefaultAvlQty2Move', @cStorerKey)
   IF @cDefaultAvlQty2Move = '0'
      SET @cDefaultAvlQty2Move = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey) --(yeekung01)

   SET @cSuggestLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestedLocSP', @cStorerKey)
   IF @cSuggestLocSP = '0'
      SET @cSuggestLocSP = ''

   SET @cMatchSuggestedLoc = rdt.RDTGetConfig( @nFunc, 'MatchSuggestedLoc', @cStorerKey)

   SET @nFlowThruToIDScn = rdt.RDTGetConfig( @nFunc, 'FlowThruToIDScn', @cStorerKey)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cOutField01 = '' -- FromLOC

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


/********************************************************************************
Step 1. Scn = 5190. FromLOC
   FromLOC (field01, input)
********************************************************************************/
Step_FromLOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 125551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_FromLOC_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 125552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_FromLOC_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 125553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_FromLOC_Fail
      END

      -- Get StorerConfig 'UCC'
      DECLARE @cUCCStorerConfig NVARCHAR( 1)
      SELECT @cUCCStorerConfig = SValue
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      -- Check UCC exists
      IF @cUCCStorerConfig = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.UCC (NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND LOC = @cFromLOC
               AND Status = 1) -- 1=Received
         BEGIN
            SET @nErrNo = 125554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC have UCC'
            GOTO Step_FromLOC_Fail
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
            @cFromLOC, @cFromID, @cSKU, @nMQTY_Move, @cToID, @cToLOC, @cLottableCode,   
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,   
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,   
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,   
            @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
            GOTO Step_FromLOC_Fail  
      END  
  
      -- Prep next screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

      -- Go to next screen
      SET @nScn = @nScn_FromID
      SET @nStep = @nStep_FromID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

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

   Step_FromLOC_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5191. FromID
   FromLOC (field01)
   FromID  (field02, input)
********************************************************************************/
Step_FromID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField02

      -- Validate ID
      IF ISNULL(@cFromID, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1
            FROM dbo.LOTxLOCxID (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LOC = @cFromLOC
               AND ID = @cFromID
               AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
         BEGIN
            SET @nErrNo = 125555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ID'
            GOTO Step_FromID_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = CASE WHEN @cDefaultSKU2Move = '' THEN '' ELSE @cDefaultSKU2Move END --@cSKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromLOC

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

      -- Go to prev screen
      SET @nScn = @nScn_FromLOC
      SET @nStep = @nStep_FromLOC
   END
   GOTO Quit

   Step_FromID_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField02 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 5192. SKU screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 125556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_SKU_Fail
      END

      -- Validate SKU
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 125557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_SKU_Fail
      END

      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            IF (@cFromID <>'')
            BEGIN
               EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,
                  'POPULATE',
                  @cMultiSKUBarcode,
                  @cStorerKey,
                  @cSKU         OUTPUT,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT,
                  'LOTXLOCXID.ID',    -- DocType
                  @cFromID
            END
            ELSE
            BEGIN
               EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,
                  'POPULATE',
                  @cMultiSKUBarcode,
                  @cStorerKey,
                  @cSKU         OUTPUT,
                  @nErrNo       OUTPUT,
                  @cErrMsg      OUTPUT,
                  'LOTXLOCXID.LOC',    -- DocType
                  @cFromLOC
            END

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn_SKU
               SET @nFromStep = @nStep_SKU
               SET @nScn = @nScn_MultiSKUBarcode
               SET @nStep = @nStep_MultiSKUBarcode
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 125558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
            GOTO Step_SKU_Fail
         END
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Get QTY avail
      SET @nQTY_Avail = 0
      SELECT @nQTY_Avail = SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
      FROM dbo.LOTxLOCxID (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = CASE WHEN @cFromID = '' THEN ID ELSE @cFromID END
         AND (( @cMoveAllSKUWithinSameLottable = '1' AND SKU = SKU) OR ( SKU = @cSKU))

      -- Validate no QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 125559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_SKU_Fail
      END
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
         FROM dbo.SKU S (NOLOCK)
            INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

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
         SET @cOutField13=''
         SET @cInField13=''
         SET @cPrevOutField15 = @cOutField15
         SET @nScn = 3990
         SET @nStep = @nStep_Lottables
      END
      ELSE
      BEGIN
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nPQTY_Move  = 0
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         SET @cID =@cFromID --(yeekung01)

         -- Prepare next screen var
         SET @nPQTY_Move = 0
         SET @nMQTY_Move = 0
         SET @cOutField01 = @cID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
        -- SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)
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

         -- Go to next screen
         SET @nScn = @nScn_Qty
         SET @nStep = @nStep_Qty
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cFromID

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

      -- Go to prev screen
      SET @nScn = @nScn_FromID
      SET @nStep = @nStep_FromID
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField03 = CASE WHEN @cDefaultSKU2Move = '' THEN '' ELSE @cDefaultSKU2Move END -- SKU
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
Step_Lottables:
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
         SET @cSQL = ''
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
            '    @cID = LLI.ID,' +
            '    @cSKU = LLI.SKU,' +
            '    @nQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) ' +
            ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +
            ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +
            ' WHERE LLI.StorerKey = @cStorerKey ' +
            ' AND   LLI.SKU = @cSKU ' +
            ' AND   LLI.LOC = @cFromLOC ' +
            ' AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +
            ' AND   LLI.ID = CASE WHEN ISNULL( @cFromID, '''') = '''' THEN LLI.ID ELSE @cFromID END ' +
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
         ' @cID         NVARCHAR( 18) OUTPUT, ' +
         ' @nQTY_Avail  INT           OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cID OUTPUT,  @nQTY_Avail OUTPUT

      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL
      BEGIN
         SET @nErrNo = 125560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_Lottables_Fail
      END

      IF @cMoveAllSKUWithinSameLottable = '1'
         SET @cID = CASE WHEN ISNULL( @cFromID, '') = '' THEN '' ELSE @cFromID END

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
         SET @nPQTY_Move  = 0
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @nPQTY_Move = 0
      SET @nMQTY_Move = 0
      SET @cOutField01 = @cID
      --SET @cOutField02 = @cLottable01
      --SET @cOutField03 = @cLottable02
      --SET @cOutField04 = @cLottable03
      --SET @cOutField05 = rdt.rdtFormatDate( @dLottable04)

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

      -- Goto next screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cSKU = ''
      SET @cSKUDescr = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = CASE WHEN @cDefaultSKU2Move = '' THEN '' ELSE @cDefaultSKU2Move END -- SKU
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
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   Step_Lottables_Fail:
   BEGIN      
      SET @cOutField15 = @cPrevOutField15
   END
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
Step_Qty:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY NVARCHAR( 5)
      DECLARE @cMQTY NVARCHAR( 5)

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

      -- Screen mapping
      IF @cPUOM_Desc = ''
         SET @cPQTY = ''
      ELSE
         SET @cPQTY = IsNULL( @cInField10, '')
         SET @cMQTY = IsNULL( @cInField13, '')

      -- Retain the key-in value
      IF @cPUOM_Desc = ''
         SET @cOutField10 = @cInField10 -- Pref QTY
      ELSE
         SET @cOutField10 = ''
         SET @cOutField13 = @cInField13 -- Master QTY

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
         '    @cNextID = LLI.ID, ' +
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
         ' @cNextID     NVARCHAR( 18) OUTPUT, ' +
         ' @cNextSKU    NVARCHAR( 20) OUTPUT, ' +
         ' @nNextQTY_Avail  INT       OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU, @cID,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cNextID OUTPUT, @cNextSKU OUTPUT, @nNextQTY_Avail OUTPUT

         -- Validate if any result
         IF IsNULL( @nNextQTY_Avail, 0) = 0
         BEGIN
            SET @nErrNo = 125561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'
            GOTO Step_Qty_Fail
         END

         -- Set next record values
         SET @cID = @cNextID
         SET @cSKU = @cNextSKU
         SET @nQTY_Avail = @nNextQTY_Avail

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Avail = 0
            SET @nPQTY_Move  = 0
            SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         END
         ELSE
         BEGIN
            SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prepare next screen var
         SET @nPQTY_Move = 0
         SET @nMQTY_Move = 0
         SET @cOutField01 = @cID

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
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 125562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Step_Qty_Fail
      END

      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 125563
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- MQTY
         GOTO Step_Qty_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY_Move = CAST( @cPQTY AS INT)
      SET @nMQTY_Move = CAST( @cMQTY AS INT)
      SET @nQTY_Move = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY_Move = @nQTY_Move + @nMQTY_Move

      -- Validate QTY
      IF @nQTY_Move = 0
      BEGIN
         SET @nErrNo = 125564
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_Qty_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY_Move > @nQTY_Avail
      BEGIN
         SET @nErrNo = 125565
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_Qty_Fail
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
            @cFromLOC, @cFromID, @cSKU, @nMQTY_Move, @cToID, @cToLOC, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_Qty_Fail
      END

      -- Prep ToID screen var
      SET @cFromID = @cID
      SET @cToID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = '' -- @cToID

      -- Go to ToID screen
      SET @nScn = @nScn_ToID
      SET @nStep = @nStep_ToID

      -- (james02)
      IF @nFlowThruToIDScn = 1
      BEGIN
         GOTO Step_ToID
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
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
         SET @nScn = 3990
         SET @nStep = @nStep_Lottables
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = ''  -- SKU desc 2

         -- Go to QTY screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
   END
   GOTO Quit

   Step_Qty_Fail:
      SET @cFieldAttr10 = ''

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O'

END
GOTO Quit


/********************************************************************************
Step 6. Scn = 5195. ToID
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field08)
   QTY MV  (field07, field09)
   ToID    (field10, input)
********************************************************************************/
Step_ToID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField10

      -- Extended putaway
      IF @cSuggestLocSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +
            ' @cType, @cFromLOC, @cFromID, @cSKU, @nQty, @cToID, @cToLOC, @cLottableCode, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cSuggestedLOC OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cType           NVARCHAR( 10), ' +
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
            '@cSuggestedLOC   NVARCHAR( 10) OUTPUT,  ' +
            '@nErrNo          INT           OUTPUT,  ' +
            '@nPABookingKey   INT           OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,
            'LOCK', @cFromLOC, @cFromID, @cSKU, @nMQTY_Move, @cToID, @cToLOC, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cSuggestedLOC OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
         END
      END

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

      -- Prep ToLOC screen var
      SET @cToLOC = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = @cToID
      SET @cOutField11 = '' -- @cToLOC
      SET @cOutField12 = CASE WHEN ISNULL( @cSuggestedLOC, '') <> '' THEN @cSuggestedLOC ELSE '' END

      -- Go to next screen
      SET @nScn = @nScn_ToLOC
      SET @nStep = @nStep_ToLOC
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Prepare next screen var
      SET @cOutField01 = @cID

      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY_Move
         SET @nMQTY_Avail = @nQTY_Avail -- Bug fix by Vicky on 09-Aug-2007
         SET @cFieldAttr10 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
         SET @cOutField10 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 5))
      SET @cOutField13 = CAST( @nMQTY_Move AS NVARCHAR( 5))

      -- Go to QTY screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty
   END
END
GOTO Quit


/********************************************************************************
Step 7. Scn = 5196. ToLOC
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field08)
   QTY MV  (field07, field09)
   ToID    (field10)
   ToLOC   (field11, input)
********************************************************************************/
Step_ToLOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField11
      SET @cSuggestedLOC = @cOutField12

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

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         SET @nErrNo = 125566
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLOC needed'
         GOTO Step_ToLOC_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 125567
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_ToLOC_Fail
      END

      IF @cSuggestedLOC <> @cToLOC AND @cMatchSuggestedLoc = '1'
      BEGIN
         SET @nErrNo = 125570
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Not Match'
         GOTO Step_ToLOC_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 125568
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_ToLOC_Fail
         END

      -- Confirm
      EXEC rdt.rdt_Move_SKU_Lottable_Confirm_V7
          @nMobile         = @nMobile    
         ,@nFunc           = @nFunc      
         ,@cLangCode       = @cLangCode  
         ,@nStep           = @nStep      
         ,@nInputKey       = @nInputKey  
         ,@cStorerKey      = @cStorerKey 
         ,@cFacility       = @cFacility  
         ,@cFromLOC        = @cFromLOC   
         ,@cFromID         = @cID    
         ,@cSKU            = @cSKU       
         ,@cLottableCode   = @cLottableCode
         ,@cLottable01     = @cLottable01
         ,@cLottable02     = @cLottable02
         ,@cLottable03     = @cLottable03
         ,@dLottable04     = @dLottable04
         ,@dLottable05     = @dLottable05
         ,@cLottable06     = @cLottable06
         ,@cLottable07     = @cLottable07
         ,@cLottable08     = @cLottable08
         ,@cLottable09     = @cLottable09
         ,@cLottable10     = @cLottable10
         ,@cLottable11     = @cLottable11
         ,@cLottable12     = @cLottable12
         ,@dLottable13     = @dLottable13
         ,@dLottable14     = @dLottable14
         ,@dLottable15     = @dLottable15
         ,@nQTY            = @nQTY_Move       
         ,@cToID           = @cToID      
         ,@cToLOC          = @cToLOC     
         ,@nErrNo          = @nErrNo    OUTPUT 
         ,@cErrMsg         = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Go to next screen
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Prepare ToID screen var
      SET @cToID = ''
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescR, 1, 20)   -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescR, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField06 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY_Avail
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY_Move AS NVARCHAR( 5))
      END
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CAST( @nMQTY_Move AS NVARCHAR( 5))
      SET @cOutField10 = '' -- ToID

      -- Go to ToID screen
      SET @nScn  = @nScn_ToID
      SET @nStep = @nStep_ToID
   END
   GOTO Quit

   Step_ToLOC_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField11 = '' -- @cToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 8. scn = 5197. Message screen
   Message
********************************************************************************/
Step_Message:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn_FromLOC
   SET @nStep = @nStep_FromLOC

   -- Prep next screen var
   SET @cFromLOC = ''
   SET @cOutField01 = '' -- FromLOC

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

/********************************************************************************
Step_MultiSKUBarcode. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_MultiSKUBarcode:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF (@cFromID <>'')
      BEGIN
         EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,
            'CHECK',
            @cMultiSKUBarcode,
            @cStorerKey,
            @cSKU         OUTPUT,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT,
            'LOTXLOCXID.ID',    -- DocType
            @cFromID
      END
      ELSE
      BEGIN
         EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,
            'CHECK',
            @cMultiSKUBarcode,
            @cStorerKey,
            @cSKU     OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT,
            'LOTXLOCXID.LOC',    -- DocType
            @cFromLOC
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep

      -- To indicate sku has been successfully selected
      SET @nFromScn = @nScn_MultiSKUBarcode
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromID
      SET @cOutField03 = ''   -- SKU
      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
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

      V_ID       = @cID,
      V_SKUDescr = @cSKUDescr,
      V_UOM      = @cPUOM,
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

      V_Integer1   = @nQTY_Avail,
      V_Integer2   = @nPQTY_Avail,
      V_Integer3   = @nMQTY_Avail,
      V_Integer4   = @nQTY_Move,
      V_Integer5   = @nPQTY_Move,
      V_Integer6   = @nMQTY_Move,
      V_Integer7   = @nPUOM_Div,
      V_Integer8   = @nFlowThruToIDScn,

      V_String1  = @cFromLOC,
      V_String2  = @cFromID,
      V_String3  = @cSKU,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_String6  = @cSuggestLocSP,
      V_String7  = @cMatchSuggestedLoc,
      V_String13 = @cToLOC,
      V_String14 = @cToID,
      V_String15 = @cLottableCode,
      V_String16 = @cMoveAllSKUWithinSameLottable,
      V_String17 = @cExtendedValidateSP,
      V_String18 = @cDefaultSKU2Move,
      V_String19 = @cDefaultAvlQty2Move,
      V_String20 = @cMultiSKUBarcode, -- (yeekung01)
      V_String21 = @cPrevOutField15, --(yeekung03)

      V_FromStep = @nFromStep, --(yeekung01)
      V_FromScn  = @nFromScn,  --(yeekung01)

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