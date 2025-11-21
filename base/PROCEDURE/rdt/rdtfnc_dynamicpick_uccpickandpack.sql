SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_UCCPickAndPack                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Dynamic Pick - Pick And Pack UCC                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 24-04-2013 1.0  James    SOS262114. Created                          */
/* 30-09-2016 1.1  Ung      Performance tuning                          */
/* 01-11-2018 1.2  TungGH   Performance                                 */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_UCCPickAndPack] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cUCCNo            NVARCHAR( 20), 
   @cOption           NVARCHAR( 1), 
   @cSQL              NVARCHAR( MAX), 
   @cSQLParam         NVARCHAR( MAX)
   
-- RDT.RDTMobRec variable
DECLARE
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @cLangCode         NVARCHAR(3),
   @nInputKey         INT,
   @nMenu             INT,

   @cStorerKey        NVARCHAR(15),
   @cFacility         NVARCHAR(5),
   @cUserName         NVARCHAR(15),
   @cPrinter          NVARCHAR(10),

   @cSKU              NVARCHAR(20),
   @cSKUDescr         NVARCHAR(40),
   @cLottable01       NVARCHAR(18),
   @cLottable02       NVARCHAR(18),
   @cLottable03       NVARCHAR(18),
   @dLottable04       DATETIME,
   @cSuggestedLOC     NVARCHAR(10), 
   @nQTY              INT, 

   @cWaveKey          NVARCHAR(10), 
   @cPWZone           NVARCHAR(10),
   @cFromLOC          NVARCHAR(10),
   @cToLOC            NVARCHAR(10), 
   @nBalQTY           INT, 
   @nTotalQTY         INT, 
   @cDecodeLabelNo    NVARCHAR(20),
   @cExtendedUpdateSP NVARCHAR(20),

   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60)

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
   @cPrinter    = Printer,

   @cSKU          = V_SKU,
   @cSKUDescr     = V_SKUDescr,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @cSuggestedLOC = V_LOC,
   
   @nQTY          = V_QTY,

   @nBalQTY       = V_Integer1,
   @nTotalQty     = V_Integer2,
      
   @cWaveKey      = V_String1,
   @cPWZone       = V_String2,
   @cFromLOC      = V_String3,
   @cToLOC        = V_String4,
   @cDecodeLabelNo     = V_String7,
   @cExtendedUpdateSP  = V_String8,

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

