SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Material_Return                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Picking: Material Return by Work Order                      */
/*                   (E1MY - E1 Manufacturing)                          */
/* SOS: 217207                                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2011-06-07   1.0  James      Created                                 */
/* 2011-08-05   1.1  James      Bug fix (james01)                       */
/* 2016-09-30   1.2  Ung        Performance tuning                      */
/* 2018-11-02   1.3  Gan        Performance tuning                      */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_Material_Return](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
	@b_success			   INT,
   @b_isok              INT,
	@n_err				   INT,
	@c_errmsg			   NVARCHAR( 250) 
  
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cUserName           NVARCHAR(18),
   @cPrinter            NVARCHAR(10),
   
   @cLOT                NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cPackKey            NVARCHAR( 10),
   @cDefaultUOM         NVARCHAR( 1),
   @cWorkOrder          NVARCHAR( 10), 
   @cSKUDesc            NVARCHAR( 60),
   @nQty                INT,
   @nQtyInsert          INT,
   @nSKUCnt             INT,
   @nCountLot           INT,
   @cKDQty              NVARCHAR( 10),
   @cADJQty             NVARCHAR( 10),
   @cInvQTY             NVARCHAR( 10),
   @cLotQTY             NVARCHAR( 10),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLotLabel01         NVARCHAR( 20),
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cUOM                NVARCHAR( 10),
   @cQTY                NVARCHAR( 10),
   @cMsg                NVARCHAR( 20),
   @cOption             NVARCHAR( 1),
   @cLastScn            NVARCHAR( 5),
   @cLastStep           NVARCHAR( 5),
	@cAdjustmentKey	   NVARCHAR( 10),
	@cAdjDetailLine	   NVARCHAR( 5),
   @cAdjType            NVARCHAR( 3),
   @cAdjReasonCode      NVARCHAR( 10),
   @cItrnKey            NVARCHAR( 10),
   @cSourceKey          NVARCHAR( 20),
   @cAllowOverADJ       NVARCHAR( 1),
   @cRemark             NVARCHAR( 255),
   @cActSKU             NVARCHAR( 20),
   @cStoredProd         NVARCHAR( 250),  
   @cLottable01_Code    NVARCHAR( 20),  
   @cLottable02_Code    NVARCHAR( 20),  
   @cLottable03_Code    NVARCHAR( 20),  
   @cLottable04_Code    NVARCHAR( 20),  
   @cLottable05_Code    NVARCHAR( 20),  
   @cHasLottable        NVARCHAR( 1),  
   @cListName           NVARCHAR( 20),  
   @cShort              NVARCHAR( 10),  
   @cLottableLabel      NVARCHAR( 20),  
   @cTempLottable01     NVARCHAR( 18),  
   @cTempLottable02     NVARCHAR( 18),  
   @cTempLottable03     NVARCHAR( 18),  
   @cTempLottable04     NVARCHAR( 16),  
   @cTempLottable05     NVARCHAR( 16),  
   @dTempLottable04     DATETIME,  
   @dTempLottable05     DATETIME,  
   @nTranCount          INT,     -- (james01)
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
  
SET @c_TraceName = 'rdtfnc_Material_Return'  
            
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
   @cUserName           = UserName, 
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
   @cPackKey            = V_String5,
   @cKDQty              = V_String6,
   @cMsg                = V_String7,
   @cInvQTY             = V_String8,
   @cLastScn            = V_String9,
   @cLastStep           = V_String10,
   @cAdjustmentKey      = V_String11,
   @cAdjDetailLine      = V_String12,
   @cAdjType            = V_String13,
   @cLotQTY             = V_String14,
   @cAdjReasonCode      = V_String15,
   @cItrnKey            = V_String16,
   @cSourceKey          = V_String17,
   @cADJQty             = V_String18,
   @cAllowOverADJ       = V_String19,
   @cLottable01_Code    = V_String20, 
   @cLottable02_Code    = V_String21, 
   @cLottable03_Code    = V_String22, 
   @cLottable04_Code    = V_String23, 
   @cLottable05_Code    = V_String24, 
   @cPrevWorkOrder      = V_String25,

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

IF @nFunc = 1785 -- Material Return By WorkOrder
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. 1785
   IF @nStep = 1 GOTO Step_1   -- Scn = 2850   Scan-in the WorkOrder#
   IF @nStep = 2 GOTO Step_2   -- Scn = 2851   Scan-in the LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 2852   Scan-in the SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 2853   Scan-in the LOTTABLE
   IF @nStep = 5 GOTO Step_5   -- Scn = 2854   Input UOM, QTY...
   IF @nStep = 6 GOTO Step_6   -- Scn = 2855   Enter Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu 
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2850
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
   SET @cLotQTY           = '0'
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
   SET @cPrevWorkOrder    = ''     -- (james01)

   SET @cAdjType = 'MR'

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
Step 1. screen = 2850 Scan-in the WorkOrder#
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
         SET @nErrNo = 73301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO Needed
         GOTO Step_1_Fail  
      END 

      --check WO exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder)
      BEGIN
         SET @nErrNo = 73302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WO
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Kit WITH (NOLOCK)
         WHERE ExternKitkey = @cWorkOrder
           AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 73303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Storer
         GOTO Step_1_Fail    
      END

      --check ADJ facility
      IF Right(ISNULL(RTRIM(@cFacility), '') ,2) <> '10'
      BEGIN
         SET @nErrNo = 73304
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
         SET @nErrNo = 73305
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
         SET @nErrNo = 73306
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
         SET @nErrNo = 73307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO Cancelled
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
            SET @nErrNo = 73340
            SET @cErrMsg = rdt.rdtgetmessage( 73340, @cLangCode, 'DSP') --UPD ADJ Fail
            GOTO Step_1_Fail
         END   
         ELSE
         BEGIN
            COMMIT TRAN
            SET @cAdjustmentKey = ''
         END
      END      

      --prepare next screen variable
      SET @cLOC = ''
      SET @cOutField01 = @cWorkOrder   -- WorkOrder
      SET @cOutField02 = ''            -- LOC
             
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
            SET @nErrNo = 73339
            SET @cErrMsg = rdt.rdtgetmessage( 73339, @cLangCode, 'DSP') --UPD ADJ Fail
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
Step 2. (screen = 2851) Scan-in the LOC 
   LOC:  (Field01, input)
 
   ENTER =  Next Page
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02

      --When LOC is blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 73308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Required
         GOTO Step_2_Fail  
      END 

      --check LOC exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 73309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail    
      END

      --check diff facility
      IF NOT EXISTS (SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 73310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Fac
         GOTO Step_2_Fail    
      END

      --prepare next screen variable
      SET @cSKU = ''
      SET @cOutField01 = @cWorkOrder   -- WorkOrder
      SET @cOutField02 = @cLOC         -- LOC
      SET @cOutField03 = ''            -- LOC

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- go to previous screen
      SET @cWorkOrder = ''
      SET @cOutField01 = ''   -- WorkOrder

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC = ''

      -- Reset this screen var
      SET @cOutField01 = @cWorkOrder   -- WorkOrder
      SET @cOutField02  = ''           -- LOC
   END  
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2852) Scan-in/Display the SKU
   SKU:  
   (Field01)                                       -- SKU
   DESC: 
   (Field02)                                       -- SKUDesc (Len  1-20)
   (Field03)                                       -- SKUDesc (Len 21-40)

   ENTER =  Next Page
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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

      -- Screen mapping
      SET @cActSKU = @cInField03
      
      --When SKU is blank
      IF @cActSKU = ''
      BEGIN
         SET @nErrNo = 73311
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Required
         GOTO Step_3_Fail    
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
         SET @nErrNo = 73312
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail    
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 73313
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_3_Fail    
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
         SET @nErrNo = 73314
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RM SKU
         GOTO Step_3_Fail    
      END      

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

      SET @cFieldAttr01  = ''  -- Lottable01
      SET @cFieldAttr02  = ''  -- Lottable02
      SET @cFieldAttr03  = ''  -- Lottable03
      SET @cFieldAttr04  = ''  -- Lottable04
      SET @cFieldAttr05  = ''  -- Lottable05
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01

      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cLOC = ''
      SET @cOutField01   = @cWorkOrder -- WorkOrder
      SET @cOutField02   = ''          -- LOC

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''

      -- Reset this screen var
      SET @cOutField01 = @cWorkOrder   -- WorkOrder
      SET @cOutField02 = @cLOC         -- LOC
      SET @cOutField03 = ''            -- SKU
   END  
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 2853) Scan-in the LOTTABLE
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
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLottable01 = @cInField01
      SET @cLottable02 = @cInField02
      SET @cLottable03 = @cInField03
      SET @cLottable04 = @cInField04
      SET @cLottable05 = @cInField05

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
  
      -- Validate lottable01  
      IF @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL  
      BEGIN  
         IF @cLottable01 = '' OR @cLottable01 IS NULL  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73315, @cLangCode, 'DSP') --'Lottable01 required'  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_4_Fail  
         END  
      END  

      -- Validate lottable02  
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL  
      BEGIN  
         IF @cLottable02 = '' OR @cLottable02 IS NULL  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73316, @cLangCode, 'DSP') --'Lottable02 required'  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Step_4_Fail  
         END  
      END  
  
      -- Validate lottable03  
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL  
      BEGIN  
         IF @cLottable03 = '' OR @cLottable03 IS NULL  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73317, @cLangCode, 'DSP') --'Lottable03 required'  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_4_Fail  
         END  
    END  
  
      -- Validate lottable04  
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL  
      BEGIN  
         -- Validate empty  
       IF @cLottable04 = '' OR @cLottable04 IS NULL  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73318, @cLangCode, 'DSP') --'Lottable04 required'  
            EXEC rdt.rdtSetFocusField @nMobile, 8  
            GOTO Step_4_Fail  
         END  
         -- Validate date  
         IF RDT.rdtIsValidDate( @cLottable04) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73319, @cLangCode, 'DSP') --'Invalid date'  
            EXEC rdt.rdtSetFocusField @nMobile, 8  
            GOTO Step_4_Fail  
         END  
      END  
  
      -- Validate lottable05  
      IF @cLotlabel05 <> '' AND @cLotlabel05 IS NOT NULL  
      BEGIN  
         -- Validate empty  
         IF @cLottable05 = '' OR @cLottable05 IS NULL  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73320, @cLangCode, 'DSP') --'Lottable05 required'  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            GOTO Step_4_Fail  
         END  
         -- Validate date  
         IF RDT.rdtIsValidDate( @cLottable05) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 73321, @cLangCode, 'DSP') --'Invalid date'  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            GOTO Step_4_Fail  
         END  
      END  

      SET @dLottable04 = @cLottable04
      SET @dLottable05 = @cLottable05

      --check Inventory exists  
      IF NOT EXISTS (SELECT LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
         WHERE LA.Storerkey = @cStorerkey
            AND LA.SKU = @cSKU
            AND ISNULL(RTRIM(LA.Lottable01),'') = ISNULL(RTRIM(@cLottable01),'') 
            AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
            AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'') 
            AND ISNULL( LA.Lottable04, 0) = CASE WHEN @dLottable04 = 0 THEN ISNULL( LA.Lottable04, 0) ELSE @dLottable04 END 
            AND ISNULL( LA.Lottable05, 0) = CASE WHEN @dLottable05 = 0 THEN ISNULL( LA.Lottable05, 0) ELSE @dLottable05 END)  
