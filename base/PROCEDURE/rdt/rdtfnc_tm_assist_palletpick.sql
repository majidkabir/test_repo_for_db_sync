SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_PalletPick                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Assisted pick pallet                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2017-11-15 1.0  Ung      WMS-3272 Created                            */
/* 2022-08-24 1.1  LZG      JSM-90772 - Reset variable (ZG01)           */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_Assist_PalletPick] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @bSuccess            INT,
   @cAreaKey            NVARCHAR( 10),
   @cTTMStrategykey     NVARCHAR( 10),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cFinalLOC           NVARCHAR( 10)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cFromID             NVARCHAR( 20),
   @cFromLOC            NVARCHAR( 10),
   @cTaskDetailKey      NVARCHAR( 10),

   @cTTMTaskType        NVARCHAR( 10),
   @cSuggToLOC          NVARCHAR( 10),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cOverwriteToLOC     NVARCHAR( 1),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDefaultToLoc       NVARCHAR( 20),

   @cTaskDetailKey1     NVARCHAR( 10),
   @cTaskDetailKey2     NVARCHAR( 10),
   @cTaskDetailKey3     NVARCHAR( 10),
   @cTaskDetailKey4     NVARCHAR( 10),
   @cMaximumPallet      NVARCHAR( 1),
   @cPalletCount        NVARCHAR( 1),

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
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cStorerKey       = V_StorerKey,
   @cFromID          = V_ID,
   @cFromLOC         = V_LOC,
   @cTaskDetailKey   = V_TaskDetailKey,

   @cAreakey            = V_String1,
   @cTTMStrategykey     = V_String2,
   @cTTMTaskType        = V_String3,
   @cSuggToLOC          = V_String4,
   @cExtendedValidateSP = V_String5,
   @cExtendedUpdateSP   = V_String6,
   @cOverwriteToLOC     = V_String7,
   @cExtendedInfoSP     = V_String8,
   @cExtendedInfo       = V_String9,
   @cDefaultToLoc       = V_String10,
   @cMaximumPallet      = V_String11,

   @cTaskDetailKey1     = V_String20,
   @cTaskDetailKey2     = V_String21,
   @cTaskDetailKey3     = V_String22,
   @cTaskDetailKey4     = V_String23,
   @cMaximumPallet      = V_String24,
   @cPalletCount        = V_String25,

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
IF @nFunc = 1830
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1830
   IF @nStep = 1 GOTO Step_1   -- Scn = 5060. Final LOC (1 pallet)
   IF @nStep = 2 GOTO Step_2   -- Scn = 5061. From ID   (multi pallet)
   IF @nStep = 3 GOTO Step_3   -- Scn = 5062. Final LOC (multi pallet)
   IF @nStep = 4 GOTO Step_4   -- Scn = 5063. Message. Next task type
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Initialize
********************************************************************************/
Step_0:
BEGIN
   -- Get task manager data
   SET @cTaskDetailKey  = @cOutField06
   SET @cAreaKey        = @cOutField07
   SET @cTTMStrategyKey = @cOutField08

   -- Get task info
   SELECT
      @cTTMTaskType = TaskType,
      @cStorerKey   = Storerkey,
      @cFromID      = FromID,
      @cFromLOC     = FromLOC,
      @cSuggToLOC   = ToLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get storer configure
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)

   SET @cDefaultToLoc = rdt.rdtGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- Get equipment info
   DECLARE @nMaximumPallet INT
   SELECT @nMaximumPallet = E.MaximumPallet
   FROM TaskManagerUser TMU WITH (NOLOCK)
      JOIN EquipmentProfile E WITH (NOLOCK) ON (E.EquipmentProfileKey = TMU.EquipmentProfileKey)
   WHERE TMU.UserKey = @cUserName
   IF @nMaximumPallet = 0
      SET @nMaximumPallet = 1
   IF @nMaximumPallet > 4
      SET @nMaximumPallet = 4
   SET @cMaximumPallet = CAST( @nMaximumPallet AS NVARCHAR(1))

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Set the entry point
   IF @cMaximumPallet = '1'
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSuggToLOC
      SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC

      SET @nScn  = 5060
      SET @nStep = 1
   END
   ELSE
   BEGIN
      SET @cTaskDetailKey1 = @cTaskDetailKey
      SET @cTaskDetailKey2 = ''
      SET @cTaskDetailKey3 = ''
      SET @cTaskDetailKey4 = ''
      SET @cPalletCount = '1'

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = @cPalletCount + '/' + @cMaximumPallet

      SET @nScn  = 5061
      SET @nStep = 2
   END

   -- Extended info
   SET @cOutField15 = ''
   SET @cExtendedInfo = ''
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5060
   ID           (Field01)
   SUGGEST LOC  (Field02)
   FINAL LOC    (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField03

      -- Check blank
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 116801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_1_Fail
      END

      -- Check if FromLOC match
      IF @cFinalLOC <> @cSuggToLOC AND @cSuggToLOC <> ''
      BEGIN
         IF @cOverwriteToLOC = '0'
         BEGIN
            SET @nErrNo = 116802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC
            GOTO Step_1_Fail
         END

         -- Check ToLOC valid
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC)
         BEGIN
            SET @nErrNo = 116803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            GOTO Step_1_Fail
         END
      END
      SET @cOutField03 = @cFinalLOC

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Confirm (move by ID, update task status = 9)
      EXEC rdt.rdt_TM_Assist_PalletPick_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cTaskdetailKey
         ,@cFinalLOC
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Step_1_Fail

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Get next task
      DECLARE @cNextTaskDetailKey NVARCHAR(10)
      SET @cNextTaskDetailKey = ''
      SELECT TOP 1
         @cNextTaskDetailKey = TaskDetailKey,
         @cTTMTasktype = TaskType
      FROM dbo.TaskDetail WITH (NOLOCK)
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)
      WHERE FromID = @cFromID
         AND Status = '0'
      ORDER BY TaskDetailKey

      -- No task
      IF @cNextTaskDetailKey = ''
      BEGIN
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign-out
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey

         -- Go back to assist task manager
         SET @nFunc = 1814
         SET @nScn = 4060
         SET @nStep = 1

         SET @cOutField01 = ''  -- From ID

         GOTO QUIT
      END

      -- Have next task
      IF @cNextTaskDetailKey <> ''
      BEGIN
         SET @cTaskDetailKey = @cNextTaskDetailKey

         -- Prepare next screen var
         SET @cOutField01 = @cTTMTasktype

         -- Go to next task
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
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

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      GOTO QUIT
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFinalLOC = ''
      SET @cOutField03 = '' -- FinalLOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 5061
   ID       (Field01, input)
   ID COUNT (Field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01

      -- Check blank
      IF @cFromID = ''
      BEGIN
         -- Get task
         IF @cPalletCount = '4' SET @cTaskDetailKey = @cTaskDetailKey4 ELSE
         IF @cPalletCount = '3' SET @cTaskDetailKey = @cTaskDetailKey3 ELSE
         IF @cPalletCount = '2' SET @cTaskDetailKey = @cTaskDetailKey2 ELSE
         IF @cPalletCount = '1' SET @cTaskDetailKey = @cTaskDetailKey1

         -- Get task info
         SELECT
            @cFromID      = FromID,
            @cFromLOC     = FromLOC,
            @cSuggToLOC   = ToLOC
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Prepare next screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cSuggToLOC
         SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC
         SET @cOutField04 = @cPalletCount + '/' + @cMaximumPallet

         -- Go to final LOC (multi pallet)
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Check maximum pallet
      IF @cPalletCount = @cMaximumPallet
      BEGIN
         SET @nErrNo = 116812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverMaxPallet
         GOTO Step_2_Fail
      END

      -- Check ID valid
      IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cFromID)
      BEGIN
         SET @nErrNo = 116804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_2_Fail
      END

      -- Get task
      SET @cTaskDetailKey = ''
      SELECT TOP 1
         @cTaskDetailKey = TaskDetailKey,
         @cTTMTaskType = TaskType,
         @cFromLOC = FromLOC
      FROM dbo.TaskDetail WITH (NOLOCK)
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)
      WHERE FromID = @cFromID
         AND TaskType = @cTTMTaskType
         AND Status = '0'
      ORDER BY TaskDetailKey

      -- No Task
      IF @cTaskDetailKey = ''
      BEGIN
         SET @nErrNo = 116805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task
         GOTO Step_2_Fail
      END

      -- Check pallet ID scanned
      IF @cTaskDetailKey IN (@cTaskDetailKey1, @cTaskDetailKey2, @cTaskDetailKey3, @cTaskDetailKey4)
      BEGIN
         SET @nErrNo = 116811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet scanned
         GOTO Step_2_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      SET @cPalletCount = CAST( @cPalletCount AS INT) + 1

      -- Save task
      IF @cPalletCount = '4' SET @cTaskDetailKey4 = @cTaskDetailKey ELSE
      IF @cPalletCount = '3' SET @cTaskDetailKey3 = @cTaskDetailKey ELSE
      IF @cPalletCount = '2' SET @cTaskDetailKey2 = @cTaskDetailKey ELSE
      IF @cPalletCount = '1' SET @cTaskDetailKey1 = @cTaskDetailKey

      -- Prep current screen var
      SET @cOutField01 = ''
      SET @cOutField02 = @cPalletCount + '/' + @cMaximumPallet
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

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      GOTO QUIT
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = '' -- FromID
   END