FROM rdt.RDTMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 949 -- Dynamic UCC Pick & Pack 
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 950
   IF @nStep = 1 GOTO Step_1   -- Scn = 1640. WaveKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 1643. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1644. UCC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1647. Confirm Short Pick
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 949)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3560
   SET @nStep = 1

   -- Init var
   SET @cWaveKey = ''
   SET @cPWZone = ''
   SET @cFromLOC = ''
   SET @cToLOC = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = 0

   -- Get StorerConfig
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- WaveKey
   SET @cOutField02 = '' -- WaveKey
   SET @cOutField03 = '' -- FromLOC
   SET @cOutField04 = '' -- ToLOC

    -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3560
   WAVEKEY  (field01, input)
   PWZONE   (field02, input)
   FROM LOC (field03, input)
   TO LOC   (field04, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWaveKey = @cInField01
      SET @cPWZone  = @cInField02
      SET @cFromLOC = @cInField03
      SET @cToLOC   = @cInField04

      -- Retain value
      SET @cOutField01 = @cInField01 -- WaveKey
      SET @cOutField02 = @cInField02 -- PWZone
      SET @cOutField03 = @cInField03 -- FromLOC
      SET @cOutField04 = @cInField04 -- ToLOC

      -- Check WaveKey blank
      IF @cWaveKey = '' -- WaveKey
      BEGIN
         --SET @cOutField01 = ''
         SET @nErrNo = 65576
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need WAVEKEY'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
         GOTO Step_1_Fail
      END

      -- Check WaveKey exists
      IF NOT EXISTS (SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
      BEGIN
         SET @cWaveKey = ''
         SET @nErrNo = 65577
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad WAVEKEY'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
         GOTO Step_1_Fail
      END

      -- Check putaway zone blank
      IF @cPWZone = '' -- PWZone
      BEGIN
         --SET @cOutField02 = ''
         SET @nErrNo = 65590
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need PWAYZONE'
         EXEC rdt.rdtSetFocusField @nMobile, 2 --PWZone
         GOTO Step_1_Fail
      END

      -- Check putaway zone valid
      IF NOT EXISTS (SELECT 1 FROM dbo.PutawayZone WITH (NOLOCK) WHERE PutawayZone = @cPWZone)
      BEGIN
         SET @cPWZone = ''
         SET @nErrNo = 65591
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad PWAYZONE'
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PWZone
         GOTO Step_1_Fail
      END       
      
      -- Check FromLOC
      IF @cFromLOC <> ''
      BEGIN
         -- Check FromLOC valid
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cFromLOC)
         BEGIN
            SET @cFromLOC = ''
            SET @nErrNo = 65578
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad FROMLOC
            EXEC rdt.rdtSetFocusField @nMobile, 3  -- FromLOC
            GOTO Step_1_Fail
         END

         -- Check FromLOC facility
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cFromLOC AND Facility = @cFacility)
         BEGIN
            SET @cFromLOC = ''
            SET @nErrNo = 65579
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff FACILITY
            EXEC rdt.rdtSetFocusField @nMobile, 3  -- FromLOC
            GOTO Step_1_Fail
         END
      END

      -- Check ToLOC
      IF @cToLOC <> ''
      BEGIN
         -- Check ToLOC valid
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLOC)
         BEGIN
            SET @cToLOC = ''
            SET @nErrNo = 65580
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad TOLOC
            EXEC rdt.rdtSetFocusField @nMobile, 4  -- ToLOC
            GOTO Step_1_Fail
         END

         -- Check ToLOC facility
         IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLOC AND Facility = @cFacility)
         BEGIN
            SET @cToLOC = ''
            SET @nErrNo = 65581
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff FACILITY
            EXEC rdt.rdtSetFocusField @nMobile, 4  -- ToLOC
            GOTO Step_1_Fail
         END
      END

      -- Check FromLOC without ToLOC
      IF @cFromLOC <> '' AND @cToLOC = ''
      BEGIN
         SET @cToLOC = ''
         SET @nErrNo = 65582
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TOLOC
         EXEC rdt.rdtSetFocusField @nMobile, 4  -- ToLOC
         GOTO Step_1_Fail
      END

      -- Check ToLOC without FromLOC
      IF @cFromLOC = '' AND @cToLOC <> ''
      BEGIN
         SET @cFromLOC = ''
         SET @nErrNo = 65583
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FROMLOC
         EXEC rdt.rdtSetFocusField @nMobile, 3  -- FromLOC
         GOTO Step_1_Fail
      END

      IF @cToLOC = ''
         SET @cToLOC = 'ZZZZZZZZZZ'

      -- Get first LOC to pick
      SET @cSuggestedLoc = ''
      EXECUTE rdt.rdt_DynamicPick_UCCPickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, 
         @cWaveKey,
         @cPWZone, 
         @cFromLOC,
         @cToLOC,
         '',      -- Current location
         @cSuggestedLOC OUTPUT,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep ' +
               ',@cFacility      ' +
               ',@cStorerKey     ' +
               ',@cWaveKey       ' +
               ',@cPWZone        ' + 
               ',@cFromLoc       ' +
               ',@cToLoc         ' +
               ',@cSuggestedLOC  ' +
               ',@cSKU           ' +
               ',@cLottable01    ' +
               ',@cLottable02    ' +
               ',@cLottable03    ' +
               ',@dLottable04    ' +
               ',@nQTY           ' +
               ',@nBalQTY        ' +
               ',@nTotalQTY      ' +
               ',@cUCCNo         ' +
               ',@cOption        ' +
               ',@nErrNo  OUTPUT ' +
               ',@cErrMsg OUTPUT'
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT ' +
               ',@cFacility       NVARCHAR( 5)   ' +
               ',@cStorerKey      NVARCHAR( 15)  ' +
               ',@cWaveKey        NVARCHAR( 10)  ' +
               ',@cPWZone         NVARCHAR( 10)  ' +
               ',@cFromLoc        NVARCHAR( 10)  ' +
               ',@cToLoc          NVARCHAR( 10)  ' +
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +
               ',@cSKU            NVARCHAR( 20)  ' +
               ',@cLottable01     NVARCHAR( 18)  ' +
               ',@cLottable02     NVARCHAR( 18)  ' +
               ',@cLottable03     NVARCHAR( 18)  ' +
               ',@dLottable04     DATETIME   ' +
               ',@nQTY            INT        ' +
               ',@nBalQTY         INT        ' +
               ',@nTotalQTY       INT        ' +
               ',@cUCCNo          NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +
               ',@nErrNo          INT OUTPUT ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep
               ,@cFacility
               ,@cStorerKey
               ,@cWaveKey
               ,@cPWZone
               ,@cFromLoc
               ,@cToLoc
               ,@cSuggestedLOC
               ,@cSKU
               ,@cLottable01
               ,@cLottable02
               ,@cLottable03
               ,@dLottable04
               ,@nQTY
               ,@nBalQTY
               ,@nTotalQTY
               ,@cUCCNo
               ,@cOption
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Clear next screen variable
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = '' -- LOC

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign-out
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @cRefNo1     = 'Pick And Pack',
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   IF @cWaveKey = '' SELECT @cInField01 = '', @cOutField01 = ''
   IF @cPWZone  = '' SELECT @cInField02 = '', @cOutField02 = ''
   IF @cFromLOC = '' SELECT @cInField03 = '', @cOutField03 = ''
   IF @cToLOC   = '' SELECT @cInField04 = '', @cOutField04 = ''

