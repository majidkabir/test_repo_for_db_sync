SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SerialNoSearch                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Serial No Capture                                           */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 01-Sep-2006 1.0  jwong    Created                                    */
/* 26-Oct-2006 1.1  MaryVong Modified option #1. Serial # Capture:      */
/*                           1) Add in control not allow to re-scan     */
/*                              confirmed PickSlipNo                    */
/*                           2) Running total counted base on pickslip, */
/*                              not by individual SKU                   */
/*                           3) Running total appears on both Scan UPC  */
/*                              and Scan Serial No screens              */
/*                           4) Validate Short Pick when press ESC from */
/*                              Scan UPC screen                         */
/*                           5) User allow to rotate scanning UPC and   */
/*                              Serial No                               */
/*                           Note: No more calling Step_11              */
/* 24-Apr-2007 1.2  James    Split capture, delete & search to 3        */
/*                           different screen                           */
/* 29-Jan-2008 1.3  James    To clear field when user pressed esc       */
/* 08-Apr-2010 1.4  James    SOS#153915 - Change Serial No length from  */
/*                           18 to 20 digits (james01)                  */ 
/* 23-Feb-2012 1.5  Ung      SOS236331 Reorganize RDT message           */
/* 14-Jul-2014 1.6  James    SOS315487 - Extend length of serial no     */
/*                           from 20 to 30 chars (james02)              */
/* 30-Sep-2016 1.7  Ung      Performance tuning                         */
/* 23-Oct-2018 1.8  TungGH   Performance                                */
/************************************************************************/

CREATE  PROC [RDT].[rdtfnc_SerialNoSearch] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

-- Define a variable
DECLARE @nFunc      int,
      @nScn         int,
      @nStep        int,
      @cLangCode    NVARCHAR( 3),
      @nMenu        int,
      @nInputKey    NVARCHAR( 3), 
      @cInField01   NVARCHAR( 60),      @cInField02  NVARCHAR( 60),
      @cInField03   NVARCHAR( 60),      @cInField04  NVARCHAR( 60),
      @cInField05   NVARCHAR( 60),      @cInField06  NVARCHAR( 60),
      @cInField07   NVARCHAR( 60),      @cInField08  NVARCHAR( 60),
      @cInField09   NVARCHAR( 60),      @cInField10  NVARCHAR( 60),
      @cInField011  NVARCHAR( 60),      @cInField12  NVARCHAR( 60),
      @cInField013  NVARCHAR( 60),      @cInField14  NVARCHAR( 60),
      @cInField015  NVARCHAR( 60),     
      @cOutField01  NVARCHAR( 60),      @cOutField02  NVARCHAR( 60),   
      @cOutField03  NVARCHAR( 60),      @cOutField04  NVARCHAR( 60),   
      @cOutField05  NVARCHAR( 60),      @cOutField06  NVARCHAR( 60),   
      @cOutField07  NVARCHAR( 60),      @cOutField08  NVARCHAR( 60),   
      @cOutField09  NVARCHAR( 60),      @cOutField10  NVARCHAR( 60),   
      @cOutField11  NVARCHAR( 60),      @cOutField12  NVARCHAR( 60),   
      @cOutField13  NVARCHAR( 60),      @cOutField14  NVARCHAR( 60),   
      @cOutField15  NVARCHAR( 60),   
      @b_success   int,
      @n_err       int,
      @c_errmsg    NVARCHAR( 215),  
      @cFacility   NVARCHAR( 5)

Declare @cPickSlipNo         NVARCHAR( 10)
       ,@cUPC                NVARCHAR( 20)
       ,@cSerialNo           NVARCHAR( 30) --(james02)
       ,@cOrderKey           NVARCHAR( 10)
       ,@cOrderLineNumber    NVARCHAR( 5)
       ,@cOutZone            NVARCHAR( 18)
       ,@cZone               NVARCHAR( 18)
       ,@nQTY                int
       ,@cSKU                NVARCHAR( 20)
       ,@cDescr              NVARCHAR( 30) 
       ,@cStorerKey          NVARCHAR( 15)
       ,@cExternOrderKey     NVARCHAR( 10)
       ,@cSerialNoKey        NVARCHAR( 10)
       ,@nSKUCount           int
       ,@cScannedSerialCount NVARCHAR( 5)
       ,@cTotalSerialCount   NVARCHAR( 5)
       ,@cOption             NVARCHAR( 1)
       ,@cCompanyName        NVARCHAR( 40)
       ,@cCompanyName1       NVARCHAR( 20)
       ,@cCompanyName2       NVARCHAR( 20)
       ,@cSKUScannedCount     NVARCHAR( 5)
       ,@cSKUTotalSerialCount NVARCHAR( 5)
       ,@cSerialNo1           NVARCHAR( 20) --(james02)
       ,@cSerialNo2           NVARCHAR( 20) --(james02)
       ,@cCheckSSCC_SP        NVARCHAR( 20) --(james02)
       ,@cSQL                 NVARCHAR(MAX) --(james02)
       ,@cSQLParam            NVARCHAR(MAX) --(james02)

