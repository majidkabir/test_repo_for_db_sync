SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_PrePalletizeSort_Reversal                    */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Pre palletize sorting reversal (scan ucc to remove)         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2023-10-13   1.0  James    WMS-23812. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PrePalletizeSort_Reversal] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nAfterStep  INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,
   @nMorePage   INT,
   @bSuccess    INT,
   @nTranCount  INT,
   @nFromScn    INT,
   @nFromStep   INT,
   @nCount      INT = 0,
   
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @cBarcode            NVARCHAR( 60),
   @cReceiptKey         NVARCHAR( 10),
   @cLane               NVARCHAR( 10),
   @cUCC                NVARCHAR( 20),
   @cToID               NVARCHAR( 18),
   @cChkFacility        NVARCHAR( 5),
   @cChkStorerKey       NVARCHAR( 15),
   @cChkReceiptKey      NVARCHAR( 10),
   @cReceiptStatus      NVARCHAR( 10),
   @cUCCStatus          NVARCHAR( 10),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @tExtValidVar        VariableTable,
   @tExtUpdateVar       VariableTable,
   @tExtInfoVar         VariableTable,
   
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

-- Getting Mobile information
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

   @cReceiptKey = V_ReceiptKey,
   @cLane       = V_LOC,
   @cToID       = V_ID,
   @cUCC        = V_UCC,

   @nFromScn    = V_FromScn,
   @nFromStep   = V_FromStep,

   @nCount      = V_Integer1,
   
   @cExtendedInfoSP        =  V_String1,
   @cExtendedValidateSP    =  V_String2,
   @cExtendedUpdateSP      =  V_String3,
   
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

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ASN              INT,  @nScn_ASN            INT,
   @nStep_TOIDLANE         INT,  @nScn_TOIDLANE       INT,
   @nStep_UCC              INT,  @nScn_UCC            INT

SELECT
   @nStep_ASN           = 1,    @nScn_ASN          = 6290,
   @nStep_TOIDLANE      = 2,    @nScn_TOIDLANE     = 6291,
   @nStep_UCC           = 3,    @nScn_UCC          = 6292


IF @nFunc = 1865 -- Pre Palletize Sort Reversal
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0           -- Start
   IF @nStep = 1 GOTO Step_ASN         -- Scn = 6290. ASN
   IF @nStep = 2 GOTO Step_TOIDLANE    -- Scn = 6291. TO ID, LANE
   IF @nStep = 3 GOTO Step_UCC         -- Scn = 6292. UCC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1865. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Initialize value
   SET @cReceiptKey = ''
   SET @cLane = ''
   SET @cToID = ''
   SET @cUCC = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''
   
   -- Prep next screen var
   SET @cOutField01 = '' -- ASN

   SET @nScn = @nScn_ASN
   SET @nStep = @nStep_ASN

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
Step 1. Scn = 6290
   ASN      (field01, input)
********************************************************************************/
Step_ASN:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01

      IF ISNULL( @cReceiptKey, '') = ''
      BEGIN
         SET @nErrNo = 207351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
         GOTO Step_ASN_Fail
      END

      -- Get the ASN info
      SELECT
         @cChkFacility = Facility,
         @cChkStorerKey = StorerKey,
         @cChkReceiptKey = ReceiptKey,
         @cReceiptStatus = ASNStatus
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 207352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Step_ASN_Fail
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 207353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_ASN_Fail
      END

      -- Validate ASN belong to the storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 207354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Step_ASN_Fail
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 207355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         GOTO Step_ASN_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_UCC_Fail
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Goto UCC screen
      SET @nScn  = @nScn_TOIDLANE
      SET @nStep = @nStep_TOIDLANE
      
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_ASN_Fail:
   BEGIN
      -- Reset this screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = ''
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 6291
   TO ID    (field01, input)
   LANE     (field02, input)
