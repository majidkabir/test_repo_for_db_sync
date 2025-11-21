SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PTLCart                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2015-04-05 1.0  Ung        SOS336903 Created                               */
/* 2015-05-05 1.1  Ung        SOS336312 Add assign WaveKey, SKU               */
/*                            SOS333663 Add assign Pickslip                   */
/*                            Replace DeviceProfileLog with rdt.rdtPTLCartLog */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2017-08-14 1.3  Ung        WMS-2671 Add PassOnCart                         */
/* 2017-11-27 1.4  Ung        WMS-3250 Fix split carton not prompt new carton */
/* 2018-02-05 1.5  James      WMS3893-Add DefaultDeviceID (james01)           */
/* 2018-05-21 1.6  Ung        WMS-5150 Add rdt format for NEW TOTE            */
/* 2018-05-03 1.6  James      WMS1933-Add Row & Col (james03)                 */
/* 2018-06-05 1.7  James      WMS-5312-Add rdt_decode (james02)               */
/* 2018-10-01 1.8  TungGH     Performance                                     */
/* 2018-01-03 1.9  Ung        WMS-3549 Add lottables                          */
/* 2018-01-26 2.0  Ung        Change to PTL.Schema                            */
/* 2018-03-15 2.1  Ung        WMS-4247 Add ExtendedInfoSP at SKU screen       */
/* 2019-03-07 2.2  Ung        WMS-8024 Add MatrixSP to code lookup            */
/* 2019-11-26 2.3  James      WMS-11089 Add ExtValidSP @ step 2, 6 (james04)  */
/*                            Clear CartID when finish picking (by config)    */
/* 2020-03-11 2.4  James      WMS-12512 Clear Cart ID screen field            */
/*                            (by config) (james05)                           */
/* 2020-02-10 2.5  James      WMS-11909-Add Loc.Descr & MultiSku scn (james06)*/
/* 2020-08-04 2.6  YeeKung    WMS-14246 Defaultmethod  (yeekung01)            */
/* 2021-06-24 2.7  GuoHui     JSM-5377 Retain step 3 when AllowSkipTask.      */
/* 2022-06-24 2.8  Ung        WMS-20046 Add piece scan                        */
/* 2023-04-04 2.9  Ung        WMS-22075 Add VerifyLOC                         */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PTLCart] (
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
   @nCount        INT,
   @bSuccess      INT,
   @nTranCount    INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @cWhere        NVARCHAR( MAX),
   @nRowCount     INT,
   @nMorePage     INT,
   @cNewToteID    NVARCHAR( 20),
   @nToteQTY      INT,
   @cLocDescr     NVARCHAR( 15),
   @tVar          VariableTable,
   @tExtValidVar  VariableTable, 
        
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

   @nFromScn      INT,                       
   @cOrderKey     NVARCHAR(10),
   @cLOC          NVARCHAR(10),
   @cSKU          NVARCHAR(20),
   @cSKUDescr     NVARCHAR(60),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,

   @nTotalOrder   INT,
   @nTotalTote    INT,
   @nTotalPOS     INT,
   @nTotalQTY     INT,
   @nNextPage     INT,
   @nPieceQTY     INT, 
   @nMatrixQTY    INT, 

   @cCartID                NVARCHAR( 10),
   @cPickZone              NVARCHAR( 10),
   @cMethod                NVARCHAR( 1),
   @cDPLKey                NVARCHAR( 10),
   @cToteID                NVARCHAR( 20),
   @cPosition              NVARCHAR( 10),
   @cBatch                 NVARCHAR( 10),
   @cClearCartIDScnField   NVARCHAR( 10),
   @cLocShowDescr          NVARCHAR( 1), 
   @cMultiSKUBarcode       NVARCHAR( 1), 
   @cOption                NVARCHAR( 1),
   @cPickSeq               NVARCHAR( 1),
   @cRow                   NVARCHAR( 5), 
   @cCol                   NVARCHAR( 5), 
   @cLottableCode          NVARCHAR( 20),

   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cPTLPKZoneReq          NVARCHAR( 20),
   @cAllowSkipTask         NVARCHAR( 1),
   @cDecodeLabelNo         NVARCHAR( 20),
   @cLight                 NVARCHAR( 1),
   @cExtendedInfo          NVARCHAR( 20),
   @cPassOnCart            NVARCHAR( 1),
   @cDecodeSP              NVARCHAR( 20),
   @cDefaultMethod         NVARCHAR( 1), 
   @cVerifyPiece           NVARCHAR( 1),
   @cVerifyLOC             NVARCHAR( 1),

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

   @nFromScn    = V_FromScn,
   @cOrderKey   = V_OrderKey,
   @cLOC        = V_LOC,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = V_QTY,
   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @nTotalOrder = V_Integer1,
   @nTotalTote  = V_Integer2,
   @nTotalPOS   = V_Integer3,
   @nTotalQTY   = V_Integer4,
   @nNextPage   = V_Integer5,
   @nPieceQTY   = V_Integer6,
   @nMatrixQTY  = V_Integer7,

   @cCartID                = V_String1,
   @cPickZone              = V_String2,
   @cMethod                = V_String3,
   @cDPLKey                = V_String4,
   @cToteID                = V_String5,
   @cPosition              = V_String6,
   @cBatch                 = V_String7,
   @cClearCartIDScnField   = V_String8,
   @cLocShowDescr          = V_String9,
   @cMultiSKUBarcode       = V_String10,

   @cOption                = V_String13,
   @cPickSeq               = V_String14,
   @cRow                   = V_String15,
   @cCol                   = V_String16,
   @cLottableCode          = V_String17,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cPTLPKZoneReq       = V_String23,
   @cAllowSkipTask      = V_String24,
   @cDecodeLabelNo      = V_String25,
   @cLight              = V_String26,
   @cExtendedInfo       = V_String27,
   @cPassOnCart         = V_String28,
   @cDecodeSP           = V_String29,
   @cDefaultMethod      = V_String30,--(yeekung01)
   @cVerifyPiece        = V_String31,
   @cVerifyLOC          = V_String32,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_CartID        INT,  @nScn_CartID         INT,
   @nStep_Assign        INT,  @nScn_Assign         INT,
   @nStep_SKU           INT,  @nScn_SKU            INT,
   @nStep_Matrix        INT,  @nScn_Matrix         INT,
   @nStep_CloseTote     INT,  @nScn_CloseTote      INT,
   @nStep_NewTote       INT,  @nScn_NewTote        INT,
   @nStep_Unassign      INT,  @nScn_Unassign       INT,
   @nStep_MultiSKU      INT,  @nScn_MultiSKU       INT,
   @nStep_VerifyLOC     INT,  @nScn_VerifyLOC      INT

SELECT
   @nStep_CartID        = 1,  @nScn_CartID         = 4130,
   @nStep_Assign        = 2,  @nScn_Assign         = 4131,
   @nStep_SKU           = 3,  @nScn_SKU            = 4132,
   @nStep_Matrix        = 4,  @nScn_Matrix         = 4133,
   @nStep_CloseTote     = 5,  @nScn_CloseTote      = 4134,
   @nStep_NewTote       = 6,  @nScn_NewTote        = 4135,
   @nStep_Unassign      = 7,  @nScn_Unassign       = 4136,
   @nStep_MultiSKU      = 8,  @nScn_MultiSKU       = 3570,
   @nStep_VerifyLOC     = 9,  @nScn_VerifyLOC      = 4137

IF @nFunc = 808  -- PTL Cart
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start       -- PTL Cart
   IF @nStep = 1 GOTO Step_CartID      -- Scn = 4130. CartID, PickZone, Method
   IF @nStep = 2 GOTO Step_Assign      -- Scn = 4131. Dynamic assign
   IF @nStep = 3 GOTO Step_SKU         -- Scn = 4132. SKU
   IF @nStep = 4 GOTO Step_Matrix      -- Scn = 4133. Matrix
   IF @nStep = 5 GOTO Step_CloseTote   -- Scn = 4134. Close tote, QTY
   IF @nStep = 6 GOTO Step_NewTote     -- Scn = 4135. New tote
   IF @nStep = 7 GOTO Step_Unassign    -- Scn = 4136. Unassign cart?
   IF @nStep = 8 GOTO Step_MultiSKU    -- Scn = 3570. Multi SKU Barocde
   IF @nStep = 9 GOTO Step_VerifyLOC   -- Scn = 4137. Verify LOC
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 810. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cAllowSkipTask = rdt.rdtGetConfig( @nFunc, 'AllowSkipTask', @cStorerKey)
   SET @cClearCartIDScnField = rdt.RDTGetConfig( @nFunc, 'ClearCartIDScnField', @cStorerKey)
   SET @cLocShowDescr = rdt.RDTGetConfig( @nFunc, 'LocShowDescr', @cStorerkey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cPassOnCart = rdt.rdtGetConfig( @nFunc, 'PassOnCart', @cStorerKey)
   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   SET @cVerifyLOC = rdt.RDTGetConfig( @nFunc, 'VerifyLOC', @cStorerKey)
   SET @cVerifyPiece = rdt.rdtGetConfig( @nFunc, 'VerifyPiece', @cStorerKey)
   
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultMethod =  rdt.RDTGetConfig( @nFunc, 'Defaultmethod', @cStorerKey) --(yeekung01)
   IF @cDefaultMethod = '0'
      SET @cDefaultMethod = ''
   SET @cDecodeLabelNo = rdt.rdtGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

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
   SET @cOutField01 = CASE WHEN CHARINDEX ( '1', @cClearCartIDScnField) = 0 AND @cDeviceID <> '' THEN
                      @cDeviceID ELSE '' END -- Cart id  (james01)
   SET @cOutField02 = '' -- Pickzone
   SET @cOutField03 = CASE WHEN @cDefaultMethod<>'' THEN @cDefaultMethod ELSE '' END-- Method  --(yeekung01)
   SET @cOutField04 = '' -- PickSeq
   SET @cOutField05 = '' -- Col
   SET @cOutField06 = '' -- Row

   SET @cCol = '0'
   SET @cRow = '0'

   IF ISNULL( @cOutField01, '') <> ''
   BEGIN
      SELECT TOP 1
         @cRow = [Row], -- Default 0
         @cCol = [Col]  -- Default 0
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cDeviceID
      ORDER BY DeviceID
   END

   SET @cOutField05 = CASE WHEN @cCol = '0' THEN '' ELSE @cCol END -- Col
   SET @cOutField06 = CASE WHEN @cRow = '0' THEN '' ELSE @cRow END -- Row

   -- Set the entry point
   SET @nScn = @nScn_CartID
   SET @nStep = @nStep_CartID

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4130.
   CartID   (Field01, input)
   PickZone (Field02, input)
   Method   (Field03, input)
   PickSeq  (Field04, input)
   Col      (Field05, input)
   Row      (Field06, input)
********************************************************************************/
Step_CartID:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cCartID = @cInField01
      SET @cPickZone = @cInField02
      SET @cMethod = @cInField03
      SET @cPickSeq = @cInField04
      SET @cCol = @cInField05
      SET @cRow = @cInField06

      -- Retain value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06

      -- Check blank
      IF @cCartID = ''
      BEGIN
         SET @nErrNo = 53401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check cart valid
      IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceType = 'CART' AND DeviceID = @cCartID)
      BEGIN
         SET @nErrNo = 53402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check cart use by other
      IF @cPassOnCart <> '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND AddWho <> @cUserName)
         BEGIN
            SET @nErrNo = 53403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      SET @cOutField01 = @cCartID

      -- Check pickzone
      IF @cPickZone = ''
      BEGIN
         -- Check blank
         IF @cPTLPKZoneReq = '1'
         BEGIN
            SET @nErrNo = 53404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check pickzone valid
         IF NOT EXISTS( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Facility = @cFacility AND PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 53405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKZone
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO Quit
         END
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
         SET @nErrNo = 53406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMethodSP
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Check method SP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMethodSP AND type = 'P')
      BEGIN
         SET @nErrNo = 53407
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Method SP
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      SET @cOutField03 = @cMethod

      -- Check pick seq
      IF @cPickSeq <> ''
      BEGIN
         -- Check PickSeq valid
         IF NOT EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'PTLPickOrd' AND StorerKey = @cStorerKey AND Code = @cPickSeq)
         BEGIN
            SET @nErrNo = 53424
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad pick seq
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- PickSeq
            SET @cOutField04 = ''
            GOTO Quit
         END
      END
      SET @cOutfield04 = @cPickSeq

      -- Col is optional. Can be blank or 0
      IF @cCol <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cCol, 0) = 0
         BEGIN
            SET @nErrNo = 53429
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Col
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- Col
            SET @cOutField05 = ''
            GOTO Quit
         END

         -- Check col max
         IF CAST( @cCol AS INT) > 10
         BEGIN
            SET @nErrNo = 53430
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over max Col
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- Col
            SET @cOutField05 = ''
            GOTO Quit
         END

         SET @cOutfield05 = @cCol
      END

      -- Row is optional. Can be blank or 0
      IF @cRow <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cRow, 0) = 0
         BEGIN
            SET @nErrNo = 53431
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Row
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- Row
            SET @cOutField06 = ''
            GOTO Quit
         END

         -- Check row max
         IF CAST( @cRow AS INT) > 5
         BEGIN
            SET @nErrNo = 53432
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over max Row
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- Row
            SET @cOutField06 = ''
            GOTO Quit
         END

         SET @cOutfield06 = @cRow
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
            @cPickZone = CASE WHEN @cPassOnCart = '1' THEN @cPickZone ELSE PickZone END,
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
            SET @nErrNo = 53408
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

      SET @nStep = @nStep_Assign
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
Step_Assign:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- (james04)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @tExtValidVar  VariableTable READONLY, ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SELECT @cLOC = '', @cSKU = '', 
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get task
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
         ,@cLottableCode OUTPUT
         ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
         ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
         ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get LOC desc
      IF @cLocShowDescr = '1'
      BEGIN
         SELECT @cLocDescr = LEFT( ISNULL( Descr, ''), 15)
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOC = @cLOC
         IF @cLocDescr = ''
            SET @cLocDescr = @cLOC
      END

      -- Verify LOC
      IF @cVerifyLOC = '1'
      BEGIN
         SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
         SET @cOutField02 = '' -- LOC
         
         SET @nStep = @nStep_VerifyLOC
         SET @nScn = @nScn_VerifyLOC
         
         GOTO Quit
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 8,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      SET @nPieceQTY = 0
      SET @nMatrixQTY = @nTotalQTY

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
      SET @cOutField07 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLight         NVARCHAR( 1),  ' +
               ' @cDPLKey        NVARCHAR( 10), ' +
               ' @cCartID        NVARCHAR( 10), ' +
               ' @cPickZone      NVARCHAR( 10), ' +
               ' @cMethod        NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @cToteID        NVARCHAR( 20), ' +
               ' @nQTY           INT,           ' +
               ' @cNewToteID     NVARCHAR( 20), ' +
               ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
               ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +
               ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,  @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
               ' @tVar           VariableTable  READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_Assign, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3 -- SKU
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0
   BEGIN
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
      BEGIN
         -- Prep next screen var
         SET @cOutfield01 = '' -- Option

         -- Go to unassign cart screen
         SET @nScn = @nScn_Unassign
         SET @nStep = @nStep_Unassign
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
         SET @cOutfield01 = CASE WHEN CHARINDEX( '1', @cClearCartIDScnField) = '0' THEN @cCartID ELSE '' END   --@cCartID
         SET @cOutfield02 = CASE WHEN CHARINDEX( '2', @cClearCartIDScnField) = '0' THEN @cPickZone ELSE '' END --@cPickZone
         SET @cOutfield03 = CASE WHEN CHARINDEX( '3', @cClearCartIDScnField) = '0' THEN @cMethod ELSE '' END   --@cMethod
         SET @cOutfield04 = CASE WHEN CHARINDEX( '4', @cClearCartIDScnField) = '0' THEN @cPickSeq ELSE '' END  --@cPickSeq
         SET @cOutfield05 = CASE WHEN CHARINDEX( '5', @cClearCartIDScnField) = '0' THEN @cCol ELSE '' END      --@cCol
         SET @cOutfield06 = CASE WHEN CHARINDEX( '6', @cClearCartIDScnField) = '0' THEN @cRow ELSE '' END      --@cRow

         IF @cOutfield01 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Cart ID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

         -- Go to cart screen
         SET @nScn = @nScn_CartID
         SET @nStep = @nStep_CartID
      END
   END
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 4132. SKU screen
   LOC      (Field01)
   SKU      (Field02)
   SKU      (Field03, input)
   Descr 1  (Field04)
   Descr 2  (Field05)
   TotalPOS (Field06)
   TotalQTY (Field07)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cActSKU NVARCHAR(40)
      DECLARE @cBarcode NVARCHAR(60)

      -- Screen mapping
      SET @cActSKU = @cInField03
      SET @cBarcode = @cInField03

      -- Skip task
      IF @cActSKU = '' AND @nPieceQTY = 0 
      BEGIN
         -- Check blank
         IF @cAllowSkipTask <> '1' -- 1=Yes
         BEGIN
            SET @nErrNo = 53409
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU needed
            GOTO Quit
         END

         -- Get next task
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
            ,@cLottableCode OUTPUT
            ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
            ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
            ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT

         IF @nErrNo <> 0 -- No More Task!
            GOTO Step_SKU_Fail

         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 8,
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nMorePage   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT,
            '',      -- SourceKey
            @nFunc   -- SourceType

         -- Get LOC desc
         IF @cLocShowDescr = '1'
         BEGIN
            SELECT @cLocDescr = LEFT( ISNULL( Descr, ''), 15)
            FROM dbo.LOC WITH (NOLOCK)
            WHERE Facility = @cFacility
               AND LOC = @cLOC
            IF @cLocDescr = ''
               SET @cLocDescr = @cLOC
         END
         SET @nPieceQTY = 0
         SET @nMatrixQTY = @nTotalQTY

         -- Prepare next screen var
         SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
         SET @cOutField02 = @cSKU
         SET @cOutField03 = '' -- @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutfield06 = CAST( @nTotalPOS AS NVARCHAR( 5))
         SET @cOutfield07 = CAST( @nTotalQTY AS NVARCHAR( 5))
         SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
         SET @cOutField15 = '' -- ExtendedInfo

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nAfterStep     INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cLight         NVARCHAR( 1),  ' +
                  ' @cDPLKey        NVARCHAR( 10), ' +
                  ' @cCartID        NVARCHAR( 10), ' +
                  ' @cPickZone      NVARCHAR( 10), ' +
                  ' @cMethod        NVARCHAR( 10), ' +
                  ' @cLOC           NVARCHAR( 10), ' +
                  ' @cSKU           NVARCHAR( 20), ' +
                  ' @cToteID        NVARCHAR( 20), ' +
                  ' @nQTY           INT,           ' +
                  ' @cNewToteID     NVARCHAR( 20), ' +
                  ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
                  ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +
                  ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,      @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
                  ' @tVar           VariableTable  READONLY, ' +
                  ' @cExtendedInfo  NVARCHAR( 20)  OUTPUT,   ' +
                  ' @nErrNo         INT            OUTPUT,   ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit

               IF @nStep = 3 -- SKU
                  SET @cOutField15 = @cExtendedInfo
            END
         END

         IF @cAllowSkipTask = '1' -- 1=Yes -- (JSM-5377)
         BEGIN
            GOTO Quit
         END
      END

      -- SKU scanned
      IF @cActSKU <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC    = @cActSKU OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UPC'
         END
         ELSE
         BEGIN
            -- Decode
            IF @cDecodeLabelNo <> ''
            BEGIN
               DECLARE
                  @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20), @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20), @c_oFieled05 NVARCHAR(20),
                  @c_oFieled06 NVARCHAR(20), @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20), @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

               EXEC dbo.ispLabelNo_Decoding_Wrapper
                   @c_SPName     = @cDecodeLabelNo
                  ,@c_LabelNo    = @cActSKU
                  ,@c_Storerkey  = @cStorerKey
                  ,@c_ReceiptKey = @nMobile
                  ,@c_POKey      = ''
                  ,@c_LangCode   = @cLangCode
                  ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
                  ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
                  ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
                  ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
                  ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
                  ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
                  ,@c_oFieled07  = @c_oFieled07 OUTPUT
                  ,@c_oFieled08  = @c_oFieled08 OUTPUT
                  ,@c_oFieled09  = @c_oFieled09 OUTPUT
                  ,@c_oFieled10  = @c_oFieled10 OUTPUT
                  ,@b_Success    = @bSuccess    OUTPUT
                  ,@n_ErrNo      = @nErrNo      OUTPUT
                  ,@c_ErrMsg     = @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_SKU_Fail

               SET @cActSKU = @c_oFieled01
            END
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
            SET @nErrNo = 53410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO Step_SKU_Fail
         END

         -- (james06)
         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            -- (james03)
            IF @cMultiSKUBarcode IN ('1', '2')
            BEGIN
               EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
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
                  @cStorerKey,
                  @cActSKU  OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT,
                  'PTLTRAN.CART',    -- DocType
                  @cCartID

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nScn = @nScn_MultiSKU
                  SET @nStep = @nStep_MultiSKU
                  GOTO Quit
               END
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               BEGIN
                  SET @nErrNo = 0
                  SET @cSKU = @cActSKU
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 53433
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               GOTO Step_SKU_Fail
            END

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
            SET @nErrNo = 53411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_SKU_Fail
         END

         -- Check SKU match
         IF @cSKU <> @cActSKU
         BEGIN
            SET @nErrNo = 53412
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different SKU
            IF @cVerifyPiece = '1'
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cErrMsg
               SET @cErrMsg = ''
            END
            GOTO Step_SKU_Fail
         END
      END
      
      -- Piece scan
      IF @cVerifyPiece = '1' AND @cBarcode <> ''
      BEGIN
         -- Check over pick
         IF @nPieceQTY + 1 > @nTotalQTY
         BEGIN
            SET @nErrNo = 53434
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
            GOTO Step_SKU_Fail
         END
         
         -- Top up QTY
         SET @nPieceQTY += 1

         -- Not fully scan
         IF @nPieceQTY < @nTotalQTY
         BEGIN
            -- Remain in current screen
            SET @cOutField03 = '' -- SKU
            SET @cOutField12 = CAST( @nPieceQTY AS NVARCHAR(3))
            GOTO Quit
         END
      END

      -- Draw matrix (and light up)
      SET @nNextPage = 0
      EXEC rdt.rdt_PTLCart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode
         ,@cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05
         ,@cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10
         ,@cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15
         ,@nErrNo     OUTPUT,  @cErrMsg    OUTPUT
         ,@cResult01  OUTPUT,  @cResult02  OUTPUT,  @cResult03  OUTPUT,  @cResult04  OUTPUT,  @cResult05  OUTPUT
         ,@cResult06  OUTPUT,  @cResult07  OUTPUT,  @cResult08  OUTPUT,  @cResult09  OUTPUT,  @cResult10  OUTPUT
         ,@nNextPage  OUTPUT
         ,@cCol
         ,@cRow
         ,@cMethod

      IF @nErrNo <> 0
         GOTO Step_SKU_Fail

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
      SET @nScn = @nScn_Matrix
      SET @nStep = @nStep_Matrix
   END

   IF @nInputKey = 0
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

      SET @nStep = @nStep_Assign

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLight         NVARCHAR( 1),  ' +
               ' @cDPLKey        NVARCHAR( 10), ' +
               ' @cCartID        NVARCHAR( 10), ' +
               ' @cPickZone      NVARCHAR( 10), ' +
               ' @cMethod        NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @cToteID        NVARCHAR( 20), ' +
               ' @nQTY           INT,           ' +
               ' @cNewToteID     NVARCHAR( 20), ' +
               ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
               ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +
               ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,      @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
               ' @tVar           VariableTable  READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            --IF @nStep = 3 -- SKU
            --   SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cOutField03 = '' -- SKU
   END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 4133. Maxtrix screen
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
Step_Matrix:
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
            SET @nErrNo = 53413
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Quit
         END

         -- Use light
         IF @cLight = '1'
         BEGIN
            -- Short not allow
            IF @cOption = '9'
            BEGIN
               SET @nErrNo = 53414
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UseLight2Short
               GOTO Quit
            END

            -- Disable QTY field
            SET @cFieldAttr02 = 'O' -- QTY
         END

         -- Prepare next screen var
         SET @cOutField01 = '' -- ToteID
         SET @cOutField02 = '' -- QTY

         EXEC rdt.rdtSetFocusField @nMobile, 1 --ToteID

         -- Go to close tote screen
         SET @nScn = @nScn_CloseTote
         SET @nStep = @nStep_CloseTote

         GOTO Quit
      END

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PTLCart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode
         ,@cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05
         ,@cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10
         ,@cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15
         ,@nErrNo     OUTPUT,  @cErrMsg    OUTPUT
         ,@cResult01  OUTPUT,  @cResult02  OUTPUT,  @cResult03  OUTPUT,  @cResult04  OUTPUT,  @cResult05  OUTPUT
         ,@cResult06  OUTPUT,  @cResult07  OUTPUT,  @cResult08  OUTPUT,  @cResult09  OUTPUT,  @cResult10  OUTPUT
         ,@nNextPage  OUTPUT
         ,@cCol
         ,@cRow
         ,@cMethod

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

      -- Confirm (for non-light)
      IF @cLight = '0'
      BEGIN
         IF @cVerifyPiece = '1'
         BEGIN
            -- Check QTY scan, QTY confirm not tally
            IF @nPieceQTY <> @nMatrixQTY
            BEGIN
               SET @nErrNo = 53435
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTYScanConfDif
               GOTO Quit
            END
         END
         
         EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
            ,@cDPLKey
            ,@cMethod
            ,@cCartID
            ,'' -- @cToteID
            ,@cLOC
            ,@cSKU
            ,0  -- @cQTY
            ,'' -- @cNewToteID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLottableCode
            ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
            ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
            ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
         IF @nErrNo <> 0
            GOTO Quit
      END

      SET @nRowCount = 0

      -- Get confirm SP info
      DECLARE @cConfirmSP SYSNAME
      SET @cConfirmSP = ''
      SELECT @cConfirmSP = ISNULL( UDF03, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'CartMethod'
         AND Code = @cMethod
         AND StorerKey = @cStorerKey

      -- Detect lottables
      IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cConfirmSP) AND name = '@cLottableCode')
      BEGIN
         SET @cSQL =
            ' SELECT TOP 1 ' +
               ' @nRowCount = 1 ' +
            ' FROM PTL.PTLTran WITH (NOLOCK) ' +
            ' WHERE DeviceProfileLogKey = @cDPLKey ' +
               ' AND SKU = @cSKU ' +
               ' AND LOC = @cLOC ' +
               ' AND Status <> ''9'' '

         -- Get lottable filter
         EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'PTLTran',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cWhere   OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT

         -- Lottable filter
         IF @cWhere <> ''
            SET @cSQL = @cSQL + ' AND ' + @cWhere

         SET @cSQLParam =
            ' @cDPLKey     NVARCHAR( 10), ' +
            ' @cLOC        NVARCHAR( 10), ' +
            ' @cSKU        NVARCHAR( 15), ' +
            ' @cLottable01 NVARCHAR( 18), ' +
            ' @cLottable02 NVARCHAR( 18), ' +
            ' @cLottable03 NVARCHAR( 18), ' +
            ' @dLottable04 DATETIME,      ' +
            ' @dLottable05 DATETIME,      ' +
            ' @cLottable06 NVARCHAR( 30), ' +
            ' @cLottable07 NVARCHAR( 30), ' +
            ' @cLottable08 NVARCHAR( 30), ' +
            ' @cLottable09 NVARCHAR( 30), ' +
            ' @cLottable10 NVARCHAR( 30), ' +
            ' @cLottable11 NVARCHAR( 30), ' +
            ' @cLottable12 NVARCHAR( 30), ' +
            ' @dLottable13 DATETIME,      ' +
            ' @dLottable14 DATETIME,      ' +
            ' @dLottable15 DATETIME,      ' +
            ' @nRowCount   INT     OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cDPLKey, @cLOC, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowCount OUTPUT
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @nRowCount = 1
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND SKU = @cSKU
            AND LOC = @cLOC
            AND Status <> '9'
      END

      -- Check pick completed (light and no light)
      IF @nRowCount > 0
      BEGIN
         SET @nErrNo = 53415
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
         GOTO Quit
      END

      -- Get next task
      DECLARE @cCurrentLOC NVARCHAR( 10) = @cLOC
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
         ,@cLottableCode OUTPUT
         ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
         ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
         ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT

      IF @nErrNo <> 0 -- No More Task!
      BEGIN
         IF @cAllowSkipTask = '1'
         BEGIN
            SELECT @cLOC = '', @cSKU = '',
               @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
               @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
               @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

            -- Get next task
            SET @nErrNo = 0
            EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LOC'
               ,@cLight
               ,@cCartID
               ,@cPickZone
               ,@cMethod
               ,@cPickSeq
               ,'' -- @cToteID
               ,@cDPLKey
               ,@nErrNo        OUTPUT
               ,@cErrMsg       OUTPUT
               ,@cLOC OUTPUT
               ,@cSKU          OUTPUT
               ,@cSKUDescr     OUTPUT
               ,@nTotalPOS     OUTPUT
               ,@nTotalQTY     OUTPUT
               ,@nToteQTY      OUTPUT
               ,@cLottableCode OUTPUT
               ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
               ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
               ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
         END

         IF @nErrNo <> 0 -- No More Task!
         BEGIN
            SET @nErrNo = 0 -- Reset error from GetTask

            -- Extended info (exception: need to place it before close cart, as it might need rdtPTLCartLog info)
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  SET @cExtendedInfo = ''
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                     ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
                     ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                     ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                     ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                     ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     ' @nMobile        INT,           ' +
                     ' @nFunc          INT,           ' +
                     ' @cLangCode      NVARCHAR( 3),  ' +
                     ' @nStep          INT,           ' +
                     ' @nAfterStep     INT,           ' +
                     ' @nInputKey      INT,           ' +
                     ' @cFacility      NVARCHAR( 5),  ' +
                     ' @cStorerKey     NVARCHAR( 15), ' +
                     ' @cLight         NVARCHAR( 1),  ' +
                     ' @cDPLKey        NVARCHAR( 10), ' +
                     ' @cCartID        NVARCHAR( 10), ' +
                     ' @cPickZone      NVARCHAR( 10), ' +
                     ' @cMethod        NVARCHAR( 10), ' +
                     ' @cLOC           NVARCHAR( 10), ' +
                     ' @cSKU           NVARCHAR( 20), ' +
                     ' @cToteID        NVARCHAR( 20), ' +
                     ' @nQTY           INT,           ' +
                     ' @cNewToteID     NVARCHAR( 20), ' +
                     ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
                     ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +                       ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,      @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
                     ' @tVar           VariableTable  READONLY, ' +
                     ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
                     ' @nErrNo         INT           OUTPUT, ' +
                     ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep_Matrix, @nStep_CartID, @nInputKey, @cFacility, @cStorerKey,
                     @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                     @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit

                  IF @nStep = 3 -- SKU
                     SET @cOutField15 = @cExtendedInfo
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
               GOTO Quit

            -- Prepare next screen var
            SET @cOutfield01 = CASE WHEN CHARINDEX( '1', @cClearCartIDScnField) = '0' THEN @cCartID ELSE '' END   --@cCartID
            SET @cOutfield02 = CASE WHEN CHARINDEX( '2', @cClearCartIDScnField) = '0' THEN @cPickZone ELSE '' END --@cPickZone
            SET @cOutfield03 = CASE WHEN CHARINDEX( '3', @cClearCartIDScnField) = '0' THEN @cMethod ELSE '' END   --@cMethod
            SET @cOutfield04 = CASE WHEN CHARINDEX( '4', @cClearCartIDScnField) = '0' THEN @cPickSeq ELSE '' END  --@cPickSeq
            SET @cOutfield05 = CASE WHEN CHARINDEX( '5', @cClearCartIDScnField) = '0' THEN @cCol ELSE '' END      --@cCol
            SET @cOutfield06 = CASE WHEN CHARINDEX( '6', @cClearCartIDScnField) = '0' THEN @cRow ELSE '' END      --@cRow

            IF @cOutfield01 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 1 --Cart ID
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 2 --PickZone

            -- Go to CartID screen
            SET @nScn = @nScn_CartID
            SET @nStep = @nStep_CartID

            GOTO Quit
         END
      END

      -- Get LOC desc
      IF @cLocShowDescr = '1'
      BEGIN
         SELECT @cLocDescr = LEFT( ISNULL( Descr, ''), 15)
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOC = @cLOC
         IF @cLocDescr = ''
            SET @cLocDescr = @cLOC
      END

      -- Verify LOC
      IF @cVerifyLOC = '1'
      BEGIN
         -- Different LOC
         IF @cLOC <> @cCurrentLOC
         BEGIN
            SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
            SET @cOutField02 = '' -- LOC
            
            SET @nStep = @nStep_VerifyLOC
            SET @nScn = @nScn_VerifyLOC
            
            GOTO Quit
         END
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 8,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      SET @nPieceQTY = 0
      SET @nMatrixQTY = @nTotalQTY

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutfield06 = CAST( @nTotalPOS AS NVARCHAR( 5))
      SET @cOutfield07 = CAST( @nTotalQTY AS NVARCHAR( 5))
      SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0
   BEGIN
      -- Draw matrix (and light up)
      EXEC rdt.rdt_PTLCart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode
         ,@cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05
         ,@cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10
         ,@cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15
         ,@nErrNo     OUTPUT,  @cErrMsg    OUTPUT
         ,@cResult01  OUTPUT,  @cResult02  OUTPUT,  @cResult03  OUTPUT,  @cResult04  OUTPUT,  @cResult05  OUTPUT
         ,@cResult06  OUTPUT,  @cResult07  OUTPUT,  @cResult08  OUTPUT,  @cResult09  OUTPUT,  @cResult10  OUTPUT
         ,@nNextPage  OUTPUT
         ,@cCol
         ,@cRow
         ,@cMethod

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

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 8,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      SELECT @cLocDescr = SUBSTRING( Descr, 1, 20)
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Facility = @cFacility
      AND LOC = @cLOC

      IF ISNULL( @cLocDescr, '') = ''
         SET @cLocDescr = @cLOC

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutfield06 = CAST( @nTotalPOS AS NVARCHAR( 5))
      SET @cOutfield07 = CAST( @nTotalQTY AS NVARCHAR( 5))
      SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
      SET @cOutField15 = '' -- ExtendedInfo

      -- Back to SKU Screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU

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
         WHERE DeviceID = @cCartID
            AND DeviceType = 'CART'
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
            WHERE Loc = @cLoc
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

         -- Off all lights
