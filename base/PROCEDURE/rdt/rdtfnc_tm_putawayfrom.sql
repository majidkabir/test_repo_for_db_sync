SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdtfnc_TM_PutawayFrom                                      */
/* Copyright      : IDS                                                        */
/*                                                                             */
/* Purpose: RDT Task Manager - Move                                            */
/*          Called By rdtfnc_TaskManager                                       */
/*                                                                             */
/* Modifications log:                                                          */
/*                                                                             */
/* Date        Rev   Author   Purposes                                         */
/* 30-01-2013  1.0   Ung      SOS256104. Created                               */
/* 24-07-2015  1.1   Ung      SOS346285 Fix reason code screen flow            */
/* 30-09-2016  1.2   Ung       Performance tuning                              */   
/* 27-09-2017  1.3   TLTING   Performance tuning - NOLOCK                      */
/* 13-09-2019  1.4   James    WMS-10397 Add cannot overwrite in transit loc    */
/*                            Enhance overwrite loc logic (james01)            */
/* 12-03-2019  1.5   James    WMS-11350 Add output areakey nsptmtm01 (james02) */
/* 18-12-2019  1.6   James    WMS-11394 Skip reason code screen if RDT config  */
/*                            turn on                                          */
/*                            Add ExtendedInfo @ screen 3 (james03)            */
/* 17-02-2020  1.7   Chermaine WMS-12080 Add sku & Desc display in step3 (cc01)*/
/*******************************************************************************/
CREATE  PROC [RDT].[rdtfnc_TM_PutawayFrom](
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
   @b_success           INT, 
   @c_outstring         NVARCHAR(255), 
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000), 
   @cFromLoc            NVARCHAR(10)

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),
   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cTaskdetailKey      NVARCHAR(10),
   @cAreaKey            NVARCHAR(10),
   @cTTMStrategyKey     NVARCHAR(10),
   @cTTMTaskType        NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),

   @cSuggFromLoc        NVARCHAR(10),
   @cSuggToLoc          NVARCHAR(10),
   @cSuggID             NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSKUDescr           NVARCHAR(60),
   @nQTY                INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cSwapTask           NVARCHAR( 1), 
   @cOverwriteToLOC     NVARCHAR( 20), 
   @cDefaultFromLOC     NVARCHAR( 20), 
   @cToLoc              NVARCHAR( 10),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @tExtInfo            VariableTable, 
   @cDIsplaySKU         NVARCHAR( 1),  -- (cc01)
   @cExtendedScreenSP   NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @cLocNeedCheck       NVARCHAR( 20),
   @cReloadToLoc        NVARCHAR( 1),  --NLT013

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

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cTaskdetailKey   = V_TaskDetailKey,
   @cSuggFromLoc     = V_LOC,
   @cSuggID          = V_ID,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr, 
   @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   
   @cSuggToloc          = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cExtendedUpdateSP   = V_String4,
   @cSwapTask           = V_String5, 
   @cOverwriteToLOC     = V_String6, 
   @cDefaultFromLOC     = V_String7, 
   @cToLoc              = V_String8,
   @cDisplaySKU         = V_String9,   -- (cc01)

   @cAreakey            = V_String32,
   @cTTMStrategyKey     = V_String33,
   @cTTMTaskType        = V_String34,
   @cRefKey01           = V_String35,
   @cRefKey02           = V_String36,
   @cRefKey03           = V_String37,
   @cRefKey04           = V_String38,
   @cRefKey05           = V_String39,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile
   
-- Redirect to respective screen
IF @nFunc = 1797
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Initialize
   IF @nStep = 1 GOTO Step_1   -- Scn = 3440. FromLOC      
   IF @nStep = 2 GOTO Step_2   -- Scn = 3441. ID      
   IF @nStep = 3 GOTO Step_3   -- Scn = 3442. ToLOC    
   IF @nStep = 4 GOTO Step_4   -- Scn = 3443. Sucess Msg
   IF @nStep = 5 GOTO Step_5   -- Scn = 2109. Reason Code  
END      
RETURN -- Do nothing if incorrect step      


