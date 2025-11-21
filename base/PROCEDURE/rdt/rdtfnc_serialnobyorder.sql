SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SerialNoByOrder                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Serial No Capture Reset                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 05-Mar-2012 1.0  Ung      SOS237587 Created                          */
/* 15-Mar-2012 1.1  Ung      Enlarge ExterOrderKey field                */
/* 16-Mar-2012 1.2  Ung      Make StorerKey + OrderKey + SerialNo unique*/
/* 09-Jul-2012 1.3  Ung      SOS249193 support scan multi serialno      */
/* 14-Aug-2012 1.4  Ung      SOS253037 Add validation extern orderkey   */
/*                           should not same as serial no               */
/* 02-Aug-2013 1.5  ChewKP   SOS#285141 SerialNo by QRCode (ChewKP01)   */
/* 11-Jul-2014 1.6  James    SOS314637-Allow duplicate serialno in diff */
/*                           orders by config (james01)                 */
/* 16-Feb-2016 1.7  SPChin   SOS363737 - Bug Fixed                      */
/* 25-Feb-2016 1.8  ChewKP   SOS#364494 - Add StorerConfig (ChewKP02)   */
/*                           ExtendedValidateSP,ExtendedInfoSP          */
/* 30-Sep-2016 1.9  Ung      Performance tuning                         */
/* 23-Oct-2018 2.0  TungGH   Performance                                */   
/* 10-Sep-2019 2.1  James    WMS-10007 Add ExtendedInfoSP in screen 2   */
/*                           ESC part (james02)                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_SerialNoByOrder] (
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

   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),

   @cExternOrderKey  NVARCHAR( 30),
   @cOrderKey        NVARCHAR( 10),
   @nSerialNoCount   INT,
   @cMax             NVARCHAR(MAX), -- (ChewKP01)
   @cExtendedDecodeSP NVARCHAR(20), -- (ChewKP01)
   @cExecStatements   NVARCHAR(4000), -- (ChewKP01)
   @cExecArguments    NVARCHAR(4000), -- (ChewKP01)
   @cSKU              NVARCHAR(20),   -- (CheWKP01)
   @b_Success         INT,            -- (ChewKP01)
   @cCodeString       NVARCHAR(MAX),  -- (ChewKP01)
   @cAllowDupSerialNo NVARCHAR( 10),  -- (James01)
   @cExtendedInfoSP     NVARCHAR(30), -- (ChewKP02)
   @cExtendedValidateSP NVARCHAR(30), -- (CheWKP02) 
   @cSQL                NVARCHAR(1000), -- (ChewKP02)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP02)
   @cOutInfo01          NVARCHAR(20), -- (ChewKP02) 

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

-- (ChewKP01)
DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)


-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,
   @cSKU       = V_SKU,
   @cMax       = V_Max, -- (ChewKP01)

   @cExternOrderKey = V_String1,
   @cOrderKey = V_String2,
   @cAllowDupSerialNo   = V_String4,      -- (james01)
   @cExtendedValidateSP = V_String5, -- (ChewKP02)
   @cExtendedInfoSP     = V_String6, -- (ChewKP02) 
   
   @nSerialNoCount  = V_Integer1,

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
IF @nFunc IN (875, 876)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 875, 876
   IF @nStep = 1 GOTO Step_1   -- Scn = 3020 ExternOrderKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 3021 SerialNo
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 875)
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
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Reset var
   SET @cOutField01 = '' -- ExternOrderKey
   SET @cOutField03 = '' -- SerialNoCounter

   SET @cAllowDupSerialNo = rdt.RDTGetConfig( @nFunc, 'AllowDupSerialNo', @cStorerKey)
   
   -- (ChewKP02)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
   IF @cExtendedInfoSP = '0'  
      SET @cExtendedInfoSP = ''  


   -- Set the entry point
   SET @nScn = 3020
   SET @nStep = 1
END

GOTO Quit

/********************************************************************************
Step 1. Scn = 3020
   ExternOrderKey (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cExternOrderKey = @cInField01
      SET @cOrderKey = @cInField02

      IF @cExternOrderKey = '' AND @cOrderKey = ''
      BEGIN
         SET @nErrNo = 75310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Atleast1InputReq
         GOTO Step_1_Fail
      END

-- (ChewKP01)
      -- Check blank PickSlipNo
--      IF @cExternOrderKey = ''
--      BEGIN
--         SET @nErrNo = 75301
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ExtOrdKey
--         GOTO Step_1_Fail
--      END

-- (ChewKP01)
      DECLARE @cStatus NVARCHAR(10)
      SET @cStatus = ''

      IF @cExternOrderKey <> ''
      BEGIN
         -- Get order info
         SET @cOrderKey = ''

         SELECT
            @cOrderKey = OrderKey,
            @cStatus = Status
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ExternOrderKey = @cExternOrderKey

         -- Check valid ExternOrderKey
         IF @cOrderKey = ''
         BEGIN
            SET @nErrNo = 75302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ExtOrdKey
            GOTO Step_1_Fail
         END
      END
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey )
         BEGIN
            SET @nErrNo = 75311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOrderKey
            GOTO Step_1_Fail
         END

         SELECT
            @cStatus = Status
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey


      END

      -- Check order status
      IF NOT (@cStatus > '0' AND @cStatus < '9')
      BEGIN
         SET @nErrNo = 75303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid status
         GOTO Step_1_Fail
      END

      -- Update counter
      SELECT @nSerialNoCount = ISNULL( SUM( QTY), 0)
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey


      -- Prepare next screen var
      SET @cOutField01 = @cExternOrderKey
      SET @cOutField02 = '' -- SerialNo
      SET @cOutField03 = CAST( @nSerialNoCount AS NVARCHAR( 5))
      SET @cOutField04 = @cOrderKey -- (ChewKP01)
      SET @cMax = ''
      SET @cOutField05 = '' -- (ChewKP02) 

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
       @cStorerKey  = @cStorerKey,
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
      SET @cExternOrderKey = ''
      SET @cOutField01 = '' -- ExternOrderKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3021
   ExternOrderKey (Field01)
   SerialNo       (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cSerialNo NVARCHAR( 18)

      -- Screen mapping
      SET @cCodeString = @cMax

      -- Check if SerialNo blank
      IF @cCodeString = ''
      BEGIN
         SET @nErrNo = 75304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need SerialNo
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_2_Fail
      END


      -- (ChewKP01)
      SET @cExtendedDecodeSP = rdt.RDTGetConfig( @nFunc, 'ExtendedDecodeSP', @cStorerKey)
		IF @cExtendedDecodeSP = '0' 		--SOS363737
         SET @cExtendedDecodeSP = ''	--SOS363737

      SET @cSKU = ''

      -- Extended info
      IF @cExtendedDecodeSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cExtendedDecodeSP) AND type = 'P')
         BEGIN


            SET @cExecStatements = N'EXEC ' + RTRIM( @cExtendedDecodeSP) +
                                    '  @nMobile              ' +
                                    ' ,@nFunc                ' +
                                    ' ,@c_CodeString         ' +
                                    ' ,@c_Storerkey          ' +
                                    ' ,@c_OrderKey           ' +
                                    ' ,@c_LangCode	          ' +
                                 	' ,@c_oFieled01   OUTPUT ' +
                                 	' ,@c_oFieled02   OUTPUT ' +
                                    ' ,@c_oFieled03   OUTPUT ' +
                                    ' ,@c_oFieled04   OUTPUT ' +
                                    ' ,@c_oFieled05   OUTPUT ' +
                                    ' ,@c_oFieled06   OUTPUT ' +
                                    ' ,@c_oFieled07   OUTPUT ' +
                                    ' ,@c_oFieled08   OUTPUT ' +
                                    ' ,@c_oFieled09   OUTPUT ' +
                                    ' ,@c_oFieled10   OUTPUT ' +
                                    ' ,@b_Success     OUTPUT ' +
                                    ' ,@n_ErrNo       OUTPUT ' +
                                    ' ,@c_ErrMsg      OUTPUT '

             SET @cExecArguments =
                         N'@nMobile              INT,                 ' +
                           ' @nFunc              INT,                 ' +
                           ' @c_CodeString       NVARCHAR(MAX),       ' +
                           ' @c_Storerkey        NVARCHAR(15),        ' +
                           ' @c_OrderKey         NVARCHAR(10),        ' +
                           ' @c_LangCode	       NVARCHAR(3),         ' +
                        	' @c_oFieled01        NVARCHAR(20) OUTPUT, ' +  -- SerialNo
                        	' @c_oFieled02        NVARCHAR(20) OUTPUT, ' +  -- SKU
                           ' @c_oFieled03        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled04        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled05        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled06        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled07        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled08        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled09        NVARCHAR(20) OUTPUT, ' +
                           ' @c_oFieled10        NVARCHAR(20) OUTPUT, ' +
                           ' @b_Success          INT      OUTPUT,     ' +
                           ' @n_ErrNo            INT      OUTPUT,     ' +
                           ' @c_ErrMsg           NVARCHAR(250) OUTPUT '

            EXEC sp_executesql @cExecStatements, @cExecArguments
                                 ,@nMobile
                                 ,@nFunc
                                 ,@cCodeString
                                 ,@cStorerKey
                                 ,@cOrderKey
                                 ,@cLangCode
                                 ,@c_oFieled01   OUTPUT
                                 ,@c_oFieled02   OUTPUT
                                 ,@c_oFieled03   OUTPUT
                                 ,@c_oFieled04   OUTPUT
                                 ,@c_oFieled05   OUTPUT
                                 ,@c_oFieled06   OUTPUT
                                 ,@c_oFieled07   OUTPUT
                                 ,@c_oFieled08   OUTPUT
                                 ,@c_oFieled09   OUTPUT
                                 ,@c_oFieled10   OUTPUT
                                 ,@b_Success     OUTPUT
                                 ,@nErrNo        OUTPUT
                                 ,@cErrMsg       OUTPUT


           IF @nErrNo <> 0
           BEGIN
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
                EXEC rdt.rdtSetFocusField @nMobile, 6
                GOTO Step_2_Fail
           END
           ELSE
           BEGIN
              SET @cSerialNo = ''
              SET @cSerialNo = @c_oFieled01
              SET @cSKU      = @c_oFieled02
           END
         END
      END
      ELSE
      BEGIN
          SET @cSerialNo = RTRIM(@cCodeString)
      END


      -- Check if scanned ExternOrderKey
      IF @cSerialNo = @cExternOrderKey
      BEGIN
         SET @nErrNo = 75305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Same ExtOrdKey
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_2_Fail
      END

      -- Check if duplicate SerialNo
      IF EXISTS( SELECT 1
         FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            --AND OrderKey = @cOrderKey -- (ChewKP01)
            AND OrderKey = CASE WHEN ISNULL( @cAllowDupSerialNo, '') = '1' THEN @cOrderKey ELSE OrderKey END
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 75306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SerialNo exist
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_2_Fail
      END

      -- Check if extern order same as SerialNo
      IF RTRIM( @cExternOrderKey) = RTRIM( @cSerialNo)
      BEGIN
         SET @nErrNo = 75309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SameExtOrd&SNO
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_2_Fail
      END
      
      -- Extended Validate SP -- (ChewKP02)
      IF @cExtendedValidateSP <> ''
      BEGIN
         
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
              
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3), ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cExternOrderKey  NVARCHAR( 30), ' +
               '@cOrderKey        NVARCHAR( 10),  ' +
               '@cSerialNo        NVARCHAR( 18),  ' +
               '@cSKU             NVARCHAR( 20),  ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0 
            BEGIN
               
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_2_Fail
            END
         END
      END  

      -- Get SerialNoKey
      DECLARE @n_err     INT
      DECLARE @c_errmsg  NVARCHAR( 20)
      DECLARE @cSerialNoKey NVARCHAR( 10)

      EXECUTE dbo.nspg_GetKey
         'SerialNo',
         10 ,
         @cSerialNoKey OUTPUT,
         @b_success    OUTPUT,
         @n_err        OUTPUT,
         @c_errmsg     OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 75307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
         GOTO Step_2_Fail
      END

      -- Insert serial no
      INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, LotNo, QTY)
      VALUES (@cSerialNoKey, @cOrderKey, '', @cStorerKey, @cSKU, @cSerialNo, '', 1) -- (ChewKP01)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 75308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSNOFail
         GOTO Step_2_Fail
      END

      -- Update counter
      SELECT @nSerialNoCount = ISNULL( SUM( QTY), 0)
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      
      IF @cExtendedInfoSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @cOutInfo01 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3), ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cExternOrderKey  NVARCHAR( 30), ' +
               '@cOrderKey        NVARCHAR( 10),  ' +
               '@cSerialNo        NVARCHAR( 18),  ' +
               '@cSKU             NVARCHAR( 20),  ' +
               '@cOutInfo01       NVARCHAR( 20) OUTPUT,'+
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @cOutInfo01 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0  
               GOTO Step_2_Fail  
              
            SET @cOutfield05 = @cOutInfo01  
            
              
              
         END 
      END
      -- Scan one SerialNo
      IF @nFunc = 875
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' --ExternOrderKey
         SET @cOutField03 = CAST( @nSerialNoCount AS NVARCHAR(5))

         -- Go to next screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- Scan multi SerialNo
      IF @nFunc = 876
      BEGIN
         -- Prepare current screen var
         SET @cOutField01 = @cExternOrderKey
         SET @cOutField02 = '' -- SerialNo
         SET @cOutField03 = CAST( @nSerialNoCount AS NVARCHAR(5))

         -- Go to next screen
         -- SET @nScn = @nScn - 1
         -- SET @nStep = @nStep - 1
      END

      SET @cMax = ''
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      IF @cExtendedInfoSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @cOutInfo01 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3), ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cExternOrderKey  NVARCHAR( 30), ' +
               '@cOrderKey        NVARCHAR( 10),  ' +
               '@cSerialNo        NVARCHAR( 18),  ' +
               '@cSKU             NVARCHAR( 20),  ' +
               '@cOutInfo01       NVARCHAR( 20) OUTPUT,'+
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cExternOrderKey, @cOrderKey, @cSerialNo, @cSKU, @cOutInfo01 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0  
               GOTO Step_2_Fail  
             
            IF ISNULL( @cOutInfo01, '') <> ''
               SET @cOutfield15 = @cOutInfo01  
         END 
      END

      -- Reset prev screen var
      SET @cOutField01 = '' --ExternOrderKey
      SET @cOutField03 = CAST( @nSerialNoCount AS NVARCHAR(5))
      SET @cMax = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSerialNo = ''
      SET @cOutField02 = '' --SerialNo
      SET @cMax = ''

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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,
      V_SKU     = @cSKU,
      V_Max     = @cMax, -- (ChewKP01)

      V_String1 = @cExternOrderKey,
      V_String2 = @cOrderKey,
      V_String4 = @cAllowDupSerialNo,
      
      V_String5 = @cExtendedValidateSP , -- (ChewKP02)
      V_String6 = @cExtendedInfoSP, -- (ChewKP02) 
      
      V_Integer1 = @nSerialNoCount,

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