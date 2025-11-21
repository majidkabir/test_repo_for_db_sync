SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PTLStation                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-01-28 1.0  Ung        SOS361967 Created                               */
/* 2016-09-30 1.1  Ung        Performance tuning                              */  
/* 2017-05-09 1.2  ChewKP     WMS-1841 - Fix MultiStation issues (ChewKP01)   */
/* 2017-06-30 1.3  Ung        WMS-2307 Add ExtendedInfoSP                     */
/*                            Add confirm all task screen                     */
/* 10-07-2017 1.4  Ung        IN00400794 Close carton should not refresh light*/
/*                            not yet press (for 1 station multi users)       */
/* 12-07-2017 1.5  Ung        WMS-2410 Clear scan ID if not task              */
/* 17-07-2017 1.6  Ung        WMS-2402 Add ExtendedInfoSP at matrix screen    */
/* 05-12-2017 1.7  Ung        WMS-3604 Add DecodeIDSP                         */
/* 22-12-2017 1.8  Ung        WMS-3604 Add RDT format for CartonID            */
/* 03-01-2018 1.9  ChewKP     WMS-3487 Enhancement (ChewKP02)                 */
/* 05-02-2018 2.0  James      WMS3893-Add DefaultDeviceID (james01)           */
/* 03-09-2018 2.1  Ung        WMS-6027 Support multi page matrix              */
/* 07-06-2018 2.2  ChewKP     WMS-3962 Enhancement on Decode SP (ChewKP03)    */
/* 18-12-2018 2.3  ChewKP     WMS-4538 Add Print function when Close Carton   */
/*                            with Next Task (ChewKP04)                       */
/* 21/05/2019 2.4  YeeKung    WMS-8762 Add Eventlog                           */
/* 10/10/2019 2.5  Chermaine  WMS-10753-Remove EventLog actiontype=3          */
/*                            which exists n rdt.rdt_PTLStation_Confirm (cc01)*/
/* 21/04/2021 2.6  James      WMS-15658 Add ExtendedUpdateSP at step 4        */
/*                            (james02)                                       */
/* 03-08-2021 2.7  YeeKung    WMS-17625 add light=0 allow multiuser go in the */
/*                            station(yeekung01)                              */
/* 15-11-2022 2.8  Ung        WMS-21024 Adjust ExtendedInfoSP at SKU screen   */
/*                            Clear QTY field when ESC to SKU screen          */
/* 16-06-2023 2.9  Ung        WMS-22703 Add MatrixSP Method param             */
/* 28-03-2024 2.9  NLT013     UWP-17105 Sorting on the QC location            */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PTLStation] (
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
   @tVar          VariableTable, 
   @nRowCount     INT, 
   @nActQTY       INT, 
   @cNewCartonID  NVARCHAR( 20), 
   @cShort        NVARCHAR( 10), 
   @cCode2        NVARCHAR( 30),

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
   @nTaskQTY      INT, -- (ChewKP02) 

   @cExtendedStationValSP  NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cTerminateLightSP      NVARCHAR( 20), -- (ChewKP02) 
   --@cDefaultCartonIDSP    NVARCHAR( 20),
   @cAllowSkipTask         NVARCHAR( 1),
   @cDecodeLabelNo         NVARCHAR( 20),
   @cLight                 NVARCHAR( 1),
   @cExtendedInfo          NVARCHAR( 20),
   @cDecodeIDSP            NVARCHAR( 20),
   @cDefaultDeviceID       NVARCHAR( 20), -- (james01)
   @nDefaultSKU            INT, -- (ChewKP03) 
   @nDefaultQty            INT, -- (ChewKP03) 

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
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 9), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @cStation1   = V_String1,
   @cStation2   = V_String2,
   @cStation3   = V_String3,
   @cStation4   = V_String4,
   @cStation5   = V_String5, 
   @cMethod     = V_String6,
   @cScanID     = V_String7,
   @cCartonID   = V_String8,
   @nCartonQTY  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @nNextPage   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 5), 0) = 1 THEN LEFT( V_String10, 5) ELSE 0 END,
   @cOption     = V_String11,

   @cExtendedStationValSP  = V_String20,
   @cExtendedValidateSP    = V_String21,
   @cExtendedUpdateSP      = V_String22,
   @cExtendedInfoSP        = V_String23,
   --@cDefaultCartonIDSP     = V_String24,
   @cAllowSkipTask         = V_String25,
   @cDecodeLabelNo         = V_String26,
   @cLight                 = V_String27,
   @cExtendedInfo          = V_String28,
   @cDecodeIDSP            = V_String29,
   @cTerminateLightSP      = V_String30,

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

IF @nFunc = 805  -- PTL Station
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Cart
   IF @nStep = 1 GOTO Step_1   -- Scn = 4480. PTLStation, Method
   IF @nStep = 2 GOTO Step_2   -- Scn = 4490~4499 Dynamic assign
   IF @nStep = 3 GOTO Step_3   -- Scn = 4482. ScanID, SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 4483. Matrix
   IF @nStep = 5 GOTO Step_5   -- Scn = 4484. Confirm all tasks?
   IF @nStep = 6 GOTO Step_6   -- Scn = 4485. Close carton, QTY
   IF @nStep = 7 GOTO Step_7   -- Scn = 4486. New carton
   IF @nStep = 8 GOTO Step_8   -- Scn = 4487. Unassign cart?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 805. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cAllowSkipTask = rdt.rdtGetConfig( @nFunc, 'AllowSkipTask', @cStorerKey)
   SET @cDecodeIDSP = rdt.rdtGetConfig( @nFunc, 'DecodeIDSP', @cStorerKey)
   IF @cDecodeIDSP = '0'
      SET @cDecodeIDSP = ''
   SET @cDecodeLabelNo = rdt.rdtGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
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

   -- (james01)
   SET @cDefaultDeviceID = rdt.RDTGetConfig( @nFunc, 'DefaultDeviceID', @cStorerKey)
             
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

   -- Init screen
   SET @cOutField01 = CASE WHEN @cDefaultDeviceID = '1' AND @cDeviceID <> '' THEN 
                      @cDeviceID ELSE '' END -- Cart id  (james01)
   SET @cOutField02 = '' -- Pickzone
   SET @cOutField03 = '' -- Method

   -- Set the entry point
   SET @nScn = 4480
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4480.
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
        SET @nErrNo = 96001
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
         SET @nErrNo = 96002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationScanned
         EXEC rdt.rdtSetFocusField @nMobile, @i
         GOTO Quit
      END

      -- Not use light, only allow 1 station (due to matrix looks same across stations, operator might put to wrong station)
      IF @cLight = '0' AND ((SELECT COUNT(1) FROM @tStation WHERE Station <> '') > 1)
      BEGIN
         SET @nErrNo = 96003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NolightUse1PTL
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
                     SET @nErrNo = 96004
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStation
                  END
                  
                  IF @nErrNo = 0
                  BEGIN
                     --(yeekung02)
                     IF @cLight=0
                     BEGIN
                        -- Check station in use                  
                        IF EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) 
                           WHERE Mobile <> @nMobile
                              AND Func = @nFunc 
                              AND @cInField IN (V_String1, V_String2, V_String3, V_String4, V_String5)
                              AND deviceid<>'')
                        BEGIN
                           SET @nErrNo = 96035
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationInUse
                        END
                     END
                     ELSE
                     BEGIN
                        -- Check station in use                  
                        IF EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) 
                           WHERE Mobile <> @nMobile
                              AND Func = @nFunc 
                              AND @cInField IN (V_String1, V_String2, V_String3, V_String4, V_String5))
                        BEGIN
                           SET @nErrNo = 96030
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationInUse
                        END
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
         SET @nErrNo = 96005
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
         SET @nErrNo = 96006
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 96007
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Assign SP
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END
      SET @cOutField06 = @cMethod

      -- Dynamic assign
      EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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
Step 2. Scn = 4490~4499. Dynamic assign
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, ' + 
               ' @cCartonID, @nActQTY, @cNewCartonID, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cStation1  NVARCHAR( 10), ' +
               ' @cStation2  NVARCHAR( 10), ' +
               ' @cStation3  NVARCHAR( 10), ' +
               ' @cStation4  NVARCHAR( 10), ' +
               ' @cStation5  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cScanID    NVARCHAR( 20), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cCartonID    NVARCHAR( 20), ' +
               ' @nActQTY    INT,           ' +
               ' @cNewCartonID NVARCHAR( 20), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, 
               @cCartonID, @nActQTY, @cNewCartonID, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get method info
      SET @cShort = ''
      SET @cCode2 = ''
      SELECT @cShort = Short,
         @cCode2 = ISNULL(code2, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PTLMethod' 
         AND Code = @cMethod 
         AND StorerKey = @cStorerKey
         
      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN ISNULL(@cCode2, '') = 'C' THEN @cOutField01 ELSE '' END --@cScanID
      SET @cOutField02 = '' --@cSuggSKU
      SET @cOutField03 = '' --@cSKU
      SET @cOutField04 = '' --@cSKUDescr
      SET @cOutField05 = '' --@cSKUDescr
      SET @cOutField06 = '' --@nQTY
      SET @cOutField07 = '' --@cExtendedInfo

      -- Enable disable field
      SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'I', @cShort) > 0 THEN '' ELSE 'O' END -- UCC/ID field
      SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'S', @cShort) > 0 THEN '' ELSE 'O' END -- SKU
      SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'Q', @cShort) > 0 THEN '' ELSE 'O' END -- QTY      

      IF @cFieldAttr01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cFieldAttr03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 
      
      -- Go to ID screen
      SET @nScn = 4482
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES 
               ('@cStation1',    @cStation1), 
               ('@cStation2',    @cStation2), 
               ('@cStation3',    @cStation3), 
               ('@cStation4',    @cStation4), 
               ('@cStation5',    @cStation5), 
               ('@cMethod',      @cMethod), 
               ('@cScanID',      @cScanID), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@cCartonID',    @cCartonID), 
               ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
               ('@cNewCartonID', @cNewCartonID), 
               ('@cLight',       @cLight), 
               ('@cOption',      @cOption) 

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = 3
               SET @cOutField07 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0
   BEGIN
      -- Dynamic assign  
      EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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

      -- Get method info
      SET @cShort = ''
      SELECT @cShort = Short
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PTLMethod' 
         AND Code = @cMethod 
         AND StorerKey = @cStorerKey
      
      -- Unassign station
      IF CHARINDEX( 'U', @cShort) > 0 -- U=Unassign
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = '' -- Option
         
         -- Go to unassign station screen
         SET @nScn = 4481 + 6
         SET @nStep = @nStep + 6
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = @cStation1
         SET @cOutfield02 = @cStation2
         SET @cOutfield03 = @cStation3
         SET @cOutfield04 = @cStation4
         SET @cOutfield05 = @cStation5
         SET @cOutfield06 = @cMethod
   
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Station1
   
         -- Go to station screen
         SET @nScn = 4481 - 1
         SET @nStep = @nStep - 1
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4482. ID, SKU screen
   ScanID   (Field01, input)
   SuggSKU  (Field02)
   SKU      (Field03, input)
   Descr 1  (Field04)
   Descr 2  (Field05)
   QTY      (Field06, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cActSKU NVARCHAR(30)
      DECLARE @cActQTY NVARCHAR(5)

      -- Screen mapping
      SET @cScanID = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cActSKU = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cActQTY = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END

      --SET @cScanID = 'M028'
      --SET @cActSKU = '' 
      
      -- UCC/ID field enable
      IF @cFieldAttr01 = ''
      BEGIN
         IF @cScanID = ''
         BEGIN
            SET @nErrNo = 96029
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UCC/ID
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
            GOTO Quit
         END
         
         -- Decode ID
         IF @cDecodeIDSP <> ''
         BEGIN
            -- (ChewKP03) 
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeIDSP AND type = 'P')
            BEGIN
              SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeIDSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cScanID OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nDefaultSKU OUTPUT, @nDefaultQty OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cFacility    NVARCHAR( 5),    ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cScanID      NVARCHAR( 20)  OUTPUT, ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY         INT            OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT, ' +
                  ' @nDefaultSKU  INT  OUTPUT,'  + 
                  ' @nDefaultQty  INT  OUTPUT'  
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cScanID OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT , @nDefaultSKU OUTPUT, @nDefaultQty OUTPUT
   
   
               IF @nErrNo <> 0
                  GOTO Quit
                
               IF @nDefaultSKU = 1 AND @cFieldAttr03 = ''
               BEGIN
                  SET @cActSKU = @cSKU 
               END
               
               IF @nDefaultQty = 1 AND @cFieldAttr06 = ''
               BEGIN
                  SET @cActQTY = @nQTY 
               END
            END
         END
         
         SET @cOutField01 = @cScanID
      END

      -- SKU field enable
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
   		IF @cActSKU = ''
         BEGIN
            SET @nErrNo = 96008
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
            GOTO Step_3_Quit
         END
   
         IF @cDecodeLabelNo <> ''
         BEGIN
            DECLARE
               @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
               @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
               @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
               @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
               @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)
   
            SET @c_oFieled01 = @cSKU
   
            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cActSKU
               ,@c_Storerkey  = @cStorerKey
               ,@c_ReceiptKey = ''
               ,@c_POKey      = ''
               ,@c_LangCode   = @cLangCode
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
               ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
               ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
               ,@b_Success    = @bSuccess    OUTPUT
               ,@n_ErrNo      = @nErrNo      OUTPUT
               ,@c_ErrMsg     = @cErrMsg     OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
   
            SET @cActSKU = @c_oFieled01
         END
   
         -- Get SKU/UPC
         DECLARE @nSKUCnt INT
         DECLARE @cSKUCode NVARCHAR(20)
         SET @nSKUCnt = 0
   
         EXEC RDT.rdt_GetSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cActSKU
            ,@nSKUCnt     = @nSKUCnt   OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT
   
         -- Check SKU valid
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 96009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            SET @cOutField04 = ''
            GOTO Quit
         END
   
         IF @nSKUCnt = 1
            EXEC rdt.rdt_GetSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU   OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT
   
         -- Check barcode return multi SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 96010
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            SET @cOutField04 = ''
            GOTO Quit
         END
         SET @cSKU = @cActSKU
         SET @cOutField03 = @cActSKU
      END
      
      -- QTY field enable
      IF @cFieldAttr06 = ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cActQTY, 1) = 0
         BEGIN
            SET @nErrNo = 96011
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
            SET @cOutField06 = ''
            GOTO Step_3_Quit
         END
         SET @nQTY = CAST( @cActQTY AS INT)
      END
      
      -- Get next task
      EXEC rdt.rdt_PTLStation_CreateTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'ID'
         ,@cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID   OUTPUT
         ,'' -- @cCartonID
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
         ,@cSKU      OUTPUT
         ,@cSKUDescr OUTPUT
         ,@nQTY      OUTPUT

      IF @nErrNo <> 0 AND -- Means No More Task!
         @nErrNo <> -1    -- Remain in current screen
         GOTO Step_3_Fail

      SET @cOutField01 = @cScanID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = CAST( @nQTY AS NVARCHAR(5))

      -- Remain in current screen
      IF @nErrNo = -1
         GOTO Quit
      
      -- Draw matrix (and light up)
      SET @nNextPage = 0
      EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
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

      -- Enable field
      SET @cFieldAttr01 = '' -- ID/UCC
      SET @cFieldAttr03 = '' -- SKU
      SET @cFieldAttr06 = '' -- QTY
               
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
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- ID/UCC
      SET @cFieldAttr03 = '' -- SKU
      SET @cFieldAttr06 = '' -- QTY
      
      -- Dynamic assign  
      EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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
  
      SET @nStep = @nStep - 1  
   END

   Step_3_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES 
               ('@cStation1',    @cStation1), 
               ('@cStation2',    @cStation2), 
               ('@cStation3',    @cStation3), 
               ('@cStation4',    @cStation4), 
               ('@cStation5',    @cStation5), 
               ('@cMethod',      @cMethod), 
               ('@cScanID',      @cScanID), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@cCartonID',    @cCartonID), 
               ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
               ('@cNewCartonID', @cNewCartonID), 
               ('@cLight',       @cLight), 
               ('@cOption',      @cOption) 

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            -- IF @nErrNo <> 0
            --    GOTO Quit
               
            IF @nStep = 3
               SET @cOutField07 = @cExtendedInfo
            IF @nStep = 4
               SET @cOutField12 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField03 = '' -- SKU
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 4483. Maxtrix screen
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
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      

      -- Screen mapping
      SET @cOption = @cInField11

      -- Option
      IF @cOption <> ''
      BEGIN
         -- Check option valid
         IF @cOption <> '1' AND @cOption <> '9'
         BEGIN
            SET @nErrNo = 96012
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Quit
         END

         -- Use light
         IF @cLight = '1'
         BEGIN
            -- Short not allow
            IF @cOption = '9'
            BEGIN
               SET @nErrNo = 96013
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UseLight2Short
               GOTO Quit
            END

            -- Disable QTY field
            SET @cFieldAttr03 = 'O' -- QTY
         END

         -- Prepare next screen var
         SET @cOutField01 = '' -- CartonID
         SET @cOutField02 = '' -- LOC
         SET @cOutField03 = '' -- QTY

         -- Default cursor on CartonID or LOC
         IF EXISTS( SELECT 1 
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'PTLMethod' 
               AND Code = @cMethod 
               AND StorerKey = @cStorerKey
               AND CHARINDEX( 'L', Short) > 0)
            EXEC rdt.rdtSetFocusField @nMobile, 2 --LOC
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 1 --CartonID
         
         -- Go to close carton screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'' -- @cLight. Not re-light up
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
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

      -- Go to confirm all tasks (for non-light)
      IF @cLight = '0'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option
         
         -- Go to confirm all task screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO Quit
      END

      -- Check pick completed (light)
      IF @cLight = '1'
      BEGIN
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLStationLog L WITH (NOLOCK)
               JOIN PTL.PTLTran PTL WITH (NOLOCK) ON (L.RowRef = PTL.GroupKey AND PTL.Func = @nFunc)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND LightUp = '1')
         BEGIN
            SET @nErrNo = 96014
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Put NotFinish
            GOTO Quit
         END

         SET @i = 1
         WHILE @i <= 5 -- (ChewKP01)
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
        
         -- Get method info
         SET @cShort = ''
         SELECT @cShort = Short
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'PTLMethod' 
            AND Code = @cMethod 
            AND StorerKey = @cStorerKey
            
         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'I', @cShort) > 0 THEN '' ELSE 'O' END -- UCC/ID field
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'S', @cShort) > 0 THEN '' ELSE 'O' END -- SKU
         SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'Q', @cShort) > 0 THEN '' ELSE 'O' END -- QTY   
         
         IF @cFieldAttr01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 
   
         -- To Check on Retain ID next screen -- (ChewKP02) 
         EXEC rdt.rdt_PTLStation_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENTTASK'
         ,@cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
         ,@cCartonID
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
         ,@nTaskQTY OUTPUT
         
         IF @nErrNo <> 0 
         BEGIN 
            IF @cFieldAttr01 = '' AND @cFieldAttr03 = '' 
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cScanID
               SET @cOutField02 = '' -- @cSKU
               SET @cOutField03 = '' -- @cSKU
               SET @cOutField04 = '' -- @cSKUDescr
               SET @cOutField05 = '' -- @cSKUDescr
               SET @cOutField06 = '' -- @nQTY 
               SET @cOutField07 = '' -- @cExtendedInfo

               EXEC rdt.rdtSetFocusField @nMobile, 3
            END
            ELSE 
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '' -- @cScanID -- (ChewKP02) 
               SET @cOutField02 = '' -- @cSKU
               SET @cOutField03 = '' -- @cSKU
               SET @cOutField04 = '' -- @cSKUDescr
               SET @cOutField05 = '' -- @cSKUDescr
               SET @cOutField06 = '' -- @nQTY 
               SET @cOutField07 = '' -- @cExtendedInfo
            END
            
         END
         ELSE
         BEGIN
            
            -- Prepare next screen var
            SET @cOutField01 = '' -- @cScanID -- (ChewKP02) 
            SET @cOutField02 = '' -- @cSKU
            SET @cOutField03 = '' -- @cSKU
            SET @cOutField04 = '' -- @cSKUDescr
            SET @cOutField05 = '' -- @cSKUDescr
            SET @cOutField06 = '' -- @nQTY 
            SET @cOutField07 = '' -- @cExtendedInfo
            
         END

         -- Go to UCC/ID screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, ' + 
               ' @cCartonID, @nActQTY, @cNewCartonID, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cStation1  NVARCHAR( 10), ' +
               ' @cStation2  NVARCHAR( 10), ' +
               ' @cStation3  NVARCHAR( 10), ' +
               ' @cStation4  NVARCHAR( 10), ' +
               ' @cStation5  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cScanID    NVARCHAR( 20), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cCartonID    NVARCHAR( 20), ' +
               ' @nActQTY    INT,           ' +
               ' @cNewCartonID NVARCHAR( 20), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, 
               @cCartonID, @nActQTY, @cNewCartonID, @cLight, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

   IF @nInputKey = 0
   BEGIN
      -- Draw matrix (and light up)
      EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,'' -- @cLight. Not re-light up
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
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
         DECLARE @tPos TABLE
         (
            Seq       INT IDENTITY(1,1) NOT NULL,
            IPAddress NVARCHAR(40),
            Position  NVARCHAR(5)
         )

         -- Populate light position
         INSERT INTO @tPos (IPAddress, Position)
         SELECT DISTINCT IPAddress, DevicePosition
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DeviceType = 'STATION'
            AND DeviceID <> ''

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLStation -- For rollback or commit only our own transaction

         DECLARE @nPTLKey BIGINT
         DECLARE @curPTLTran CURSOR
         SET @curPTLTran = CURSOR FOR
            SELECT PTLKey
            FROM PTL.PTLTran T WITH (NOLOCK)
               JOIN @tPos P ON (T.IPAddress = P.IPAddress AND T.DevicePosition = P.Position)
            WHERE DropID = @cScanID
               AND SKU = @cSKU
               AND Status = '1' -- Due to light on, set PTLTran.Status = 1
         OPEN @curPTLTran
         FETCH NEXT FROM @curPTLTran INTO @nPTLKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update light position QTY
            UPDATE PTL.PTLTran SET
               Status = '0'
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdt_PTLStation -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
            FETCH NEXT FROM @curPTLTran INTO @nPTLKey
         END
         
         COMMIT TRAN rdt_PTLStation -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         SET @i = 1
         WHILE @i <= 5 -- (ChewKP01) 
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

      -- Get method info
      SET @cShort = ''
      SELECT @cShort = Short,
         @cCode2 = ISNULL(code2, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PTLMethod' 
         AND Code = @cMethod 
         AND StorerKey = @cStorerKey

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN ISNULL(@cCode2, '') = 'C' THEN @cScanID ELSE '' END --@cScanID --@cScanID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = '' -- CAST( @nQTY AS NVARCHAR(5))
      SET @cOutField07 = '' -- ExtendedInfo

      -- Enable disable field
      SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'I', @cShort) > 0 THEN '' ELSE 'O' END -- UCC/ID field
      SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'S', @cShort) > 0 THEN '' ELSE 'O' END -- SKU
      SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'Q', @cShort) > 0 THEN '' ELSE 'O' END -- QTY      

      IF @cFieldAttr01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cFieldAttr03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 

      -- Back to UCC/ID Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         INSERT INTO @tVar (Variable, Value) VALUES 
            ('@cStation1',    @cStation1), 
            ('@cStation2',    @cStation2), 
            ('@cStation3',    @cStation3), 
            ('@cStation4',    @cStation4), 
            ('@cStation5',    @cStation5), 
            ('@cMethod',      @cMethod), 
            ('@cScanID',      @cScanID), 
            ('@cSKU',         @cSKU), 
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
            ('@cCartonID',    @cCartonID), 
            ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
            ('@cNewCartonID', @cNewCartonID), 
            ('@cLight',       @cLight), 
            ('@cOption',      @cOption) 

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tVar           VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
            
         IF @nStep = 3
            SET @cOutField07 = @cExtendedInfo
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 5. Scn = 4134. Confirm all tasks?
   Confirm all tasks?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      --SET @cOption = '1' 

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 96032
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 96033
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Confirm (for non-light)
         IF @cLight = '0'
         BEGIN
            EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'ID'
               ,@cStation1
               ,@cStation2
               ,@cStation3
               ,@cStation4
               ,@cStation5
               ,@cMethod
               ,@cScanID
               ,@cSKU
               ,@nQTY
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Get method info
            SET @cShort = ''
            SELECT @cShort = Short
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'PTLMethod' 
               AND Code = @cMethod 
               AND StorerKey = @cStorerKey
            
            -- Enable disable field
            SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'I', @cShort) > 0 THEN '' ELSE 'O' END -- UCC/ID field
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'S', @cShort) > 0 THEN '' ELSE 'O' END -- SKU
            SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'Q', @cShort) > 0 THEN '' ELSE 'O' END -- QTY   
            
            IF @cFieldAttr01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
            IF @cFieldAttr03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
            IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6    
      
            -- To Check on Retain ID next screen -- (ChewKP02) 
            EXEC rdt.rdt_PTLStation_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENTTASK'
            ,@cLight
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cScanID
            ,@cSKU
            ,@cCartonID
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
            ,@nTaskQTY OUTPUT
            
            IF @nErrNo <> 0 
            BEGIN 
               IF @cFieldAttr01 = '' AND @cFieldAttr03 = '' 
               BEGIN
                  -- Prepare next screen var
                  SET @cOutField01 = @cScanID
                  SET @cOutField02 = '' -- @cSKU
                  SET @cOutField03 = '' -- @cSKU
                  SET @cOutField04 = '' -- @cSKUDescr
                  SET @cOutField05 = '' -- @cSKUDescr
                  SET @cOutField06 = '' -- @nQTY 
                  SET @cOutField07 = '' -- @cExtendedInfo

                  EXEC rdt.rdtSetFocusField @nMobile, 3
               END
               ELSE 
               BEGIN
                  SET @cCode2 = ''
                  SELECT @cCode2 = ISNULL(code2, '')
                  FROM CodeLKUP WITH (NOLOCK) 
                  WHERE ListName = 'PTLMethod' 
                     AND Code = @cMethod 
                     AND StorerKey = @cStorerKey

                  -- Prepare next screen var
                  SET @cOutField01 = CASE WHEN ISNULL(@cCode2, '') = 'C' THEN @cScanID ELSE '' END -- @cScanID -- (ChewKP02) 
                  SET @cOutField02 = '' -- @cSKU
                  SET @cOutField03 = '' -- @cSKU
                  SET @cOutField04 = '' -- @cSKUDescr
                  SET @cOutField05 = '' -- @cSKUDescr
                  SET @cOutField06 = '' -- @nQTY 
                  SET @cOutField07 = '' -- @cExtendedInfo
               END
               
            END
            ELSE
            BEGIN
               SET @cCode2 = ''
               SELECT @cCode2 = ISNULL(code2, '')
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'PTLMethod' 
                  AND Code = @cMethod 
                  AND StorerKey = @cStorerKey
               
               -- Prepare next screen var
               SET @cOutField01 = CASE WHEN ISNULL(@cCode2, '') = 'C' THEN @cScanID ELSE '' END -- @cScanID -- (ChewKP02) 
               SET @cOutField02 = '' -- @cSKU
               SET @cOutField03 = '' -- @cSKU
               SET @cOutField04 = '' -- @cSKUDescr
               SET @cOutField05 = '' -- @cSKUDescr
               SET @cOutField06 = '' -- @nQTY 
               SET @cOutField07 = '' -- @cExtendedInfo
            END

            -- Go to UCC/ID screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
            
            GOTO Step_5_Quit
         END
      END
   END

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,'' -- @cLight. Not re-light up
      ,@cStation1
      ,@cStation2
      ,@cStation3
      ,@cStation4
      ,@cStation5
      ,@cMethod
      ,@cScanID
      ,@cSKU
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
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1

Step_5_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         INSERT INTO @tVar (Variable, Value) VALUES 
            ('@cStation1',    @cStation1), 
            ('@cStation2',    @cStation2), 
            ('@cStation3',    @cStation3), 
            ('@cStation4',    @cStation4), 
            ('@cStation5',    @cStation5), 
            ('@cMethod',      @cMethod), 
            ('@cScanID',      @cScanID), 
            ('@cSKU',         @cSKU), 
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
            ('@cCartonID',    @cCartonID), 
            ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
            ('@cNewCartonID', @cNewCartonID), 
            ('@cLight',       @cLight), 
            ('@cOption',      @cOption) 

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tVar           VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
            
         IF @nStep = 3 SET @cOutField07 = @cExtendedInfo
         IF @nStep = 4 SET @cOutField12 = @cExtendedInfo
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 6. Scn = 4135. Old carton screen
   CartonID (field01, input)
   LOC      (field02, input
   QTY      (field03, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --DECLARE @nTaskQTY INT
      DECLARE @cQTY     NVARCHAR(5)

      -- Screen mapping
      SET @cCartonID = @cInField01
      SET @cLOC = @cInField02
      SET @cQTY = CASE WHEN @cFieldAttr03 = 'O' THEN '' ELSE @cInField03 END

      -- Check both blank
      IF @cCartonID = '' AND @cLOC = ''
      BEGIN
         SET @nErrNo = 96015
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/LOC
         GOTO Quit
      END

      -- Check both with value
      IF @cCartonID <> '' AND @cLOC <> ''
      BEGIN
         SET @nErrNo = 96016
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
               AND CartonID = @cCartonID)
         BEGIN
            SET @nErrNo = 96017
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
            SET @cOutField01 = ''
            GOTO Quit
         END
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
            SET @nErrNo = 96018
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Get carton ID, base on LOC
         SELECT @cCartonID = CartonID
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND LOC = @cLOC

         IF @@ROWCOUNT > 1
         BEGIN
            SET @nErrNo = 96019
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCMultiCarton
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END
         
         -- Check LOC on station
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 96020
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC No Carton
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
            SET @cOutField02 = ''
            GOTO Quit
         END
         SET @cOutField02 = @cLOC
      END

      -- Get current task QTY
      EXEC rdt.rdt_PTLStation_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENTCARTON'
         ,@cLight
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
         ,@cCartonID
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
         ,@nTaskQTY OUTPUT
            
      -- Use light
      IF @cLight = '1'
      BEGIN
         -- Check carton no task
         IF @nTaskQTY = 0
         BEGIN
            SET @nErrNo = 96031
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN/LOC NoTask
            GOTO Quit
         END

         SET @nCartonQTY = 0
         
         -- Need to handle lightup already, not yet press, but close carton
      END
      ELSE
      BEGIN
         -- Check carton no task but key-in QTY
         IF @nTaskQTY = 0 AND @cQTY <> ''
         BEGIN
            SET @nErrNo = 96021
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN/LOC NoTask
            GOTO Quit
         END

         -- Check carton have task but not confirm QTY
         IF @nTaskQTY > 0 AND @cQTY = ''
         BEGIN
            SET @nErrNo = 96022
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY
            GOTO Quit
         END

         -- Check QTY valid
         IF rdt.rdtIsValidQTY( @cQTY, 0) = 0 -- Not check zero QTY
         BEGIN
            SET @nErrNo = 96023
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY
            GOTO Quit
         END
         SET @nCartonQTY = CAST( @cQTY AS INT)

         -- Check over pick
         IF @nCartonQTY > @nTaskQTY
         BEGIN
            SET @nErrNo = 96024
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY
            GOTO Quit
         END
      END

      -- Close
      IF @cOption = '1'
      BEGIN
         -- Get next task 
         EXEC rdt.rdt_PTLStation_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTCARTON'
            ,@cLight
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cScanID
            ,@cSKU
            ,@cCartonID
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT

         IF @nErrNo <> 0 AND           -- No more next task
            @nCartonQTY = @nTaskQTY    -- Current task fully packed
         BEGIN
            SET @nErrNo = 0

            -- Confirm
            EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
               ,@cStation1
               ,@cStation2
               ,@cStation3
               ,@cStation4
               ,@cStation5
               ,@cMethod
               ,@cScanID
               ,@cSKU
               ,0  -- @cQTY
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cCartonID
               ,@nCartonQTY
               ,'' -- @cNewCartonID
            IF @nErrNo <> 0
               GOTO Quit
               
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
         END
         ELSE
         BEGIN
            -- (ChewKP04) 
            IF @cLight = '1' 
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
            END
            
            -- Custom carton ID
            SET @cNewCartonID = ''
            EXEC rdt.rdt_PTLStation_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEW', 
               @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNewCartonID OUTPUT 
            
            -- Prepare next screen var
            SET @cOutField01 = @cNewCartonID

            -- Disable field
            IF @cNewCartonID <> ''
               SET @cFieldAttr01 = 'O' -- New carton ID

            -- Go to new carton screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
      END

      -- Short
      IF @cOption = '9'
      BEGIN
         -- Confirm
         EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SHORTCARTON'
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,@cScanID
            ,@cSKU
            ,0  -- @cQTY
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cCartonID
            ,@nCartonQTY
            ,'' -- @cNewCartonID
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,'' -- @cLight. Not re-light up
      ,@cStation1
      ,@cStation2
      ,@cStation3
      ,@cStation4
      ,@cStation5
      ,@cMethod
      ,@cScanID
      ,@cSKU
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

   -- Enable field
   SET @cFieldAttr03 = '' -- QTY

   -- Go to matrix screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         INSERT INTO @tVar (Variable, Value) VALUES 
            ('@cStation1',    @cStation1), 
            ('@cStation2',    @cStation2), 
            ('@cStation3',    @cStation3), 
            ('@cStation4',    @cStation4), 
            ('@cStation5',    @cStation5), 
            ('@cMethod',      @cMethod), 
            ('@cScanID',      @cScanID), 
            ('@cSKU',         @cSKU), 
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
            ('@cCartonID',    @cCartonID), 
            ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
            ('@cNewCartonID', @cNewCartonID), 
            ('@cLight',       @cLight), 
            ('@cOption',      @cOption) 

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tVar           VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
            
         IF @nStep = 3 SET @cOutField07 = @cExtendedInfo 
         IF @nStep = 4 SET @cOutField12 = @cExtendedInfo
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 7. Scn = 4136. New carton screen
   New CartonID   (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewCartonID = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END

      -- Check blank
      IF @cNewCartonID = ''
      BEGIN
         SET @nErrNo = 96025
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need NewCarton
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cNewCartonID) = 0
      BEGIN
         SET @nErrNo = 96034
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check carton on cart
      IF EXISTS( SELECT 1 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5) 
            AND CartonID = @cNewCartonID)
      BEGIN
         SET @nErrNo = 96026
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExistingCarton
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
         ,0  -- @cQTY
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cCartonID
         ,@nCartonQTY
         ,@cNewCartonID
      IF @nErrNo <> 0
         GOTO Quit

      IF @cLight <> '1' 
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
      END
      
      -- Draw matrix (and light up)
      SET @nNextPage = 0
      EXEC rdt.rdt_PTLStation_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
        ,'' -- @cLight. Not re-light up
        ,@cStation1
        ,@cStation2
        ,@cStation3
        ,@cStation4
        ,@cStation5
        ,@cMethod
        ,@cScanID
        ,@cSKU
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

      -- Enable field
      SET @cFieldAttr01 = '' -- Carton ID
      SET @cFieldAttr03 = '' -- QTY

      -- Go to matrix screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLOC = '' THEN @cCartonID ELSE '' END
      SET @cOutField02 = @cLOC
      SET @cOutField03 = CAST( @nCartonQTY AS NVARCHAR(5))

      -- Use light
      IF @cLight = '1'
      BEGIN
         SET @cFieldAttr03 = 'O' -- QTY
         SET @cOutField03 = ''
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID
      END
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY

      SET @cFieldAttr01 = '' -- Carton ID

      -- Go to carton ID screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         INSERT INTO @tVar (Variable, Value) VALUES 
            ('@cStation1',    @cStation1), 
            ('@cStation2',    @cStation2), 
            ('@cStation3',    @cStation3), 
            ('@cStation4',    @cStation4), 
            ('@cStation5',    @cStation5), 
            ('@cMethod',      @cMethod), 
            ('@cScanID',      @cScanID), 
            ('@cSKU',         @cSKU), 
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
            ('@cCartonID',    @cCartonID), 
            ('@nActQTY',      CAST( @nActQTY AS NVARCHAR( 10))), 
            ('@cNewCartonID', @cNewCartonID), 
            ('@cLight',       @cLight), 
            ('@cOption',      @cOption) 

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tVar           VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
            
         IF @nStep = 3 SET @cOutField07 = @cExtendedInfo 
         IF @nStep = 4 SET @cOutField12 = @cExtendedInfo
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 8. Scn = 4137. Unassign cart screen
   Unassign cart?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 96027
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 96028
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Dynamic assign
         EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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

         -- Close station
         EXEC rdt.rdt_PTLStation_Unassign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cStation1
            ,@cStation2
            ,@cStation3
            ,@cStation4
            ,@cStation5
            ,@cMethod
            ,'' -- @cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prep next screen var
         SET @cOutField01 = @cStation1
         SET @cOutField02 = @cStation2
         SET @cOutField03 = @cStation3
         SET @cOutField04 = @cStation4
         SET @cOutField05 = @cStation5
         SET @cOutField06 = @cMethod
   
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Station
   
         -- Go to PTL station screen
         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 7
         
         GOTO Quit
      END
      
      IF @cOption = '9' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cStation1
         SET @cOutField02 = @cStation2
         SET @cOutField03 = @cStation3
         SET @cOutField04 = @cStation4
         SET @cOutField05 = @cStation5
         SET @cOutField06 = @cMethod
   
         -- Go to station screen
         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 7
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PTLStation_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
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
   
      -- Go to assign screen
      SET @nStep = @nStep - 6
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
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,

      V_String1  = @cStation1,
      V_String2  = @cStation2,
      V_String3  = @cStation3,
      V_String4  = @cStation4,
      V_String5  = @cStation5,
      V_String6  = @cMethod,
      V_String7  = @cScanID,
      V_String8  = @cCartonID,
      V_String9  = @nCartonQTY,
      V_String10 = @nNextPage,
      V_String11 = @cOption,

      V_String20 = @cExtendedStationValSP,
      V_String21 = @cExtendedValidateSP,
      V_String22 = @cExtendedUpdateSP,
      V_String23 = @cExtendedInfoSP,
      -- V_String24 = @cDefaultCartonIDSP,
      V_String25 = @cAllowSkipTask,
      V_String26 = @cDecodeLabelNo,
      V_String27 = @cLight,
      V_String28 = @cExtendedInfo,
      V_String29 = @cDecodeIDSP,
      V_String30 = @cTerminateLightSP,

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