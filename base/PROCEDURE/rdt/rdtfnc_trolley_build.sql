SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_Trolley_Build                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS259761. Created                        */
/* 2015-06-11 1.1  Ung        SOS343960.                                */
/*                            Change ExtendedUpdate to ExtendedValidate */
/* 2016-09-30 1.2  Ung        Performance tuning                        */   
/* 2017-03-24 1.3  James      WMS1398 - Support UCC.Status = 3 (james01)*/
/* 2018-10-02 1.4  TungGH     Performance                               */   
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_Trolley_Build] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cTrolleyPos      NVARCHAR( 4), 
   @cSQL             NVARCHAR(1000),
   @cSQLParam        NVARCHAR(1000)

-- rdt.rdtMobRec variable
DECLARE
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @nMenu             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
                      
   @cStorerKey        NVARCHAR( 15),
   @cFacility         NVARCHAR( 5),
   @cUserName         NVARCHAR(18),
   @cPrinter          NVARCHAR( 10),
                      
   @cUCC              CHAR (20), 
   @cSuggestedLOC     NVARCHAR( 10),
   @cSuggestedID      NVARCHAR( 18),
   @cPutawayZone      NVARCHAR( 10),
   @cTaskDetailKey    NVARCHAR( 10), 
   @cTrolleyNo        NVARCHAR( 10),
   @cExtendedValidateSP NVARCHAR( 20),

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

   @cFieldAttr01 NVARCHAR( 1),
   @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1),
   @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @nInputKey  = InputKey,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cUCC          = V_UCC, 
   @cSuggestedLOC = V_LOC,
   @cSuggestedID  = V_ID,
   @cPutawayZone  = V_Zone,
   @cTaskDetailKey = V_TaskDetailKey, 

   @cTrolleyNo          = V_String1,
   @cExtendedValidateSP = V_String2,
   
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

   @cFieldAttr01 = FieldAttr01,
   @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,
   @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc in (740)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 740
   IF @nStep = 1 GOTO Step_1  -- Scn = 3400. UCC
   IF @nStep = 2 GOTO Step_2  -- Scn = 3401. PWAYZONE, LOC
   IF @nStep = 3 GOTO Step_3  -- Scn = 3402. Option. Close trolley
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 740
********************************************************************************/
Step_0:
BEGIN
   -- Init var
   SET @cUCC = ''

   -- Get storer config
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Sign-in
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign in function
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

   -- Go to next screen
   SET @nScn = 3400
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3400
   UCC       (field01, input)
   TrolleyNo (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01
      SET @cTrolleyNo = @cInField02 --TrolleyNo

      -- Check blank
      IF @cUCC = '' AND @cTrolleyNo = ''
      BEGIN
         SET @nErrNo = 79051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC or Trolley
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
         GOTO Step_1_Fail
      END

      -- Check both key-in
      IF @cUCC <> '' AND @cTrolleyNo <> ''
      BEGIN
         SET @nErrNo = 79052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key-in either
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
         GOTO Step_1_Fail
      END

      -- UCC
      IF @cUCC <> ''
      BEGIN
         -- Check UCC
         IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 79053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC not exist
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
         
         -- Check UCC valid
         IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                        WHERE UCCNo = @cUCC 
                        AND   StorerKey = @cStorerKey 
                        AND   Status IN ('1', '3'))   -- (james01)
         BEGIN
            SET @nErrNo = 79054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC status
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
         
         -- Check UCC scanned
         IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE UCCNo = @cUCC)
         BEGIN
            SET @nErrNo = 79055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END
      
         DECLARE @cSKU NVARCHAR( 20)
         DECLARE @cLOT NVARCHAR( 10)
         DECLARE @cLOC NVARCHAR( 10)
         DECLARE @cID  NVARCHAR( 18)
         DECLARE @cUOM NVARCHAR( 10)
         DECLARE @nQTY INT
   
         -- Get UCC info
         SELECT TOP 1 
            @cSKU = SKU, 
            @cLOT = LOT, 
            @cLOC = LOC, 
            @cID = ID, 
            @nQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC 
            AND StorerKey = @cStorerKey
            AND Status = '1'
   
         -- Get UCC assigned PickDetail
         SET @cTaskDetailKey = ''
         SELECT TOP 1 
            @cTaskDetailKey = TaskDetailKey, 
            @cUOM = UOM
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND Status < '9' -- Exclude cancel order that ship out and generate ASN, and re-receive the same UCC
            AND DropID = @cUCC
         IF @cTaskDetailKey = ''
         BEGIN
            SET @nErrNo = 79056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NotOnPKDtl
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
            GOTO Step_1_Fail
         END

         -- Get UCC assigned TaskDetail LOC
         SET @cSuggestedLOC = ''
         SET @cSuggestedID = ''
         SELECT 
            @cSuggestedLOC = CASE WHEN FinalLOC <> '' THEN FinalLOC ELSE ToLOC END, 
            @cSuggestedID  = CASE WHEN FinalLOC <> '' THEN FinalID  ELSE ToID END
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey 
         IF @cSuggestedLOC = ''
         BEGIN
            SET @nErrNo = 79057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoUCCAssignLOC
            GOTO Step_1_Fail
         END
      END

      -- TrolleyNo
      IF @cTrolleyNo <> ''
      BEGIN
         -- Check trolley valid
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo)
         BEGIN
            SET @nErrNo = 79058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad Trolley No
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- TrolleyNo
            GOTO Step_1_Fail
         END

         -- Check trolley closed
         IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo AND Status = '1')
         BEGIN
            SET @nErrNo = 79059
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Trolley closed
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- TrolleyNo
            GOTO Step_1_Fail
         END
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cUCC, @cPutawayZone, @cSuggestedLOC, @cTrolleyNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' + 
               '@cUCC            NVARCHAR( 20), ' +
               '@cPutawayZone    NVARCHAR( 10), ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cTrolleyNo      NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cUCC, @cPutawayZone, @cSuggestedLOC, @cTrolleyNo, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
      
      -- UCC
      IF @cUCC <> ''
      BEGIN
         -- Get LOC info
         SELECT @cPutawayZone = PutawayZone
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cSuggestedLOC
         
         -- Prepare next screen var
         SET @cOutField01 = @cPutawayZone
         SET @cOutField02 = @cSuggestedLOC
         SET @cOutField03 = '' -- TrolleyNo
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      -- TrolleyNo
      IF @cTrolleyNo <> ''
      BEGIN
         -- Get total UCC on Trolley
         SELECT @cTrolleyPos = ISNULL( COUNT( DISTINCT Position), '0')
         FROM rdt.rdtTrolleyLog WITH (NOLOCK)
         WHERE TrolleyNo = @cTrolleyNo
               
         -- Prepare next screen var
         SET @cOutField01 = @cTrolleyPos
         SET @cOutField02 = '' -- Option
   
         -- Go to next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
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
         
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cTrolleyNo = ''
      SET @cOutField01 = '' -- UCC
      SET @cOutField02 = '' -- TrolleyNo
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3401. Trolley screen
   PWAYZONE      (field01)
   SUGGESTED LOC (field02)
   TROLLEY NO    (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cTrolleyNo = @cInField03 --TrolleyNo

      -- Check blank
      IF @cTrolleyNo = ''
      BEGIN
         SET @nErrNo = 79060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need TrolleyNo
         GOTO Step_2_Fail
      END

      -- Check trolley closed
      IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo AND Status = '1')
      BEGIN
         SET @nErrNo = 79061
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Trolley closed
         GOTO Step_2_Fail
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cUCC, @cPutawayZone, @cSuggestedLOC, @cTrolleyNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' + 
               '@cUCC            NVARCHAR( 20), ' +
               '@cPutawayZone    NVARCHAR( 10), ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cTrolleyNo      NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cUCC, @cPutawayZone, @cSuggestedLOC, @cTrolleyNo, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END
      
      -- Get Trolley max position
      SELECT @cTrolleyPos = ISNULL( MAX( Position), '')
      FROM rdt.rdtTrolleyLog WITH (NOLOCK)
      WHERE TrolleyNo = @cTrolleyNo
      
      -- Increase trolley position
      IF @cTrolleyPos = ''
         SET @cTrolleyPos = 'A'
      ELSE
         SET @cTrolleyPos = master.dbo.fnc_GetCharASCII( ASCII( @cTrolleyPos) + 1)

      -- Insert log
      INSERT INTO rdt.rdtTrolleyLog (TrolleyNo, Position, UCCNo, LOC, ID, Status, TaskDetailKey)
      VALUES (@cTrolleyNo, @cTrolleyPos, @cUCC, @cSuggestedLOC, @cSuggestedID, '0', @cTaskDetailKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS Log Fail
         GOTO Step_2_Fail
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cSuggestedLOC, 
         @cUCC          = @cUCC, 
         @cDeviceID     = @cTrolleyNo, 
         @cDevicePosition = @cTrolleyPos, 
         @cTaskDetailKey  = @cTaskDetailKey,
         @nStep         = @nStep

      -- Prep UCC screen var
      SET @cUCC = ''
      SET @cTrolleyNo = ''
      SET @cOutField01 = '' -- UCC
      SET @cOutField02 = '' -- TrolleyNo
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
      
      -- Go to UCC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Reset UCC screen var
      SET @cUCC = ''
      SET @cTrolleyNo = ''
      SET @cOutField01 = '' -- UCC
      SET @cOutField02 = '' -- TrolleyNo

      -- Go to UCC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
      SET @cTrolleyNo = ''
      SET @cOutField03 = '' --TrolleyNo
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3402. Message. Close trolley?
   TROLLEY POS (field01)
   OPTION      (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField02 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 79063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_3_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 79064
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_3_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Update rdtTrolleyLog
         UPDATE rdt.rdtTrolleyLog SET 
            Status = '1' 
         WHERE TrolleyNo = @cTrolleyNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79064
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail
            GOTO Step_3_Fail
         END

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cDeviceID     = @cTrolleyNo, 
            @cRefNo4       = 'CLOSE',
            @nStep         = @nStep
      END
   END

   -- Go to UCC screen
   SET @cUCC = ''
   SET @cTrolleyNo = ''
   SET @cOutField01 = '' -- UCC
   SET @cOutField02 = '' -- TrolleyNo
   EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC

   -- Go to prev screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2

   GOTO Quit

   Step_3_Fail:
      SET @cOption = ''
      SET @cOutField02 = '' --Option
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
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_UCC     = @cUCC, 
      V_LOC     = @cSuggestedLOC,
      V_ID      = @cSuggestedID,
      V_Zone    = @cPutawayZone,
      V_TaskDetailKey = @cTaskDetailKey, 

      V_String1 = @cTrolleyNo,
      V_String2 = @cExtendedValidateSP,

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

      FieldAttr01  = @cFieldAttr01,
      FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,
      FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05

   WHERE Mobile = @nMobile
END

GO