END
GOTO Quit



/********************************************************************************
Step 3. Screen = 5062
   ID           (Field01)
   SUGGEST LOC  (Field02)
   FINAL LOC    (Field03, input)
   ID COUNT     (Field04)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField03

      -- Check blank
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 116806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_3_Fail
      END

      -- Check if FromLOC match
      IF @cFinalLOC <> @cSuggToLOC AND @cSuggToLOC <> ''
      BEGIN
         IF @cOverwriteToLOC = '0'
         BEGIN
            SET @nErrNo = 116807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC
            GOTO Step_1_Fail
         END

         -- Check ToLOC valid
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC)
         BEGIN
            SET @nErrNo = 116808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            GOTO Step_3_Fail
         END
      END
      SET @cOutField03 = @cFinalLOC

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Confirm (move by ID, update task status = 9)
      EXEC rdt.rdt_TM_Assist_PalletPick_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cTaskdetailKey
         ,@cFinalLOC
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Step_1_Fail

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Reduce pallet
      SET @cPalletCount = CAST( @cPalletCount AS INT) - 1

      -- Still have pallet
      IF @cPalletCount > '0'
      BEGIN
         -- Get task
         IF @cPalletCount = '4' SET @cTaskDetailKey = @cTaskDetailKey4 ELSE
         IF @cPalletCount = '3' SET @cTaskDetailKey = @cTaskDetailKey3 ELSE
         IF @cPalletCount = '2' SET @cTaskDetailKey = @cTaskDetailKey2 ELSE
         IF @cPalletCount = '1' SET @cTaskDetailKey = @cTaskDetailKey1

         -- Get task info
         SELECT
            @cFromID      = FromID,
            @cFromLOC     = FromLOC,
            @cSuggToLOC   = ToLOC
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Prepare next screen var
         SET @cOutField01 = @cFromID
         SET @cOutField02 = @cSuggToLOC
         SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC
         SET @cOutField04 = @cPalletCount + '/' + @cMaximumPallet

         GOTO Quit
      END

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      SET @cOutField02 = ''             -- ZG01
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''  -- From ID
      SET @cOutField02 = @cPalletCount + '/' + @cMaximumPallet

      -- Go to FromID (multi pallet)
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cFinalLOC = ''
      SET @cOutField03 = '' -- FinalLOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen 5063. Next task
   Next task type (field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @nToFunc INT
      DECLARE @nToScn  INT
      DECLARE @nToStep INT
      SET @nToFunc = 0
      SET @nToScn  = 0
      SET @nToStep = 0

      -- Check if function setup
      SELECT
         @nToFunc = Function_ID,
         @nToStep = Step
      FROM rdt.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = @cTTMTaskType
      IF @nToFunc = 0
      BEGIN
         SET @nErrNo = 116809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr
         GOTO Quit
      END

      -- Check if screen setup
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn
      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 116810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Quit
      END

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      SET @cOutField06 = @cTaskDetailKey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey

      SET @nFunc = @nToFunc
      SET @nScn  = @nToScn
      SET @nStep = @nToStep

      IF @cTTMTaskType IN ('ASTNMV')
         GOTO Step_0
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

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
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

      Facility  = @cFacility,
      -- UserName  = @cUserName,

      V_StorerKey = @cStorerKey,
      V_ID        = @cFromID,
      V_LOC       = @cFromLOC,
      V_TaskDetailKey = @cTaskDetailKey,

      V_String1  = @cAreakey,
      V_String2  = @cTTMStrategykey,
      V_String3  = @cTTMTaskType,
      V_String4  = @cSuggToLOC,
      V_String5  = @cExtendedValidateSP,
      V_String6  = @cExtendedUpdateSP,
      V_String7  = @cOverwriteToLOC,
      V_String8  = @cExtendedInfoSP,
      V_String9  = @cExtendedInfo,
      V_String10 = @cDefaultToLoc,

      V_String20 = @cTaskDetailKey1,
      V_String21 = @cTaskDetailKey2,
      V_String22 = @cTaskDetailKey3,
      V_String23 = @cTaskDetailKey4,
      V_String24 = @cMaximumPallet,
      V_String25 = @cPalletCount,

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

   -- Execute TM module initialization (ung01)
   IF (@nFunc <> 1816 AND @nStep = 0) AND -- Other module that begin with step 0
      (@nFunc <> @nMenu)                  -- Not ESC from screen to menu
   BEGIN
      -- Get the stor proc to execute
      DECLARE @cStoredProcName NVARCHAR( 1024)
      SELECT @cStoredProcName = StoredProcName
      FROM RDT.RDTMsg WITH (NOLOCK)
      WHERE Message_ID = @nFunc

      -- Execute the stor proc
      SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)
      SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @InMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'
      EXEC sp_executesql @cStoredProcName , N'@InMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',
         @nMobile,
         @nErrNo OUTPUT,
         @cErrMsg OUTPUT
   END
END

GO