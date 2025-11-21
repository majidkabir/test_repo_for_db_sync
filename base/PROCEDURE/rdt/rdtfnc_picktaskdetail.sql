SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdtfnc_PickTaskDetail                                  */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2019-02-18   1.0  ChewKP   WMS-7996 Created                             */
/* 2019-07-01   1.1  Ung      WMS-9542 Add storer group                    */
/*                            Clean up source                              */
/* 2019-10-14   1.2  Ung      WMS-10284 Add FPP task, Cart ID              */
/* 2022-06-21   1.3  Ung      WMS-19992 Add event log                      */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PickTaskDetail](
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption       NVARCHAR(1),
   @curTask       CURSOR,
   @tTaskLabel    VariableTable

-- RDT.RDTMobRec variables
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerGroup  NVARCHAR( 20),
   @cStorerKey    NVARCHAR( 15),
   @cUserName     NVARCHAR( 18),
   @cFacility     NVARCHAR( 5),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),

   @cAreaKey      NVARCHAR(10),
   @cTaskType     NVARCHAR(10),
   @cUserKey      NVARCHAR(18),
   @cGroupKey     NVARCHAR(10),
   @cCartID       NVARCHAR(10),

   @nOpenTask     INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),   @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),   @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),   @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),   @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),   @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),   @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),   @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),   @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),   @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),   @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),   @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),   @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),   @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),   @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cStorerGroup  = StorerGroup,
   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cUserName     = UserName,
   @cLabelPrinter = Printer,
   @cPaperPrinter = Printer_Paper,

   @cAreaKey      = V_String1,
   @cTaskType     = V_String2,
   @cUserKey      = V_String3,
   @cGroupKey     = V_String4,
   @cCartID       = V_String5,

   @nOpenTask     = V_Integer1,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,   @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,   @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,   @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,   @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,   @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,   @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,   @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,   @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,   @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,   @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,   @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,   @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,   @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,   @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,   @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 836
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0 -- Menu. Func = 836
   IF @nStep = 1  GOTO Step_1 -- Scn = 5160. UserID, AreaKey, TaskType
   IF @nStep = 2  GOTO Step_2 -- Scn = 5161. Option. Print Label
   IF @nStep = 3  GOTO Step_3 -- Scn = 5162. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 836
