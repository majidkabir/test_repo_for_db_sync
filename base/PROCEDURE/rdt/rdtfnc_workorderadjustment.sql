SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_WorkOrderAdjustment                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Picking: Adjustment by Work Order (E1MY - E1 Manufacturing) */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2010-03-24   1.0  Vanessa    Created                                 */
/* 2010-04-14   1.1  Shong      Fixing Bug - Change dbo.fnc_RTRIM() to  */
/*                                           RTRIM()        --(Shong01) */
/* 2010-06-11   1.2  Vanessa    SOS#165436 Func1771 SET QTY = 0 and     */
/*                              LLI.QTY > 0 checking. --(Vanessa01)     */ 
/* 2010-06-14   1.3  Vanessa    SOS#165436 Func1773 Remove LOTxLOCxID   */
/*                              Checking. -- (Vanessa02)                */  
/* 2010-06-17   1.4  Vanessa    SOS#165436 Change Lot On Hold checking  */
/*                              by ID + SKU. -- (Vanessa03)             */
/* 2010-07-06   1.5  Vanessa    SOS#165436 Revise on @nQty > 0.         */
/*                                                       -- (Vanessa04) */ 
/* 2010-07-22   1.6  Vanessa    SOS#165436 Disable the pallet id for FG */
/*                              Scan Out -- (Vanessa05)                 */
/* 2010-09-09   1.7  Vanessa    SOS#165436 Revise as SUM(AdjustmentQTY) */
/*                              and Remove AdjType Checking. (Vanessa06)*/ 
/* 2016-09-30   1.8  Ung        Performance tuning                      */
/************************************************************************/
CREATE PROC  [RDT].[rdtfnc_WorkOrderAdjustment](
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
   @cPackKey            NVARCHAR(10),
   @cDefaultUOM         NVARCHAR(1),
   @cWorkOrder          NVARCHAR(10), 
   @cSKUDesc            NVARCHAR(60),
   @nQty                INT,
   @nQtyInsert          INT,
   @cKDQty              NVARCHAR(10),
   @cADJQty             NVARCHAR(10),
   @cInvQTY             NVARCHAR(10),
   @cLotQTY             NVARCHAR(10),
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

-- TraceInfo (Vicky02) - Start  
DECLARE    @d_starttime    datetime,  
           @d_endtime      datetime,  
           @d_step1        datetime,  
           @d_step2        datetime,  
           @d_step3        datetime,  
           @d_step4        datetime,  
           @d_step5        datetime,  
           @c_col1         NVARCHAR(20),  
           @c_col2         NVARCHAR(20),  
           @c_col3         NVARCHAR(20),  
           @c_col4         NVARCHAR(20),  
           @c_col5         NVARCHAR(20),  
           @c_TraceName    NVARCHAR(80)  
  
SET @d_starttime = getdate()  
  
SET @c_TraceName = 'rdtfnc_WorkOrderAdjustment'  
-- TraceInfo (Vicky02) - End  
            
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
   @cLotQTY             = V_String16,
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
-- @nFunc = 1771 Material Charge Out
-- @nFunc = 1772 FG SCAN-OUT
-- @nFunc = 1773 Material Return
IF @nFunc in (1771, 1772, 1773) -- WorkOrder Adjustment
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func in (1771, 1772, 1773)
   IF @nStep = 1 GOTO Step_1   -- Scn = 2260   Scan-in the WorkOrder#
   IF @nStep = 2 GOTO Step_2   -- Scn = 2261   Scan-in the LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 2262   Scan-in the PALLET ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 2263   Scan-in the SKU
   IF @nStep = 5 GOTO Step_5   -- Scn = 2264   Scan-in the LOTTABLE
   IF @nStep = 6 GOTO Step_6   -- Scn = 2265   Input UOM, QTY...
   IF @nStep = 7 GOTO Step_7   -- Scn = 2266   Enter Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func in (1771, 1772, 1773))
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2260
   SET @nStep = 1

   -- (Vicky06) EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey

   -- Init var
   SET @nLOCCnt = 0
   SET @nCount  = 0

   -- initialise all variable
   SET @cDataWindow       = ''
   SET @cTargetDB         = ''
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
   SET @cLotQTY           = '0'
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
   SET @cLastScn          = ''
   SET @cLastStep         = ''
   SET @cAdjustmentKey    = ''
   SET @cAdjDetailLine    = ''
   IF @nFunc = '1771' 
   BEGIN   
      SET @cAdjType = 'MI'
   END

   IF @nFunc = '1772' 
   BEGIN   
      SET @cAdjType = 'PRD'
   END

   IF @nFunc = '1773' 
   BEGIN   
      SET @cAdjType = 'MR'
   END
   SET @cAdjReasonCode    = 'ADJ_RDT'
   SET @cItrnKey          = ''
   SET @cSourceKey        = ''

   SET @cAllowOverADJ = ''
   SET @cAllowOverADJ = rdt.RDTGetConfig(@nFunc, 'Allow_WOOverQty', @cStorerkey) -- Parse in Function

   -- Prep next screen var   
   SET @cOutField01  = ''  -- WorkOrder
   SET @cInField01   = ''  -- WorkOrder
   EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder

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
Step 1. screen = 2260 Scan-in the WorkOrder#
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

      -- Get Label Print Info If @nFunc = '1772' 
      IF @nFunc = '1772' 
      BEGIN 
         --Validate printer setup
  		   IF ISNULL(@cPrinter, '') = ''
		   BEGIN			
            SET @nErrNo = 68950
            SET @cErrMsg = rdt.rdtgetmessage( 68950, @cLangCode, 'DSP') --NoLoginPrinter
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
            GOTO Step_1_Fail  
		   END

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	      FROM RDT.RDTReport WITH (NOLOCK) 
	      WHERE StorerKey = @cStorerKey
            AND ReportType = 'PLTLBLWO' 

         --Validate Pallet Label setup
         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 68951
            SET @cErrMsg = rdt.rdtgetmessage( 68951, @cLangCode, 'DSP') --DWNOTSetup
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
            GOTO Step_1_Fail  
         END

         --Validate TargetDB setup
         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 68952
            SET @cErrMsg = rdt.rdtgetmessage( 68952, @cLangCode, 'DSP') --TgetDB Not Set
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
            GOTO Step_1_Fail  
         END
      END

      --When WorkOrder is blank
      IF @cWorkOrder = ''
      BEGIN
         SET @nErrNo = 68891
         SET @cErrMsg = rdt.rdtgetmessage( 68891, @cLangCode, 'DSP') --WO Needed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail  
      END 

      --check WO exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder)
      BEGIN
         SET @nErrNo = 68892
         SET @cErrMsg = rdt.rdtgetmessage( 68892, @cLangCode, 'DSP') --Invalid WO
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
           AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 68893
         SET @cErrMsg = rdt.rdtgetmessage( 68893, @cLangCode, 'DSP') --Invalid Storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      --check ADJ facility
      IF Right(ISNULL(RTRIM(@cFacility), '') ,2) <> '10'
      BEGIN
         SET @nErrNo = 68894
         SET @cErrMsg = rdt.rdtgetmessage( 68894, @cLangCode, 'DSP') --Non-manufac WO
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      --check diff facility
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 68895
         SET @cErrMsg = rdt.rdtgetmessage( 68895, @cLangCode, 'DSP') --Invalid Fac
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      --check for Workorder Status = 9
      IF EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Status = '9')
      BEGIN
         SET @nErrNo = 68896
         SET @cErrMsg = rdt.rdtgetmessage( 68896, @cLangCode, 'DSP') --WO Closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END

      --check for Workorder Status = 'CANC'
      IF EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
            AND Storerkey = @cStorerkey
            AND Status = 'CANC')
      BEGIN
         SET @nErrNo = 68897
         SET @cErrMsg = rdt.rdtgetmessage( 68897, @cLangCode, 'DSP') --WO Cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
         GOTO Step_1_Fail    
      END
 
      Step_1_Next:  
      SET @cLastScn       = '' 
      SET @cLastStep      = ''
      SET @cAdjustmentKey = ''

      --prepare next screen variable
      SET @cOutField01 = '' -- LOC
      SET @cInField01  = '' -- LOC
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
                  
      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = '' -- Option
      SET @cInField01  = '' -- Option

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
      SET @cInField01  = '' -- WorkOrder
   END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2261) Scan-in the LOC 
   LOC:  (Field01, input)
 
   ENTER =  Next Page
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField01

      --When LOC is blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 68898
         SET @cErrMsg = rdt.rdtgetmessage( 68898, @cLangCode, 'DSP') --LOC Required
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         GOTO Step_2_Fail  
      END 

      --check LOC exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 68899
         SET @cErrMsg = rdt.rdtgetmessage( 68899, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         GOTO Step_2_Fail    
      END

      --check diff facility
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 68900
         SET @cErrMsg = rdt.rdtgetmessage( 68900, @cLangCode, 'DSP') --Invalid Fac
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
         GOTO Step_2_Fail    
      END

      Step_2_Next:
      --prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cInField02  = '' -- ID

      -- Auto generate ID if @nFunc = '1772'
      IF @nFunc = '1772' 
      BEGIN 
         EXECUTE dbo.nspg_GetKey
                  'ID', 
                  10 ,
                  @cID               OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 68901
            SET @cErrMsg = rdt.rdtgetmessage( 68901, @cLangCode, 'DSP') -- 'GetIDKey Fail'
            GOTO Step_2_Fail
         END
         ELSE
         BEGIN
            -- Init next screen var
            SET @cFieldAttr02  = 'O' -- ID -- (Vanessa05)
            SET @cOutField02 = @cID -- ID
            SET @cInField02  = @cID -- ID  -- (Vanessa05)
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         END
      END
      ELSE
      BEGIN
         SET @cFieldAttr02  = '' -- ID -- (Vanessa05)
         SET @cOutField02 = '' -- ID
         SET @cInField02  = '' -- ID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
      END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- go to previous screen
      IF @cLastScn = '2266' 
      BEGIN
         SET @cOutField01        = @cMsg -- Msg
         SET @cOutField02        = ''    -- Option

         SET @nScn = CONVERT(INT, @cLastScn)    -- Screen 2266
         SET @nStep = CONVERT(INT, @cLastStep)  -- Step 7
      END
      ELSE
      BEGIN  
         -- Prepare prev screen var
         SET @cOutField01        = @cWorkOrder -- WorkOrder
         SET @cInField01         = @cWorkOrder -- WorkOrder
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- WorkOrder
   
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC        = ''

      -- Reset this screen var
      SET @cInField01  = ''  -- LOC
   END  
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2262) Scan-in the PALLET ID
   LOC: (Field01)
   PLT ID:
   (Field02, input) -- ID  
 
   ENTER =  Next Page
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField02

      --When ID is blank
      IF @cID = ''
      BEGIN
         SET @nErrNo = 68902
         SET @cErrMsg = rdt.rdtgetmessage( 68902, @cLangCode, 'DSP') --PLTID Required
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         GOTO Step_3_Fail  
      END 

      Step_3_Next:

      -- Get SKU if @nFunc = '1771'
      IF @nFunc = '1771' 
      BEGIN 
         /* (Vanessa03)
         IF EXISTS (SELECT 1
                    FROM dbo.LOTxLOCxID LLI
                    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    JOIN dbo.INVENTORYHOLD IH WITH (NOLOCK) ON (IH.Storerkey = LLI.Storerkey
                                                                     AND IH.Lottable02 = LA.Lottable02
                                                                     AND ISNULL(RTRIM(IH.Lottable02), '') <> '' 
                                                                     AND IH.Hold = '1')
                    WHERE LLI.LOC = @cLOC
                       AND LLI.ID = @cID
                       AND LLI.QTY > 0  -- (Vanessa01)
                       AND LLI.Storerkey = @cStorerkey)
         BEGIN
            SET @nErrNo = 68958
            SET @cErrMsg = rdt.rdtgetmessage( 68958, @cLangCode, 'DSP') --Lot On Hold
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            GOTO Step_3_Fail  
         END 
         */
         SET ROWCOUNT 1
         SELECT @cSKU     = ISNULL(RTRIM(KD.SKU),''), 
                @cSKUDesc = ISNULL(RTRIM(SKU.DESCR),'')
         FROM dbo.KitDetail KD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Storerkey = KD.Storerkey 
                                 AND SKU.SKU = KD.SKU)
         -- Start (Vanessa02)
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( KD.SKU = LLI.SKU
                                 AND LLI.LOC = @cLOC
                                 AND LLI.ID = @cID
                                 AND LLI.Storerkey = @cStorerkey
                                 AND LLI.QTY > 0) 
         -- End (Vanessa02)
         WHERE KD.Storerkey = @cStorerkey
            AND KD.ExternKitkey = @cWorkOrder
            AND KD.Type = 'F'
            /* -- (Vanessa02)
            AND KD.SKU IN (SELECT LLI.SKU
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           WHERE LLI.LOC = @cLOC
                              AND LLI.ID = @cID
                              AND LLI.Storerkey = @cStorerkey
                              AND LLI.QTY > 0)
            */ 
         SET ROWCOUNT 0

         --Check SKU exist
         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 68903
            SET @cErrMsg = rdt.rdtgetmessage( 68903, @cLangCode, 'DSP') --Not WO SKU
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            GOTO Step_3_Fail  
         END 
         ELSE
         BEGIN
            -- SET @cFieldAttr01  = 'O' -- SKU
            SET @cOutField01   = @cSKU   -- SKU
            SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
            SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
            SET @cInField01    = @cSKU   -- SKU
         END
      END
      ELSE
      BEGIN
         SET @cOutField01 = '' -- SKU
         SET @cOutField02 = '' -- SKU desc 1
         SET @cOutField03 = '' -- SKU desc 2
         SET @cInField01  = '' -- SKU
      END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      IF @cLastScn = '2266' 
      BEGIN
         SET @cOutField01        = @cMsg -- Msg
         SET @cOutField02        = ''    -- Option

         SET @cFieldAttr02			= ''    -- ID  -- (Vanessa05)

         SET @nScn = CONVERT(INT, @cLastScn)    -- Screen 2266
         SET @nStep = CONVERT(INT, @cLastStep)  -- Step 7
      END
      ELSE
      BEGIN 
         -- Prepare prev screen var
         SET @cID           = ''

         SET @cOutField01   = @cLOC -- LOC
         SET @cInField01    = @cLOC -- LOC
         SET @cFieldAttr01  = ''    -- LOC
         SET @cFieldAttr02  = ''    -- ID  -- (Vanessa05)
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC

         -- go to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cID                = ''

      -- Reset this screen var
      SET @cOutField01   = @cLOC
      SET @cInField02    = '' -- ID
      SET @cFieldAttr01  = '' -- LOC
   END  
