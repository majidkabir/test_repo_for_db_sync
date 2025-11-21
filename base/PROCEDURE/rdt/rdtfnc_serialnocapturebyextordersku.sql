SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SerialNoCaptureByExtOrderSKU                 */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Serial no capture by ext orderkey + sku                     */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 16-Mar-2016 1.0  James      SOS365632 Created                        */
/* 12-May-2016 1.1  James      Check serialno for valid format (james01)*/
/* 30-Sep-2016 1.2  Ung        Performance tuning                       */
/* 17-Oct-2018 1.3  Gan        Performance tuning                       */
/* 14-Dec-2023 1.4  Ung        WMS-24364 Convert to generic module      */
/*                             Clean up source                          */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_SerialNoCaptureByExtOrderSKU] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE 
   @bSuccess      INT,
   @n_Err         INT,
   @c_ErrMsg      NVARCHAR( 20),
   @cSQL          NVARCHAR(MAX), 
   @cSQLParam     NVARCHAR(MAX),
   @tExtValidate  VARIABLETABLE,
   @tSerialNoCfm  VARIABLETABLE

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cOrderKey           NVARCHAR( 10),
	@cSKU                NVARCHAR( 20),
	@cSKUDescr           NVARCHAR( 60),

   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cPickStatus         NVARCHAR( 1),
   @cOrderStatus        NVARCHAR( 1),

	@cExternOrderKey        NVARCHAR( 50),
	@cSerialNo           NVARCHAR( 30),

   @nExpQTY             INT,
   @nActQTY             INT,
   
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

   @cOrderKey  = V_OrderKey,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,

   @cExtendedUpdateSP   = V_String21,  
   @cExtendedValidateSP = V_String22,  
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cPickStatus         = V_String25,
   @cOrderStatus        = V_String26,

   @cExternOrderKey     = V_String41,
   @cSerialNo           = V_String42,
   
   @nExpQTY             = V_Integer1,
   @nActQTY             = V_Integer2,

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Start            INT, 
   @nStep_ExternOrderKey   INT,  @nScn_ExternOrderKey   INT,
   @nStep_SKU              INT,  @nScn_SKU              INT,
   @nStep_SerialNo         INT,  @nScn_SerialNo         INT,
   @nStep_ConfirmSerialNo  INT,  @nScn_ConfirmSerialNo  INT

SELECT
   @nStep_Start            = 0,
   @nStep_ExternOrderKey   = 1,  @nScn_ExternOrderKey  = 4530,
   @nStep_SKU              = 2,  @nScn_SKU             = 4531,
   @nStep_SerialNo         = 3,  @nScn_SerialNo        = 4532,
   @nStep_ConfirmSerialNo  = 4,  @nScn_ConfirmSerialNo = 4533

IF @nFunc = 878 -- Serial no capture by ExternOrderKey
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start           -- Func = 878
   IF @nStep = 1 GOTO Step_ExternOrderKey  -- 4530 ExternOrderKey
   IF @nStep = 2 GOTO Step_SKU             -- 4531 SKU
   IF @nStep = 3 GOTO Step_SerialNo        -- 4531 Serial no
   IF @nStep = 4 GOTO Step_ConfirmSerialNo -- 4532 Confirm serial no
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 878. Menu
********************************************************************************/
Step_Start:
BEGIN
	-- Storer configure
	SET @cOrderStatus = rdt.RDTGetConfig( @nFunc, 'OrderStatus', @cStorerKey)
	IF @cOrderStatus = '0'
	   SET @cOrderStatus = ''
	SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
	IF @cPickStatus = '0'
	   SET @cPickStatus = ''
   
   -- Default status
   IF @cPickStatus  = '' SET @cPickStatus  = '5'
   IF @cOrderStatus = '' SET @cOrderStatus = '5'
   
   -- Set the entry point
   SET @nScn = @nScn_ExternOrderKey
   SET @nStep = @nStep_ExternOrderKey

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4530
   EXT ORDER KEY  (Field01, input)
