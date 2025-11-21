SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Move pallet                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-09-26 1.0  UngDH    Created                                     */
/* 2006-01-18 1.1  UngDH    Support config 'MoveToLOCNotCheckFacility'  */
/* 2007-04-27 1.2  James    SOS67842 Add no. of move that can be        */
/*                          performed per session                       */
/* 2008-04-08 1.3  James    1. Change loading of variable @nTotalMoveCnt*/
/*                          2. Fix bug on no display FromLoc after ESC  */
/*                          step 4                                      */
/* 2009-05-29 1.4  Vicky    SOS#137962 - Add TO ID field scanning       */
/*                          (Vicky01)                                   */
/* 2009-07-06 1.5  Vicky    Add in EventLog (Vicky06)                   */
/* 2010-09-15 1.6  Shong    QtyAvailable Should exclude QtyReplen       */
/* 2011-11-11 1.7  ChewKP   LCI Project Changes Update UCC Table        */
/*                          (ChewKP01)                                  */
/* 2011-02-14 1.8  James    Update toid to ucc table (james01)          */
/* 2012-07-19 1.9  ChewKP   SOS#250946 - Move UCC Update to SP rdt_Move */
/*                          (ChewKP02)                                  */
/* 2013-02-26 2.0  Shong    Revised Qty Allocated Checking              */
/* 2013-05-03 2.1  James    SOS276237 - Allow multi storer (james02)    */
/* 2013-11-22 2.2  James    SOS295127 - Show TOLOC on sucessfull move   */
/*                          screen (james03)                            */
/* 2015-09-01 2.3  James    SOS348153 - Add extended valid sp (james04) */
/* 2016-09-30 2.4  Ung      Performance tuning                          */
/* 2018-06-04 2.5  James    WMS5307-Add rdt_decode sp (james05)         */
/* 2018-10-29 2.6  TungGH   Performance                                 */
/* 2019-01-07 2.7  James    WMS4787-Add ExtendedInfoSP (james06)        */
/* 2019-09-11 2.8  YeeKung  WMS10516 Set focusfield  (yeekung01)        */
/* 2021-01-04 2.9  Chermaine WMS-15903 add LOCLookupSP config (cc01)    */
/* 2022-12-13 3.0  YeeKung   JSM-116802 Add func for rdt_move (yeekung02)*/
/* 2023-02-22 3.1  YeeKung   WMS-21820 Add rdtformat toid (yeekung03)   */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Move_LOC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 NVARCHAR max
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
   @nMoveCnt      INT,
   @nTotalMoveCnt INT,
   @cOption       NVARCHAR( 1)

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

   @cFromLOC   NVARCHAR( 10),
   @cSKU       NVARCHAR( 20),
   @cSKUDescr  NVARCHAR( 60),
   @cPUOM      NVARCHAR( 1), -- Prefer UOM
   @cToLOC     NVARCHAR( 10),
   @cToID      NVARCHAR( 18), -- (Vicky01)
   @cFromID    NVARCHAR( 18), -- (Vicky01)

   @nTotalRec    INT,
   @nCurrentRec  INT,

   @cUserName    NVARCHAR(18), -- (Vicky06)

   @nMultiStorer        INT,              -- (james02)
   @nCounter INT,                    -- (yeekung01)
   @cLoop_StorerKey     NVARCHAR( 15),    -- (james02)
   @cSKU_StorerKey      NVARCHAR( 15),    -- (james02)
   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james04)
   @cChkStorerKey       NVARCHAR( 15),    -- (james04)
   @cSQL                NVARCHAR(MAX),    -- (james04)
   @cSQLParam           NVARCHAR(MAX),    -- (james04)
   @cExtendedValidateSP NVARCHAR( 20),    -- (james04)
   @cStorerGroup        NVARCHAR( 20),    -- (james04)
   @cTempToLOC          NVARCHAR( 10),
   @cTempToID           NVARCHAR( 18),
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
   @cExtendedInfo       NVARCHAR( 20), -- (james07)
   @cExtendedInfoSP     NVARCHAR( 20), -- (james07)
   @cLOCLookupSP        NVARCHAR(20),  --(cc01)

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

   @cStorerGroup = StorerGroup,
   @cFacility  = Facility,

   @cUserName  = UserName,-- (Vicky06)

   @cStorerKey = V_StorerKey,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @cPUOM      = V_UOM,
   @nQTY       = V_QTY,

   @cFromLOC            = V_String2,
   @cToLOC              = V_String3,
   @cExtendedInfoSP     = V_String4,
   @cExtendedValidateSP = V_String5,
   @cToID               = V_String7,   -- (Vicky01)
   @cDecodeSP           = V_String9,
   @cLOCLookupSP        = V_String10, --(cc01)
   @cExtendedUpdateSP           = V_String11,

   @nTotalRec     = V_Integer1,
   @nCurrentRec   = V_Integer2,
   @nTotalMoveCnt = V_Integer3,
   @nMultiStorer  = V_Integer4,   -- (james02)
   @nCounter      = V_Integer5,   --(yeekung01)

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 512 -- Move by LOC
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move (generic)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1010. FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1011. SKU, Desc, UOM, QTY, ToLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1012. Message
   --IF @nStep = 4 GOTO Step_4   -- Scn = 1012. Confirm only move 10 records per screen
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 512. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1010
   SET @nStep = 1

   -- Prep next screen var
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

   -- (james02)
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
      
       --(XLL045)                                      
   set @cExtendedUpdateSP = rdt.rdtGetConfig(@nFunc,'ExtendedUpdateSP',@cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorerKey)   --(cc01)

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init screen
   SET @cOutField02 = '' -- FromLOC
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1010. FromLOC
   FromLOC (field02)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField02

      -- Validate blank
      IF @cFromLOC = '' OR @cFromLOC IS NULL
      BEGIN
         SET @nErrNo = 62551
         SET @cErrMsg = rdt.rdtgetmessage( 62551, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_1_Fail
      END

      -- add from loc prefix (cc01)
     IF @cLOCLookupSP = 1
     BEGIN
      EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
      @cFromLOC    OUTPUT,
      @nErrNo     OUTPUT,
      @cErrMsg    OUTPUT
      IF @nErrNo <> 0
       GOTO Step_1_Fail
     END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62552
         SET @cErrMsg = rdt.rdtgetmessage( 62552, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 62553
         SET @cErrMsg = rdt.rdtgetmessage( 62553, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- If LOC having more than 1 storer then is multi storer else turn multi storer off
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                     WHERE EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
                     AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                     AND   LOC.Facility = @cFacility
                     AND   LOC.LOC = @cFromLoc
                     GROUP BY LLI.LOC
                     HAVING COUNT( DISTINCT StorerKey) > 1)
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                            WHERE  LLI.LOC = @cFromLOC
                            AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked -
                                  (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                            AND   LOC.Facility = @cFacility
                            AND   EXISTS ( SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK)
                                           WHERE SG.StorerGroup = @cStorerGroup
                                           AND SG.StorerKey = LLI.StorerKey))
            BEGIN
               SET @nErrNo = 62562
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               GOTO Step_1_Fail
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cChkStorerKey = StorerKey
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
               WHERE  LLI.LOC = @cFromLOC
               AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
               AND   LOC.Facility = @cFacility

               -- Set session storer
               SET @cStorerKey = @cChkStorerKey
               SET @nMultiStorer = 1
            END
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
            WHERE  LLI.LOC = @cFromLOC
            AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            AND   LOC.Facility = @cFacility

            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
            BEGIN
               SET @nErrNo = 62563
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               GOTO Step_1_Fail
            END

            -- Set session storer
            SET @cStorerKey = @cChkStorerKey
            SET @nMultiStorer = 0
         END
      END

      -- (james02)
      -- If for the loc entered, there is record in lotxlocxid.storerkey
      -- not defined in storergroup.storerkey, error message should be prompted.
      IF @nMultiStorer = 1
      BEGIN
         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT(1)
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE  LLI.LOC = @cFromLOC
         AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         AND   LOC.Facility = @cFacility
         AND   NOT EXISTS (SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)

         IF @nTotalRec >= 1
         BEGIN
            SET @nErrNo = 62561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC INV STORER'
            GOTO Step_1_Fail
         END
      END

      -- Get total record
      DECLARE @nQTYAlloc INT
      SET @nTotalRec = 0
      SELECT
         @nTotalRec = COUNT( DISTINCT SKU.SKU), -- Total no of SKU
         @nQTYAlloc = IsNULL( SUM( QTYAllocated + (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0)  -- SHONG 26022013
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 62554
         SET @cErrMsg = rdt.rdtgetmessage( 62554, @cLangCode, 'DSP') --'No record'
         GOTO Step_1_Fail
      END

      -- Validate QTY allocated
      IF @nQTYAlloc > 0
      BEGIN
         SET @nErrNo = 62555
         SET @cErrMsg = rdt.rdtgetmessage( 62555, @cLangCode, 'DSP') --'QTY allocated'
         GOTO Step_1_Fail
      END

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
            END
         END
      END

      -- Get LOTxLOCxID info
      SELECT TOP 1
         @cSKU_StorerKey = SKU.StorerKey,
         @cSKU = SKU.SKU,
         @nQTY = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
         INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
      GROUP BY SKU.StorerKey, SKU.SKU
      ORDER BY SKU.SKU

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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cSKU, @cOption, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cSKU, @cOption, @cExtendedInfo OUTPUT

            SET @cOutField13 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
         END
      END

      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cToLOC = ''
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
      SET @cOutField12 = '' -- ToID
      SET @nCounter    = 0
      EXEC rdt.rdtSetFocusField @nMobile, 11 -- LOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
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
      SET @cFromLOC  = ''
      SET @cOutField02 = '' -- FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1011. ToLOC
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
   ToID      (field12)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField11
      SET @cToID  = @cInField12
      SET @cBarcode = @cInField12

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cToID   OUTPUT,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
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
               @cToID       OUTPUT, @cFromLOC    OUTPUT, @cToLOC     OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END
      
      
      -- Validate blank
      IF @cToLOC = '' OR @cToLOC IS NULL
      BEGIN
         IF @nCurrentRec = @nTotalRec
            SET @nCurrentRec = 0

         -- Get LOTxLOCxID info
         DECLARE @curLLI CURSOR
         SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT
               SKU.StorerKey,
               SKU.SKU,
               SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
            FROM dbo.LOTxLOCxID LLI (NOLOCK)
               INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
               AND LLI.LOC = @cFromLOC
               AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
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
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cSKU, @cOption, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     +
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromLOC        NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@cToID           NVARCHAR( 18), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@cOption         NVARCHAR( 1),  ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cSKU, @cOption, @cExtendedInfo OUTPUT

               SET @cOutField13 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
            END
         END

         -- Prep next screen var
         SET @nCurrentRec = @nCurrentRec + 1
         SET @cToLOC = ''
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
         SET @cOutField12 = '' -- ToID

         GOTO Quit
      END

      -- add loc prefix (cc01)
     IF @cLOCLookupSP = 1   and @nCounter<1
     BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cToLOC        OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
     END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      --INSERT INTO traceinfo (TraceName,Col1,Col2,col3)
      --VALUES ('cc512',@cToLOC,@cLOCLookupSP,@cChkFacility)

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62556
         SET @cErrMsg = rdt.rdtgetmessage( 62358, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END

      -- Validate LOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 62557
            SET @cErrMsg = rdt.rdtgetmessage( 62557, @cLangCode, 'DSP') --'Diff facility'
            GOTO Step_2_Fail
         END

      IF isnull(@cToID,'') = '' and @nCounter<1 --(yeekung01)
      BEGIN
         SET @cOutField11=@cToLOC
         SET @nCounter = @nCounter+1
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- ID
         GOTO Quit
      END

      -- Check DropID format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0        --(yeekung03)
      BEGIN        
         SET @nErrNo = 62564        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
         GOTO Quit       
      END    

     -- (Vicky01) - Start
     IF ISNULL(RTRIM(@cToID), '') <> ''
     BEGIN
         -- Get LOTxLOCxID info
         DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.ID
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LLI.LOC = @cFromLOC
            AND LLI.SKU = @cSKU
            AND ISNULL(RTRIM(LLI.ID), '') <> ''
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         GROUP BY LLI.ID

         OPEN C_CUR

         FETCH NEXT FROM C_CUR INTO @cFromID

         WHILE @@FETCH_STATUS <> -1
         BEGIN

            -- Check Whether ID on hold
            IF EXISTS (SELECT 1 FROM dbo.ID (NOLOCK)
                       WHERE ID = @cFromID AND Status = 'HOLD')
            BEGIN
               SET @nErrNo = 62558
               SET @cErrMsg = rdt.rdtgetmessage( 62558, @cLangCode, 'DSP') --'ID on Hold'
               GOTO Step_2_Fail
            END

          FETCH NEXT FROM C_CUR INTO @cFromID
         END -- While detail
         CLOSE C_CUR
         DEALLOCATE C_CUR
     END
     -- (Vicky01) - End

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromLOC, @cToLOC, @cToID, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_2_Fail
            END
         END
      END

      -- Vicky01 - Start
      IF ISNULL(RTRIM(@cToID), '') = ''
      BEGIN
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @nFunc       = @nFunc, --(yeekung02)
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_Move_LOC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @nMoveCnt    = 0
         END
         ELSE
         BEGIN
            -- (james02)
            -- Using loop here to make sure every move is within storerkey defined in storergroup
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT StorerKey
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            WHERE LLI.LOC = @cFromLOC
            AND   EXISTS (SELECT 1 from dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @nFunc       = @nFunc, --(yeekung02)
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdtfnc_Move_LOC',
                  @cStorerKey  = @cLoop_StorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @nMoveCnt    = 0

               FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END
      END
      ELSE
      BEGIN
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @nFunc       = @nFunc, --(yeekung02)
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_Move_LOC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cToID       = @cToID,
               @nMoveCnt    = 0
         END
         ELSE
         BEGIN
            -- (james02)
            -- Using loop here to make sure every move is within storerkey defined in storergroup
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT StorerKey
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            WHERE LLI.LOC = @cFromLOC
            AND   EXISTS (SELECT 1 from dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @nFunc       = @nFunc, --(yeekung02)
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdtfnc_Move_LOC',
                  @cStorerKey  = @cLoop_StorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cToID       = @cToID,
                  @nMoveCnt    = 0

               FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END
         
          -- Extended update
          IF @cExtendedUpdateSP <> ''
            BEGIN
              IF EXISTS(SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP and type = 'p')
                BEGIN
           
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                    ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,@cSKU   OUTPUT,@nQTY     OUTPUT,' +
                    ' @cToID         OUTPUT,' +
                    ' @cFromLOC    OUTPUT, @cToLOC      OUTPUT, ' +
                    ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
                  SET @cSQLParam =
                    ' @nMobile      INT,             ' +
                    ' @nFunc        INT,             ' +
                    ' @cLangCode    NVARCHAR( 3),    ' +
                    ' @nStep        INT,             ' +
                    ' @nInputKey    INT,             ' +
                    ' @cStorerKey   NVARCHAR( 15),   ' +
                    ' @cBarcode     NVARCHAR( 60), ' +
                    ' @cSKU			NVARCHAR(20)   OUTPUT, ' +
                    ' @nQTY			INT			   OUTPUT, ' +
                    ' @cToID		NVARCHAR( 18)  OUTPUT, ' +
                    ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
                    ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
                    ' @nErrNo       INT            OUTPUT, ' +
                    ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,
                    @cSKU			OUTPUT, @nQTY		 OUTPUT,
                    @cToID       OUTPUT, @cFromLOC    OUTPUT, @cToLOC     OUTPUT,
                    @nErrNo      OUTPUT, @cErrMsg     OUTPUT

                  IF @nErrNo <> 0
                    BEGIN
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                      GOTO Step_2_Fail
                    END
                END
          END
      END
      -- Vicky01 - End

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = @cErrMsg --rdt.rdtgetmessage( 62558, @cLangCode, 'DSP') --LocMoveFailed
         SET @cOption = ''
         GOTO Step_2_Fail
      END
      ELSE
      BEGIN
          -- (Vicky06) EventLog - QTY
          IF ISNULL(RTRIM(@cToID), '') = ''
          BEGIN
             SET @cToID = ''
          END

          EXEC RDT.rdt_STD_EventLog
             @cActionType   = '4', -- Move
             @cUserID       = @cUserName,
             @nMobileNo     = @nMobile,
             @nFunctionID   = @nFunc,
             @cFacility     = @cFacility,
             @cStorerKey    = @cStorerkey,
             @cLocation     = @cFromLOC,
             @cToLocation   = @cToLOC,
             @cID           = @cToID,
             @nStep         = @nStep
      END

      SET @cOutField01 = @cToLOC -- (james03)

      SET @nScn  = @nScn + 1   --msg
      SET @nStep = @nStep + 1   --msg


      /*
      SELECT @nTotalMoveCnt = COUNT(1)
      FROM dbo.LOTxLOCxID LLI (NOLOCK)
      WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
         AND LLI.LOC = @cFromLOC
         AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0

      SET @cOutField01 = @nTotalMoveCnt -- no. of loc to be moved
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn = @nScn + 2
      SET @nStep = @nStep + 2
      */
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField02 = '' -- FromLOC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cToID = '' -- Vicky01
      SET @cOutField11 = ''
      SET @cOutField12 = '' -- Vicky02
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 1012. Message screen
   Msg
********************************************************************************/
Step_3:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 2
   SET @nStep = @nStep - 2

   -- Prep next screen var
   SET @cFromLOC = ''

   SET @cOutField02 = '' -- FromLOC
END
GOTO Quit

/*
/********************************************************************************
Step 4. scn = 1013. Message screen
   Only move 10 records
   at one time

   Remaining Rec = 999

   Continue Move?
   1 = YES
   2 = NO

   Option: @cInField02
********************************************************************************/
Step_4:
BEGIN

   SET @cOption = ''
   SET @cOption = @cInField02

   IF RTRIM(@cOption) <> '1' AND RTRIM(@cOption) <> '2'
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( 4, @cLangCode, 'DSP') --Invalid Option
      SET @cOption = ''
      GOTO Step_4_Fail
   END

   IF @nTotalMoveCnt > 10    --still got > 10 records to move
      SET @nMoveCnt = 10
   ELSE
      SET @nMoveCnt = 0 --move remaining records

   IF RTRIM(@cOption) = '1'   --Yes, start to move
   BEGIN
      -- Vicky01 - Start
      IF ISNULL(RTRIM(@cToID), '') = ''
      BEGIN
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_Move_LOC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @nMoveCnt    = @nMoveCnt
         END
         ELSE
         BEGIN
            -- (james02)
            -- Using loop here to make sure every move is within storerkey defined in storergroup
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT StorerKey
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            WHERE LLI.LOC = @cFromLOC
            AND   EXISTS (SELECT 1 from dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdtfnc_Move_LOC',
                  @cStorerKey  = @cLoop_StorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @nMoveCnt    = @nMoveCnt

               FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END
      END
      ELSE
      BEGIN
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_Move_LOC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cToID       = @cToID,
               @nMoveCnt    = @nMoveCnt
         END
         ELSE
         BEGIN
            -- (james02)
            -- Using loop here to make sure every move is within storerkey defined in storergroup
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT StorerKey
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            WHERE LLI.LOC = @cFromLOC
            AND   EXISTS (SELECT 1 from dbo.StorerGroup SG WITH (NOLOCK) WHERE LLI.StorerKey = SG.StorerKey AND SG.StorerGroup = @cStorerKey)
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdtfnc_Move_LOC',
                  @cStorerKey  = @cLoop_StorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cToID       = @cToID,
                  @nMoveCnt    = @nMoveCnt

               FETCH NEXT FROM CUR_LOOP INTO @cLoop_StorerKey
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
         END
      END
      -- Vicky01 - End

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = @cErrMsg --rdt.rdtgetmessage( 62558, @cLangCode, 'DSP') --LocMoveFailed
         SET @cOption = ''
         GOTO Step_4_Fail
      END
      ELSE
      BEGIN
         SET @nTotalMoveCnt = @nTotalMoveCnt - 10

          -- (Vicky06) EventLog - QTY
          IF ISNULL(RTRIM(@cToID), '') = ''
          BEGIN
             SET @cToID = ''
          END

          EXEC RDT.rdt_STD_EventLog
             @cActionType   = '4', -- Move
             @cUserID       = @cUserName,
             @nMobileNo     = @nMobile,
             @nFunctionID   = @nFunc,
             @cFacility     = @cFacility,
             @cStorerKey    = @cStorerkey,
             @cLocation     = @cFromLOC,
             @cToLocation   = @cToLOC,
             @cID           = @cToID,
             @nStep         = @nStep
      END

      IF @nTotalMoveCnt > 0
      BEGIN
         SET @cOutField01 = @nTotalMoveCnt -- no. of loc to be moved
         SET @cOutField02 = ''
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cToLOC -- (james03)

         SET @nScn  = @nScn - 1   --msg
         SET @nStep = @nStep - 1   --msg
      END
   END

   IF RTRIM(@cOption) = '2'   --No & go back to scan To LOC scn (step 2)
   BEGIN
      -- Go back to scan To LOC screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      -- Prep next screen var
      SET @cToLOC = ''
      SET @cOutField11 = '' -- ToLOC
      SET @cOutField12 = '' -- ToID
      SET @cOutField02 = @cFromLOC -- FromLOC
   END
   GOTO Quit

   Step_4_Fail:
      SET @cOutField02 = '' -- FromLOC

END
GOTO Quit
*/

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
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_UOM      = @cPUOM,
      V_QTY      = @nQTY,

      V_String2  = @cFromLOC,
      V_String3  = @cToLOC,
      V_String4  = @cExtendedInfoSP,
      V_String5  = @cExtendedValidateSP,

      V_Integer1 = @nTotalRec,
      V_Integer2 = @nCurrentRec,
      V_Integer3 = @nTotalMoveCnt,
      V_Integer4 = @nMultiStorer,    -- (james25)
   V_Integer5 = @nCounter, --(yeekung01)

      V_String7 = @cToID,           -- (Vicky01)
      V_String9 = @cDecodeSP,
      V_String10 = @cLOCLookupSP,   --(cc01)
      v_String11 = @cExtendedUpdateSP,

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