--         EXEC dbo.isp_DPC_TerminateAllLight
--             @cStorerKey
--            ,@cCartID
--            ,@bSuccess    OUTPUT
--            ,@nErrNo       OUTPUT
--            ,@cErrMsg      OUTPUT

         -- Off all lights
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cCartID
            ,'0'
            ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

Step_Matrix_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cLight         NVARCHAR( 1),  ' +
            ' @cDPLKey        NVARCHAR( 10), ' +
            ' @cCartID        NVARCHAR( 10), ' +
            ' @cPickZone      NVARCHAR( 10), ' +
            ' @cMethod        NVARCHAR( 10), ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @cToteID        NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cNewToteID     NVARCHAR( 20), ' +
            ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
            ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +
            ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,      @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_Matrix, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         IF @nStep = 3 -- SKU
            SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO QUIT


/********************************************************************************
Step 5. Scn = 4134. Old tote screen
   ToteID   (field01, input)
   QTY      (field02, input)
********************************************************************************/
Step_CloseTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cQTY     NVARCHAR(5)

      -- Screen mapping
      SET @cToteID = @cInField01
      SET @cQTY = CASE WHEN @cFieldAttr02 = 'O' THEN '' ELSE @cInField02 END

      -- Check blank
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 53416
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check tote on cart
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = @cToteID)
      BEGIN
         SET @nErrNo = 53417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cToteID

      -- Get current task QTY
      EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENTTOTE'
         ,@cLight
         ,@cCartID
         ,@cPickZone
         ,@cMethod
         ,@cPickSeq
         ,@cToteID
         ,@cDPLKey
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLOC       OUTPUT
         ,@cSKU       OUTPUT
         ,@cSKUDescr  OUTPUT
         ,@nTotalPOS  OUTPUT
         ,@nTotalQTY  OUTPUT
         ,@nToteQTY   OUTPUT
         ,@cLottableCode OUTPUT
         ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
         ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
         ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT

      -- Use light
      IF @cLight = '1'
      BEGIN
         -- Check carton no task
         IF @nToteQTY = 0
         BEGIN
            SET @nErrNo = 53427
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote no task
            GOTO Quit
         END

         SET @nQTY = 0
      END
      ELSE
      BEGIN
         -- Check tote no task but key-in QTY
         IF @nToteQTY = 0 AND @cQTY <> ''
         BEGIN
            SET @nErrNo = 53418
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote no task
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check tote have task but not confirm QTY
         IF @nToteQTY > 0 AND @cQTY = ''
         BEGIN
            SET @nErrNo = 53419
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY
            GOTO Quit
         END

         -- Check QTY valid
         IF rdt.rdtIsValidQTY( @cQTY, 0) = 0 -- Not check zero QTY
         BEGIN
            SET @nErrNo = 53420
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY
            GOTO Quit
         END
         SET @nQTY = CAST( @cQTY AS INT)

         -- Check over pick
         IF @nQTY > @nToteQTY
         BEGIN
            SET @nErrNo = 53421
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY
            GOTO Quit
         END
      END

      -- Close
      IF @cOption = '1'
      BEGIN
         -- Current task fully packed
         IF @nQTY = @nToteQTY
         BEGIN
            -- Get next task QTY
            EXEC rdt.rdt_PTLCart_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTTOTE'
               ,@cLight
               ,@cCartID
               ,@cPickZone
               ,@cMethod
               ,@cPickSeq
               ,@cToteID
               ,@cDPLKey
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cLOC       OUTPUT
               ,@cSKU       OUTPUT
               ,@cSKUDescr  OUTPUT
               ,@nTotalPOS  OUTPUT
               ,@nTotalQTY  OUTPUT
               ,@nToteQTY   OUTPUT
               ,@cLottableCode OUTPUT
               ,@cLottable01   OUTPUT, @cLottable02  OUTPUT, @cLottable03 OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
               ,@cLottable06   OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
               ,@cLottable11   OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT

            IF @nErrNo <> 0   -- No more next task
            BEGIN
               SET @nErrNo = 0

               -- Confirm
               EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSETOTE'
                  ,@cDPLKey
                  ,@cMethod
                  ,@cCartID
                  ,@cToteID
                  ,@cLOC
                  ,@cSKU
                  ,@nQTY
                  ,'' -- @cNewToteID
                  ,@nErrNo     OUTPUT
                  ,@cErrMsg    OUTPUT
                  ,@cLottableCode
                  ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
                  ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
                  ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
               IF @nErrNo <> 0
                  GOTO Quit
            END
            ELSE
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '' -- New tote

               -- Go to new tote screen
               SET @nScn = @nScn_NewTote
               SET @nStep = @nStep_NewTote

               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- New tote

            -- Go to new tote screen
            SET @nScn = @nScn_NewTote
            SET @nStep = @nStep_NewTote

            GOTO Quit
         END
      END

      -- Short
      IF @cOption = '9'
      BEGIN
         -- Confirm
         EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SHORTTOTE'
            ,@cDPLKey
            ,@cMethod
            ,@cCartID
            ,@cToteID
            ,@cLOC
            ,@cSKU
            ,@nQTY
            ,'' -- @cNewToteID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
            ,@cLottableCode
            ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
            ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
            ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
         IF @nErrNo <> 0
            GOTO Quit
      
         -- Reduce the short QTY
         SET @nMatrixQTY = @nMatrixQTY - (@nToteQTY - @nQTY)
      END
   END

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLCart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode
      ,@cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05
      ,@cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10
      ,@cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15
      ,@nErrNo     OUTPUT,  @cErrMsg    OUTPUT
      ,@cResult01  OUTPUT,  @cResult02  OUTPUT,  @cResult03  OUTPUT,  @cResult04  OUTPUT,  @cResult05  OUTPUT
      ,@cResult06  OUTPUT,  @cResult07  OUTPUT,  @cResult08  OUTPUT,  @cResult09  OUTPUT,  @cResult10  OUTPUT
      ,NULL -- @nNextPage  OUTPUT
      ,@cCol
      ,@cRow
      ,@cMethod

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
   SET @cFieldAttr02 = '' -- QTY

   -- Go to matrix screen
   SET @nScn = @nScn_Matrix
   SET @nStep = @nStep_Matrix