********************************************************************************/
Step_0:
BEGIN
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- UserID
   SET @cOutField02 = '' -- AreaKey
   SET @cOutField03 = '' -- TaskType

   EXEC rdt.rdtSetFocusField @nMobile, 1 -- UserKey

   -- Go to next screen
   SET @nScn = 5160
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 5160.
   UserID  (field01, input)
   AreaKey (field02, input)
   TaskType (field03, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUserKey = @cInField01
      SET @cAreaKey = @cInField02
      SET @cTaskType = @cInField03
      SET @cCartID = @cInField04

      -- Any change, remain on same screen
      DECLARE @nNewInput INT
      IF @cInField01 <> @cOutField01 OR
         @cInField02 <> @cOutField02 OR
         @cInField03 <> @cOutField03 OR
         @cInField04 <> @cOutField04
         SET @nNewInput = 1
      ELSE
         SET @nNewInput = 0

      -- Check blank
      IF @cUserKey = ''
      BEGIN
         SET @nErrNo = 134451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UserID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check user valid
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskManagerUserDetail WITH (NOLOCK) WHERE UserKey = @cUserKey)
      BEGIN
         SET @nErrNo = 134452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UserID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UserKey
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 134453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UserKey
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      SET @cOutField01 = @cUserKey

      -- Check areakey
      IF @cAreaKey <> ''
      BEGIN
         -- Check areakey valid
         IF NOT EXISTS( SELECT 1 FROM dbo.AreaDetail WITH (NOLOCK) WHERE AreaKey = @cAreaKey)
         BEGIN
            SET @nErrNo = 134454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvAreaKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- AreaKey
            SET @cOutField02 = ''
            GOTO Quit
         END
      END
      SET @cOutField02 = @cAreaKey

      -- Check TaskType
      IF @cTaskType NOT IN ('FPK', 'FCP', 'FPP')
      BEGIN
         SET @nErrNo = 134455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvTaskType
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- TaskType
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cTaskType

      -- Check cart ID
      IF @cTaskType = 'FPP'
      BEGIN
         IF @cCartID = ''
         BEGIN
            SET @nErrNo = 134458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FPP need cart
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartID
            GOTO Quit
         END

         -- Check cart ID valid
         IF NOT EXISTS( SELECT 1 FROM DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID)
         BEGIN
            SET @nErrNo = 134459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cart
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartID
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF @cCartID <> ''
         BEGIN
            SET @nErrNo = 134460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dont need cart
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartID
            SET @cOutField04 = ''
            GOTO Quit
         END
      END
      SET @cOutField04 = @cCartID

      -- Any change, remain on same screen
      IF @nNewInput = 1
      BEGIN
         IF @cAreaKey = '' OR
           (@cTaskType = 'FPP' AND @cCartID = '')
         BEGIN
            IF @cAreaKey  = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- AreaKey
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartID

            GOTO Quit
         END
      END

      -- Get user setting
      DECLARE @cUserAreaKey NVARCHAR(10)
      DECLARE @cUserTaskType NVARCHAR(10)
      SELECT TOP 1
          @cUserAreaKey = AreaKey
         ,@cUserTaskType = PermissionType
      FROM dbo.TaskManagerUserDetail WITH (NOLOCK)
      WHERE UserKey = @cUserKey

      -- Default AreaKey
      IF @cAreaKey = ''
         SET @cAreaKey = @cUserAreaKey

      -- Default TaskType
      IF @cTaskType = ''
         SET @cTaskType = @cUserTaskType

      -- Get stat
      IF @cStorerGroup <> ''
      BEGIN
         SELECT @nOpenTask = COUNT(1)
         FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = TD.StorerKey)
         WHERE SG.StorerGroup = @cStorerGroup
            AND TD.TaskType = @cTaskType
            AND TD.AreaKey = @cAreaKey
            AND TD.Status = '0'
      END
      ELSE
      BEGIN
         SELECT @nOpenTask = COUNT(1)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND TaskType = @cTaskType
            AND AreaKey = @cAreaKey
            AND Status = '0'
      END

      SET @cOutField01 = @cAreaKey
      SET @cOutField02 = @cTaskType
      SET @cOutField03 = CAST( @nOpenTask AS NVARCHAR(5))
      SET @cOutField04 = '' -- Option

       -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5161. screen
   AreaKey    (field01)
   TaskType   (field02)
   Open Task  (field03)
   Option     (field04, input)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField04

      -- Check option valid
      IF @cOption <> '1'
      BEGIN
         SET @nErrNo = 134456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Print
      IF @cOption = '1'
      BEGIN
         DECLARE @cTaskDetailKey NVARCHAR(10)
         DECLARE @nTotalPrintTask INT

         SET @nTotalPrintTask = 0

         IF @cTaskType = 'FPP'
         BEGIN
            DECLARE @tCartPOSLabel VariableTable
            DECLARE @tCartPickList VariableTable

            DECLARE @nMaxPOS     INT = 0
            DECLARE @nNoOfCopy   INT = 1
            DECLARE @cPriority   NVARCHAR( 10) = ''
            DECLARE @cOrderKey   NVARCHAR( 10) = ''
            DECLARE @cDocType    NVARCHAR( 1) = ''

            -- Get cart info
            SELECT @nMaxPOS = COUNT(1) FROM DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID
            SELECT TOP 1 @cPriority = Priority FROM DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Priority <> ''

            -- Limit to 6 orders per cart
            IF @nMaxPOS > 6
               SET @nMaxPOS = 6

            DECLARE @tOrders TABLE
            (
               RowRef   INT IDENTITY( 1, 1),
               OrderKey    NVARCHAR( 10),
               StorerKey   NVARCHAR( 15),
               DocType     NVARCHAR( 1),
               PRIMARY KEY CLUSTERED (OrderKey)
            )

            -- Get up to 6 orders
            IF @cStorerGroup <> ''
               INSERT INTO @tOrders (OrderKey, StorerKey, DocType)
               SELECT TOP (@nMaxPOS)
                  A.OrderKey, A.StorerKey, A.DocType
               FROM
               (
                  SELECT O.OrderKey, O.StorerKey, O.DocType, MIN( TD.Priority) AS Priority, MIN( TD.TaskDetailKey) AS TaskDetailKey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = TD.StorerKey)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = TD.OrderKey)
                  WHERE SG.StorerGroup = @cStorerGroup
                     AND TD.TaskType = @cTaskType
                     AND TD.AreaKey = @cAreaKey
                     AND TD.Status = '0'
                     AND ((@cPriority =  'ECOM' AND O.DocType =  'E') OR  -- ECOM cart, pick ECOM order
                          (@cPriority <> 'ECOM' AND O.DocType <> 'E'))    -- Non ECOM cart, pick non ECOM order
                  GROUP BY O.OrderKey, O.StorerKey, O.DocType
               ) A
               ORDER BY
                  A.Priority, A.TaskDetailKey
            ELSE
               INSERT INTO @tOrders (OrderKey, StorerKey, DocType)
               SELECT TOP (@nMaxPOS)
                  A.OrderKey, A.StorerKey, A.DocType
               FROM
               (
                  SELECT O.OrderKey, O.StorerKey, O.DocType, MIN( TD.Priority) AS Priority, MIN( TD.TaskDetailKey) AS TaskDetailKey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = TD.OrderKey)
                  WHERE TD.StorerKey = @cStorerKey
                     AND TD.TaskType = @cTaskType
                     AND TD.AreaKey = @cAreaKey
                     AND TD.Status = '0'
                     AND ((@cPriority =  'ECOM' AND O.DocType =  'E') OR  -- ECOM cart, pick ECOM order
                          (@cPriority <> 'ECOM' AND O.DocType <> 'E'))    -- Non ECOM cart, pick non ECOM order
                  GROUP BY O.OrderKey, O.StorerKey, O.DocType
               ) A
               ORDER BY
                  A.Priority, A.TaskDetailKey

            -- Check orders
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 134461
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No orders
               GOTO Quit
            END

            DECLARE @nTranCount INT
            SET @nTranCount = @@ROWCOUNT
            BEGIN TRAN
            SAVE TRAN rdtfnc_PickTaskDetail

            -- Update TaskDetail
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TD.TaskDetailKey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN @tOrders t ON (TD.OrderKey = t.OrderKey)
               WHERE TD.StorerKey = @cStorerKey
                  AND TD.TaskType = @cTaskType
                  AND TD.AreaKey = @cAreaKey
                  AND TD.Status = '0'
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.TaskDetail SET
                  Status = '3',
                  UserKey = @cUserKey,
                  StartTime = GETDATE(),
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_PickTaskDetail
                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN

                  SET @nErrNo = 134462
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail
                  GOTO Quit
               END
               FETCH NEXT FROM @curTask INTO @cTaskDetailKey
            END

            COMMIT TRAN rdtfnc_PickTaskDetail
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

            -- Cart position label
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT OrderKey, StorerKey, DocType
               FROM @tOrders
               ORDER BY RowRef
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cOrderKey, @cStorerKey, @cDocType
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DECLARE @cCartPOSLabel NVARCHAR(20)
               SET @cCartPOSLabel = rdt.RDTGetConfig( @nFunc, 'CartPositionLabel', @cStorerKey)
               IF @cCartPOSLabel = '0'
                  SET @cCartPOSLabel = ''

               IF @cCartPOSLabel <> ''
               BEGIN
                  DELETE FROM @tCartPOSLabel
                  INSERT INTO @tCartPOSLabel (Variable, Value) VALUES
                     ( '@cCartID',    @cCartID),
                     ( '@cOrderKey',  @cOrderKey)

                  IF @cDocType = 'E'
                     SET @nNoOfCopy = 1
                  ELSE
                     SET @nNoOfCopy = NULL -- follow rdtReport.NoOfCopy

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cCartPOSLabel, -- Report type
                     @tCartPOSLabel, -- Report params
                     'rdtfnc_PickTaskDetail',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @nNoOfCopy = @nNoOfCopy

                  IF @nErrNo <> 0
                     GOTO Quit

                  SET @nTotalPrintTask = @nTotalPrintTask + 1
               END
               FETCH NEXT FROM @curTask INTO @cOrderKey, @cStorerKey, @cDocType
            END

            -- Cart pick list
            DECLARE @cCartPickList NVARCHAR(20)
            SET @cCartPickList = rdt.RDTGetConfig( @nFunc, 'CartPickList', @cStorerKey)
            IF @cCartPickList = '0'
               SET @cCartPickList = ''

            IF @cCartPickList <> ''
            BEGIN
               DECLARE @nOrders INT

               INSERT INTO @tCartPickList (Variable, Value)
               SELECT '@cOrderKey' + CAST( RowRef AS NVARCHAR(1)), OrderKey
               FROM @tOrders

               -- rdtReport had mapped 6 orders param. Insert blank, if not enough orders
               SET @nOrders = @@ROWCOUNT
               WHILE @nOrders < 6
               BEGIN
                  SET @nOrders = @nOrders + 1
                  INSERT INTO @tCartPickList (Variable, Value)
                  VALUES ('@cOrderKey' + CAST( @nOrders AS NVARCHAR(1)), '')
               END

               INSERT INTO @tCartPickList (Variable, Value)
               VALUES ( '@cUserKey', @cUserKey)

               -- Print cart pick list
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cCartPickList, -- Report type
                  @tCartPickList, -- Report params
                  'rdtfnc_PickTaskDetail',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END
         END

         IF @cTaskType IN ('FPK', 'FCP')
         BEGIN
            IF @cStorerGroup <> ''
            BEGIN
               -- Get a grouped tasks
               SELECT TOP 1
                  @cGroupKey = GroupKey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = TD.StorerKey)
               WHERE SG.StorerGroup = @cStorerGroup
                  AND TaskType = @cTaskType
                  AND AreaKey = @cAreaKey
                  AND Status = '0'
               ORDER BY Priority, TaskDetailKey

               -- Loop tasks in the group
               SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT TD.TaskDetailKey, TD.StorerKey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = TD.StorerKey)
                  WHERE SG.StorerGroup = @cStorerGroup
                     AND TD.TaskType = @cTaskType
                     AND TD.AreaKey = @cAreaKey
                     AND TD.Status = '0'
                     AND TD.GroupKey = @cGroupKey
                  ORDER BY TD.TaskDetailKey
            END
            ELSE
            BEGIN
               -- Get a grouped tasks
               SELECT TOP 1
                  @cGroupKey = GroupKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND TaskType = @cTaskType
                  AND AreaKey = @cAreaKey
                  AND Status = '0'
               ORDER BY Priority, TaskDetailKey

               -- Loop tasks in the group
               SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT TaskDetailKey, StorerKey
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND TaskType = @cTaskType
                     AND AreaKey = @cAreaKey
                     AND Status = '0'
                     AND GroupKey = @cGroupKey
                  ORDER BY TaskDetailKey
            END

            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Task label
               DECLARE @cTaskLabel NVARCHAR(20)
               SET @cTaskLabel = rdt.RDTGetConfig( @nFunc, 'TaskLabel', @cStorerKey)
               IF @cTaskLabel = '0'
                  SET @cTaskLabel = ''

               -- Print task label
               IF @cTaskLabel <> ''
               BEGIN
                  DELETE FROM @tTaskLabel
                  INSERT INTO @tTaskLabel (Variable, Value) VALUES ( '@cTaskDetailKey',  @cTaskDetailKey)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cTaskLabel, -- Report type
                     @tTaskLabel, -- Report params
                     'rdtfnc_PickTaskDetail',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit

                  -- Update TaskDetail
                  UPDATE dbo.TaskDetail SET
                     Status = '3',
                     UserKey = @cUserKey,
                     StartTime = GETDATE(),
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     TrafficCop = NULL
                  WHERE TaskDetailKey = @cTaskDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 134457
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail
                     GOTO Quit
                  END

                  SET @nTotalPrintTask = @nTotalPrintTask + 1
               END
               FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey
            END
         END

         -- Logging
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey, 
            @cAreaKey      = @cAreaKey, 
            @cTaskType     = @cTaskType, 
            @cDeviceID     = @cCartID, 
            @cRefNo1       = @cGroupKey, 
            @cRefNo2       = @cUserKey

         SET @cOutField01 = @cAreaKey
         SET @cOutField02 = @cTaskType
         SET @cOutField03 = CAST( @nOpenTask AS NVARCHAR(5))
         SET @cOutField04 = CAST( @nTotalPrintTask AS NVARCHAR(5))

          -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = '' -- AreaKey
      SET @cOutField03 = '' -- TaskType

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UserKey

      -- Go to next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5162. screen
   AreaKey    (field01)
   TaskType   (field02)
   Open Task  (field03)
   Get task   (field04)
***********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0  -- ENTER
   BEGIN
       -- Go to next screen
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = '' -- AreaKey
      SET @cOutField03 = '' -- TaskType

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UserKey

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
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

      -- StorerKey = @cStorerKey,

	   V_String1 = @cAreaKey,
	   V_String2 = @cTaskType,
	   V_String3 = @cUserKey,
	   V_String4 = @cGroupKey,
	   V_String5 = @cCartID,

      V_Integer1 = @nOpenTask,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO