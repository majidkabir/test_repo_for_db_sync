SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_IndentOrdersPickToPalletID                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Picking: Indent Orders Pick To PalletID (C4LGMY - Carrefour)*/
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2009-07-30   1.0  Vanessa    Created                                 */
/* 2009-09-16   1.1  Vanessa    Script enhancement                      */
/* 2009-09-14   1.2  Vicky      Add in EventLog (Vicky06)               */
/* 2009-11-09   1.3  Vicky      Performance Tuning (Vicky01)            */
/* 2011-08-02   1.4  ChewKP     RDT EventLog Standardization (ChewKP01) */
/* 2012-09-21   1.5  James      Bug fix on lottable04 (james01)         */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_IndentOrdersPickToPalletID](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
	@b_success			   INT,
	@n_err				   INT,
	@c_errmsg			   NVARCHAR( 250),
   @nCount              INT,
   @nSKUCnt             INT
  
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
   @cUserName           NVARCHAR( 18),

   @cLOC                NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cNextSKU            NVARCHAR(20),
   @cDefaultUOM         NVARCHAR(1),
   @cPickSlipNo         NVARCHAR(10), 
   @cConsigneeKey       NVARCHAR(15),
   @cNextConsigneeKey   NVARCHAR(15),
   @cSKUDesc            NVARCHAR(60),
   @nQty                INT,
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @dLottable04         DATETIME,
   @cBALQty             NVARCHAR(5),
   @cACTQty             NVARCHAR(5),
   @cPackUOM3           NVARCHAR(10),
   @cDefaultUOMDesc     NVARCHAR(10),
   @cDefaultUOMDIV      NVARCHAR(5),
   @cDefaultUOMQTY      NVARCHAR(5),
   @cPackUOM3QTY        NVARCHAR(5),
   @cKeyDefaultUOMQTY   NVARCHAR(5),
   @cKeyPackUOM3QTY     NVARCHAR(5),
   @cDropID             NVARCHAR(18),
   @cOption             NVARCHAR(1),
   @nQTY_Act            INT,
   @nQTY_Bal            INT,
	@nQTY_PD				   INT,
	@cPickDetailKey	   NVARCHAR(10),
	@cPrePickDetailKey NVARCHAR(10),
   @dScanOutDate        DATETIME,
   @cAutoScanInPS       NVARCHAR(1),
   @cAutoScanOutPS      NVARCHAR(1),
   @cOrderKey           NVARCHAR(10), -- (ChewKP01)
   @nPickedQty          INT,         -- (ChewKP01)

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
  
SET @c_TraceName = 'rdtfnc_IndentOrdersPickToPalletID'  
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

   @cLOC                = V_Loc,
   @cSKU                = V_SKU, 
   @cDefaultUOM         = V_UOM,
   @cPickSlipNo         = V_PickSlipNo,
   @cConsigneeKey       = V_ConsigneeKey,
   @cSKUDesc            = V_SkuDescr, 
   @nQty                = V_QTY,   
   @cLottable01         = V_Lottable01,
   @cLottable02         = V_Lottable02,
   @cLottable03         = V_Lottable03,
   @dLottable04         = V_Lottable04,
   @cBALQty             = V_String1,
   @cACTQty             = V_String2,
   @cPackUOM3           = V_String3,
   @cDefaultUOMDesc     = V_String4,
   @cDefaultUOMDIV      = V_String5,
   @cDefaultUOMQTY      = V_String6,
   @cPackUOM3QTY        = V_String7,
   @cKeyDefaultUOMQTY   = V_String8,
   @cKeyPackUOM3QTY     = V_String9,
   @cDropID             = V_String10,
   @cAutoScanInPS       = V_String11,
   @cAutoScanOutPS      = V_String12,

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
IF @nFunc = 865 -- Pick to DropID
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 865
   IF @nStep = 1 GOTO Step_1   -- Scn = 2090   Scan-in the Pickslipno
   IF @nStep = 2 GOTO Step_2   -- Scn = 2091   Scan-in the STOR
   IF @nStep = 3 GOTO Step_3   -- Scn = 2092   Scan-in the SKU 
   IF @nStep = 4 GOTO Step_4   -- Scn = 2093   Key-in the ACT QTY picked in its corresponding UOM column
 IF @nStep = 5 GOTO Step_5   -- Scn = 2094   Scan-in the Drop ID
   IF @nStep = 6 GOTO Step_6   -- Scn = 2095   Enter Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 865)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2090
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
   SET @nCount  = 0
   SET @nSKUCnt = 0

   -- initialise all variable
   SET @cLOC              = ''
   SET @cSKU              = ''
   SET @cNextSKU          = ''
   SET @cDefaultUOM       = ''
   SET @cPickSlipNo       = ''
   SET @cConsigneeKey     = ''
   SET @cSKUDesc          = ''
   SET @nQty              = 0
   SET @cLottable01       = ''
   SET @cLottable02       = ''
   SET @cLottable03       = ''
   SET @dLottable04       = ''
   SET @cBALQty           = ''
   SET @cACTQty           = ''
   SET @cPackUOM3         = ''
   SET @cDefaultUOMDesc   = ''
   SET @cDefaultUOMDIV    = ''
   SET @cDefaultUOMQTY    = ''
   SET @cPackUOM3QTY      = ''
   SET @cKeyDefaultUOMQTY = ''
   SET @cKeyPackUOM3QTY   = ''
   SET @cDropID           = ''
   SET @cOption           = ''
   SET @nQTY_Act          = 0
   SET @nQTY_Bal          = 0
   SET @nQTY_PD           = 0
   SET @cPickDetailKey    = ''
   SET @cPrePickDetailKey = ''
   SET @dScanOutDate      = ''
   SET @cAutoScanInPS     = ''
   SET @cAutoScanOutPS    = ''
   -- Prep next screen var   
   SET @cOutField01 = ''  -- PickSlipNo
   SET @cOutField02 = ''  -- LOC
   SET @cOutField03 = ''  -- ConsigneeKey

   SET @cInField01  = ''  -- PickSlipNo

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
Step 1. screen = 2090 Scan-in the PickSlipNo screen
   PICKSLIP: 
   (Field01, input)

   ENTER = Next Page
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      SET @cAutoScanInPS = rdt.RDTGetConfig( @nFunc, 'AutoScanInPS', @cStorerKey)
      SET @cAutoScanOutPS = rdt.RDTGetConfig( @nFunc, 'AutoScanOutPS', @cStorerKey)

      --When PS is blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 67515
         SET @cErrMsg = rdt.rdtgetmessage( 67515, @cLangCode, 'DSP') --PS required
         GOTO Step_1_Fail  
      END 

      --check for existing PickSlipNo 
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 67516
         SET @cErrMsg = rdt.rdtgetmessage( 67516, @cLangCode, 'DSP') --Invalid PS
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
           AND PH.ExternOrderKey <> '' -- (Vicky01)
           AND O.Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 67517
         SET @cErrMsg = rdt.rdtgetmessage( 67517, @cLangCode, 'DSP') --Diff storer
         GOTO Step_1_Fail    
      END

      --check diff facility
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
           AND PH.ExternOrderKey <> ''  -- (Vicky01)
           AND O.Facility = @cFacility)
      BEGIN
         SET @nErrNo = 67518
         SET @cErrMsg = rdt.rdtgetmessage( 67518, @cLangCode, 'DSP') --Diff facility
         GOTO Step_1_Fail    
      END

      --Check if ScanOutDate exists for PickSlipNo
      SELECT @dScanOutDate = ScanOutDate
      FROM dbo.PickingInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      IF ISNULL(@dScanOutDate, '') <> ''
      BEGIN
         SET @nErrNo = 67519
         SET @cErrMsg = rdt.rdtgetmessage( 67519, @cLangCode, 'DSP') --PS Picked
         GOTO Step_1_Fail    
      END

      IF @cAutoScanInPS = '1'
      BEGIN
         --Check if PickSlipNo is not exists
         IF NOT EXISTS ( SELECT 1
         FROM dbo.PickingInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID, AddWho )
            Values(@cPickSlipNo, GetDate(), sUser_sName(), sUser_sName())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 67520
               SET @cErrMsg = rdt.rdtgetmessage( 67520, @cLangCode, 'DSP') --'InsPkInfoFail'
               GOTO Step_1_Fail
            END
         END
      END
 
      Step_1_Next:  
      --prepare next screen variable
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConsigneeKey
                  
      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
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
      SET @nFunc        = @nMenu
      SET @nScn         = @nMenu
      SET @nStep        = 0
      SET @cOutField01  = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPickSlipNo   = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- PickSlipNo

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo
   END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2091) Scan-in the STOR
   PICKSLIP:
   (Field01)         -- PickSlipNo
   STOR: 
   (Field02, input)  -- ConsigneeKey
 
   ENTER =  Next Page
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cConsigneeKey = @cInField02

      --When STOR is blank
      IF @cConsigneeKey = ''
      BEGIN
         SET @nErrNo = 67521
         SET @cErrMsg = rdt.rdtgetmessage( 67521, @cLangCode, 'DSP') --STOR needed
         GOTO Step_2_Fail  
      END 

      SET @d_step1 = GETDATE() 

      --Check if PickSlipNo is not exists
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
           AND PH.ExternOrderKey <> '' -- (Vicky01)
           AND O.ConsigneeKey   = @cConsigneeKey )
      BEGIN
         SET @nErrNo = 67522
         SET @cErrMsg = rdt.rdtgetmessage( 67522, @cLangCode, 'DSP') --Invalid STOR
         GOTO Step_2_Fail    
      END

  SET @d_step1 = GETDATE() - @d_step1
     SET @c_col1 = 'Step_2'

      Step_2_Next:
      --prepare next screen variable
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = '' -- SKU
      
      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      SET @d_step2 = GETDATE()

      SELECT @cBALQty = CONVERT(VARCHAR(5), ISNULL(SUM(PD.QTY),0)) 
      FROM dbo.PickHeader PH WITH (NOLOCK)
      JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)
      JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
      WHERE PH.PickHeaderKey = @cPickSlipNo
        AND PD.Storerkey = @cStorerkey
        --AND O.Storerkey = @cStorerkey -- (Vicky01)
        AND PH.ExternOrderKey <> ''  -- (Vicky01)
        AND PD.Status = '0'    

      SELECT @cACTQty = CONVERT(VARCHAR(5), ISNULL(SUM(PD.QTY), 0)) 
      FROM dbo.PickHeader PH WITH (NOLOCK)
      JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
      JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
      WHERE PH.PickHeaderKey = @cPickSlipNo
        AND PD.Storerkey = @cStorerkey
        -- AND O.Storerkey = @cStorerkey -- (Vicky01)
        AND PH.ExternOrderKey <> ''  -- (Vicky01)
        AND PD.Status = '5' 


     SET @d_step2 = GETDATE() - @d_step2
     SET @c_col1 = 'Step_2 ESC'

      IF @cBALQty <> '0'
      BEGIN
         SET @cOutField01 = @cBALQty 
         SET @cOutField02 = @cACTQty 
         SET @cOutField03 = '' -- Option

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Option 

         -- go to previous screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
      ELSE
      BEGIN
         IF @cAutoScanOutPS = '1'
         BEGIN
            UPDATE dbo.PickingInfo SET 
               ScanOutDate = GETDATE(), 
               EditWho = sUser_sName() 
            WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 67523
               SET @cErrMsg = rdt.rdtgetmessage( 67523, @cLangCode, 'DSP') --'UpdPkInfoFail'
               GOTO Step_2_Fail
            END
         END

         -- Prepare prev screen var
         SET @cPickSlipNo        = ''
         SET @cConsigneeKey      = ''
         SET @cBALQty            = ''
         SET @cACTQty            = ''
         SET @cOutField01        = '' -- PickSlipNo

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo

         -- go to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cConsigneeKey      = ''
      SET @cOutField01        = @cPickSlipNo
      SET @cOutField02        = '' -- ConsigneeKey

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConsigneeKey
   END  
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2092) Scan-in the SKU
   PICKSLIP:
   (Field01)         -- PickSlipNo
   STOR: 
   (Field02)         -- ConsigneeKey
   SKU:
   (Field03, input)  -- SKU
 
   ENTER =  Next Page
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03

      --When SKU is blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 67524
         SET @cErrMsg = rdt.rdtgetmessage( 67524, @cLangCode, 'DSP') --SKU needed
         GOTO Step_3_Fail  
      END 

      --if SKU scanned
      IF ISNULL(@cSKU, '') <> ''
      BEGIN
         -- Get SKU/UPC
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg    = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 67525
            SET @cErrMsg = rdt.rdtgetmessage( 67525, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_3_Fail   
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 67526
            SET @cErrMsg = rdt.rdtgetmessage( 67526, @cLangCode, 'DSP') --Multi SKU
            GOTO Step_3_Fail   
         END

         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 67525
            SET @cErrMsg = rdt.rdtgetmessage( 67525, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_3_Fail   
         END

      END

      -- Check if SKU exists in Pickslip + STOR + SKU
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.PickHeader PH WITH (NOLOCK)
                      JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
                      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
                      JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
                      WHERE PH.PickHeaderKey = @cPickSlipNo
                        AND PH.ExternOrderKey <> ''  -- (Vicky01)
                        AND O.ConsigneeKey = @cConsigneeKey
                        AND PD.Storerkey = @cStorerkey
                        -- AND O.Storerkey = @cStorerkey -- (Vicky01)
                        AND PD.SKU = @cSKU )
      BEGIN
         SET @nErrNo = 67527
         SET @cErrMsg = rdt.rdtgetmessage( 67527, @cLangCode, 'DSP') --SKU NotForSTOR
         GOTO Step_3_Fail    
      END

      -- Check if SKU still have outstanding balance in PickDetail (Status = 0 and QTY > 0) for the Pickslip + STOR
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.PickHeader PH WITH (NOLOCK)
                      JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
                      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
                      JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
                      WHERE PH.PickHeaderKey = @cPickSlipNo
                        AND PH.ExternOrderKey <> ''  -- (Vicky01)
                        AND O.ConsigneeKey = @cConsigneeKey
                        AND PD.Storerkey = @cStorerkey
                        -- AND O.Storerkey = @cStorerkey -- (Vicky01)
                        AND PD.Status = '0'
                        AND PD.QTY > 0
                        AND PD.SKU = @cSKU )
      BEGIN
         SET @nErrNo = 67528
         SET @cErrMsg = rdt.rdtgetmessage( 67528, @cLangCode, 'DSP') --No more Task
         GOTO Step_3_Fail    
      END

      -- Get prefer UOM
      SELECT @cDefaultUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M (NOLOCK)
         INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      SET ROWCOUNT 1
      SELECT @cSKU            = SKU.SKU, 
             @cSKUDesc        = SKU.DESCR, 
             @cLottable01     = LA.Lottable01, 
             @cLottable02     = LA.Lottable02, 
             @cLottable03     = LA.Lottable03, 
             @dLottable04     = LA.Lottable04,
	          @cPackUOM3       = PACK.PackUOM3,
             @cDefaultUOMDesc = CASE @cDefaultUOM
		                             WHEN '2' THEN PACK.PackUOM1 -- Case
		                             WHEN '3' THEN PACK.PackUOM2 -- Inner pack
		                             WHEN '6' THEN PACK.PackUOM3 -- Master unit
		                             WHEN '1' THEN PACK.PackUOM4 -- Pallet
		                             WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
		                             WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
		                          END,
	          @cDefaultUOMDIV  = CAST( IsNULL(
		                          CASE @cDefaultUOM
		                             WHEN '2' THEN PACK.CaseCNT
		                             WHEN '3' THEN PACK.InnerPack
		                             WHEN '6' THEN PACK.QTY
		                             WHEN '1' THEN PACK.Pallet
		                             WHEN '4' THEN PACK.OtherUnit1
		                             WHEN '5' THEN PACK.OtherUnit2
		                          END, 1) AS INT),
             @nQTY            = SUM(PD.QTY)
      FROM dbo.PickHeader PH WITH (NOLOCK)
      JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
      JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
      JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND PD.SKU = SKU.SKU) -- (Vicky01)
      JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
      WHERE PH.PickHeaderKey = @cPickSlipNo
        AND PH.ExternOrderKey <> ''  -- (Vicky01)
        AND O.ConsigneeKey = @cConsigneeKey
        AND PD.Storerkey = @cStorerkey
        AND PD.Status = '0'
        AND PD.QTY > 0
        AND PD.SKU = @cSKU
      GROUP BY SKU.SKU, 
               SKU.DESCR, 
               LA.Lottable01, 
               LA.Lottable02, 
               LA.Lottable03, 
               LA.Lottable04,
	            PACK.PackUOM3,
               CASE @cDefaultUOM
		            WHEN '2' THEN PACK.PackUOM1 -- Case
		            WHEN '3' THEN PACK.PackUOM2 -- Inner pack
		            WHEN '6' THEN PACK.PackUOM3 -- Master unit
		            WHEN '1' THEN PACK.PackUOM4 -- Pallet
		            WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
		            WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
		         END,
	            CAST( IsNULL(
		         CASE @cDefaultUOM
		            WHEN '2' THEN PACK.CaseCNT
		            WHEN '3' THEN PACK.InnerPack
		            WHEN '6' THEN PACK.QTY
		            WHEN '1' THEN PACK.Pallet
		            WHEN '4' THEN PACK.OtherUnit1
		            WHEN '5' THEN PACK.OtherUnit2
		         END, 1) AS INT)
      ORDER BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
      SET ROWCOUNT 0

      IF @cDefaultUOM < '6' 
      BEGIN
         IF ISNULL(@cDefaultUOMDIV,'') = '' OR @cDefaultUOMDIV = '0'
         BEGIN
            SET @nErrNo = 67529
            SET @cErrMsg = rdt.rdtgetmessage( 67529, @cLangCode, 'DSP') --Invalid PackQTY
            GOTO Step_3_Fail  
         END

         -- Calc QTY in DefaultUOM
         SET @cDefaultUOMQTY = CONVERT(VARCHAR(5), @nQTY/CONVERT(INT, @cDefaultUOMDIV))
        
         -- Calc the Balance QTY in PackUOM3
         SET @cPackUOM3QTY = CONVERT(VARCHAR(5), @nQTY % CONVERT(INT, @cDefaultUOMDIV))
      END
      ELSE
      BEGIN
         SET @cDefaultUOMDesc = ''
         SET @cDefaultUOMQTY  = ''
         SET @cPackUOM3QTY    = CONVERT(VARCHAR(5), @nQTY)
         SET @cInField14      = ''
      END

      Step_3_Next:
      --prepare next screen variable
      SET @cOutField01 = @cConsigneeKey
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)
      SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate(@dLottable04)
      SET @cOutField09 = @cDefaultUOMDIV
      SET @cOutField10 = @cDefaultUOMDesc
      SET @cOutField11 = @cPackUOM3
      SET @cOutField12 = @cDefaultUOMQTY
      SET @cOutField13 = @cPackUOM3QTY
      SET @cOutField14 = ''
      SET @cOutField15 = ''
      
      IF ISNULL(@cDefaultUOMQTY,'') = '' 
      BEGIN
         SET @cFieldAttr14 = 'O' -- KeyDefaultUOMQTY
         SET @cOutField14  = ''
      END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cConsigneeKey      = ''
      SET @cOutField02        = '' -- ConsigneeKey
      SET @cFieldAttr14       = '' -- KeyDefaultUOMQTY

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU         = ''
      SET @cOutField01  = @cPickSlipNo
      SET @cOutField02  = @cConsigneeKey
      SET @cOutField03  = '' -- SKU 
      SET @cFieldAttr14       = '' -- KeyDefaultUOMQTY

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConsigneeKey
   END  
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 2093) Key-in the ACT QTY picked in its corresponding UOM column
   STOR: (Field01)
   SKU:  
   (Field02)                                       -- SKU
   (Field03)                                       -- SKUDesc (Len  1-20)
   (Field04)                                       -- SKUDesc (Len 21-40)
   1 (Field05)                                     -- Lottable01 
   2 (Field06)                                     -- Lottable02
   3 (Field07)                                     -- Lottable03 
   4 (Field08)                                     -- Lottable04
   1:(Field09)  (Field10)        (Field11)         -- DefaultUOMDIV     -- DefaultUOMDesc  -- PackUOM3
   BAL QTY:     (Field12)        (Field13)         -- DefaultUOMQTY     -- PackUOM3QTY
   ACT QTY:     (Field14, input) (Field15, input)  -- KeyDefaultUOMQTY  -- KeyPackUOM3QTY
 
   ENTER =  Next Page
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cKeyDefaultUOMQTY = @cInField14
      SET @cKeyPackUOM3QTY   = @cInField15

      IF ISNULL(@cKeyDefaultUOMQTY,'') = '' 
      BEGIN
         IF ISNULL(@cDefaultUOMQTY,'') = '' 
         BEGIN
            SET @cKeyDefaultUOMQTY = ''
         END
         ELSE
         BEGIN
            SET @cKeyDefaultUOMQTY = 0
         END
      END

      IF ISNULL(@cKeyPackUOM3QTY,'') = '' 
      BEGIN
         SET @cKeyPackUOM3QTY = 0
      END

      -- (Vicky01) 
      IF (RDT.rdtIsValidQTY( @cKeyDefaultUOMQTY, 0) = 0) OR 
         (RDT.rdtIsValidQTY( @cKeyPackUOM3QTY, 0) = 0) 
	   BEGIN
         SET @nErrNo = 67530
         SET @cErrMsg = rdt.rdtgetmessage( 67530, @cLangCode, 'DSP') --Invalid QTY
         GOTO Step_4_Fail  
      END