END
GOTO QUIT


/********************************************************************************
Step 6. Scn = 4135. New tote screen
   New ToteID   (field01, input)
********************************************************************************/
Step_NewTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewToteID = @cInField01

      -- Check blank
      IF @cNewToteID = ''
      BEGIN
         SET @nErrNo = 53422
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need new Tote
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check tote on cart
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cNewToteID)
      BEGIN
         SET @nErrNo = 53423
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Existing Tote
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cNewToteID) = 0
      BEGIN
         SET @nErrNo = 53428
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- (james04)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               ' @cLOC       NVARCHAR( 10), ' +
               ' @cSKU       NVARCHAR( 20), ' +
               ' @cToteID    NVARCHAR( 20), ' +
               ' @nQTY       INT,           ' +
               ' @cNewToteID NVARCHAR( 20), ' +
               ' @tExtValidVar  VariableTable READONLY, ' +
               ' @nErrNo     INT            OUTPUT, ' +
               ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Confirm
      EXEC rdt.rdt_PTLCart_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSETOTE'
         ,@cDPLKey
         ,@cMethod
         ,@cCartID
         ,@cToteID
         ,@cLOC
         ,@cSKU
         ,@nQTY
         ,@cNewToteID
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
         ,@cLottableCode
         ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
         ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
         ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
      IF @nErrNo <> 0
         GOTO Quit

      -- Draw matrix (and light up)
      EXEC rdt.rdt_PTLCart_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode
         ,@cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05
         ,@cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10
         ,@cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15
         ,@nErrNo     OUTPUT,  @cErrMsg    OUTPUT
         ,@cResult01  OUTPUT,  @cResult02  OUTPUT,  @cResult03  OUTPUT,  @cResult04  OUTPUT,  @cResult05  OUTPUT
         ,@cResult06  OUTPUT,  @cResult07  OUTPUT,  @cResult08  OUTPUT,  @cResult09  OUTPUT,  @cResult10  OUTPUT
         ,NULL -- @nNextPage  OUTPUT
         ,@cCol
         ,@cRow
         ,@cMethod

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
      SET @cFieldAttr02 = '' -- QTY

      -- Go to matrix screen
      SET @nScn = @nScn_Matrix
      SET @nStep = @nStep_Matrix
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cToteID
      SET @cOutField02 = CAST( @nQTY AS NVARCHAR(5))

      -- Use light
      IF @cLight = '1'
      BEGIN
         SET @cFieldAttr02 = 'O' -- QTY
         SET @cOutField02 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ToteID
      END
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY

      -- Go to old tote screen
      SET @nScn = @nScn_CloseTote
      SET @nStep = @nStep_CloseTote
   END
