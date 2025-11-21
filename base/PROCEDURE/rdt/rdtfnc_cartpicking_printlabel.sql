SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_CartPicking_PrintLabel                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pr eCartonize Print Label                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-04-03   1.0  James    WMS12367. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CartPicking_PrintLabel] (
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

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @nQty                INT,
   @cQTY                NVARCHAR( 10),
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX), 

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @tExtValidVar        VariableTable,
   @tExtUpdateVar       VariableTable,
   @tExtInfoVar         VariableTable,      
   @tPrintLabelVar      VariableTable,


   @cAreaKey            NVARCHAR( 10),
   @cCartID             NVARCHAR( 10),
   @cUserID             NVARCHAR( 20),
   @cTaskType           NVARCHAR( 10),
   @cNoOfTask           NVARCHAR( 2),
   @cDefaultTaskType    NVARCHAR( 10),
   @cDefaultNoOfTask    NVARCHAR( 10),
   @cTaskDetailKey      NVARCHAR( 10),
   @nNoOfLabel          INT,
   
   
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
   @cTaskDetailKey = V_TaskDetailKey,
   
   @cAreaKey         = V_String1,
   @cCartID          = V_String2,
   @cUserID          = V_String3,
   @cTaskType        = V_String4,
   @cNoOfTask        = V_String5,
   @cDefaultTaskType = V_String6,
   @cDefaultNoOfTask = V_String7,
 
   @cExtendedInfoSP        =  V_String23,
   @cExtendedValidateSP    =  V_String24,
   @cExtendedUpdateSP      =  V_String25,

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
   @nStep_Area          INT,  @nScn_Area           INT,
   @nStep_LabelPrinted  INT,  @nScn_LabelPrinted   INT       

SELECT
   @nStep_Area          = 1,    @nScn_Area         = 5740,
   @nStep_LabelPrinted  = 2,   @nScn_LabelPrinted  = 5741
   

IF @nFunc = 646 -- Pre Cartonize Print Label 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0              -- Func = PRE CARTONIZE PRINT LABEL
   IF @nStep = 1 GOTO Step_Area           -- Scn = 5740. AREA, CART ID, USER ID, TASK TYPE, # OF TASK
   IF @nStep = 2 GOTO Step_LabelPrinted   -- Scn = 5741. LABEL PRINTED
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 646. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get receive DefaultToLoc
   SET @cDefaultTaskType = rdt.RDTGetConfig( @nFunc, 'DefaultTaskType', @cStorerKey)
   IF @cDefaultTaskType = '0'
      SET @cDefaultTaskType = ''

   SET @cDefaultNoOfTask = rdt.RDTGetConfig( @nFunc, 'DefaultNoOfTask', @cStorerKey)

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP IN ('0', '')
      SET @cExtendedInfoSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''

   -- Initialize value
   SET @cAreaKey = ''
   SET @cCartID = ''
   SET @cUserID = ''
   SET @cTaskType = ''
   SET @cNoOfTask = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- Area
   SET @cOutField02 = '' -- Cart ID
   SET @cOutField03 = '' -- User ID
   SET @cOutField04 = CASE WHEN ISNULL( @cDefaultTaskType, '') <> '' THEN @cDefaultTaskType ELSE '' END -- Lane
   SET @cOutField05 = CASE WHEN ISNULL( @cDefaultNoOfTask, '0') <> '0' THEN @cDefaultNoOfTask ELSE '' END -- No Of Task
   
   EXEC rdt.rdtSetFocusField @nMobile, 1      
      
   SET @nScn = @nScn_Area
   SET @nStep = @nStep_Area

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
Step 1. Scn = 5740
   AREA        (field01, input)
   CART ID     (field02, input)   
   USER ID     (field03, input)
   TASK TYPE   (field04, input)
   NO OF TASK  (field05, input)
