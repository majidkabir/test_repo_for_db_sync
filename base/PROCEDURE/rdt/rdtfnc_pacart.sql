SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PACart                                             */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2015-10-06 1.0  Ung        SOS350419 Created                               */
/* 2016-12-15 1.1  Ung        WMS-752 Add ExtendedPutawaySP                   */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-08-07 1.3  James      WMS-5639 Add confirm sku (james01)              */
/* 2019-01-25 1.4  James      WMS-5639 Add ExtendedInfo @ scn 4 (james01)     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PACart] (
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
   @bSuccess   INT,
   @cSQL       NVARCHAR( MAX),
   @cSQLParam  NVARCHAR( MAX),

   @cResult01  NVARCHAR( 20),
   @cResult02  NVARCHAR( 20),
   @cResult03  NVARCHAR( 20),
   @cResult04  NVARCHAR( 20),
   @cResult05  NVARCHAR( 20)

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
   @cSKU          NVARCHAR(20),
   @cSKUDescr     NVARCHAR(60),
   @nQTY          INT,

   @cCartID       NVARCHAR(10),
   @cCol          NVARCHAR(5),
   @cRow          NVARCHAR(5),
   @cToteID       NVARCHAR(20),
   @cPosition     NVARCHAR(10),
   @nTotalTote    INT,
   @nTotalQTY     INT,
   @nTotalActQTY  INT,

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedPutawaySP  NVARCHAR(20), 
   @cPACartConfirmSKU   NVARCHAR(1), 

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

DECLARE    @tVar                VariableTable
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

   @cLOC        = V_LOC,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 9), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @cCartID     = V_String1,
   @cCol        = V_String2,
   @cRow        = V_String3,
   @cToteID     = V_String4,
   @cPosition   = V_String5,
   @nTotalTote  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @nTotalQTY   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,
   @nTotalActQTY= CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cExtendedInfo       = V_String23,
   @cExtendedPutawaySP  = V_String24,
   @cPACartConfirmSKU   = V_String25,

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

IF @nFunc = 807  -- PTL Cart
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Cart
   IF @nStep = 1 GOTO Step_1   -- Scn = 4130. CartID, Col, Row
   IF @nStep = 2 GOTO Step_2   -- Scn = 4131. Assign ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 4132. LOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 4133. SKU
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 810. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedPutawaySP = rdt.rdtGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
   IF @cExtendedPutawaySP = '0'
      SET @cExtendedPutawaySP = ''  
   SET @cPACartConfirmSKU = rdt.rdtGetConfig( @nFunc, 'PACartConfirmSKU', @cStorerKey)
   IF @cPACartConfirmSKU = '0'
      SET @cPACartConfirmSKU = ''  
      
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

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign-in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

   -- Init screen
   SET @cOutField01 = SUSER_SNAME() -- Cart id
   SET @cOutField02 = '' -- Col
   SET @cOutField03 = '' -- Row

   -- Set the entry point
   SET @nScn = 4290
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 2 -- Col

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
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4290.
   CartID   (Field01, input)
   Col      (Field02, input)
   Row      (Field03, input)  
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cCartID = @cInField01
      SET @cCol = @cInField02
      SET @cRow = @cInField03

      -- Retain value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03

      -- Check blank
      IF @cCartID = ''
      BEGIN
         SET @nErrNo = 57301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check cart use by other
      IF EXISTS( SELECT 1 FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID AND AddWho <> @cUserName)
      BEGIN
         SET @nErrNo = 57302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cCartID

      -- Check col blank
      IF @cCol = ''
      BEGIN
         SET @nErrNo = 57303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Col
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check col valid
      IF rdt.rdtIsValidQTY( @cCol, 1) = 0
      BEGIN
         SET @nErrNo = 57304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Col
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check col max
      IF CAST( @cCol AS INT) > 10
      BEGIN
         SET @nErrNo = 57305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over max Col
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END
      SET @cOutField02 = @cCol

      -- Check row blank
      IF @cRow = ''
      BEGIN
         SET @nErrNo = 57306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Row
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Check row valid
      IF rdt.rdtIsValidQTY( @cRow, 1) = 0
      BEGIN
         SET @nErrNo = 57307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Row
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      
      -- Check row max
      IF CAST( @cCol AS INT) > 5
      BEGIN
         SET @nErrNo = 57308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over max Row
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      SET @cOutField03 = @cRow

      -- Clear cart assign (network disconnected leave dirty data)
      DELETE rdt.rdtPACartLog WHERE CartID = @cCartID

      -- Dynamic assign ID
      EXEC rdt.rdt_PACart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cCartID, @cCol, @cRow, 
         @cResult01  OUTPUT,  
         @cResult02  OUTPUT,  
         @cResult03  OUTPUT,  
         @cResult04  OUTPUT,  
         @cResult05  OUTPUT,  
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cResult01
      SET @cOutField02 = @cResult02
      SET @cOutField03 = @cResult03
      SET @cOutField04 = @cResult04
      SET @cOutField05 = @cResult05
      SET @cOutField06 = '' -- ID

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
Step 2. Scn = 4291. Assign ID
   Result01 (Field01)
   Result02 (Field02)
   Result03 (Field03)
   Result04 (Field04)
   Result05 (Field05)
   ID       (Field06, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cToteID = @cInField06
      
      -- Exit condition
      IF @cToteID = ''
      BEGIN
         -- Check assigned
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         BEGIN
            SET @nErrNo = 57309
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
            SET @cOutField06 = ''
            GOTO Quit
         END

         -- Get task
         SET @cLOC = ''
         SET @cSKU = ''
         EXEC rdt.rdt_PACart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cCartID
            ,@cCol
            ,@cRow
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLOC       OUTPUT
            ,@cSKU       OUTPUT
            ,@cSKUDescr  OUTPUT
            ,@nTotalQTY  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
            
         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = ''
         
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO Quit
      END
      
      -- Check assigned
      IF EXISTS( SELECT 1 FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID)
      BEGIN
         SET @nErrNo = 57310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID assigned
         SET @cOutField06 = ''
         GOTO Quit
      END
      
      -- Check ID QTY
      IF NOT EXISTS( SELECT 1 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND ID = @cToteID
            AND QTY-QTYAllocated-QTYPicked > 0)
      BEGIN
         SET @nErrNo = 57316
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID no QTY
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Extended putaway
      IF @cExtendedPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cType, @cCartID, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile          INT,                  ' +
               '@nFunc            INT,                  ' +
               '@cLangCode        NVARCHAR( 3),         ' +
               '@cUserName        NVARCHAR( 18),        ' +
               '@cStorerKey       NVARCHAR( 15),        ' +
               '@cFacility        NVARCHAR( 5),         ' + 
               '@cType            NVARCHAR( 10),        ' + 
               '@cCartID          NVARCHAR( 10),        ' +
               '@cToteID          NVARCHAR( 20),        ' +
               '@nErrNo           INT           OUTPUT, ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, 'LOCK', @cCartID, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END         
      
      -- Check ID booking
      IF NOT EXISTS( SELECT 1 
         FROM RFPutaway R WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (R.FromLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND R.FromID = @cToteID)
      BEGIN
         SET @nErrNo = 57317
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID no booking
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Get max position
      SELECT @cPosition = ''
      SELECT @cPosition = Position FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID ORDER BY Position
      IF @cPosition = ''
         SET @cPosition = '01'
      ELSE
         SET @cPosition = RIGHT( '00' + CAST( CAST( @cPosition AS INT) + 1 AS NVARCHAR(2)), 2)
      
      -- Assign ID
      INSERT INTO rdt.rdtPACartLog (CartID, ToteID, Position, Col, Row)
      VALUES (@cCartID, @cToteID, @cPosition, @cCol, @cRow)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 57311
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PACartFail
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Dynamic assign ID
      EXEC rdt.rdt_PACart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cCartID, @cCol, @cRow, 
         @cResult01  OUTPUT,  
         @cResult02  OUTPUT,  
         @cResult03  OUTPUT,  
         @cResult04  OUTPUT,  
         @cResult05  OUTPUT,  
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cResult01
      SET @cOutField02 = @cResult02
      SET @cOutField03 = @cResult03
      SET @cOutField04 = @cResult04
      SET @cOutField05 = @cResult05
      SET @cOutField06 = '' -- ID
   END

   IF @nInputKey = 0
   BEGIN
      -- Extended putaway
      IF @cExtendedPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cType, @cCartID, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile          INT,                  ' +
               '@nFunc            INT,                  ' +
               '@cLangCode        NVARCHAR( 3),         ' +
               '@cUserName        NVARCHAR( 18),        ' +
               '@cStorerKey       NVARCHAR( 15),        ' +
               '@cFacility        NVARCHAR( 5),         ' + 
               '@cType            NVARCHAR( 10),        ' + 
               '@cCartID          NVARCHAR( 10),        ' +
               '@cToteID          NVARCHAR( 20),        ' +
               '@nErrNo           INT           OUTPUT, ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, 'UNLOCK', @cCartID, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END  
      
      DELETE rdt.rdtPACartLog WHERE CartID = @cCartID

      -- Prep next screen var
      SET @cOutfield01 = @cCartID
      SET @cOutfield02 = @cCol
      SET @cOutfield03 = @cRow
         
      -- Go to cart ID screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4292. LOC screen
   LOC      (Field01)
   LOC      (Field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cActLOC NVARCHAR(10)
   
      -- Screen mapping
      SET @cActLOC = @cInField02

      -- Check same location
      IF @cActLOC <> @cLOC
      BEGIN
         SET @nErrNo = 57312
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff LOC
         GOTO Quit
      END

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PACart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
        ,@cCartID
        ,@cCol
        ,@cRow
        ,@cLOC
        ,@cSKU
        ,@nErrNo     OUTPUT
        ,@cErrMsg    OUTPUT
        ,@cResult01  OUTPUT
        ,@cResult02  OUTPUT
        ,@cResult03  OUTPUT
        ,@cResult04  OUTPUT
        ,@cResult05  OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      -- Extended info (james01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cLOC',      @cLOC)

            SET @cExtendedInfo = ''
            SET @cOutField12 = ''

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
               @nMobile, @nFunc, @cLangCode, @nStep, 4, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF ISNULL( @cExtendedInfo, '') <> '' SET @cOutField12 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = @cResult01 -- Result 1
      SET @cOutField05 = @cResult02
      SET @cOutField06 = @cResult03
      SET @cOutField07 = @cResult04
      SET @cOutField08 = @cResult05 -- Result 5
      SET @cOutField09 = @nTotalQTY
      SET @cOutField10 = '' -- @nActQTY

      IF @cPACartConfirmSKU = '1'
      BEGIN
         SET @cFieldAttr10 = 'O' -- Disable Total Qty
         SET @cFieldAttr11 = ''  -- Enable SKU
         SET @cOutField10 = '0' 
         SET @cOutField11 = '' 
      END
      ELSE
      BEGIN
         SET @cFieldAttr10 = ''  -- Enable Total Qty
         SET @cFieldAttr11 = 'O' -- Disable SKU
         SET @cOutField11 = ''
      END

      SET @nTotalActQTY = 0

      -- Go to matrix screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Dynamic assign ID
      EXEC rdt.rdt_PACart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cCartID, @cCol, @cRow, 
         @cResult01  OUTPUT,  
         @cResult02  OUTPUT,  
         @cResult03  OUTPUT,  
         @cResult04  OUTPUT,  
         @cResult05  OUTPUT,  
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cResult01
      SET @cOutField02 = @cResult02
      SET @cOutField03 = @cResult03
      SET @cOutField04 = @cResult04
      SET @cOutField05 = @cResult05
      SET @cOutField06 = '' -- ID

      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  

      SET @cFieldAttr10 = ''  -- Enable Total Qty
      SET @cFieldAttr11 = ''  -- Enable SKU
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField02 = '' -- LOC
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 4293. Maxtrix screen
   SKU      (field01)
   Desc1    (field02)
   Desc2    (field03)
   Result01 (field04)
   Result02 (field05)
   Result03 (field06)
   Result04 (field07)
   Result05 (field08)
   EXP QTY  (field09)
   ACT QTY  (field10, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      DECLARE @nActQTY        INT
      DECLARE @nSKUCnt        INT
      DECLARE @cActQTY        NVARCHAR(5)
      DECLARE @cActSKU        NVARCHAR(20) 
      
      -- Screen mapping
      IF @cPACartConfirmSKU = '1'
      BEGIN
         SET @cActQTY = '1'
         SET @cActSKU = @cInField11
      END
      ELSE
      BEGIN
         SET @cActQTY = @cInField10
         SET @cActSKU = ''
      END

      -- Check blank
      IF @cActQTY = ''
      BEGIN
         SET @nErrNo = 57313
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Quit
      END

      -- Check QTY valid
      IF rdt.rdtIsValidQTY( @cActQTY, 0) = 0
      BEGIN
         SET @nErrNo = 57314
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nActQTY = @cActQTY

      -- Check col max
      IF @nActQTY > @nTotalQTY
      BEGIN
         SET @nErrNo = 57315
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over max QTY
         GOTO Quit
      END

      IF @cPACartConfirmSKU = '1'
      BEGIN
         IF ISNULL( @cActSKU, '') <> ''
         BEGIN
            -- Get SKU/UPC
            SET @nSKUCnt = 0

            EXEC RDT.rdt_GETSKUCNT
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU
               ,@nSKUCnt     = @nSKUCnt       OUTPUT
               ,@bSuccess    = @bSuccess      OUTPUT
               ,@nErr        = @nErrNo        OUTPUT
               ,@cErrMsg     = @cErrMsg       OUTPUT

            -- Validate SKU/UPC
            IF @nSKUCnt = 0
            BEGIN
               SET @nErrNo = 57318
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
               GOTO Quit
            END

            IF @nSKUCnt > 1
            BEGIN
               SET @nErrNo = 57319
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarcodeSKU
               GOTO Quit
            END

            EXEC [RDT].[rdt_GETSKU]
                  @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU       OUTPUT
               ,@bSuccess    = @bSuccess      OUTPUT
               ,@nErr        = @nErrNo        OUTPUT
               ,@cErrMsg     = @cErrMsg       OUTPUT

         END

         SET @cSKU = @cActSKU
      END

      --set @cErrMsg = cast(@nTotalQTY as nvarchar(2)) + ',' + cast(@nActQTY as nvarchar(2)) +','+ cast(@nTotalActQTY as nvarchar(2))
      --goto quit

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PACart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cCartID 
         ,@cLOC
         ,@cSKU
         ,@nTotalQTY
         ,@nActQTY
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get next task
      DECLARE @cCurrentLOC NVARCHAR(10)
      SET @cCurrentLOC = @cLOC
      EXEC rdt.rdt_PACart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cCartID
         ,@cCol
         ,@cRow
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalQTY  OUTPUT

      IF @nErrNo <> 0 -- No More Task!
      BEGIN
         SET @nErrNo = 0

         -- Prepare next screen var
         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cCol
         SET @cOutField03 = @cRow

         EXEC rdt.rdtSetFocusField @nMobile, 1 --CartID

         -- Go to CartID screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3

         GOTO Quit
      END
      
      -- Different LOC
      ELSE IF @cCurrentLOC <> @cLOC
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = ''
         
         -- Go to LOC screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit         
      END

      -- Same LOC, different SKU. Draw matrix (and light up)
      EXEC rdt.rdt_PACart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
        ,@cCartID
        ,@cCol
        ,@cRow
        ,@cLOC
        ,@cSKU
        ,@nErrNo     OUTPUT
        ,@cErrMsg    OUTPUT
        ,@cResult01  OUTPUT
        ,@cResult02  OUTPUT
        ,@cResult03  OUTPUT
        ,@cResult04  OUTPUT
        ,@cResult05  OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      -- Extended info (james01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cLOC',      @cLOC)

            SET @cExtendedInfo = ''
            SET @cOutField12 = ''

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
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF ISNULL( @cExtendedInfo, '') <> '' SET @cOutField12 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = @cResult01 -- Result 1
      SET @cOutField05 = @cResult02
      SET @cOutField06 = @cResult03
      SET @cOutField07 = @cResult04
      SET @cOutField08 = @cResult05 -- Result 5
      SET @cOutField09 = @nTotalQTY
      SET @cOutField10 = '' -- @nActQTY

      IF @cPACartConfirmSKU = '1'
      BEGIN
         SET @nTotalActQTY = @nTotalActQTY + @nActQTY
         SET @cOutField10 = @nTotalActQTY 
         SET @cOutField11 = '' 
      END
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 2 --LOC

      -- Back to LOC Screen
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
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,

      V_String1  = @cCartID,
      V_String2  = @cCol,
      V_String3  = @cRow,
      V_String4  = @cToteID,
      V_String5  = @cPosition,
      V_String6  = @nTotalTote,
      V_String7  = @nTotalQTY,

      V_String20 = @cExtendedValidateSP,
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @cExtendedInfoSP,
      V_String23 = @cExtendedInfo,
      V_String24 = @cExtendedPutawaySP,
      V_String25 = @cPACartConfirmSKU,

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