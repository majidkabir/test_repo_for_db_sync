SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Move pallet                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-08-23 1.0  UngDH    Created                                     */
/* 2006-01-18 1.1  UngDH    Support config 'MoveToLOCNotCheckFacility'  */
/* 2009-07-06 1.2  Vicky    Add in EventLog (Vicky06)                   */
/* 2010-10-25 1.3  ChewKP   SOS#191975 DefaultFromLoc of Pallet         */
/*                          (ChewKP01)                                  */
/* 2010-09-15 1.4  Shong    QtyAvailable Should exclude QtyReplen       */
/* 2011-05-16 1.5  Ung      SOS 215229. Add FromLOC same as ToLOC check */
/* 2011-11-11 1.6  ChewKP   LCI Project Changes Update UCC Table        */
/*                          (ChewKP02)                                  */
/* 2012-05-25 1.7  Ung      SOS243024 ToLOC lookup logic (ung01)        */
/* 2012-07-19 1.8  ChewKP   SOS#250946 - Move UCC Update to SP rdt_Move */
/*                          (ChewKP03)                                  */
/* 2012-07-30 1.9  James    Bug Fix on get no of distinct loc (james01) */
/* 2013-05-03 2.0  James    SOS276237 - Allow multi storer (james02)    */
/* 2013-11-22 2.1  James    SOS295127 - Show TOLOC on sucessfull move   */
/*                          screen (james03)                            */
/* 2015-04-24 2.2  Ung      SOS340174 Add ExtendedUpdateSP              */
/* 2015-08-24 2.3  James    SOS350166 - Enable storergroup (james04)    */
/* 2015-09-02 2.4  James    SOS315483 - Add extended validate (james05) */
/* 2016-06-10 2.5  James    IN00066814 - Add storer checking (james06)  */
/* 2016-04-07 2.6  ChewKP   SOS#368018 - Support RDT Configkey          */
/*                          MoveQTYPick, MoveQTYAlloc (ChewKP04)        */
/* 2016-09-30 2.7  Ung      Performance tuning                          */
/* 2017-01-06 2.8  Ung      Fix int overflow when load rdtmobrec        */
/* 2017-05-22 2.9  James    WMS1945-Enhance qty display on screen based */
/*                          on storer configuration (james07)           */
/* 2018-06-04 3.0  James    WMS5305-Add rdt_decode sp (james08)         */
/* 2018-10-02 3.1  TungGH   Performance                                 */
/* 2019-01-07 3.2  James    WMS7487-Add ExtendedInfoSP (james09)        */
/* 2019-03-05 3.3  YeeKung  WMS-8085/WMS-8122 add loc prefix (yeekung01)*/
/* 2019-06-18 3.4  JihHaur  Arithmetic overflow (JH01)                  */
/* 2019-07-12 3.5  James    WMS9712 Remove @nErrNo & @cErrMsg output    */
/*                          from rdt_Decode (james10)                   */
/* 2019-10-18 3.6  James    WMS-10922 Add ExtValid in step 1 (james11)  */
/* 2022-01-23 3.7  Ung      WMS-18784 Fix DefaultFromLOC                */
/* 2022-07-05 3.8  Calvin	Fixed Cursor variable (CLVN01)              */
/* 2024-03-06 3.9  CYU027   UWP-15739 Created, for Unilever            */
/* 2024-05-21 4.0  Dennis   FCR-336 Check Digit                         */
/************************************************************************/