--            AND CONVERT(VARCHAR(11),ISNULL(RTRIM(LA.Lottable04),''),103) = CONVERT(VARCHAR(11),ISNULL(RTRIM(@dLottable04),''),103) 
--            AND CONVERT(VARCHAR(11),ISNULL(RTRIM(LA.Lottable05),''),103) = CONVERT(VARCHAR(11),ISNULL(RTRIM(@dLottable05),''),103))
      BEGIN
         SET @nErrNo = 73322
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OIvt Not Found
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
         GOTO Step_4_Fail    
      END

      -- Validate if any of the lot and SKU has lottable02 on hold
      IF EXISTS (SELECT 1 
         FROM dbo.LotAttribute LA WITH (NOLOCK) 
         JOIN dbo.LOT LOT WITH (NOLOCK) ON LA.LOT = LOT.LOT 
         WHERE LA.StorerKey = @cStorerKey 
            AND LA.SKU = @cSKU
            AND LOT.Status = 'HOLD'
            AND ISNULL(RTRIM(LA.Lottable01),'') = ISNULL(RTRIM(@cLottable01),'') 
            AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
            AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'') 
            AND ISNULL( LA.Lottable04, 0) = CASE WHEN @dLottable04 = 0 THEN ISNULL( LA.Lottable04, 0) ELSE @dLottable04 END 
            AND ISNULL( LA.Lottable05, 0) = CASE WHEN @dLottable05 = 0 THEN ISNULL( LA.Lottable05, 0) ELSE @dLottable05 END) 