--      IF (CHARINDEX('.',@cKeyDefaultUOMQTY) > 0) OR   -- Validate Decimal Value
--         (CHARINDEX('.',@cKeyPackUOM3QTY) > 0)        -- Validate Decimal Value
--      BEGIN
--         SET @nErrNo = 67530
--         SET @cErrMsg = rdt.rdtgetmessage( 67530, @cLangCode, 'DSP') --Invalid QTY
--         GOTO Step_4_Fail           
--      END
--
--      IF ISNULL(@cKeyDefaultUOMQTY,'') <> '' 
--      BEGIN
--         IF (ISNUMERIC(@cKeyDefaultUOMQTY) = 0) OR       -- Validate Numeric
--            (@cKeyDefaultUOMQTY < 0)                     -- Validate Negative VaLue
--         BEGIN
--            SET @nErrNo = 67530
--            SET @cErrMsg = rdt.rdtgetmessage( 67530, @cLangCode, 'DSP') --Invalid QTY
--            GOTO Step_4_Fail           
--         END
--      END
--
--      IF (ISNUMERIC(@cKeyPackUOM3QTY) = 0) OR         -- Validate Numeric
--         (@cKeyPackUOM3QTY < 0)                       -- Validate Negative VaLue
--      BEGIN
--         SET @nErrNo = 67530
--         SET @cErrMsg = rdt.rdtgetmessage( 67530, @cLangCode, 'DSP') --Invalid QTY
--         GOTO Step_4_Fail           
--      END

      SET @nQTY_Act = CONVERT(INT, @cKeyDefaultUOMQTY) * CONVERT(INT, @cDefaultUOMDIV) + 
                      CONVERT(INT, @cKeyPackUOM3QTY)

      IF @nQTY_Act > @nQTY                     
      BEGIN
         SET @nErrNo = 67531
         SET @cErrMsg = rdt.rdtgetmessage( 67531, @cLangCode, 'DSP') --Over pick
         GOTO Step_4_Fail           
      END

      Step_4_Next:
      IF ISNULL(@nQTY_Act, 0) = 0
      BEGIN
         SET ROWCOUNT 1
         SELECT @cNextSKU        = SKU.SKU, 
                @cSKUDesc        = SKU.DESCR, 
                @cLottable01     = LA.Lottable01, 
                @cLottable02     = LA.Lottable02, 
                @cLottable03     = LA.Lottable03, 
                @dLottable04     = LA.Lottable04,
	             @cPackUOM3       = PACK.PackUOM3,
                @cDefaultUOMDesc = CASE @cDefaultUOM
		                                WHEN '2' THEN PACK.PackUOM1 -- Case
		                                WHEN '3' THEN PACK.PackUOM2 -- Inner pack
		                                WHEN '6' THEN PACK.PackUOM3 -- Master unit
		                                WHEN '1' THEN PACK.PackUOM4 -- Pallet
		                                WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
		                                WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
		                             END,
	             @cDefaultUOMDIV  = CAST( IsNULL(
		                             CASE @cDefaultUOM
		                                WHEN '2' THEN PACK.CaseCNT
		                                WHEN '3' THEN PACK.InnerPack
		                                WHEN '6' THEN PACK.QTY
		                                WHEN '1' THEN PACK.Pallet
		                                WHEN '4' THEN PACK.OtherUnit1
		                                WHEN '5' THEN PACK.OtherUnit2
		                             END, 1) AS INT),
                @nQTY            = SUM(PD.QTY)
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
         JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
         JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
         JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND PD.SKU = SKU.SKU)  -- (Vicky01)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
         JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
         WHERE PH.PickHeaderKey = @cPickSlipNo
           AND PH.ExternOrderKey <> ''   -- (Vicky01)
           AND O.ConsigneeKey = @cConsigneeKey
           AND PD.Storerkey = @cStorerkey
           AND PD.Status = '0'
           AND PD.QTY > 0
           AND PD.SKU = @cSKU
           AND LA.Lottable01 + LA.Lottable02 + -- (Vicky01) 
               LA.Lottable03 + CONVERT(VARCHAR(23),ISNULL(RTRIM(LA.Lottable04),'')) > -- (Vicky01) 
               @cLottable01  + @cLottable02 + -- (Vicky01) 
               @cLottable03  + CONVERT(VARCHAR(23),ISNULL(RTRIM(@dLottable04),''),121) -- (Vicky01) 
         GROUP BY SKU.SKU, 
                  SKU.DESCR, 
                  LA.Lottable01, 
                  LA.Lottable02, 
                  LA.Lottable03, 
                  LA.Lottable04,
	               PACK.PackUOM3,
                  CASE @cDefaultUOM
		               WHEN '2' THEN PACK.PackUOM1 -- Case
		               WHEN '3' THEN PACK.PackUOM2 -- Inner pack
		               WHEN '6' THEN PACK.PackUOM3 -- Master unit
		               WHEN '1' THEN PACK.PackUOM4 -- Pallet
		               WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
		               WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
		            END,
	               CAST( IsNULL(
		            CASE @cDefaultUOM
		               WHEN '2' THEN PACK.CaseCNT
		               WHEN '3' THEN PACK.InnerPack
		               WHEN '6' THEN PACK.QTY
		               WHEN '1' THEN PACK.Pallet
		               WHEN '4' THEN PACK.OtherUnit1
		               WHEN '5' THEN PACK.OtherUnit2
		            END, 1) AS INT)
         ORDER BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
         SET ROWCOUNT 0

         SET @cSKU = @cNextSKU

         IF ISNULL(@cSKU,'') <> ''
         BEGIN
            IF @cDefaultUOM < '6' 
            BEGIN
               IF ISNULL(@cDefaultUOMDIV,'') = '' OR @cDefaultUOMDIV = '0'
               BEGIN
                  SET @nErrNo = 67529
                  SET @cErrMsg = rdt.rdtgetmessage( 67529, @cLangCode, 'DSP') --Invalid PackQTY
                  GOTO Step_4_Fail  
               END

               -- Calc QTY in DefaultUOM
               SET @cDefaultUOMQTY = CONVERT(VARCHAR(5), @nQTY/CONVERT(INT, @cDefaultUOMDIV))
              
               -- Calc the Balance QTY in PackUOM3
               SET @cPackUOM3QTY = CONVERT(VARCHAR(5), @nQTY % CONVERT(INT, @cDefaultUOMDIV))
            END
            ELSE
            BEGIN
               SET @cDefaultUOMDesc = ''
               SET @cDefaultUOMQTY  = ''
               SET @cPackUOM3QTY    = CONVERT(VARCHAR(5), @nQTY)
               SET @cInField14      = ''
            END

            --prepare same screen variable
            SET @cOutField01 = @cConsigneeKey
            SET @cOutField02 = @cSKU
            SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)
            SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)
            SET @cOutField05 = @cLottable01
            SET @cOutField06 = @cLottable02
            SET @cOutField07 = @cLottable03
            SET @cOutField08 = rdt.rdtFormatDate(@dLottable04)
            SET @cOutField09 = @cDefaultUOMDIV
            SET @cOutField10 = @cDefaultUOMDesc
            SET @cOutField11 = @cPackUOM3
            SET @cOutField12 = @cDefaultUOMQTY
            SET @cOutField13 = @cPackUOM3QTY
            SET @cOutField14 = ''
            SET @cOutField15 = ''

            -- Go to next screen
            SET @nScn  = @nScn 
            SET @nStep = @nStep 
         END
         ELSE
         BEGIN
            SET @nErrNo = 67532
            SET @cErrMsg = rdt.rdtgetmessage( 67532, @cLangCode, 'DSP') --End of Record
            GOTO Step_4_Fail  
         END
      END
      ELSE
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = @cConsigneeKey
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cSKUDesc,1,20)
         SET @cOutField04 = SUBSTRING(@cSKUDesc,21,20)
         SET @cOutField05 = @cDefaultUOMDIV
         SET @cOutField06 = @cDefaultUOMDesc
         SET @cOutField07 = @cPackUOM3
         SET @cOutField08 = @cDefaultUOMQTY
         SET @cOutField09 = @cPackUOM3QTY
         SET @cOutField10 = @cKeyDefaultUOMQTY
         SET @cOutField11 = @cKeyPackUOM3QTY
         SET @cOutField12 = '' -- DropID

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cDefaultUOM        = ''
      SET @cSKU               = ''
      SET @cSKUDesc           = ''
      SET @cLottable01        = ''
      SET @cLottable02        = ''
      SET @cLottable03        = ''
      SET @dLottable04        = ''
      SET @cDefaultUOMDIV     = ''
      SET @cDefaultUOMDesc    = ''
      SET @cPackUOM3          = ''
      SET @cDefaultUOMQTY     = ''
      SET @cPackUOM3QTY       = ''

      SET @cOutField01        = @cPickSlipNo
      SET @cOutField02        = @cConsigneeKey
      SET @cOutField03        = '' -- SKU

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cKeyDefaultUOMQTY  = ''
      SET @cKeyPackUOM3QTY    = ''
      SET @cOutField01        = @cConsigneeKey
      SET @cOutField02        = @cSKU
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)
      SET @cOutField05        = @cLottable01
      SET @cOutField06        = @cLottable02
      SET @cOutField07        = @cLottable03
      SET @cOutField08        = rdt.rdtFormatDate(@dLottable04)
      SET @cOutField09        = @cDefaultUOMDIV
      SET @cOutField10        = @cDefaultUOMDesc
      SET @cOutField11        = @cPackUOM3
      SET @cOutField12        = @cDefaultUOMQTY
      SET @cOutField13        = @cPackUOM3QTY
      SET @cOutField14        = ''
      SET @cOutField15        = ''
   END 