********************************************************************************/
Step_TOIDLANE:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02
      SET @cLane = @cInField03

      IF ISNULL( @cToID, '') = ''
      BEGIN
         SET @nErrNo = 207356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOID required
         GOTO Step_TOID_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0
      BEGIN
         SET @nErrNo = 207357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_TOID_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   ID = @cToID)
      BEGIN
         SET @nErrNo = 207358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToID
         GOTO Step_TOID_Fail
      END

      IF ISNULL( @cLane, '') = ''
      BEGIN
         SET @nErrNo = 207359
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane
         GOTO Step_Lane_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   Loc = @cLane)
      BEGIN
         SET @nErrNo = 207360
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane
         GOTO Step_Lane_Fail
      END

      -- Get the Lane info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLane

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 207361
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lane
         GOTO Step_Lane_Fail
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 207362
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_Lane_Fail
      END

      IF NOT EXISTS ( SELECT 1
                      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   Facility = @cFacility
                      AND   Loc = @cLane
                      AND   ID = @cToID)
      BEGIN
         SET @nErrNo = 207363
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Record
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_UCC_Fail
         END
      END

      SET @cUCC = ''
      SET @nCount = 0
      
      -- Prep next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cLane
      SET @cOutField03 = ''

      -- Goto UCC screen
      SET @nScn  = @nScn_UCC
      SET @nStep = @nStep_UCC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- ASN

      SET @nScn = @nScn_ASN
      SET @nStep = @nStep_ASN
   END
   GOTO Quit

   Step_TOID_Fail:
   BEGIN
      SET @cTOID = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''
      SET @cOutField03 = @cLane
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   GOTO Quit
   
   Step_LANE_Fail:
   BEGIN
      SET @cLane = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cToID
      SET @cOutField03 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6292.
   TO ID       (field01)
   LANE        (field02)
   UCC         (field03, input)
********************************************************************************/
Step_UCC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField03
      SET @cBarcode = @cInField03

      IF ISNULL( @cUCC, '') = ''
      BEGIN
         SET @nErrNo = 207364
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC required
         GOTO Step_UCC_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cUCC) = 0  
      BEGIN  
         SET @nErrNo = 207365  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_UCC_Fail  
      END 

      IF NOT EXISTS ( SELECT 1
                      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   Facility = @cFacility
                      AND   Loc = @cLane
                      AND   ID = @cToID
                      AND   UCCNo = @cUCC)
      BEGIN  
         SET @nErrNo = 207366  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists 
         GOTO Step_UCC_Fail  
      END 
                      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cToID, @cLane, @cUCC, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_UCC_Fail
         END
      END

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_PreSortReversal
   
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PrePalletizeSort_Reversal]
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cToID         = @cToID,
         @cLane         = @cLane,
         @cUCC          = @cUCC,
         @nErrNo        = @nErrNo         OUTPUT,
         @cErrMsg       = @cErrMsg        OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdt_PreSortReversal
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_UCC_Fail
      END               

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cToID, @cLane, @cUCC, @tExtUpdateVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @tExtUpdateVar  VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cToID, @cLane, @cUCC, @tExtUpdateVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdt_PreSortReversal
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_UCC_Fail
            END               
         END
      END

      COMMIT TRAN rdt_PreSortReversal
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
         
      IF @nErrNo <> 0
         GOTO Step_UCC_Fail

      SET @nCount = @nCount + 1

      -- EventLog --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep,
         @cUCC        = @cUCC,
         @cReceiptKey = @cReceiptKey,
         @cToID       = @cToID,
         @cLane       = @cLane

      -- Prep next screen var
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cLane
      SET @cOutField03 = ''
      SET @cOutField04 = @nCount

      -- Remain in current screen
      SET @nScn  = @nScn_UCC
      SET @nStep = @nStep_UCC
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Goto UCC screen
      SET @nScn  = @nScn_TOIDLANE
      SET @nStep = @nStep_TOIDLANE
   END
   GOTO Quit

   Step_UCC_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField03 = ''
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
      UserName  = @cUserName,

      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cLane,
      V_ID         = @cToID,
      V_UCC        = @cUCC,

      V_FromScn    = @nFromScn,
      V_FromStep   = @nFromStep,

      V_Integer1   = @nCount,
      
      V_String1 = @cExtendedInfoSP,
      V_String2 = @cExtendedValidateSP,
      V_String3 = @cExtendedUpdateSP,

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