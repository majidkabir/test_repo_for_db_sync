SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_Replenish_V7                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Modified from rdtfnc_Replenish (510) with dynamic lottable  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2019-03-25 1.0  James    WMS-8254 Created                            */
/* 2022-09-22 1.1  James    Bug fix on input field not matching on      */
/*                          step to loc (james01)                       */
/* 2022-08-23 1.2  Ung      WMS-20562 Add UCC                           */
/* 2024-10-17 1.3  PXL009   FCR-759 ID and UCC Length Issue             */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Replenish_V7] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 nvarchar max
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess      INT, 
   @cChkFacility  NVARCHAR( 5),
   @nSKUCnt       INT

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

   @cSKU        NVARCHAR( 20),
   @cDescr      NVARCHAR( 40),
   @cPUOM       NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc  NVARCHAR( 5),
   @cMUOM_Desc  NVARCHAR( 5),
   @cReplenKey  NVARCHAR( 10),
   @cLot        NVARCHAR( 10),
   @cFromLoc    NVARCHAR( 10),
   @cToLoc      NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cToID       NVARCHAR( 18),
   @cRPLKey     NVARCHAR( 10),
   @cActToLOC   NVARCHAR( 10),
   @cRefNo      NVARCHAR( 20),
   @cUCCNo      NVARCHAR( 20),

   @nPUOM_Div   INT, -- UOM divider
   @nQTY_Avail  INT, -- QTY available in LOTxLOCXID
   @nQTY        INT, -- Replenishment.QTY
   @nPQTY       INT, -- Preferred UOM QTY
   @nMQTY       INT, -- Master unit QTY
   @nActQTY     INT, -- Actual replenish QTY
   @nActMQTY    INT, -- Actual keyed in master QTY
   @nActPQTY    INT, -- Actual keyed in prefered QTY

   @nLOCCnt     INT, -- # LOC Count
   @nIDCnt      INT, -- # ID Count

   @cReplenBySKUQTY     NVARCHAR( 1),
   @cDisplayQtyAvail    NVARCHAR( 1),
   @cReplenEnableTOID   NVARCHAR( 1),
   @cMoveQTYAlloc       NVARCHAR( 1),
   @cUCCStorerConfig    NVARCHAR( 1), 

   @cTempFromLoc        NVARCHAR( 10),
   @cTempFromID         NVARCHAR( 18),
   @cBarcode            NVARCHAR( 60),
   @cDecodeSP           NVARCHAR( 20),
   @cSwapUCCSP          NVARCHAR( 20),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @tVar                VariableTable,
   @nMorePage           INT,
   @nLottableOnPage     INT,
   @cLottableCode       NVARCHAR( 30),

   @cChkLottable01 NVARCHAR( 18),   @cChkLottable02 NVARCHAR( 18),   @cChkLottable03 NVARCHAR( 18),
   @dChkLottable04 DATETIME,        @dChkLottable05 DATETIME,        @cChkLottable06 NVARCHAR( 30),
   @cChkLottable07 NVARCHAR( 30),   @cChkLottable08 NVARCHAR( 30),   @cChkLottable09 NVARCHAR( 30),
   @cChkLottable10 NVARCHAR( 30),   @cChkLottable11 NVARCHAR( 30),   @cChkLottable12 NVARCHAR( 30),
   @dChkLottable13 DATETIME,        @dChkLottable14 DATETIME,        @dChkLottable15 DATETIME,

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

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

   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cPUOM       = V_UOM,
   @cLOT        = V_LOT,
   @cFromLoc    = V_LOC,
   @cFromID     = V_ID,
   @cUCCNo      = V_UCC, 

   @nPUOM_Div   = V_PUOM_Div,
   @nQTY        = V_TaskQTY, 
   @nMQTY       = V_MTaskQTY,
   @nPQTY       = V_PTaskQTY,
   @nActMQTY    = V_MQTY,
   @nActPQTY    = V_PQTY,
   @nActQty     = V_QTY,

   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @cToLOC      = V_String1,
   @cActToLOC   = V_String2,
   @cMUOM_Desc  = V_String3,
   @cPUOM_Desc  = V_String4,
   @cReplenKey  = V_String5,  -- For internal processing
   @cToID       = V_String12,
   @cRPLKey     = V_String13, -- For screen key-in
   @cRefNo      = V_String15, 

   @cReplenBySKUQTY     = V_String20,
   @cDisplayQtyAvail    = V_String21,
   @cReplenEnableTOID   = V_String22,
   @cMoveQTYAlloc       = V_String23,
   @cUCCStorerConfig    = V_String24,
   @cExtendedInfoSP     = V_String25,
   @cDecodeSP           = V_String26,
   @cSwapUCCSP          = V_String27,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 896 -- Replenish
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 510
   IF @nStep = 1 GOTO Step_1   -- Scn = 5370. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 5371. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 5372. ACT QTY
   IF @nStep = 4 GOTO Step_4   -- Scn = 5373. To LOC
   IF @nStep = 5 GOTO Step_5   -- Scn = 5374. Replen to diff LOC?
   IF @nStep = 6 GOTO Step_6   -- Scn = 5375. Successful
   IF @nStep = 7 GOTO Step_7   -- Scn = 5376. UCC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 896)