END
GOTO Quit

Step_5:
/********************************************************************************
Step 5. (screen = 2064) Scan-in the Drop ID
   STOR: (Field01)
   SKU:  
   (Field02)                                       -- SKU
   (Field03)                                       -- SKUDesc (Len  1-20)
   (Field04)                                       -- SKUDesc (Len 21-40)

   1:(Field05)  (Field06)        (Field07)         -- DefaultUOMDIV     -- DefaultUOMDesc  -- PackUOM3
   BAL QTY:     (Field08)        (Field09)         -- DefaultUOMQTY     -- PackUOM3QTY
   ACT QTY:     (Field10)        (Field11)         -- KeyDefaultUOMQTY  -- KeyPackUOM3QTY
   DROP ID:
   (Field14, input)                                -- DropID

   ENTER =  Next Page
********************************************************************************/
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField12

      --When DropID is blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 67533
         SET @cErrMsg = rdt.rdtgetmessage( 67533, @cLangCode, 'DSP') --Drop ID req
         GOTO Step_5_Fail  
      END 
      ELSE
      BEGIN
         IF EXISTS(SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
                  JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Storerkey = OD.Storerkey) -- (Vicky01)
                  JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND OD.Storerkey = O.Storerkey) -- (Vicky01)
                  WHERE PD.DropID = @cDropID
                  AND PD.Storerkey = @cStorerkey
                  -- AND O.Storerkey = @cStorerkey -- (Vicky01)
                  AND O.ConsigneeKey <> @cConsigneeKey)
         BEGIN
            SET @nErrNo = 67534
            SET @cErrMsg = rdt.rdtgetmessage( 67534, @cLangCode, 'DSP') --Drop ID used
            GOTO Step_5_Fail   
         END

         IF (CONVERT(INT, @cKeyDefaultUOMQTY) < CONVERT(INT, @cDefaultUOMQTY)) OR (CONVERT(INT, @cKeyPackUOM3QTY) < CONVERT(INT, @cPackUOM3QTY))
         BEGIN
            SET @nCount   = 0
            SET @nQTY_Act = CONVERT(INT, @cKeyDefaultUOMQTY) * CONVERT(INT, @cDefaultUOMDIV) + 
                            CONVERT(INT, @cKeyPackUOM3QTY)


            -- Get PickDetail candidate
            DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PickDetailKey, QTY, PD.OrderKey -- (ChewKP01)
            FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.ORDERS O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
            JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
            WHERE PH.PickHeaderKey = @cPickSlipNo
              AND PH.ExternOrderKey <> '' -- (Vicky01) 
              AND O.ConsigneeKey = @cConsigneeKey
              AND PD.Storerkey = @cStorerkey
              -- AND O.Storerkey = @cStorerkey -- (Vicky01)
              AND PD.Status = '0'
              AND PD.QTY > 0
              AND PD.SKU = @cSKU
              AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01) 
              AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01) 
              AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '')  -- (Vicky01) 
              AND ISNULL(LA.Lottable04,'') = ISNULL(@dLottable04, '') -- (james01)
              --AND LA.Lottable04 = @dLottable04    -- (Vicky01) 
            ORDER BY PD.PickDetailKey

            OPEN curPD
            FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @nCount = 0
               BEGIN
                  IF @nQTY_Act > @nQTY_PD
                  BEGIN
                     SET @nQTY_Act = @nQTY_Act - @nQTY_PD


                     SET @d_step3 = GETDATE()

                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        DropID = @cDropID,
                        Status = '5',
                        EditDate = GetDate(), 
                        EditWho  = sUser_sName() 
                     WHERE PickDetailKey = @cPickDetailKey

                     SET @d_step3 = GETDATE() - @d_step3
                     SET @c_col3 = 'QACT>QPD'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 67535
                        SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
                        GOTO Step_5_Fail
                     END
                     ELSE
                     BEGIN
                          -- (Vicky06) EventLog - QTY
                          EXEC RDT.rdt_STD_EventLog
                             @cActionType   = '3', -- Picking
                             @cUserID       = @cUserName,
                             @nMobileNo     = @nMobile,
                             @nFunctionID   = @nFunc,
                             @cFacility     = @cFacility,
                             @cStorerKey    = @cStorerkey,
                             --@cLocation     = @cLOC,
                             --@cID           = @cMUID,
                             @cSKU          = @cSKU,
                             @cUOM          = @cPackUOM3,
                             @nQTY          = @nQTY_PD,
                             @cLottable01   = @cLottable01,  
                             @cLottable02   = @cLottable02, 
                             @cLottable03   = @cLottable03, 
                             @dLottable04   = @dLottable04, 
                             @cRefNo1       = @cPickSlipNo,
                             @cRefNo2       = @cConsigneeKey,
                             @cRefNo3       = @cDropID,
                             @cOrderKey     = @cOrderKey,   -- (ChewKP01)
                             @cPickSlipNo   = @cPickSlipNo  -- (ChewKP01)
                     END
                  END
                  ELSE IF @nQTY_Act = @nQTY_PD
                  BEGIN
                     SET @nQTY_Act = @nQTY_Act - @nQTY_PD


                     SET @d_step3 = GETDATE()

                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        DropID = @cDropID,
                        Status = '5',
                        EditDate = GetDate(), 
                        EditWho  = sUser_sName() 
                     WHERE PickDetailKey = @cPickDetailKey

                     SET @d_step3 = GETDATE() - @d_step3
                     SET @c_col3 = 'QACT=QPD'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 67535
                        SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
                        GOTO Step_5_Fail
                     END
                     ELSE
                     BEGIN
                          -- (Vicky06) EventLog - QTY
                          EXEC RDT.rdt_STD_EventLog
                             @cActionType   = '3', -- Picking
                             @cUserID       = @cUserName,
                             @nMobileNo     = @nMobile,
                             @nFunctionID   = @nFunc,
                             @cFacility     = @cFacility,
                             @cStorerKey    = @cStorerkey,
                             --@cLocation     = @cLOC,
                             --@cID           = @cMUID,
                             @cSKU          = @cSKU,
                             @cUOM          = @cPackUOM3,
                             @nQTY          = @nQTY_PD,
                             @cLottable01   = @cLottable01,  
                             @cLottable02   = @cLottable02, 
                             @cLottable03   = @cLottable03, 
                             @dLottable04   = @dLottable04, 
                             @cRefNo1       = @cPickSlipNo,
                             @cRefNo2       = @cConsigneeKey,
                             @cRefNo3       = @cDropID,
                             @cOrderKey     = @cOrderKey,   -- (ChewKP01)
                             @cPickSlipNo   = @cPickSlipNo  -- (ChewKP01)
                     END
                  END
                  ELSE IF @nQTY_Act < @nQTY_PD AND @nQTY_Act <> 0
                  BEGIN
                     SET @nQTY_Bal = @nQTY_PD - @nQTY_Act
                     SET @nCount   = 1
                     SET @cPrePickDetailKey = @cPickDetailKey


                     SET @d_step3 = GETDATE()

                     -- Get new PickDetailkey
                     DECLARE @cNewPickDetailKey NVARCHAR(10)
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY', 
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @b_success         OUTPUT,
                        @n_err             OUTPUT,
                        @c_errmsg          OUTPUT
                     IF @b_success <> 1
                     BEGIN
                        SET @nErrNo = 67536
                        SET @cErrMsg = rdt.rdtgetmessage( 67536, @cLangCode, 'DSP') -- 'GetPDtlKeyFail'
                        GOTO Step_5_Fail
                     END

                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PICKDETAIL (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, 
                        PickDetailKey, 
                        QTY, 
                        --TrafficCop,
                        OptimizeCop)
                     SELECT 
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
                        UOMQTY, QTYMoved, '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, 
                        @cNewPickDetailKey, 
                        @nQTY_Bal, -- QTY
                        --NULL, --TrafficCop,  
                        '1'  --OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK) 
			            WHERE PickDetailKey = @cPickDetailKey	

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 67537
                        SET @cErrMsg = rdt.rdtgetmessage( 67537, @cLangCode, 'DSP') --'InsPickDtlFail'
                        GOTO Step_5_Fail
                     END	

                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        QTY    = @nQTY_Act,
                        DropID = @cDropID,
                        TrafficCop = NULL,
                        EditDate = GetDate(), 
                        EditWho  = sUser_sName() 
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 67535
                        SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
                        GOTO Step_5_Fail
                     END

                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '5',
                        EditDate = GetDate(), 
                        EditWho  = sUser_sName() 
                     WHERE PickDetailKey = @cPickDetailKey


                     SET @d_step3 = GETDATE() - @d_step3
                     SET @c_col3 = 'QACT<QPD'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 67535
                        SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
                        GOTO Step_5_Fail
                     END
                     ELSE
                     BEGIN
                          -- (Vicky06) EventLog - QTY
                          EXEC RDT.rdt_STD_EventLog
                             @cActionType   = '3', -- Picking
                             @cUserID       = @cUserName,
                             @nMobileNo     = @nMobile,
                             @nFunctionID   = @nFunc,
                             @cFacility     = @cFacility,
                             @cStorerKey    = @cStorerkey,
                             --@cLocation     = @cLOC,
                             --@cID           = @cMUID,
                             @cSKU          = @cSKU,
                             @cUOM          = @cPackUOM3,
                             @nQTY          = @nQTY_Act,
                             @cLottable01   = @cLottable01,  
                             @cLottable02   = @cLottable02, 
                             @cLottable03   = @cLottable03, 
                             @dLottable04   = @dLottable04, 
                             @cRefNo1       = @cPickSlipNo,
                             @cRefNo2       = @cConsigneeKey,
                             @cRefNo3       = @cDropID,
                             @cOrderKey     = @cOrderKey,   -- (ChewKP01)
                             @cPickSlipNo   = @cPickSlipNo  -- (ChewKP01)
                     END
                  END 
               END -- @nCount = 0
   
               IF @cPrePickDetailKey <> @cPickDetailKey AND @nCount = 1 
               BEGIN

                 SET @d_step4 = GETDATE()

                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     Status = '0',
                     TrafficCop = NULL, 
                     EditDate = GetDate(), 
                     EditWho  = sUser_sName() 
                  WHERE PickDetailKey = @cPickDetailKey

                   SET @d_step4 = GETDATE() - @d_step4
                   SET @c_col4 = '@cPrePickDetailKey'


                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 67535
                     SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
                     GOTO Step_5_Fail
                  END
               END

               SET @cPrePickDetailKey = @cPickDetailKey
               FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD, @cOrderKey -- (ChewKP01)
            END 
            CLOSE curPD
            DEALLOCATE curPD 
         END   
         ELSE 
         BEGIN
            SET @d_step5 = GETDATE()

            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               DropID = @cDropID,
               Status = '5',
               EditDate = GetDate(), 
               EditWho  = sUser_sName() 
            FROM dbo.PickDetail PD
            JOIN dbo.ORDERS O (NOLOCK) ON (PD.OrderKey = O.OrderKey AND PD.Storerkey = O.Storerkey) -- (Vicky01)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
            JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
            WHERE PH.PickHeaderKey = @cPickSlipNo
              AND PH.ExternOrderKey <> '' -- (Vicky01) 
              AND O.ConsigneeKey = @cConsigneeKey
              AND PD.Storerkey = @cStorerkey
              AND PD.Status = '0'
              AND PD.QTY > 0
              AND PD.SKU = @cSKU
              AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01) 
              AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01) 
              AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '') -- (Vicky01)   
              AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')  -- (james01)

              SET @d_step5 = GETDATE() - @d_step5
              SET @c_col5 = '@d_step5'
  
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 67535
               SET @cErrMsg = rdt.rdtgetmessage( 67535, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO Step_5_Fail
            END
            ELSE
            BEGIN
              DECLARE @nQtyPick INT
              
              
              -- Start (ChewKP02)
              DECLARE curEventLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
              
              SELECT PD.OrderKey , SUM(PD.Qty)
              FROM dbo.PickDetail PD (NOLOCK)
              JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
              JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
              JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
              JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
              WHERE PH.PickHeaderKey = @cPickSlipNo
                AND PH.ExternOrderKey <> '' -- (Vicky01) 
                AND O.ConsigneeKey = @cConsigneeKey
                AND PD.Status = '5'
                AND PD.QTY > 0
                AND PD.SKU = @cSKU
                AND PD.DropID = @cDropID
                AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01) 
                AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01) 
                AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '') -- (Vicky01)  