/********************************************************************************
Step 0. Called from Task Manager Main Screen (func = 1796)

********************************************************************************/
Step_0:
BEGIN
   -- Get task manager data
   SET @cTaskdetailKey  = @cOutField06
   SET @cAreaKey        = @cOutField07
   SET @cTTMStrategyKey = @cOutField08
   
   -- Get storer config
   SET @cSwapTask = rdt.rdtGetConfig( @nFunc, 'SwapTask', @cStorerKey)
   SET @cDefaultFromLOC = rdt.rdtGetConfig( @nFunc, 'DefaultFromLOC', @cStorerKey)
   IF @cDefaultFromLOC = '0'
      SET @cDefaultFromLOC = ''
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)
   IF @cOverwriteToLOC = '0'
      SET @cOverwriteToLOC = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   -- (james03)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- (cc01)
   SET @cDisplaySKU = rdt.rdtGetConfig( @nFunc, 'DisplaySKU', @cStorerKey)


   -- Get task info
   SELECT 
      @cTTMTaskType = TaskType, 
      @cStorerKey   = Storerkey,
      @cSuggFromLoc = FromLOC, 
      @cSuggID      = FromID,
      @cSuggToLOC   = ToLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey

   -- Default FromLOC
   SET @cFromLOC = ''
   IF @cDefaultFromLOC <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cDefaultFromLOC AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDefaultFromLOC) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +  
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo = 0
            SET @cFromLOC = @cSuggFromLoc
         ELSE 
            SET @nErrNo = 0
      END
   END   

   -- Swap ID
   IF @cSwapTask = '1'
      SET @cSuggID = ''

   -- Enable all fields
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

   -- Prepare next screen
   SET @cOutField01 = @cSuggFromLoc
   SET @cOutField02 = @cFromLOC

   -- Sign-in
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign in function
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @cLocation       = @cSuggFromLoc,
      @cToLocation    =  @cSuggToLoc,
      @cID             = @cSuggID,
      @cRefNo2         = @cAreaKey,
      @cRefNo3         = @cTTMStrategyKey,
      @cRefNo4         = '',
      @cRefNo5         = '',
      @cTaskdetailKey  = @cTaskdetailKey


   -- Extended update
   IF @cExtendedUpdateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN

         SET @cSQL = 'EXEC [RDT].' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,        ' +
            '@nFunc           INT,        ' +
            '@cLangCode       NVARCHAR( 3),   ' +
            '@nStep           INT,        ' +
            '@cTaskdetailKey  NVARCHAR( 10),  ' +
            '@nErrNo          INT OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
			
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Set the entry point
   SET @nScn  = 3440
   SET @nStep = 1

   GOTO Quit
   
   Step_0_Fail:
   BEGIN
      -- Back to task manager
      SET @nFunc = 1756
      SET @nScn = 2100
      SET @nStep = 1
  END
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3420. FromLOC
    SUGG FROM LOC (Field01)
    FROM LOC      (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField02 -- FromLOC
      SET @cLocNeedCheck = @cInField02

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1797ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1797ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
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
               GOTO Step_1_Fail
            
            SET @cFromLOC = @cLocNeedCheck
         END
      END
      -- Check FromLOC match
      IF @cFromLoc <> @cSuggFromLOC
      BEGIN
         SET @nErrNo = 79351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
         GOTO Step_1_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC [RDT].' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,        ' +
               '@nFunc           INT,        ' +
               '@cLangCode       NVARCHAR( 3),   ' +
               '@nStep           INT,        ' +
               '@cTaskdetailKey  NVARCHAR( 10),  ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare next screen
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = @cSuggID
      SET @cOutField03 = '' --FromID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
/*
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
*/
      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutfield04 = ''
      SET @cOutField05 = ''
      SET @cOutField09 = ''

      -- Go to Reason Code Screen                       
      SET @nFromScn  = @nScn                       
      SET @nFromStep = @nStep                       
      SET @nScn  = 2109      SET @nScn  = 2109                       
      SET @nStep = @nStep + 4 -- Step 5      SET @nStep = @nStep + 4 -- Step 5                     

   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cFromLoc = ''
      SET @cOutField02 = ''
  END
END
GOTO Quit


/********************************************************************************
Step 2. screen = 3421 ID Screen
   FROM LOC (Field01)
   SUGG ID  (Field02)
   ID       (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cFromID NVARCHAR(18)

      -- Screen mapping
      SET @cFromID = @cInField03

      -- Check blank
      IF @cFromID = ''
      BEGIN
         SET @nErrNo = 79360
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
         GOTO Step_2_Fail
      END

      -- Check FromID match
      IF @cFromID <> @cSuggID
      BEGIN
         IF @cSwapTask <> '1'
         BEGIN
            SET @nErrNo = 79352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not match
            GOTO Step_2_Fail
         END

         -- Swap task
         DECLARE @cNewTaskDetailKey NVARCHAR( 10)
         EXEC rdt.rdt_TM_PutawayFrom_SwapTask @nMobile, @nFunc, @cLangCode, @cUserName
            ,@cTaskDetailKey
            ,@cFromID
            ,@cNewTaskDetailKey OUTPUT
            ,@nErrNo            OUTPUT
            ,@cErrMsg           OUTPUT
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Quit
         END
      
         -- Reload task
         SET @cTaskDetailKey = @cNewTaskDetailKey
         SELECT 
            @cStorerKey   = Storerkey,
            @cSuggFromLoc = FromLOC, 
            @cSuggID      = FromID,
            @cSuggToLOC   = ToLOC
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailKey
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC [RDT].' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,        ' +
               '@nFunc           INT,        ' +
               '@cLangCode       NVARCHAR( 3),   ' +
               '@nStep           INT,        ' +
               '@cTaskdetailKey  NVARCHAR( 10),  ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @tExtInfo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,        ' +
               '@nFunc           INT,        ' +
               '@cLangCode       NVARCHAR( 3),   ' +
               '@nStep           INT,        ' +
               '@nInputKey       INT,        ' + 
               '@cTaskdetailKey  NVARCHAR( 10),  ' +
               '@tExtInfo        VariableTable READONLY, ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' + 
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @tExtInfo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
      
      IF @cDIsplaySKU = '1'
      BEGIN
      	IF (SELECT COUNT(DISTINCT Sku) FROM lotxlocxid WITH (NOLOCK) WHERE Loc =@cSuggFromLoc AND Id = @cFromID) >1
      	BEGIN
      		SET @cOutField04 = 'Multi SKUs'
      	   SET @cOutField05 = ''
      	   SET @cOutField06 = ''
      	END 
      	ELSE
         BEGIN
         	SELECT @cSKU = Sku FROM dbo.lotxlocxid WITH (NOLOCK) WHERE Loc =@cSuggFromLoc AND Id = @cFromID
         	SELECT @cSKUDescr = DESCR FROM dbo.SKU WITH (NOLOCK) WHERE storerKey = @cStorerKey AND Sku = @cSKU
         	
         	SET @cOutField04 = @cSKU
      	   SET @cOutField05 = LEFT (@cSKUDescr, 20)
      	   SET @cOutField06 = SUBSTRING(@cSKUDescr, 21, 20)
         END
      END


	  --NLT013
      SET @cReloadToLoc = rdt.rdtGetConfig( @nFunc, 'ReloadToLoc', @cStorerKey)
      IF @cReloadToLoc = '0'
         SET @cReloadToLoc = ''
	  IF @cReloadToLoc = '1'
      BEGIN
         SELECT
            @cSuggToLOC = ToLOC
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailKey

      END
      
      -- Prepare next screen var
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cSuggToLOC
      SET @cOutField03 = '' -- ToLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = '' -- FromLOC

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromID = ''
      SET @cOutField03 = ''  -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 3. screen = 3423 TO LOC screen
   ID          (Field01)
   SUGG TO LOC (Field02)
   TO LOC      (Field03, Input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03 -- ToLOC

      -- Check blank
      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 79361
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToLOC
         GOTO Step_3_Fail            
      END
      
      SET @cLocNeedCheck = @cInField03

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1797ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1797ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
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
               GOTO Step_3_Fail
            
            SET @cToLoc = @cLocNeedCheck
         END
      END
      -- Check different ToLOC
      IF @cToLoc <> @cSuggToLoc
      BEGIN
         -- Not allow overwrite
         IF @cOverwriteToLOC = ''
         BEGIN
            SET @nErrNo = 79353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
            GOTO Step_3_Fail            
         END
         
         -- (james01)
         -- Override suggest LOC should not allow, if suggest LOC is transit LOC (TaskDetail.TransitLOC)
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                     WHERE TaskDetailKey = @cTaskdetailKey 
                     AND TransitLOC = @cToLOC)
         BEGIN
            SET @nErrNo = 79362
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InTransit Loc
            GOTO Step_3_Fail            
         END

         -- Extended validate ToLOC
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cOverwriteToLOC AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cOverwriteToLOC) +
               ' @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cSuggToLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@cTaskdetailKey NVARCHAR( 10), ' +
               '@cSuggToLOC     NVARCHAR( 10), ' +
               '@cToLOC         NVARCHAR( 10), ' +
               '@nErrNo         INT OUTPUT,    ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cSuggToLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo NOT IN (0, -1)
               GOTO Step_3_Fail
         END
         ELSE
         BEGIN
            IF @cOverwriteToLOC = '1'
               SET @nErrNo = -1
         END
            
         -- Either set rdt config svalue = 1 or sp return errno = -1 then skip reason code screen
         IF @nErrNo <> -1 
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutfield04 = ''
            SET @cOutField05 = ''
            SET @cOutField09 = ''
   
            -- Go to Reason Code Screen                       
            SET @nFromScn  = @nScn                       
            SET @nFromStep = @nStep                       
            SET @nScn  = 2109                   
            SET @nStep = @nStep + 2
         
            GOTO Quit
         END
         ELSE
            SET @nErrNo = 0
      END

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_TM_PutawayFrom -- For rollback or commit only our own transaction

      IF @cToLoc <> @cSuggToLoc
      BEGIN
         UPDATE dbo.TaskDetail SET
            ToLoc = @cToLoc
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79364
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverWrite Fail
            ROLLBACK TRAN rdt_TM_PutawayFrom -- Only rollback change made here
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
      END
            
      -- Confirm task
      EXEC rdt.rdt_TM_PutawayFrom_Confirm @nMobile, @nFunc, @cLangCode, @cUserName
         ,@cTaskDetailKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdt_TM_PutawayFrom -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC [RDT].' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,        ' +
               '@nFunc           INT,        ' +
               '@cLangCode       NVARCHAR( 3),   ' +
               '@nStep           INT,        ' +
               '@cTaskdetailKey  NVARCHAR( 10),  ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdt_TM_PutawayFrom -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
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
         @cLocation     = @cSuggFromLoc,
         @cToLocation   = @cToLOC,
         @cID           = @cSuggID

      -- Go to message screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to previous screen
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = @cSuggID
      SET @cOutField03 = '' --FromID
      
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField07 = '' -- ToLOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 3424. Message screen
   SUCCESSFUL PUTAWAY
   ENTER = Next Task
   ESC   = Exit TM
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cNextTaskDetailKey NVARCHAR(10)
      DECLARE @cNextTaskType NVARCHAR(10)

      SET @cNextTaskDetailKey = ''
      SET @cNextTaskType = ''

      -- Get next task
      EXEC dbo.nspTMTM01
          @c_sendDelimiter = null
         ,@c_ptcid         = 'RDT'
         ,@c_userid        = @cUserName
         ,@c_taskId        = 'RDT'
         ,@c_databasename  = NULL
         ,@c_appflag       = NULL
         ,@c_recordType    = NULL
         ,@c_server        = NULL
         ,@c_ttm           = NULL
         ,@c_areakey01     = @cAreaKey    OUTPUT   --(james02)
         ,@c_areakey02     = ''
         ,@c_areakey03  = ''
         ,@c_areakey04     = ''
         ,@c_areakey05     = ''
         ,@c_lastloc       = @cSuggToLOC
         ,@c_lasttasktype  = @cTTMTaskType
         ,@c_outstring     = @c_outstring    OUTPUT
         ,@b_Success       = @b_Success      OUTPUT
         ,@n_err           = @nErrNo         OUTPUT
         ,@c_errmsg        = @cErrMsg        OUTPUT
         ,@c_TaskDetailKey = @cNextTaskDetailKey OUTPUT
         ,@c_ttmtasktype   = @cNextTaskType  OUTPUT
         ,@c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,@c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,@c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,@c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,@c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,@n_Mobile        = @nMobile     -- (james02)
         ,@n_Func          = @nFunc       -- (james02)
         ,@c_StorerKey     = @cStorerKey  -- (james02)

      IF @b_Success = 0 OR @nErrNo <> 0
         GOTO Step_4_Fail

      -- No task
      IF @cNextTaskDetailKey = ''
      BEGIN
         -- Logging
         EXEC RDT.rdt_STD_EventLog
             @cActionType = '9', -- Sign out function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerKey  = @cStorerKey

         -- Go back to Task Manager Main Screen
         SET @cErrMsg = 'No More Task'
         --SET @cAreaKey = ''
         SET @cOutField01 = @cAreaKey  -- Area
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''

         SET @nFunc = 1756
         SET @nScn = 2100
         SET @nStep = 1
         GOTO QUIT
      END

      -- Have next task
      IF @cNextTaskDetailKey <> ''
      BEGIN
         SET @cTaskdetailKey = @cNextTaskDetailKey
         SET @cTTMTaskType = @cNextTaskType
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailKey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategyKey
         SET @cOutField09 = ''
         SET @nFromStep = '0'
      END

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
         SET @nErrNo = 79354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Step_4_Fail
      END

      -- Check if screen setup
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn
      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 79355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_4_Fail
      END

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      SET @nFunc = @nToFunc
      SET @nScn  = @nToScn
      SET @nStep = @nToStep

      IF @cTTMTaskType IN ('PAF', 'PA1')
         GOTO Step_0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Go back to Task Manager Main Screen
      SET @nFunc = 1756
      SET @nScn = 2100
      SET @nStep = 1

      SET @cAreaKey = ''
      SET @cOutField01 = ''  -- Area
   END
   GOTO Quit

   Step_4_Fail:
END
GOTO Quit


/********************************************************************************
Step 5. screen = 2109
     REASON CODE  (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cReasonCode NVARCHAR(10)
      DECLARE @nShortQTY INT

      -- Screen mapping
      SET @cReasonCode = @cInField01
      
      -- Check blank reason
      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 79356
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason needed
        GOTO Step_5_Fail
      END

      -- Update ReasonCode
      EXEC dbo.nspRFRSN01
          @c_sendDelimiter = NULL
         ,@c_ptcid         = 'RDT'
         ,@c_userid        = @cUserName
         ,@c_taskId        = 'RDT'
         ,@c_databasename  = NULL
         ,@c_appflag       = NULL
         ,@c_recordType    = NULL
         ,@c_server        = NULL
         ,@c_ttm           = NULL
         ,@c_TaskDetailKey = @cTaskdetailKey
         ,@c_fromloc       = @cSuggFromLOC
         ,@c_fromid        = @cSuggID
         ,@c_toloc         = @cSuggToloc
         ,@c_toid          = @cSuggID
         ,@n_qty           = @nQTY
         ,@c_PackKey       = ''
         ,@c_uom           = ''
         ,@c_reasoncode    = @cReasonCode
         ,@c_outstring     = @c_outstring    OUTPUT
         ,@b_Success       = @b_Success      OUTPUT
         ,@n_err           = @nErrNo         OUTPUT
         ,@c_errmsg        = @cErrMsg        OUTPUT
         ,@c_userposition  = '1' -- 1=at from LOC
      IF @b_Success = 0 OR @nErrNo <> 0
         GOTO Step_5_Fail

      -- Get task reason info
      DECLARE @cContinueProcess         NVARCHAR(10)
      DECLARE @cRemoveTaskFromUserQueue NVARCHAR(10)
      DECLARE @cTaskStatus              NVARCHAR(10)
      SELECT 
         @cContinueProcess = ContinueProcessing,
         @cRemoveTaskFromUserQueue = RemoveTaskFromUserQueue, 
         @cTaskStatus = TaskStatus
      FROM dbo.TaskManagerReason WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode

      IF @cRemoveTaskFromUserQueue = '1'
      BEGIN
         INSERT INTO TaskManagerSkipTasks (UserID, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID)
         SELECT UserKey, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailKey  
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79357
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSkipTskFail
            GOTO Step_5_Fail
         END
      END

      -- Get task info
      DECLARE @cTaskType NVARCHAR(10)
      SELECT @cTaskType = TaskType FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

      -- Update TaskDetail.Status
      IF @cTaskStatus <> ''
      BEGIN
         -- Skip task
         IF @cTaskStatus = '0'
         BEGIN
            -- Release current task
            IF @cTaskType = 'PAF'
            BEGIN
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                   UserKey = ''
                  ,ReasonKey = ''
                  ,Status = '0'
                  ,ToLOC = ''
                  ,ToID = ''
                  ,ListKey = ''
                  ,TransitLOC = ''
                  ,FinalLOC = ''
                  ,FinalID = ''
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey

               -- Unlock SuggestedLOC
               IF @cSuggID <> ''
               BEGIN
                  EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                     ,'' --@cSuggFromLOC
                     ,@cSuggID 
                     ,'' --@cSuggToLOC
                     ,@cStorerKey
                     ,@nErrNo  OUTPUT
                     ,@cErrMsg OUTPUT
                  IF @nErrNo <> 0
                     GOTO Step_5_Fail
               END
            END
            ELSE
               UPDATE dbo.TaskDetail SET
                   UserKey = ''
                  ,ReasonKey = ''
                  ,Status = '0'
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79358
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdSkipTskFail
               GOTO Step_5_Fail
            END
         END
         
         -- Cancel task
         IF @cTaskStatus = 'X'
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                Status = 'X'
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_SNAME()
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79359
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdSkipTskFail
               GOTO Step_5_Fail
            END

            -- Unlock SuggestedLOC
            IF @cSuggID <> ''
            BEGIN
               EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                  ,'' --@cSuggFromLOC
                  ,@cSuggID 
                  ,'' --@cSuggToLOC
                  ,@cStorerKey
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Step_5_Fail
            END
         END
      END

      -- Continue process current task 
      IF @cContinueProcess = '1'
      BEGIN
         -- Back to FromLOC screen
         IF @nFromStep = 1
         BEGIN
            SET @cFromLOC = ''
            SET @cOutField01 = @cSuggFromLOC
            SET @cOutField02 = '' -- FromLOC
         END

         -- Back to ToLOC screen
         IF @nFromStep = 3
         BEGIN
            SET @cOutField01 = @cSuggID
            SET @cOutField02 = @cSuggToLOC
            SET @cOutField03 = '' -- ToLOC
         END

         SET @nScn = @nFromScn
         SET @nStep = @nFromStep
      END
      ELSE
      BEGIN 
         -- Setup RDT storer config ContProcNotUpdTaskStatus, to avoid nspRFRSN01 set TaskDetail.Status = '9', when ContinueProcess <> 1
         -- Go to next task screen
         IF @nFromStep = 1
         BEGIN
            SET @nScn = @nFromScn + 3
            SET @nStep = @nFromStep + 3
         END
         
         IF @nFromStep = 3
         BEGIN
            -- Handling transaction
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_TM_PutawayFrom -- For rollback or commit only our own transaction

            UPDATE dbo.TaskDetail SET
               ToLoc = @cToLoc
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79363
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverWrite Fail
               GOTO Step_5_Fail
            END

            -- Confirm task
            EXEC rdt.rdt_TM_PutawayFrom_Confirm @nMobile, @nFunc, @cLangCode, @cUserName
               ,@cTaskDetailKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdt_TM_PutawayFrom -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC [RDT].' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,        ' +
                     '@nFunc           INT,        ' +
                     '@cLangCode       NVARCHAR( 3),   ' +
                     '@nStep           INT,        ' +
                     '@cTaskdetailKey  NVARCHAR( 10),  ' +
                     '@nErrNo          INT OUTPUT, ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'
   
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN rdt_TM_PutawayFrom -- Only rollback change made here
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                        COMMIT TRAN
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
               @cLocation     = @cSuggFromLoc,
               @cToLocation   = @cToLOC,
               @cID           = @cSuggID

            SET @nScn = @nFromScn + 1
            SET @nStep = @nFromStep + 1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to FromLOC screen
      IF @nFromStep = 1
      BEGIN
         SET @cFromLOC = ''
         SET @cOutField01 = @cSuggFromLOC
         SET @cOutField02 = '' -- FromLOC
      END
      
      -- Go to ToLOC screen
      IF @nFromStep = 3
      BEGIN
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = @cSuggToLOC
         SET @cOutField03 = '' -- ToLOC
      END
      
      -- Back to prev screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cReasonCode = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_TaskDetailKey = @cTaskdetailKey,
      V_LOC         = @cSuggFromloc,
      V_ID          = @cSuggID,
      V_SKU         = @cSKU,
      V_SKUDescr    = @cSKUDescr, 
      V_QTY         = @nQTY,

      V_FromStep    = @nFromStep,
      V_FromScn     = @nFromScn,
   
      V_String1      = @cSuggToloc,
      V_String2      = @cExtendedValidateSP,
      V_String3      = @cExtendedInfoSP,
      V_String4      = @cExtendedUpdateSP,
      V_String5      = @cSwapTask,
      V_String6      = @cOverwriteToLOC, 
      V_String7      = @cDefaultFromLOC, 
      V_String8      = @cToLoc,
      V_String9      = @cDisplaySKU,
      
      V_String32     = @cAreakey,
      V_String33     = @cTTMStrategyKey,
      V_String34     = @cTTMTaskType,
      V_String35     = @cRefKey01,
      V_String36     = @cRefKey02,
      V_String37     = @cRefKey03,
      V_String38     = @cRefKey04,
      V_String39     = @cRefKey05,

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
   IF (@nFunc <> 1797 AND @nStep = 0) AND -- Other module that begin with step 0
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