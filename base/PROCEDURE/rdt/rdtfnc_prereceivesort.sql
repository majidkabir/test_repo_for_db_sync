SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PreReceiveSort                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pre receive sorting                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 14-Feb-2017  1.0  James    WMS1073 - Created                         */
/* 02-Oct-2018  1.1  TungGH   Performance                               */
/* 03-Jan-2019  1.2  James    WMS7488-Add ExtendedValidateSP (james01)  */
/* 05-Nov-2019  1.3  Chermaine WMS11031-Add EventLog (cc01)             */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PreReceiveSort] (
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
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX), 

   @cGetUCCStatSP       NVARCHAR( 20),
   @cReceiptKey         NVARCHAR( 10),
   @cLane               NVARCHAR( 10),
   @cUCC                NVARCHAR( 20), 
   @cChkFacility        NVARCHAR( 5), 
   @cChkStorerKey       NVARCHAR( 15),
   @cChkReceiptKey      NVARCHAR( 10),
   @cReceiptStatus      NVARCHAR( 10),
   @cUCCStatus          NVARCHAR( 10),
   @cPosition           NVARCHAR( 20),
   @cRecordCount        NVARCHAR( 20),
   @cReceiveDefaultToLoc   NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @tVar                VariableTable,

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
   @cUCC        = V_UCC,

   @cGetUCCStatSP = V_String1,
   @cReceiveDefaultToLoc   =  V_String2,
   @cExtendedInfoSP        =  V_String3,
   @cExtendedValidateSP    =  V_String4,

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

IF @nFunc = 1825 -- Pre Receive Sort 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry SKU
   IF @nStep = 1 GOTO Step_1   -- Scn = 4801. ASN, LANE
   IF @nStep = 2 GOTO Step_2   -- Scn = 4801. UCC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4802. UCC/Position
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1825. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Initialize value
   SET @cReceiptKey = ''
   SET @cLane = ''

   SET @cGetUCCStatSP = rdt.RDTGetConfig( @nFunc, 'GetUCCStatSP', @cStorerkey)
   IF @cGetUCCStatSP IN ('0', '')
      SET @cGetUCCStatSP = ''

   -- Get receive DefaultToLoc
   SET @cReceiveDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
   IF @cReceiveDefaultToLoc IN ('', '0')
      SET @cReceiveDefaultToLoc = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- ASN
   SET @cOutField02 = RTRIM( @cReceiveDefaultToLoc) -- Lane

   SET @nScn = 4800
   SET @nStep = 1

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
Step 1. Scn = 4800
   ASN      (field01, input)   
   LANE     (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cLane = @cInField02

      IF ISNULL( @cReceiptKey, '') = '' 
      BEGIN
         SET @nErrNo = 106001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
         GOTO Step_1a_Fail
      END

      IF ISNULL( @cLane, '') = ''
      BEGIN
         SET @nErrNo = 106002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane
         GOTO Step_1b_Fail
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
         SET @nErrNo = 106003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Step_1a_Fail
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 106004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_1a_Fail
      END

      -- Validate ASN belong to the storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 106005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Step_1a_Fail
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 106006
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         GOTO Step_1a_Fail
      END

      -- Get the Lane info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cLane

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 106007
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lane
         GOTO Step_1b_Fail
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 106008
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_1b_Fail
      END

      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLane
      SET @cOutField03 = ''

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
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

   Step_1a_Fail:
   BEGIN
      -- Reset this screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cLane
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_1b_Fail:
   BEGIN
      -- Reset this screen var
      SET @cLane = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4801. 
   ASN         (field01)
   LANE        (field02)
   UCC         (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField03

      IF ISNULL( @cUCC, '') = ''
      BEGIN
         SET @nErrNo = 106009
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC required
         GOTO Step_2_Fail
      END

      SELECT @cUCCStatus = [Status],
             @cSKU   = SKU
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 106010
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
         GOTO Step_2_Fail
      END

      IF @cUCCStatus <> '0'
      BEGIN
         SET @nErrNo = 106011
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Received
         GOTO Step_2_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES 
               ('@cReceiptKey',  @cReceiptKey), 
               ('@cLane',        @cLane), 
               ('@cUCC',         @cUCC), 
               ('@cSKU',         @cSKU)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
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
               ' @tVar           VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail            
         END
      END

      SET @nErrNo = 0
      IF @cGetUCCStatSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetUCCStatSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetUCCStatSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, ' + 
            ' @cPosition OUTPUT, @cRecordCount OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cReceiptKey     NVARCHAR( 20), ' +
            '@cLane           NVARCHAR( 10), ' +
            '@cUCC            NVARCHAR( 20), ' + 
            '@cSKU            NVARCHAR( 20), ' + 
            '@cPosition       NVARCHAR( 20)  OUTPUT, ' +  
            '@cRecordCount    NVARCHAR( 20)  OUTPUT, ' +  
            '@nErrNo          INT            OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, 
               @cPosition OUTPUT, @cRecordCount OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      END
      ELSE
      BEGIN
         EXEC [RDT].[rdt_PreRcvSortGetUCCStat] 
            @nMobile       = @nMobile,
            @nFunc         = @nFunc, 
            @cLangCode     = @cLangCode,
            @nStep         = @nStep, 
            @nInputKey     = @nInputKey, 
            @cStorerKey    = @cStorerKey, 
            @cFacility     = @cFacility, 
            @cReceiptKey   = @cReceiptKey, 
            @cLane         = @cLane, 
            @cUCC          = @cUCC,  
            @cSKU          = @cSKU,  
            @cPosition     = @cPosition      OUTPUT,   
            @cRecordCount  = @cRecordCount   OUTPUT,   
            @nErrNo        = @nErrNo         OUTPUT, 
            @cErrMsg       = @cErrMsg        OUTPUT 
      END

      IF @nErrNo <> 0
         GOTO Step_2_Fail

     IF @cExtendedInfoSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, ' + 
            ' @cPosition, @cRecordCount, @cExtendedInfo OUTPUT '    

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cReceiptKey     NVARCHAR( 20), ' +
            '@cLane           NVARCHAR( 10), ' +
            '@cUCC            NVARCHAR( 20), ' + 
            '@cSKU            NVARCHAR( 20), ' + 
            '@cPosition       NVARCHAR( 20), ' +  
            '@cRecordCount    NVARCHAR( 20), ' +  
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT'   

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, 
               @cPosition, @cRecordCount, @cExtendedInfo OUTPUT 
      END
      
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
         @cLane       = @cLane   
         
         
      -- Prep next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cPosition
      SET @cOutField03 = @cRecordCount
      SET @cOutField15 = @cExtendedInfo

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cReceiptKey = ''
      SET @cLane = @cReceiveDefaultToLoc
      SET @cUCC = ''

      SET @cOutField01 = ''
      SET @cOutField02 = @cLane

      EXEC rdt.rdtSetFocusField @nMobile, 1
      
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 4782. Result
   Sku         (field01)
   Descr1      (field02)
   Descr2      (field03)
   Summary     (field04)
   Pick Loc    (field05)
   No Of Loc   (field06)
   SKU1        (field07)
   SKU2        (field08)
   SKU3        (field09)
   SKU4        (field10)
   SKU5        (field08)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cUCC = ''

      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLane
      SET @cOutField03 = ''

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cUCC = ''

      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLane
      SET @cOutField03 = ''
            
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
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
      V_UCC        = @cUCC,

      V_String1 = @cGetUCCStatSP,
      V_String2 = @cReceiveDefaultToLoc,
      V_String3 = @cExtendedInfoSP,
      V_String4 = @cExtendedValidateSP,

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