DECLARE @cScanAllFlag        NVARCHAR(1)
SELECT @cScanAllFlag = 'N'

-- Getting Mobile information
SELECT @nFunc      = Func,
      @nScn        = Scn,
      @nStep       = Step,
      @nInputKey   = InputKey,
      @cLangCode   = Lang_code,
      @nMenu       = Menu,
      @cFacility   = Facility,
      @cStorerKey  = StorerKey,
      @cInField01  = I_Field01,      @cInField02 = I_Field02,
      @cInField03  = I_Field03,      @cInField04 = I_Field04,
      @cInField05  = I_Field05,      @cInField06 = I_Field06,
      @cInField07  = I_Field07,      @cInField08 = I_Field08,
      @cInField09  = I_Field09,      @cInField10 = I_Field10,
      @cInField011 = I_Field11,      @cInField12 = I_Field12,
      @cInField013 = I_Field13,      @cInField14 = I_Field14,
      @cInField015 = I_Field15,
      @cOutField01 = O_Field01,      @cOutField02 = O_Field02,
      @cOutField03 = O_Field03,      @cOutField04 = O_Field04,
      @cOutField05 = O_Field05,      @cOutField06 = O_Field06,
      @cOutField07 = O_Field07,      @cOutField08 = O_Field08,
      @cOutField09 = O_Field09,      @cOutField10 = O_Field10,
      @cOutField10 = O_Field10,      @cOutField12 = O_Field12,
      @cOutField13 = O_Field13,      @cOutField14 = O_Field14,
      @cOutField15 = O_Field15,
      @cPickSlipNo = V_PickSlipNo,
      @cSKU        = V_SKU,          
      @cDescr      = V_SKUDescr, 
      @cOrderKey   = V_OrderKey,      
      @cUPC        = V_String1,      
      @cScannedSerialCount  = V_String2,   
      @cTotalSerialCount    = V_String3, 
      @cCompanyName1        = V_String4, 
      @cCompanyName2        = V_String5, 
      --@cSerialNo            = V_String6,   -- (james02)
      @cSKUScannedCount     = V_String7,
      @cSKUTotalSerialCount = V_String8,
      @cSerialNo1           = V_String9,     -- (james02)
      @cSerialNo2           = V_String10     -- (james02)
      FROM   RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 872    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 870
   IF @nStep = 1 GOTO Step_1   -- Scn = 879   Enter serial no to search
   IF @nStep = 2 GOTO Step_2   -- Scn = 880   display serial no info
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 554)
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   IF EXISTS (SELECT 1 FROM RDTSessionData WHERE Mobile = @nMobile)
      UPDATE RDTSessionData SET XML = '' WHERE Mobile = @nMobile
   ELSE
      INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)

   SET @nScn = 879
   SET @nStep = 1

-- initialise all variable  
   SET @cPickSlipNo = '' 
END

GOTO Quit

/********************************************************************************
Step 1. screen (scn = 879)
   Serial #: 
   @cInField01
********************************************************************************/
Step_1:

BEGIN

   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cSerialNo = ''
      SET @cSerialNo = @cInField01

      IF (@cSerialNo = '' OR @cSerialNo IS NULL) 
      BEGIN
         SET @nErrNo = 63251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Serial# Required
         GOTO Step_1_Fail      
      END

      -- (james02)
      -- If rdt CheckSSCC config has value 1 then check len of serialno
      -- If len of config > 1 and is a valid sp name then use customised sp to check for serial no validity
      SET @cCheckSSCC_SP = rdt.RDTGetConfig( @nFunc, 'CheckSSCC', @cStorerKey) 
      IF LEN( RTRIM( @cCheckSSCC_SP)) > 1 AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCheckSSCC_SP AND type = 'P')
      BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCheckSSCC_SP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cSerialNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,       '     +
               '@nFunc        INT,       '     +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     + 
               '@nInputKey    INT,       '     +
               '@cSerialNo    NVARCHAR( 30)  OUTPUT, ' +
               '@nErrNo       INT OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cSerialNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         -- (james01) - Start
         IF @cCheckSSCC_SP = '1'
         BEGIN
            IF LEN(RTRIM(@cSerialNo)) > 18   -- (james02)
            BEGIN
               SET @cSerialNo = RIGHT(RTRIM(@cSerialNo), 18)
            END
         END
      
      END      
      
      IF NOT EXISTS (
         SELECT 1 FROM dbo.SERIALNO WITH (NOLOCK) 
         WHERE SERIALNO = @cSerialNo 
            AND STORERKEY = @cStorerKey)
      BEGIN
         SET @nErrNo = 63252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SN# Not Exists
         GOTO Step_1_Fail      
      END

      SET @cSerialNo1 = SUBSTRING( RTRIM( @cSerialNo),  1, 20)  -- (james02)
      SET @cSerialNo2 = SUBSTRING( RTRIM( @cSerialNo), 21, 10)  -- (james02)
      SET @cOrderKey = ''
      SET @cCompanyName1 = ''
      SET @cCompanyName2 = ''
      SET @cSKU = ''
      SET @cDescr= ''

      SELECT 
         @cOrderKey = OrderKey, 
         @cSKU = SKU 
      FROM dbo.SERIALNO WITH (NOLOCK) 
      WHERE SERIALNO = @cSerialNo 
         AND STORERKEY = @cStorerKey

      SELECT 
         @cDescr = DESCR 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE SKU = @cSKU 
         AND STORERKEY = @cStorerKey

      SELECT 
         @cCompanyName = C_COMPANY 
      FROM dbo.ORDERS WITH (NOLOCK) 
      WHERE ORDERKEY = @cOrderKey 
