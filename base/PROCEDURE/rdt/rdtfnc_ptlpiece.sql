SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PTLPiece                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-04-25 1.0  Ung        SOS368861 Created                               */
/* 2018-02-05 1.1  James      WMS3893-Add DefaultDeviceID (james01)           */
/* 2018-10-24 1.2  James      WMS6781-Add display who locked station (james02)*/
/* 2019-05-21 1.3  YeeKung    WMS-8762  Add RDT Event Log (yeekung01)         */
/* 2019-10-10 1.4  Chermaine  WMS-10753-Remove EventLog actiontype=3 which    */
/*                            exists in rdt.rdt_PTLPiece_Confirm (cc01)       */
/* 2020-01-16 1.5  James      WMS-11427 Add default method by config (james03)*/
/*                            Add extvalid @ step 1                           */
/* 2021-02-22 1.6  YeeKung    WMS-16066 Add Close carton(yeekung01)           */
/* 2022-03-29 1.7  Ung        WMS-19254 Add MultiSKUBarocde                   */
/* 2022-11-22 1.8  Ung        WMS-21112 Revise close carton                   */
/*                            Add custom carton ID                            */
/* 2022-12-15 1.9  Ung        WMS-21056 Allow multi sorter, if not use light  */
/* 2022-11-30 2.0  Ung        WMS-21170 Add DynamicSlot that need carton ID   */
/* 2022-11-01 2.1  JHU151     FCR-650 sorting for inbound                     */
/******************************************************************************/

CREATE   PROC rdt.rdtfnc_PTLPiece (
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
   @i                INT, 
   @nCount           INT,
   @bSuccess         INT,
   @nTranCount       INT,
   @nRowCount        INT, 
   @cSQL             NVARCHAR( MAX),
   @cSQLParam        NVARCHAR( MAX),
   @cOption          NVARCHAR( 1), 
   @cLOC             NVARCHAR( 10),
   @cDefaultDeviceID NVARCHAR( 20),
   @cDefaultMethod   NVARCHAR( 1),
   @tExtValid        VARIABLETABLE,

   @cResult01        NVARCHAR( 20),
   @cResult02        NVARCHAR( 20),
   @cResult03        NVARCHAR( 20),
   @cResult04        NVARCHAR( 20),
   @cResult05        NVARCHAR( 20),
   @cResult06        NVARCHAR( 20),
   @cResult07        NVARCHAR( 20),
   @cResult08        NVARCHAR( 20),
   @cResult09        NVARCHAR( 20),
   @cResult10        NVARCHAR( 20)

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

   @cSKU          NVARCHAR( 20),
   @nFromScn      INT,
   @nAction       INT, --(JHU151)  
   @cStation      NVARCHAR(10),
   @cMethod       NVARCHAR( 1),
   @cLastPos      NVARCHAR( 5),
   @cIPAddress    NVARCHAR( 40), 
   @cPosition     NVARCHAR( 10), 
   @cNewCartonID  NVARCHAR( 20),
   @cDynamicSlot  NVARCHAR( 1),

   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cDecodeSP              NVARCHAR( 20),
   @cLight                 NVARCHAR( 1),
   @cExtendedInfo          NVARCHAR( 20),
   @cMultiSKUBarcode       NVARCHAR( 1),
   @cCustomCartonIDSP      NVARCHAR( 20),
   @cExtendedScreenSP      NVARCHAR( 20), --(JHU151)
   @tExtScnData			   VariableTable, --(JHU151)
   @cUPC                   NVARCHAR( 30), 

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),

   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

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

   @cSKU        = V_SKU,
   @nFromScn    = V_FromScn,

   @cStation         = V_String1,
   @cMethod          = V_String2,
   @cLastPos         = V_String3,
   @cIPAddress       = V_String4,
   @cPosition        = V_String5,
   @cNewCartonID     = V_String6,
   @cDynamicSlot     = V_String7,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cDecodeSP           = V_String23,
   @cLight              = V_String24,
   @cExtendedInfo       = V_String25,
   @cMultiSKUBarcode    = V_String26, 
   @cCustomCartonIDSP   = V_String27, 
   @cExtendedScreenSP   = V_String28,
   @cUPC                = V_String41, 

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

IF @nFunc = 803  -- PTL piece
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Cart
   IF @nStep = 1 GOTO Step_1   -- Scn = 4590. Station, Method
   IF @nStep = 2 GOTO Step_2   -- Scn = 4591. Dynamic assign
   IF @nStep = 3 GOTO Step_3   -- Scn = 4592. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 4593. Unassign cart?
   IF @nStep = 5 GOTO Step_5   -- Scn = 4594. Close Carton
   IF @nStep = 6 GOTO Step_6   -- Scn = 3570. Multi SKU screen  
   IF @nStep = 99 GOTO Step_99 -- Extended Screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 803. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cCustomCartonIDSP = rdt.rdtGetConfig( @nFunc, 'CustomCartonIDSP', @cStorerKey)
   IF @cCustomCartonIDSP = '0'
      SET @cCustomCartonIDSP = ''
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cDefaultDeviceID = rdt.RDTGetConfig( @nFunc, 'DefaultDeviceID', @cStorerKey)
   SET @cDefaultMethod = rdt.RDTGetConfig( @nFunc, 'DefaultMethod', @cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey) 
   
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END

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
   SET @cLastPos = ''
   SET @cDynamicSlot = ''

   -- Init screen
   SET @cOutField01 = CASE WHEN @cDefaultDeviceID = '1' AND @cDeviceID <> '' THEN 
                      @cDeviceID ELSE '' END -- Station  (james01)
   SET @cOutField02 = CASE WHEN @cDefaultMethod <> '' THEN @cDefaultMethod ELSE '' END -- Method  (james03)

   -- Set the entry point
   SET @nScn = 4590
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4590.
   Station  (Field01, input)
   Method   (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cStation = @cInField01
      SET @cMethod = @cInField02

      -- Validate blank
      IF @cStation = ''
      BEGIN
         SET @nErrNo = 99501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need station
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check station valid
      IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceType = 'STATION' AND DeviceID <> '' AND DeviceID = @cStation)
      BEGIN
         SET @nErrNo = 99502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStation
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check station in use                  
      IF @cLight = '1'
      BEGIN
         -- Get station info
         DECLARE @cUserWhoLockedStation NVARCHAR( 20) = ''
         SELECT @cUserWhoLockedStation = UserName 
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile <> @nMobile
            AND Func = @nFunc 
            AND @cStation = V_String1

         -- Station in use by other
         IF @cUserWhoLockedStation <> ''
         BEGIN
            DECLARE @cMsg1 NVARCHAR(20), @cMsg2 NVARCHAR(20)
            SET @cMsg1 = rdt.rdtgetmessage( 99503, @cLangCode, 'DSP') --STATION IN USE
            SET @cMsg2 = rdt.rdtgetmessage( 99512, @cLangCode, 'DSP') --LOCKED BY:

            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg1, '', @cMsg2, @cUserWhoLockedStation

            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      SET @cOutField01 = @cStation
                  
      -- Check blank
      IF @cMethod = ''
      BEGIN
         SET @nErrNo = 99504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need method
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Get method info
      DECLARE @cMethodSP SYSNAME
      SET @cMethodSP = ''
      SELECT @cMethodSP = ISNULL( UDF01, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'PTLPiece'
         AND Code = @cMethod
         AND StorerKey = @cStorerKey

      -- Check method
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 99505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid method
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 99506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      SET @cOutField02 = @cMethod

      --james03
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption, ' +
               ' @tExtValid, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' + 
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cStation     NVARCHAR( 10), ' +
               '@cMethod      NVARCHAR( 1),  ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLastPos     NVARCHAR( 10), ' +
               '@cOption      NVARCHAR( 1),  ' +
               '@tExtValid    VariableTable READONLY, ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
               @tExtValid, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Dynamic assign
      EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, 'POPULATE-IN',
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
Step 2. Scn = 4591. Dynamic assign
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, 'CHECK',
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

      SET @cLastPos = ''

      -- Prepare next screen var
      SET @cOutField01 = '' --Result01
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' --Result10
      SET @cOutField11 = '' --@cSKU
      SET @cOutField12 = '' --@cLastPos

      -- Go to matrix, SKU screen
      SET @nScn = 4592
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Dynamic assign  
      EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, 'POPULATE-OUT',  
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
      DECLARE @cShort NVARCHAR(10)
      SET @cShort = ''
      SELECT @cShort = Short
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PTLPiece' 
         AND Code = @cMethod 
         AND StorerKey = @cStorerKey
      
      -- Unassign station
      IF CHARINDEX( 'U', @cShort) > 0 -- U=Unassign
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = '' -- Option
         
         -- Go to unassign station screen
         SET @nScn = 4591 + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = @cStation
         SET @cOutfield02 = @cMethod
   
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Station1
   
         -- Go to cart screen
         SET @nScn = 4591 - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @cExtendedScreenSP = 'rdt_803ExtScn01'
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4592. Matrix, SKU screen
   Result01 (Field01)
   Result02 (Field02)
   Result03 (Field03)
   Result04 (Field04)
   Result05 (Field05)
   Result06 (Field06)
   Result07 (Field07)
   Result08 (Field08)
   Result09 (Field09)
   Result10 (Field10)
   SKU      (Field11, input)
   LAST     (Field12)
   OPTION   (Field13, input) 
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)

      -- Screen mapping
      SET @cBarcode = @cInField11 -- SKU
      SET @cUPC = LEFT( @cInField11, 30)
      SET @cOption = @cInField13

      IF @cOption = '9' -- Close
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- LOC
         SET @cOutField02 = ''

         IF @cCustomCartonIDSP <> ''
            SET @cFieldAttr02 = 'O'

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC

         -- Go to close carton ID screen
         SET @nStep = @nStep + 2
         SET @nScn = @nScn + 2
         
         GOTO Quit
      END

      -- Check blank
		IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 99507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
         GOTO Step_3_Fail
      END
   
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUPC    = @cUPC     OUTPUT, 
               @nErrNo  = @nErrNo   OUTPUT, 
               @cErrMsg = @cErrMsg  OUTPUT
         END
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cBarcode, ' +
               ' @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cStation     NVARCHAR( 10), ' +
               ' @cMethod      NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cUPC         NVARCHAR( 30)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cBarcode, 
               @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Get SKU count
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 99508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_3_Fail
      END

      IF @nSKUCnt = 1
         EXEC rdt.rdt_GetSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC      OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            EXEC rdt.rdt_PTLPiece_MultiSKU @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nScn = 3570
               SET @nStep = @nStep + 3
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE       
         BEGIN
            SET @nErrNo = 99509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_3_Fail
         END
      END
      SET @cSKU = @cUPC

      -- Confirm task
      EXEC rdt.rdt_PTLPiece_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight
         ,@cStation
         ,@cMethod
         ,@cSKU
         ,@cIPAddress OUTPUT
         ,@cPosition  OUTPUT
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
      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -2 -- Assign carton ID
         BEGIN
            SET @cDynamicSlot = '1'
            
            -- Get LOC info
            SELECT @cLOC = LOC
            FROM DeviceProfile WITH (NOLOCK) 
            WHERE DeviceType = 'STATION'
               AND DeviceID = @cStation
               AND DevicePosition = @cPosition
            
            -- Prepare next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = ''

            SET @cFieldAttr01 = 'O'
            IF @cCustomCartonIDSP <> ''
               SET @cFieldAttr02 = 'O'
               
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- New carton ID

            -- Go to close carton ID screen
            SET @nStep = @nStep + 2
            SET @nScn = @nScn + 2
            
            GOTO Quit
         END
         
         GOTO Step_3_Fail
      END

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
      SET @cOutField11 = '' -- SKU
      SET @cOutField12 = @cLastPos
        
      -- Save last position
      SET @cLastPos = ''
      SELECT @cLastPos = LEFT( LogicalName, 5)
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'STATION'
         AND DeviceID = @cStation
         AND DeviceID <> ''
         AND IPAddress = @cIPAddress
         AND DevicePosition = @cPosition

      -- Remain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' + 
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cStation     NVARCHAR( 10), ' +
               '@cMethod      NVARCHAR( 1),  ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLastPos     NVARCHAR( 10), ' +
               '@cOption      NVARCHAR( 1),  ' +
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Dynamic assign  
      EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, 'POPULATE-IN',  
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
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Blank the matrix 
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = '' -- SKU
/*
      -- Off all lights
      IF @cLight = '1'
      BEGIN
         -- Clear light
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cStation
            ,'STATION'
            ,@bSuccess    OUTPUT
            ,@nErrNo      --OUTPUT -- Prevent PTL overwrite RDT error
            ,@cErrMsg     --OUTPUT -- Prevent PTL overwrite RDT error
         IF @nErrNo <> 0
            GOTO Quit
      END
*/
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 4593. Unassign cart screen
   Unassign cart?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 99510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 99511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      --james03
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption, ' +
               ' @tExtValid, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' + 
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cStation     NVARCHAR( 10), ' +
               '@cMethod      NVARCHAR( 1),  ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLastPos     NVARCHAR( 10), ' +
               '@cOption      NVARCHAR( 1),  ' +
               '@tExtValid    VariableTable READONLY, ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
               @tExtValid, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      IF @cOption = '1' -- Yes
      BEGIN
         -- Dynamic assign
         EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cStation, @cMethod, 'POPULATE-OUT',
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
         EXEC rdt.rdt_PTLPiece_Unassign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cStation
            ,@cMethod
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prep next screen var
         SET @cOutField01 = @cStation
         SET @cOutField02 = @cMethod
   
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Station
   
         -- Go to station screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
         
         GOTO Quit
      END
      
      IF @cOption = '9' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cStation
         SET @cOutField02 = @cMethod
   
         -- Go to station screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, 'POPULATE-IN',
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
      SET @nStep = @nStep - 2
   END
END
GOTO QUIT


/********************************************************************************
Step 5. Scn = 4594 New Carton ID screen
   LOC            (field01, input)
   NEW CARTON ID  (field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC         = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cNewCartonID = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END

      -- Validate blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 99513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      
      -- Get assign info
      DECLARE @cClosePosition NVARCHAR( 10)
      SELECT @cClosePosition = DevicePosition
      FROM DeviceProfile WITH (NOLOCK) 
      WHERE DeviceType = 'STATION'
         AND DeviceID = @cStation
         AND LOC = @cLOC
      
      SET @nRowCount = @@ROWCOUNT
      
      -- Check LOC valid
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 99514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      --- Check multi LOC
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 99515
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Multi POS
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      --- Check LOC assigned
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND LOC = @cLOC)
      BEGIN
         SET @nErrNo = 99516
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Not Assign
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      SET @cOutField01 = @cLOC

      -- Custom carton ID
      IF @cCustomCartonIDSP <> ''
      BEGIN
         -- Custom carton ID
         SET @cNewCartonID = ''
         EXEC rdt.rdt_PTLPiece_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cStation, 
            @cClosePosition, 
            @cMethod, 
            @cSKU, 
            @nErrNo        OUTPUT, 
            @cErrMsg       OUTPUT, 
            @cNewCartonID  OUTPUT 
         IF @nErrNo <> 0
            GOTO Quit
      END
         
      -- Validate blank
      IF @cNewCartonID = ''
      BEGIN
         SET @nErrNo = 99517
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Carton ID
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cNewCartonID) = 0
      BEGIN
         SET @nErrNo = 99518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- NewCartonID
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get assign info
      DECLARE @cCartonID NVARCHAR( 20)
      SELECT @cCartonID = CartonID 
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation
         AND Position = @cClosePosition

      -- Check same carton ID
      IF @cCartonID = @cNewCartonID
      BEGIN
         SET @nErrNo = 99519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same carton ID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- NewCartonID
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check carton on cart
      IF EXISTS( SELECT 1 
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
         WHERE Station = @cStation
            AND CartonID = @cNewCartonID)
      BEGIN
         SET @nErrNo = 99520
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExistingCarton
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- CartonID
         SET @cOutField02 = ''
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PTLPiece -- For rollback or commit only our own transaction
      
      -- Close carton
      EXEC rdt.rdt_PTLPiece_CloseCarton @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cLight
         ,@cStation
         ,@cClosePosition
         ,@cLOC
         ,@cCartonID
         ,@cNewCartonID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PTLPiece
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END
      
      -- Confirm task
      IF @cDynamicSlot = '1'
      BEGIN
         EXEC rdt.rdt_PTLPiece_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cLight
            ,@cStation
            ,@cMethod
            ,@cSKU
            ,@cIPAddress OUTPUT
            ,@cPosition  OUTPUT
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
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_PTLPiece
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END         
      END
      
      COMMIT TRAN rdtfnc_PTLPiece
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      -- Save last position
      SET @cLastPos = ''
      SELECT @cLastPos = LEFT( LogicalName, 5)
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'STATION'
         AND DeviceID = @cStation
         AND LOC = @cLOC

      IF @cDynamicSlot = '1'
      BEGIN 
         SET @cDynamicSlot = ''

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
         SET @cOutField11 = '' -- SKU
         SET @cOutField12 = @cLastPos
         SET @cOutField13 = '' --Option         
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' --Result01
         SET @cOutField02 = '' 
         SET @cOutField03 = '' 
         SET @cOutField04 = '' 
         SET @cOutField05 = '' 
         SET @cOutField06 = '' 
         SET @cOutField07 = '' 
         SET @cOutField08 = '' 
         SET @cOutField09 = '' 
         SET @cOutField10 = '' --Result10
         SET @cOutField11 = '' -- SKU
         SET @cOutField12 = @cLastPos
         SET @cOutField13 = '' --Option
      END
      
      SET @cFieldAttr01 = '' -- LOC
      SET @cFieldAttr02 = '' -- New carton ID
      
      -- Go to matrix, SKU screen
      SET @nScn = @nScn - 2
      SET @nStep= @nStep - 2
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cDynamicSlot = ''
      
      -- Prepare next screen var
      SET @cOutField01 = '' --Result01
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' --Result10
      SET @cOutField11 = '' -- SKU
      SET @cOutField12 = @cLastPos
      SET @cOutField13 = '' --Option

      SET @cFieldAttr01 = '' -- LOC
      SET @cFieldAttr02 = '' -- New carton ID

      -- Go to matrix, SKU screen
      SET @nScn = @nScn - 2
      SET @nStep= @nStep - 2
   END
END
GOTO QUIT


/********************************************************************************
Step 10. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2   (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_PTLPiece_MultiSKU @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cUPC     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
      SET @cSKU = @cUPC
      
      -- Prepare SKU screen var
      SET @cOutField01 = '' --@cResult01
      SET @cOutField02 = '' --@cResult02
      SET @cOutField03 = '' --@cResult03
      SET @cOutField04 = '' --@cResult04
      SET @cOutField05 = '' --@cResult05
      SET @cOutField06 = '' --@cResult06
      SET @cOutField07 = '' --@cResult07
      SET @cOutField08 = '' --@cResult08
      SET @cOutField09 = '' --@cResult09
      SET @cOutField10 = '' --@cResult10
      SET @cOutField11 = @cSKU -- SKU
      SET @cOutField12 = @cLastPos

      -- Go to next screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare SKU screen var
      SET @cOutField01 = '' --@cResult01
      SET @cOutField02 = '' --@cResult02
      SET @cOutField03 = '' --@cResult03
      SET @cOutField04 = '' --@cResult04
      SET @cOutField05 = '' --@cResult05
      SET @cOutField06 = '' --@cResult06
      SET @cOutField07 = '' --@cResult07
      SET @cOutField08 = '' --@cResult08
      SET @cOutField09 = '' --@cResult09
      SET @cOutField10 = '' --@cResult10
      SET @cOutField11 = '' -- SKU
      SET @cOutField12 = @cLastPos

      -- Go to next screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 3
   END
END
GOTO Quit



Step_99:
BEGIN
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScreenSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail

         IF @cExtendedScreenSP = 'rdt_803ExtScn01'
         BEGIN
            SET @cIPAddress = @cUDF01
            SET @cPosition = @cUDF02
            SET @cLight = @cUDF03
            SET @cUPC = @cUDF04
            SET @cLastPos = @cUDF05
            SET @cSKU = @cUDF06
         END

         GOTO Quit
      END
   END -- Ext scn sp <> ''

   Step_99_Fail:
      GOTO Quit
END -- End step99


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

      V_SKU      = @cSKU,
      V_FromScn  = @nFromScn,

      V_String1  = @cStation,
      V_String2  = @cMethod,
      V_String3  = @cLastPos,
      V_String4  = @cIPAddress,
      V_String5  = @cPosition,
      V_String6  = @cNewCartonID,
      V_String7  = @cDynamicSlot, 
   
      V_String20 = @cExtendedValidateSP,
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @cExtendedInfoSP,
      V_String23 = @cDecodeSP,
      V_String24 = @cLight,
      V_String25 = @cExtendedInfo,
      V_String26 = @cMultiSKUBarcode, 
      V_String27 = @cCustomCartonIDSP, 
      V_String28 = @cExtendedScreenSP,
      V_String41 = @cUPC, 

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