********************************************************************************/
Step_Area:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cAreaKey = @cInField01
      SET @cCartID = @cInField02
      SET @cUserID = @cInField03
      SET @cTaskType = @cInField04
      SET @cNoOfTask = @cInField05
      
      IF ISNULL( @cAreaKey, '') = '' 
      BEGIN
         SET @nErrNo = 150601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Area
         SET @cOutField01 = ''
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 1      
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.AreaDetail (NOLOCK) WHERE AreaKey = @cAreaKey)
      BEGIN
         SET @nErrNo = 150602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Area
         SET @cOutField01 = ''
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 1      
         GOTO Quit
      END
      
      IF ISNULL( @cCartID, '') = '' 
      BEGIN
         SET @nErrNo = 150603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cart ID
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = ''
         SET @cOutField03 = @cUserID
         SET @cOutField04= @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 2      
         GOTO Quit
      END
      
      IF NOT EXISTS ( SELECT 1 FROM DeviceProfile (NOLOCK) 
                      WHERE DeviceType = 'CART' 
                      AND   DeviceID = @cCartID )
      BEGIN
         SET @nErrNo = 150604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Cart ID
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = ''
         SET @cOutField03 = @cUserID
         SET @cOutField04= @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 2      
         GOTO Quit
      END
      
      IF ISNULL( @cUserID, '') = '' 
      BEGIN
         SET @nErrNo = 150605
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need User ID
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = ''
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 3      
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskManagerUserDetail WITH (NOLOCK)
                      WHERE UserKey = @cUserID
                      AND   Permission = '1')
      BEGIN
         SET @nErrNo = 150606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid User
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = ''
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 3      
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskManagerUserDetail WITH (NOLOCK)
                      WHERE UserKey = @cUserID
                      AND   AreaKey = @cAreaKey
                      AND   Permission = '1')
      BEGIN
         SET @nErrNo = 150607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not User Area
         SET @cOutField01 = ''
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 1      
         GOTO Quit
      END
      
      IF ISNULL( @cTaskType, '') = '' 
      BEGIN
         SET @nErrNo = 150608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TaskType
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = ''
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 4      
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskManagerUserDetail WITH (NOLOCK)
                      WHERE UserKey = @cUserID
                      AND   AreaKey = @cAreaKey
                      AND   PermissionType = @cTaskType
                      AND   Permission = '1')
      BEGIN
         SET @nErrNo = 150609
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task No Allow
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = ''
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 4      
         GOTO Quit
      END

      IF rdt.rdtIsValidQTY( @cNoOfTask, 1) = 0
      BEGIN
         SET @nErrNo = 150610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv # Of Task
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5      
         GOTO Quit
      END

      IF EXISTS (SELECT 1 FROM dbo.DeviceProfile (NOLOCK) 
                 WHERE StorerKey = @cStorerKey 
                 AND   DeviceID = @cCartID 
                 GROUP BY DeviceID 
                 HAVING COUNT( DISTINCT DevicePosition) < CAST( @cNoOfTask AS INT))
      BEGIN
         SET @nErrNo = 150611
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Capacity
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cCartID
         SET @cOutField03 = @cUserID
         SET @cOutField04 = @cTaskType
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5      
         GOTO Quit
      END

      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail (NOLOCK) 
                  WHERE Storerkey = @cStorerKey 
                  AND   UserKeyOverRide <> ''
                  AND   [Status] < '9'
                  AND   DeviceID = @cCartID )
      BEGIN
         SET @nErrNo = 150612
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart In Use
         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = ''
         SET @cOutField03 = @cUserID
         SET @cOutField04= @cTaskType
         SET @cOutField05 = @cNoOfTask
         EXEC rdt.rdtSetFocusField @nMobile, 2      
         GOTO Quit
      END

      -- Print label
      SET @nErrNo = 0
      EXEC rdt.rdt_CartPicking_PrintLabel
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,
         @nStep            = @nStep,
         @nInputKey        = @nInputKey,
         @cStorerKey       = @cStorerKey,
         @cFacility        = @cFacility,    
         @cAreaKey         = @cAreaKey,
         @cCartID          = @cCartID,    
         @cUserID          = @cUserID,    
         @cTaskType        = @cTaskType,
         @cNoOfTask        = @cNoOfTask,    
         @tPrintLabelVar   = @tPrintLabelVar,
         @nNoOfLabel       = @nNoOfLabel  OUTPUT,
         @nErrNo           = @nErrNo      OUTPUT,    
         @cErrMsg          = @cErrMsg     OUTPUT  

      IF @nErrNo <> 0
         GOTO Quit
         
      -- Prep next screen var
      SET @cOutField01 = @nNoOfLabel

      -- Goto UCC screen
      SET @nScn  = @nScn_LabelPrinted
      SET @nStep = @nStep_LabelPrinted
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
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5741. 
   ASN         (field01)
   LANE        (field02)
   UCC         (field03, input)
********************************************************************************/
Step_LabelPrinted:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cAreaKey = ''
      SET @cCartID = ''
      SET @cUserID = ''
      SET @cTaskType = ''
      SET @cNoOfTask = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Area
      SET @cOutField02 = '' -- Cart ID
      SET @cOutField03 = '' -- User ID
      SET @cOutField04 = CASE WHEN ISNULL( @cDefaultTaskType, '') <> '' THEN @cDefaultTaskType ELSE '' END -- Lane
      SET @cOutField05 = CASE WHEN ISNULL( @cDefaultNoOfTask, '0') <> '0' THEN @cDefaultNoOfTask ELSE '' END -- No Of Task
   
      EXEC rdt.rdtSetFocusField @nMobile, 1      
      
      SET @nScn = @nScn_Area
      SET @nStep = @nStep_Area
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Initialize value
      SET @cAreaKey = ''
      SET @cCartID = ''
      SET @cUserID = ''
      SET @cTaskType = ''
      SET @cNoOfTask = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- Area
      SET @cOutField02 = '' -- Cart ID
      SET @cOutField03 = '' -- User ID
      SET @cOutField04 = CASE WHEN ISNULL( @cDefaultTaskType, '') <> '' THEN @cDefaultTaskType ELSE '' END -- Lane
      SET @cOutField05 = CASE WHEN ISNULL( @cDefaultNoOfTask, '0') <> '0' THEN @cDefaultNoOfTask ELSE '' END -- No Of Task
   
      EXEC rdt.rdtSetFocusField @nMobile, 1      
      
      SET @nScn = @nScn_Area
      SET @nStep = @nStep_Area
   END
   GOTO Quit
END
GOTO Quit



/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      UserName  = @cUserName,
      V_TaskDetailKey = @cTaskDetailKey,
   
      V_String1   = @cAreaKey,
      V_String2   = @cCartID,
      V_String3   = @cUserID,
      V_String4   = @cTaskType, 
      V_String5   = @cNoOfTask,
      V_String6   = @cDefaultTaskType,
      V_String7   = @cDefaultNoOfTask,
   
   
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cExtendedValidateSP,
      V_String25 = @cExtendedUpdateSP,

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