--         AND STORERKEY = @cStorerKey

      SET @cCompanyName1 = SUBSTRING(@cCompanyName,  1, 20)
      SET @cCompanyName2 = SUBSTRING(@cCompanyName, 21, 20)

      GOTO Step_1_Next
   END
   
   IF @nInputKey = 0 -- Esc OR No
   BEGIN

      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cSerialNo = ''

      -- Delete session data
      DELETE RDTSessionData WHERE Mobile = @nMobile
      GOTO Quit

   END
   
   Step_1_Next:
   BEGIN
      SET @cOutField01 = @cSerialNo
      SET @cOutField02 = @cOrderKey
      SET @cOutField03 = @cCompanyName1
      SET @cOutField04 = @cCompanyName2
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING(@cDescr, 1, 20)
      SET @nScn = 880
      SET @nStep = 2
      GOTO Quit
   END

   Step_1_Fail:
   BEGIN
      SET @cSerialNo = ''
   END   
END
GOTO Quit

/********************************************************************************
Step 2. screen (scn = 880)
   Serial #: 
   XXXXXXXXXXXXXXXXXX
   Order #:
   XXXXXXXXXX
   Customer:
   XXXXXXXXXXXXXXXXXXXX
   XXXXXXXXXXXXXXXXXXXX
   SKU:
   XXXXXXXXXXXXXXXXXXXX
   <enter> - Delete SN#
********************************************************************************/
Step_2:

BEGIN

   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      GOTO Step_2_Next
   END
   
   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nScn  = 879
      SET @nStep = 1
--      SET @cSerialNo = @cSerialNo remarked by James 29/01/2008
      SET @cOutField01 = '' --Added by james on 29/01/2008 to clear field when user pressed esc
      GOTO Quit
   END
   
   Step_2_Next:
   BEGIN
      SET @cOutField01 = ''
      SET @nScn  = 879
      SET @nStep = 1
      GOTO Quit
   END

END
GOTO Quit

Quit:
BEGIN

   UPDATE RDTMOBREC WITH (ROWLOCK) SET
   EditDate = GETDATE(), 
   ErrMsg = @cErrMsg   , Func = @nFunc,
   Step = @nStep,            Scn = @nScn,
   O_Field01 = @cOutField01, O_Field02 =  @cOutField02,
   O_Field03 = @cOutField03, O_Field04 =  @cOutField04,
   O_Field05 = @cOutField05, O_Field06 =  @cOutField06,
   O_Field07 = @cOutField07, O_Field08 =  @cOutField08,
   O_Field09 = @cOutField09, O_Field10 =  @cOutField10,
   O_Field11 = @cOutField11, O_Field12 =  @cOutField12,
   O_Field13 = @cOutField13, O_Field14 =  @cOutField14,
   O_Field15 = @cOutField15, 
   I_Field01 = '',   I_field02 = '',
   I_Field03 = '',   I_field04 = '',
   I_Field05 = '',   I_field06 = '',
   I_Field07 = '',   I_field08 = '',
   I_Field09 = '',   I_field10 = '',
   I_Field11 = '',   I_field12 = '',
   I_Field13 = '',   I_field14 = '',
   I_Field15 = '',
   V_PickSlipNo = @cPickSlipNo,
   V_SKU        = @cSKU,     
   V_SKUDescr   = @cDescr, 
   V_OrderKey = @cOrderKey,     
   V_String1    = @cUPC,            
   V_String2    = @cScannedSerialCount,
   V_String3    = @cTotalSerialCount, 
   V_String4    = @cCompanyName1, 
   V_String5    = @cCompanyName2, 
   --V_String6    = @cSerialNo,     -- (james02)
   V_String7    = @cSKUScannedCount,
   V_String8    = @cSKUTotalSerialCount, 
   V_String9    = @cSerialNo1,      -- (james02)
   V_String10   = @cSerialNo2       -- (james02)
   WHERE Mobile = @nMobile
END





GO