CREATE     PROCEDURE [RDT].[rdtfnc_Move_ID] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @i             INT,
   @nRowCount     INT,
   @cChkFacility  NVARCHAR( 5),
   @cPUOM_Desc    NVARCHAR( 5), -- Preferred UOM desc
   @cMUOM_Desc    NVARCHAR( 5), -- Master unit desc
   @nPUOM_Div     INT, -- UOM divider
   @nPQTY         INT, -- Preferred UOM QTY
   @nMQTY         INT, -- Master unit QTY
   @nQTY          INT,

   @cLoop_StorerKey     NVARCHAR( 15),    -- (james02)
   @cSKU_StorerKey      NVARCHAR( 15)     -- (james02)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerGroup    NVARCHAR( 20),
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR(18), -- (Vicky06)

   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @cPUOM         NVARCHAR( 1), -- Prefer UOM
   @cLOCCheckDigitSP    NVARCHAR( 20),
   @cCheckDigitLOC      NVARCHAR( 20),
   @cFromLOC            NVARCHAR( 10),
   @cFromID             NVARCHAR( 18),
   @cToLOC              NVARCHAR( 10),
   @nTotalRec           INT,
   @nCurrentRec         INT,
   @cToLOCLookupSP      NVARCHAR(20),  -- (ung01)
   @nMultiStorer        INT,           -- (james02)
   @cExtendedUpdateSP   NVARCHAR(20),
   @cChkStorerKey       NVARCHAR( 15), -- (james04)
   @cExtendedValidateSP NVARCHAR( 20), -- (james05)
   @cSQL                NVARCHAR(MAX), -- (james05)
   @cSQLParam           NVARCHAR(MAX), -- (james05)
   @cMoveQTYAlloc       NVARCHAR( 1),  -- (ChewKP04)
   @cMoveQTYPick        NVARCHAR( 1),  -- (ChewKP04)
   @nQTYPick            INT,           -- (james07)
   @nQTYAlloc           INT,           -- (james07)
   @cBarcode            NVARCHAR( 60),
   @cDecodeSP           NVARCHAR( 20),
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
   @cExtendedInfo       NVARCHAR( 20),    -- (james09)
   @cExtendedInfoSP     NVARCHAR( 20),    -- (james09)
   @cSuggestLocSP       NVARCHAR( 20),    -- (CYU027)
   @cLOCLookupSP        NVARCHAR( 20),    -- (yeekung01)
   @cDefaultFromLOC     NVARCHAR( 1),

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerGroup  = StorerGroup,
   @cFacility   = Facility,
   @cUserName   = UserName,-- (Vicky06)

   @cStorerKey = V_StorerKey,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @cPUOM      = V_UOM,

   @cFromID             = V_String1,
   @cFromLOC            = V_String2,
   @cToLOC              = V_String3,
   @cExtendedInfoSP     = V_String4,
   @cExtendedValidateSP = V_String5,
   @cToLOCLookupSP      = V_String6, --(ung01)
   @cExtendedUpdateSP   = V_String8,
   @cMoveQTYPick        = V_String9, -- (ChewKP04)
   @cMoveQTYAlloc       = V_String10,-- (ChewKP04)
   @cDecodeSP           = V_String11,
   @cLOCLookupSP        = V_String12, --(yeekung01)
   @cDefaultFromLOC     = V_String13,
   @cSuggestLocSP       = V_String14, --(CYU027)

   @nTotalRec           = V_Integer1,
   @nCurrentRec         = V_Integer2,
   @nMultiStorer        = V_Integer3,   -- (james25)

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 511 -- Move (generic)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move (generic)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1000. FromID
   IF @nStep = 2 GOTO Step_2   -- Scn = 1001. FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1002. SKU, Desc, UOM, QTY, ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1003. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 511. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1000
   SET @nStep = 1

   -- Prep next screen var
   SET @cFromID = ''
   SET @cFromLOC = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cToLOC = ''

   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get storer configure
   SET @cDefaultFromLOC = rdt.RDTGetConfig( @nFunc, 'DefaultFromLOC', @cStorerKey)
   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc, 'LOCLookupSP', @cStorerKey)
   SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cSuggestLocSP = rdt.rdtGetConfig( @nFunc, 'SuggestLocSP', @cStorerKey)
   IF @cSuggestLocSP = '0'
       SET @cSuggestLocSP = ''

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Init screen
   SET @cOutField01 = '' -- FromID
   SET @cOutField02 = '' -- FromLOC
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1000. FromID
   FromID  (field01, input)
   FromLOC (field02)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
      SET @cBarcode = @cInField01

      SET @cFromLOC = ''

      -- Validate blank
      IF @cFromID = '' OR @cFromID IS NULL
      BEGIN
         SET @nErrNo = 62351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ID needed'
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
               @cID     = @cFromID OUTPUT,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cID         OUTPUT, @cFromLOC    OUTPUT, @cToLOC      OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,             ' +
               ' @nFunc        INT,             ' +
               ' @cLangCode    NVARCHAR( 3),    ' +
               ' @nStep        INT,             ' +
               ' @nInputKey    INT,             ' +
               ' @cStorerKey   NVARCHAR( 15),   ' +
               ' @cBarcode     NVARCHAR( 2000), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,
               @cFromID     OUTPUT, @cFromLOC    OUTPUT, @cToLOC      OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- If ID or SKU having more than 1 storer then is multi storer else turn multi storer off
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     WHERE EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
                     --AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                     AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked -
                           (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                     AND    LLI.ID = @cFromID
                     GROUP BY ID
                     HAVING COUNT( DISTINCT StorerKey) > 1)
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                            WHERE  LLI.ID = @cFromID
                            AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked -
                                  (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                            AND   EXISTS ( SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK)
                                           WHERE SG.StorerGroup = @cStorerGroup
                                           AND SG.StorerKey = LLI.StorerKey))
            BEGIN
               SET @nErrNo = 62364
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cChkStorerKey = StorerKey
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE  ID = @cFromID
               AND   (QTY - QTYAllocated - QTYPicked -
                     (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0

               -- Set session storer
               SET @cStorerKey = @cChkStorerKey
               SET @nMultiStorer = 1
            END
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            WHERE ID = @cFromID
               AND (QTY - QTYPicked - QtyAllocated -
                   (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0

            -- (james06)
            -- Check if record exists in inventory table
            IF ISNULL( @cChkStorerKey, '') = ''
            BEGIN
               SET @nErrNo = 62366
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid record
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_1_Fail
            END

            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
            BEGIN
               SET @nErrNo = 62365
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END

            -- Set session storer
            SET @cStorerKey = @cChkStorerKey
            SET @nMultiStorer = 0
         END
      END

      -- Get ID info
      IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '0'
      BEGIN

         IF NOT EXISTS( SELECT 1
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
               AND ID = @cFromID
               AND (QTY - QTYPicked - QtyAllocated - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
         BEGIN
            SET @nErrNo = 62352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ID'
            GOTO Step_1_Fail
         END
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cFromID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
            END
         END
      END

      -- Auto default pallet LOC (if only 1 LOC)
      IF @cDefaultFromLOC = '1'
      BEGIN
         -- Count pallet LOC
         SELECT @nRowCount = COUNT( DISTINCT LOC)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE ID = @cFromID
            AND LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND QTY -
               (CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE LLI.QTYAllocated END) -
               (CASE WHEN @cMoveQTYPick = '1'  THEN 0 ELSE LLI.QTYPicked END) -
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
               > 0

         -- Pallet with multi LOC
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 62360
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'From Loc > 1'
            -- GOTO Step_1_Fail
         END

         -- Pallet with 1 LOC
         IF @nRowCount = 1
         BEGIN
            -- Get pallet LOC
            SELECT TOP 1
               @cFromLOC = LOC
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE ID = @cFromID
            AND LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND QTY -
               (CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE LLI.QTYAllocated END) -
               (CASE WHEN @cMoveQTYPick = '1'  THEN 0 ELSE LLI.QTYPicked END) -
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
               > 0
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cFromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Flow thru from LOC screen
      IF @cFromLOC <> ''
      BEGIN
         SET @cInField02 = @cFromLOC

         GOTO Step_2
      END
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
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromID  = ''
      SET @cOutField01 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1001. FromLOC
   FromID  (field01)
   FromLOC (field02, input)
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
         SET @nErrNo = 62353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_2_Fail
      END
      SET @cCheckDigitLOC = @cInField02
      SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)
      IF @cLOCCheckDigitSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
         SET @cFromLOC = @cCheckDigitLOC
      END

      -- add loc prefix (yeekung01)
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cFromLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 62355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_2_Fail
      END

      -- (james02)
      --If for the loc+id entered, there is record in lotxlocxid.storerkey not defined in
      -- storergroup.storerkey, error message should be prompted.
      IF @nMultiStorer = 1
      BEGIN
         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT(1)
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE LLI.ID = @cFromID
         AND   LLI.LOC = @cFromLOC
         AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         AND   LOC.Facility = @cFacility
         AND   NOT EXISTS (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)

         IF @nTotalRec >= 1
         BEGIN
            SET @nErrNo = 62363
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC INV STORER'
            GOTO Step_2_Fail
         END
      END

      -- Get total record
      SET @nTotalRec = 0

      IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '0'
      BEGIN
         SELECT
            @nTotalRec = COUNT( DISTINCT SKU.SKU), -- Total no of SKU
            @nQTYAlloc = IsNULL( SUM( LLI.QTYAllocated + LLI.QtyPicked + (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0

         -- Validate QTY allocated
         IF @nQTYAlloc > 0
         BEGIN
            SET @nErrNo = 62357
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY allocated'
            GOTO Step_2_Fail
         END
      END
      ELSE
      IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '1'
      BEGIN
         SELECT
            @nTotalRec = COUNT( DISTINCT SKU.SKU) -- Total no of SKU
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND ( LLI.QTY - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
      END
      ELSE
      IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '1'
      BEGIN
         SELECT
            @nTotalRec = COUNT( DISTINCT SKU.SKU), -- Total no of SKU
            @nQTYPick = IsNULL( SUM( LLI.QtyPicked), 0)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND ( LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0

         -- Validate QTY pickeded
         IF @nQTYPick > 0
         BEGIN
            SET @nErrNo = 62367
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY Picked'
            GOTO Step_2_Fail
         END
      END
      ELSE  -- IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '0'
      BEGIN
         SELECT
            @nTotalRec = COUNT( DISTINCT SKU.SKU), -- Total no of SKU
            @nQTYAlloc = IsNULL( SUM( LLI.QTYAllocated), 0)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0

         -- Validate QTY allocated
         IF @nQTYAlloc > 0
         BEGIN
            SET @nErrNo = 62368
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY allocated'
            GOTO Step_2_Fail
         END
      END

      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 62356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'
         GOTO Step_2_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cFromID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_2_Fail
            END
         END
      END

      -- Get LOTxLOCxID info
      IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '0'
      BEGIN
         SELECT TOP 1
            @cSKU_StorerKey = SKU.StorerKey,
            @cSKU = SKU.SKU,
            @nQTY = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         GROUP BY SKU.StorerKey, SKU.SKU
         ORDER BY SKU.SKU
      END
      ELSE
      IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '1'
      BEGIN
         SELECT TOP 1
            @cSKU_StorerKey = SKU.StorerKey,
            @cSKU = SKU.SKU,
            @nQTY = SUM( LLI.QTY - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         GROUP BY SKU.StorerKey, SKU.SKU
         ORDER BY SKU.SKU
      END
      ELSE
      IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '1'
      BEGIN
         SELECT TOP 1
            @cSKU_StorerKey = SKU.StorerKey,
            @cSKU = SKU.SKU,
            @nQTY = SUM( LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
            AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         GROUP BY SKU.StorerKey, SKU.SKU
         ORDER BY SKU.SKU
      END
      ELSE  --       IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '0'
      BEGIN
         SELECT TOP 1
            @cSKU_StorerKey = SKU.StorerKey,
            @cSKU = SKU.SKU,
            @nQTY = SUM( LLI.QTY - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.ID = @cFromID
            AND LLI.LOC = @cFromLOC
  AND (LLI.QTY - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         GROUP BY SKU.StorerKey, SKU.SKU
         ORDER BY SKU.SKU
      END

      -- Get Pack info
      SELECT
         @cSKUDescr = SKU.Descr,
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
      FROM dbo.SKU SKU (NOLOCK)
         INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
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

      -- Extended update
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cToID, @cSKU, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cExtendedInfo   NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cFromID, @cSKU, @cExtendedInfo OUTPUT

            SET @cOutField12 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
         END
      END

      SET @cOutField11 = '' -- ToLOC
      IF @cSuggestLocSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
                        ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @cType, ' +
                        ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
                        ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
                        ' @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT, ' +
                        ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
                          ' @nMobile         INT,                  ' +
                          ' @nFunc  INT,                  ' +
                          ' @cLangCode       NVARCHAR( 3),         ' +
                          ' @cStorerKey      NVARCHAR( 15),        ' +
                          ' @cFacility       NVARCHAR(  5),        ' +
                          ' @cFromLOC        NVARCHAR( 10),        ' +
                          ' @cFromID         NVARCHAR( 18),        ' +
                          ' @cSKU            NVARCHAR( 20),        ' +
                          ' @nQTY            INT,                  ' +
                          ' @cToID           NVARCHAR( 18),        ' +
                          ' @cToLOC          NVARCHAR( 10),        ' +
                          ' @cType           NVARCHAR( 10),        ' +
                          ' @cOutField01     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField02     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField03     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField04     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField05     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField06     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField07     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField08     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField09     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField10     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField11     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField12     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField13     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField14     NVARCHAR( 20) OUTPUT, ' +
                          ' @cOutField15     NVARCHAR( 20) OUTPUT, ' +
                          ' @nErrNo          INT           OUTPUT, ' +
                          ' @cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cFromID, @cToLOC, 'VAS',
                  @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
                  @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT,
                  @cOutField11 OUTPUT, @cOutField12 OUTPUT, @cOutField13 OUTPUT, @cOutField14 OUTPUT, @cOutField15 OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0 AND
               @nErrNo <> -1
                GOTO Quit
         END
      END

      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cToLOC = ''
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cFromLOC
      SET @cOutField03 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField04 = @cSKU
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField07 = @cPUOM_Desc
      SET @cOutField08 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField09 = @cMUOM_Desc
      SET @cOutField10 = CAST( @nMQTY AS NVARCHAR( 7)) --(JH01)  NVARCHAR( 5)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cFromID = ''
      SET @cFromLOC = ''
      SET @cOutField01 = '' -- FromID
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromLOC  = ''
      SET @cOutField02 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 1002. ToLOC
   FromID    (field01)
   FromLOC   (field02)
   Counter   (field03)
   SKU       (field04)
   Desc1     (field05)
   Desc2     (field06)
   PUOM_Desc (field07)
   PQTY      (field08)
   MUOM_Desc (filed09)
   MQTY      (field10)
   ToLOC     (field11)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField11

      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         IF @nCurrentRec = @nTotalRec
            SET @nCurrentRec = 0

         -- Get LOTxLOCxID info
         DECLARE @curLLI CURSOR
         IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '0'
            SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT
                  SKU.StorerKey,
                  SKU.SKU,
                  SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
                  AND LLI.ID = @cFromID
                  AND LLI.LOC = @cFromLOC
                  AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                  AND 1 = CASE WHEN @nMultiStorer = 1 THEN (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
                          ELSE 1 END
               GROUP BY SKU.StorerKey, SKU.SKU
               ORDER BY SKU.SKU
         ELSE
         IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '1'
            SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT
                  SKU.StorerKey,
                  SKU.SKU,
                  SUM( LLI.QTY - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
                  AND LLI.ID = @cFromID
                  AND LLI.LOC = @cFromLOC
                  AND (LLI.QTY - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                  AND 1 = CASE WHEN @nMultiStorer = 1 THEN (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
                          ELSE 1 END
               GROUP BY SKU.StorerKey, SKU.SKU
               ORDER BY SKU.SKU
         ELSE
         IF @cMoveQTYPick = '0' AND  @cMoveQTYAlloc = '1'
            SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT
                  SKU.StorerKey,
                  SKU.SKU,
                  SUM( LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
                  AND LLI.ID = @cFromID
                  AND LLI.LOC = @cFromLOC
                  AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                  AND 1 = CASE WHEN @nMultiStorer = 1 THEN (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
                          ELSE 1 END
               GROUP BY SKU.StorerKey, SKU.SKU
               ORDER BY SKU.SKU
         ELSE  -- IF @cMoveQTYPick = '1' AND  @cMoveQTYAlloc = '0'
            SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT
                  SKU.StorerKey,
                  SKU.SKU,
                  SUM( LLI.QTY - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
                  AND LLI.ID = @cFromID
                  AND LLI.LOC = @cFromLOC
                  AND (LLI.QTY - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                  AND 1 = CASE WHEN @nMultiStorer = 1 THEN (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
                          ELSE 1 END
               GROUP BY SKU.StorerKey, SKU.SKU
               ORDER BY SKU.SKU

         OPEN @curLLI
         FETCH NEXT FROM @curLLI INTO @cSKU_StorerKey, @cSKU, @nQTY

         -- Skip to the record
         SET @i = 1
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i > @nCurrentRec BREAK
            SET @i = @i + 1
            FETCH NEXT FROM @curLLI INTO @cSKU_StorerKey, @cSKU, @nQTY
         END

         -- Get Pack info
         SELECT
            @cSKUDescr = SKU.Descr,
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
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.Pack Pack (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
            AND SKU.SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
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

         -- Extended update
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cToID, @cSKU, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     +
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromID         NVARCHAR( 18), ' +
                  '@cFromLOC        NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@cToID           NVARCHAR( 18), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@cExtendedInfo   NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cFromID, @cSKU, @cExtendedInfo OUTPUT

               SET @cOutField12 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
            END
         END

         -- Prep next screen var
         SET @nCurrentRec = @nCurrentRec + 1
         SET @cToLOC = ''
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cFromLOC
         SET @cOutField03 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField06 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField07 = @cPUOM_Desc
         SET @cOutField08 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
         SET @cOutField09 = @cMUOM_Desc
         SET @cOutField10 = CAST( @nMQTY AS NVARCHAR( 5))
         SET @cOutField11 = '' -- ToLOC

         GOTO Quit
      END

      SET @cCheckDigitLOC = @cInField11
      SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)
      IF @cLOCCheckDigitSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_3_Fail
         SET @cToLOC = @cCheckDigitLOC
      END

      SET @cToLOCLookupSP = rdt.RDTGetConfig( @nFunc, 'MoveByIDToLOCLookup', @cStorerkey) --(ung01)
      IF @cToLOCLookupSP = '0'
         SET @cToLOCLookupSP = ''

      -- add loc prefix (yeekung01)
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cToLOC      OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END

      -- ToLOC lookup (ung01)
      IF @cToLOCLookupSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cToLOCLookupSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC ' + RTRIM( @cToLOCLookupSP) + ' @cFromID, @cFromLOC, @cStorerKey, @cSKU, @cToLOC OUTPUT'
            SET @cSQLParam =
               '@cFromID    NVARCHAR( 18), ' +
               '@cFromLOC   NVARCHAR( 10), ' +
               '@cStorerKey NVARCHAR( 15), ' +
               '@cSKU       NVARCHAR( 20), ' +
               '@cToLOC     NVARCHAR( 10) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @cFromID
               ,@cFromLOC
               ,@cStorerKey
               ,@cSKU
               ,@cToLOC OUTPUT
         END
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_3_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 62359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_3_Fail
         END

      -- Validate FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         SET @nErrNo = 62361
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Same FromToLOC'
         GOTO Step_3_Fail
      END


      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromID, @cFromLOC, @cToLOC, @cFromID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_3_Fail
            END
         END
      END

      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_Move_ID

      IF @nMultiStorer = 0
      BEGIN
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdtfnc_Move_ID',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,
            @cToID       = NULL,  -- NULL means not changing ID
            @nFunc       = @nFunc

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_Move_ID
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- (james02)
         -- Using loop here to make sure every move is within storerkey defined in storergroup
         DECLARE @curStorer CURSOR
         SET @curStorer = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT StorerKey
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            WHERE LLI.LOC = @cFromLOC
            AND   LLI.ID = @cFromID
            AND   EXISTS (SELECT 1 from dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
         OPEN @curStorer										--(CLVN01)
         FETCH NEXT FROM @curStorer INTO @cLoop_StorerKey		--(CLVN01)
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Loop thru every storer within the pallet id
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT,
               @cSourceType = 'rdtfnc_Move_ID',
               @cStorerKey  = @cLoop_StorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,
               @cToID       = NULL,  -- NULL means not changing ID
               @nFunc       = @nFunc

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Move_ID
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_3_Fail
            END

            FETCH NEXT FROM @curStorer INTO @cLoop_StorerKey
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cFromID, @cFromLOC, @cToLoc, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@nInputKey      INT,           ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cFromID        NVARCHAR( 18), ' +
               '@cFromLOC       NVARCHAR( 10), ' +
               '@cToLOC         NVARCHAR( 10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cFromID, @cFromLOC, @cToLoc,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Move_ID
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_3_Fail
            END
         END
      END

      COMMIT TRAN rdtfnc_Move_ID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cLocation     = @cFromLOC,
         @cToLocation   = @cToLOC,
         @cID           = @cFromID,
         @nStep         = @nStep

      -- Prepare next screen var
      SET @cOutField01 = @cToLOC -- (james03)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cFromID
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField11 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 1003. Message screen
   Msg
********************************************************************************/
Step_4:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3

   -- Prep next screen var
   SET @cFromID = ''
   SET @cFromLOC = ''

   SET @cOutField01 = '' -- FromID
   SET @cOutField02 = '' -- FromLOC
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

      Facility  = @cFacility,
      -- UserName  = @cUserName,-- (Vicky06)

      V_StorerKey = @cStorerKey,
      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,
      V_UOM       = @cPUOM,

      V_String1   = @cFromID,
      V_String2   = @cFromLOC,
      V_String3   = @cToLOC,
      V_String4   = @cExtendedInfoSP,
      V_String5   = @cExtendedValidateSP,
      V_String6   = @cToLOCLookupSP,
      V_String8   = @cExtendedUpdateSP,
      V_string9   = @cMoveQTYPick, -- (ChewKP04)
      V_String10  = @cMoveQTYAlloc, -- (ChewKP04)
      V_String11  = @cDecodeSP,
      V_String12  = @cLOCLookupSP, -- (yeekung01)
      V_String13  = @cDefaultFromLOC,
      V_String14 =  @cSuggestLocSP,-- (CYU027)

      V_Integer1  = @nTotalRec,
      V_Integer2  = @nCurrentRec,
      V_Integer3  = @nMultiStorer,   -- (james25)

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO