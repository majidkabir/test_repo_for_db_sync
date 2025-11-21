SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_PackByCartonID                                  */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Carton packing with scanning serial no                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2019-04-01   1.0  James    WMS8119. Created                             */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_PackByCartonID](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE 
   @cSQL           NVARCHAR(MAX), 
   @cSQLParam      NVARCHAR(MAX), 
   @nCnt           INT, 
   @cReport        NVARCHAR( 20),
   @curLabelReport CURSOR

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cLabelPrinter  NVARCHAR( 10),
   @cPaperPrinter  NVARCHAR( 10),

   @cSKU                NVARCHAR( 20), 
   @cSKUDescr           NVARCHAR( 60), 
   @cDecodeSP           NVARCHAR( 20), 
   @cPickSlipNo         NVARCHAR( 10), 
   @cDropID             NVARCHAR( 20), 
   @cCaseID             NVARCHAR( 20), 
   @cSerialNo           NVARCHAR( 50), 
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cMax                NVARCHAR( MAX), 
   @cBarcode            NVARCHAR( Max), 
   @cSrSerialNo         NVARCHAR( Max), 
   @cUPC                NVARCHAR( 30),
   @cTemp_UPC           NVARCHAR( 30),
   @cTemp_DropID        NVARCHAR( 20), 
   @cTemp_CaseID        NVARCHAR( 20), 
   @cUserDefine01       NVARCHAR( 60), 
   @cUserDefine02       NVARCHAR( 60), 
   @cClosePallet        NVARCHAR( 1), 
   @cPrintManifest      NVARCHAR( 1), 
   @cOption             NVARCHAR( 1), 
   @cDelNotes           NVARCHAR( 10), 
   @nSKUCnt             INT,
   @bSuccess            INT,
   @cErrType            NVARCHAR( 20),
   @cWaveKey            NVARCHAR( 10),
   @cDataCapture        NVARCHAR(1),
   @cSerialNoCapture    NVARCHAR(1),

   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 

   @cWaveKey         = V_WaveKey,
   @cPickSlipNo      = V_PickSlipNo,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cCaseID          = V_CaseID, 
   @cDropID          = V_Dropid,
   @cMax             = V_Max,

   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cClosePallet        = V_String4,
   @cPrintManifest      = V_String5,
   @cSerialNo           = V_String41,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08, 
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15
   
FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_RefNo         INT,  @nScn_RefNo     INT,
   @nStep_SKUCaseSerial INT,  @nScn_SKUCaseSerial  INT

SELECT
   @nStep_RefNo         = 1,  @nScn_RefNo          = 5380,
   @nStep_SKUCaseSerial = 2,  @nScn_SKUCaseSerial  = 5381   

IF @nFunc = 833
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 1644
   IF @nStep = 1  GOTO Step_RefNo         -- Scn = 5380. Pickslipno
   IF @nStep = 2  GOTO Step_SKUCaseSerial -- Scn = 5381. SKU/Case Id/ Serial No

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 833        
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- Prepare next screen var
   SET @cOutField01 = '' 

   -- Initialise variable
   SET @cWaveKey = ''
   SET @cSKU = ''
   SET @cCaseID = ''
   SET @cSerialNo = ''
   SET @cMax = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep
   
   -- Go to next screen
   SET @nScn = @nScn_RefNo
   SET @nStep = @nStep_RefNo
END
GOTO Quit


/************************************************************************************
Scn = 5310. PickSlip No
   PickSlip No (field01, input)
************************************************************************************/
Step_RefNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWaveKey = @cInField01

      -- Check blank
      IF ISNULL( @cWaveKey, '') = ''
      BEGIN
         SET @nErrNo = 137101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveKey req
         GOTO Step_RefNo_Fail
      END

      -- Check valid WaveKey
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                      WHERE WD.WaveKey = @cWaveKey
                      AND   PD.Qty > 0
                      AND   PD.Status <= '3')
      BEGIN
         SET @nErrNo = 137102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Wave
         GOTO Step_RefNo_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cWaveKey, @cDropID, @cSKU, ' +
            ' @cCaseID, @cSerialNo, @cErrType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cWaveKey     NVARCHAR( 10), ' +
            '@cDropID      NVARCHAR( 20), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cSerialNo    NVARCHAR( 50), ' +
            '@cErrType     NVARCHAR( 20) OUTPUT, '+
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cWaveKey, @cDropID, @cSKU,
              @cCaseID, @cSerialNo, @cErrType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_RefNo_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cMax = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to next screen
      SET @nScn = @nScn_SKUCaseSerial 
      SET @nStep = @nStep_SKUCaseSerial 
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
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

      -- Reset all variables
      SET @cOutField01 = '' 

      -- Enable field
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
   END
   GOTO Quit

   Step_RefNo_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cWaveKey = ''
   END
   GOTO Quit
END
GOTO Quit

/***********************************************************************************
Scn = 5381. SKU/Case Id/ Serial No screen
   WaveKey     (field01)
   SKU/UPC     (field02, input)
   Case ID     (field03, input)
   Serial No   (field04, input)
***********************************************************************************/
Step_SKUCaseSerial:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cUPC =  @cInField02 
      SET @cCaseID =  @cInField03 
      SET @cSrSerialNo =  @cMax 
      SET @cBarcode = @cInField02

      IF ISNULL( @cUPC, '') = ''
      BEGIN
         SET @nErrNo = 137103
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Need SKU/UPC
         SET @cOutField02 = ''
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit  
      END

      IF ISNULL( @cCaseID, '') = ''
      BEGIN
         SET @nErrNo = 137104
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Need CaseID
         SET @cOutField02 = @cInField02
         SET @cOutField03 = ''
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit  
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
            @cUPC             OUTPUT, 
            @cUserDefine01    OUTPUT, 
            @cUserDefine02    OUTPUT
         END
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cWaveKey    OUTPUT, @cDropID     OUTPUT, ' +
               ' @cUPC           OUTPUT, @cCaseID     OUTPUT, @cSerialNo      OUTPUT, ' +
               ' @nErrNo         OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,             ' +
               ' @nFunc          INT,             ' +
               ' @cLangCode      NVARCHAR( 3),    ' +
               ' @nStep          INT,             ' +
               ' @nInputKey      INT,             ' +
               ' @cStorerKey     NVARCHAR( 15),   ' +
               ' @cFacility      NVARCHAR( 5),    ' +
               ' @cBarcode       NVARCHAR( MAX),  ' +
               ' @cWaveKey       NVARCHAR( 10)  OUTPUT, ' +
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cUPC           NVARCHAR( 30)  OUTPUT, ' +
               ' @cCaseID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cSerialNo      NVARCHAR( 50)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cWaveKey      OUTPUT, @cDropID     OUTPUT,
               @cUPC          OUTPUT, @cCaseID     OUTPUT, @cSrSerialNo      OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nSKUCnt = 0

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 137106
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         SET @cOutField02 = ''
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 137107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU barcode
         SET @cOutField02 = ''
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      --SET @cSKU = @cSKUCode
      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      SET @cSKU = @cUPC

      -- Get SKU info  
      SELECT @cDataCapture = DataCapture, 
             @cSerialNoCapture = SerialNoCapture
      FROM SKU WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
      AND   SKU = @cSKU  

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CaseID', @cCaseID) = 0
      BEGIN
         SET @nErrNo = 137108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         SET @cOutField02 = @cInField02
         SET @cOutField03 = ''
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit 
      END


      IF ISNULL( @cSrSerialNo, '') = ''
      BEGIN
         IF @cDataCapture IN ('1', '3') OR @cSerialNoCapture IN ('1', '3')
         BEGIN
            SET @nErrNo = 137105
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Need Serial No
            SET @cOutField02 = @cInField02
            SET @cOutField03 = @cInField03
            SET @cOutField04 = ''
            SET @cMax = ''
            EXEC rdt.rdtSetFocusField @nMobile, V_MAX
            GOTO Quit  
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cWaveKey, @cDropID, @cSKU, ' +
            ' @cCaseID, @cSerialNo, @cErrType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cWaveKey     NVARCHAR( 10), ' +
            '@cDropID      NVARCHAR( 20), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cSerialNo    NVARCHAR( MAX),' +
            '@cErrType     NVARCHAR( 20) OUTPUT, '+
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cWaveKey, @cDropID, @cSKU,
              @cCaseID, @cSrSerialNo, @cErrType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
         BEGIN
            IF @cErrType = 'SKU'
            BEGIN
               SET @cOutField02 = ''
               SET @cOutField03 = @cInField03
               SET @cOutField04 = @cMax
               EXEC rdt.rdtSetFocusField @nMobile, 2
            END

            IF @cErrType = 'CaseID'
            BEGIN
               SET @cOutField02 = @cInField02
               SET @cOutField03 = ''
               SET @cOutField04 = @cMax
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END

            IF @cErrType = 'SerialNo'
            BEGIN
               SET @cOutField02 = @cInField02
               SET @cOutField03 = @cInField03
               SET @cOutField04 = ''
               SET @cMax = ''
               EXEC rdt.rdtSetFocusField @nMobile, V_MAX
            END

            GOTO Quit  
         END
      END

      EXEC rdt.rdt_PackByCartonID_Confirm
         @nMobile,
         @nFunc,
         @cLangCode,
         @cStorerKey,
         @cFacility, 
         @cWaveKey, 
         @cDropID,
         @cSKU, 
         @cCaseID, 
         @cSrSerialNo,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2

         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cMax = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2  -- SKU/UPC

     -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cWaveKey, @cDropID, @cSKU, @cCaseID, ' + 
               ' @cSerialNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cWaveKey     NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cCaseID      NVARCHAR( 20), ' +
               '@cSerialNo    NVARCHAR( 50), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cWaveKey, @cDropID, @cSKU, @cCaseID, 
              @cSrSerialNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Go to prev screen
      SET @nScn = @nScn_SKUCaseSerial
      SET @nStep = @nStep_SKUCaseSerial
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = ''

      -- Go to next screen
      SET @nScn = @nScn_RefNo
      SET @nStep = @nStep_RefNo
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

      V_WaveKey   = @cWaveKey,
      V_PickSlipNo= @cPickSlipNo,
      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,
      V_CaseID    = @cCaseID, 
      V_Dropid    = @cDropID,
      V_Max       = @cMax,

	   V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cClosePallet,
      V_String5  = @cPrintManifest,
      V_String41 = @cSerialNo,
               
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