END
GOTO Quit

Step_4:
/********************************************************************************
Step 4. (screen = 2263) Scan-in/Display the SKU
   SKU:  
   (Field01)                                       -- SKU
   DESC: 
   (Field02)                                       -- SKUDesc (Len  1-20)
   (Field03)                                       -- SKUDesc (Len 21-40)

   ENTER =  Next Page
********************************************************************************/
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField01
      
      --When SKU is blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 68904
         SET @cErrMsg = rdt.rdtgetmessage( 68904, @cLangCode, 'DSP') --SKU Required
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
         GOTO Step_4_Fail  
      END 
      
      -- Start (Vanessa03)
      IF @nFunc = '1771' 
      BEGIN 
         IF EXISTS (SELECT 1
                    FROM dbo.LOTxLOCxID LLI
                    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    JOIN dbo.INVENTORYHOLD IH WITH (NOLOCK) ON (IH.Storerkey = LLI.Storerkey
                                                                     AND IH.Lottable02 = LA.Lottable02
                                                                     AND ISNULL(RTRIM(IH.Lottable02), '') <> '' 
                                                                     AND IH.Hold = '1')
                    WHERE LLI.LOC = @cLOC
                       AND LLI.ID = @cID
                       AND LLI.SKU = @cSKU
                       AND LLI.QTY > 0  -- (Vanessa01)
                       AND LLI.Storerkey = @cStorerkey)
         BEGIN
            SET @nErrNo = 68958
            SET @cErrMsg = rdt.rdtgetmessage( 68958, @cLangCode, 'DSP') --Lot On Hold
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            GOTO Step_4_Fail  
         END 
      END -- End (Vanessa03)

      IF @nFunc = '1772' 
      BEGIN 
         --check SKU exists for @nFunc = '1772' 
         IF NOT EXISTS (SELECT 1 
            FROM dbo.KitDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
               AND ExternKitkey = @cWorkOrder
               AND SKU = @cSKU
               AND Type = 'T')
         BEGIN
            SET @nErrNo = 68905
            SET @cErrMsg = rdt.rdtgetmessage( 68905, @cLangCode, 'DSP') --Invalid FG SKU
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
            GOTO Step_4_Fail    
         END
      END

      IF @nFunc = '1771' OR @nFunc = '1773' 
      BEGIN
         --check SKU exists for @nFunc = '1773' 
         IF NOT EXISTS (SELECT 1 
            FROM dbo.KitDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
               AND ExternKitkey = @cWorkOrder
               AND SKU = @cSKU
               AND Type = 'F')
         BEGIN
            SET @nErrNo = 68906
            SET @cErrMsg = rdt.rdtgetmessage( 68906, @cLangCode, 'DSP') --Invalid RM SKU
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
            GOTO Step_4_Fail    
         END      
      END

      Step_4_Next:
      BEGIN
         --prepare screen variables
         SET @cOutField01   = ''  -- Lottable01
         SET @cOutField02   = ''  -- Lottable02
         SET @cOutField03   = ''  -- Lottable03
         SET @cOutField04   = ''  -- Lottable04
         SET @cOutField05   = ''  -- Lottable05

         SET @cInField01    = ''  -- Lottable01
         SET @cInField02    = ''  -- Lottable02
         SET @cInField03    = ''  -- Lottable03
         SET @cInField04    = ''  -- Lottable04
         SET @cInField05    = ''  -- Lottable05

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
         
         IF @nFunc = '1772' 
         BEGIN 
            -- Validate lottable0Nlabel = '', Disable from Input
            IF ISNULL(RTRIM(@cLotlabel01),'') = '' 
            BEGIN
               SET @cFieldAttr01  = 'O'  -- Lottable01
            END
            
            IF ISNULL(RTRIM(@cLotlabel02),'') = '' 
            BEGIN
               SET @cFieldAttr02  = 'O'  -- Lottable02
            END
            ELSE  -- (Vanessa05)
            BEGIN
               SET @cFieldAttr02  = ''  -- Lottable02
            END

            IF ISNULL(RTRIM(@cLotlabel03),'') = '' 
            BEGIN
               SET @cFieldAttr03  = 'O'  -- Lottable03
            END

            IF ISNULL(RTRIM(@cLotlabel04),'') = '' 
            BEGIN
               SET @cFieldAttr04  = 'O'  -- Lottable04
            END

            IF ISNULL(RTRIM(@cLotlabel05),'') = '' 
            BEGIN
               SET @cFieldAttr05  = 'O'  -- Lottable05
            END
         END
         ELSE
         BEGIN
            SET @cFieldAttr01  = ''  -- Lottable01
            SET @cFieldAttr02  = ''  -- Lottable02
            SET @cFieldAttr03  = ''  -- Lottable03
            SET @cFieldAttr04  = ''  -- Lottable04
            SET @cFieldAttr05  = ''  -- Lottable05
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
         END

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      -- Start (Vanessa05)
      IF @nFunc = '1772'  
      BEGIN
         SET @cFieldAttr02  = 'O'  -- ID
      END
      ELSE
      BEGIN
         SET @cFieldAttr02  = ''  -- ID
      END
      -- End (Vanessa05)
      
      SET @cOutField01   = @cLOC -- LOC
      SET @cOutField02   = @cID  -- ID
      SET @cInField02    = @cID  -- ID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cSKU               = ''

      -- Reset this screen var
      SET @cOutField01        = '' -- SKU
      SET @cOutField02        = '' -- SKU desc 1
      SET @cOutField03        = '' -- SKU desc 2
   END  
