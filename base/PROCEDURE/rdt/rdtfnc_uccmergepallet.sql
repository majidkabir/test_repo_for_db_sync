SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCMergePallet                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Merge UCC pallet before ASN finalize                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-09-19 1.0  Ung      SOS256003 Created                           */
/* 2014-03-21 1.2  TLTING   Bug fix                                     */
/* 2016-09-30 1.3  Ung      Performance tuning                          */
/* 2017-02-13 1.4  Leong    IN00251879 - Revise StdEventLog.            */
/* 2018-10-08 1.5  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCMergePallet] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cUCCNo        NVARCHAR( 20),
   @cFinalizeFlag NVARCHAR( 1),
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
   @nFromStep   INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName   NVARCHAR(18),
   @cPrinter    NVARCHAR(10),

   @cReceiptKey NVARCHAR( 10),
   @cLOC        NVARCHAR( 10),

   @cFromID           NVARCHAR( 20),
   @cToID             NVARCHAR( 20),
   @cOption           NVARCHAR( 1),
   @cScanned          NVARCHAR( 5),
   @cExtendedUpdateSP NVARCHAR( 20),
   @cPutawayPallet    NVARCHAR( 1),
   --@cFromStep         NVARCHAR( 1),
   @cPutawayPalletCountUCC NVARCHAR( 1),

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
   @cPrinter    = Printer,

   @cReceiptKey = V_ReceiptKey,
   @cLOC        = V_LOC,
   
   @nFromStep   = V_FromStep,

   @cFromID           = V_String1,
   @cToID             = V_String2,
   @cOption           = V_String3,
   @cScanned          = V_String4,
   @cExtendedUpdateSP = V_String5,
   @cPutawayPallet    = V_String6,
   @cPutawayPalletCountUCC = V_String8,

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
IF @nFunc = 528
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 3180. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3181. To ID, merge pallet
   IF @nStep = 3 GOTO Step_3   -- Scn = 3182. UCC
   IF @nStep = 4 GOTO Step_4   -- Scn = 3183. Putaway pallet?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3180
   SET @nStep = 1

   -- Init var

   -- Get StorerConfig
   SET @cPutawayPallet = rdt.RDTGetConfig( 528, 'PutawayPallet', @cStorerKey)
   SET @cPutawayPalletCountUCC = rdt.RDTGetConfig( @nFunc, 'PutawayPalletCountUCC', @cStorerKey)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( 528, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cFromID = ''
   SET @cOutField01 = ''  -- From ID

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

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3180
   FROM ID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01

      -- Check blank
      IF @cFromID = ''
      BEGIN
         SET @nErrNo = 76951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromID needed
         GOTO Step_1_Fail
      END

      -- Get From ID info
      SET @cReceiptKey = ''
      SET @cFinalizeFlag = ''
      SET @cLOC = ''
      SELECT TOP 1
         @cReceiptKey = R.ReceiptKey,
         @cFinalizeFlag = RD.FinalizeFlag,
         @cLOC = RD.ToLOC
      FROM dbo.Receipt R WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND RD.ToID = @cFromID

      -- Check FromID valid
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 76952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid FromID
         GOTO Step_1_Fail
      END

      -- Check FromID status
      IF @cFinalizeFlag = 'Y'
      BEGIN
         SET @nErrNo = 76953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID finalized
         GOTO Step_1_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = '' -- ToID
      SET @cOutField03 = ''

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
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
      SET @cOutField01 = '' -- Clean up for menu option

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

   Step_1_Fail:
   BEGIN
      SET @cFromID = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 3181
   FROM ID         (Field01)
   TO ID           (Field12, input)
   MERGE PALLET:   (Field03, input)
   1 = Yes
   2 = No
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02
      SET @cOption = @cInField03

      -- Check blank
      IF @cToID = ''
      BEGIN
         SET @nErrNo = 76954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TO ID
         GOTO Step_2_Fail
      END

      -- Check both ID same
      IF @cFromID = @cToID
      BEGIN
         SET @nErrNo = 76955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Both ID Same
         GOTO Step_2_Fail
      END

      -- Get ToID info
      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cChkLOC NVARCHAR( 10)
      SET @cChkReceiptKey = ''
      SET @cFinalizeFlag = ''
      SET @cChkLOC = ''
      SELECT TOP 1
         @cChkReceiptKey = R.ReceiptKey,
         @cFinalizeFlag = RD.FinalizeFlag,
         @cChkLOC = RD.ToLOC
      FROM dbo.Receipt R WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND RD.ToID = @cToID

      -- Check ToID valid
      IF @cChkReceiptKey = ''
      BEGIN
         SET @nErrNo = 76956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToID
         GOTO Step_2_Fail
      END

      -- Check different ASN
      IF @cReceiptKey <> @cChkReceiptKey
      BEGIN
         SET @nErrNo = 76957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different ASN
         GOTO Step_2_Fail
      END

      -- Check different LOC
      IF @cLOC <> @cChkLOC
      BEGIN
         SET @nErrNo = 76958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Diff LOC
         GOTO Step_2_Fail
      END

      -- Check ToID status
      IF @cFinalizeFlag = 'Y'
      BEGIN
         SET @nErrNo = 76959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID finalized
         GOTO Step_2_Fail
      END

      -- Retain ToDropID
      SET @cOutField02 = @cToID

      -- Validate Option is blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 76960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Validate Option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 76961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- ExtendedUpdateSP
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cLOC, @cFromID, @cToID, @cOption, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile    INT,       ' +
               '@nFunc      INT,       ' +
               '@nStep      INT,       ' +
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' +
               '@cLOC       NVARCHAR( 10), ' +
               '@cFromID    NVARCHAR( 18), ' +
               '@cToID      NVARCHAR( 18), ' +
               '@cOption    NVARCHAR( 1),  ' +
               '@cUCCNo     NVARCHAR( 20), ' +
               '@nErrNo     INT OUTPUT, ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               ,@nMobile
               ,@nFunc
               ,@nStep
               ,@cLangCode
               ,@cStorerKey
               ,@cLOC
               ,@cFromID
               ,@cToID
               ,@cOption
               ,'' -- @cUCCNo
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      -- Merge by pallet
      IF @cOption = '1'
      BEGIN
         -- Merge
         EXEC rdt.rdt_UCCMergePallet_Confirm @nFunc, @nMobile, @cLangCode
            ,@cStorerKey
            ,@cFacility
            ,@cReceiptKey
            ,@cLOC
            ,@cFromID
            ,@cToID
            ,'' --@cUCCNo
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail

         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cID           = @cFromID,
            @cToID         = @cToID,
            @cReceiptKey   = @cReceiptKey,-- IN00251879
            @nStep         = @nStep

         -- Prep next screen var
         SET @cOutField01 = '' -- Option

         IF @cPutawayPallet = '1'
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' -- Option
            SET @cOutField02 = '' -- Count UCC

            -- Go to putaway pallet screen
            SET @nFromStep = 2
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2

            IF @cPutawayPalletCountUCC <> '1'
               SET @cFieldAttr02 = 'O' -- Count UCC
         END
         ELSE
         BEGIN
            -- Go to FromID screen
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2

            DECLARE @cErrMsg1 NVARCHAR( 20)
            SET @cErrMsg1 = rdt.rdtgetmessage( 76962, @cLangCode, 'DSP') --MERGE SUCCESSFUL
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         END
      END

      -- Merge by carton
      IF @cOption = '2'
      BEGIN
         SET @cScanned = '0'
         SET @cOutField01 = @cToID
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = @cScanned

         -- Go to UCC screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cFromID = ''
      SET @cOutField01 = '' --FromID

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField02 = '' -- To ID
      EXEC rdt.rdtSetFocusField @nMobile, 2 --ToID
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen 3182
   TO ID:   (Field01)
   UCC:     (Field02, input)
   SCANNED: (Field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField02

      -- Validate blank
      IF @cUCCNo = ''
      BEGIN
         IF @cPutawayPallet = '1' AND @cScanned > '0'
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = '' -- Option
            SET @cOutField02 = '' -- Count UCC

            -- Go to putaway pallet screen
            SET @nFromStep = 3
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1

            IF @cPutawayPalletCountUCC <> '1'
               SET @cFieldAttr02 = 'O' -- Count UCC

            GOTO Quit
         END

         SET @nErrNo = 76963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC needed
         GOTO Step_3_Fail
      END

      -- Check UCC valid
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo)
      BEGIN
         SET @nErrNo = 76964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
         GOTO Step_3_Fail
      END

      -- Check UCC on From ID
      IF NOT EXISTS (SELECT 1
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCCNo
            AND StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND ID = @cFromID
            AND Status = '1')
      BEGIN
         SET @nErrNo = 76965
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC not on ID
         GOTO Step_3_Fail
      END

      -- Check extended validation
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cLOC, @cFromID, @cToID, @cOption, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile    INT,       ' +
               '@nFunc      INT,       ' +
               '@nStep      INT,       ' +
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' +
               '@cLOC       NVARCHAR( 10), ' +
               '@cFromID    NVARCHAR( 18), ' +
               '@cToID      NVARCHAR( 18), ' +
               '@cOption    NVARCHAR( 1),  ' +
               '@cUCCNo     NVARCHAR( 20), ' +
               '@nErrNo     INT OUTPUT, ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               ,@nMobile
               ,@nFunc
               ,@nStep
               ,@cLangCode
               ,@cStorerKey
               ,@cLOC
               ,@cFromID
               ,@cToID
               ,@cOption
               ,@cUCCNo
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Merge
      EXEC rdt.rdt_UCCMergePallet_Confirm @nFunc, @nMobile, @cLangCode
         ,@cStorerKey
         ,@cFacility
         ,@cReceiptKey
         ,@cLOC
         ,@cFromID
         ,@cToID
         ,@cUCCNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cID           = @cFromID,
         @cToID         = @cToID,
         --@cRefNo1       = @cUCCNo,
         @cUCC          = @cUCCNo,
         @cReceiptKey   = @cReceiptKey,-- IN00251879
         @nStep         = @nStep

      SET @cScanned = CAST( @cScanned AS INT) + 1

      -- Remain in current screen
      SET @cUCCNo = ''
      SET @cOutField01 = @cToID
      SET @cOutField02 = ''
      SET @cOutField03 = @cScanned

      -- Remain in current screen
      -- SET @nScn  = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = '' --ToID
      SET @cOutField03 = @cOption

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- FromDropID
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cUCCNo = ''
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 3183
   Putaway pallet?
   1 = YES
   2 = NO
   OPTION: (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cCountUCC NVARCHAR(2)

      --screen mapping
      SET @cOption = @cInField01
      SET @cCountUCC = @cInField02

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 76966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 76967
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = '' --option
         SET @cOption = ''
         GOTO Quit
      END

      -- Putaway pallet
      IF @cOption = '1' -- 1=YES
      BEGIN
         -- Check UCC count
         IF @cPutawayPalletCountUCC = '1'
         BEGIN
            -- Check count valid
            IF rdt.rdtIsValidQTY( @cCountUCC, 1) = 0  --1=Validate zero
            BEGIN
               SET @nErrNo = 76968
               SET @cErrMsg = rdt.rdtgetmessage(63134, @cLangCode, 'DSP') --Invalid QTY
               GOTO Quit
            END

            -- Count UCC on pallet
            DECLARE @nCountUCConID INT
            SELECT @nCountUCConID = COUNT( DISTINCT UCCNo)
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ID = @cToID

            -- Check UCC on ID
            IF CAST( @cCountUCC AS INT) <> @nCountUCConID
            BEGIN
               SET @nErrNo = 76969
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong count
               GOTO Quit
            END
         END

         -- Check extended validation
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cLOC, @cFromID, @cToID, @cOption, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile    INT,       ' +
                  '@nFunc      INT,       ' +
                  '@nStep      INT,       ' +
                  '@cLangCode  NVARCHAR( 3),  ' +
                  '@cStorerKey NVARCHAR( 15), ' +
                  '@cLOC       NVARCHAR( 10), ' +
                  '@cFromID    NVARCHAR( 18), ' +
                  '@cToID      NVARCHAR( 18), ' +
                  '@cOption    NVARCHAR( 1),  ' +
                  '@cUCCNo     NVARCHAR( 20), ' +
                  '@nErrNo     INT OUTPUT, ' +
                  '@cErrMsg    NVARCHAR( 20) OUTPUT'
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam
                  ,@nMobile
                  ,@nFunc
                  ,@nStep
                  ,@cLangCode
                  ,@cStorerKey
                  ,@cLOC
                  ,@cFromID
                  ,@cToID
                  ,@cOption
                  ,@cUCCNo
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      -- Prepare next screen
      SET @cFromID = ''
      SET @cOutField01 = '' -- FromID

      SET @cFieldAttr02 = '' -- Count UCC

      -- Go to FromID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

/*
   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cFromStep = '2' -- ToID
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = '' --ToID
         SET @cOutField03 = @cOption

         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END

      IF @cFromStep = '3' -- UCC
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = '' --UCC
         SET @cOutField03 = @cScanned

         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END

      SET @cFieldAttr02 = '' -- Count UCC
   END
*/
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,-- (Vicky06)
      Printer    = @cPrinter,

      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cLOC,
      V_FromStep   = @nFromStep,

      V_String1  = @cFromID,
      V_String2  = @cToID,
      V_String3  = @cOption,
      V_String4  = @cScanned,
      V_String5  = @cExtendedUpdateSP,
      V_String6  = @cPutawayPallet,
      V_String8  = @cPutawayPalletCountUCC,

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