********************************************************************************/
Step_ExternOrderKey:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cExternOrderKey = @cInField01

      -- Check blank
      IF @cExternOrderKey = ''
      BEGIN
         SET @nErrNo = 97551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EXT ORDKEY REQ
         GOTO Quit
      END

      -- Get order info
      DECLARE @cStatus NVARCHAR( 10)
      SET @cOrderKey = ''
      SELECT 
         @cOrderKey = OrderKey,
         @cStatus = [Status]
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternOrderKey = @cExternOrderKey

      -- Check order valid
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 97552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV EXT ORDKEY
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check order status
      IF CHARINDEX( @cOrderStatus, @cStatus) = 0
      BEGIN
         SET @nErrNo = 97553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOrderStatus
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Go to SKU screen
      SET @cOutField01 = @cExternOrderKey
      SET @cOutField02 = '' -- SKU

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign-Out
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 4531
   EXT ORDER KEY  (Field01)
   SKU            (Field02, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)
      
      -- Screen mapping
      SET @cUPC = @cInField02

      -- Check blank
      IF @cUPC = ''
      BEGIN
         SET @nErrNo = 97554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC 
         GOTO Quit
      END

      DECLARE @nSKUCnt INT
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
         SET @nErrNo = 97555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 97556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get SKU
      EXEC rdt.rdt_GetSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      SET @cSKU = @cUPC

      -- Get SKU info
      DECLARE @cSerialNoCapture NVARCHAR( 1)
      SELECT 
         @cSKUDescr = DESCR, 
         @cSerialNoCapture = SerialNoCapture
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Check need serial No
      IF @cSerialNoCapture NOT IN ('1', '3')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         SET @nErrNo = 97557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not SNO SKU
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check SKU in order
      IF NOT EXISTS ( SELECT 1
          FROM dbo.PickDetail WITH (NOLOCK)
          WHERE OrderKey = @cOrderKey
            AND SKU = @cSKU
            AND QTY > 0
            AND Status <> '4'
            AND CHARINDEX( Status, @cPickStatus) > 0)
      BEGIN
         SET @nErrNo = 97558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO RECORD
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get statistic
      SELECT @nExpQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status <> '4'
         AND CHARINDEX( PD.Status, @cPickStatus) > 0
      
      SELECT @nActQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      -- Go to serial no screen
      SET @cOutField01 = @cExternOrderKey
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField05 = '' -- Serial No
      SET @cOutField07 = CAST( @nExpQTY AS NVARCHAR( 5))
      SET @cOutField08 = CAST( @nActQTY AS NVARCHAR( 5))

      -- Fully captured
      IF @nExpQTY = @nActQTY
      BEGIN
         SET @nErrNo = 97559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fully captured
         SET @cOutField02 = ''
         GOTO Quit
      END
      
      SET @nScn = @nScn_SerialNo
      SET @nStep = @nStep_SerialNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to extern order screen
      SET @cOutField01 = '' -- ExtOrderKey
      
      SET @nScn = @nScn_ExternOrderKey
      SET @nStep = @nStep_ExternOrderKey
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 4532
   EXT ORDER KEY  (Field01)
   SKU            (Field02)
   DESC1          (Field03)
   DESC2          (Field04)
   SERIAL NO      (Field05, input)
   ORG QTY        (Field06)
   EXP QTY        (Field07)
   ACT QTY        (Field08)
