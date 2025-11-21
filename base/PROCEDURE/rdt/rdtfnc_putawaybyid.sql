SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PutawayByID                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Putaway by pallet ID                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-03-19 1.0  Ung      SOS336606 Created                           */
/* 2015-09-28 1.1  Ung      Add MoveQTYAlloc, MoveQTYPick               */
/*                          Add PutawayMatchSuggestLOC                  */
/* 2016-08-04 1.2  Ung      SOS374890 Add DefaultToLOC                  */
/*                          Performance turning                         */
/* 2018-06-11 1.3  James    WMS5390 Add rdt_decode (james01)            */
/* 2018-09-03 1.4  James    WMS6233 Add sucessfully putaway scn(james02)*/
/* 2019-01-28 1.5  James    WMS7793 Add pallet criteria scn (james03)   */
/* 2019-07-17 1.6  James    WMS9858 Add loc prefix (james04)            */   
/* 2019-08-07 1.7  James    WMS10120 Add screen confirm overwrite       */
/*                          suggested loc (james05)                     */
/* 2023-03-20 1.8  Dennis   UWP-14536 Check Digit                       */
/* 2024-04-18 1.9  Calvin   UWP-18503 Map full input values (CLVN01)    */
/* 2024-06-11 2.0  NLT013   FCR-267 Unlock locations for all UCC        */
/* 2024-07-31 2.1  CYU027   FCR-122 Add Reason Code for Override        */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PutawayByID] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @nTranCount          INT, 
   @bSuccess            INT, 
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerGroup        NVARCHAR( 20),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cStorerKey          NVARCHAR( 15),
   @cFromLOC            NVARCHAR( 10), 
   @cFromID             NVARCHAR( 20), 
   
   @cSuggLOC            NVARCHAR( 10), 
   @cPickAndDropLOC     NVARCHAR( 10), 
   @cToLOC              NVARCHAR( 20), 
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @nPABookingKey       INT, 
   @cDefaultToLOC       NVARCHAR( 1), 
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cShowPASuccessScn   NVARCHAR( 1),
   @cPalletCriteria     NVARCHAR( 20),
   @cParam1             NVARCHAR( 20),
   @cParam2             NVARCHAR( 20),
   @cParam3             NVARCHAR( 20),
   @cParam4             NVARCHAR( 20),
   @cParam5             NVARCHAR( 20),
   @cPalletCriteriaSP   NVARCHAR( 20),
   @cParamLabel1        NVARCHAR( 20),
   @cParamLabel2        NVARCHAR( 20),
   @cParamLabel3        NVARCHAR( 20),
   @cParamLabel4        NVARCHAR( 20),
   @cParamLabel5        NVARCHAR( 20),
   @cLOCLookupSP        NVARCHAR( 20),
   @cPAMatchSuggestLOC  NVARCHAR( 1), 
   @cOption             NVARCHAR( 10), --(CLVN01)
   @cExtendedScreenSP   NVARCHAR( 20),
   @cExtScnSP           NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @tExtScnData			VariableTable,


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
   @cFieldAttr15 NVARCHAR( 1),

   @cLottable01  NVARCHAR( 18), @cLottable02  NVARCHAR( 18), @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,      @dLottable05  DATETIME,      @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30), @cLottable08  NVARCHAR( 30), @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30), @cLottable11  NVARCHAR( 30), @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,      @dLottable14  DATETIME,      @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)


-- Load RDT.RDTMobRec
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cStorerKey       = V_StorerKey,
   @cFromID          = V_ID,
   @cFromLOC         = V_LOC,

   @cSuggLOC            = V_String1,
   @cPickAndDropLOC     = V_String2,
   @cToLOC              = V_String3,
   @cExtendedValidateSP = V_String4,
   @cExtendedUpdateSP   = V_String5,
   @cExtendedInfoSP     = V_String6,
   @cExtendedInfo       = V_String7,
   @cPalletCriteriaSP   = V_String8,
   @cDefaultToLOC       = V_String9, 
   @cDecodeSP           = V_String10,
   @cShowPASuccessScn   = V_String11,
   @cPalletCriteria     = V_String12,
   @cParam1             = V_String13,
   @cParam2             = V_String14,
   @cParam3             = V_String15,
   @cParam4             = V_String16,
   @cParam5             = V_String17,
   @cLOCLookupSP        = V_String18,
   @cPAMatchSuggestLOC  = V_String19,
   @cExtScnSP           = V_String20,

   @nPABookingKey       = V_Integer1,

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

-- Redirect to respective screen
IF @nFunc = 1819
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1819
   IF @nStep = 1 GOTO Step_1   -- Scn = 4110. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4111. Suggest LOC, TO LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4112. Successful Putaway
   IF @nStep = 4 GOTO Step_4   -- Scn = 4113. Pallet criteria
   IF @nStep = 5 GOTO Step_5   -- Scn = 4114. Loc not match. Proceed?
   IF @nStep =99 GOTO Step_ExtScn   -- Scn = 4114. Reason Code
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Initialize
********************************************************************************/
Step_0:
BEGIN
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- (james02)
   SET @cShowPASuccessScn = rdt.RDTGetConfig( @nFunc, 'ShowPASuccessScn', @cStorerKey)
   IF @cShowPASuccessScn = '0'
      SET @cShowPASuccessScn = ''

   -- (james03)
   SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
   IF @cPalletCriteria = '0'
      SET @cPalletCriteria = ''

   -- (james03)
   SET @cPalletCriteriaSP = rdt.RDTGetConfig( @nFunc, 'PalletCriteriaSP', @cStorerKey)
   IF @cPalletCriteriaSP = '0'
      SET @cPalletCriteriaSP = ''

   -- (james04)
   SET @cLOCLookupSP = rdt.rdtGetConfig( @nFunc, 'LOCLookupSP', @cStorerKey)

   -- (james05)
   SET @cPAMatchSuggestLOC = rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorerKey)

   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
   BEGIN
      SET @cExtScnSP = ''
   END


   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   SET @cParam1 = ''
   SET @cParam2 = ''
   SET @cParam3 = ''
   SET @cParam4 = ''
   SET @cParam5 = ''

   -- Pallet criteria
   IF @cPalletCriteria <> ''
   BEGIN
      -- Get pallet criteria label
      SELECT
         @cParamLabel1 = UDF01,
         @cParamLabel2 = UDF02,
         @cParamLabel3 = UDF03,
         @cParamLabel4 = UDF04,
         @cParamLabel5 = UDF05
     FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTPACrit'
      AND   Code = @cPalletCriteria
      AND   StorerKey = @cStorerKey
      AND   Code2 = @nFunc

      -- Check pallet criteria setup
      IF @cParamLabel1 = '' AND
         @cParamLabel2 = '' AND
         @cParamLabel3 = '' AND
         @cParamLabel4 = '' AND
         @cParamLabel5 = ''
      BEGIN
         SET @nErrNo = 52760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Quit
      END

      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = ''
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = ''
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = ''
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = ''
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = ''

      -- Go to pallet criteria screen
      SET @nScn  = 4113
      SET @nStep = 4
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- @cFromID

      -- Set the entry point
      SET @nScn  = 4110
      SET @nStep = 1
   END
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4110
   FROM ID      (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
      SET @cBarcode = @cInField01

      -- Check blank
      IF @cFromID = ''
      BEGIN
         SET @nErrNo = 52751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --From ID needed
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
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cID   OUTPUT, @cLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg  OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cLOC         NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cFromID OUTPUT, @cToLOC   OUTPUT, @nErrNo   OUTPUT, @cErrMsg  OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END
      
      -- Check ID valid (with QTY to move)
      IF NOT EXISTS( SELECT 1 
         FROM LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.ID = @cFromID
            AND LLI.QTY - 
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', LLI.StorerKey) = '0' THEN LLI.QTYAllocated ELSE 0 END) - 
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', LLI.StorerKey) = '0' THEN LLI.QTYPicked ELSE 0 END) > 0)
      BEGIN
         SET @nErrNo = 52752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Get storer
         DECLARE @cChkStorerKey NVARCHAR(15)
         SELECT TOP 1 @cChkStorerKey = StorerKey 
         FROM LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.ID = @cFromID 
            AND LLI.QTY - 
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', LLI.StorerKey) = '0' THEN LLI.QTYAllocated ELSE 0 END) - 
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', LLI.StorerKey) = '0' THEN LLI.QTYPicked ELSE 0 END) > 0 
         
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 52755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      -- Get storer configure
      DECLARE @cMoveQTYAlloc NVARCHAR( 1)
      DECLARE @cMoveQTYPick  NVARCHAR( 1)
      SET @cDefaultToLOC = rdt.rdtGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
      SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
      SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      
      -- Check ID allocated
      IF @cMoveQTYAlloc = '0'
      BEGIN
         IF EXISTS( SELECT 1 
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cFromID
               AND LLI.QTYAllocated > 0)
         BEGIN
            SET @nErrNo = 52758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Allocated
            GOTO Step_1_Fail
         END
      END
      
      -- Check ID picked
      IF @cMoveQTYPick = '0'
      BEGIN
         IF EXISTS( SELECT 1 
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cFromID
               AND LLI.QTYPicked > 0)
         BEGIN
            SET @nErrNo = 52759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Picked
            GOTO Step_1_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Get ID info
      SELECT TOP 1 
         @cFromLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.ID = @cFromID 
         AND LLI.QTY - 
            (CASE WHEN @cMoveQTYAlloc = '0' THEN LLI.QTYAllocated ELSE 0 END) - 
            (CASE WHEN @cMoveQTYPick = '0' THEN LLI.QTYPicked ELSE 0 END) > 0 

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayByID -- For rollback or commit only our own transaction

      -- Get suggest LOC
      DECLARE @nPAErrNo INT
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_PutawayByID_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
         ,@cFromLOC
         ,@cFromID
         ,@cSuggLOC        OUTPUT
         ,@cPickAndDropLOC OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo        OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         
         ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_1_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_1_Fail
            END
         END
      END
      
      -- Check no suggest LOC (but allow user go to next screen scan another LOC)
      IF @nPAErrNo = -1
      BEGIN
         SET @nErrNo = 52756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
      SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to Suggest LOC screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            SET @cOutField15 = @cExtendedInfo
         END
      END
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
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_ExtScn
   END

   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFromID = ''
      SET @cOutField01 = '' -- FromID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 4111. TO LOC
   FROM ID     (Field01, input)
   Suggest LOC (Field02)
   TO LOC      (Field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 52753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TO LOC
         GOTO Step_2_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1819ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1819ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cSuggLOC OUTPUT ,@cToLOC OUTPUT,@cPickAndDropLOC OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END
      
		-- (james04)        
		IF @cLOCLookupSP = 1              
		BEGIN              
			EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,               
			   @cToLOC     OUTPUT,               
			   @nErrNo     OUTPUT,               
			   @cErrMsg    OUTPUT              

			IF @nErrNo <> 0              
				GOTO Step_2_Fail              
		END 

      -- Check TO LOC valid
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)
      BEGIN
         SET @nErrNo = 52754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail
      END

      -- Check if suggested LOC match
      IF (@cToLOC <> @cSuggLOC AND @cPickAndDropLOC = '') OR      -- Not match suggested LOC
         (@cToLOC <> @cPickAndDropLOC AND @cPickAndDropLOC <> '') -- Not match PND LOC
      BEGIN
         IF @cPAMatchSuggestLOC = '1'
         BEGIN
            SET @nErrNo = 52757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
            GOTO Step_2_Fail
         END
         ELSE IF @cPAMatchSuggestLOC = '2'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- Option
            
            -- Go to LOC not match screen
            SET @nScn = @nScn + 3
            SET @nStep = @nStep + 3
            
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayByID -- For rollback or commit only our own transaction

      -- Confirm task         
      EXEC rdt.rdt_PutawayByID_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
         ,@cFromLOC
         ,@cFromID
         ,@cSuggLOC
         ,@cPickAndDropLOC
         ,@cToLOC
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_2_Fail
            END
         END
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLocation     = @cFromLOC,
         @cToLocation   = @cToLOC,
         @cID           = @cFromID

      IF @cShowPASuccessScn = '1'
      BEGIN
         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- FromID

         -- Go to FromID screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --cSuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO Step_2_Fail

         SET @nPABookingKey = 0
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_2_Fail
            END
         END
      END


      -- Prepare next screen var
      SET @cOutField01 = '' --FromID

      -- Go to FromID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField03 = '' -- TOLOC
   END
END
GOTO Quit

/********************************************************************************
Step 3. scn = 4112. Message screen
   Successful putaway
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- FromID

      -- Go to FromID screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
END
GOTO Quit

/***********************************************************************************
Scn = 2324. Parameter screen
   Report       (field11)
   Param1 label (field01)
   Param1       (field02, input)
   Param2 label (field03)
   Param2       (field04, input)
   Param3 label (field05)
   Param3       (field06, input)
   Param4 label (field07)
   Param4       (field08, input)
   Param5 label (field09)
   Param5       (field10, input)
***********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1 = @cInField02
      SET @cParam2 = @cInField04
      SET @cParam3 = @cInField06
      SET @cParam4 = @cInField08
      SET @cParam5 = @cInField10

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      -- Extended validate
      IF @cPalletCriteriaSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPalletCriteriaSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cPalletCriteriaSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

         END
      END

      -- Go to Pallet ID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
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
   END

   -- Prepare prev screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''

   -- Enable field
   SET @cFieldAttr02 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr10 = ''
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 4114.
   LOC not match. Proceed?
   1 = YES
   2 = NO
   OPTION (Input, Field01)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 73883
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req
         GOTO Quit
      END
      
      -- Check optin valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 73884
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               SET @cOutField01 = ''
               GOTO Quit
            END
         END
      END


      IF @cOption = '1' -- YES
      BEGIN

         --FCR-122 GOTO Reason Code Screen
         IF @cExtScnSP = 'rdt_1819ExtScn02'
         BEGIN
            GOTO Step_ExtScn
         END

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_PutawayByID -- For rollback or commit only our own transaction

         -- Confirm task         
         EXEC rdt.rdt_PutawayByID_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
            ,@cFromLOC
            ,@cFromID
            ,@cSuggLOC
            ,@cPickAndDropLOC
            ,@cToLOC
            ,@nErrNo    OUTPUT
            ,@cErrMsg   OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' + 
                  '@cFromID         NVARCHAR( 18), ' +
                  '@cSuggLOC        NVARCHAR( 10), ' +
                  '@cPickAndDropLOC NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@nErrNo          INT           OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  SET @cOutField01 = ''
                  GOTO Quit
               END
            END
         END

         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Logging
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cLocation     = @cFromLOC,
            @cToLocation   = @cToLOC,
            @cID           = @cFromID

         IF @cShowPASuccessScn = '1'
         BEGIN
            -- Go to next screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- FromID

            -- Go to FromID screen
            SET @nScn  = @nScn - 4
            SET @nStep = @nStep - 4
         END
      END

      IF @cOption = '2' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
         SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
         SET @cOutField15 = '' -- ExtendedInfo

         -- Go to Suggest LOC screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, ' + 
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nAfterStep      INT,           ' +
                  '@nInputKey       INT,           ' + 
                  '@cFromID         NVARCHAR( 18), ' +
                  '@cSuggLOC        NVARCHAR( 10), ' +
                  '@cPickAndDropLOC NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo          INT           OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               SET @cOutField15 = @cExtendedInfo
            END
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
      SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to Suggest LOC screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFromID         NVARCHAR( 18), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit
END

/********************************************************************************
Scn = 4115. REASON CODE
   REASON CODE:          (field01, input)
********************************************************************************/

Step_ExtScn:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData

         INSERT INTO @tExtScnData (Variable, Value) VALUES
            ('@cFromLOC',             @cFromLOC),
            ('@cFromID',              @cFromID ),
            ('@cSuggLOC',             @cSuggLOC),
            ('@cPickAndDropLOC',      @cPickAndDropLOC),
            ('@cToLOC',               @cToLOC)

         EXECUTE [RDT].[rdt_ExtScnEntry]
                 @cExtScnSP,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
                 @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
                 @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
                 @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
                 @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
                 @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
                 @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
                 @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
                 @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
                 @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
                 @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
                 @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
                 @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
                 @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
                 @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
                 @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
                 @nAction,
                 @nScn     OUTPUT,  @nStep OUTPUT,
                 @nErrNo   OUTPUT,
                 @cErrMsg  OUTPUT,
                 @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
                 @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
                 @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
                 @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
                 @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
                 @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
                 @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
                 @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
                 @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
                 @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @cUDF01 <> ''
            SET @cToLOC = @cUDF01

         IF @nErrNo <> 0
            GOTO Step_99_Fail

      END
   END

   GOTO Quit

   Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END

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

      V_StorerKey = @cStorerKey, 
      V_ID        = @cFromID,
      V_LOC       = @cFromLOC,

      V_String1  = @cSuggLOC,
      V_String2  = @cPickAndDropLOC,
      V_String3  = @cToLOC,
      V_String4  = @cExtendedValidateSP,
      V_String5  = @cExtendedUpdateSP,
      V_String6  = @cExtendedInfoSP,
      V_String7  = @cExtendedInfo,
      V_String8  = @cPalletCriteriaSP,
      V_String9  = @cDefaultToLOC, 
      V_String10 = @cDecodeSP,
      V_String11 = @cShowPASuccessScn,
      V_String12 = @cPalletCriteria,
      V_String13 = @cParam1,
      V_String14 = @cParam2,
      V_String15 = @cParam3,
      V_String16 = @cParam4,
      V_String17 = @cParam5,
      V_String18 = @cLOCLookupSP,
      V_String19 = @cPAMatchSuggestLOC,
      V_String20 = @cExtScnSP,

      V_Integer1 = @nPABookingKey, 

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