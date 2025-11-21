SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PTLCart_Zone                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-08-09 1.0  James      SOS370883 Created                               */
/* 2016-11-07 1.1  James      Extend option to 2 chars                        */
/* 2016-11-15 1.2  James      Add resaon screen                               */
/* 2017-11-20 1.3  James      INC0048924-Fix short pick update incorrect tote */
/*                            issue (james01)                                 */
/* 2018-11-07 1.4  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTLCart_Zone] (
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
   @nCount     INT,
   @bSuccess   INT,
   @nTranCount INT,
   @cSQL       NVARCHAR( MAX),
   @cSQLParam  NVARCHAR( MAX),
   @nRowCount  INT, 
   @nToteQTY   INT,

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
   @cDeviceID     NVARCHAR( 20),

   @cOrderKey     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @nQTY          INT,

   @cCartID       NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cDPLKey       NVARCHAR( 10),
   @cToteID       NVARCHAR( 20),
   @cOldToteID    NVARCHAR( 20),
   @cNewToteID    NVARCHAR( 20),
   @cBatch        NVARCHAR( 10),
   @cPosition     NVARCHAR( 10),
   @nTotalOrder   INT,
   @nTotalTote    INT,
   @nTotalPOS     INT,
   @nTotalQTY     INT,
   @nNextPage     INT,
   @cOption       NVARCHAR( 2),
   @cPickSeq      NVARCHAR( 1),
   @cPickMethod   NVARCHAR( 1),
   @cDefaultPickSeq NVARCHAR( 1),

   @cPTLPKZoneReq       NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cAllowSkipTask      NVARCHAR( 1),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cLight              NVARCHAR( 1),
   @cExtendedInfo       NVARCHAR( 20),
   @cCartCapacity       NVARCHAR( 2),
   @cActToteID          NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20), 
   @cBarcode            NVARCHAR( 60), 
   @cID                 NVARCHAR( 18), 
   @cUPC                NVARCHAR( 30), 
   @cLottable01         NVARCHAR( 18), 
   @cLottable02         NVARCHAR( 18), 
   @cLottable03         NVARCHAR( 18), 
   @dLottable04         DATETIME,    
   @dLottable05         DATETIME,    
   @cLottable06         NVARCHAR( 30), 
   @cLottable07         NVARCHAR( 30), 
   @cLottable08         NVARCHAR( 30), 
   @cLottable09         NVARCHAR( 30), 
   @cLottable10         NVARCHAR( 30), 
   @cLottable11         NVARCHAR( 30), 
   @cLottable12         NVARCHAR( 30), 
   @dLottable13         DATETIME,      
   @dLottable14         DATETIME,      
   @dLottable15         DATETIME,    
   @cUserDefine01       NVARCHAR( 60),  
   @cUserDefine02       NVARCHAR( 60),  
   @cUserDefine03       NVARCHAR( 60),  
   @cUserDefine04       NVARCHAR( 60),  
   @cUserDefine05       NVARCHAR( 60),  
   @nFromScn            INT,
   @nFromStep           INT,
   @cShortPickFlag      NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),  
   @cUOM                NVARCHAR( 10),  
   @cUOMQty             NVARCHAR( 10),  
   @cLot                NVARCHAR( 10),  
   @cStoredProcName     NVARCHAR( 45),  
   @nUOMQty             INT,
   @nShortPickQty       INT,
   @c_NewLineChar       NVARCHAR( 2),  
   @c_AlertMessage      NVARCHAR( 512),
   @b_success           INT,
   @n_Err               INT,
   @c_Errmsg            NVARCHAR( 20),

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
   
   @nQTY        = V_Integer1,
   @nTotalOrder = V_Integer2,
   @nTotalTote  = V_Integer3,
   @nTotalPOS   = V_Integer4,
   @nTotalQTY   = V_Integer5,
   @nNextPage   = V_Integer6,
   
   @nFromScn    = V_FromScn, 
   @nFromStep   = V_FromStep,

   @cOrderKey   = V_OrderKey,
   @cLOC        = V_LOC,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
  -- @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 9), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @cCartID     = V_String1,
   @cPickZone   = V_String2,
   @cMethod     = V_String3,
   @cDPLKey     = V_String4,
   @cToteID     = V_String5,
   @cPosition   = V_String6,
   @cBatch      = V_String7,
  -- @nTotalOrder = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  5), 0) = 1 THEN LEFT( V_String8,  5) ELSE 0 END,
  -- @nTotalTote  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,
  -- @nTotalPOS   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10, 5), 0) = 1 THEN LEFT( V_String10, 5) ELSE 0 END,
  -- @nTotalQTY   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
  -- @nNextPage   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
   @cOption     = V_String13,
   @cPickSeq    = V_String14,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cPTLPKZoneReq       = V_String23,
   @cAllowSkipTask      = V_String24,
   @cDecodeSP           = V_String25,
   @cLight              = V_String26,
   @cExtendedInfo       = V_String27,
  -- @nFromScn    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28, 5), 0) = 1 THEN LEFT( V_String28, 5) ELSE 0 END,
  -- @nFromStep   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 5), 0) = 1 THEN LEFT( V_String29, 5) ELSE 0 END,
   @cShortPickFlag      = V_String30,

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

IF @nFunc = 819  -- PTL Cart By Zone
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0   -- PTL Cart
   IF @nStep = 1  GOTO Step_1   -- Scn = 4700. CartID, PickZone, Method
   IF @nStep = 2  GOTO Step_2   -- Scn = 4188. Dynamic assign
   IF @nStep = 3  GOTO Step_3   -- Scn = 4701. Cart ready
   IF @nStep = 4  GOTO Step_4   -- Scn = 4702. Loc
   IF @nStep = 5  GOTO Step_5   -- Scn = 4703. SKU
   IF @nStep = 6  GOTO Step_6   -- Scn = 4704. Scan tote, tote full?
   IF @nStep = 7  GOTO Step_7   -- Scn = 4705. Picking complete
   IF @nStep = 8  GOTO Step_8   -- Scn = 4706. Change tote
   IF @nStep = 9  GOTO Step_9   -- Scn = 4707. Unassign cart?
   IF @nStep = 10 GOTO Step_10  -- Scn = 2109. REASON Screen  
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 810. Menu
********************************************************************************/
Step_0:
BEGIN
   SET @cShortPickFlag = 'N'  

   -- Get storer config
   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   SET @cAllowSkipTask = rdt.rdtGetConfig( @nFunc, 'AllowSkipTask', @cStorerKey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cPickMethod = rdt.RDTGetConfig( @nFunc, 'PTLDefaultMethod', @cStorerKey)
   IF @cPickMethod = '0'
      SET @cPickMethod = ''

   SET @cDefaultPickSeq = rdt.RDTGetConfig( @nFunc, 'PTLDefaultPickSeq', @cStorerKey)
   IF @cDefaultPickSeq = '0'
      SET @cDefaultPickSeq = ''

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
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init screen
   SET @cOutField01 = '' -- Cart id
   SET @cOutField02 = '' -- Pickzone
   SET @cOutField03 = CASE WHEN ISNULL( @cPickMethod, '') <> '' THEN @cPickMethod ELSE '' END -- Method
   SET @cOutField04 = CASE WHEN ISNULL( @cDefaultPickSeq, '') <> '' THEN @cDefaultPickSeq ELSE '' END -- PickSeq

   -- Set the entry point
   SET @nScn = 4700
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4130.
   CartID   (Field01, input)
   PickZone (Field02, input)
   Method   (Field03, input)
   PickSeq  (Field04, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cCartID = @cInField01
      SET @cPickZone = @cInField02
      SET @cMethod = @cInField03
      SET @cPickSeq = @cInField04

      -- Retain value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04

      -- Check blank
      IF @cCartID = ''
      BEGIN
         SET @nErrNo = 102801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check cart valid
      IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceType = 'CART' AND DeviceID = @cCartID)
      BEGIN
         SET @nErrNo = 102802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check cart use by other
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND AddWho <> @cUserName)
      BEGIN
         SET @nErrNo = 102803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Get cart capacity
      SELECT @cCartCapacity = Short
      FROM dbo.CodeLkUp WITH (NOLOCK) 
      WHERE ListName = 'CART'
      AND   Code = @cCartID
      AND   StorerKey = @cStorerKey

      IF ISNULL( @cCartCapacity, '') = ''
      BEGIN
         SET @nErrNo = 102804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup capacity
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      SET @cOutField01 = @cCartID

      -- Check pickzone & blank
      IF @cPickZone = '' AND @cPTLPKZoneReq = '1'
      BEGIN
         SET @nErrNo = 102805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)
                      WHERE ListName = 'WCSSTATION'
                      AND   Long = @cPickZone
                      AND   StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 102806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup PKZone
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check pickzone valid
      IF NOT EXISTS( SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK) 
                     WHERE Facility = @cFacility 
                     AND   EXISTS ( SELECT 1 FROM dbo.CodeLkUp CLK WITH (NOLOCK) 
                                    WHERE CLK.ListName = 'WCSStation'
                                    AND   CLK.Code = LOC.PickZone
                                    AND   CLK.Long = @cPickZone))
      BEGIN
         SET @nErrNo = 102807
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKZone
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END

      SET @cOutField02 = @cPickZone

      -- Get method info
      DECLARE @cMethodSP SYSNAME
      SET @cMethodSP = ''
      SELECT @cMethodSP = ISNULL( UDF01, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CartMethod'
         AND Code = @cMethod
         AND StorerKey = @cStorerKey

      -- Check method
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 102808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 102809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Method SP
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      SET @cOutField03 = @cMethod

      -- Check pick seq
      IF @cPickSeq <> ''
      BEGIN
         -- Check PickSeq valid
         IF NOT EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) 
                        WHERE ListName = 'CARTORDTYP' 
                        AND   StorerKey = @cStorerKey 
                        AND   Code = @cPickSeq)
         BEGIN
            SET @nErrNo = 102810
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad pick seq
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- PickSeq
            SET @cOutField04 = ''
            GOTO Quit
         END
      END
      SET @cOutfield04 = @cPickSeq

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
               ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cPickSeq   NVARCHAR( 1),  ' +
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cDPLKey = ''
      SELECT TOP 1
         @cDPLKey = DeviceProfileLogKey
      FROM rdt.rdtPTLCartLog WITH (NOLOCK)
      WHERE CartID = @cCartID

      -- Check cart not unassign (network disconnected)
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
      BEGIN
         -- Load earlier setting to continue
         SELECT TOP 1
            @cDPLKey = DeviceProfileLogKey, 
            @cPickZone = PickZone,
            @cMethod = Method, 
            @cPickSeq = PickSeq
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
      END
      ELSE
      BEGIN
         -- Get DeviceProfileLogKey
         EXECUTE nspg_getkey
             'DeviceProfileLogKey'
            ,10
            ,@cDPLKey  OUTPUT
            ,@bSuccess OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 102811
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO Quit
         END
      END

      -- Dynamic assign
      EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-IN',
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
Step 2. Scn = 4131. Dynamic assign
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Dynamic assign
      EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'CHECK',
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
               ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cPickSeq   NVARCHAR( 1),  ' +               
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Go to Cart ready screen
      SET @nScn = 4701
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = '' -- Option
         SET @cOutfield02 = @cCartID -- Cart Id
         
         -- Go to unassign cart screen
         SET @nScn = 4701 + 6
         SET @nStep = @nStep + 7
      END
      ELSE
      BEGIN
         -- Dynamic assign  
         EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-OUT',  
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
         SET @cOutfield01 = @cCartID
         SET @cOutfield02 = @cPickZone
         SET @cOutfield03 = @cMethod
         SET @cOutfield04 = @cPickSeq
   
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
   
         -- Go to cart screen
         SET @nScn = 4701 - 1
         SET @nStep = @nStep - 1
      END
   END
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 4701. Cart ready screen

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Get task
      SET @cLOC = ''
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,'' -- @cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prep next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = ''
      SET @cOutField03 = @cCartID
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1      
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 4702. LOC screen
   LOC      (Field03, input)

********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cActLOC NVARCHAR(20)

      -- Screen mapping
      SET @cActLOC = @cInField02
      
      IF ISNULL( @cActLOC, '') = ''
      BEGIN
         SET @nErrNo = 102812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Loc required
         GOTO Step_4_Fail
      END

      IF @cLOC <> @cActLOC
      BEGIN
         SET @nErrNo = 102813
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Loc required
         GOTO Step_4_Fail
      END  

      -- Get task
      SET @cSKU = ''
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,'' -- @cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = ''
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = '9'
      SET @cOutField07 = @cCartID
      
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 --ESC
   BEGIN
      -- Dynamic assign  
      EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-IN',  
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
  
      SET @nStep = @nStep - 2  
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField02 = ''   -- LOC
      SET @cOutField03 = @cCartID   -- Cart ID
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 4703. SKU screen
   LOC      (Field01)
   SKU      (Field02)
   SKU      (Field03, input)
   Descr 1  (Field04)
   Descr 2  (Field05)
   Option   (Field06, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cActSKU NVARCHAR(40)

      -- Screen mapping
      SET @cActSKU = @cInField03
      SET @cOption = @cInField06

      IF ISNULL( @cOption, '') <> ''
      BEGIN
         -- Check option valid
         IF @cOption <> '1' AND @cOption <> '9'
         BEGIN
            SET @nErrNo = 102821
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Quit
         END

         SET @cShortPickFlag = 'N'  

         -- Short pick
         IF @cOption = '1'
         BEGIN
            SET @cShortPickFlag = 'Y'  

            -- If setup codelkp then goto reason code if short pick
            IF EXISTS( SELECT 1 FROM CODELKUP WITH (NOLOCK)  
                       WHERE LISTNAME IN ( 'SPKINVRSN', 'NSPKINVRSN')
                       AND   1 = CASE WHEN ISNULL( StorerKey, '') = '' THEN 1
                                      WHEN StorerKey = @cStorerKey THEN 1
                                      ELSE 0 END)
            BEGIN
               SET @cOutField01 = ''  

               SET @nFromScn  = @nScn  
               SET @nFromStep = @nStep  

               -- Go to Reason Code Screen  
               SET @nScn  = 2109  
               SET @nStep = @nStep + 5 -- Step 10

               GOTO Quit
            END
            
            SET @nTranCount = @@TRANCOUNT

            BEGIN TRAN  
            SAVE TRAN Step_5_ShortPick 

            -- Confirm
            EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SHORTTOTE'
               ,@cDPLKey
               ,@cMethod
               ,@cCartID
               ,@cToteID
               ,@cLOC
               ,@cSKU
               ,0--@nQTY   (james01)
               ,'' -- @cNewToteID
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_5_ShortPick
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               GOTO Quit
            END

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
                     ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     ' @nMobile    INT,           ' +
                     ' @nFunc      INT,           ' +
                     ' @cLangCode  NVARCHAR( 3),  ' +
                     ' @nStep      INT,           ' +
                     ' @nInputKey  INT,           ' +
                     ' @cFacility  NVARCHAR( 5),  ' +
                     ' @cStorerKey NVARCHAR( 15), ' +
                     ' @cLight     NVARCHAR( 1),  ' + 
                     ' @cDPLKey    NVARCHAR( 10), ' +
                     ' @cCartID    NVARCHAR( 10), ' +
                     ' @cPickZone  NVARCHAR( 10), ' +
                     ' @cMethod    NVARCHAR( 10), ' +
                     ' @cPickSeq   NVARCHAR( 1),  ' +               
                     ' @cLOC       NVARCHAR( 10), ' +
                     ' @cSKU       NVARCHAR( 20), ' +
                     ' @cToteID    NVARCHAR( 20), ' +
                     ' @nQTY       INT,           ' +
                     ' @cNewToteID NVARCHAR( 20), ' +
                     ' @nErrNo     INT            OUTPUT, ' +
                     ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
         
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                     @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cActToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN Step_5_ShortPick
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN
                     GOTO Quit
                  END
               END
            END

            COMMIT TRAN Step_5_ShortPick
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

            -- Get next sku
            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
               ,@cLight
               ,@cCartID
               ,@cPickZone
               ,@cMethod
               ,@cPickSeq
               ,'' -- @cToteID
               ,@cDPLKey
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cLOC       OUTPUT
               ,@cSKU       OUTPUT
               ,@cSKUDescr  OUTPUT
               ,@nTotalPOS  OUTPUT
               ,@nTotalQTY  OUTPUT
               ,@nToteQTY   OUTPUT

            IF @nErrNo <> 0 -- No More Task!
            BEGIN
               -- Get next loc
               SET @nErrNo = 0
               SET @cErrMsg = ''
               EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
                  ,@cLight
                  ,@cCartID
                  ,@cPickZone
                  ,@cMethod
                  ,@cPickSeq
                  ,'' -- @cToteID
                  ,@cDPLKey
                  ,@nErrNo     OUTPUT
                  ,@cErrMsg    OUTPUT
                  ,@cLOC       OUTPUT
                  ,@cSKU       OUTPUT
                  ,@cSKUDescr  OUTPUT
                  ,@nTotalPOS  OUTPUT
                  ,@nTotalQTY  OUTPUT
                  ,@nToteQTY   OUTPUT

               IF @nErrNo <> 0 -- No More Task!
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''

                  SET @cOutField01 = @cCartID
                  SET @cOutField02 = @cPickZone
                  SET @cOutField03 = @cMethod
                  SET @cOutField04 = @cPickSeq
                  
                  IF EXISTS ( 
                     SELECT 1 
                     FROM PTLTran PTL WITH (NOLOCK)  
                     JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
                        (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
                     WHERE PTL.DeviceProfileLogKey = @cDPLKey  
                     AND   PTL.Status = '9'  
                     AND   PTL.Qty > 0
                     AND   PTLLog.CartID = @cCartID )
                  BEGIN
                     -- Something pick for this tote
                     SET @cOutField05 = 'PLEASE PLACE TOTE'
                     SET @cOutField06 = @cToteID
                     SET @cOutField07 = 'ON CONVEYOR.'
                  END
                  ELSE
                  BEGIN
                     -- Nothing pick for this tote
                     SET @cOutField05 = ''
                     SET @cOutField06 = ''
                     SET @cOutField07 = ''
                  END
               
                  -- Go to finish screen
                  SET @nScn = @nScn + 2
                  SET @nStep = @nStep + 2

                  GOTO Quit
               END
               ELSE  -- Get the task in next LOC
               BEGIN
                  -- Prep next screen var
                  SET @cOutField01 = @cLOC
                  SET @cOutField02 = ''
                  SET @cOutField03 = @cCartID

                  -- Go to next screen
                  SET @nScn = @nScn - 1
                  SET @nStep = @nStep - 1    
                  
                  GOTO Quit  
               END
            END
            ELSE  -- Get the task for next SKU
            BEGIN
               -- Prepare next screen variable
               SET @cOutField01 = @cLOC
               SET @cOutField02 = @cSKU
               SET @cOutField03 = ''
               SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
               SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
               SET @cOutField06 = '9'
               SET @cOutField07 = @cCartID

               GOTO Quit
            END
         END
      END

      IF ISNULL( @cActSKU, '') = ''
      BEGIN
         SET @nErrNo = 102814
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Sku required
         GOTO Step_5_Fail
      END

      -- (james02)
      IF @cDecodeSP <> ''
      BEGIN
         SET @cBarcode = @cInField03

         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cLOC           OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cToteID        OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' + 
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cLOC           NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY           INT            OUTPUT, ' +
               ' @cToteID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04    DATETIME       OUTPUT, ' +
               ' @dLottable05    DATETIME       OUTPUT, ' +
               ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13    DATETIME       OUTPUT, ' +
               ' @dLottable14    DATETIME       OUTPUT, ' +
               ' @dLottable15    DATETIME       OUTPUT, ' +
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, 
               @cLOC          OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT, @cToteID        OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,               
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT
         END
      END   -- End for DecodeSP
            
      IF @cActSKU <> @cSKU
      BEGIN
         SET @nErrNo = 102815
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Sku not match
         GOTO Step_5_Fail
      END

      -- Get SKU
      DECLARE @nSKUCnt INT
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cActSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 102816
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_5_Fail
      END

      -- Get SKU code
      EXEC dbo.nspg_GETSKU
          @cStorerKey
         ,@cActSKU    OUTPUT
         ,@bSuccess   OUTPUT
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 102817
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_5_Fail
      END

      -- Get current task QTY  
      SELECT TOP 1 @cToteID = ToteID
      FROM PTLTran PTL WITH (NOLOCK)  
      JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
         (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
      AND   PTL.Status = '0'  
      AND   PTL.LOC = @cLOC  
      AND   PTL.SKU = @cSKU  
      AND   PTLLog.CartID = @cCartID
         
      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cToteID
      SET @cOutField05 = ''
      SET @cOutField06 = '9' -- Option
      SET @cOutField07 = @cCartID -- Cart ID

      -- Go to scan tote screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare prev screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = ''
      SET @cOutField03 = @cCartID
      
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField03 = '' -- SKU
   END
END
GOTO QUIT


/********************************************************************************
Step 6. Scn = 4704. 
   SKU            (Field01)
   Descr 1        (Field02)
   Descr 2        (Field03)
   Tote ID        (Field04)
   Scan Tote ID   (Field05, input)
   Option         (field06, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cActToteID = @cInField05
      SET @cOption = @cInField06

      IF ISNULL( @cActToteID, '') = ''
      BEGIN
         SET @nErrNo = 102818
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote req
         SET @cOutField05 = ''
         GOTO Quit
      END

      IF @cActToteID <> @cToteID
      BEGIN
         SET @nErrNo = 102819
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not match
         SET @cOutField05 = ''
         GOTO Quit
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cActToteID) = 0
      BEGIN
         SET @nErrNo = 102820
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      -- Option
      IF ISNULL( @cOption, '') <> ''
      BEGIN
         -- Check option valid
         IF @cOption <> '1' AND @cOption <> '9'
         BEGIN
            SET @nErrNo = 102822
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Quit
         END

         IF @cOption = '1'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cToteID   -- Tote ID
            SET @cOutField02 = ''         -- New Tote ID
            SET @cOutField03 = @cCartID   -- Cart ID
            
            -- Go to close tote screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
      END

      SET @nTranCount = @@TRANCOUNT    

      BEGIN TRAN    
      SAVE TRAN Step_6_ScanTote

      -- Confirm SKU (for non-light)
      EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
         ,@cDPLKey
         ,@cMethod
         ,@cCartID
         ,@cActToteID -- @cToteID
         ,@cLOC
         ,@cSKU
         ,0  -- @cQTY
         ,'' -- @cNewToteID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_6_ScanTote
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
         AND   LOC = @cLOC
         AND   SKU = @cSKU
         AND   DropID = @cActToteID
         AND   ExpectedQty > Qty
         AND   Status <> '9')
      BEGIN
         -- Confirm LOC (for non-light)
         EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
            ,@cDPLKey
            ,@cMethod
            ,@cCartID
            ,@cActToteID -- @cToteID
            ,@cLOC
            ,@cSKU
            ,0  -- @cQTY
            ,'' -- @cNewToteID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_6_ScanTote
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
            GOTO Quit
         END

         -- Check pick completed (light and no light)
         IF EXISTS( SELECT 1
            FROM dbo.PTLTran WITH (NOLOCK)
            WHERE DeviceProfileLogKey = @cDPLKey
               AND SKU = @cSKU
               AND LOC = @cLOC
               AND DropID = @cActToteID
               AND Status <> '9')
         BEGIN
            ROLLBACK TRAN Step_6_ScanTote
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

            SET @nErrNo = 102827
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
            SET @cOutField05 = ''
            GOTO Quit
         END
      
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
               ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cPickSeq   NVARCHAR( 1),  ' +               
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cActToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_6_ScanTote
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN Step_6_ScanTote
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      -- Check if this tote has anything else to pick on this cart. If not then send to conveyor
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PTLTran PTL WITH (NOLOCK) 
         JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
            ( PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
         WHERE PTL.DeviceProfileLogKey = @cDPLKey  
         AND   PTL.Status = '0'  
         AND   PTLLog.CartID = @cCartID 
         AND   PTLLog.ToteID = @cActToteID)
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg = ''

         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cPickZone
         SET @cOutField03 = @cMethod
         SET @cOutField04 = @cPickSeq      

         -- Something pick for this tote
         SET @cOutField05 = 'PLEASE PLACE TOTE'
         SET @cOutField06 = @cToteID
         SET @cOutField07 = 'ON CONVEYOR.'
      
         -- Go to finish screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit            
      END

      -- Get next task
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,'' -- @cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT

      IF @nErrNo <> 0 -- No More Task!
      BEGIN
         -- Get next task
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
            ,@cLight
            ,@cCartID
            ,@cPickZone
            ,@cMethod
            ,@cPickSeq
            ,'' -- @cToteID
            ,@cDPLKey
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLOC       OUTPUT
            ,@cSKU       OUTPUT
            ,@cSKUDescr  OUTPUT
            ,@nTotalPOS  OUTPUT
            ,@nTotalQTY  OUTPUT
            ,@nToteQTY   OUTPUT

         IF @nErrNo <> 0 -- No More Task!
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''

            SET @cOutField01 = @cCartID
            SET @cOutField02 = @cPickZone
            SET @cOutField03 = @cMethod
            SET @cOutField04 = @cPickSeq

            IF EXISTS ( 
               SELECT 1 
               FROM PTLTran PTL WITH (NOLOCK)  
               JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
                  (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
               WHERE PTL.DeviceProfileLogKey = @cDPLKey  
               AND   PTL.Status = '9'  
               AND   PTL.Qty > 0
               AND   PTLLog.CartID = @cCartID )
            BEGIN
               -- Something pick for this tote
               SET @cOutField05 = 'PLEASE PLACE TOTE'
               SET @cOutField06 = @cToteID
               SET @cOutField07 = 'ON CONVEYOR.'
            END
            ELSE
            BEGIN
               -- Nothing pick for this tote
               SET @cOutField05 = ''
               SET @cOutField06 = ''
               SET @cOutField07 = ''
            END
         
            -- Go to finish screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
         ELSE  -- Get next task in next LOC
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = ''
            SET @cOutField03 = @cCartID

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
            
            GOTO Quit
         END
      END
   
      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = ''
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = '9'
      SET @cOutField07 = @cCartId

      -- Go to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = ''
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = '9'
      SET @cOutField07 = @cCartId

      -- Back to SKU Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO QUIT

/********************************************************************************
Step 7. Scn = 4705. 
   Picking completed
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- If close tote then need check if anything else need to pick for the new tote
      -- Get current task QTY  
      SET @cToteID = ''
      SELECT TOP 1 @cToteID = ToteID
      FROM PTLTran PTL WITH (NOLOCK)  
      JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
         (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
      AND   PTL.Status = '0'  
      AND   PTL.LOC = @cLOC  
      AND   PTL.SKU = @cSKU  
      AND   PTL.Status <> '9'
      AND   PTLLog.CartID = @cCartID

      IF ISNULL( @cToteID, '') <> ''
      BEGIN 
         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = ''
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = '9'
         SET @cOutField07 = @cCartID

         -- Go to scan sku screen (same loc, same sku, 
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         
         GOTO Quit
      END

      -- Get next task
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,'' -- @cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         -- Get next task
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
            ,@cLight
            ,@cCartID
            ,@cPickZone
            ,@cMethod
            ,@cPickSeq
            ,'' -- @cToteID
            ,@cDPLKey
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLOC       OUTPUT
            ,@cSKU       OUTPUT
            ,@cSKUDescr  OUTPUT
            ,@nTotalPOS  OUTPUT
            ,@nTotalQTY  OUTPUT
            ,@nToteQTY   OUTPUT

         IF @nErrNo <> 0 -- No More Task!
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''

            -- Dynamic assign
            EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-OUT',
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
      
            -- Close cart
            EXEC rdt.rdt_PTLCart_CloseCart @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cCartID
               ,@cPickZone
               ,@cDPLKey
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Prep next screen var
            SET @cOutfield01 = @cCartID
            SET @cOutfield02 = @cPickZone
            SET @cOutfield03 = @cMethod
            SET @cOutfield04 = @cPickSeq
      
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
      
            -- Go to cart screen
            SET @nScn = @nScn - 5
            SET @nStep = @nStep - 6
            
            GOTO Quit
         END
         ELSE
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = ''
            SET @cOutField03 = @cCartID

            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3       
         END
      END
--      ELSE
--      BEGIN
--         -- Prepare next screen variable
--         SET @cOutField01 = @cLOC
--         SET @cOutField02 = @cSKU
--         SET @cOutField03 = ''
--         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
--         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
--         SET @cOutField06 = '9'
--         SET @cOutField07 = @cCartID
--
--         -- Go to SKU screen
--         SET @nScn = @nScn - 2
--         SET @nStep = @nStep - 2
--      END
   END
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 4706. Swap tote
   Old Tote       (Field01)
   New Tote       (Field02, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOldToteID = @cOutField01
      SET @cNewToteID = @cInField02

      -- Check blank
      IF @cNewToteID = ''
      BEGIN
         SET @nErrNo = 102823
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --New Tote req
         GOTO Step_8_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cNewToteID) = 0
      BEGIN
         SET @nErrNo = 102824
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_8_Fail
      END

      -- Check tote on cart
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cNewToteID)
      BEGIN
         SET @nErrNo = 102825
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Existing Tote
         GOTO Step_8_Fail
      END

      SET @nTranCount = @@TRANCOUNT    

      BEGIN TRAN    
      SAVE TRAN Step_5_ToteFull
   
      -- Confirm
      SET @nErrNo = 0
      EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSETOTE'
         ,@cDPLKey
         ,@cMethod
         ,@cCartID
         ,@cOldToteID
         ,@cLOC
         ,@cSKU
         ,1 -- Piece scanning
         ,@cNewToteID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_5_ToteFull
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
               ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cPickSeq   NVARCHAR( 1),  ' +               
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_5_ToteFull
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN Step_5_ToteFull
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cMethod
      SET @cOutField04 = @cPickSeq

      SET @cOutField05 = 'PLEASE PLACE TOTE'
      SET @cOutField06 = @cOldToteID
      SET @cOutField07 = 'ON CONVEYOR.'
         
      -- Go to finish screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cToteID
      SET @cOutField05 = ''
      SET @cOutField06 = '9' -- Option
      SET @cOutField07 = @cCartID -- Cart Id

      -- Go to scan tote screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOutField01 = @cOldToteID
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 9. Scn = 4707. Unassign cart screen
   Unassign cart?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 53425
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 53426
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Dynamic assign
         EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-OUT',
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

         SET @nTranCount = @@TRANCOUNT    

         BEGIN TRAN    
         SAVE TRAN Step_9_Unassign

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
                  ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  ' @nMobile    INT,           ' +
                  ' @nFunc      INT,           ' +
                  ' @cLangCode  NVARCHAR( 3),  ' +
                  ' @nStep      INT,           ' +
                  ' @nInputKey  INT,           ' +
                  ' @cFacility  NVARCHAR( 5),  ' +
                  ' @cStorerKey NVARCHAR( 15), ' +
                  ' @cLight     NVARCHAR( 1),  ' + 
                  ' @cDPLKey    NVARCHAR( 10), ' +
                  ' @cCartID    NVARCHAR( 10), ' +
                  ' @cPickZone  NVARCHAR( 10), ' +
                  ' @cMethod    NVARCHAR( 10), ' +
                  ' @cPickSeq   NVARCHAR( 1),  ' +               
                  ' @cLOC       NVARCHAR( 10), ' +
                  ' @cSKU       NVARCHAR( 20), ' +
                  ' @cToteID    NVARCHAR( 20), ' +
                  ' @nQTY       INT,           ' +
                  ' @cNewToteID NVARCHAR( 20), ' +
                  ' @nErrNo     INT            OUTPUT, ' +
                  ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_9_Unassign
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                        COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         -- Close cart
         EXEC rdt.rdt_PTLCart_CloseCart @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cCartID
            ,@cPickZone
            ,@cDPLKey
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_9_Unassign
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
            GOTO Quit
         END

         COMMIT TRAN Step_9_Unassign
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            
         -- Prep next screen var
         SET @cOutfield01 = @cCartID
         SET @cOutfield02 = @cPickZone
         SET @cOutfield03 = @cMethod
         SET @cOutfield04 = @cPickSeq
   
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
   
         -- Go to cart screen
         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 8
         
         GOTO Quit
      END
   END

   -- Dynamic assign
   EXEC rdt.rdt_PTLCart_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cCartID, @cPickZone, @cMethod, @cPickSeq, @cDPLKey, 'POPULATE-IN',
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
   SET @nStep = @nStep - 7
END
GOTO QUIT

/********************************************************************************  
Step 10. screen = 2109  
     REASON CODE  (Field01, input)  
********************************************************************************/  
Step_10:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReasonCode = @cInField01  
  
      IF @cReasonCode = ''  
      BEGIN  
         SET @nErrNo = 70024  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req  
         GOTO Step_10_Fail  
      END  
  
      IF @cShortPickFlag = 'Y'  
      BEGIN  
         IF NOT EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK)  
                       WHERE LISTNAME = 'SPKVALRSN'  
                       AND   Code = @cReasonCode
                       AND   StorerKey = @cStorerKey
                       AND   Code2 = @nFunc)
         BEGIN  
            SET @nErrNo = 102828  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD REASON  
            GOTO Step_10_Fail  
         END  
      END  
      ELSE  
      BEGIN  
         IF NOT EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK)  
                       WHERE LISTNAME = 'NSPKVALRSN'  
                       AND   Code = @cReasonCode  
                       AND   StorerKey = @cStorerKey
                       AND   Code2 = @nFunc)
         BEGIN  
            SET @nErrNo = 102829  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD REASON  
            GOTO Step_10_Fail  
         END  
      END  

      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN  
      SAVE TRAN Step_10_ShortPick 

      -- Confirm
      EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SHORTTOTE'
         ,@cDPLKey
         ,@cMethod
         ,@cCartID
         ,@cToteID
         ,@cLOC
         ,@cSKU
         ,0 --@nQTY  (james01)
         ,'' -- @cNewToteID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_10_ShortPick
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
         GOTO Quit
      END

      -- Get current task QTY  
      SELECT TOP 1 @cOrderKey = PTLLog.OrderKey, 
                   @nShortPickQty = ISNULL( SUM(PTL. ExpectedQty), 0)
      FROM dbo.PTLTran PTL WITH (NOLOCK)  
      JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
         (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
      AND   PTL.Status = '0'  
      AND   PTL.LOC = @cLOC  
      AND   PTL.SKU = @cSKU  
      AND   PTLLog.CartID = @cCartID
      GROUP BY PTLLog.OrderKey

      SELECT TOP 1 @cUOM = UOM, 
                   @nUOMQty = UOMQty, 
                   @cLot = LOT   
      FROM dbo.PickDetail WITH (NOLOCK)   
      WHERE OrderKey = @cOrderKey  
      AND   Sku = @cSku

      SELECT @cStoredProcName = StoredProcName FROM rdt.rdtMsg WITH (NOLOCK) WHERE Message_id = @nFunc
      
      SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)     
   
      SET @c_AlertMessage = 'Short Pick for CART: ' + @cCartID + @c_NewLineChar     
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @cOrderKey + @c_NewLineChar     
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' RDT Function ID: ' + CAST( @nFunc AS NVARCHAR( 5))  +  @c_NewLineChar     
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Reason: ' + @cReasonCode  +  @c_NewLineChar     
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar     

      EXEC nspLogAlert    
           @c_modulename         = @cStoredProcName         
         , @c_AlertMessage       = @c_AlertMessage       
         , @n_Severity           = '5'           
         , @b_success            = @b_success     OUTPUT           
         , @n_err                = @n_Err         OUTPUT             
         , @c_errmsg             = @c_Errmsg      OUTPUT          
         , @c_Activity           = 'CART PICK'    
         , @c_Storerkey          = @cStorerkey        
         , @c_SKU                = @cSku              
         , @c_UOM                = @cUOM              
         , @c_UOMQty             = @nUOMQty           
         , @c_Qty                = @nShortPickQty    
         , @c_Lot                = @cLot             
         , @c_Loc                = @cLoc              
         , @c_ID                 = ''                 
         , @c_TaskDetailKey      = ''    
         , @c_UCCNo              = ''          
  
      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN  
         ROLLBACK TRAN Step_10_ShortPick
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

         SET @nErrNo = 102830  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Alert Fail'  
         GOTO Quit
      END  
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, @cDPLKey, ' +
               ' @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' + 
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cMethod    NVARCHAR( 10), ' +
               ' @cPickSeq   NVARCHAR( 1),  ' +               
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cPickSeq, @cLOC, @cSKU, @cActToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_5_ShortPick
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN Step_10_ShortPick
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      -- Get next sku
      SET @nErrNo = 0
      SET @cErrMsg = ''
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,'' -- @cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT

      IF @nErrNo <> 0 -- No More Task!
      BEGIN
         -- Get next loc
         SET @nErrNo = 0
         SET @cErrMsg = ''
         EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
            ,@cLight
            ,@cCartID
            ,@cPickZone
            ,@cMethod
            ,@cPickSeq
            ,'' -- @cToteID
            ,@cDPLKey
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLOC       OUTPUT
            ,@cSKU       OUTPUT
            ,@cSKUDescr  OUTPUT
            ,@nTotalPOS  OUTPUT
            ,@nTotalQTY  OUTPUT
            ,@nToteQTY   OUTPUT

         IF @nErrNo <> 0 -- No More Task!
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg = ''

            SET @cOutField01 = @cCartID
            SET @cOutField02 = @cPickZone
            SET @cOutField03 = @cMethod
            SET @cOutField04 = @cPickSeq
            
            IF EXISTS ( 
               SELECT 1 
               FROM PTLTran PTL WITH (NOLOCK)  
               JOIN rdt.rdtPTLCartLog PTLLog WITH (NOLOCK) ON 
                  (PTL.DeviceProfileLogKey = PTLLog.DeviceProfileLogKey AND PTL.DeviceID = PTLLog.CartID AND PTL.OrderKey = PTLLog.OrderKey)  
               WHERE PTL.DeviceProfileLogKey = @cDPLKey  
               AND   PTL.Status = '9'  
               AND   PTL.Qty > 0
               AND   PTLLog.CartID = @cCartID )
            BEGIN
               -- Something pick for this tote
               SET @cOutField05 = 'PLEASE PLACE TOTE'
               SET @cOutField06 = @cToteID
               SET @cOutField07 = 'ON CONVEYOR.'
            END
            ELSE
            BEGIN
               -- Nothing pick for this tote
               SET @cOutField05 = ''
               SET @cOutField06 = ''
               SET @cOutField07 = ''
            END
         
            -- Go to finish screen
            SET @nScn = @nFromScn + 2
            SET @nStep = @nFromStep + 2

            GOTO Quit
         END
         ELSE  -- Get the task in next LOC
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cLOC
            SET @cOutField02 = ''
            SET @cOutField03 = @cCartID

            -- Go to next screen
            SET @nScn = @nFromScn - 1
            SET @nStep = @nFromStep - 1    
            
            GOTO Quit  
         END
      END
      ELSE  -- Get the task for next SKU
      BEGIN
         -- Prepare next screen variable
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = ''
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField06 = '9'
         SET @cOutField07 = @cCartID

         -- Go back to prev screen
         SET @nScn = @nFromScn
         SET @nStep = @nFromStep
            
         GOTO Quit
      END
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = ''
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = '9'
      SET @cOutField07 = @cCartID

      SET @nScn = @nFromScn  
      SET @nStep = @nFromStep  
   END  
   GOTO Quit  
  
   Step_10_Fail:  
   BEGIN  
      SET @cReasonCode = ''  
  
      -- Reset this screen var  
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
      Printer   = @cPrinter,
      InputKey  = @nInputKey,

      V_OrderKey = @cOrderKey,
      V_LOC      = @cLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      --V_QTY      = @nQTY,
      
      V_Integer1  = @nQTY,
      V_Integer2  = @nTotalOrder,
      V_Integer3  = @nTotalTote,
      V_Integer4  = @nTotalPOS,
      V_Integer5  = @nTotalQTY,
      V_Integer6  = @nNextPage,
         
      V_FromScn   = @nFromScn,
      V_FromStep  = @nFromStep,

      V_String1  = @cCartID,
      V_String2  = @cPickZone,
      V_String3  = @cMethod,
      V_String4  = @cDPLKey,
      V_String5  = @cToteID,
      V_String6  = @cPosition,
      V_String7  = @cBatch,
      --V_String8  = @nTotalOrder,
      --V_String9  = @nTotalTote,
      --V_String10 = @nTotalPOS,
      --V_String11 = @nTotalQTY,
      --V_String12 = @nNextPage,
      V_String13 = @cOption,
      V_String14 = @cPickSeq,

      V_String20 = @cExtendedValidateSP,
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @cExtendedInfoSP,
      V_String23 = @cPTLPKZoneReq,
      V_String24 = @cAllowSkipTask,
      V_String25 = @cDecodeSP,
      V_String26 = @cLight,
      V_String27 = @cExtendedInfo,
      --V_String28 = @nFromScn,
      --V_String29 = @nFromStep,
      V_String30 = @cShortPickFlag,
   
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