END
GOTO Quit

/********************************************************************************
Step 5. (screen = 2264) Scan-in the LOTTABLE
   Lottable01:    
   (Field01, input)
   Lottable02:    
   (Field02, input)
   Lottable03:    
   (Field02, input)
   Lottable04
   (DD/MM/YYYY):    
   (Field02, input)
   Lottable05:  
   (DD/MM/YYYY):   
   (Field02, input)
   ENTER =  Next Page
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLottable01 = @cInField01
      SET @cLottable02 = @cInField02
      SET @cLottable03 = @cInField03
      SET @cLottable04 = @cInField04
      SET @cLottable05 = @cInField05

      IF @nFunc = '1772' 
      BEGIN 
         -- Validate lottable01
         IF ISNULL(RTRIM(@cLotlabel01),'') <> '' 
         BEGIN
            IF ISNULL(RTRIM(@cLottable01),'') = '' 
            BEGIN
               SET @nErrNo = 68907
               SET @cErrMsg = rdt.rdtgetmessage( 68907, @cLangCode, 'DSP') --'Lot01 Required'
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
               GOTO Step_5_Fail
            END
         END

         -- Validate lottable02
         IF ISNULL(RTRIM(@cLotlabel02),'') <> '' 
         BEGIN
            IF ISNULL(RTRIM(@cLottable02),'') = ''
            BEGIN
               SET @nErrNo = 68908
               SET @cErrMsg = rdt.rdtgetmessage( 68908, @cLangCode, 'DSP') --'Lot02 Required'
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable02
               GOTO Step_5_Fail
            END
         END

         -- Validate lottable03
         IF ISNULL(RTRIM(@cLotlabel03),'') <> ''
         BEGIN
            IF ISNULL(RTRIM(@cLottable03),'') = ''
            BEGIN
               SET @nErrNo = 68909
               SET @cErrMsg = rdt.rdtgetmessage( 68909, @cLangCode, 'DSP') --'Lot03 Required'
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- Lottable03
               GOTO Step_5_Fail
            END  
  		   END

         -- Validate lottable04
         IF ISNULL(RTRIM(@cLotlabel04),'') <> ''
         BEGIN
            -- Validate empty
            IF ISNULL(RTRIM(@cLottable04),'') = ''
            BEGIN
               SET @nErrNo = 68910
               SET @cErrMsg = rdt.rdtgetmessage( 68910, @cLangCode, 'DSP') --'Lot04 Required'
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable04
               GOTO Step_5_Fail
            END
         END

         -- Validate lottable05
         IF ISNULL(RTRIM(@cLotlabel05),'') <> ''
         BEGIN
            -- Validate empty
            IF ISNULL(RTRIM(@cLottable05),'') = ''
            BEGIN
               --IF @nFunc = '1772' 
               --BEGIN 
                  SET @cLottable05 = RDT.RDTFormatDate( GETDATE())
               --END
               --ELSE
               --BEGIN
               --   SET @nErrNo = 68912
               --   SET @cErrMsg = rdt.rdtgetmessage( 68912, @cLangCode, 'DSP') --'Lot05 Required'
               --   EXEC rdt.rdtSetFocusField @nMobile, 5 -- Lottable05
               --   GOTO Step_5_Fail
               --END
            END  
         END
      END

      -- Validate empty
      IF ISNULL(RTRIM(@cLottable04),'') <> ''
      BEGIN
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable04) = 0
         BEGIN
            SET @nErrNo = 68911
            SET @cErrMsg = rdt.rdtgetmessage( 68911, @cLangCode, 'DSP') --'Inv Lot04 Date'
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable04
            GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            SET @dLottable04 = CAST( @cLottable04 AS DATETIME)
         END
      END

      -- Validate empty
      IF ISNULL(RTRIM(@cLottable05),'') <> ''
      BEGIN
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable05) = 0
         BEGIN
            SET @nErrNo = 68913
            SET @cErrMsg = rdt.rdtgetmessage( 68913, @cLangCode, 'DSP') --'Inv Lot05 Date'
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- Lottable05
            GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            SET @dLottable05 = CAST( @cLottable05 AS DATETIME)
         END
      END

      IF @nFunc = '1771' 
      BEGIN 
         --check Inventory exists for @nFunc = '1771' 
         SELECT @cInvQTY = ISNULL(SUM(LLI.QTY), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         -- Start (Vanessa02)
         JOIN dbo.LotAttribute LA WITH (NOLOCK)
                           ON (LLI.LOT = LA.LOT 
                               AND ISNULL(RTRIM(LA.Lottable01),'') = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable01),'') END
                               AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable02),'') END
                               AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable03),'') END
                               AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                     CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                          THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                     ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                               AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                     CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                          THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                     ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
         -- End (Vanessa02)
         WHERE LLI.Storerkey = @cStorerkey
            AND LLI.LOC      = @cLOC
            AND LLI.ID       = @cID
            AND LLI.SKU      = @cSKU
            AND LLI.QTY      > 0  -- (Vanessa01)
            /* -- (Vanessa02)
            AND LLI.LOT IN (SELECT LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                            WHERE ISNULL(RTRIM(LA.Lottable01),'')  = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable01),'') END
                               AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable02),'') END
                               AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                          THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                     ELSE ISNULL(RTRIM(@cLottable03),'') END
                               AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                     CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                          THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                     ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                               AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                     CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                          THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                     ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
         */
         IF ISNULL(@cInvQTY, '0') = '0'
         BEGIN
            SET @nErrNo = 68914
            SET @cErrMsg = rdt.rdtgetmessage( 68914, @cLangCode, 'DSP') --IIvt Not Found
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
            GOTO Step_5_Fail    
         END
      END

      IF @nFunc = '1773' 
      BEGIN 
         --check Inventory exists for @nFunc = '1773' 
         -- Start (Vanessa02)
         IF NOT EXISTS (SELECT LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                                           WHERE LA.Storerkey = @cStorerkey
                                              AND LA.SKU      = @cSKU
                                              AND ISNULL(RTRIM(LA.Lottable01),'')  = ISNULL(RTRIM(@cLottable01),'')
                                              AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
                                              AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'')
                                              AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) 
                                              AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103))
         -- End (Vanessa02)
         BEGIN
            SET @nErrNo = 68915
            SET @cErrMsg = rdt.rdtgetmessage( 68915, @cLangCode, 'DSP') --OIvt Not Found
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
            GOTO Step_5_Fail    
         END
      END

      SET ROWCOUNT 1
      SELECT @cUOM   = ISNULL(RTRIM(UOM),''), 
             @cKDQty   = ISNULL(RTRIM(ExpectedQty),0) 
      FROM dbo.KitDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
         AND ExternKitkey = @cWorkOrder
         AND SKU = @cSKU
      SET ROWCOUNT 0

      -- Get QTY If @nFunc = '1772' 
      IF @nFunc = '1772' 
      BEGIN 
         SET ROWCOUNT 1
         SELECT @cPalletQTY = ISNULL(RTRIM(P.Pallet),0),  
	             @cUOMDIV    = CAST(IsNULL(
		                             CASE @cUOM
		                                WHEN P.PackUOM1 THEN P.CaseCNT
		                                WHEN P.PackUOM2 THEN P.InnerPack
		                                WHEN P.PackUOM3 THEN P.QTY
		                                WHEN P.PackUOM4 THEN P.Pallet
		                                WHEN P.PackUOM8 THEN P.OtherUnit1
		                                WHEN P.PackUOM9 THEN P.OtherUnit2
		                             END, 1) AS INT)
         FROM dbo.Pack P WITH (NOLOCK)
            INNER JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.StorerKey = @cStorerkey
            AND S.SKU = @cSKU
            AND @cUOM IN (
               P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, 
               P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9)
         SET ROWCOUNT 0

         IF CAST(@cPalletQTY AS INT) > 0
         BEGIN
            IF CAST(@cKDQty AS INT) > CAST(@cPalletQTY AS INT)
            BEGIN
               SET @cQTY = CAST(CAST(@cPalletQTY AS INT) / CAST(@cUOMDIV AS INT) AS NVARCHAR(10))       
            END
         END
      END

      Step_5_Next:
      BEGIN
         --prepare screen variables
         SET @cOutField01   = @cSKU   -- SKU
         SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04   = @cUOM  -- UOM
         SET @cOutField05   = @cQTY  -- QTY
         SET @cInField04    = @cUOM  -- UOM
         SET @cInField05    = @cQTY  -- QTY

         SET @cFieldAttr01  = ''     -- SKU
         SET @cFieldAttr02  = ''     -- SKU desc 1
         SET @cFieldAttr03  = ''     -- SKU desc 2
         SET @cFieldAttr04  = ''     -- UOM
         SET @cFieldAttr05  = ''     -- QTY
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END  

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      /*
      IF @nFunc = '1771' 
      BEGIN 
         SET @cFieldAttr01  = 'O' -- SKU
         SET @cFieldAttr02  = ''     -- SKU desc 1
         SET @cFieldAttr03  = ''     -- SKU desc 2
         SET @cFieldAttr04  = ''     -- UOM
         SET @cFieldAttr05  = ''     -- QTY
      END
      ELSE
      BEGIN
      */
         SET @cFieldAttr01  = ''     -- SKU
         SET @cFieldAttr02  = ''     -- SKU desc 1
         SET @cFieldAttr03  = ''     -- SKU desc 2
         SET @cFieldAttr04  = ''     -- UOM
         SET @cFieldAttr05  = ''     -- QTY
      -- END

      SET @cOutField01   = @cSKU   -- SKU
      SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
      SET @cInField01    = @cSKU   -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @cLottable04 = ''
      SET @cLottable05 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      -- Reset this screen var
      SET @cOutField01 = @cInField01 -- Lottable01
      SET @cOutField02 = @cInField02 -- Lottable02
      SET @cOutField03 = @cInField03 -- Lottable03
      SET @cOutField04 = @cInField04 -- Lottable04
      SET @cOutField05 = @cInField05 -- Lottable05

      IF @nFunc = '1772' 
      BEGIN 
         -- Validate lottable0Nlabel = '', Disable from Input
         IF ISNULL(RTRIM(@cLotlabel01),'') = '' 
         BEGIN
            SET @cFieldAttr01  = 'O'  -- Lottable01
         END
         
         IF ISNULL(RTRIM(@cLotlabel02),'') = '' 
         BEGIN
            SET @cFieldAttr02  = 'O'  -- Lottable02
         END

         IF ISNULL(RTRIM(@cLotlabel03),'') = '' 
         BEGIN
            SET @cFieldAttr03  = 'O'  -- Lottable03
         END

         IF ISNULL(RTRIM(@cLotlabel04),'') = '' 
         BEGIN
            SET @cFieldAttr04  = 'O'  -- Lottable04
         END

         IF ISNULL(RTRIM(@cLotlabel05),'') = '' 
         BEGIN
            SET @cFieldAttr05  = 'O'  -- Lottable05
         END
      END
      ELSE
      BEGIN
         SET @cFieldAttr01  = ''  -- Lottable01
         SET @cFieldAttr02  = ''  -- Lottable02
         SET @cFieldAttr03  = ''  -- Lottable03
         SET @cFieldAttr04  = ''  -- Lottable04
         SET @cFieldAttr05  = ''  -- Lottable05
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
      END
   END  
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 2265) Input UOM, QTY... 
   SKU:  
   (Field01)                                       -- SKU
   DESC: 
   (Field02)                                       -- SKUDesc (Len  1-20)
   (Field03)                                       -- SKUDesc (Len 21-40)
   UOM: (Field04, input)                           -- UOM
   QTY: (Field05, input)                           -- QTY

   ENTER = Next Page
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUOM = @cInField04
      SET @cQTY = @cInField05

      --Validate UOM field
      IF ISNULL(RTRIM(@cUOM),'') = '' 
      BEGIN
         SET @nErrNo = 68916
         SET @cErrMsg = rdt.rdtgetmessage( 68916, @cLangCode, 'DSP') --UOM Required
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- UOM
         GOTO Step_6_Fail
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
         SET @nErrNo = 68917
         SET @cErrMsg = rdt.rdtgetmessage( 68917, @cLangCode, 'DSP') --Invalid UOM
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- UOM
         GOTO Step_6_Fail    
      END

      --Validate QTY field
      IF ISNULL(RTRIM(@cQTY),'') = '' 
      BEGIN
         SET @nErrNo = 68918
         SET @cErrMsg = rdt.rdtgetmessage( 68918, @cLangCode, 'DSP') --QTY Required
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_6_Fail
      END

      --Validate QTY is numeric
      IF IsNumeric(@cQTY) = 0
      BEGIN
         SET @nErrNo = 68919
         SET @cErrMsg = rdt.rdtgetmessage( 68919, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_6_Fail
      END

      --Validate QTY < 0
      IF CAST(@cQTY AS FLOAT) < 0
      BEGIN
         SET @nErrNo = 68920
         SET @cErrMsg = rdt.rdtgetmessage( 68920, @cLangCode, 'DSP') --QTY must > 0
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_6_Fail
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
         SET @nErrNo = 68921
         SET @cErrMsg = rdt.rdtgetmessage( 68921, @cLangCode, 'DSP') --nspUOMCONV err
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- UOM
         GOTO Step_6_Fail
      END

      SET @nQTY = FLOOR(@nQTY)

      --Validate UOM Convert QTY < 1 
      IF @nQTY < 1  
      BEGIN
         SET @nErrNo = 68922
         SET @cErrMsg = rdt.rdtgetmessage( 68922, @cLangCode, 'DSP') --UOMConvQTY < 1
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_6_Fail
      END

      SELECT @cADJQty = ISNULL(RTRIM(SUM(AD.QTY)),0) -- (Vanessa06)
      FROM dbo.ADJUSTMENTDETAIL AD WITH (NOLOCK)
      JOIN dbo.ADJUSTMENT A WITH (NOLOCK) ON (A.AdjustmentKey = AD.AdjustmentKey) 
      WHERE A.Storerkey = @cStorerkey
         AND A.CustomerRefNo = @cWorkOrder
         -- AND A.AdjustmentType = @cAdjType  -- (Vanessa06)
         AND AD.SKU = @cSKU     

		-- Start (Vanessa06)
		IF @nFunc = '1771' 
      BEGIN 
			SET @cADJQty = -(CAST(@cADJQty AS INT) - @nQTY) 
		END
		ELSE
      BEGIN 
		   SET @cADJQty = CAST(@cADJQty AS INT) + @nQTY
		END

		IF @nFunc = '1773' 
      BEGIN 
			IF CAST(@cADJQty AS INT) > 0
			BEGIN 
				GOTO ADJQty_Checking
			END
		END
		-- End (Vanessa06)

      --Validate UOM Convert QTY > KDQty
      IF CAST(@cADJQty AS INT) > CAST(@cKDQty AS INT)
      BEGIN
			ADJQty_Checking:  -- (Vanessa06)
         IF @cAllowOverADJ = '1'
         BEGIN
            SET @cMsg = 'WARNING:QTY>KITQty'
         END
         ELSE
         BEGIN
            SET @nErrNo = 68953
            SET @cErrMsg = rdt.rdtgetmessage( 68953, @cLangCode, 'DSP') --QTY > KITQTY
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
            GOTO Step_6_Fail         
         END
      END

      IF @nFunc = '1771' 
      BEGIN  
         --Validate UOM Convert QTY > InvQTY
         IF @nQTY > CAST(@cInvQTY AS INT)
         BEGIN
            SET @nErrNo = 68923
            SET @cErrMsg = rdt.rdtgetmessage( 68923, @cLangCode, 'DSP') --QTY not Avail
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
            GOTO Step_6_Fail
         END
      END

      Step_6_Next:
      BEGIN
         --prepare screen variables
         SET @cOutField01   = @cMsg   -- Msg
         SET @cOutField02   = ''      -- Option
         SET @cInField02    = ''      -- Option

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END  

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cLottable01 -- Lottable01
      SET @cOutField02 = @cLottable02 -- Lottable02
      SET @cOutField03 = @cLottable03 -- Lottable03
      SET @cOutField04 = @cLottable04 -- Lottable04
      SET @cOutField05 = @cLottable05 -- Lottable05

      SET @cInField01 = @cLottable01 -- Lottable01
      SET @cInField02 = @cLottable02 -- Lottable02
      SET @cInField03 = @cLottable03 -- Lottable03
      SET @cInField04 = @cLottable04 -- Lottable04
      SET @cInField05 = @cLottable05 -- Lottable05

      IF @nFunc = '1772' 
      BEGIN 
         -- Validate lottable0Nlabel = '', Disable from Input
         IF ISNULL(RTRIM(@cLotlabel01),'') = '' 
         BEGIN
            SET @cFieldAttr01  = 'O'  -- Lottable01
         END
         
         IF ISNULL(RTRIM(@cLotlabel02),'') = '' 
         BEGIN
            SET @cFieldAttr02  = 'O'  -- Lottable02
         END

         IF ISNULL(RTRIM(@cLotlabel03),'') = '' 
         BEGIN
            SET @cFieldAttr03  = 'O'  -- Lottable03
         END

         IF ISNULL(RTRIM(@cLotlabel04),'') = '' 
         BEGIN
            SET @cFieldAttr04  = 'O'  -- Lottable04
         END

         IF ISNULL(RTRIM(@cLotlabel05),'') = '' 
         BEGIN
            SET @cFieldAttr05  = 'O'  -- Lottable05
         END
      END
      ELSE
      BEGIN
         SET @cFieldAttr01  = ''  -- Lottable01
         SET @cFieldAttr02  = ''  -- Lottable02
         SET @cFieldAttr03  = ''  -- Lottable03
         SET @cFieldAttr04  = ''  -- Lottable04
         SET @cFieldAttr05  = ''  -- Lottable05
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
      END

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cUOM = ''
      SET @cQTY = ''
      SET @cMsg = ''

      -- Reset this screen var
      SET @cOutField01   = @cSKU   -- SKU
      SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04   = @cInField04 -- UOM
      SET @cOutField05   = @cInField05 -- QTY
   END  
END
GOTO Quit

/********************************************************************************
Step 7. (screen = 2266) Enter Option
   (Field01)  -- Msg    
   Confirm Adjustment?

   1=YES/NEXT PLT ID
   2=NO
   3=YES/EXIT ALL TASK

   OPTION: (Field02, input)
********************************************************************************/
Step_7:
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
         SET @nErrNo = 68924
         SET @cErrMsg = rdt.rdtgetmessage( 68924, @cLangCode, 'DSP') --Option Needed
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
         GOTO Step_7_Fail  
      END 
      ELSE IF @cOption = '1'
      BEGIN
         -- Check ESC from Screen 2 and 3, Cant Select Option 1
         IF ISNULL(RTRIM(@cSKU),'') = ''
         BEGIN
            SET @nErrNo = 68948
            SET @cErrMsg = rdt.rdtgetmessage( 68948, @cLangCode, 'DSP') --Not Allowed
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
            GOTO Step_7_Fail  
         END

         IF ISNULL(RTRIM(@cAdjustmentKey),'') = ''
         BEGIN
            BEGIN TRAN
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
               ROLLBACK TRAN
               SET @nErrNo = 68925
               SET @cErrMsg = rdt.rdtgetmessage( 68925, @cLangCode, 'DSP') --GetADJKey Fail
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
               GOTO Step_7_Fail
	         END
			   ELSE 
			   BEGIN           
               -- Insert new adjustment header
				   INSERT dbo.ADJUSTMENT (AdjustmentKey, StorerKey, CustomerRefNo, AdjustmentType, Facility)
				   VALUES (@cAdjustmentKey, @cStorerKey, @cWorkOrder, @cAdjType, @cFacility)

				   SELECT @n_err = @@error
				   IF @n_err > 0
				   BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 68926
                  SET @cErrMsg = rdt.rdtgetmessage( 68926, @cLangCode, 'DSP') --INS ADJ Fail
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                  GOTO Step_7_Fail
	      	   END
               COMMIT TRAN
			   END            
         END

         IF @nFunc = '1771' 
         BEGIN   
            DECLARE C_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LLI.LOT, ISNULL(LLI.QTY, 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            -- Start (Vanessa02)
            JOIN dbo.LotAttribute LA WITH (NOLOCK)
                              ON (LLI.LOT = LA.LOT 
                                  AND ISNULL(RTRIM(LA.Lottable01),'') = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable01),'') END
                                  AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable02),'') END
                                  AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable03),'') END
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                        CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                             THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                        ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                        CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                             THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                        ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
            -- End (Vanessa02)
            WHERE LLI.Storerkey = @cStorerkey
               AND LLI.LOC      = @cLOC
               AND LLI.ID       = @cID
               AND LLI.SKU      = @cSKU
               AND LLI.QTY      > 0  -- (Vanessa01)
               /* -- (Vanessa02)
               AND LLI.LOT IN (SELECT LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                               WHERE ISNULL(RTRIM(LA.Lottable01),'')  = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable01),'') END
                                  AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable02),'') END
                                  AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                             THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                        ELSE ISNULL(RTRIM(@cLottable03),'') END
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                        CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                             THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                        ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                        CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                             THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                        ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
            */
            ORDER BY LLI.LOT
            OPEN C_LOT
            FETCH NEXT FROM C_LOT INTO  @cLOT, @cLotQTY  
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               IF @nQTY = 0
               BEGIN  
                  BREAK
               END
   
               IF CAST(@cLotQTY AS INT) <= @nQTY
               BEGIN  
                  SET @nQTY = @nQTY - CAST(@cLotQTY AS INT)
                  SET @nQtyInsert = CAST(@cLotQTY AS INT)
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
            
                  BEGIN TRAN
                  INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                          UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
                  VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                          @cUOM, @cPackKey, -@nQtyInsert, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
               --END                -- (Vanessa01) -- (Vanessa04)
         
		            SET @n_err = @@error
		            IF @n_err <> 0
		            BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68927
                     SET @cErrMsg = rdt.rdtgetmessage( 68927, @cLangCode, 'DSP') --INS ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
                     BREAK
   	            END  
                  ELSE
                  BEGIN
                     BEGIN TRAN
                     UPDATE dbo.AdjustmentDetail WITH (ROWLOCK)
                     SET FinalizedFlag = 'Y'
                     WHERE AdjustmentKey = @cAdjustmentKey
                        AND AdjustmentLineNumber = @cAdjDetailLine

                     SET @n_err = @@error
                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68928
                        SET @cErrMsg = rdt.rdtgetmessage( 68928, @cLangCode, 'DSP') --UPD ADJDT Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                     END   
                     COMMIT TRAN
                  END
                  COMMIT TRAN
               END                -- (Vanessa04)

               FETCH NEXT FROM C_LOT INTO  @cLOT, @cLotQTY  
            END --end of while
            CLOSE C_LOT
            DEALLOCATE C_LOT
         END  

         IF @nFunc = '1772' 
         BEGIN  
            IF @nQty > 0  -- (Vanessa04)
            BEGIN         -- (Vanessa04) 
               SELECT @b_isok = 0
               EXECUTE dbo.nsp_LotLookUp 
                   @cStorerKey
                 , @cSKU
                 , @cLottable01
                 , @cLottable02
                 , @cLottable03
                 , @dLottable04
                 , @dLottable05
                 , @cLOT       OUTPUT
                 , @b_isok     OUTPUT
                 , @n_err      OUTPUT
                 , @c_errmsg   OUTPUT
         
               IF @b_isok = 1
               BEGIN                    
                   /* Add To Lotattribute File */
                   BEGIN TRAN
                   SELECT @b_isok = 0
                   EXECUTE dbo.nsp_lotgen
                        @cStorerKey
                      , @csku
                      , @clottable01
                      , @clottable02
                      , @clottable03
                      , @dlottable04
                      , @dlottable05
                      , @cLOT       OUTPUT
                      , @b_isok     OUTPUT
                      , @n_err      OUTPUT
                      , @c_errmsg   OUTPUT

                  IF @b_isok <> 1
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68929
                     SET @cErrMsg = rdt.rdtgetmessage( 68929, @cLangCode, 'DSP') --Get Lot Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
                  END  
                  COMMIT TRAN 
               END  

            --IF @nQty > 0  -- (Vanessa01) -- (Vanessa04)
            --BEGIN         -- (Vanessa01) -- (Vanessa04)
               SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
               FROM  dbo.AdjustmentDetail (NOLOCK)
               WHERE AdjustmentKey = @cAdjustmentKey
         
               BEGIN TRAN
               INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                       UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
               VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                       @cUOM, @cPackKey, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
            --END -- (Vanessa01) -- (Vanessa04)

	            SET @n_err = @@error
	            IF @n_err <> 0
	            BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 68930
                  SET @cErrMsg = rdt.rdtgetmessage( 68930, @cLangCode, 'DSP') --INS ADJDT Fail
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                  GOTO Step_7_Fail
	            END  
               ELSE
               BEGIN
                  SELECT @cHoldSetup = ISNULL(RTRIM(Data), '0') 
                  FROM dbo.SKUCONFIG WITH (NOLOCK)  
                  WHERE ConfigType='HoldByLottable02'
                  And StorerKey = @cStorerKey
                  AND SKU = @cSKU

                  IF @cHoldSetup = '1'    
                  BEGIN
                     SELECT @cCurrentHold = ISNULL(RTRIM(HOLD), '0')
                     FROM dbo.INVENTORYHOLD WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND Lottable02 = @cLottable02

                     IF @cCurrentHold = '1'
                     BEGIN
                        SET @cLotStatus = 'HOLD'
                     END
                     ELSE
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @cOtherOKlot = COUNT(1) 
                        FROM dbo.Lot L WITH (NOLOCK)
                        JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = L.Lot)
                        WHERE L.Storerkey = @cStorerKey
                        AND L.Sku = @cSKU
                        AND L.Status = 'OK'
                        AND LA.Lottable02 = @cLottable02
                        SET ROWCOUNT 0

                        IF @cOtherOKlot = '0'
                        BEGIN
                           SET @cHoldByLot02 = 'Y'
                        END                     
                     END            
                  END

                  BEGIN TRAN
                  -- Create inventory record
                  SELECT @b_success = 0      
                  SELECT @cSourceKey = @cAdjustmentKey + @cAdjDetailLine
                  EXECUTE dbo.nspItrnAddDeposit         
                     NULL,        
                     @cStorerKey,         
                     @cSKU,         
                     @cLOT,         
                     @cLOC,         
                     @cID,         
                     'OK',        
                     @cLottable01,         
                     @cLottable02,         
                     @cLottable03,         
                     @dLottable04,         
                     @dLottable05,        
                     0,        
                     0,        
                     0, -- QTY        
                     0,        
                     0,        
                     0,        
                     0,        
                     0,        
                     0,        
                     @cSourceKey,        
                     'rdtfnc_WorkOrderAdjustment',        
                     @cPackKey,         
                     @cUOM,         
                     1,        
                     NULL,        
                     @cItrnKey     OUTPUT,        
                     @b_success    OUTPUT,        
                     @n_err        OUTPUT,        
                     @c_errmsg     OUTPUT    

				      SELECT @n_err = @@error
				      IF @b_success <> 1
				      BEGIN
				         IF @n_err <> 0
				         BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68931
                        SET @cErrMsg = rdt.rdtgetmessage( 68931, @cLangCode, 'DSP') --INS Lot Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail     
	      	         END		
                  END			   
                  COMMIT TRAN 

                  BEGIN TRAN
                  UPDATE dbo.AdjustmentDetail WITH (ROWLOCK)  
                  SET FinalizedFlag = 'Y'
                  WHERE AdjustmentKey = @cAdjustmentKey
                     AND AdjustmentLineNumber = @cAdjDetailLine

                  SET @n_err = @@error
                  IF @n_err <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68932
                     SET @cErrMsg = rdt.rdtgetmessage( 68932, @cLangCode, 'DSP') --UPD ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
                  END   
                  COMMIT TRAN  

                  IF @cLotStatus = 'HOLD'
                  BEGIN
                     BEGIN TRAN
                     UPDATE dbo.LOT WITH (ROWLOCK)
                     SET Status = @cLotStatus
                     WHERE LOT = @cLOT

                     SET @n_err = @@error
                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68956
                        SET @cErrMsg = rdt.rdtgetmessage( 68956, @cLangCode, 'DSP') --UPD LOT Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                     END   
                     COMMIT TRAN  
                  END

                  IF @cHoldByLot02 = 'Y'
                  BEGIN
                     SET @cRemark = 'AUTO HOLD from RDT WorkOrder Adjustment!'
                     BEGIN TRAN
                     EXEC dbo.nspInventoryHoldWrapper   
                        '',               -- lot  
                        '',               -- loc  
                        '',               -- id  
                        @cStorerKey,      -- storerkey  
                        @cSKU,            -- sku  
                        '',               -- lottable01  
                        @cLottable02,     -- lottable02  
                        '',               -- lottable03  
                        NULL,             -- lottable04  
                        NULL,             -- lottable05  
                        'QC',             -- status     
                        '1',              -- hold  
                        @b_success OUTPUT,    
                        @n_err OUTPUT,   
                        @c_errmsg OUTPUT,  
                        @cRemark          -- remark     
                                                  
                     IF NOT @b_success = 1  
                     BEGIN  
                        ROLLBACK TRAN
                        SET @nErrNo = 68954
                        SET @cErrMsg = rdt.rdtgetmessage( 68954, @cLangCode, 'DSP') --InsInvHKeyFail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail                
                     END  
                     COMMIT TRAN
                  END

                  BEGIN TRAN
                  UPDATE dbo.Kit WITH (ROWLOCK) 
                  SET Status = '3'
                  WHERE ExternKitkey = @cWorkOrder
                     AND Storerkey = @cStorerkey

	               SET @n_err = @@error
	               IF @n_err <> 0
	               BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68933
                     SET @cErrMsg = rdt.rdtgetmessage( 68933, @cLangCode, 'DSP') --UPD Kit Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
	               END   
                  COMMIT TRAN  

                  BEGIN TRAN
                  -- Call printing spooler
                  INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                  VALUES('PRINTPALLETLABEL_WORKORDER', 'PLTLBLWO', '0', @cDataWindow, 3, @cWorkOrder, @cID, @cID, @cPrinter, 1, @nMobile, @cTargetDB)               

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN
                  END
                  COMMIT TRAN
               END   
            END -- (Vanessa04)            
         END     

         IF @nFunc = '1773' 
         BEGIN   
            SET ROWCOUNT 1
            -- Start (Vanessa02)
            SELECT @cLOT = LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                               WHERE LA.Storerkey = @cStorerkey
                                  AND LA.SKU      = @cSKU
                                  AND ISNULL(RTRIM(LA.Lottable01),'')  = ISNULL(RTRIM(@cLottable01),'')
                                  AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
                                  AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'')
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) 
                                  AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103)
            -- End (Vanessa02)
            SET ROWCOUNT 0

            IF @nQty > 0  -- (Vanessa01)
            BEGIN         -- (Vanessa01)
               SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
               FROM  dbo.AdjustmentDetail (NOLOCK)
               WHERE AdjustmentKey = @cAdjustmentKey
         
               BEGIN TRAN
               INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                       UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
               VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                       @cUOM, @cPackKey, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
            --END -- (Vanessa01) -- (Vanessa04)
      
	            SET @n_err = @@error
	            IF @n_err <> 0
	            BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 68934
                  SET @cErrMsg = rdt.rdtgetmessage( 68934, @cLangCode, 'DSP') --INS ADJDT Fail
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                  GOTO Step_7_Fail
	            END  
               ELSE
               BEGIN
                  BEGIN TRAN
                  UPDATE dbo.AdjustmentDetail WITH (ROWLOCK) 
                  SET FinalizedFlag = 'Y'
                  WHERE AdjustmentKey = @cAdjustmentKey
                     AND AdjustmentLineNumber = @cAdjDetailLine

                  SET @n_err = @@error
                  IF @n_err <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68935
                     SET @cErrMsg = rdt.rdtgetmessage( 68935, @cLangCode, 'DSP') --UPD ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
                  END   
                  COMMIT TRAN
               END
               COMMIT TRAN
            END -- (Vanessa04)
         END         
         
         -- Go to Screen 3
         SET @nScn              = 2262
         SET @nStep             = 3
         SET @cLOT              = ''
         SET @cSKU              = ''
         SET @cPackKey          = ''
         SET @cSKUDesc          = ''
         SET @nQty              = 0
         SET @cKDQty            = '0'
         SET @cADJQty           = '0'
         SET @cInvQTY           = '0'
         SET @cLotQTY           = '0'
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

         SET @cOutField01 = @cLOC -- LOC  

         IF @nFunc = '1772' 
         BEGIN   
            EXECUTE dbo.nspg_GetKey
                     'ID', 
                     10 ,
                     @cID               OUTPUT,
                     @b_success         OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 68949
               SET @cErrMsg = rdt.rdtgetmessage( 68949, @cLangCode, 'DSP') -- 'GetIDKey Fail'
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               -- Init next screen var
               SET @cFieldAttr02  = 'O' -- ID -- (Vanessa05)
               SET @cOutField02 = @cID -- ID
					SET @cInField02  = @cID -- ID  -- (Vanessa05)
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            END
         END
         ELSE
         BEGIN    
            SET @cFieldAttr02  = '' -- ID -- (Vanessa05)
            SET @cOutField02 = ''    -- ID  
            SET @cInField02  = ''    -- ID
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID 
         END      
      END
      ELSE IF @cOption = '2'
      BEGIN
         -- Go to Screen 2
         SET @nScn              = 2261
         SET @nStep             = 2
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
         SET @cLotQTY           = '0'
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

         SET @cOutField01       = '' -- LOC 
         SET @cInField01        = '' -- LOC 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC      
      END
      ELSE IF @cOption = '3'
      BEGIN
         -- Check ESC from Screen 2 and 3, Cant Add Adjustment Ticket
         IF ISNULL(RTRIM(@cSKU),'') <> ''
         BEGIN
            IF ISNULL(RTRIM(@cAdjustmentKey),'') = ''
            BEGIN
               BEGIN TRAN
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
                  ROLLBACK TRAN
                  SET @nErrNo = 68936
                  SET @cErrMsg = rdt.rdtgetmessage( 68936, @cLangCode, 'DSP') --GetADJKey Fail
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                  GOTO Step_7_Fail
	            END
			      ELSE 
			      BEGIN
                  -- Insert new adjustment header
				      INSERT dbo.ADJUSTMENT (AdjustmentKey, StorerKey, CustomerRefNo, AdjustmentType, Facility)
				      VALUES (@cAdjustmentKey, @cStorerKey, @cWorkOrder, @cAdjType, @cFacility)

				      SELECT @n_err = @@error
				      IF @n_err > 0
				      BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68937
                     SET @cErrMsg = rdt.rdtgetmessage( 68937, @cLangCode, 'DSP') --INS ADJ Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
	      	      END
                  COMMIT TRAN
			      END            
            END

            IF @nFunc = '1771' 
            BEGIN   
               DECLARE C_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LLI.LOT, ISNULL(LLI.QTY, 0)
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               -- Start (Vanessa02)
               JOIN dbo.LotAttribute LA WITH (NOLOCK)
                                 ON (LLI.LOT = LA.LOT 
                                     AND ISNULL(RTRIM(LA.Lottable01),'') = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable01),'') END
                                     AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable02),'') END
                                     AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable03),'') END
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                           CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                                THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                           ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                           CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                                THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                           ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
               -- End (Vanessa02)
               WHERE LLI.Storerkey = @cStorerkey
                  AND LLI.LOC      = @cLOC
                  AND LLI.ID       = @cID
                  AND LLI.SKU      = @cSKU
                  AND LLI.QTY      > 0  -- (Vanessa01)
                  /* -- (Vanessa02)
                  AND LLI.LOT IN (SELECT LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                                  WHERE ISNULL(RTRIM(LA.Lottable01),'')  = CASE WHEN ISNULL(RTRIM(@cLottable01),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable01),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable01),'') END
                                     AND ISNULL(RTRIM(LA.Lottable02),'') = CASE WHEN ISNULL(RTRIM(@cLottable02),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable02),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable02),'') END
                                     AND ISNULL(RTRIM(LA.Lottable03),'') = CASE WHEN ISNULL(RTRIM(@cLottable03),'') = '' 
                                                                                THEN ISNULL(RTRIM(LA.Lottable03),'')
                                                                           ELSE ISNULL(RTRIM(@cLottable03),'') END
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = 
                                                                           CASE WHEN ISNULL(RTRIM(@cLottable04),'') = '' 
                                                                                THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103)
                                                                           ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) END
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = 
                                                                           CASE WHEN ISNULL(RTRIM(@cLottable05),'') = '' 
                                                                                THEN Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103)
                                                                           ELSE Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103) END)
               */
               ORDER BY LLI.LOT
               OPEN C_LOT
               FETCH NEXT FROM C_LOT INTO  @cLOT, @cLotQTY  
               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  IF @nQTY = 0
                  BEGIN  
                     BREAK
                  END
      
                  IF CAST(@cLotQTY AS INT) <= @nQTY
                  BEGIN  
                     SET @nQTY = @nQTY - CAST(@cLotQTY AS INT)
                     SET @nQtyInsert = CAST(@cLotQTY AS INT)
                  END  
                  ELSE
                  BEGIN
                     SET @nQtyInsert = @nQTY
                     SET @nQTY = 0 -- (Vanessa01)
                  END

                  IF @nQtyInsert > 0  -- (Vanessa01)
                  BEGIN               -- (Vanessa01)
                     SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5)  --(Shong01)
                     FROM  dbo.AdjustmentDetail (NOLOCK)
                     WHERE AdjustmentKey = @cAdjustmentKey
               
                     BEGIN TRAN
                     INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                             UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
                     VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                             @cUOM, @cPackKey, -@nQtyInsert, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
                  --END -- (Vanessa01) -- (Vanessa04)
               
		               SET @n_err = @@error
		               IF @n_err <> 0
		               BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68938
                        SET @cErrMsg = rdt.rdtgetmessage( 68938, @cLangCode, 'DSP') --INS ADJDT Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                        BREAK
   	               END  
                     ELSE
                     BEGIN
                        BEGIN TRAN
                        UPDATE dbo.AdjustmentDetail WITH (ROWLOCK) 
                        SET FinalizedFlag = 'Y'
                        WHERE AdjustmentKey = @cAdjustmentKey
                           AND AdjustmentLineNumber = @cAdjDetailLine

                        SET @n_err = @@error
                        IF @n_err <> 0
                        BEGIN
                           ROLLBACK TRAN
                           SET @nErrNo = 68939
                           SET @cErrMsg = rdt.rdtgetmessage( 68939, @cLangCode, 'DSP') --UPD ADJDT Fail
                           EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                           GOTO Step_7_Fail
                        END   
                        COMMIT TRAN
                     END
                     COMMIT TRAN
                  END -- (Vanessa04)

                  FETCH NEXT FROM C_LOT INTO  @cLOT, @cLotQTY  
               END --end of while
               CLOSE C_LOT
               DEALLOCATE C_LOT
            END  

            IF @nFunc = '1772' 
            BEGIN   
               IF @nQty > 0  -- (Vanessa04)
               BEGIN         -- (Vanessa04)
                  SELECT @b_isok = 0
                  EXECUTE dbo.nsp_LotLookUp 
                      @cStorerKey
                    , @cSKU
                    , @cLottable01
                    , @cLottable02
                    , @cLottable03
                    , @dLottable04
                    , @dLottable05
                    , @cLOT       OUTPUT
                    , @b_isok     OUTPUT
                    , @n_err      OUTPUT
                    , @c_errmsg   OUTPUT
            
                  IF @b_isok = 1
                  BEGIN                    
                      /* Add To Lotattribute File */
                      BEGIN TRAN
                      SELECT @b_isok = 0
                      EXECUTE dbo.nsp_lotgen
                           @cStorerKey
                         , @cSKU
                         , @cLottable01
                         , @cLottable02
                         , @cLottable03
                         , @dLottable04
                         , @dLottable05
                         , @cLOT       OUTPUT
                         , @b_isok     OUTPUT
                         , @n_err      OUTPUT
                         , @c_errmsg   OUTPUT

                     IF @b_isok <> 1
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68940
                        SET @cErrMsg = rdt.rdtgetmessage( 68940, @cLangCode, 'DSP') --Get Lot Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                     END  
                     COMMIT TRAN 
                  END  

               --IF @nQty > 0  -- (Vanessa01) -- (Vanessa04)
               --BEGIN         -- (Vanessa01) -- (Vanessa04)
                  SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
                  FROM  dbo.AdjustmentDetail (NOLOCK)
                  WHERE AdjustmentKey = @cAdjustmentKey
            
                  BEGIN TRAN
                  INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                          UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
                  VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                          @cUOM, @cPackKey, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
               --END -- (Vanessa01) -- (Vanessa04)

	               SET @n_err = @@error
	               IF @n_err <> 0
	               BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68941
                     SET @cErrMsg = rdt.rdtgetmessage( 68941, @cLangCode, 'DSP') --INS ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
	               END  
                  ELSE
                  BEGIN
                     SELECT @cHoldSetup = ISNULL(RTRIM(Data), '0') 
                     FROM dbo.SKUCONFIG WITH (NOLOCK)  
                     WHERE ConfigType='HoldByLottable02'
                     And StorerKey = @cStorerKey
                     AND SKU = @cSKU

                     IF @cHoldSetup = '1'    
                     BEGIN
                        SELECT @cCurrentHold = ISNULL(RTRIM(HOLD), '0')
                        FROM dbo.INVENTORYHOLD WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND SKU = @cSKU
                        AND Lottable02 = @cLottable02

                        IF @cCurrentHold = '1'
                        BEGIN
                           SET @cLotStatus = 'HOLD'
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @cOtherOKlot = COUNT(1) 
                           FROM dbo.Lot L WITH (NOLOCK)
                           JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = L.Lot)
                           WHERE L.Storerkey = @cStorerKey
                           AND L.Sku = @cSKU
                           AND L.Status = 'OK'
                           AND LA.Lottable02 = @cLottable02
                           SET ROWCOUNT 0

                           IF @cOtherOKlot = '0'
                           BEGIN
                              SET @cHoldByLot02 = 'Y'
                           END                     
                        END            
                     END

                     BEGIN TRAN
                     -- Create inventory record
                     SELECT @b_success = 0  
                     SELECT @cSourceKey = @cAdjustmentKey + @cAdjDetailLine    
                     EXECUTE dbo.nspItrnAddDeposit         
                        NULL,        
                        @cStorerKey,         
                        @cSKU,         
                        @cLOT,         
                        @cLOC,         
                        @cID,         
                        'OK',        
                        @cLottable01,         
                        @cLottable02,         
                        @cLottable03,         
                        @dLottable04,         
                        @dLottable05,        
                        0,        
                        0,        
                        0, -- QTY       
                        0,        
                        0,        
                        0,        
                        0,        
                        0,        
                        0,        
                        @cSourceKey,        
                        'rdtfnc_WorkOrderAdjustment',        
                        @cPackKey,         
                        @cUOM,         
                        1,        
                        NULL,        
                        @cItrnKey     OUTPUT,        
                        @b_success    OUTPUT,        
                        @n_err        OUTPUT,        
                        @c_errmsg     OUTPUT        
				         SELECT @n_err = @@error
				         IF @b_success <> 1
				         BEGIN
				            IF @n_err <> 0
				            BEGIN
                           ROLLBACK TRAN
                           SET @nErrNo = 68942
                           SET @cErrMsg = rdt.rdtgetmessage( 68942, @cLangCode, 'DSP') --INS Lot Fail
                           EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                           GOTO Step_7_Fail     
	      	            END		
                     END	
                     COMMIT TRAN       

                     BEGIN TRAN
                     UPDATE dbo.AdjustmentDetail WITH (ROWLOCK) 
                     SET FinalizedFlag = 'Y'
                     WHERE AdjustmentKey = @cAdjustmentKey
                        AND AdjustmentLineNumber = @cAdjDetailLine

                     SET @n_err = @@error
                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68943
                        SET @cErrMsg = rdt.rdtgetmessage( 68943, @cLangCode, 'DSP') --UPD ADJDT Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                     END   
                     COMMIT TRAN  

                     IF @cLotStatus = 'HOLD'
                     BEGIN
                        BEGIN TRAN
                        UPDATE dbo.LOT WITH (ROWLOCK)
                        SET Status = @cLotStatus
                        WHERE LOT = @cLOT

                        SET @n_err = @@error
                        IF @n_err <> 0
                        BEGIN
                           ROLLBACK TRAN
                           SET @nErrNo = 68957
                           SET @cErrMsg = rdt.rdtgetmessage( 68957, @cLangCode, 'DSP') --UPD LOT Fail
                           EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                           GOTO Step_7_Fail
                        END   
                        COMMIT TRAN  
                     END

                     IF @cHoldByLot02 = 'Y'
                     BEGIN
                        SET @cRemark = 'AUTO HOLD from RDT WorkOrder Adjustment!'
                        BEGIN TRAN
                        EXEC dbo.nspInventoryHoldWrapper   
                           '',               -- lot  
                           '',               -- loc  
                           '',               -- id  
                           @cStorerKey,      -- storerkey  
                           @cSKU,            -- sku  
                           '',               -- lottable01  
                           @cLottable02,     -- lottable02  
                           '',               -- lottable03  
                           NULL,             -- lottable04  
                           NULL,             -- lottable05  
                           'QC',             -- status     
                           '1',              -- hold  
                           @b_success OUTPUT,    
                           @n_err OUTPUT,   
                           @c_errmsg OUTPUT,  
                           @cRemark          -- remark     
                                                     
                        IF NOT @b_success = 1  
                        BEGIN  
                           ROLLBACK TRAN
                           SET @nErrNo = 68955
                           SET @cErrMsg = rdt.rdtgetmessage( 68955, @cLangCode, 'DSP') --InsInvHKeyFail
                           EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                           GOTO Step_7_Fail                
                        END  
                        COMMIT TRAN
                     END

                     BEGIN TRAN
                     UPDATE dbo.Kit WITH (ROWLOCK) 
                     SET Status = '3'
                     WHERE ExternKitkey = @cWorkOrder
                        AND Storerkey = @cStorerkey

	                  SET @n_err = @@error
	                  IF @n_err <> 0
	                  BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68944
                        SET @cErrMsg = rdt.rdtgetmessage( 68944, @cLangCode, 'DSP') --UPD Kit Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
	                  END   
                     COMMIT TRAN  

                     BEGIN TRAN
                     -- Call printing spooler
                     INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
                     VALUES('PRINTPALLETLABEL_WORKORDER', 'PLTLBLWO', '0', @cDataWindow, 3, @cWorkOrder, @cID, @cID, @cPrinter, 1, @nMobile, @cTargetDB)               

                     IF @@ERROR <> 0
                     BEGIN
                        ROLLBACK TRAN
                     END
                     COMMIT TRAN
                  END       
               END -- (Vanessa04)
            END     

            IF @nFunc = '1773' 
            BEGIN   
               SET ROWCOUNT 1
               -- Start (Vanessa02)
               SELECT @cLOT = LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
                                  WHERE LA.Storerkey = @cStorerkey
                                     AND LA.SKU      = @cSKU
                                     AND ISNULL(RTRIM(LA.Lottable01),'')  = ISNULL(RTRIM(@cLottable01),'')
                                     AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
                                     AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'')
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable04),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable04),''),103) 
                                     AND Convert(Varchar(11),ISNULL(RTRIM(LA.Lottable05),''),103) = Convert(Varchar(11),ISNULL(RTRIM(@dLottable05),''),103)
               -- End (Vanessa02)
               SET ROWCOUNT 0

               IF @nQty > 0  -- (Vanessa01)
               BEGIN         -- (Vanessa01)
                  SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
                  FROM  dbo.AdjustmentDetail (NOLOCK)
                  WHERE AdjustmentKey = @cAdjustmentKey
            
                  BEGIN TRAN
                  INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                          UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
                  VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                          @cUOM, @cPackKey, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
               --END -- (Vanessa01) -- (Vanessa04)                   

	               SET @n_err = @@error
	               IF @n_err <> 0
	               BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 68945
                     SET @cErrMsg = rdt.rdtgetmessage( 68945, @cLangCode, 'DSP') --INS ADJDT Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                     GOTO Step_7_Fail
	               END 
                  ELSE
                  BEGIN
                     BEGIN TRAN
                     UPDATE dbo.AdjustmentDetail WITH (ROWLOCK) 
                     SET FinalizedFlag = 'Y'
                     WHERE AdjustmentKey = @cAdjustmentKey
                        AND AdjustmentLineNumber = @cAdjDetailLine

                     SET @n_err = @@error
                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRAN
                        SET @nErrNo = 68946
                        SET @cErrMsg = rdt.rdtgetmessage( 68946, @cLangCode, 'DSP') --UPD ADJDT Fail
                        EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
                        GOTO Step_7_Fail
                     END   
                     COMMIT TRAN
                  END 
                  COMMIT TRAN
               END -- (Vanessa04)
            END   
         END

         BEGIN TRAN
         UPDATE dbo.ADJUSTMENT WITH (ROWLOCK) 
         SET FinalizedFlag = 'Y'
         WHERE AdjustmentKey = @cAdjustmentKey

         SET @n_err = @@error
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 68947
            SET @cErrMsg = rdt.rdtgetmessage( 68947, @cLangCode, 'DSP') --UPD ADJ Fail
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
            GOTO Step_7_Fail
         END   
         COMMIT TRAN  

         -- Go to Screen 1
         SET @nScn              = 2260
         SET @nStep             = 1
         SET @cLOT              = ''
         SET @cLOC              = ''
         SET @cID               = ''
         SET @cSKU              = ''
         SET @cPackKey          = ''
         SET @cDefaultUOM       = ''
         SET @cWorkOrder        = ''
         SET @cSKUDesc          = ''
         SET @nQty              = 0
         SET @cKDQty            = '0'
         SET @cADJQty           = '0'
         SET @cInvQTY           = '0'
         SET @cLotQTY           = '0'
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
         SET @cLastScn          = ''
         SET @cLastStep         = ''
         SET @cAdjustmentKey    = ''
         SET @cAdjDetailLine    = ''
         SET @cItrnKey          = ''
         SET @cSourceKey        = ''

         SET @cOutField01       = '' -- WorkOrder   
         SET @cInField01        = '' -- WorkOrder    
      END
      ELSE
      BEGIN
         SET @nErrNo = 67349
         SET @cErrMsg = rdt.rdtgetmessage( 67349, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
         GOTO Step_7_Fail  
      END 
   END  
   GOTO Quit

   Step_7_Fail:
   BEGIN
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
      EditDate          = GETDATE(), 
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
       V_String16        = @cLotQTY,
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