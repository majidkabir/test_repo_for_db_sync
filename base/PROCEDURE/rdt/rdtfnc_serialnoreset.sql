SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SerialNoReset                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Serial No Capture Reset                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 20-Feb-2012 1.0  Ung      SOS236331 Created                          */
/* 30-Sep-2016 1.1  Ung      Performance tuning                         */
/* 14-Nov-2018 1.2  Gan      Performance tuning                         */
/************************************************************************/

CREATE  PROC [RDT].[rdtfnc_SerialNoReset] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,
   
   @cStorer          NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cUserName        NVARCHAR( 18), 
   
   @cPickSlipNo      NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @cSKUDescr        NVARCHAR( 60), 
   
   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60)  

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,
   
   @cPickSlipNo = V_PickSlipNo,
   @cSKU        = V_SKU,          
   @cSKUDescr   = V_SKUDescr, 
   @cOrderKey   = V_OrderKey,      
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15  
      
FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 874
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 874
   IF @nStep = 1 GOTO Step_1   -- Scn = 3010 pickslip no
   IF @nStep = 2 GOTO Step_2   -- Scn = 3011 UPC/SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 3012 Confirm reset? 
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 874)
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorer,
      @nStep       = @nStep

   -- Set the entry point
   SET @nScn = 3010
   SET @nStep = 1
END

GOTO Quit

/********************************************************************************
Step 1. Scn = 3010
   PickSlipNo (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Check blank PickSlipNo
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 75201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS# Required
         GOTO Step_1_Fail      
      END

      -- Check valid PickSlipNo
      IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 75202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PS#
         GOTO Step_1_Fail      
      END

      -- Check PickSlip scan-in
      IF EXISTS( SELECT 1
         FROM dbo.PickHeader PH WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON ([PI].PickSlipNo = PH.PickHeaderKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo 
            AND [PI].ScanInDate IS NULL)
      BEGIN
         SET @nErrNo = 75203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Not Scan In
         GOTO Step_1_Fail      
      END
         
      -- Check PickSlip scan-out
      IF rdt.RDTGetConfig( @nFunc, 'CaptureSNoNotCheckScanOut', @cStorer) <> '1'
         IF EXISTS( SELECT 1
            FROM dbo.PickHeader PH WITH (NOLOCK) 
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON ([PI].PickSlipNo = PH.PickHeaderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo 
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 75204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Not ScanOut
            GOTO Step_1_Fail      
         END

      -- Check if discrete PickSlip
      SELECT @cOrderKey = OrderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 75205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiscretePSOnly
         GOTO Step_1_Fail      
      END

      -- Check Orders.Status
      DECLARE @cStatus NVARCHAR(1)
      SELECT @cStatus = Status FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 75210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
         GOTO Step_1_Fail      
      END

      -- Prepare next screen var
      SET @cSKU = ''
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorer,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' -- PickSlipNo
   END   
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3011
   PickSlipNo (Field01)
   SKU        (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- Check if SKU blank
      IF @cSKU = ''
         SET @cSKUDescr = ''
      ELSE
      BEGIN
         DECLARE @b_success INT
         DECLARE @n_err     INT
         DECLARE @c_errmsg  NVARCHAR( 20)

         -- Validate SKU exists
         EXEC dbo.nspg_GETSKU @cStorer, @cSKU OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF @b_success = 0
         BEGIN
            SET @nErrNo = 75206
            SET @cErrMsg = rdt.rdtgetmessage( 73232, @cLangCode,'DSP') -- Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_2_Fail
         END

         -- Get SKU details
         SELECT @cSKUDescr = SKU.DESCR
         FROM dbo.SKU SKU WITH (NOLOCK)
         WHERE SKU.StorerKey = @cStorer
            AND SKU.SKU = @cSKU
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = '' --Option
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Reset prev screen var
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' -- PickSlipNo
      
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField02 = '' --SKU
   END   
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3012
   Confirm reset?
   PSNO     (field01)
   SKU      (field02)
   SKU DESC (field03)
   SKU DESC (field04)
   OPTION   (field05, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField05
      
      -- Check if blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 75207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_3_Fail      
      END

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 75208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_3_Fail      
      END

      IF @cOption = '1'
      BEGIN
         -- Reset pickslip and SKU
         IF @cSKU = ''
            DELETE dbo.SerialNo WHERE OrderKey = @cOrderKey
         ELSE
            DELETE dbo.SerialNo WHERE OrderKey = @cOrderKey AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 75209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del SNO Fail
            GOTO Step_3_Fail      
         END

         -- Back to pickslip screen
         SET @nScn = @nScn - 2 
         SET @nStep = @nStep - 2
         SET @cOutField01 = '' -- PickSlipNo
      END
      
      IF @cOption = '2'
      BEGIN
         -- Prepare prev screen var
         SET @cSKU = ''
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- SKU

         -- Back to pickslip screen
         SET @nScn = @nScn - 1 
         SET @nStep = @nStep - 1
      END
   END
      
   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn = @nScn - 1 
      SET @nStep = @nStep - 1
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' --SKU
   END
   GOTO QUIT
   
   Step_3_Fail:
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      V_PickSlipNo = @cPickSlipNo,
      V_SKU        = @cSKU,     
      V_SKUDescr   = @cSKUDescr, 
      V_OrderKey   = @cOrderKey,     
      
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15  

   WHERE Mobile = @nMobile
END

GO