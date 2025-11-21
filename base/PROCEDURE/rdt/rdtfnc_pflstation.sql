SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PFLStation                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-06-11 1.0  Ung        WMS-9372 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PFLStation] (
   @nMobile    INT,
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
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
   @tVar          VariableTable, 
   @nRowCount     INT, 
   @nActQTY       INT, 
   @cNewCartonID  NVARCHAR( 20), 
   @cShort        NVARCHAR(10), 

   @cResult01     NVARCHAR( 20),
   @cResult02     NVARCHAR( 20),
   @cResult03     NVARCHAR( 20),
   @cResult04     NVARCHAR( 20),
   @cResult05     NVARCHAR( 20),
   @cResult06     NVARCHAR( 20),
   @cResult07     NVARCHAR( 20),
   @cResult08     NVARCHAR( 20),
   @cResult09     NVARCHAR( 20),
   @cResult10     NVARCHAR( 20)

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
   @cDeviceID     NVARCHAR( 20),

   @cLOC          NVARCHAR(10),
   @cSKU          NVARCHAR(20),
   @cSKUDescr     NVARCHAR(60),
   @nQTY          INT,
   @nFromScn      INT,
   @nFromStep     INT,

   @cStation      NVARCHAR(10),
   @cStation1     NVARCHAR(10),
   @cStation2     NVARCHAR(10),
   @cStation3     NVARCHAR(10),
   @cStation4     NVARCHAR(10),
   @cStation5     NVARCHAR(10),
   @cMethod       NVARCHAR(1),
   @cScanID       NVARCHAR(20),
   @cCartonID     NVARCHAR(20),
   @nCartonQTY    INT,
   @nNextPage     INT,
   @cOption       NVARCHAR(1),
   @nTaskQTY      INT,

   @cExtendedStationValSP  NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cTerminateLightSP      NVARCHAR( 20),
   @cLight                 NVARCHAR( 1),
   @cExtendedInfo          NVARCHAR( 20),
   @cDefaultDeviceID       NVARCHAR( 20), 

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
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = V_QTY,
   @nFromScn    = V_FromScn, 
   @nFromStep   = V_FromStep, 

   @cStation1   = V_String1,
   @cStation2   = V_String2,
   @cStation3   = V_String3,
   @cStation4   = V_String4,
   @cStation5   = V_String5, 
   @cMethod     = V_String6,
   @cScanID     = V_String7,
   @cCartonID   = V_String8,
   @cOption     = V_String11,

   @cExtendedStationValSP  = V_String20,
   @cExtendedValidateSP    = V_String21,
   @cExtendedUpdateSP      = V_String22,
   @cExtendedInfoSP        = V_String23,
   @cLight                 = V_String24,
   @cExtendedInfo          = V_String25,
   @cTerminateLightSP      = V_String26,

   @nCartonQTY  = V_Integer1, 
   @nNextPage   = V_Integer2, 

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 801  -- PFL Station
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Station
   IF @nStep = 1 GOTO Step_1   -- Scn = 5500. PFLStation, Method
   IF @nStep = 2 GOTO Step_2   -- Scn = 5510~5519 Dynamic assign
   IF @nStep = 3 GOTO Step_3   -- Scn = 5502. Matrix
   IF @nStep = 4 GOTO Step_4   -- Scn = 5503. New drop ID
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 801. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cDefaultDeviceID = rdt.RDTGetConfig( @nFunc, 'DefaultDeviceID', @cStorerKey)
             
   SET @cExtendedStationValSP = rdt.RDTGetConfig( @nFunc, 'ExtendedStationValSP', @cStorerKey)
   IF @cExtendedStationValSP = '0'
      SET @cExtendedStationValSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cTerminateLightSP = rdt.RDTGetConfig( @nFunc, 'TerminateLightSP', @cStorerKey)
   IF @cTerminateLightSP = '0'
      SET @cTerminateLightSP = ''

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

   -- Light
   IF @cDeviceID <> '' AND @cBypassTCPSocket <> '1'
      SET @cLight = '1' -- Use light
   ELSE
      SET @cLight = '0' -- Not use

   -- Light is pre-requisite, due to picking module need to confirm LOC and/or SKU. 
   IF @cLight = '0'
   BEGIN
      SET @nErrNo = 140101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickNeedLight
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign-in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

   -- Init var
   SET @cStation1 = ''
   SET @cStation2 = ''
   SET @cStation3 = ''
   SET @cStation4 = ''
   SET @cStation5 = ''

   IF @cDefaultDeviceID = '1' 
      SET @cStation1 = @cDeviceID 

   -- Init screen
   SET @cOutField01 = @cStation1
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
   SET @cOutField06 = '' -- Method

   -- Set the entry point
   SET @nScn = 5500
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5500.
   Station1 (Field01, input)
   Station2 (Field02, input)
   Station3 (Field03, input)
   Station4 (Field04, input)
   Station5 (Field05, input)
   Method   (Field06, input)
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
         SET @nErrNo = 140102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Station
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
         SET @nErrNo = 140103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationScanned
         EXEC rdt.rdtSetFocusField @nMobile, @i
         GOTO Quit
      END

      -- Not use light, only allow 1 station (due to matrix looks same across stations, operator might pick from wrong station)
      IF @cLight = '0' AND ((SELECT COUNT(1) FROM @tStation WHERE Station <> '') > 1)
      BEGIN
         SET @nErrNo = 140104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NolightUse1PFL
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
            IF @i = 1 SELECT @cInField = @cInField01, @cStation = @cStation1 ELSE
            IF @i = 2 SELECT @cInField = @cInField02, @cStation = @cStation2 ELSE
            IF @i = 3 SELECT @cInField = @cInField03, @cStation = @cStation3 ELSE
            IF @i = 4 SELECT @cInField = @cInField04, @cStation = @cStation4 ELSE
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
                     SET @nErrNo = 140105
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStation
                  END
                  
                  IF @nErrNo = 0
                  BEGIN
                     -- Check station in use                  
                     IF EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) 
                        WHERE Mobile <> @nMobile
                           AND Func = @nFunc 
                           AND @cInField IN (V_String1, V_String2, V_String3, V_String4, V_String5))
                     BEGIN
                        SET @nErrNo = 140106
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationInUse
                     END
                  END
                  
                  IF @nErrNo = 0
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
                              @cInField, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT
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
         SET @nErrNo = 140107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need method
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Get method info
      DECLARE @cMethodSP SYSNAME
      SET @cMethodSP = ''
      SELECT @cMethodSP = ISNULL( UDF01, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'PFLMethod'
         AND Code = @cMethod
         AND StorerKey = @cStorerKey

      -- Check method
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 140108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 140109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Assign SP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END
      SET @cOutField06 = @cMethod

      -- Dynamic assign
      EXEC rdt.rdt_PFLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, 'POPULATE-IN',
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nScn        OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

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
         @cStorerKey  = @cStorerkey

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
Step 2. Scn = 5510~5519. Dynamic assign
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PFLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, 'CHECK',
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nScn        OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep

      -- Draw matrix (and light up)
      SET @nNextPage = 0
      EXEC rdt.rdt_PFLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cResult01  OUTPUT
         ,@cResult02  OUTPUT
         ,@cResult03  OUTPUT
         ,@cResult04  OUTPUT
         ,@cResult05  OUTPUT
         ,@cResult06  OUTPUT
         ,@cResult07  OUTPUT
         ,@cResult08  OUTPUT
         ,@cResult09  OUTPUT
         ,@cResult10  OUTPUT
         ,@nNextPage  OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cResult01
      SET @cOutField02 = @cResult02
      SET @cOutField03 = @cResult03
      SET @cOutField04 = @cResult04
      SET @cOutField05 = @cResult05
      SET @cOutField06 = @cResult06
      SET @cOutField07 = @cResult07
      SET @cOutField08 = @cResult08
      SET @cOutField09 = @cResult09
      SET @cOutField10 = @cResult10
      SET @cOutField11 = '' -- Option
      SET @cOutField12 = '' -- ExtendedInfo 

      -- Go to matrix screen
      SET @nScn = 5501 + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Dynamic assign  
      EXEC rdt.rdt_PFLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, 'POPULATE-OUT',  
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  
         @nScn        OUTPUT,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  

      -- Prep next screen var
      SET @cOutfield01 = @cStation1
      SET @cOutfield02 = @cStation2
      SET @cOutfield03 = @cStation3
      SET @cOutfield04 = @cStation4
      SET @cOutfield05 = @cStation5
      SET @cOutfield06 = @cMethod

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Station1

      -- Go to station screen
      SET @nScn = 5501 - 1
      SET @nStep = @nStep - 1
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 5503. Maxtrix screen
   Result01 (field01)
   Result02 (field02)
   Result03 (field03)
   Result04 (field04)
   Result05 (field05)
   Result06 (field06)
   Result07 (field07)
   Result08 (field08)
   Result09 (field09)
   Result10 (field10)
   Option   (field11, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cOption = CASE WHEN @cFieldAttr01 = 'O' THEN @cOutField01 ELSE @cInField11 END

      -- Option
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check option valid
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 140110
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Quit
         END

         -- Prepare next screen var
         SET @cOutField01 = '' -- NewDropID

         -- Go to new DropID screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PFLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'' -- @cLight. Not re-light up
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cResult01  OUTPUT
         ,@cResult02  OUTPUT
         ,@cResult03  OUTPUT
         ,@cResult04  OUTPUT
         ,@cResult05  OUTPUT
         ,@cResult06  OUTPUT
         ,@cResult07  OUTPUT
         ,@cResult08  OUTPUT
         ,@cResult09  OUTPUT
         ,@cResult10  OUTPUT
         ,@nNextPage  OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF @nNextPage > 0 -- Yes
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cResult01
         SET @cOutField02 = @cResult02
         SET @cOutField03 = @cResult03
         SET @cOutField04 = @cResult04
         SET @cOutField05 = @cResult05
         SET @cOutField06 = @cResult06
         SET @cOutField07 = @cResult07
         SET @cOutField08 = @cResult08
         SET @cOutField09 = @cResult09
         SET @cOutField10 = @cResult10
         SET @cOutField11 = '' -- Close option

         GOTO Quit
      END

      -- Check pick completed (light)
      IF EXISTS( SELECT 1
         FROM rdt.rdtPFLStationLog L WITH (NOLOCK)
            JOIN PTL.PTLTran PTL WITH (NOLOCK) ON (L.RowRef = PTL.GroupKey AND PTL.Func = @nFunc)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND LightUp = '1')
      BEGIN
         SET @nErrNo = 140111
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
         GOTO Quit
      END

      SET @i = 1
      WHILE @i <= 5
      BEGIN
         SET @cStation = ''
         IF @i = 1 SET @cStation = @cStation1 ELSE
         IF @i = 2 SET @cStation = @cStation2 ELSE
         IF @i = 3 SET @cStation = @cStation3 ELSE
         IF @i = 4 SET @cStation = @cStation4 ELSE
         IF @i = 5 SET @cStation = @cStation5
         
         IF @cStation <> '' 
         BEGIN
            IF @cTerminateLightSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cTerminateLightSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cTerminateLightSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                     ' @cStation, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     ' @nMobile    INT,           ' +
                     ' @nFunc      INT,           ' +
                     ' @cLangCode  NVARCHAR( 3),  ' +
                     ' @nStep      INT,           ' +
                     ' @nInputKey  INT,           ' +
                     ' @cFacility  NVARCHAR( 5),  ' +
                     ' @cStorerKey NVARCHAR( 15), ' +
                     ' @cStation   NVARCHAR( 10), ' +
                     ' @nErrNo     INT            OUTPUT, ' +
                     ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
         
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                     @cStation, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            ELSE
            BEGIN
               -- Off all lights
               EXEC PTL.isp_PTL_TerminateModule
                   @cStorerKey
                  ,@nFunc
                  ,@cStation
                  ,'STATION'
                  ,@bSuccess    OUTPUT
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
            
         END
         SET @i = @i + 1
      END
        
      -- Go to dynamic assign screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep            
   END

   IF @nInputKey = 0
   BEGIN
      -- Draw matrix (and light up)
      EXEC rdt.rdt_PFLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'' -- @cLight. Not re-light up
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cResult01  OUTPUT
         ,@cResult02  OUTPUT
         ,@cResult03  OUTPUT
         ,@cResult04  OUTPUT
         ,@cResult05  OUTPUT
         ,@cResult06  OUTPUT
         ,@cResult07  OUTPUT
         ,@cResult08  OUTPUT
         ,@cResult09  OUTPUT
         ,@cResult10  OUTPUT
         ,@nNextPage  OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      IF @nNextPage > 0 -- Yes
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cResult01
         SET @cOutField02 = @cResult02
         SET @cOutField03 = @cResult03
         SET @cOutField04 = @cResult04
         SET @cOutField05 = @cResult05
         SET @cOutField06 = @cResult06
         SET @cOutField07 = @cResult07
         SET @cOutField08 = @cResult08
         SET @cOutField09 = @cResult09
         SET @cOutField10 = @cResult10
         SET @cOutField11 = '' -- Option

         GOTO Quit
      END

      -- Using lights
      IF @cLight = '1'
      BEGIN
         SET @i = 1
         WHILE @i <= 5
         BEGIN
            SET @cStation = ''
            IF @i = 1 SET @cStation = @cStation1 ELSE
            IF @i = 2 SET @cStation = @cStation2 ELSE
            IF @i = 3 SET @cStation = @cStation3 ELSE
            IF @i = 4 SET @cStation = @cStation4 ELSE
            IF @i = 5 SET @cStation = @cStation5
            
            IF @cStation <> '' 
            BEGIN
               IF @cTerminateLightSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cTerminateLightSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cTerminateLightSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                        ' @cStation, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                     SET @cSQLParam =
                        ' @nMobile    INT,           ' +
                        ' @nFunc      INT,           ' +
                        ' @cLangCode  NVARCHAR( 3),  ' +
                        ' @nStep      INT,           ' +
                        ' @nInputKey  INT,           ' +
                        ' @cFacility  NVARCHAR( 5),  ' +
                        ' @cStorerKey NVARCHAR( 15), ' +
                        ' @cStation   NVARCHAR( 10), ' +
                        ' @nErrNo     INT            OUTPUT, ' +
                        ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
            
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                        @cStation, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END
               ELSE
               BEGIN
                  -- Off all lights
                  EXEC PTL.isp_PTL_TerminateModule
                      @cStorerKey
                     ,@nFunc
                     ,@cStation
                     ,'STATION'
                     ,@bSuccess    OUTPUT
                     ,@nErrNo       OUTPUT
                     ,@cErrMsg      OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            SET @i = @i + 1
         END
      END

      -- Dynamic assign  
      EXEC rdt.rdt_PFLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, 'POPULATE-IN',  
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  
         @nScn        OUTPUT,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  

      -- Back to assign screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 5506. New drop ID screen
   NEW DROP ID (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cDropID NVARCHAR(20)
      
      -- Screen mapping
      SET @cDropID = @cInField01

      -- Check blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 140112
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DROP ID
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DropID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 140113
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- New drop ID
      EXEC rdt.rdt_PFLStation_NewDropID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cDropID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END
   
   -- Draw matrix (and light up)
   EXEC rdt.rdt_PFLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
     ,'' -- @cLight. Not re-light up
     ,@cStation1
     ,@cStation2
     ,@cStation3
     ,@cStation4
     ,@cStation5
     ,@cMethod
     ,@nErrNo     OUTPUT
     ,@cErrMsg    OUTPUT
     ,@cResult01  OUTPUT
     ,@cResult02  OUTPUT
     ,@cResult03  OUTPUT
     ,@cResult04  OUTPUT
     ,@cResult05  OUTPUT
     ,@cResult06  OUTPUT
     ,@cResult07  OUTPUT
     ,@cResult08  OUTPUT
     ,@cResult09  OUTPUT
     ,@cResult10  OUTPUT
     ,@nNextPage  OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Prepare next screen var
   SET @cOutField01 = @cResult01
   SET @cOutField02 = @cResult02
   SET @cOutField03 = @cResult03
   SET @cOutField04 = @cResult04
   SET @cOutField05 = @cResult05
   SET @cOutField06 = @cResult06
   SET @cOutField07 = @cResult07
   SET @cOutField08 = @cResult08
   SET @cOutField09 = @cResult09
   SET @cOutField10 = @cResult10
   SET @cOutField11 = '' -- Option

   -- Go to matrix screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
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
      InputKey  = @nInputKey,

      V_LOC      = @cLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,
      V_FromScn  = @nFromScn, 
      V_FromStep = @nFromStep, 

      V_String1  = @cStation1,
      V_String2  = @cStation2,
      V_String3  = @cStation3,
      V_String4  = @cStation4,
      V_String5  = @cStation5,
      V_String6  = @cMethod,
      V_String7  = @cScanID,
      V_String8  = @cCartonID,
      V_String11 = @cOption,

      V_String20 = @cExtendedStationValSP,
      V_String21 = @cExtendedValidateSP,
      V_String22 = @cExtendedUpdateSP,
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cLight,
      V_String25 = @cExtendedInfo,
      V_String26 = @cTerminateLightSP,

      V_Integer1 = @nCartonQTY,
      V_Integer2 = @nNextPage,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01, 
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02, 
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03, 
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04, 
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05, 
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06, 
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07, 
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08, 
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15
      
   WHERE Mobile = @nMobile
END



GO