********************************************************************************/
Step_SerialNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSerialNo = @cInField05
      
      -- Check blank
      IF @cSerialNo = ''
      BEGIN
         SET @nErrNo = 97560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SerialNo
         GOTO Quit
      END

      -- Validate serial no
      EXEC rdt.rdt_SerialNoCaptureByExtOrderSKU_SerialNoValidate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
         @cOrderKey        = @cOrderKey,
         @cExternOrderKey  = @cExternOrderKey,
         @cSKU             = @cSKU,
         @cSerialNo        = @cSerialNo,
         @nSerialQTY       = 1,
         @nErrNo           = @nErrNo      OUTPUT,
         @cErrMsg          = @cErrMsg     OUTPUT
      IF @nErrNo <> 0
      BEGIN  
         -- Go to confirm serial no screen
         IF @nErrNo = -1
         BEGIN  
         	SET @cOutField01 = SUBSTRING( @cSerialNo, 1, 20)
         	SET @cOutField02 = SUBSTRING( @cSerialNo, 21, 10)
         	SET @cOutField03 = '' -- Option
         	
         	SET @nScn = @nScn_ConfirmSerialNo
         	SET @nStep = @nStep_ConfirmSerialNo
         END

         GOTO Quit
      END

      -- Confirm
      EXEC RDT.rdt_SerialNoCaptureByExtOrderSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
         @cOrderKey        = @cOrderKey,
         @cExternOrderKey  = @cExternOrderKey,
         @cSKU             = @cSKU,
         @cSerialNo        = @cSerialNo,
         @nSerialQTY       = 1,
         @tSerialNoCfm     = @tSerialNoCfm,
         @nErrNo           = @nErrNo      OUTPUT,
         @cErrMsg          = @cErrMsg     OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
         
      -- Get statistic
      SELECT @nExpQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status <> '4'
         AND CHARINDEX( PD.Status, @cPickStatus) > 0
      
      SELECT @nActQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey--,@cWebGroup
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      -- Fully captured
      IF @nExpQTY = @nActQTY
      BEGIN
         SET @cOutField01 = @cExternOrderKey
         SET @cOutField02 = '' -- SKU

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         -- Remain in current screen
         SET @cOutField05 = '' -- Serial no
         SET @cOutField07 = CAST( @nExpQTY AS NVARCHAR( 5))
         SET @cOutField08 = CAST( @nActQTY AS NVARCHAR( 5))
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cExternOrderKey
      SET @cOutField02 = '' -- SKU

      SET @cFieldAttr05 = '' -- SerialNo

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
END
GOTO Quit


/***********************************************************************************
Step 4. Screen = 4533
   INVALID SERIAL NO
   PROCEED?
   1 = YES
   9 = NO
   OPTION   (field01, input)
***********************************************************************************/
Step_ConfirmSerialNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 2)
      
      -- Screen mapping
      SET @cOption = @cInField03

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 97561
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Check option
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 97562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Confirm
         EXEC RDT.rdt_SerialNoCaptureByExtOrderSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
            @cOrderKey        = @cOrderKey,
            @cExternOrderKey  = @cExternOrderKey,
            @cSKU             = @cSKU,
            @cSerialNo        = @cSerialNo,
            @nSerialQTY       = 1,
            @tSerialNoCfm     = @tSerialNoCfm,
            @nErrNo           = @nErrNo      OUTPUT,
            @cErrMsg          = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Get statistic
      SELECT @nExpQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status <> '4'
         AND CHARINDEX( PD.Status, @cPickStatus) > 0
      
      SELECT @nActQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      -- Fully captured
      IF @nExpQTY = @nActQTY
      BEGIN
         SET @cOutField01 = @cExternOrderKey
         SET @cOutField02 = '' -- SKU

         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Go back screen
         SET @nScn  = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cExternOrderKey
         SET @cOutField02 = @cSKU
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField05 = ''
         SET @cOutField07 = CAST( @nExpQTY AS NVARCHAR( 5))
         SET @cOutField08 = CAST( @nActQTY AS NVARCHAR( 5))
         
         SET @nScn = @nScn_SerialNo
         SET @nStep = @nStep_SerialNo
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cExternOrderKey
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField05 = '' -- Serial no
      SET @cOutField07 = CAST( @nExpQTY AS NVARCHAR( 5))
      SET @cOutField08 = CAST( @nActQTY AS NVARCHAR( 5))
      
      SET @nScn = @nScn_SerialNo
      SET @nStep = @nStep_SerialNo
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      -- UserName  = @cUserName,

      V_OrderKey = @cOrderKey,
      V_SKU = @cSKU,
      V_SKUDescr = @cSKUDescr,
            
      V_String21 = @cExtendedUpdateSP,  
      V_String22 = @cExtendedValidateSP,  
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cExtendedInfo,
      V_String25 = @cPickStatus,
      V_String26 = @cOrderStatus,
      
      V_String41 = @cExternOrderKey,
      V_String42 = @cSerialNo,
      
      V_Integer1 = @nExpQTY,
      V_Integer2 = @nActQTY,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02 = @cFieldAttr02, 
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO