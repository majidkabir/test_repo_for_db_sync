SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_WorkOrder_StartLine                               */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#315942 - WorkOrder Start Line                                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-10-26 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */ 
/* 2018-11-21 1.2  Gan      Performance tuning                               */ 
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_WorkOrder_StartLine](
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
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cWorkStation        NVARCHAR( 50),
   @cJobKey             NVARCHAR( 10),
   @cWorkOrderKey       NVARCHAR( 10),
   @cWorkStationStatus  NVARCHAR( 10),
   @cStatus             NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),
   @cSubReasonCode      NVARCHAR( 10),
   @cNoOfUser           NVARCHAR( 5),
   @dStartDownTime      DATETIME, 
   @dEndDownTime        DATETIME, 
   @nAssignedUser       INT, 
   @cSQL                NVARCHAR( 1000), 
   @cSQLParam           NVARCHAR( 1000), 
   @cStorerGroup        NVARCHAR( 20),
   @cOption             NVARCHAR( 1),
   @cNewStatus          NVARCHAR( 10),
   @cNewNoOfUser        NVARCHAR( 5),
   @cNewReason          NVARCHAR( 10),
   @cNewSubReason       NVARCHAR( 10),
   @nTranCount          INT,
   @cNewStartDownTime   NVARCHAR( 20),
   @cNewEndDownTime     NVARCHAR( 20),
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),


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

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cStorerKey       = V_StorerKey,

   @cWorkStation     = V_String1,
   @cJobKey          = V_String2,
   @cWorkOrderKey    = V_String3,

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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1150
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1150
   IF @nStep = 1 GOTO Step_1   -- Scn = 4360 WorkStation
   IF @nStep = 2 GOTO Step_2   -- Scn = 4361 WorkStation, #ofuser, reason, subreason...
   IF @nStep = 3 GOTO Step_3   -- Scn = 4362 WorkStation, #ofuser, reason, subreason...
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1150)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4360
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cWorkStation = ''
   SET @cJobKey = ''
   SET @cWorkOrderKey = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''

   EXEC rdt.rdtSetFocusField @nMobile, 1

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