END
GOTO Quit


/********************************************************************************
Step 2. Screen 3561
   SUGGEST LOC (Field01)
   LOC         (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cLOC NVARCHAR( 10)
      
      -- Screen mapping
      SET @cLOC = @cInField02

      -- Skip LOC
      IF @cLOC = ''
      BEGIN
         EXECUTE rdt.rdt_DynamicPick_UCCPickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, 
            @cWaveKey,
            @cPWZone, 
            @cFromLOC,
            @cToLOC,
            @cSuggestedLOC,
            @cSuggestedLOC OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField01 = @cSuggestedLOC
         SET @cOutField02 = '' -- LOC
         GOTO Quit
      END

      -- Check LOC same as suggested
      IF @cLOC <> @cSuggestedLOC
      BEGIN
         SET @nErrNo = 65584
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC
         GOTO Step_2_Fail
      END

      -- Get next task
      SET @nErrNo = 0
      EXEC rdt.rdt_DynamicPick_UCCPickAndPack_GetNextTask @nMobile, @nFunc, @cLangCode, 
         @cStorerKey,
         @cWaveKey,
         @cSuggestedLOC,
         @cSKU          OUTPUT,
         @cSKUDescr     OUTPUT,
         @cLottable01   OUTPUT,
         @cLottable02   OUTPUT,
         @cLottable03   OUTPUT,
         @dLottable04   OUTPUT,
         @nBalQty       OUTPUT, -- Balance UCC to pick in the LOC
         @nTotalQty     OUTPUT, -- Total UCC to pick in the LOC
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0 
         GOTO Step_2_Fail

      -- Prep next screen var
      SET @nQTY = 0
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField08 = '' -- UCC
      SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField10 = RTRIM( CAST( @nBalQTY AS NVARCHAR( 5))) + '/' + CAST( @nTotalQTY AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 11
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- WaveKey
      SET @cOutField02 = '' -- PWZone
      SET @cOutField03 = '' -- FromLOC
      SET @cOutField04 = '' -- ToLOC

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField02 = '' -- LOC
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen 3562
   SKU       (Field01)
   SKU Desc1 (Field02)
   SKU Desc2 (Field03)
   Lottable1 (Field04)
   Lottable2 (Field05)
   Lottable3 (Field06)
   Lottable4 (Field07)
   UCC       (Field08, input)
   QTY       (Field09)
   BAL       (Field10)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField08
      
      -- Check if blank
      IF @cUCCNo = ''
      BEGIN
         -- Check short pick
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.WaveKey = @cWaveKey
               AND PD.LOC = @cSuggestedLOC
               AND PD.QTY > 0
               AND PD.Status < '3'
               AND PD.UOM = '2' -- full case
               AND NOT EXISTS (SELECT 1 
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
                  WHERE O.OrderKey = PD.OrderKey
                     AND O.SOStatus = 'CANC'
                     AND PD1.UOM = '2' -- Full case
                  GROUP BY PD1.Status
                  HAVING MAX( PD1.Status) = '0'))
         BEGIN
            -- Go to confirm short screen
            SET @cOutField01 = '' -- Option
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END
      
      -- Get UCC info
      DECLARE @cUCCSKU NVARCHAR( 20)
      DECLARE @cUCCLOT NVARCHAR( 10)
      DECLARE @cUCCLOC NVARCHAR( 10)
      DECLARE @cUCCID  NVARCHAR( 18)
      DECLARE @nUCCQTY INT
      SELECT 
         @cUCCNo = UCCNo, 
         @cUCCSKU = SKU, 
         @nUCCQTY = QTY, 
         @cUCCLOT = LOT,
         @cUCCLOC = LOC, 
         @cUCCID = ID
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE UCCNo = @cUCCNo
         AND StorerKey = @cStorerKey
         AND Status IN ('1', '5', '6') -- 1=Receve, 6=Replenish

      -- Check if valid UCC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 65585
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
         GOTO Step_3_Fail
      END
      
      -- Check double scan
      IF EXISTS( SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
            AND DropID = @cUCCNo
            AND Status >= '3') -- 3=Picked
      BEGIN
         SET @nErrNo = 65586
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
         GOTO Step_3_Fail
      END

      -- Get PickDetail info
      DECLARE @cPickDetailKey NVARCHAR( 10)
      SELECT TOP 1 
         @cPickDetailKey = PickDetailKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE WaveKey = @cWaveKey
         -- AND DropID = @cUCCNo
         AND QTY > 0
         AND Status < '3' 
         AND UOM = '2' -- Full case
         -- AND LOT = @cUCCLOT
         AND LOC = @cUCCLOC
         AND ID = @cUCCID
         AND SKU = @cUCCSKU
         AND QTY = @nUCCQTY
         AND NOT EXISTS (SELECT 1 
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
            WHERE O.OrderKey = PickDetail.OrderKey
               AND O.SOStatus = 'CANC'
               AND PD1.UOM = '2' -- Full case
            GROUP BY PD1.Status
            HAVING MAX( PD1.Status) = '0')
      ORDER BY 
         CASE WHEN DropID = @cUCCNo THEN 0 ELSE 1 END, 
         CASE WHEN LOT = @cUCCLOT THEN 0 ELSE 1 END
         
      -- Check if UCC on PickDetail
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 65587
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCNotMatchPD
         GOTO Step_3_Fail
      END
   
      -- Pick the UCC
      EXEC rdt.rdt_DynamicPick_UCCPickAndPack_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, 
         @cSuggestedLOC, 
         @cPickDetailKey, 
         @cUCCNo, 
         @nErrNo  OUTPUT, 
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail
      
      SET @nQTY = @nQTY + 1
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep ' +
               ',@cFacility      ' +
               ',@cStorerKey     ' +
               ',@cWaveKey       ' +
               ',@cPWZone        ' + 
               ',@cFromLoc       ' +
               ',@cToLoc         ' +
               ',@cSuggestedLOC  ' +
               ',@cSKU           ' +
               ',@cLottable01    ' +
               ',@cLottable02    ' +
               ',@cLottable03    ' +
               ',@dLottable04    ' +
               ',@nQTY           ' +
               ',@nBalQTY        ' +
               ',@nTotalQTY      ' +
               ',@cUCCNo         ' +
               ',@cOption        ' +
               ',@nErrNo  OUTPUT ' +
               ',@cErrMsg OUTPUT'
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT ' +
               ',@cFacility       NVARCHAR( 5)   ' +
               ',@cStorerKey      NVARCHAR( 15)  ' +
               ',@cWaveKey        NVARCHAR( 10)  ' +
               ',@cPWZone         NVARCHAR( 10)  ' + 
               ',@cFromLoc        NVARCHAR( 10)  ' +
               ',@cToLoc          NVARCHAR( 10)  ' +
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +
               ',@cSKU            NVARCHAR( 20)  ' +
               ',@cLottable01     NVARCHAR( 18)  ' +
               ',@cLottable02     NVARCHAR( 18)  ' +
               ',@cLottable03     NVARCHAR( 18)  ' +
               ',@dLottable04     DATETIME   ' +
               ',@nQTY            INT        ' +
               ',@nBalQTY         INT        ' +
               ',@nTotalQTY       INT        ' +
               ',@cUCCNo          NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +
               ',@nErrNo          INT OUTPUT ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep
               ,@cFacility
               ,@cStorerKey
               ,@cWaveKey
               ,@cPWZone
               ,@cFromLoc
               ,@cToLoc
               ,@cSuggestedLOC
               ,@cSKU
               ,@cLottable01
               ,@cLottable02
               ,@cLottable03
               ,@dLottable04
               ,@nQTY
               ,@nBalQTY
               ,@nTotalQTY
               ,@cUCCNo
               ,@cOption
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END   

      -- Get next task to pick
      SET @nErrNo = 0
      EXEC rdt.rdt_DynamicPick_UCCPickAndPack_GetNextTask @nMobile, @nFunc, @cLangCode, 
         @cStorerKey,
         @cWaveKey,
         @cSuggestedLOC,
         @cSKU          OUTPUT,
         @cSKUDescr     OUTPUT,
         @cLottable01   OUTPUT,
         @cLottable02   OUTPUT,
         @cLottable03   OUTPUT,
         @dLottable04   OUTPUT,
         @nBalQty       OUTPUT, -- Balance UCC to pick in the LOC
         @nTotalQty     OUTPUT, -- Total UCC to pick in the LOC
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
         
      IF @nErrNo = 0 -- More task on same LOC
      BEGIN
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField08 = '' -- UCC
         SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))
         SET @cOutField10 = RTRIM( CAST( @nBalQTY AS NVARCHAR( 5))) + '/' + CAST( @nTotalQTY AS NVARCHAR( 5))
      END

      IF @nErrNo <> 0 -- No task on same LOC
      BEGIN
         -- Get next LOC to pick
         SET @cSuggestedLOC = ''
         EXECUTE rdt.rdt_DynamicPick_UCCPickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, 
            @cWaveKey,
            @cPWZone, 
            @cFromLOC,
            @cToLOC,
            @cSuggestedLOC,   -- Current location
            @cSuggestedLOC OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
         
         IF @nErrNo = 0  -- Found next LOC to pick
         BEGIN
            -- Go to LOC screen
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = '' -- LOC
   
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
         ELSE
         BEGIN
            -- Go to Wave screen
            SET @cOutField01 = '' -- WaveKey
            SET @cOutField02 = '' -- PWZone
            SET @cOutField03 = '' -- FromLoc
            SET @cOutField04 = '' -- ToLOC

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey

            -- Clean up err msg (otherwise appear on destination screen)
            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
      END      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = '' -- LOC

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField08 = '' -- UCC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 3563
   CONFIRM SHORT PICK?
   1=YES
   2=NO
   Option (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 65588
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_4_Fail
      END

      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 65589
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_4_Fail
      END

      IF @cOption = '1' -- Short
      BEGIN
         -- Get next LOC to pick
         EXECUTE rdt.rdt_DynamicPick_UCCPickAndPack_GetNextLOC @nMobile, @nFunc, @cLangCode, 
            @cWaveKey,
            @cPWZone, 
            @cFromLOC,
            @cToLOC,
            @cSuggestedLOC,
            @cSuggestedLOC OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
            
         IF @nErrNo = 0  -- Found next LOC to pick
         BEGIN
            -- Go to LOC screen
            SET @cOutField01 = @cSuggestedLOC
            SET @cOutField02 = '' -- LOC
   
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
         ELSE
         BEGIN
            -- Go to Wave screen
            SET @cOutField01 = '' -- WaveKey
            SET @cOutField02 = '' -- PWZone
            SET @cOutField03 = '' -- FromLoc
            SET @cOutField04 = '' -- ToLOC

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey

            -- Clean up err msg (otherwise appear on destination screen)
            SET @nErrNo = 0
            SET @cErrMsg = ''
         END         
      END
   END
   
   -- Prepare prev screen variable
   SET @cOutField01 = @cSKU
   SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
   SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
   SET @cOutField04 = @cLottable01
   SET @cOutField05 = @cLottable02
   SET @cOutField06 = @cLottable03
   SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
   SET @cOutField08 = '' -- UCC
   SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))
   SET @cOutField10 = RTRIM( CAST( @nBalQTY AS NVARCHAR( 5))) + '/' + CAST( @nTotalQTY AS NVARCHAR( 5))

   -- Go to previous screen
   SET @nScn  = @nScn - 1
   SET @nStep = @nStep - 1
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' --Option
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
      ErrMsg   = @cErrMsg,
      Func     = @nFunc,
      Step     = @nStep,
      Scn      = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      Printer    = @cPrinter,

      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_LOC        = @cSuggestedLOC,
      
      V_QTY        = @nQTY,

      V_Integer1   = @nBalQty,
      V_Integer2   = @nTotalQty,
      
      V_String1    = @cWaveKey,
      V_String2    = @cPWZone,
      V_String3    = @cFromLOC,
      V_String4    = @cToLOC,
      V_String7    = @cDecodeLabelNo,
      V_String8    = @cExtendedUpdateSP,

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