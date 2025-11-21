SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PTLStation_CloseCarton                             */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-03-09 1.0  Ung        SOS361967 Created                               */
/* 2016-06-09 1.1  Ung        SOS361967 Fix LOC multi carton check            */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-10-10 1.3  TungGH     Performance                                     */  
/* 2018-11-21 1.4  James      WMS6952-Allow cartonid = ALL to unassign whole  */  
/*                            ptl station (james01)                           */
/* 2019-05-15 1.5  Ung        WMS-9089 Add turn off light                     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTLStation_CloseCarton] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @i             INT, 
   @nCount        INT,
   @bSuccess      INT,
   @nTranCount    INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @nRowCount     INT, 
   @nActQTY       INT, 
   @cNewCartonID  NVARCHAR( 20), 
   @cShort        NVARCHAR( 10), 
   @cDeviceID     NVARCHAR( 20),
   @cPosition     NVARCHAR( 10), 
      
   @cResult01  NVARCHAR( 20),
   @cResult02  NVARCHAR( 20),
   @cResult03  NVARCHAR( 20),
   @cResult04  NVARCHAR( 20),
   @cResult05  NVARCHAR( 20),
   @cResult06  NVARCHAR( 20),
   @cResult07  NVARCHAR( 20),
   @cResult08  NVARCHAR( 20),
   @cResult09  NVARCHAR( 20),
   @cResult10  NVARCHAR( 20)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPrinter      NVARCHAR( 20),
   @cUserName     NVARCHAR( 18),

   @cLOC          NVARCHAR(10),

   @cStation      NVARCHAR(10),
   @cStation1     NVARCHAR(10),
   @cStation2     NVARCHAR(10),
   @cStation3     NVARCHAR(10),
   @cStation4     NVARCHAR(10),
   @cStation5     NVARCHAR(10),
   @cMethod       NVARCHAR(1),
   @cCartonID     NVARCHAR(20),
   @cLight        NVARCHAR(1),

   @cExtendedStationValSP  NVARCHAR( 20),

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,
   @cDeviceID  = DeviceID,
   
   @cLOC        = V_LOC,

   @cStation1   = V_String1,
   @cStation2   = V_String2,
   @cStation3   = V_String3,
   @cStation4   = V_String4,
   @cStation5   = V_String5, 
   @cMethod     = V_String6,
   @cCartonID   = V_String7,
   @cLight      = V_String8,

   @cExtendedStationValSP  = V_String10,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 804  -- PTL Station close carton
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Cart
   IF @nStep = 1 GOTO Step_1   -- Scn = 4510. PTLStation, Method
   IF @nStep = 2 GOTO Step_2   -- Scn = 4511. Carton ID, LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4512. Confirm close?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 804. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cExtendedStationValSP = rdt.RDTGetConfig( @nFunc, 'ExtendedStationValSP', @cStorerKey)
   IF @cExtendedStationValSP = '0'
      SET @cExtendedStationValSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign-in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init var
   SET @cStation1 = ''
   SET @cStation2 = ''
   SET @cStation3 = ''
   SET @cStation4 = ''
   SET @cStation5 = ''

   -- Init screen
   SET @cOutField01 = '' -- Station1
   SET @cOutField02 = '' -- Station2
   SET @cOutField03 = '' -- Station3
   SET @cOutField04 = '' -- Station4
   SET @cOutField05 = '' -- Station5
   SET @cOutField06 = '' -- Method

   -- Get storer config
   DECLARE @cBypassTCPSocket NVARCHAR(1)
   SET @cBypassTCPSocket = ''
   EXECUTE nspGetRight
      NULL,
      @cStorerKey,
      NULL,
      'BypassTCPSocketClient',
      @bSuccess         OUTPUT,
      @cBypassTCPSocket OUTPUT,
      @nErrNo           OUTPUT,
      @cErrMsg          OUTPUT

   IF @cDeviceID <> '' AND @cBypassTCPSocket <> '1'
      SET @cLight = '1' -- Use light
   ELSE
      SET @cLight = '0' -- Not use

   -- Set the entry point
   SET @nScn = 4510
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4510.
   PTLStation1 (Field01, input)
   PTLStation1 (Field02, input)
   PTLStation1 (Field03, input)
   PTLStation1 (Field04, input)
   PTLStation1 (Field05, input)
   Method      (Field06, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Retain key-in value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cMethod = @cInField06

      -- Validate blank
      IF @cInField01 = '' AND
         @cInField02 = '' AND
         @cInField03 = '' AND
         @cInField04 = '' AND
         @cInField05 = '' 
      BEGIN
        SET @nErrNo = 97301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTLStation req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Put all UCC into temp table
      DECLARE @tStation TABLE (Station NVARCHAR( 10), i INT)
      INSERT INTO @tStation (Station, i) VALUES (@cInField01, 1)
      INSERT INTO @tStation (Station, i) VALUES (@cInField02, 2)
      INSERT INTO @tStation (Station, i) VALUES (@cInField03, 3)
      INSERT INTO @tStation (Station, i) VALUES (@cInField04, 4)
      INSERT INTO @tStation (Station, i) VALUES (@cInField05, 5)

      -- Validate UCC scanned more than once
      SELECT @i = MAX( i)
      FROM @tStation
      WHERE Station <> '' AND Station IS NOT NULL
      GROUP BY Station
      HAVING COUNT( Station) > 1

      IF @@ROWCOUNT <> 0
      BEGIN
         SET @nErrNo = 97302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationScanned
         EXEC rdt.rdtSetFocusField @nMobile, @i
         GOTO Quit
      END

      -- Validate if anything changed
      IF @cStation1 <> @cInField01 OR
         @cStation2 <> @cInField02 OR
         @cStation3 <> @cInField03 OR
         @cStation4 <> @cInField04 OR
         @cStation5 <> @cInField05
      -- There are changes, remain in current screen
      BEGIN
         DECLARE @cInField NVARCHAR( 10)
         
         -- Check newly scanned station. Validated station will be saved to respective @cStation variable
         SET @i = 1
         WHILE @i < 6
         BEGIN
            IF @i = 1 SELECT @cInField = @cInField01, @cStation = @cStation1
            IF @i = 2 SELECT @cInField = @cInField02, @cStation = @cStation2
            IF @i = 3 SELECT @cInField = @cInField03, @cStation = @cStation3
            IF @i = 4 SELECT @cInField = @cInField04, @cStation = @cStation4
            IF @i = 5 SELECT @cInField = @cInField05, @cStation = @cStation5

            -- Value changed
            IF @cInField <> @cStation
            BEGIN
               -- Consist a new value
               IF @cInField <> ''
               BEGIN
                  -- Check station valid
                  IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceType = 'STATION' AND DeviceID <> '' AND DeviceID = @cInField)
                  BEGIN
                     SET @nErrNo = 97304
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStation
                  END
                  
                  IF @nErrNo <> 0
                  BEGIN
                     -- Extended station validate
                     IF @cExtendedStationValSP <> ''
                     BEGIN
                        IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedStationValSP AND type = 'P')
                        BEGIN
                           SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedStationValSP) +
                              ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                              ' @cStation, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                           SET @cSQLParam =
                              ' @nMobile    INT,           ' +
                              ' @nFunc      INT,           ' +
                              ' @cLangCode  NVARCHAR( 3),  ' +
                              ' @nStep      INT,           ' +
                              ' @nInputKey  INT,           ' +
                              ' @cFacility  NVARCHAR( 5),  ' +
                              ' @cStorerKey NVARCHAR( 15), ' +
                              ' @cStation   NVARCHAR( 10), ' +
                              ' @cStation1  NVARCHAR( 10), ' +
                              ' @cStation2  NVARCHAR( 10), ' +
                              ' @cStation3  NVARCHAR( 10), ' +
                              ' @cStation4  NVARCHAR( 10), ' +
                              ' @cStation5  NVARCHAR( 10), ' +
                              ' @cLight     NVARCHAR( 1),  ' + 
                              ' @nErrNo     INT            OUTPUT, ' +
                              ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
                  
                           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                              @cInField, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, '0', @nErrNo OUTPUT, @cErrMsg OUTPUT
                        END
                     END
                  END
                  
                  IF @nErrNo <> 0
                  BEGIN
                     -- Error, clear the station field
                     IF @i = 1 SELECT @cStation1 = '', @cInField01 = '', @cOutField01 = ''
                     IF @i = 2 SELECT @cStation2 = '', @cInField02 = '', @cOutField02 = ''
                     IF @i = 3 SELECT @cStation3 = '', @cInField03 = '', @cOutField03 = ''
                     IF @i = 4 SELECT @cStation4 = '', @cInField04 = '', @cOutField04 = ''
                     IF @i = 5 SELECT @cStation5 = '', @cInField05 = '', @cOutField05 = ''
                     EXEC rdt.rdtSetFocusField @nMobile, @i
                     GOTO Quit
                  END
               END
               
               -- Save to station variable
               IF @i = 1 SET @cStation1 = @cInField01
               IF @i = 2 SET @cStation2 = @cInField02
               IF @i = 3 SET @cStation3 = @cInField03
               IF @i = 4 SET @cStation4 = @cInField04
               IF @i = 5 SET @cStation5 = @cInField05

            END
            SET @i = @i + 1
         END
         
         -- Set next field focus
         SET @i = 1 -- start from 1st field
         IF @cInField01 <> '' SET @i = @i + 1
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1

         EXEC rdt.rdtSetFocusField @nMobile, @i
         GOTO Quit
      END

      -- Check blank
      IF @cMethod = ''
      BEGIN
         SET @nErrNo = 97305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need method
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Get method info
      DECLARE @cMethodSP SYSNAME
      SET @cMethodSP = ''
      SELECT @cMethodSP = ISNULL( UDF01, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'PTLMethod'
         AND Code = @cMethod
         AND StorerKey = @cStorerKey

      -- Check method
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 97306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 97307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Method SP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END
      SET @cOutField06 = @cMethod

      -- Prepare next screen var
      SET @cOutField01 = '' -- Carton ID
      SET @cOutField02 = '' -- LOC
      
      -- Go to carton ID / LOC screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 2. Scn = 4511. Old carton screen
   CartonID (field01, input)
   LOC      (field02, input
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @nTaskQTY INT
      DECLARE @cQTY     NVARCHAR(5)

      -- Screen mapping
      SET @cCartonID = @cInField01
      SET @cLOC = @cInField02

      -- Check both blank
      IF @cCartonID = '' AND @cLOC = ''
      BEGIN
         SET @nErrNo = 97308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/LOC
         GOTO Quit
      END

      -- Check both with value
      IF @cCartonID <> '' AND @cLOC <> ''
      BEGIN
         SET @nErrNo = 97309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either ID/LOC
         GOTO Quit
      END

      -- Carton ID
      IF @cCartonID <> ''
      BEGIN
         -- Check carton on station
         IF NOT EXISTS( SELECT 1
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND ( (@cCartonID = 'ALL') OR CartonID = @cCartonID)) -- (james01)
         BEGIN
            SET @nErrNo = 97310
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         IF @cLight = '1' -- Use light
            SELECT 
               @cStation = Station, 
               @cPosition = Position
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cCartonID 
         
         SET @cOutField01 = @cCartonID
      END

      -- LOC
      IF @cLOC <> ''
      BEGIN
         -- Check LOC valid
         IF NOT EXISTS( SELECT 1 FROM DeviceProfile WITH (NOLOCK) 
            WHERE DeviceID IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND DeviceType = 'STATION'
               AND DeviceID <> ''
               AND LOC = @cLOC)
         BEGIN
            SET @nErrNo = 97311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Check LOC multi carton
         IF EXISTS( SELECT 1 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND LOC = @cLOC
            HAVING COUNT( DISTINCT CartonID) > 1)
         BEGIN
            SET @nErrNo = 97312
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCMultiCarton
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Get carton ID, base on LOC
         SELECT 
            @cCartonID = CartonID, 
            @cStation = Station, 
            @cPosition = Position
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND LOC = @cLOC
         
         -- Check LOC on station
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 97313
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC No Carton
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END
         SET @cOutField02 = @cLOC
      END

      -- Get next task QTY
      EXEC rdt.rdt_PTLStation_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTCARTON'
         ,'' -- @cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,'' -- @cScanID
         ,'' -- @cSKU
         ,@cCartonID
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
      IF @nErrNo = -1 -- No more next task
      BEGIN
         SET @nErrNo = 0
         
         -- Print label
         EXEC rdt.rdt_PTLStation_PrintLabel @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
         -- Close position
         EXEC rdt.rdt_PTLStation_Unassign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Turn off light
         IF @cLight = '1'
         BEGIN
            EXEC PTL.isp_PTL_TerminateModuleSingle
                  @cStorerKey
                 ,@nFunc
                 ,@cStation
                 ,@cPosition
                 ,@bSuccess    OUTPUT
                 ,@nErrNo      OUTPUT
                 ,@cErrMsg     OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
         
         -- Prepare current screen var
         SET @cOutField01 = '' -- CartonID
         SET @cOutField02 = '' -- LOC
         
         -- Remain in current screen
         -- SET @nScn = @nScn - 1
         -- SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to confirm close screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cStation1
      SET @cOutField02 = @cStation2
      SET @cOutField03 = @cStation3
      SET @cOutField04 = @cStation4
      SET @cOutField05 = @cStation5
      SET @cOutField06 = @cMethod

      -- Go to station screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 4512. Confirm close screen
   Found outstanding.  
   Confirm close?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)
   
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 97314
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 97315
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Print label
         EXEC rdt.rdt_PTLStation_PrintLabel @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
         -- Close position
         EXEC rdt.rdt_PTLStation_Unassign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- Prep next screen var
      SET @cOutField01 = '' -- Carton ID
      SET @cOutField02 = '' -- LOC
   
      IF @cLOC = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
   
      -- Go to PTL station screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = CASE WHEN @cLOC = '' THEN @cCartonID ELSE '' END
      SET @cOutField02 = @cLOC
   
      IF @cLOC = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
   
      -- Go to carton, LOC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO QUIT


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
      InputKey  = @nInputKey,

      V_LOC      = @cLOC,

      V_String1  = @cStation1,
      V_String2  = @cStation2,
      V_String3  = @cStation3,
      V_String4  = @cStation4,
      V_String5  = @cStation5,
      V_String6  = @cMethod,
      V_String7  = @cCartonID,
      V_String8  = @cLight,

      V_String10 = @cExtendedStationValSP,

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