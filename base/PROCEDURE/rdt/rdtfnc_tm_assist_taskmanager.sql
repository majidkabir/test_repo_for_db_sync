SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_TaskManager                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Assisted Task Manager for ASRS                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-03-04 1.0  Ung      SOS332780 Created                           */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-10-25 1.2  Gan      Performance tuning                          */
/* 2019-08-13 1.3  Ung      WMS-10166 Add case ID                       */
/* 2019-09-27 1.4  James    WMS-10316 Add Taskdetailkey in table        */
/*                          RDT.RDTMOBREC (james01)                     */
/* 2024-03-28 1.3  Shinto   Custom check to ensure pallet weight is     */
/*							captured before doing the putaway			*/
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_Assist_TaskManager] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cStrategyKey     NVARCHAR(10), 
   @cTTMStrategyKey  NVARCHAR(10), 
   @cTTMTaskType     NVARCHAR(10), 
   @cTaskDetailKey   NVARCHAR(10), 
   @cAreaKey         NVARCHAR(10), 
   @nToFunc          INT, 
   @nToStep          INT, 
   @nToScn           INT, 
   @cPutawayZone     NVARCHAR(10), 
   @cFromLOC         NVARCHAR(10), 
   @cFromID          NVARCHAR(18), 
   @cCaseID          NVARCHAR(20) 
      
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

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,
   @cTaskDetailKey   = V_TaskDetailKey,

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
IF @nFunc = 1814
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1814
   IF @nStep = 1 GOTO Step_1   -- Scn = 4060. From ID
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 1814)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 4060
   SET @nStep = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cFromID = ''
   SET @cOutField01 = '' -- FromID
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4060
   FROM ID   (Field01, input)
   CASE ID   (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01
      SET @cCaseID = @cInField02

      -- Check blank
      IF @cFromID = '' AND @cCaseID = ''
      BEGIN
         SET @nErrNo = 51901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID / Case
         GOTO Step_1_Fail
      END
	  /*******Demeter Pallet weight Precheck**********START*/
	  DECLARE @PalletWeightPreCheck     NVARCHAR(10)
	  SELECT @PalletWeightPreCheck = CODELKUP.code2
	  FROM CODELKUP
	  WHERE CODELKUP.LISTNAME = 'Demeter'
	  AND CODELKUP.Code = 'PalletWeightPreCheck'
	  AND CODELKUP.Storerkey = @cStorerkey
	  
	  IF @PalletWeightPreCheck = '1'
	  BEGIN
		IF NOT EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) WHERE PalletKey = @cFromID and pallet.GrossWgt > 0)
		BEGIN
			SET @nErrNo = 75364
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
		END
	  END
	  /*******Demeter Pallet weight Precheck**********END*/
      IF @cFromID = '' AND @cCaseID = ''
      BEGIN
         SET @nErrNo = 51901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID / Case
         GOTO Step_1_Fail
      END
	 
      -- Check both with value
      IF @cFromID <> '' AND @cCaseID <> ''
      BEGIN
         SET @nErrNo = 51907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID / Case
         GOTO Step_1_Fail
      END

      -- From ID
      IF @cFromID <> ''
      BEGIN
         -- Check ID valid
         IF NOT EXISTS ( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cFromID)
         BEGIN
            SET @nErrNo = 51902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
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
            AND Status = '0'
         ORDER BY TaskDetailKey
      END

      -- Case ID
      IF @cCaseID <> ''
      BEGIN
         -- Get task
         SET @cTaskDetailKey = ''
         SELECT TOP 1 
            @cTaskDetailKey = TaskDetailKey,
            @cTTMTaskType = TaskType,
            @cFromLOC = FromLOC
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)
         WHERE CaseID = @cCaseID
            AND Status = '0'
         ORDER BY TaskDetailKey
      END

      -- No Task
      IF @cTaskDetailKey = ''
      BEGIN
         SET @nErrNo = 51903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Task
         GOTO Step_1_Fail
      END
/*
      -- Update task
      UPDATE dbo.TaskDetail SET
         Status = '3',
         UserKey = SUSER_SNAME(),
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(), 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
         AND Status = '0'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 51904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetTask Fail
         GOTO Step_1_Fail
      END
*/
      -- Get function
      SET @nToFunc = 0
      SELECT
         @nToFunc = ISNULL(FUNCTION_ID, 0),
         @nToStep = ISNULL(Step, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = @cTTMTaskType

      -- Check function
      IF @nToFunc = 0
      BEGIN
         SET @nErrNo = 51905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Quit
      END

      -- Get screen
      SET @nToScn = 0
      SELECT TOP 1
         @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      -- Check screen
      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 51906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskScnErr
         GOTO Quit
      END

      SET @cAreaKey = ''
      SET @cStrategyKey = ''
      SET @cTTMStrategyKey = ''

      -- Get AreaKey
      SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
      SELECT @cAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cPutawayZone
      
      -- Get TTMStrategyKey
      SELECT @cStrategyKey = StrategyKey FROM dbo.TaskManagerUser WITH (NOLOCK) WHERE UserKey = @cUserName 
      SELECT @cTTMStrategyKey = TtmstrategyKey FROM dbo.Strategy WITH (NOLOCK) WHERE StrategyKey = @cStrategyKey    

      -- Pass data to sub module
      SET @cOutField06 = @cTaskdetailKey    
      SET @cOutField07 = @cAreaKey    
      SET @cOutField08 = @cTTMStrategyKey    
      
      -- Go to sub module
      SET @nFunc = @nToFunc
      SET @nScn = @nToScn
      SET @nStep = @nToStep      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign-Out
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
      -- UserName  = @cUserName,
      Printer   = @cPrinter,
      V_TaskDetailKey = @cTaskDetailKey,

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
   IF (@nFunc <> 1814 AND @nStep = 0) AND
      (@nFunc <> @nMenu) -- ESC from AREA screen to menu
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