--                AND LA.Lottable04 = @dLottable04 -- (Vicky01)
                AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '') -- (james01)
                AND PD.Storerkey = @cStorerkey
              GROUP By PD.OrderKey  
                
              OPEN curEventLog
              FETCH NEXT FROM curEventLog INTO @cOrderKey, @nPickedQty
              WHILE @@FETCH_STATUS = 0
              BEGIN
               
                 -- (Vicky06) EventLog - QTY 
                 EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '3', -- Picking
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerkey,
                    --@cLocation     = @cLOC,
                    --@cID           = @cMUID,
                    @cSKU          = @cSKU,
                    @cUOM          = @cPackUOM3,
                    @nQTY          = @nPickedQty, --@nQtyPick,
                    @cLottable01   = @cLottable01,  
                    @cLottable02   = @cLottable02, 
                    @cLottable03   = @cLottable03, 
                    @dLottable04   = @dLottable04, 
                    @cRefNo1       = @cPickSlipNo,
                    @cRefNo2       = @cConsigneeKey,
                    @cRefNo3       = @cDropID,
                    @cOrderKey     = @cOrderKey,   -- (ChewKP01)
                    @cPickSlipNo   = @cPickSlipNo  -- (ChewKP01)
               
               FETCH NEXT FROM curEventLog INTO @cOrderKey, @nPickedQty
              END
              CLOSE curEventLog
              DEALLOCATE curEventLog 
              -- End (ChewKP02)
              
              
              

              SELECT @nQtyPick = SUM(QTY)
              FROM dbo.PickDetail PD (NOLOCK)
              JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
              JOIN dbo.ORDERS O (NOLOCK) ON (OD.OrderKey = O.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
              JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
              JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT AND PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU) -- (Vicky01)
              WHERE PH.PickHeaderKey = @cPickSlipNo
                AND PH.ExternOrderKey <> '' -- (Vicky01) 
                AND O.ConsigneeKey = @cConsigneeKey
                AND PD.Status = '5'
                AND PD.QTY > 0
                AND PD.SKU = @cSKU
                AND PD.DropID = @cDropID
                AND LA.Lottable01 = ISNULL(RTRIM(@cLottable01), '') -- (Vicky01) 
                AND LA.Lottable02 = ISNULL(RTRIM(@cLottable02), '') -- (Vicky01) 
                AND LA.Lottable03 = ISNULL(RTRIM(@cLottable03), '') -- (Vicky01)  
--                AND LA.Lottable04 = @dLottable04 -- (Vicky01)
                AND ISNULL(LA.Lottable04, '') = ISNULL(@dLottable04, '')   -- (james01)
                AND PD.Storerkey = @cStorerkey
                -- AND O.Storerkey = @cStorerkey -- (Vicky01)

              -- (Vicky06) EventLog - QTY 
--              EXEC RDT.rdt_STD_EventLog
--                 @cActionType   = '3', -- Picking
--                 @cUserID       = @cUserName,
--                 @nMobileNo     = @nMobile,
--                 @nFunctionID   = @nFunc,
--                 @cFacility     = @cFacility,
--                 @cStorerKey    = @cStorerkey,
--                 --@cLocation     = @cLOC,
--                 --@cID           = @cMUID,
--                 @cSKU          = @cSKU,
--                 @cUOM          = @cPackUOM3,
--                 @nQTY          = @nQtyPick,
--                 @cLottable01   = @cLottable01,  
--                 @cLottable02   = @cLottable02, 
--                 @cLottable03   = @cLottable03, 
--                 @dLottable04   = @dLottable04, 
--                 @cRefNo1       = @cPickSlipNo,
--                 @cRefNo2       = @cConsigneeKey,
--                 @cRefNo3       = @cDropID,
--                 @cOrderKey     = @cOrderKey,   -- (ChewKP01)
--                 @cPickSlipNo   = @cPickSlipNo  -- (ChewKP01)
             END
         END     

         -- Trace Info (Vicky02) - Start  
         SET @d_endtime = GETDATE()  
         INSERT INTO TraceInfo VALUES  
                 (RTRIM(@c_TraceName), @d_starttime, @d_endtime  
                 ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)  
                 ,CONVERT(CHAR(12),@d_step1,114)  
                 ,CONVERT(CHAR(12),@d_step2,114)  
                 ,CONVERT(CHAR(12),@d_step3,114)  
                 ,CONVERT(CHAR(12),@d_step4,114)  
                 ,CONVERT(CHAR(12),@d_step5,114)  
                 ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  
  
            SET @d_step1 = NULL  
            SET @d_step2 = NULL  
            SET @d_step3 = NULL  
            SET @d_step4 = NULL  
            SET @d_step5 = NULL  
         -- Trace Info (Vicky02) - End  

         SET @nCount   = 0

         SET ROWCOUNT 1
         SELECT @cNextSKU = PD.SKU 
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.ORDERS O (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
         JOIN dbo.ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey AND O.Storerkey = OD.Storerkey) -- (Vicky01)
         JOIN dbo.PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.Storerkey = PD.Storerkey) -- (Vicky01)
         WHERE PH.PickHeaderKey = @cPickSlipNo
           AND PH.ExternOrderKey <> '' -- (Vicky01) 
           AND O.ConsigneeKey = @cConsigneeKey
           AND PD.Storerkey = @cStorerkey
          -- AND O.Storerkey = @cStorerkey -- (Vicky01)
           AND PD.Status = '0'
           AND PD.QTY > 0
         SET ROWCOUNT 0

         SET @cSKU = @cNextSKU
      END   

      Step_5_Next:
      IF ISNULL(@cSKU,'') <> ''
      BEGIN
         --prepare screen 3 variable
         SET @cSKU         = ''
         SET @cOutField01  = @cPickSlipNo
         SET @cOutField02  = @cConsigneeKey
         SET @cOutField03  = '' -- SKU 

         SET @cInField03   = '' -- SKU 
                     
         -- Go to next screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END 
      ELSE
      BEGIN
         --prepare screen 2 variable
         SET @cOutField01  = @cPickSlipNo
         SET @cOutField02  = '' -- ConsigneeKey

         SET @cInField03   = '' -- ConsigneeKey 

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConsigneeKey

         -- Go to next screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cKeyDefaultUOMQTY  = ''
      SET @cKeyPackUOM3QTY    = '' 
      SET @cOutField01        = @cConsigneeKey
      SET @cOutField02        = @cSKU
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)
      SET @cOutField05        = @cLottable01
      SET @cOutField06        = @cLottable02
      SET @cOutField07        = @cLottable03
      SET @cOutField08        = rdt.rdtFormatDate(@dLottable04)
      SET @cOutField09        = @cDefaultUOMDIV
      SET @cOutField10        = @cDefaultUOMDesc
      SET @cOutField11        = @cPackUOM3
      SET @cOutField12        = @cDefaultUOMQTY
      SET @cOutField13        = @cPackUOM3QTY
      SET @cOutField14        = '' -- KeyDefaultUOMQTY
      SET @cOutField15        = '' -- KeyPackUOM3QTY

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- KeyDefaultUOMQTY

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cDropID            = ''
      SET @cOutField01        = @cConsigneeKey
      SET @cOutField02        = @cSKU
      SET @cOutField03        = SUBSTRING(@cSKUDesc,1,20)
      SET @cOutField04        = SUBSTRING(@cSKUDesc,21,20)
      SET @cOutField05        = @cDefaultUOMDIV
      SET @cOutField06        = @cDefaultUOMDesc
      SET @cOutField07        = @cPackUOM3
      SET @cOutField08        = @cDefaultUOMQTY
      SET @cOutField09        = @cPackUOM3QTY
      SET @cOutField10        = @cKeyDefaultUOMQTY
      SET @cOutField11        = @cKeyPackUOM3QTY
      SET @cOutField12        = ''
   END  
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 2095) Enter Option
   FINISH BUILD DROPID?

   BAL QTY: (Field01)
   ACT QTY: (Field02)

   1=YES
   2=NO

   OPTION: (Field03, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
 BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      --When Option is blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 67538
         SET @cErrMsg = rdt.rdtgetmessage( 67538, @cLangCode, 'DSP') --Option needed
         GOTO Step_6_Fail  
      END 
      ELSE IF @cOption = '1'
      BEGIN
         SET @cPickSlipNo = ''
         SET @cOutField01 = '' -- PickSlipNo    

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo    

         -- go to screen 1
         SET @nScn  = 2090
         SET @nStep = 1   
      END
      ELSE IF @cOption = '2'
      BEGIN
         SET @cConsigneeKey = ''
         SET @cOutField01   = @cPickSlipNo
         SET @cOutField02   = '' -- ConsigneeKey 

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConsigneeKey

         -- go to screen 2
         SET @nScn  = 2091
         SET @nStep = 2     
      END
      ELSE
      BEGIN
         SET @nErrNo = 67539
         SET @cErrMsg = rdt.rdtgetmessage( 67539, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail  
      END 
   END  
   GOTO Quit 

   Step_6_Fail:
   BEGIN
      SET @cOption       = ''
      SET @cOutField03   = '' -- Option

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Option 
   END  
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       ErrMsg           = @cErrMsg, 
       Func             = @nFunc,
       Step             = @nStep,            
       Scn              = @nScn,

       Facility         = @cFacility, -- (Vicky06)
       StorerKey        = @cStorerKey, -- (Vicky06)
       UserName         = @cUserName, -- (Vicky06)

       V_Loc            = @cLOC,
       V_SKU            = @cSKU,  
       V_UOM            = @cDefaultUOM,
       V_PickSlipNo     = @cPickSlipNo,
       V_ConsigneeKey   = @cConsigneeKey,
       V_SkuDescr       = @cSKUDesc,
       V_QTY            = @nQty,   
       V_Lottable01     = @cLottable01,
       V_Lottable02     = @cLottable02,
       V_Lottable03     = @cLottable03,
       V_Lottable04     = @dLottable04,
       V_String1        = @cBALQty,
       V_String2        = @cACTQty,
       V_String3        = @cPackUOM3,
       V_String4        = @cDefaultUOMDesc,
       V_String5        = @cDefaultUOMDIV,
       V_String6        = @cDefaultUOMQTY,
       V_String7        = @cPackUOM3QTY,
       V_String8        = @cKeyDefaultUOMQTY,
       V_String9        = @cKeyPackUOM3QTY,
       V_String10       = @cDropID,
       V_String11       = @cAutoScanInPS,
       V_String12       = @cAutoScanOutPS,

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