END
GOTO QUIT


/********************************************************************************
Step 7. Scn = 4136. Unassign cart screen
   Unassign cart?
   1 = YES
   9 = NO
   Option   (field01, input)
********************************************************************************/
Step_Unassign:
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
         SET @cOutfield01 = CASE WHEN CHARINDEX( '1', @cClearCartIDScnField) = '0' THEN @cCartID ELSE '' END   --@cCartID
         SET @cOutfield02 = CASE WHEN CHARINDEX( '2', @cClearCartIDScnField) = '0' THEN @cPickZone ELSE '' END --@cPickZone
         SET @cOutfield03 = CASE WHEN CHARINDEX( '3', @cClearCartIDScnField) = '0' THEN @cMethod ELSE '' END   --@cMethod
         SET @cOutfield04 = CASE WHEN CHARINDEX( '4', @cClearCartIDScnField) = '0' THEN @cPickSeq ELSE '' END  --@cPickSeq
         SET @cOutfield05 = CASE WHEN CHARINDEX( '5', @cClearCartIDScnField) = '0' THEN @cCol ELSE '' END      --@cCol
         SET @cOutfield06 = CASE WHEN CHARINDEX( '6', @cClearCartIDScnField) = '0' THEN @cRow ELSE '' END      --@cRow

         IF @cOutfield01 = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Cart ID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

         -- Go to cart screen
         SET @nScn = @nScn_CartID
         SET @nStep = @nStep_CartID

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
   SET @nStep = @nStep_Assign
END
GOTO QUIT


/********************************************************************************
Step 8. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_MultiSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
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
         @cStorerKey,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   END

   SELECT @cLocDescr = SUBSTRING( Descr, 1, 20)
   FROM dbo.LOC WITH (NOLOCK)
   WHERE Facility = @cFacility
   AND LOC = @cLOC

   IF ISNULL( @cLocDescr, '') = ''
      SET @cLocDescr = @cLOC

   -- Prepare next screen var
   SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
   SET @cOutField02 = @cSKU
   SET @cOutField03 = @cSKU -- SKU
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
   SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
   SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
   SET @cOutField07 = CAST( @nTotalQTY AS NVARCHAR(5))
   SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
   SET @cOutField15 = '' -- ExtendedInfo

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep_SKU

END
GOTO Quit


/********************************************************************************
Scn = 4137. Verify LOC
   LOC   (field01)
   LOC   (field02, input)
********************************************************************************/
Step_VerifyLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkLOC NVARCHAR( 10)
      
      -- Screen mapping
      SET @cChkLOC = @cInField02

      -- Check LOC      
      IF @cLOC <> @cChkLOC      
      BEGIN      
         SET @nErrNo = 53436      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC      
         GOTO Step_VerifyLOC_Fail      
      END      

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 8,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Get LOC desc
      IF @cLocShowDescr = '1'
      BEGIN
         SELECT @cLocDescr = LEFT( ISNULL( Descr, ''), 15)
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOC = @cLOC
         IF @cLocDescr = ''
            SET @cLocDescr = @cLOC
      END
      SET @nPieceQTY = 0
      SET @nMatrixQTY = @nTotalQTY

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @cLocShowDescr = '1' THEN @cLocDescr ELSE @cLOC END
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
      SET @cOutField07 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField12 = CASE WHEN @cVerifyPiece = '1' THEN CAST( @nPieceQTY AS NVARCHAR(3)) ELSE '' END
      SET @cOutField15 = '' -- ExtendedInfo

      -- Goto SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
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

      SET @nStep = @nStep_Assign
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cLight         NVARCHAR( 1),  ' +
            ' @cDPLKey        NVARCHAR( 10), ' +
            ' @cCartID        NVARCHAR( 10), ' +
            ' @cPickZone      NVARCHAR( 10), ' +
            ' @cMethod        NVARCHAR( 10), ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @cToteID        NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cNewToteID     NVARCHAR( 20), ' +
            ' @cLottable01    NVARCHAR( 18), @cLottable02 NVARCHAR( 18), @cLottable03 NVARCHAR( 18), @dLottable04 DATETIME,      @dLottable05 DATETIME,      ' +
            ' @cLottable06    NVARCHAR( 30), @cLottable07 NVARCHAR( 30), @cLottable08 NVARCHAR( 30), @cLottable09 NVARCHAR( 30), @cLottable10 NVARCHAR( 30), ' +
            ' @cLottable11    NVARCHAR( 30), @cLottable12 NVARCHAR( 30), @dLottable13 DATETIME,      @dLottable14 DATETIME,      @dLottable15 DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_VerifyLOC, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cLight, @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nQTY, @cNewToteID,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         --IF @nStep = 3 -- SKU
         --   SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   Step_VerifyLOC_Fail:
   BEGIN
      SET @cOutField02 = '' -- LOC
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
      -- UserName  = @cUserName,
      InputKey  = @nInputKey,

      V_FromScn  = @nFromScn,
      V_OrderKey = @cOrderKey,
      V_LOC      = @cLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_Integer1 = @nTotalOrder,
      V_Integer2 = @nTotalTote,
      V_Integer3 = @nTotalPOS,
      V_Integer4 = @nTotalQTY,
      V_Integer5 = @nNextPage,
      V_Integer6 = @nPieceQTY, 
      V_Integer7 = @nMatrixQTY, 

      V_String1  = @cCartID,
      V_String2  = @cPickZone,
      V_String3  = @cMethod,
      V_String4  = @cDPLKey,
      V_String5  = @cToteID,
      V_String6  = @cPosition,
      V_String7  = @cBatch,
      V_String8  = @cClearCartIDScnField,
      V_String9  = @cLocShowDescr,
      V_String10 = @cMultiSKUBarcode,

      V_String13 = @cOption,
      V_String14 = @cPickSeq,
      V_String15 = @cRow,
      V_String16 = @cCol,
      V_String17 = @cLottableCode,

      V_String20 = @cExtendedValidateSP,
      V_String21 = @cExtendedUpdateSP,
      V_String22 = @cExtendedInfoSP,
      V_String23 = @cPTLPKZoneReq,
      V_String24 = @cAllowSkipTask,
      V_String25 = @cDecodeLabelNo,
      V_String26 = @cLight,
      V_String27 = @cExtendedInfo,
      V_String28 = @cPassOnCart,
      V_String29 = @cDecodeSP,
      V_String30 = @cDefaultMethod, --(yeekung01)
      V_String31 = @cVerifyPiece,
      V_String32 = @cVerifyLOC, 

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