/********************************************************************************
Step 1. screen = 4360
   WorkStation    (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWorkStation = @cInField01
      SET @cJobKey = @cInField02
      SET @cWorkOrderKey = @cInField03

      --Check blank
      IF ISNULL( @cWorkStation, '') = ''
      BEGIN
         SET @nErrNo = 58051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrkStation req
         GOTO Step1_Fail
      END

      --Check Exists
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.WorkStation WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation)
      BEGIN
         SET @nErrNo = 58052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WrkStation
         GOTO Step1_Fail
      END

      IF ISNULL( @cJobKey, '') = '' AND ISNULL( @cWorkOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '58053 PLS KEY IN'
         SET @cErrMsg2 = 'EITHER JOB ID'
         SET @cErrMsg3 = 'OR WORKORDER #.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END

         SET @cOutField01 = @cWorkStation
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF ISNULL( @cJobKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey)
         BEGIN
            SET @nErrNo = 58054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Job ID

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE JobKey = @cJobKey
                     GROUP BY JobKey
                     HAVING COUNT( DISTINCT WorkOrderKey) > 1) 
            AND ISNULL( @cWorkOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58055 THE JOB ID'
            SET @cErrMsg2 = 'CONTAIN > 1'
            SET @cErrMsg3 = 'WORKORDER #.'
            SET @cErrMsg4 = 'PLS KEY IN BOTH'
            SET @cErrMsg5 = 'VALUE TO PROCEED.'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         IF ISNULL( @cWorkOrderKey, '') = ''
            SELECT TOP 1 @cWorkOrderKey = WorkOrderKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE JobKey = @cJobKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58056 INVALID'
            SET @cErrMsg2 = 'JOB ID + WORKORDER #'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END
      END

      IF ISNULL( @cWorkOrderKey, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 58057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv WORKORDER#

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = @cJobKey
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                     WHERE WorkStation = @cWorkStation
                     AND   WorkOrderKey = @cWorkOrderKey
                     GROUP BY WorkOrderKey
                     HAVING COUNT( DISTINCT JobKey) > 1) 
            AND ISNULL( @cJobKey, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58058 WORKORDER #'
            SET @cErrMsg2 = 'CONTAIN > 1'
            SET @cErrMsg3 = 'JOB ID.'
            SET @cErrMsg4 = 'PLS KEY IN BOTH'
            SET @cErrMsg5 = 'VALUE TO PROCEED.'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step1_Fail
         END

         IF ISNULL( @cJobKey, '') = ''
            SELECT TOP 1 @cJobKey = JobKey 
            FROM dbo.WorkOrderJob WITH (NOLOCK) 
            WHERE WorkOrderKey = @cWorkOrderKey

         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrderJob WITH (NOLOCK) 
                         WHERE JobKey = @cJobKey
                         AND   WorkOrderKey = @cWorkOrderKey)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '58059 INVALID'
            SET @cErrMsg2 = 'JOB ID + WORKORDER #'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            SET @cOutField01 = @cWorkStation
            SET @cOutField02 = ''
            SET @cOutField03 = @cWorkOrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END

      SELECT @nAssignedUser = NoOfAssignedWorker, 
             @cStatus = [Status], 
             @cReasonCode = ReasonCode, 
             @cSubReasonCode = SubReasonCode, 
             @dStartDownTime = StartDownTime, 
             @dEndDownTime = EndDownTime
      FROM dbo.WorkStation WITH (NOLOCK)
      WHERE WorkStation = @cWorkStation

      SELECT @cWorkStationStatus = Short
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'WSTNSTATUS'
      AND   Code = @cStatus

      --prepare next screen variable
      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @nAssignedUser
      SET @cOutField03 = @cWorkStationStatus
      SET @cOutField04 = @cReasonCode
      SET @cOutField05 = @cSubReasonCode
      SET @cOutField06 = CASE WHEN @cStatus = '1' THEN '' ELSE
                         CONVERT(NVARCHAR, @dStartDownTime, 101) + ' ' + 
		                   CONVERT(NVARCHAR, DATEPART(hh, @dStartDownTime)) + ':' + 
		                   RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, @dStartDownTime)), 2) END
      SET @cOutField07 = CASE WHEN @cStatus = '1' THEN '' ELSE
                         CONVERT(NVARCHAR, @dEndDownTime, 101) + ' ' + 
		                   CONVERT(NVARCHAR, DATEPART(hh, @dEndDownTime)) + ':' + 
		                   RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, @dEndDownTime)), 2) END
      SET @cOutField08 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

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

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
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

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step1_Fail:
   BEGIN
      SET @cWorkstation = ''
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4361)
   WorkStation       (Field01)
   Assigned user     (Field02)
   Status            (Field03)
   Reason            (Field04)
   Sub Reason        (Field05)
   StartDownTime     (Field06)
   EndDownTime       (Field07)
   Option            (Field08, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField08

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 58060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option req'
         GOTO Step_2_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 58061
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_2_Fail
      END

      SELECT @nAssignedUser = NoOfAssignedWorker, 
             @cStatus = [Status], 
             @cReasonCode = ReasonCode, 
             @cSubReasonCode = SubReasonCode, 
             @dStartDownTime = StartDownTime, 
             @dEndDownTime = EndDownTime
      FROM dbo.WorkStation WITH (NOLOCK)
      WHERE WorkStation = @cWorkStation

      SELECT @cWorkStationStatus = Short
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'WSTNSTATUS'
      AND   Code = @cStatus

      IF @cOption = '1' -- Set something to active
      BEGIN
         SET @cOutField01 = @cWorkStation
         SET @cOutField02 = @nAssignedUser
         SET @cOutField03 = 'ACTIVE'
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''

         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = 'O'
         SET @cFieldAttr06 = 'O'
         SET @cFieldAttr07 = 'O'
         SET @cFieldAttr08 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cWorkStation
         SET @cOutField02 = @nAssignedUser
         SET @cOutField03 = 'DOWN'
         SET @cOutField04 = ''
         SET @cOutField05 = @cReasonCode
         SET @cOutField06 = @cSubReasonCode
         SET @cOutField07 = ''
         SET @cOutField08 = ''

         SET @cFieldAttr04 = 'O'
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cWorkStation = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField01 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 4362)
   WorkStation       (Field01)
   Assigned user     (Field02)
   # of User         (Field03, input)
   Status            (Field04, input)
   Reason            (Field05, input)
   Sub Reason        (Field06, input)
   StartDownTime     (Field07, input)
   EndDownTime       (Field08, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewNoOfUser = @cInField04
      SET @cNewReason = @cInField05
      SET @cNewSubReason = @cInField06
      SET @cNewStartDownTime = @cInField07
      SET @cNewEndDownTime = @cInField08

      SELECT @cNewStatus = Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'WSTNSTATUS'
      AND   Short = @cOutField03

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN Step_3

      INSERT INTO WorkStation_LOG 
         (Facility, WorkZone, WorkStation, WorkMethod, 
         Descr, NoOfAssignedWorker, Status, ReasonCode, 
         SubReasonCode, StartDownTime, EndDownTime, LogWho, LogDate,
         JobKey, WorkOrderKey)
       SELECT Facility, WorkZone, WorkStation, WorkMethod, 
         Descr, NoOfAssignedWorker, Status, ReasonCode, 
         SubReasonCode, StartDownTime, EndDownTime,
         @cUserName AS LogWho, GETDATE() AS LogDate,
         @cJobKey, @cWorkOrderKey
      FROM dbo.WorkStation WITH (NOLOCK)
      WHERE WorkStation = @cWorkStation

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins WKLOG fail'
         ROLLBACK TRAN Step_3
         GOTO Step_3_Fail
      END

      UPDATE dbo.WorkStation WITH (ROWLOCK) SET 
         NoOfAssignedWorker = @cNewNoOfUser,
         Status = @cNewStatus,
         ReasonCode = CASE WHEN @cNewStatus = '0' THEN @cNewReason ELSE '' END,
         SubReasonCode = CASE WHEN @cNewStatus = '0' THEN @cNewSubReason ELSE '' END,
         StartDownTime = CASE WHEN @cNewStatus = '0' THEN @cNewStartDownTime ELSE NULL END,
         EndDownTime = CASE WHEN @cNewStatus = '0' THEN @cNewEndDownTime ELSE NULL END,
         JobKey = @cJobKey, 
         WorkOrderKey = @cWorkOrderKey
      WHERE WorkStation = @cWorkStation

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 58063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd WKSTN fail'
         ROLLBACK TRAN Step_3
         GOTO Step_3_Fail
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Step_3

      -- initialise all variable
      SET @cWorkStation = ''
      SET @cJobKey = ''
      SET @cWorkOrderKey = ''

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

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

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nAssignedUser = NoOfAssignedWorker, 
             @cStatus = [Status], 
             @cReasonCode = CASE WHEN [Status] = '0' THEN '' ELSE ReasonCode END, 
             @cSubReasonCode = CASE WHEN [Status] = '0' THEN '' ELSE SubReasonCode END, 
             @dStartDownTime = CASE WHEN [Status] = '0' THEN NULL ELSE StartDownTime END, 
             @dEndDownTime = CASE WHEN [Status] = '0' THEN NULL ELSE EndDownTime END
      FROM dbo.WorkStation WITH (NOLOCK)
      WHERE WorkStation = @cWorkStation

      SELECT @cWorkStationStatus = Short
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'WSTNSTATUS'
      AND   Code = @cStatus

      SET @cOutField01 = @cWorkStation
      SET @cOutField02 = @nAssignedUser
      SET @cOutField03 = @cWorkStationStatus
      SET @cOutField04 = @cReasonCode
      SET @cOutField05 = @cSubReasonCode
      SET @cOutField06 = CONVERT(NVARCHAR, @dStartDownTime, 101) + ' ' + 
		                   CONVERT(NVARCHAR, DATEPART(hh, @dStartDownTime)) + ':' + 
		                   RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, @dStartDownTime)), 2)
      SET @cOutField07 = CONVERT(NVARCHAR, @dEndDownTime, 101) + ' ' + 
		                   CONVERT(NVARCHAR, DATEPART(hh, @dEndDownTime)) + ':' + 
		                   RIGHT('0' + CONVERT(NVARCHAR, DATEPART(mi, @dEndDownTime)), 2)
      SET @cOutField08 = ''

      --prepare prev screen variable
      SET @cOption = ''

      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

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

   Step_3_Fail:
END
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_StorerKey   = @cStorerKey, 

      V_String1     = @cWorkStation,
      V_String2     = @cJobKey,
      V_String3     = @cWorkOrderKey,

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