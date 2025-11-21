SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Batch_Charge_Out                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Material Charge Out By Batch (E1MY - E1 Manufacturing)      */
/*                                                                      */
/* SOS: 213132                                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2011-05-06   1.0  James      Created                                 */
/* 2011-08-05   1.1  James      Bug fix (james01)                       */
/* 2016-09-30   1.2  Ung        Performance tuning                      */
/* 2018-10-30   1.3  Gan        Performance tuning                      */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_Batch_Charge_Out](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
	@b_success			   INT,
   @b_isok              INT,
	@n_err				   INT,
	@c_errmsg			   NVARCHAR( 250),
   @nLOCCnt             INT,
   @nCount              INT
  
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   @cUserName           NVARCHAR(18),
   @cPrinter            NVARCHAR(10),
   @cDataWindow         NVARCHAR(50), 
   @cTargetDB           NVARCHAR(10), 
   
   @cLOT                NVARCHAR(10),
   @cLOC                NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cActSKU             NVARCHAR(20),
   @cDESCR              NVARCHAR(60),
   @cPackKey            NVARCHAR(10),
   @cDefaultUOM         NVARCHAR(1),
   @cWorkOrder          NVARCHAR(10), 
   @cSKUDesc            NVARCHAR(60),
   @nQty                INT,
   @nSKUCnt             INT,
   @nQtyInsert          INT,
   @cKDQty              NVARCHAR(10),
   @cADJQty             NVARCHAR(10),
   @cInvQTY             NVARCHAR(10),
   @nLotQTY             NVARCHAR(10),
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @cLottable04         NVARCHAR(16),
   @cLottable05         NVARCHAR(16),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLotLabel01         NVARCHAR(20),
   @cLotLabel02         NVARCHAR(20),
   @cLotLabel03         NVARCHAR(20),
   @cLotLabel04         NVARCHAR(20),
   @cLotLabel05         NVARCHAR(20),
   @cUOM                NVARCHAR(10),
   @cQTY                NVARCHAR(10),
   @cPalletQTY          NVARCHAR(10),
   @cUOMDIV             NVARCHAR(10),
   @cMsg                NVARCHAR(20),
   @cOption             NVARCHAR(1),
   @cLastScn            NVARCHAR(5),
   @cLastStep           NVARCHAR(5),
	@cAdjustmentKey	   NVARCHAR(10),
	@cAdjDetailLine	   NVARCHAR(5),
   @cAdjType            NVARCHAR(3),
   @cAdjReasonCode      NVARCHAR(10),
   @cItrnKey            NVARCHAR(10),
   @cSourceKey          NVARCHAR(20),
   @cAllowOverADJ       NVARCHAR(1),
   @cCurrentHold        NVARCHAR(1),
   @cHoldSetup          NVARCHAR(1),
   @cOtherOKlot         NVARCHAR(1),
   @cLotStatus          NVARCHAR(5),
   @cHoldByLot02        NVARCHAR(1),
   @cRemark             NVARCHAR(255),
   @nTranCount          INT,           -- (james01)
   @cPrevWorkOrder      NVARCHAR(10),   -- (james01)

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
   @nFunc               = Func,
   @nScn                = Scn,
   @nStep               = Step,
   @nInputKey           = InputKey,
   @cLangCode           = Lang_code,
   @nMenu               = Menu,

   @cFacility           = Facility,
   @cStorerKey          = StorerKey,
   @cUserName           = UserName, -- (Vicky06)
   @cPrinter            = Printer, 

   @cLOC                = V_Loc,
   @cSKU                = V_SKU, 
   @cUOM                = V_UOM,
   @cID                 = V_ID,
   @cSKUDesc            = V_SkuDescr, 
   @nQty                = V_QTY,   
   @cLOT                = V_Lot,   
   @cLottable01         = V_Lottable01,
   @cLottable02         = V_Lottable02,
   @cLottable03         = V_Lottable03,
   @dLottable04         = V_Lottable04,
   @dLottable05         = V_Lottable05,
   @cLotLabel01         = V_LottableLabel01,
   @cLotLabel02         = V_LottableLabel02,
   @cLotLabel03         = V_LottableLabel03,
   @cLotLabel04         = V_LottableLabel04,
   @cLotLabel05         = V_LottableLabel05,
   @cWorkOrder          = V_String1,
   @cLottable04         = V_String2,
   @cLottable05         = V_String3,
   @cQTY                = V_String4,
   @cPalletQTY          = V_String5,
   @cUOMDIV             = V_String6,
   @cPackKey            = V_String7,
   @cKDQty              = V_String8,
   @cMsg                = V_String9,
   @cInvQTY             = V_String10,
   @cLastScn            = V_String11,
   @cLastStep           = V_String12,
   @cAdjustmentKey      = V_String13,
   @cAdjDetailLine      = V_String14,
   @cAdjType            = V_String15,
   @nLotQTY             = V_String16,
   @cAdjReasonCode      = V_String17,
   @cDataWindow         = V_String18,
   @cTargetDB           = V_String19,
   @cItrnKey            = V_String20,
   @cSourceKey          = V_String21,
   @cADJQty             = V_String22,
   @cAllowOverADJ       = V_String23,
   @cCurrentHold        = V_String24,
   @cHoldSetup          = V_String25,
   @cOtherOKlot         = V_String26,
   @cLotStatus          = V_String27,
   @cHoldByLot02        = V_String28,
   @cPrevWorkOrder      = V_String29,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1784 -- Material Charge Out By Batch
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. 1784
   IF @nStep = 1 GOTO Step_1   -- Scn = 2260   Scan-in the WorkOrder#
   IF @nStep = 2 GOTO Step_2   -- Scn = 2261   Scan-in the LOC, SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 2262   Scan-in the Lottable02
   IF @nStep = 4 GOTO Step_4   -- Scn = 2263   Scan-in the Lottables, UOM, QTY
   IF @nStep = 5 GOTO Step_5   -- Scn = 2264   Scan-in the Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func in (1771, 1772, 1773))
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2800
   SET @nStep = 1

   -- (Vicky06) EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- initialise all variable
   SET @cLOT              = ''
   SET @cLOC              = ''
   SET @cID               = ''
   SET @cSKU              = ''
   SET @cPackKey          = ''
   SET @cDefaultUOM       = ''
   SET @cWorkOrder        = ''
   SET @cSKUDesc          = ''
   SET @nQty              = 0
   SET @nQtyInsert        = 0
   SET @cKDQty            = '0'
   SET @cADJQty           = '0'
   SET @cInvQTY           = '0'
   SET @cLottable01       = ''
   SET @cLottable02       = ''
   SET @cLottable03       = ''
   SET @cLottable04       = ''
   SET @cLottable05       = ''
   SET @dLottable04       = NULL
   SET @dLottable05       = NULL
   SET @cLotLabel01       = ''
   SET @cLotLabel02       = ''
   SET @cLotLabel03       = ''
   SET @cLotLabel04       = ''
   SET @cLotLabel05       = ''
   SET @cUOM              = ''
   SET @cQTY              = ''
   SET @cMsg              = ''
   SET @cOption           = ''
   SET @cLastScn          = ''
   SET @cLastStep         = ''
   SET @cAdjustmentKey    = ''
   SET @cAdjDetailLine    = ''

   -- Prep next screen var   
   SET @cOutField01        = ''     -- WorkOrder
   SET @cPrevWorkOrder     = ''     -- (james01)

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
Step 1. screen = 2800 Scan-in the WorkOrder#
   WORKORDER NO: 
   (Field01, input)

   ENTER = Next Page
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWorkOrder = @cInField01

      --When WorkOrder is blank
      IF @cWorkOrder = ''
      BEGIN
         SET @nErrNo = 73016
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO Needed
         GOTO Step_1_Fail  
      END 

      --check WO exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder)
      BEGIN
         SET @nErrNo = 73017
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WO
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
           AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 73018
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Storer
         GOTO Step_1_Fail    
      END

      --check ADJ facility
      IF Right(ISNULL(RTRIM(@cFacility), '') ,2) <> '10'
      BEGIN
         SET @nErrNo = 73019
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Non-manufac WO
         GOTO Step_1_Fail    
      END

      --check diff facility
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 73020
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Fac
         GOTO Step_1_Fail    
      END

      --check for Workorder Status = 9
      IF EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Status = '9')
      BEGIN
         SET @nErrNo = 73021
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO Closed
         GOTO Step_1_Fail    
      END

      --check for Workorder Status = 'CANC'
      IF EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Status = 'CANC')
      BEGIN
         SET @nErrNo = 73022
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO Cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      -- If user key in new workorder then finalize the previous adjustment
      IF ISNULL(@cPrevWorkOrder, '') <> '' AND ISNULL(@cAdjustmentKey, '') <> '' AND @cPrevWorkOrder <> @cWorkOrder
      BEGIN
         BEGIN TRAN

         UPDATE dbo.ADJUSTMENT WITH (ROWLOCK) 
         SET FinalizedFlag = 'Y'
         WHERE AdjustmentKey = @cAdjustmentKey
            AND FinalizedFlag <> 'Y'

         SET @n_err = @@error
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 73049
            SET @cErrMsg = rdt.rdtgetmessage( 73049, @cLangCode, 'DSP') --UPD ADJ Fail
            GOTO Step_1_Fail
         END   
         ELSE
         BEGIN
            COMMIT TRAN
            SET @cAdjustmentKey = ''
         END
      END                   

      --prepare next screen variable
      SET @cOutField01 = @cWorkOrder
      SET @cOutField02 = '' -- LOC
      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC

      SET @cLOC = ''
      SET @cSKU = ''

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF ISNULL(@cAdjustmentKey, '') <> ''
      BEGIN
         BEGIN TRAN

         UPDATE dbo.ADJUSTMENT WITH (ROWLOCK) 
         SET FinalizedFlag = 'Y'
         WHERE AdjustmentKey = @cAdjustmentKey
            AND FinalizedFlag <> 'Y'

         SET @n_err = @@error
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 73049
            SET @cErrMsg = rdt.rdtgetmessage( 73049, @cLangCode, 'DSP') --UPD ADJ Fail
            GOTO Step_1_Fail
         END   
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END

     -- (Vicky06) EventLog - Sign Out Function
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

      SET @cOutField01 = '' -- Option
      SET @cWorkOrder = ''

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

   Step_1_Fail:
   BEGIN
      SET @cWorkOrder  = ''

      -- Reset this screen var
      SET @cOutField01 = '' -- WorkOrder
   END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2801) Scan-in the LOC & SKU
   LOC:  (Field01, input)
   SKU:  (Field02, input)

   ENTER =  Next Page
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02
      SET @cActSKU = @cInField03

      --When LOC is blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 73023
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Required
         SET @cOutField03 = @cActSKU
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         GOTO Quit
      END 

      --check LOC exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 73024
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cLOC = ''
         SET @cOutField02 = ''
         SET @cOutField03 = @cActSKU
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         GOTO Quit
      END

      --check diff facility
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 73025
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Fac
         SET @cLOC = ''
         SET @cOutField02 = ''
         SET @cOutField03 = @cActSKU
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         GOTO Quit
      END

      --When SKU is blank
      IF @cActSKU = ''
      BEGIN
         SET @nErrNo = 73026
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Required
         SET @cOutField02 = @cLOC
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         GOTO Quit
      END 

      EXEC [RDT].[rdt_GETSKUCNT]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cActSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 73027
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         SET @cActSKU = ''
         SET @cOutField02 = @cLOC
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         GOTO Quit
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 73028
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
         SET @cActSKU = ''
         SET @cOutField02 = @cLOC
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         GOTO Quit
      END

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cActSKU       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      SET @cSKU = @cActSKU

      IF NOT EXISTS (SELECT 1 
         FROM dbo.KitDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
            AND ExternKitkey = @cWorkOrder
            AND SKU = @cSKU
            AND Type = 'F')
      BEGIN
         SET @nErrNo = 73029
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RM SKU
         SET @cSKU = ''
         SET @cActSKU = ''
         SET @cOutField02 = @cLOC
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         GOTO Quit
      END      

      IF NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 73047
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SKU + LOC
         SET @cOutField02 = @cLOC
         SET @cOutField03 = @cActSKU
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         GOTO Quit
      END      

      SELECT @cDESCR = DESCR FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      --prepare next screen variable
      SET @cOutField01 = @cWorkOrder
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cDESCR,  1, 20)
      SET @cOutField05 = SUBSTRING(@cDESCR, 21, 20)
      SET @cOutField06 = ''      -- Lottable02

      SET @cLottable02 = ''

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- go to previous screen
      SET @cOutField01 = '' 
      SET @cWorkOrder = ''

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2802) Scan-in the Lottable02
   L2: (Field01, input)
 
   ENTER =  Next Page
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLottable02 = @cInField06

      IF ISNULL(@cLottable02, '') = ''
      BEGIN
         SET @nErrNo = 73030
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT02 req
         GOTO Step_3_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LotAttribute WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Lottable02 = @cLottable02)
      BEGIN
         SET @nErrNo = 73031
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT02
         GOTO Step_3_Fail
      END

      -- Validate if any of the lot and SKU has lottable02 on hold
      IF EXISTS (SELECT 1 
                 FROM dbo.LotAttribute LA WITH (NOLOCK) 
                 JOIN dbo.LOT LOT WITH (NOLOCK) ON LA.LOT = LOT.LOT 
                 WHERE LA.StorerKey = @cStorerKey 
                 AND LA.SKU = @cSKU
                 AND LA.Lottable02 = @cLottable02
                 AND LOT.Status = 'HOLD')
      BEGIN
         SET @nErrNo = 73032
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT ON HOLD
         GOTO Step_3_Fail    
      END

      --check Inventory exists  
      SELECT @cInvQTY = ISNULL(SUM(LLI.QTY), 0)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LotAttribute LA WITH (NOLOCK)
                        ON (LLI.LOT = LA.LOT) 
      JOIN dbo.LOT LOT WITH (NOLOCK) ON LLI.LOT = LOT.LOT
      WHERE LLI.Storerkey  = @cStorerkey
         AND LLI.LOC       = @cLOC
         AND LLI.SKU       = @cSKU
         AND LOT.STATUS    <>'HOLD'        
         AND LA.Lottable02 = @cLottable02
         -- check expirary date. Cannot charge out expired date goods
         AND ISNULL(LA.Lottable04, 0) >= ISNULL(CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120), 0)

      IF ISNULL(@cInvQTY, '0') = '0'
      BEGIN
         SET @nErrNo = 73033
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IIvt Not Found
         GOTO Step_3_Fail    
      END

      -- Get LottableNNlabel
      SELECT
         @cSKUDesc = IsNULL(RTRIM(S.DescR), ''), 
         @cLotLabel01 = IsNULL((SELECT C.Code FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''), 
         @cLotLabel02 = IsNULL((SELECT C.Code FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''), 
         @cLotLabel03 = IsNULL((SELECT C.Code FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''), 
         @cLotLabel04 = IsNULL((SELECT C.Code FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),
         @cLotLabel05 = IsNULL((SELECT C.Code FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), '')
      FROM dbo.SKU S WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND SKU = @cSKU

      SELECT TOP 1 
         @cLottable01 = Lottable01, 
         @cLottable02 = Lottable02, 
         @cLottable03 = Lottable03, 
         @dLottable04 = Lottable04, 
         @dLottable05 = Lottable05 
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND Lottable02 = @cLottable02
         AND ISNULL(Lottable04, 0) >= ISNULL(CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120), 0)
      ORDER BY LOT 

      -- Lottable01
      IF ISNULL(RTRIM(@cLotlabel01),'') = '' 
      BEGIN
         SET @cOutField01  = ''  
         SET @cOutField02  = ''
      END
      ELSE
      BEGIN
         SET @cOutField01  = @cLotLabel01  
         SET @cOutField02  = @cLottable01
      END

      -- Lottable02
      IF ISNULL(RTRIM(@cLotlabel02),'') = '' 
      BEGIN
         SET @cOutField03  = ''  
         SET @cOutField04  = ''
      END
      ELSE
      BEGIN
         SET @cOutField03  = @cLotLabel02  
         SET @cOutField04  = @cLottable02
      END

      -- Lottable03
      IF ISNULL(RTRIM(@cLotlabel03),'') = '' 
      BEGIN
         SET @cOutField05  = ''  
         SET @cOutField06  = ''
      END
      ELSE
      BEGIN
         SET @cOutField05  = @cLotLabel03  
         SET @cOutField06  = @cLottable03
      END

      -- Lottable04
      IF ISNULL(RTRIM(@cLotlabel04),'') = '' 
      BEGIN
         SET @cOutField07  = ''  
         SET @cOutField08  = ''
      END
      ELSE
      BEGIN
         SET @cOutField07  = @cLotLabel04  
         SET @cOutField08  = rdt.rdtFormatDate(@dLottable04)
      END

      -- Lottable01
      IF ISNULL(RTRIM(@cLotlabel05),'') = '' 
      BEGIN
         SET @cOutField09  = ''  
         SET @cOutField10  = ''
      END
      ELSE
      BEGIN
         SET @cOutField09  = @cLotLabel05  
         SET @cOutField10  = rdt.rdtFormatDate(@dLottable05)
      END

      SET @cUOM = ''
      SET @cKDQty = ''

      SELECT @cUOM = KD.UOM, 
             @cKDQty   = ISNULL(RTRIM(ExpectedQty),0) 
      FROM dbo.Kit K WITH (NOLOCK)
      JOIN dbo.KitDetail KD WITH (NOLOCK) ON K.KITKey = KD.KITKey
      WHERE K.ExternKitkey = @cWorkOrder
         AND K.Storerkey = @cStorerkey
         AND K.Facility = @cFacility
         AND KD.SKU = @cSKU
         AND KD.Type = 'F'

      SET @cOutField11 = @cUOM
      SET @cOutField12 = ''


      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01   = @cWorkOrder
      SET @cOutField02   = '' -- LOC
      SET @cOutField03   = '' -- SKU

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField06   = ''
      SET @cLottable02 = ''
   END  
END
GOTO Quit

Step_4:
/********************************************************************************
Step 4. (screen = 2803) Scan-in UOM & Qty
   LOTTABLES
   UOM: (Field04, input)                           -- UOM
   QTY: (Field05, input)                           -- QTY

   ENTER =  Next Page
********************************************************************************/
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUOM = @cInField11
      SET @cQTY = @cInField12

      --Validate UOM field
      IF ISNULL(RTRIM(@cUOM),'') = '' 
      BEGIN
         SET @nErrNo = 73034
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UOM Required
         SET @cOutField11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- UOM
         GOTO Quit 
      END

      --check UOM exists 
      SELECT @cPackKey = ISNULL(RTRIM(P.PackKey),'')
      FROM dbo.Pack P WITH (NOLOCK)
         INNER JOIN dbo.SKU S WITH (NOLOCK) ON (P.PackKey = S.PackKey)
      WHERE S.StorerKey = @cStorerkey
         AND S.SKU = @cSKU
         AND @cUOM IN (
            P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, 
            P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9)

      IF ISNULL(RTRIM(@cPackKey),'') = ''
      BEGIN
         SET @nErrNo = 73035
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UOM
         SET @cUOM = ''
         SET @cOutField11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- UOM
         GOTO Quit    
      END

      --Validate QTY field
      IF ISNULL(RTRIM(@cQTY),'') = '' 
      BEGIN
         SET @nErrNo = 73036
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY Required
         SET @cOutField12 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      --Validate QTY is numeric
      IF rdt.rdtIsValidQty(@cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 73037
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         SET @cOutField12 = ''
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      --Validate QTY < 0
      IF CAST(@cQTY AS FLOAT) < 0
      BEGIN
         SET @nErrNo = 73038
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY must > 0
         SET @cOutField12 = ''
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      --Convert QTY to EA
      SET @b_success = 0
      EXECUTE dbo.nspUOMCONV
         @n_fromqty    = @cQTY,
         @c_fromuom    = @cUOM,
         @c_touom      = '',
         @c_packkey    = @cPackkey,
         @n_toqty      = @nQTY         OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @nErrNo       OUTPUT,
         @c_errmsg     = @cErrMsg      OUTPUT

      IF @b_success = 0
      BEGIN
         SET @nErrNo = 73039
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspUOMCONV err
         SET @cOutField11 = ''
         SET @cUOM = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- UOM
         GOTO Quit
      END

      SET @nQTY = FLOOR(@nQTY)

      --Validate UOM Convert QTY < 1 
      IF @nQTY < 1  
      BEGIN
         SET @nErrNo = 73040
         SET @cErrMsg = rdt.rdtgetmessage( 73040, @cLangCode, 'DSP') --UOMConvQTY < 1
         SET @cOutField12 = ''
         SET @cQty = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      SELECT @cADJQty = ISNULL(RTRIM(SUM(AD.QTY)),0) 
      FROM dbo.ADJUSTMENTDETAIL AD WITH (NOLOCK)
      JOIN dbo.ADJUSTMENT A WITH (NOLOCK) ON (A.AdjustmentKey = AD.AdjustmentKey) 
      WHERE A.Storerkey = @cStorerkey
         AND A.CustomerRefNo = @cWorkOrder
         AND AD.SKU = @cSKU     

		SET @cADJQty = -(CAST(@cADJQty AS INT) - @nQTY) 

--      SET @cErrMsg = @cADJQty
--      GOTO Quit
      --Validate UOM Convert QTY > KDQty
      IF CAST(@cADJQty AS INT) > CAST(@cKDQty AS INT)
      BEGIN
         IF rdt.RDTGetConfig(@nFunc, 'Allow_WOOverQty', @cStorerkey) = '1'
         BEGIN
            SET @cMsg = 'WARNING:QTY>KITQty'
         END
         ELSE
         BEGIN
            SET @nErrNo = 73041
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY > KITQTY
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
            SET @cOutField12 = ''
            SET @cQty = ''
            GOTO Quit         
         END
      END

      --Validate UOM Convert QTY > InvQTY
      IF @nQTY > CAST(@cInvQTY AS INT)
      BEGIN
         SET @nErrNo = 73042
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not Avail
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         SET @cOutField12 = ''
         SET @cQty = ''
         GOTO Quit
      END

      --prepare screen variables
      SET @cOutField01   = @cMsg   -- Msg
      SET @cOutField02   = ''      -- Option
      SET @cInField02    = ''      -- Option

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END  

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = @cWorkOrder
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING(@cDESCR,  1, 20)
      SET @cOutField05 = SUBSTRING(@cDESCR, 21, 20)
      SET @cOutField06 = ''      -- Lottable02

      SET @cLottable02 = ''

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 5. (screen = 2804) Enter Option
   (Field01)  -- Msg    
   Confirm Adjustment?

   1=YES/NEXT PLT ID
   2=NO
   3=YES/EXIT ALL TASK

   OPTION: (Field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      SET @cLastScn  = @nScn 
      SET @cLastStep = @nStep

      --When Option is blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 73043
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Needed
         GOTO Step_5_Fail  
      END 

      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 73044
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail  
      END 

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN

      SAVE TRAN ADJ

      IF @cOption IN ('1', '3')
      BEGIN
         IF ISNULL(RTRIM(@cAdjustmentKey),'') = ''
         BEGIN
            SET @cAdjType = 'MI'
            SET @b_success = 0

		      EXECUTE dbo.nspg_getkey
			      'Adjustment'
			      , 10
			      , @cAdjustmentKey OUTPUT
			      , @b_success OUTPUT
			      , @n_err OUTPUT
			      , @c_errmsg OUTPUT

		      IF @b_success <> 1
		      BEGIN
               ROLLBACK TRAN ADJ
               SET @nErrNo = 73045
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetADJKey Fail
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
               GOTO Step_5_Fail
            END

            -- Insert new adjustment header
		      INSERT dbo.ADJUSTMENT (AdjustmentKey, StorerKey, CustomerRefNo, AdjustmentType, Facility)
		      VALUES (@cAdjustmentKey, @cStorerKey, @cWorkOrder, @cAdjType, @cFacility)

		      SELECT @n_err = @@error
		      IF @n_err > 0
		      BEGIN
               ROLLBACK TRAN ADJ
               SET @nErrNo = 73046
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ADJ Fail
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
               GOTO Step_5_Fail
   	      END
         END

         DECLARE C_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.LOT, LLI.ID, ISNULL(LLI.QTY, 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT) 
         JOIN dbo.LOT LOT WITH (NOLOCK) ON (LA.LOT = LOT.LOT )
         WHERE LLI.Storerkey  = @cStorerkey
            AND LLI.LOC       = @cLOC
            AND LLI.SKU       = @cSKU
            AND LLI.QTY       > 0  
            AND LOT.Status    <> 'HOLD'
            AND LA.Lottable02 = @cLottable02
            -- check expirary date. Cannot charge out expired date goods
            AND ISNULL(LA.Lottable04, 0) >= ISNULL(CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120), 0)

         ORDER BY LLI.LOT
         OPEN C_LOT
         FETCH NEXT FROM C_LOT INTO  @cLOT, @cID, @nLotQTY  
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            IF @nQTY = 0
            BEGIN  
               BREAK
            END

            IF @nLotQTY <= @nQTY
            BEGIN  
               SET @nQTY = @nQTY - @nLotQTY
               SET @nQtyInsert = @nLotQTY
            END  
            ELSE
            BEGIN
               SET @nQtyInsert = @nQTY
               SET @nQTY = 0 -- (Vanessa01)
            END

            IF @nQtyInsert > 0  -- (Vanessa01)
            BEGIN               -- (Vanessa01)
               SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
               FROM  dbo.AdjustmentDetail (NOLOCK)
               WHERE AdjustmentKey = @cAdjustmentKey
         
               INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                       UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
               VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                       @cUOM, @cPackKey, -@nQtyInsert, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
      
	            SET @n_err = @@error
	            IF @n_err <> 0
	            BEGIN
                  ROLLBACK TRAN ADJ
                  SET @nErrNo = 68927
                  SET @cErrMsg = rdt.rdtgetmessage( 68927, @cLangCode, 'DSP') --INS ADJDT Fail
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                  CLOSE C_LOT
                  DEALLOCATE C_LOT
                  GOTO Step_5_Fail
	            END  
               ELSE
               BEGIN
                  UPDATE dbo.AdjustmentDetail WITH (ROWLOCK)
                  SET FinalizedFlag = 'Y'
                  WHERE AdjustmentKey = @cAdjustmentKey
                     AND AdjustmentLineNumber = @cAdjDetailLine

                  SET @n_err = @@error
                  IF @n_err <> 0
                  BEGIN
                     ROLLBACK TRAN ADJ
                     SET @nErrNo = 68928
                     SET @cErrMsg = rdt.rdtgetmessage( 68928, @cLangCode, 'DSP') --UPD ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     CLOSE C_LOT
                     DEALLOCATE C_LOT
                     GOTO Step_5_Fail
                  END   
               END
            END                

            FETCH NEXT FROM C_LOT INTO  @cLOT, @cID, @nLotQTY  
         END --end of while
         CLOSE C_LOT
         DEALLOCATE C_LOT

         IF @cOption = '1'
         BEGIN
            -- Go to LOC Screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
            SET @cOutField01 = @cWorkOrder   -- WO#  
            SET @cOutField02 = @cLOC         -- LOC
            SET @cOutField03 = ''            -- SKU
         END
         ELSE
         BEGIN
            UPDATE dbo.ADJUSTMENT WITH (ROWLOCK) 
            SET FinalizedFlag = 'Y'
            WHERE AdjustmentKey = @cAdjustmentKey
               AND FinalizedFlag <> 'Y'

            SET @n_err = @@error
            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN ADJ
               SET @nErrNo = 73048
               SET @cErrMsg = rdt.rdtgetmessage( 73048, @cLangCode, 'DSP') --UPD ADJ Fail
               GOTO Step_5_Fail
            END   

            -- Go to WO Screen
            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4
            SET @cOutField01 = ''            -- WO#  
            SET @cAdjustmentKey = ''         -- (james01)
         END

         SET @cPrevWorkOrder    = @cWorkOrder

         SET @cLOT              = ''
         SET @cSKU              = ''
         SET @cPackKey          = ''
         SET @cSKUDesc          = ''
         SET @nQty              = 0
         SET @cKDQty            = '0'
         SET @cADJQty           = '0'
         SET @cInvQTY           = '0'
         SET @nLotQTY           = '0'
         SET @cCurrentHold      = '0'
         SET @cHoldSetup        = '0'
         SET @cOtherOKlot       = '1'
         SET @cLotStatus        = 'OK'
         SET @cHoldByLot02      = 'N'
         SET @cLottable01       = ''
         SET @cLottable02       = ''
         SET @cLottable03       = ''
         SET @cLottable04       = ''
         SET @cLottable05       = ''
         SET @dLottable04       = NULL
         SET @dLottable05       = NULL
         SET @cLotLabel01       = ''
         SET @cLotLabel02       = ''
         SET @cLotLabel03       = ''
         SET @cLotLabel04       = ''
         SET @cLotLabel05       = ''
         SET @cUOM              = ''
         SET @cQTY              = ''
         SET @cPalletQTY        = ''
         SET @cUOMDIV           = ''
         SET @cMsg              = ''
         SET @cOption           = ''
         SET @cAdjDetailLine    = ''
         SET @cItrnKey          = ''
         SET @cSourceKey        = ''
      END

      IF @cOption = '2'
      BEGIN
         -- Go to WO Screen 
         SET @cPrevWorkOrder    = @cWorkOrder

         SET @nScn              = @nScn - 4
         SET @nStep             = @nStep - 4
         SET @cLOT              = ''
         SET @cLOC              = ''
         SET @cID               = ''
         SET @cSKU              = ''
         SET @cPackKey          = ''
         SET @cSKUDesc          = ''
         SET @nQty              = 0
         SET @cKDQty            = '0'
         SET @cADJQty           = '0'
         SET @cInvQTY           = '0'
         SET @nLotQTY           = '0'
         SET @cCurrentHold      = '0'
         SET @cHoldSetup        = '0'
         SET @cOtherOKlot       = '1'
         SET @cLotStatus        = 'OK'
         SET @cHoldByLot02      = 'N'
         SET @cLottable01       = ''
         SET @cLottable02       = ''
         SET @cLottable03       = ''
         SET @cLottable04       = ''
         SET @cLottable05       = ''
         SET @dLottable04       = NULL
         SET @dLottable05       = NULL
         SET @cLotLabel01       = ''
         SET @cLotLabel02       = ''
         SET @cLotLabel03       = ''
         SET @cLotLabel04       = ''
         SET @cLotLabel05       = ''
         SET @cUOM              = ''
         SET @cQTY              = ''
         SET @cPalletQTY        = ''
         SET @cUOMDIV           = ''
         SET @cMsg              = ''
         SET @cOption           = ''
         SET @cAdjDetailLine    = ''
         SET @cItrnKey          = ''
         SET @cSourceKey        = ''
         SET @cAdjustmentKey    = ''   -- (james01)

         SET @cOutField01       = '' -- LOC 
         SET @cInField01        = '' -- LOC 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC      
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN ADJ
   END  
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- rollback didn't decrease @@trancount
      -- COMMIT statements for such transaction 
      -- decrease @@TRANCOUNT by 1 without making updates permanent
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN ADJ

      SET @cOption     = ''

      -- Reset this screen var
      SET @cOutField01 = @cMsg -- Msg
      SET @cOutField02 = ''    -- Option
   END  
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate         = GETDATE(), 
       ErrMsg           = @cErrMsg, 
       Func             = @nFunc,
       Step             = @nStep,            
       Scn              = @nScn,

       Facility         = @cFacility, -- (Vicky06)
       StorerKey        = @cStorerKey, -- (Vicky06)
       -- UserName         = @cUserName, -- (Vicky06)
       Printer          = @cPrinter,   

       V_Loc             = @cLOC,
       V_SKU             = @cSKU,  
       V_UOM             = @cUOM,
       V_ID              = @cID,
       V_SkuDescr        = @cSKUDesc,
       V_QTY             = @nQty,   
       V_Lot             = @cLOT,  
       V_Lottable01      = @cLottable01,
       V_Lottable02      = @cLottable02,
       V_Lottable03      = @cLottable03,
       V_Lottable04      = @dLottable04,
       V_Lottable05      = @dLottable05,
       V_LottableLabel01 = @cLotLabel01,
       V_LottableLabel02 = @cLotLabel02,
       V_LottableLabel03 = @cLotLabel03,
       V_LottableLabel04 = @cLotLabel04,
       V_LottableLabel05 = @cLotLabel05,
       V_String1         = @cWorkOrder,
       V_String2         = @cLottable04,
       V_String3         = @cLottable05,
       V_String4         = @cQTY,
       V_String5         = @cPalletQTY,
       V_String6         = @cUOMDIV,
       V_String7         = @cPackKey,
       V_String8         = @cKDQty,
       V_String9         = @cMsg,
       V_String10        = @cInvQTY,
       V_String11        = @cLastScn,
       V_String12        = @cLastStep,
       V_String13        = @cAdjustmentKey,
       V_String14        = @cAdjDetailLine,
       V_String15        = @cAdjType,
       V_String16        = @nLotQTY,
       V_String17        = @cAdjReasonCode,
       V_String18        = @cDataWindow,
       V_String19        = @cTargetDB,
       V_String20        = @cItrnKey,
       V_String21        = @cSourceKey,
       V_String22        = @cADJQty,
       V_String23        = @cAllowOverADJ,
       V_String24        = @cCurrentHold,
       V_String25        = @cHoldSetup,
       V_String26        = @cOtherOKlot,
       V_String29        = @cPrevWorkOrder,

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