--            AND CONVERT(VARCHAR(11),ISNULL(RTRIM(LA.Lottable04),''),103) = CONVERT(VARCHAR(11),ISNULL(RTRIM(@dLottable04),''),103) 
--            AND CONVERT(VARCHAR(11),ISNULL(RTRIM(LA.Lottable05),''),103) = CONVERT(VARCHAR(11),ISNULL(RTRIM(@dLottable05),''),103))
      BEGIN
         SET @nErrNo = 73323
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT ON HOLD
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
         GOTO Step_4_Fail    
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

      --prepare screen variables
      SET @cOutField01   = @cSKU   -- SKU
      SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04   = @cUOM  -- UOM
      SET @cOutField05   = @cQTY  -- QTY
      SET @cInField04    = @cUOM  -- UOM
      SET @cInField05    = @cQTY  -- QTY  

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

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

   END  

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cSKU = ''
      SET @cOutField01   = @cWorkOrder   -- SKU
      SET @cOutField02   = @cLOC
      SET @cOutField03   = ''
      SET @cOutField04   = ''
      SET @cOutField05   = ''
      SET @cOutField06   = ''
      SET @cOutField07   = ''
      SET @cOutField08   = ''
      SET @cOutField09   = ''
      SET @cOutField10   = ''

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

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

   Step_4_Fail:
   BEGIN
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
  
      -- Init next screen var  
      IF @cHasLottable = '1'  
      BEGIN  
         -- Disable lottable  
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL  
         BEGIN  
            SET @cFieldAttr02 = 'O' 
            SET @cOutField02 = ''  
         END  
  
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL  
         BEGIN  
            SET @cFieldAttr04 = 'O' 
            SET @cOutField04 = ''  
         END  
  
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL  
         BEGIN  
            SET @cFieldAttr06 = 'O' 
            SET @cOutField06 = ''  
         END  
  
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL  
         BEGIN  
            SET @cFieldAttr08 = 'O' 
            SET @cOutField08 = ''  
         END  
  
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL  
         BEGIN  
            SET @cFieldAttr10 = 'O' 
            SET @cOutField10 = ''  
         END  
      END  
   END  
END
GOTO Quit

/********************************************************************************
Step 5. (screen = 2854) Input UOM, QTY... 
   SKU:  
   (Field01)                                       -- SKU
   DESC: 
   (Field02)                                       -- SKUDesc (Len  1-20)
   (Field03)                                       -- SKUDesc (Len 21-40)
   UOM: (Field04, input)                           -- UOM
   QTY: (Field05, input)                           -- QTY

   ENTER = Next Page
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUOM = @cInField04
      SET @cQTY = @cInField05

      --Validate UOM field
      IF ISNULL(RTRIM(@cUOM),'') = '' 
      BEGIN
         SET @nErrNo = 73324
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
         SET @nErrNo = 73325
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UOM
         SET @cUOM = ''
         SET @cOutField11 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- UOM
         GOTO Quit    
      END

      --Validate QTY field
      IF ISNULL(RTRIM(@cQTY),'') = '' 
      BEGIN
         SET @nErrNo = 73326
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY Required
         SET @cOutField12 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      --Validate QTY is numeric
      IF rdt.rdtIsValidQty(@cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 73327
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         SET @cOutField12 = ''
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
         GOTO Quit
      END

      --Validate QTY < 0
      IF CAST(@cQTY AS FLOAT) < 0
      BEGIN
         SET @nErrNo = 73328
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
         SET @nErrNo = 73329
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
         SET @nErrNo = 73330
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UOMConvQTY < 1
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

      SET @cADJQty = CAST(@cADJQty AS INT) + @nQTY

		IF CAST(@cADJQty AS INT) > 0
		BEGIN 
			GOTO ADJQty_Checking
		END

      --Validate UOM Convert QTY > KDQty
      IF CAST(@cADJQty AS INT) > CAST(@cKDQty AS INT)
      BEGIN
			ADJQty_Checking:  
         IF @cAllowOverADJ = '1'
         BEGIN
            SET @cMsg = 'WARNING:QTY>KITQty'
         END
         ELSE
         BEGIN
            SET @nErrNo = 73331
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY > KITQTY
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- QTY
            SET @cOutField12 = ''
            SET @cQty = ''
            GOTO Quit         
         END
      END

      --prepare screen variables
      SET @cOutField01   = @cMsg   -- Msg
      SET @cOutField02   = ''      -- Option

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
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

      SET @cFieldAttr01  = ''  -- Lottable01
      SET @cFieldAttr02  = ''  -- Lottable02
      SET @cFieldAttr03  = ''  -- Lottable03
      SET @cFieldAttr04  = ''  -- Lottable04
      SET @cFieldAttr05  = ''  -- Lottable05
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cUOM = ''
      SET @cQTY = ''
      SET @cMsg = ''

      -- Reset this screen var
      SET @cOutField01   = @cSKU   -- SKU
      SET @cOutField02   = SUBSTRING(@cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03   = SUBSTRING(@cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField11   = @cInField04 -- UOM
      SET @cOutField12   = @cInField05 -- QTY
   END  
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 2855) Enter Option
   (Field01)  -- Msg    
   Confirm Adjustment?

   1=YES/NEXT Batch
   2=NO
   3=YES/EXIT ALL TASK

   OPTION: (Field02, input)
********************************************************************************/
Step_6:
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
         SET @nErrNo = 73332
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Needed
         GOTO Step_6_Fail  
      END 

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN

      SAVE TRAN ADJ

      IF @cOption IN ('1', '3')
      BEGIN
         -- Check ESC from Screen 2 and 3, Cant Select Option 1
         IF ISNULL(RTRIM(@cSKU),'') = ''
         BEGIN
            ROLLBACK TRAN ADJ
            SET @nErrNo = 73333
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Allowed
            GOTO Step_6_Fail  
         END

         IF ISNULL(RTRIM(@cAdjustmentKey),'') = ''
         BEGIN
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
               SET @nErrNo = 73334
               SET @cErrMsg = rdt.rdtgetmessage( 68925, @cLangCode, 'DSP') --GetADJKey Fail
               GOTO Step_6_Fail
	         END
			   ELSE 
			   BEGIN           
               -- Insert new adjustment header
				   INSERT dbo.ADJUSTMENT (AdjustmentKey, StorerKey, CustomerRefNo, AdjustmentType, Facility)
				   VALUES (@cAdjustmentKey, @cStorerKey, @cWorkOrder, @cAdjType, @cFacility)

				   SELECT @n_err = @@error
				   IF @n_err > 0
				   BEGIN
                  ROLLBACK TRAN ADJ
                  SET @nErrNo = 73335
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ADJ Fail
                  GOTO Step_6_Fail
	      	   END
			   END            
         END   -- @cAdjustmentKey = ''

         SELECT TOP 1 @cLOT = LA.LOT FROM dbo.LotAttribute LA WITH (NOLOCK)
         WHERE LA.Storerkey = @cStorerkey
            AND LA.SKU      = @cSKU
            AND ISNULL(RTRIM(LA.Lottable01),'')  = ISNULL(RTRIM(@cLottable01),'')
            AND ISNULL(RTRIM(LA.Lottable02),'') = ISNULL(RTRIM(@cLottable02),'') 
            AND ISNULL(RTRIM(LA.Lottable03),'') = ISNULL(RTRIM(@cLottable03),'')
            AND Convert(VARCHAR(11),ISNULL(RTRIM(LA.Lottable04),''),103) = Convert(VARCHAR(11),ISNULL(RTRIM(@dLottable04),''),103) 
            AND Convert(VARCHAR(11),ISNULL(RTRIM(LA.Lottable05),''),103) = Convert(VARCHAR(11),ISNULL(RTRIM(@dLottable05),''),103)

         IF @nQty > 0  
         BEGIN         
            SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5) --(Shong01)
            FROM  dbo.AdjustmentDetail (NOLOCK)
            WHERE AdjustmentKey = @cAdjustmentKey
      
            INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, 
                    UOM, PackKey, Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
            VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKU, @cLOC, @cLOT, @cID, @cAdjReasonCode,
                    @cUOM, @cPackKey, @nQty, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05)
   
            SET @n_err = @@error
            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN ADJ
               SET @nErrNo = 73336
               SET @cErrMsg = rdt.rdtgetmessage( 73336, @cLangCode, 'DSP') --INS ADJDT Fail
               GOTO Step_6_Fail
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
                  SET @nErrNo = 73337
                  SET @cErrMsg = rdt.rdtgetmessage( 73337, @cLangCode, 'DSP') --UPD ADJDT Fail
                  GOTO Step_6_Fail
               END   
            END
         END 

         IF @cOption = '1'
         BEGIN
            -- Go to LOC Screen
            SET @cLOC = ''
            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4
            SET @cOutField01 = @cWorkOrder   -- WO#  
            SET @cOutField02 = ''         -- LOC
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
               SET @nErrNo = 73338
               SET @cErrMsg = rdt.rdtgetmessage( 73338, @cLangCode, 'DSP') --UPD ADJ Fail
               GOTO Step_6_Fail
            END   

            -- Go to WO Screen
            SET @cWorkOrder = ''
            SET @nScn = @nScn - 5
            SET @nStep = @nStep - 5
            SET @cOutField01 = ''            -- WO#  
            SET @cAdjustmentKey    = ''   -- (james01)
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
         SET @cLotQTY           = '0'
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
         SET @cAdjDetailLine    = ''
         SET @cItrnKey          = ''
         SET @cSourceKey        = ''
      END

      IF @cOption = '2'
      BEGIN
         -- Go to WO Screen 
         SET @cPrevWorkOrder    = @cWorkOrder

         SET @cWorkOrder        = ''
         SET @cOutField01       = '' -- WorkOrder 
         SET @nScn              = @nScn - 5
         SET @nStep             = @nStep - 5
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
         SET @cAdjDetailLine    = ''
         SET @cItrnKey          = ''
         SET @cSourceKey        = ''
         SET @cAdjustmentKey    = ''   -- (james01)
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN ADJ
   END  
   GOTO Quit

   Step_6_Fail:
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
       V_String5         = @cPackKey,
       V_String6         = @cKDQty,
       V_String7         = @cMsg,
       V_String8         = @cInvQTY,
       V_String9         = @cLastScn,
       V_String10        = @cLastStep,
       V_String11        = @cAdjustmentKey,
       V_String12        = @cAdjDetailLine,
       V_String13        = @cAdjType,
       V_String14        = @cLotQTY,
       V_String15        = @cAdjReasonCode,
       V_String16        = @cItrnKey,
       V_String17        = @cSourceKey,
       V_String18        = @cADJQty,
       V_String19        = @cAllowOverADJ,
       V_String20        = @cLottable01_Code, 
       V_String21        = @cLottable02_Code, 
       V_String22        = @cLottable03_Code, 
       V_String23        = @cLottable04_Code, 
       V_String24        = @cLottable05_Code, 
       V_String25        = @cPrevWorkOrder,

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