********************************************************************************/
Step_0:
BEGIN
   -- Init var
   SET @nPQTY = 0
   SET @nActPQTY = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Storer configure
   SET @cDisplayQtyAvail = rdt.RDTGetConfig( @nFunc, 'DisplayQtyAvailable', @cStorerKey)
   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cReplenBySKUQTY = rdt.RDTGetConfig( @nFunc, 'ReplenBySKUQTY', @cStorerKey)
   SET @cReplenEnableTOID = rdt.RDTGetConfig( @nFunc, 'ReplenEnableTOID', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cSwapUCCSP = rdt.RDTGetConfig( @nFunc, 'SwapUCCSP', @cStorerKey)
   IF @cSwapUCCSP = '0'
      SET @cSwapUCCSP = ''

   SELECT @cUCCStorerConfig = SValue
   FROM dbo.StorerConfig (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ConfigKey = 'UCC'

   -- Event log
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Prep next screen var
   SET @cOutField01 = '' -- FromLOC
   SET @cOutField02 = '' -- FromID
   SET @cOutField03 = '' -- RPL KEY

   -- Set the entry point
   SET @nScn = 5370
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5370. FROM LOC, ID or REPLENKEY screen
   FROM LOC  (Field01, input)
   FROM ID   (Field02, input)
   REPLENKEY (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cLoseUCC NVARCHAR( 1)
      
      -- Screen mapping
      SET @cFromLoc = @cInField01
      SET @cFromID = @cInField02
      SET @cBarcode = @cInField02
      SET @cRPLKey = @cInField03

      -- Check blank
      IF @cFromLoc = '' AND @cFromID = '' AND @cRPLKey = ''
      BEGIN
         SET @nErrNo = 136651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC/ID/RPLKEY
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check key-in both
      IF (@cFromLoc <> '' OR @cFromID <> '') AND @cRPLKey <> ''
      BEGIN
         SET @nErrNo = 136660
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC/ID OR RPLKEY
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID         = @cFromID      OUTPUT,
               @cUPC        = @cSKU         OUTPUT,
               @nQTY        = @nQTY         OUTPUT,
               @cLottable01 = @cLottable01  OUTPUT,
               @cLottable02 = @cLottable02  OUTPUT,
               @cLottable03 = @cLottable03  OUTPUT,
               @dLottable04 = @dLottable04  OUTPUT,
               @dLottable05 = @dLottable05  OUTPUT,
               @cLottable06 = @cLottable06  OUTPUT,
               @cLottable07 = @cLottable07  OUTPUT,
               @cLottable08 = @cLottable08  OUTPUT,
               @cLottable09 = @cLottable09  OUTPUT,
               @cLottable10 = @cLottable10  OUTPUT,
               @cLottable11 = @cLottable11  OUTPUT,
               @cLottable12 = @cLottable12  OUTPUT,
               @dLottable13 = @dLottable13  OUTPUT,
               @dLottable14 = @dLottable14  OUTPUT,
               @dLottable15 = @dLottable15  OUTPUT,
               @cType = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cFromID     OUTPUT, @cFromLOC    OUTPUT, @cToID       OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQty         INT            OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cFromID     OUTPUT, @cFromLoc     OUTPUT, @cToID       OUTPUT,
               @cToLOC      OUTPUT, @cSKU         OUTPUT, @nQty        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07  OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12  OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg      OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      IF @cRPLKey <> ''
      BEGIN
         -- Get replen info
         DECLARE @cConfirmed NVARCHAR(1)
         SELECT
            @cFromLOC = FromLOC,
            @cFromID = ID,
            @cSKU = SKU,
            @cLOT = LOT,
            @nQTY = QTY,
            @nActQTY = QTY, 
            @cToLOC = ToLOC,
            @cConfirmed = Confirmed, 
            @cRefNo = RefNo
         FROM Replenishment WITH (NOLOCK)
         WHERE ReplenishmentKey = @cRPLKey

         -- Check valid RPLKEY
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 136668
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RPLKey
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Check replenish done
         IF @cConfirmed = 'Y'
         BEGIN
            SET @nErrNo = 136671
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RPLKey done
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Get Pack info
         SELECT
            @cDescr = SKU.Descr,
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
            @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END

         -- Get LOC info
         SELECT @cLoseUCC = LoseUCC
         FROM dbo.LOC (NOLOCK)
         WHERE LOC = @cFromLOC

         SET @cReplenKey = @cRPLKey
         SET @nSKUCnt = 1
      END
      ELSE
         -- Scan FROMLOC only
         IF @cFromID = '' OR @cFromID IS NULL
         BEGIN
            -- Get LOC info
            SELECT 
               @cChkFacility = Facility, 
               @cLoseUCC = LoseUCC
            FROM dbo.LOC (NOLOCK)
            WHERE LOC = @cFromLOC

            -- Validate LOC
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 136652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END

            -- Validate LOC's facility
            IF @cChkFacility <> @cFacility
            BEGIN
               SET @nErrNo = 136653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END

            -- Validate if the LOC has open replenishment task
            IF NOT EXISTS( SELECT 1
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND FromLoc = @cFromLoc
                  AND Confirmed = 'N')
            BEGIN
               SET @nErrNo = 136654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task in LOC
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END

            -- If 1 FROM LOC have multiple ID, prompt to key in FROM ID
            SELECT @nIDCnt = COUNT ( DISTINCT ID)
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
                  AND FromLoc = @cFromLoc
                  AND Confirmed = 'N'
            IF @nIDCnt > 1
            BEGIN
               SET @nErrNo = 136673
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID needed
               EXEC rdt.rdtSetFocusField @nMobile, 2
               SET @cOutField01 = @cFromLoc -- From LOC
               SET @cOutField02 = '' -- From LOC
               GOTO Quit
            END

            -- If only 1 FROM ID found, auto retrieve FROM ID from replenishment
            IF @nIDCnt = 1
            BEGIN
               SELECT @cFromID = ID
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                     AND FromLoc = @cFromLoc
                     AND Confirmed = 'N'
            END

            -- Get replenishment task
            SELECT @nSKUCnt = COUNT( DISTINCT SKU)
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND FromLoc = @cFromLoc
               AND Confirmed = 'N' --Open

         END   -- end for Scan FROMLOC only
         ELSE  -- Scan FROMID only
         BEGIN
            -- Check for Valid Loc (if both field keyed in)
            IF ISNULL(@cFromLoc, '') <> '' --or @cFromLoc IS NOT NULL
            BEGIN
               -- Get LOC info
               SELECT 
                  @cChkFacility = Facility, 
                  @cLoseUCC = LoseUCC
               FROM dbo.LOC (NOLOCK)
               WHERE LOC = @cFromLOC

               -- Validate LOC
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 136666
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cFromID
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END

               -- Validate LOC's facility
               IF @cChkFacility <> @cFacility
               BEGIN
                  SET @nErrNo = 136667
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cFromID
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END

               -- Validate if the LOC has open replenishment task
               IF NOT EXISTS( SELECT 1
                  FROM dbo.Replenishment WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND FromLoc = @cFromLoc
                     AND Confirmed = 'N')
               BEGIN
                  SET @nErrNo = 136676
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task in LOC
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cFromID
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END
            END

            -- If 1 FROM ID have multiple FROM LOC, prompt to key in FROM LOC
            IF @cFromLoc = '' or @cFromLoc IS NULL
            BEGIN
               SELECT @nLOCCnt = COUNT ( DISTINCT FROMLOC)
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                     AND ID = @cFromID
                     AND Confirmed = 'N'
               IF @nLOCCnt > 1
               BEGIN
                  SET @nErrNo = 136672
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  SET @cOutField01 = '' -- From LOC
                  SET @cOutField02 = @cFromID -- From ID
                  GOTO Quit
               END
            END

            IF @nLOCCnt = 1
            BEGIN
               SELECT @cFromLoc = FROMLOC
               FROM dbo.Replenishment WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ID = @cFromID
                  AND Confirmed = 'N' --Open
            END

            -- Get replenishment task
            SELECT @nSKUCnt = COUNT( DISTINCT SKU)
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND FromLoc = @cFromLoc
               AND ID = @cFromID
               AND Confirmed = 'N' --Open

            -- Validate open task exist
            IF @nSKUCnt = 0
            BEGIN
               SET @nErrNo = 136655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Not IN RPL
               SET @cOutField01 = @cFromLoc
               SET @cOutField02 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO QUIT
            END
         END

      -- UCC location
      IF @cUCCStorerConfig = '1' AND @cLoseUCC <> '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' -- UCC

         -- Go to UCC screen
         SET @nScn  = @nScn + 6
         SET @nStep = @nStep + 6
      END

      -- Multiple SKU found in open tasks, go to SKU/UPC screen
      ELSE 
      BEGIN
         SET @cUCCNo = ''
         
         IF @nSKUCnt > 1
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cFromLoc
            SET @cOutField02 = @cFromID
            SET @cOutField03 = '' -- SKU/UPC

            -- Go to next screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
         END

         -- Only one SKU found in open tasks, go to QTY screen
         ELSE IF @nSKUCnt = 1
         BEGIN
            -- Get task
            IF @cRPLKey = ''
            BEGIN
               SELECT @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
                      @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
                      @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

               SET @cReplenKey = ''
               SET @cSKU = ''
               EXEC rdt.rdt_Replenish_V7_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                  ,@cReplenBySKUQTY
                  ,@cDisplayQtyAvail
                  ,@cFromLOC
                  ,@cFromID
                  ,@cReplenKey      OUTPUT
                  ,@cSKU            OUTPUT
                  ,@cLOT            OUTPUT
                  ,@cLottableCode   OUTPUT
                  ,@cLottable01     OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
                  ,@cLottable06     OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
                  ,@cLottable11     OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
                  ,@nQTY            OUTPUT
                  ,@cToLOC          OUTPUT
                  ,@nErrNo          OUTPUT
                  ,@cErrMsg         OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END

            -- Dynamic lottable
            EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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
               '',      -- SourceKey
               @nFunc   -- SourceType

            -- Get Pack info
            SELECT
               @cDescr = SKU.Descr,
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
               @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
            END

            -- Prep QTY screen var
            SET @cOutField01 = @cReplenKey
            SET @cOutField02 = @cSKU
            SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
            SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)
            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField10 = '' -- @nPQTY
               SET @cOutField12 = '' -- @nActPQTY
               SET @cFieldAttr12 = 'O' -- @nActPQTY
            END
            ELSE
            BEGIN
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField12 = '' -- @nActPQTY
               SET @cFieldAttr12 = '' -- @nActPQTY
            END
            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cOutField13 = '' -- ActMQTY
            SET @cOutField14 = '' -- ExtendedInfo

            -- Go to QTY screen
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2
         END
      END
      
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cReplenKey',   @cReplenKey),
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToLOC',       @cToLOC),
               ('@cToID',        @cToID)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nToStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nToStep        INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField14 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign-Out
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cFromID = ''
      SET @cOutField01 = '' -- From LOC
      SET @cOutField02 = '' -- From ID
      SET @cOutField03 = '' -- RPL KEY
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 5371. SKU screen
   FROM LOC (Field01)
   FROM ID  (Field02)
   SKU      (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)
      
      -- Screen mapping
      SET @cUPC = LEFT( @cInField03, 30)
      SET @cBarcode = @cInField03

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 136656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/UPC needed
         GOTO Step_2_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID         = @cFromID      OUTPUT,
               @cUPC        = @cUPC         OUTPUT,
               @nQTY        = @nQTY         OUTPUT,
               @cLottable01 = @cLottable01  OUTPUT,
               @cLottable02 = @cLottable02  OUTPUT,
               @cLottable03 = @cLottable03  OUTPUT,
               @dLottable04 = @dLottable04  OUTPUT,
               @dLottable05 = @dLottable05  OUTPUT,
               @cLottable06 = @cLottable06  OUTPUT,
               @cLottable07 = @cLottable07  OUTPUT,
               @cLottable08 = @cLottable08  OUTPUT,
               @cLottable09 = @cLottable09  OUTPUT,
               @cLottable10 = @cLottable10  OUTPUT,
               @cLottable11 = @cLottable11  OUTPUT,
               @cLottable12 = @cLottable12  OUTPUT,
               @dLottable13 = @dLottable13  OUTPUT,
               @dLottable14 = @dLottable14  OUTPUT,
               @dLottable15 = @dLottable15  OUTPUT,
               @cType = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cFromID     OUTPUT, @cFromLOC    OUTPUT, @cToID       OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQty         INT            OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cFromID     OUTPUT, @cFromLoc     OUTPUT, @cToID       OUTPUT,
               @cToLOC      OUTPUT, @cSKU         OUTPUT, @nQty        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07  OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12  OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg      OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
               
            SET @cUPC = @cSKU
         END
      END

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 136657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 136658
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_2_Fail
      END

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      SET @cSKU = @cUPC

      -- Validate if open task exists
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLoc = @cFromLoc
            AND ID = @cFromID
            AND SKU = @cSKU
            AND Confirmed = 'N')
         BEGIN
            SET @nErrNo = 136659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Not in RPL'
            GOTO Step_2_Fail
         END

      SELECT @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
             @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
             @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get task
      SET @cReplenKey = ''
      EXEC rdt.rdt_Replenish_V7_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cReplenBySKUQTY
         ,@cDisplayQtyAvail
         ,@cFromLOC
         ,@cFromID
         ,@cReplenKey      OUTPUT
         ,@cSKU            OUTPUT
         ,@cLOT            OUTPUT
         ,@cLottableCode   OUTPUT
         ,@cLottable01     OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
         ,@cLottable06     OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
         ,@cLottable11     OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
         ,@nQTY            OUTPUT
         ,@cToLOC          OUTPUT
         ,@nErrNo          OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Get Pack info
      SELECT
         @cDescr = SKU.Descr,
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
         @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prep QTY screen var
      SET @cOutField01 = @cReplenKey
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField10 = '' -- @nPQTY
         SET @cOutField12 = '' -- @nActPQTY
         SET @cFieldAttr12 = 'O' -- @nActPQTY
      END
      ELSE
      BEGIN
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField12 = '' -- ActPQTY
         SET @cFieldAttr12 = '' -- @nActPQTY
      END
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField13 = '' -- ActMQTY
      SET @cOutField14 = '' --ExtendedInfo

      -- Go to QTY screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cFromLoc = ''
      SET @cFromID = ''
      SET @cOutField01 = '' -- FromLoc
      SET @cOutField02 = '' -- FromID
      SET @cOutField03 = '' -- RPL KEY

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

   Step_2_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cReplenKey',   @cReplenKey),
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToLOC',       @cToLOC),
               ('@cToID',        @cToID)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nToStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nToStep        INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = 3
               SET @cOutField14 = @cExtendedInfo
         END
      END
      
      GOTO Quit
   END

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5372. QTY screen
   RPL KEY   (Field01)
   SKU       (Field02)
   SKU Desc1 (Field03)
   SKU Desc2 (Field04)
   Lottable  (Field05)
   Lottable  (Field06)
   Lottable  (Field07)
   Lottable  (Field08)
   DIV PUOM MUOM (Field09)
   RPL QTY   (Field10, Field11)
   ACT QTY   (Field12, Field13, input)
   Ext Info  (Field14)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      DECLARE @cActPQTY NVARCHAR( 5)
      DECLARE @cActMQTY NVARCHAR( 5)

      -- Screen mapping
      SET @cActPQTY = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END
      SET @cActMQTY = @cInField13

      -- Retain the key-in value
      SET @cOutField12 = @cInField12 -- Pref QTY
      SET @cOutField13 = @cInField13 -- Master QTY

      -- Blank to iterate open replenish tasks
      IF @cActPQTY = '' AND @cActMQTY = '' AND @cReplenBySKUQTY <> '1' AND @cRPLKey = ''
      BEGIN
         -- Get task
         EXEC rdt.rdt_Replenish_V7_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cReplenBySKUQTY
            ,@cDisplayQtyAvail
            ,@cFromLOC
            ,@cFromID
            ,@cReplenKey      OUTPUT
            ,@cSKU            OUTPUT
            ,@cLOT            OUTPUT
            ,@cLottableCode   OUTPUT
            ,@cLottable01     OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
            ,@cLottable06     OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
            ,@cLottable11     OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
            ,@nQTY            OUTPUT
            ,@cToLOC          OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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
            '',      -- SourceKey
            @nFunc   -- SourceType

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END

         -- Prep QTY screen var
         SET @cOutField01 = @cReplenKey
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRInG(@cDescr, 1, 20)
         SET @cOutField04 = SUBSTRInG(@cDescr, 21, 20)

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- ActPQTY
         END
         ELSE
         BEGIN
            SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField12 = '' -- ActPQTY
         END
         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
         SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))
         SET @cOutField13 = '' -- ActMQTY

         -- Remain in current screen
         -- SET @nScn  = @nScn + 1
         -- SET @nStep = @nStep + 1

         GOTO Step_3_Quit
      END

      -- Validate ActPQTY
      IF @cActPQTY = ''
         SET @cActPQTY = '0' -- Blank taken as zero

      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 136661
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY
         GOTO Step_3_Fail
      END

      -- Validate ActMQTY
      IF @cActMQTY  = ''
         SET @cActMQTY  = '0' -- Blank taken as zero

      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 136662
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
         GOTO Step_3_Fail
      END

      SET @nActQTY = 0 -- SOS# 274296

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nActQTY = @nActQTY + @nActMQTY

      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 136663
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_3_Fail
      END

      -- Get QTY Avail
      SET @nQTY_Avail = 0
      SELECT @nQTY_Avail = ISNULL( SUM( QTY
         - CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE QTYAllocated END
         - QTYPicked), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND (@cReplenBySKUQTY = '1' OR LOT = @cLOT)
         AND (QTY
            - CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE QTYAllocated END
            - QTYPicked) > 0

      -- Validate QTY to replen more than QTY avail
      IF @nActQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 136664
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAvalNotEnuf
         GOTO Step_3_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField05 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nActPQty
      END
      ELSE
      BEGIN
         SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField09 = CAST( @nActPQty AS NVARCHAR( 5))
      END
      SET @cOutField08 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField10 = CAST( @nActMQty AS NVARCHAR( 5))
      SET @cOutField11 = '' -- ToID
      SET @cOutField12 = @cToLoc
      SET @cOutField13 = '' -- ToLOC

      IF @cReplenEnableTOID = '1'
      BEGIN
         SET @cFieldAttr11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11
      END
      ELSE
      BEGIN
         SET @cFieldAttr11 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 13
      END

      SET @cFieldAttr12 = '' -- ActPQTY

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cRPLKey = ''
      BEGIN
         -- Prepare prev screen
         SET @cSKU = ''
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' -- SKU

         SET @cFieldAttr12 = '' -- ActPQTY

         -- Go to prev screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = '' -- FromLoc
         SET @cOutField02 = '' -- FromID
         SET @cOutField03 = '' -- RPL Key

         IF @cRPLKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromLOC
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- RPLKEY

         -- Go to From LOC screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END

   Step_3_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cReplenKey',   @cReplenKey),
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToLOC',       @cToLOC),
               ('@cToID',        @cToID)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nToStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nToStep        INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = 3
               SET @cOutField14 = @cExtendedInfo
         END
      END
      
      GOTO Quit
   END

   Step_3_Fail:
   BEGIN
      SET @cOutField12 = '' -- ActPQTY
      SET @cOutField13 = '' -- ActMQTY
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 5373. TO LOC, TO ID
   FROM LOC   (Field01)
   FROM ID    (Field02)
   SKU        (Field03)
   SKU Desc 1 (Field04)
   SKU Desc 2 (Field05)
   PUOM MUOM  (Field06, Field07)
   RPL QTY    (Field08, Field09)
   ACT QTY    (Field10, Field11)
   ID         (Field11, input)
   TO LOC     (Field12)
   TO LOC     (Field13, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField11
      SET @cActToLOC = @cInField13

      IF @cReplenEnableTOID = '1'
      BEGIN
         IF @cToID = ''
         BEGIN
            SET @nErrNo = 136677
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO ID required
            EXEC rdt.rdtSetFocusField @nMobile, 15
            GOTO Quit
         END
      END
      ELSE
         SET @cToID = ''

      -- Validate blank
      IF @cActToLOC = '' OR @cActToLOC IS NULL
      BEGIN
         SET @nErrNo = 136672
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_4_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cActToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 136674
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_4_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 136675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_4_Fail
      END

      -- If replenis to different LOC
      IF @cActToLOC <> @cToLoc
      BEGIN
         -- Prep dialog screen var
         SET @cOutField01 = '' -- Option

         -- Go to dialog screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         IF @cRPLKey = ''
            EXEC rdt.rdt_Replenish_V7_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cReplenBySKUQTY
               ,@cMoveQTYAlloc
               ,@cReplenKey
               ,@cFromLOC
               ,@cFromID
               ,@cSKU
               ,@nActQTY
               ,@cUCCNo
               ,@cToLOC
               ,@cToID
               ,@cLottableCode
               ,@cLottable01,   @cLottable02,   @cLottable03,   @dLottable04,   @dLottable05
               ,@cLottable06,   @cLottable07,   @cLottable08,   @cLottable09,   @cLottable10
               ,@cLottable11,   @cLottable12,   @dLottable13,   @dLottable14,   @dLottable15
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
         ELSE
            EXEC rdt.rdt_Replenish_V7_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,'0' -- @cReplenBySKUQTY
               ,@cMoveQTYAlloc
               ,@cReplenKey
               ,@cFromLOC
               ,@cFromID
               ,@cSKU
               ,@nActQTY
               ,@cUCCNo
               ,@cToLOC
               ,@cToID
               ,@cLottableCode
               ,@cLottable01,   @cLottable02,   @cLottable03,   @dLottable04,   @dLottable05
               ,@cLottable06,   @cLottable07,   @cLottable08,   @cLottable09,   @cLottable10
               ,@cLottable11,   @cLottable12,   @dLottable13,   @dLottable14,   @dLottable15
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         -- Go to message screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cUCCNo <> ''
      BEGIN
         SET @cOutField01 = @cFromLOC
         SET @cOutField02 = @cFromID
         SET @cOutField03 = '' -- @cUCC

         -- Go to UCC screen
         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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
            '',      -- SourceKey
            @nFunc   -- SourceType
            
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
         SET @nQTY = @nQTY + @nMQTY

         -- Prep prev screen var
         SET @cOutField01 = @cReplenKey
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
         SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField10 = '' -- @nPQTY
            SET @cOutField12 = '' -- ActPQTY
            SET @cFieldAttr12 = 'O' -- ActPQTY
         END
         ELSE
         BEGIN
            SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField12 = '' -- ActPQTY
         END
         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
         SET @cOutField11 = CAST( @nMQTY AS NVARCHAR( 5))
         SET @cOutField13 = '' -- ActMQTY
         SET @cOutField14 = '' -- ExtendedInfo

         -- Go to QTY screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   Step_4_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cReplenKey',   @cReplenKey),
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToLOC',       @cToLOC),
               ('@cToID',        @cToID)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nToStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nToStep        INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = 3
               SET @cOutField14 = @cExtendedInfo
         END
      END
      
      GOTO Quit
   END

   Step_4_Fail:
   BEGIN
      SET @cOutField13 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 13
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 5374. Confirm diff LOC screen
   REPLEN TO DIFF LOC
   PROCEED? 
   1 = YES
   9 = NO
   OPTION (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 136669
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_5_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 136670
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_5_Fail
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF @cRPLKey = ''
            EXEC rdt.rdt_Replenish_V7_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cReplenBySKUQTY
               ,@cMoveQTYAlloc
               ,@cReplenKey
               ,@cFromLOC
               ,@cFromID
               ,@cSKU
               ,@nActQTY
               ,@cUCCNo
               ,@cToLOC
               ,@cToID
               ,@cLottable01,   @cLottable02,   @cLottable03,   @dLottable04,   @dLottable05
               ,@cLottable06,   @cLottable07,   @cLottable08,   @cLottable09,   @cLottable10
               ,@cLottable11,   @cLottable12,   @dLottable13,   @dLottable14,   @dLottable15
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
         ELSE
            EXEC rdt.rdt_Replenish_V7_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,'0' -- @cReplenBySKUQTY
               ,@cMoveQTYAlloc
               ,@cReplenKey
               ,@cFromLOC
               ,@cFromID
               ,@cSKU
               ,@nActQTY
               ,@cUCCNo
               ,@cToLOC
               ,@cToID
               ,@cLottable01,   @cLottable02,   @cLottable03,   @dLottable04,   @dLottable05
               ,@cLottable06,   @cLottable07,   @cLottable08,   @cLottable09,   @cLottable10
               ,@cLottable11,   @cLottable12,   @dLottable13,   @dLottable14,   @dLottable15
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         -- Go to message screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END
   END

   -- Prep next screen var
   SET @cOutField01 = @cFromLoc
   SET @cOutField02 = @cFromID
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cDescr, 1, 20)
   SET @cOutField05 = SUBSTRING( @cDescr, 21, 20)
   SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
   IF @cPUOM_Desc = ''
   BEGIN
      SET @cOutField07 = '' -- @nPQTY
      SET @cOutField09 = '' -- @nActPQty
   END
   ELSE
   BEGIN
      SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
      SET @cOutField09 = CAST( @nActPQty AS NVARCHAR( 5))
   END
   SET @cOutField08 = CAST( @nMQTY AS NVARCHAR( 5))
   SET @cOutField10 = CAST( @nActMQty AS NVARCHAR( 5))
   SET @cOutField11 = '' -- ToID
   SET @cOutField12 = @cToLoc
   SET @cOutField13 = '' -- ToLOC

   IF @cReplenEnableTOID = '1'
   BEGIN
      SET @cFieldAttr11 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 11
   END
   ELSE
   BEGIN
      SET @cFieldAttr11 = 'O'
      EXEC rdt.rdtSetFocusField @nMobile, 13
   END

      -- Go to TO LOC screen
   SET @nScn  = @nScn - 1
   SET @nStep = @nStep - 1

   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 5375. Successful screen
   Message
********************************************************************************/
Step_6:
BEGIN
  -- EventLog
  EXEC RDT.rdt_STD_EventLog
     @cActionType   = '5', -- RPL
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = @cStorerkey,
     @cLocation     = @cFromLOC,
     @cToLocation   = @cActToLOC,
     @cID           = @cFromID,
     @cSKU          = @cSKU,
     @cUOM          = @cMUOM_Desc,
     @nQTY          = @nActQty,
     @cUCC          = @cUCCNo, 
     @cRefNo1       = @cReplenKey

   -- Prep FromLOC screen
   SET @cOutField01 = '' -- FromLOC
   SET @cOutField02 = '' -- FromID
   SET @cOutField03 = '' -- RPL KEY

   IF @cRPLKey = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromLOC
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- RPL Key

   -- Go to FromLOC screen
   SET @nScn  = @nScn - 5
   SET @nStep = @nStep - 5
END
GOTO Quit


/********************************************************************************
Step 7. Screen 5376. UCC screen
   FROM LOC (Field01)
   FROM ID  (Field02)
   UCC      (Field03, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField03
      SET @cBarcode = @cInField03

      -- Check blank
      IF @cUCCNo = ''
      BEGIN
         SET @nErrNo = 136678
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC needed
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo  = @cUCCNo      OUTPUT,
               @nErrNo  = @nErrNo      OUTPUT,
               @cErrMsg = @cErrMsg     OUTPUT,
               @cType   = 'UCCNo'

               IF @nErrNo <> 0
                  GOTO Step_7_Fail
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cFromID     OUTPUT, @cFromLOC    OUTPUT, @cToID       OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQty         INT            OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo      OUTPUT, @cFromLoc     OUTPUT, @cToID       OUTPUT,
               @cToLOC      OUTPUT, @cSKU         OUTPUT, @nQty        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07  OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12  OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg      OUTPUT

            IF @nErrNo <> 0
               GOTO Step_7_Fail
         END
      END

      -- Check UCC valid
      IF @cRPLKey <> ''
      BEGIN
         EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
            ,@cUCCNo -- UCC
            ,@cStorerKey
            ,'134'    -- 1=Received, 3=Alloc, 4=Replen
            ,@cChkLOC = @cFromLOC
            ,@cChkID  = @cFromID
            ,@cChkSKU = @cSKU
            ,@nChkQTY = @nQTY
         IF @nErrNo <> 0
            GOTO Step_7_Fail
      END
      ELSE
      BEGIN
         EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
            ,@cUCCNo -- UCC
            ,@cStorerKey
            ,'134'    -- 1=Received, 3=Alloc, 4=Replen
            ,@cChkLOC = @cFromLOC
            ,@cChkID  = @cFromID
         IF @nErrNo <> 0
            GOTO Step_7_Fail
      END
      
      -- Swap UCC
      IF @cSwapUCCSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapUCCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapUCCSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, @cRPLKey, ' +
               ' @cFromLOC    OUTPUT, @cFromID     OUTPUT, @cReplenKey  OUTPUT, ' + 
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cUCCNo      OUTPUT, ' +
               ' @cToID       OUTPUT, @cToLOC      OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cFacility    NVARCHAR( 5),    ' +
               ' @cBarcode     NVARCHAR( 60),   ' +
               ' @cRPLKey      NVARCHAR( 10),   ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cReplenKey   NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cUCCNo       NVARCHAR( 20)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, @cRPLKey, 
               @cFromLoc    OUTPUT, @cFromID      OUTPUT, @cReplenKey  OUTPUT, 
               @cSKU        OUTPUT, @nQTY         OUTPUT, @cUCCNo      OUTPUT, 
               @cToID       OUTPUT, @cToLOC       OUTPUT, 
               @cLottable01 OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07  OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12  OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg      OUTPUT

            IF @nErrNo <> 0
               GOTO Step_7_Fail
         END
      END
      ELSE
      BEGIN
         -- Check UCC on replenish task
         IF @cRPLKey <> '' 
         BEGIN
            IF @cUCCNo <> @cRefNo
            BEGIN
               SET @nErrNo = 136679
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC Not in RPL'
               GOTO Step_7_Fail
            END
         END
         ELSE
         BEGIN
            -- Get replen task info
            SELECT 
               @cReplenKey = ReplenishmentKey, 
               @cToLOC = ToLOC
            FROM dbo.Replenishment WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND FromLoc = @cFromLoc
               AND ID = @cFromID
               AND RefNo = @cUCCNo
               AND Confirmed = 'N'
            
            -- Check task valid
            IF @cReplenKey = ''
            BEGIN
               SET @nErrNo = 136680
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC Not in RPL'
               GOTO Step_7_Fail
            END
         END     
      END

      IF @cRPLKey = '' 
      BEGIN
         -- Get replen task info
         SELECT @cToLOC = ToLOC
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE ReplenishmentKey = @cReplenKey
         
         -- Get UCC info
         SELECT 
            @cSKU = SKU, 
            @nQTY = QTY, 
            @nActQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCCNo
      
         -- Get Pack info
         SELECT
            @cDescr = SKU.Descr,
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
            @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END
      END
      
      -- Prep next screen var
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField05 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + CAST( @cPUOM_Desc AS NCHAR( 5)) + ' ' + CAST( @cMUOM_Desc AS NCHAR( 5))
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nActPQty
      END
      ELSE
      BEGIN
         SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField09 = CAST( @nPQTY AS NVARCHAR( 5))
      END
      SET @cOutField08 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField10 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField11 = '' -- ToID
      SET @cOutField12 = @cToLoc
      SET @cOutField13 = '' -- ToLOC

      IF @cReplenEnableTOID = '1'
      BEGIN
         SET @cFieldAttr11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11
      END
      ELSE
      BEGIN
         SET @cFieldAttr11 = 'O'
         EXEC rdt.rdtSetFocusField @nMobile, 13
      END

      -- Go to TOLOC, TOID screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen
      SET @cOutField01 = '' -- FromLoc
      SET @cOutField02 = '' -- FromID
      SET @cOutField03 = '' -- RPL KEY

      IF @cRPLKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromLOC
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- RPLKEY

      SET @nScn  = @nScn - 6
      SET @nStep = @nStep - 6
   END

   Step_7_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cReplenKey',   @cReplenKey),
               ('@cFromLOC',     @cFromLOC),
               ('@cFromID',      @cFromID),
               ('@cSKU',         @cSKU),
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
               ('@cToLOC',       @cToLOC),
               ('@cToID',        @cToID)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nToStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nToStep        INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = 3
               SET @cOutField14 = @cExtendedInfo
         END
      END
      
      GOTO Quit
   END

   Step_7_Fail:
   BEGIN
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cFromID
      SET @cOutField03 = '' -- ucc
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

      V_SKU     = @cSKU,
      V_SKUDescr= @cDescr,
      V_UOM     = @cPUOM,
      V_LOT     = @cLOT,
      V_LOC     = @cFromLoc,
      V_ID      = @cFromID,
      V_UCC     = @cUCCNo, 

      V_PUOM_Div  = @nPUOM_Div,
      V_TaskQTY   = @nQTY, 
      V_MTaskQTY  = @nMQTY,
      V_PTaskQTY  = @nPQTY,
      V_MQTY      = @nActMQTY,
      V_PQTY      = @nActPQTY,
      V_QTY       = @nActQty,

      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      V_Lottable06   = @cLottable06,
      V_Lottable07   = @cLottable07,
      V_Lottable08   = @cLottable08,
      V_Lottable09   = @cLottable09,
      V_Lottable10   = @cLottable10,
      V_Lottable11   = @cLottable11,
      V_Lottable12   = @cLottable12,
      V_Lottable13   = @dLottable13,
      V_Lottable14   = @dLottable14,
      V_Lottable15   = @dLottable15,

      V_String1  = @cToLOC,
      V_String2  = @cActToLOC,
      V_String3  = @cMUOM_Desc,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cReplenKey,

      V_String12 = @cToID,
      V_String13 = @cRPLKey,
      V_String15 = @cRefNo, 
      
      V_String20 = @cReplenBySKUQTY,
      V_String21 = @cDisplayQtyAvail,
      V_String22 = @cReplenEnableTOID,
      V_String23 = @cMoveQTYAlloc,
      V_String24 = @cUCCStorerConfig,
      V_String25 = @cExtendedInfoSP,
      V_String26 = @cDecodeSP,
      V_String27 = @cSwapUCCSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile

END

GO