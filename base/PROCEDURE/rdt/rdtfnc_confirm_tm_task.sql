SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Confirm_TM_Task                                    */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2019-06-20   1.0  James       WMS9480 Created                              */
/* 2022-06-15   1.1  James       WMS-19554 Add eventlog (james01)             */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Confirm_TM_Task] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess   INT,
   @nTranCount INT,
   @cOption    NVARCHAR( 1),
   @cSQL       NVARCHAR( MAX),
   @cSQLParam  NVARCHAR( MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,
   @nTaskUpdated   INT,

   @cStorerGroup   NVARCHAR( 20),
   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cGroupKey           NVARCHAR( 10),    
   @cTaskDetailKey      NVARCHAR( 10),    
   @cOpenTaskStatus     NVARCHAR( 1),    
   @cChkStorerKey       NVARCHAR( 15),    
   @tExtUpdate          VariableTable, 

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
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup,
   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,


   @cGroupKey           = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedUpdateSP   = V_String3,
   @cExtendedInfoSP     = V_String4,
   @cExtendedInfo       = V_String5,
   @cOpenTaskStatus     = V_String6,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_GroupKey   INT,  @nScn_GroupKey    INT,
   @nStep_Message    INT,  @nScn_Message     INT

SELECT
   @nStep_GroupKey   = 1,  @nScn_GroupKey    = 5530,
   @nStep_Message    = 2,  @nScn_Message     = 5531   

IF @nFunc = 1822 -- Confirm TM Task
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 1822
   IF @nStep = 1  GOTO Step_GroupKey   -- Scn = 5530. GroupKey
   IF @nStep = 2  GOTO Step_Message    -- Scn = 5530. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 1822
********************************************************************************/
Step_0:
BEGIN
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Prepare next screen var
   SET @cOutField01 = '' -- GroupKey

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_GroupKey
   SET @nStep = @nStep_GroupKey
END
GOTO Quit


/************************************************************************************
Scn = 5530. GroupKey screen
   GroupKey    (field01, input)
************************************************************************************/
Step_GroupKey:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cGroupKey = @cInField01

      -- Check blank
      IF @cGroupKey = ''
      BEGIN
         SET @nErrNo = 139901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GroupKey req
         GOTO Step_1_Fail
      END

      SELECT TOP 1 @cChkStorerKey = StorerKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE GroupKey = @cGroupKey
      ORDER BY 1 DESC   -- select line with storerkey value first

      IF ISNULL( @cChkStorerKey, '') = ''
      BEGIN
         SET @nErrNo = 139902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Task
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) 
                        WHERE StorerGroup = @cStorerGroup 
                        AND   StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 139903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      -- Get storer configure
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cOpenTaskStatus = rdt.rdtGetConfig( @nFunc, 'OpenTaskStatus', @cStorerKey)

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN Step1_Confirm

      SET @nTaskUpdated = 0
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT TaskDetailKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE GroupKey = @cGroupKey
      AND   StorerKey = @cStorerKey
      AND   Status = @cOpenTaskStatus
      ORDER BY 1
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cTaskDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
            Status = '9'
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Task Fail
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO Step1_RollBackTran
         END

         SET @nTaskUpdated = 1
         FETCH NEXT FROM CUR_UPD INTO @cTaskDetailKey
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      IF @nTaskUpdated = 0
      BEGIN
         SET @nErrNo = 139905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task To Upd
         GOTO Step1_RollBackTran
      END
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
            INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cGroupKey',       @cGroupKey)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tExtUpdate     VariableTable READONLY, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step1_RollBackTran
      END

      GOTO Step1_CommitTran

      Step1_RollBackTran:
         ROLLBACK TRAN Step1_Confirm

      Step1_CommitTran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN Step1_Confirm

      IF @nErrNo <> 0
         GOTO Step_1_Fail

      -- EventLog (james01)
      EXEC RDT.rdt_STD_EventLog  
         @cActionType   = '21', -- Activity Tracking  
         @cUserID       = @cUserName,  
         @nMobileNo     = @nMobile,  
         @nFunctionID   = @nFunc,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cRefNo1       = @cGroupKey,  
         @nStep         = @nStep  
         
      -- Go to Message screen
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
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
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- GroupKey
   END
END
GOTO Quit


/********************************************************************************
Scn = 5530. Message
   Message
********************************************************************************/
Step_Message:
BEGIN
   IF @nInputKey IN ( 1, 0) -- ENTER/ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- GroupKey

      -- Go to PickSlipNo screen
      SET @nScn = @nScn_GroupKey
      SET @nStep = @nStep_GroupKey
   END

   GOTO Quit
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerGroup    = @cStorerGroup,
      StorerKey      = @cStorerKey,
      Facility       = @cFacility,

     
      V_String1      = @cGroupKey,
      V_String2      = @cExtendedValidateSP,
      V_String3      = @cExtendedUpdateSP,
      V_String4      = @cExtendedInfoSP,
      V_String5      = @cExtendedInfo,
      V_String6      = @cOpenTaskStatus,


      I_Field01 = '',  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = '',  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = '',  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = '',  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = '',  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = '',  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = '',  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = '',  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = '',  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = '',  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = '',  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = '',  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = '',  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = '',  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = '',  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO