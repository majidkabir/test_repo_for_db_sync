SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_Capture_SKUInfo                                 */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Capture sku info based on field customised by user             */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2018-11-23   1.0  James    WMS7002. Created                             */
/* 2021-02-04   1.1  Chermaine WMS-16159 Add FlowThru config,              */
/*                             Add Print Screen (cc01)                     */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_Capture_SKUInfo](
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

   @cOption        NVARCHAR( 1),
   @cSP            NVARCHAR( 20),
   @cShort         NVARCHAR( 10), 
   @cReportName    NVARCHAR( 20), 
   @cSPType        NVARCHAR( 10), 

   @cSKU                NVARCHAR( 20), 
   @cUCCSKU             NVARCHAR( 20), 
   @cSKUDescr           NVARCHAR( 60), 
   @cUCCNo              NVARCHAR( 20), 
   @cQty                NVARCHAR( 5), 
   @cDecodeSP           NVARCHAR( 20), 
   @cType               NVARCHAR( 20), 
   @cBarcode            NVARCHAR( 60), 
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),

   @cCaptureSKUInfoDefaultValue  NVARCHAR( 1),
   @cCaptureSKUInfoSetFocusOnUCC NVARCHAR( 1),
   @cCaptureSKUInfoDefaultQty    NVARCHAR( 5),
   @cDefaultQty                  NVARCHAR( 5),
   @cValidateExp                 NVARCHAR( 4000),
   @cValidateAction              NVARCHAR( 60),
   @cFlowThruScreen              NVARCHAR( 1), --(cc01)

   @nQty                INT,
   @nUCCQty             INT,
   @nSKUCnt             INT,
   @bSuccess            INT,
   @nTemp               INT,
   @cMax                NVARCHAR( MAX),
   @cFocusField         NVARCHAR( 10),
   @cMsgText            NVARCHAR( 250),
   @cWarningMsg         NVARCHAR( 250),
   @cCode2              NVARCHAR( 30),

   @cParam1Label   NVARCHAR( 20), 
   @cParam2Label   NVARCHAR( 20), 
   @cParam3Label   NVARCHAR( 20), 
   @cParam4Label   NVARCHAR( 20), 
   @cParam5Label   NVARCHAR( 20), 
   
   @cParam1Value   NVARCHAR( 60), 
   @cParam2Value   NVARCHAR( 60), 
   @cParam3Value   NVARCHAR( 60), 
   @cParam4Value   NVARCHAR( 60), 
   @cParam5Value   NVARCHAR( 60), 
   @cUDF01         NVARCHAR( 60),
   @cUDF02         NVARCHAR( 60),
   @cUDF03         NVARCHAR( 60),
   @cUDF04         NVARCHAR( 60),
   @cUDF05         NVARCHAR( 60),
   @cParams        NVARCHAR( 10),
   @cParam1        NVARCHAR( 30),
   @cParam2        NVARCHAR( 30),
   @cParam3        NVARCHAR( 30),
   @cParam4        NVARCHAR( 30),
   @cParam5        NVARCHAR( 30),


   
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

   @cUCCNo      = V_UCC,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = V_QTY, 
   @cMax        = V_Max,

   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cOption             = V_String4,
   @cDefaultQty         = V_String5,
   @cCaptureSKUInfoDefaultValue = V_string6,
   @cFlowThruScreen     = V_String7, --(cc01)


   @cParam1Label     = V_String11, 
   @cParam2Label     = V_String12, 
   @cParam3Label     = V_String13, 
   @cParam4Label     = V_String14, 
   @cParam5Label     = V_String15, 
   
   @cParam1Value     = V_String41, 
   @cParam2Value     = V_String42, 
   @cParam3Value     = V_String43, 
   @cParam4Value     = V_String44, 
   @cParam5Value     = V_String45, 

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
   
FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_UCCSKU     INT,  @nScn_UCCSKU      INT,
   @nStep_Params     INT,  @nScn_Params      INT,
   @nStep_Success    INT,  @nScn_Success     INT,
   @nStep_Print      INT,  @nScn_Print       INT  --(cc01)

SELECT
   @nStep_UCCSKU     = 1,  @nScn_UCCSKU      = 5300,
   @nStep_Params     = 2,  @nScn_Params      = 5301,
   @nStep_Success    = 3,  @nScn_Success     = 5302,
   @nStep_Print      = 4,  @nScn_Print       = 5303   --(cc01)

IF @nFunc = 826
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start   -- Menu. Func = 826
   IF @nStep = 1  GOTO Step_UCCSKU  -- Scn = 5300. UCC/SKU Barcode, Qty
   IF @nStep = 2  GOTO Step_Params  -- Scn = 5301. SKU, Descr, Param1..5
   IF @nStep = 3  GOTO Step_Success -- Scn = 5302. Success
   IF @nStep = 4  GOTO Step_Print   -- Scn = 5303. Print --(cc01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 826
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

   SET @cCaptureSKUInfoSetFocusOnUCC = rdt.RDTGetConfig( @nFunc, 'CaptureSKUInfoSetFocusOnUCC', @cStorerKey)
   IF @cCaptureSKUInfoSetFocusOnUCC = '1'
      EXEC rdt.rdtSetFocusField @nMobile, 1 --UCCNo
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 2 --SKU

   SET @cCaptureSKUInfoDefaultQty = rdt.RDTGetConfig( @nFunc, 'CaptureSKUInfoDefaultQty', @cStorerKey)
   IF @cCaptureSKUInfoDefaultQty = 0
      SET @cDefaultQty = ''
   ELSE
      SET @cDefaultQty = @cCaptureSKUInfoDefaultQty

   SET @cCaptureSKUInfoDefaultValue = rdt.RDTGetConfig( @nFunc, 'CaptureSKUInfoDefaultValue', @cStorerKey)
   IF @cCaptureSKUInfoDefaultValue = '0'  
      SET @cCaptureSKUInfoDefaultValue = ''
      
   --(cc01)
   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)

   -- Prepare next screen var
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = CASE WHEN @cDefaultQty <> '' THEN @cDefaultQty ELSE '' END

   -- Initialise variable
   SET @cOption = '1'
   SET @cSKU = ''
   SET @cUCCSKU = ''
   SET @nUCCQty = 0
   SET @cQty = '0'
   SET @nQty = 0

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
   SET @nScn = @nScn_UCCSKU
   SET @nStep = @nStep_UCCSKU
END
GOTO Quit


/************************************************************************************
Scn = 5300. Label Option
   UCC (field01, input)
   SKU (field02, input)
   QTY (field03, input)
************************************************************************************/
Step_UCCSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField01
      SET @cSKU = @cInField02
      SET @cQty = @cInField03

      -- Check blank
      IF @cUCCNo = '' AND @cSKU = ''
      BEGIN
         SET @nErrNo = 132051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req
         GOTO Step_1_Fail
      END

      -- Check blank
      IF @cUCCNo <> '' AND @cSKU <> ''
      BEGIN
         SET @nErrNo = 132052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either UCC/SKU
         GOTO Step_1_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 132053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      IF @cUCCNo <> ''
      BEGIN
         SET @cBarcode = @cUCCNo
         SET @cSKU = ''
         SET @cType = 'UCC'
      END
      ELSE
      BEGIN
         SET @cBarcode = @cSKU
         SET @cUCCNo = ''
         SET @cType = 'UPC'
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUserDefine01    = @cUCCNo  OUTPUT, 
               @cUPC    = @cSKU    OUTPUT, 
               @nQty    = @nQty    OUTPUT, 
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = @cType
            
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            -- Customize decode
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
                  ' @cUCCNo      OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cBarcode     NVARCHAR( 2000), ' +
                  ' @cUCCNo       NVARCHAR( 20)  OUTPUT, ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQty         INT            OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,
                  @cUCCNo      OUTPUT, @cSKU         OUTPUT, @nQty        OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg      OUTPUT
            END
         END
      END

      IF @cUCCNo <> ''
      BEGIN
      /*
         -- Validate UCC
         EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cUCCNo, -- UCC
            @cStorerKey, 
            '1'      -- Received
      */
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND   UCCNo = @cUCCNo)

         BEGIN
            SET @nErrNo = 132054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
            GOTO Step_1_Fail_UCC
         END

         SELECT 
            @cUCCSKU = SKU.SKU, 
            @cSKUDescr = SKU.Descr,
            @nUCCQty = Qty
         FROM dbo.UCC UCC (NOLOCK)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (SKU.StorerKey = UCC.StorerKey AND SKU.SKU = UCC.SKU)
         WHERE SKU.StorerKey = @cStorerKey
         AND   UCC.UCCNo = @cUCCNo
      END

      IF @cSKU <> ''
      BEGIN
         SET @cUCCSKU = ''
         SET @nSKUCnt = 0

         EXEC RDT.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 132055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_1_Fail_SKU
         END

         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 132056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU barcode
            GOTO Step_1_Fail_SKU
         END

         --SET @cSKU = @cSKUCode
         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey  = @cStorerKey
           ,@cSKU        = @cSKU          OUTPUT
           ,@bSuccess    = @bSuccess      OUTPUT
           ,@nErr        = @nErrNo        OUTPUT
           ,@cErrMsg     = @cErrMsg       OUTPUT

         SELECT @cSKUDescr = SKU.Descr
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         IF rdt.rdtIsValidQty( @cQty, 1) = 0
         BEGIN
            SET @nErrNo = 132057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Step_1_Fail_QTY
         END

         SET @nQty = CAST( @cQty AS INT)
      END

      IF @cUCCSKU <> ''
      BEGIN
         SET @cSKU = @cUCCSKU
         SET @nQty = @nUCCQty
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cUCCNo, @cSKU, @nQty, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cUCCNo       NVARCHAR( 20), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cUCCNo, @cSKU, @nQty,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_1_Fail
      END

      -- Get report info
      SELECT 
         @cParam1Label = UDF01, 
         @cParam2Label = UDF02, 
         @cParam3Label = UDF03, 
         @cParam4Label = UDF04, 
         @cParam5Label = UDF05, 
         @cSP = Long, 
         @cShort = RTRIM( ISNULL( Short, ''))
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'CAPSKUINFO' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      AND   ( ( Code2 = '') OR ( Code2 = @nFunc))

      -- Check report param setup
      IF @cParam1Label = '' AND 
         @cParam2Label = '' AND 
         @cParam3Label = '' AND 
         @cParam4Label = '' AND 
         @cParam5Label = ''
      BEGIN
         SET @nErrNo = 132058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Step_1_Fail
      END
      
      DECLARE @nI INT
      SET @nI = 5

      WHILE @nI < 5
      BEGIN
         IF @cParam1Label <> '' AND NOT EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SKU'
            AND  COLUMN_NAME = @cParam1Label)
         SET @cErrMsg = @cParam1Label + ' invalid'

         IF @cParam2Label <> '' AND NOT EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SKU'
            AND  COLUMN_NAME = @cParam2Label)
         SET @cErrMsg = @cParam2Label + ' invalid'

         IF @cParam3Label <> '' AND NOT EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SKU'
            AND  COLUMN_NAME = @cParam3Label)
         SET @cErrMsg = @cParam3Label + ' invalid'

         IF @cParam4Label <> '' AND NOT EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SKU'
            AND  COLUMN_NAME = @cParam4Label)
         SET @cErrMsg = @cParam4Label + ' invalid'

         IF @cParam5Label <> '' AND NOT EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SKU'
            AND  COLUMN_NAME = @cParam5Label)
         SET @cErrMsg = @cParam5Label + ' invalid'
      END

      IF @cErrMsg <> ''
         GOTO Step_1_Fail

      SET @cParam1Value = ''
      SET @cParam2Value = ''
      SET @cParam3Value = ''
      SET @cParam4Value = ''
      SET @cParam5Value = ''

      IF @cCaptureSKUInfoDefaultValue = '1'
         EXEC rdt.rdt_Capture_SKUInfo_DefaultValue
            @nMobile,
            @nFunc,
            @cLangCode,
            @cStorerKey,
            @cUCCNo,
            @cSKU,
            @nQty,
            @cParam1Label, 
            @cParam2Label, 
            @cParam3Label, 
            @cParam4Label, 
            @cParam5Label, 
            @cParam1Value  OUTPUT, 
            @cParam2Value  OUTPUT, 
            @cParam3Value  OUTPUT, 
            @cParam4Value  OUTPUT, 
            @cParam5Value  OUTPUT, 
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT

      -- Enable / disable field
      SET @cFieldAttr05 = CASE WHEN @cParam1Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr07 = CASE WHEN @cParam2Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr09 = CASE WHEN @cParam3Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr11 = CASE WHEN @cParam4Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr13 = CASE WHEN @cParam5Label = '' THEN 'O' ELSE '' END
            
      -- Clear optional in field
      SET @cInField05 = ''
      SET @cInField07 = ''
      SET @cInField09 = ''
      SET @cInField11 = ''
      SET @cInField13 = ''
      
      --Check config Param hav value(cc01)
      DECLARE @cParamCol NVARCHAR( MAX)
      DECLARE @cParamVal NVARCHAR( MAX)
      
      SET @cParamCol = @cParam1Label + ',' + @cParam2Label + ',' + @cParam3Label + ',' + @cParam4Label + ',' + @cParam5Label
      SET @cParamVal = @cParam1Value + ',' + @cParam2Value + ',' + @cParam3Value + ',' + @cParam4Value + ',' + @cParam5Value
      
      INSERT INTO traceInfo(TraceName,col1,Col2)
      VALUES ('cc',@cParamVal,@cParamCol)
      
      IF NOT EXISTS (SELECT TOP 1 1 FROM fnc_DelimSplit(',',@cParamVal) 
                  WHERE seqNo IN (SELECT seqNo FROM fnc_DelimSplit(',',@cParamCol) WHERE colValue <>'')
                  AND colValue IN ('','0'))
                  
      BEGIN
      	IF @cFlowThruScreen = '1'
      	BEGIN
      		SET @cInField01 = '1' --option
      		GOTO Step_Print    		
      	END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cParam1Label
      SET @cOutField05 = @cParam1Value
      SET @cOutField06 = @cParam2Label
      SET @cOutField07 = @cParam2Value
      SET @cOutField08 = @cParam3Label
      SET @cOutField09 = @cParam3Value
      SET @cOutField10 = @cParam4Label
      SET @cOutField11 = @cParam4Value
      SET @cOutField12 = @cParam5Label
      SET @cOutField13 = @cParam5Value

      -- Go to next screen
      SET @nScn = @nScn_Params
      SET @nStep = @nStep_Params

      -- Set the focus on first enabled field
      IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE
      IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 7 ELSE
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 9 ELSE
      IF @cFieldAttr07 = '' EXEC rdt.rdtSetFocusField @nMobile, 11 ELSE
      IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 13
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

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = @cDefaultQty
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_1_Fail_UCC:
   BEGIN
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_1_Fail_SKU:
   BEGIN
      SET @cOutField02 = ''
      SET @cOutField03 = @cDefaultQty
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   GOTO Quit

   Step_1_Fail_QTY:
   BEGIN
      SET @cOutField03 = @cDefaultQty
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END
   GOTO Quit
END
GOTO Quit


/***********************************************************************************
Scn = 5301. Parameter screen
   SKU          (field01)
   DESCR1       (field02)
   DESCR2       (field03)
   Param1 label (field01)
   Param1 value (field02, input)
   Param2 label (field03)
   Param2 value (field04, input)
   Param3 label (field05)
   Param3 value (field06, input)
   Param4 label (field07)
   Param4 value (field08, input)
   Param5 label (field09)
   Param5 value (field10, input)
***********************************************************************************/
Step_Params:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1Value = CASE WHEN @cFieldAttr05 = 'O' THEN @cOutField05 ELSE @cInField05 END
      SET @cParam2Value = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END
      SET @cParam3Value = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cParam4Value = CASE WHEN @cFieldAttr11 = 'O' THEN @cOutField11 ELSE @cInField11 END
      SET @cParam5Value = CASE WHEN @cFieldAttr13 = 'O' THEN @cOutField13 ELSE @cInField13 END

      -- Retain value
      SET @cOutField05 = @cInField05
      SET @cOutField07 = @cInField07
      SET @cOutField09 = @cInField09
      SET @cOutField11 = @cInField11
      SET @cOutField13 = @cInField13

      -- Get Codelkup RDTLBLRPT values
      SELECT @cUDF01         = ISNULL(UDF01,''),
             @cUDF02         = ISNULL(UDF02,''),
             @cUDF03         = ISNULL(UDF03,''),
             @cUDF04         = ISNULL(UDF04,''),
             @cUDF05         = ISNULL(UDF05,'')
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE Listname = 'CAPSKUINFO' 
      AND   Code = @cOption 
      AND   Storerkey = @cStorerKey
      AND   ( ( Code2 = '') OR ( Code2 = @nFunc))
      ORDER BY Code

      SET @cParams = CASE WHEN @cUDF01<>'' THEN 'Y' ELSE 'N' END
                   + CASE WHEN @cUDF02<>'' THEN 'Y' ELSE 'N' END
                   + CASE WHEN @cUDF03<>'' THEN 'Y' ELSE 'N' END
                   + CASE WHEN @cUDF04<>'' THEN 'Y' ELSE 'N' END
                   + CASE WHEN @cUDF05<>'' THEN 'Y' ELSE 'N' END

      -- Check at least one parameter input
      IF NOT ((@cUDF01<>'' AND ISNULL(@cParam1Value,'')<>'') OR
              (@cUDF02<>'' AND ISNULL(@cParam2Value,'')<>'') OR
              (@cUDF03<>'' AND ISNULL(@cParam3Value,'')<>'') OR
              (@cUDF04<>'' AND ISNULL(@cParam4Value,'')<>'') OR
              (@cUDF05<>'' AND ISNULL(@cParam5Value,'')<>'') )
      BEGIN
         SET @nErrNo = 132059
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
         GOTO Quit
      END

      -- Check mandatory parameter input
      -- (Parameter Text Label start with * means mandatory)
      SET @nTemp = CASE WHEN (LEFT(@cUDF01,1)='*' AND ISNULL(@cParam1Value,'')='') THEN 5
                        WHEN (LEFT(@cUDF02,1)='*' AND ISNULL(@cParam2Value,'')='') THEN 7
                        WHEN (LEFT(@cUDF03,1)='*' AND ISNULL(@cParam3Value,'')='') THEN 9
                        WHEN (LEFT(@cUDF04,1)='*' AND ISNULL(@cParam4Value,'')='') THEN 11
                        WHEN (LEFT(@cUDF05,1)='*' AND ISNULL(@cParam5Value,'')='') THEN 13
                        ELSE 0
                   END

      IF @nTemp > 0
      BEGIN
         SET @nErrNo = 132060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
         EXEC rdt.rdtSetFocusField @nMobile, @nTemp
         GOTO Quit
      END

      -- Validate Input
      IF EXISTS(SELECT TOP 1 1 FROM dbo.CodeLkup WITH (NOLOCK)
                 WHERE Listname = 'VLDSKUINFO' 
                 AND   Code = @cOption 
                 AND   Storerkey = @cStorerKey)
      BEGIN
         DECLARE C_VALIDATION CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT FocusField     = Short
              , MsgText        = ISNULL(RTRIM(Long), '')
              , ValidateExp    = Notes
              , Code2          = Code2
              , ValidateAction = UDF01
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE Listname = 'VLDSKUINFO' 
         AND   Code = @cOption 
         AND   Storerkey = @cStorerKey
         AND   ISNULL(Notes,'') <>''
         ORDER BY Code2

         OPEN C_VALIDATION

         SET @cSQLParam = '@bSuccess   INT          OUTPUT'
                        +',@cMsgText   NVARCHAR(250) OUTPUT'
                        +',@cStorerKey NVARCHAR(15) OUTPUT'
                        +',@cFacility  NVARCHAR(5)  OUTPUT'
                        +',@cSku       NVARCHAR(20) OUTPUT'
                        +',@cParam1    NVARCHAR(30) OUTPUT'
                        +',@cParam2    NVARCHAR(30) OUTPUT'
                        +',@cParam3    NVARCHAR(30) OUTPUT'
                        +',@cParam4    NVARCHAR(30) OUTPUT'
                        +',@cParam5    NVARCHAR(30) OUTPUT'
                        +',@cOption    NVARCHAR(1)'
                        +',@cCode2     NVARCHAR(30)'
                        +',@cValidateAction NVARCHAR(60)'

         WHILE 1=1
         BEGIN
            FETCH NEXT FROM C_VALIDATION
             INTO @cFocusField, @cMsgText, @cValidateExp, @cCode2, @cValidateAction

            IF @@FETCH_STATUS<>0
               BREAK

            SET @bSuccess = 0
            IF @cValidateAction='DECODE'
               SET @cSQL = 'SET @bSuccess=1 BEGIN ' +CHAR(10)+ @cValidateExp +CHAR(10)+ 'END'
            ELSE
               SET @cSQL = 'IF (' + @cValidateExp + ') SET @bSuccess=1'

            BEGIN TRY
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam
                  , @bSuccess    OUTPUT
                  , @cMsgText    OUTPUT
                  , @cStorerKey  OUTPUT
                  , @cFacility   OUTPUT
                  , @cSku        OUTPUT
                  , @cParam1Value     OUTPUT
                  , @cParam2Value     OUTPUT
                  , @cParam3Value     OUTPUT
                  , @cParam4Value     OUTPUT
                  , @cParam5Value     OUTPUT
                  , @cOption
                  , @cCode2
                  , @cValidateAction
            END TRY
            BEGIN CATCH
               SET @nErrNo = 132061
               --SET @cErrMsg = 'VALIDATION ERR^' + ISNULL(@cCode2,'')
               SET @cErrMsg = ISNULL(@cCode2,'') + @cMsgText
               BREAK
            END CATCH

            IF ISNULL(@bSuccess,0)<>1
            BEGIN
               IF ISNUMERIC(@cFocusField) = 1
               BEGIN
                  SET @nTemp = CONVERT(INT, CONVERT(FLOAT, @cFocusField))
                  IF @nTemp >= 1 AND @nTemp <=10 AND SUBSTRING(@cParams,@nTemp,1) = 'Y'
                  BEGIN
                     SET @nTemp = @nTemp * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nTemp
                  END
               END

               IF ISNULL(@cValidateAction,'')='WARNING'
               BEGIN
                  SET @cWarningMsg = ISNULL(@cMsgText,'')
               END
               ELSE
               BEGIN
                  SET @nErrNo = 119904
                  SET @cErrMsg = CASE WHEN ISNULL(@cMsgText,'')<>'' THEN @cMsgText
                                      ELSE rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data Not Found
                                 END
                  BREAK
               END
            END
         END

         CLOSE C_VALIDATION
         DEALLOCATE C_VALIDATION

         IF @nErrNo<>0
            GOTO Quit
      END

      EXEC rdt.rdt_Capture_SKUInfo_Confirm
         @nMobile,
         @nFunc,
         @cLangCode,
         @cStorerKey,
         @cUCCNo,
         @cSKU,
         @nQty,
         @cParam1Label, 
         @cParam2Label, 
         @cParam3Label, 
         @cParam4Label, 
         @cParam5Label, 
         @cParam1Value, 
         @cParam2Value, 
         @cParam3Value, 
         @cParam4Value, 
         @cParam5Value, 
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Enable / disable field
      SET @cFieldAttr05 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr13 = ''

      -- Go to prev screen
      SET @nScn = @nScn_Success
      SET @nStep = @nStep_Success
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cCaptureSKUInfoSetFocusOnUCC = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 1 --UCCNo
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 --SKU

      SET @nScn = @nScn_UCCSKU
      SET @nStep = @nStep_UCCSKU

      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = CASE WHEN @cDefaultQty <> '' THEN @cDefaultQty ELSE '' END
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5302. Parameter screen
   SKU          (field01)
   DESCR1       (field02)
   DESCR2       (field03)
   Param1 label (field01)
   Param1 value (field02, input)
   Param2 label (field03)
   Param2 value (field04, input)
   Param3 label (field05)
   Param3 value (field06, input)
   Param4 label (field07)
   Param4 value (field08, input)
   Param5 label (field09)
   Param5 value (field10, input)
***********************************************************************************/
Step_Success:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @cCaptureSKUInfoSetFocusOnUCC = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 1 --UCCNo
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 --SKU

      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = CASE WHEN @cDefaultQty <> '' THEN @cDefaultQty ELSE '' END

      -- Go to prev screen
      SET @nScn = @nScn_UCCSKU
      SET @nStep = @nStep_UCCSKU
   END
END
GOTO Quit

/***********************************************************************************
Scn = 5303. Parameter screen
   OPTION       (field01,  input)
***********************************************************************************/
Step_Print: 
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 132062  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option  
         GOTO Quit  
      END  
  
      -- Check valid option  
      IF @cOption <> '1' AND @cOption <> '2'  
      BEGIN  
         SET @nErrNo = 132063  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- Yes  
      BEGIN  
      	DECLARE @tPalletLabel AS VariableTable 
      	-- Common params  
         INSERT INTO @tPalletLabel (Variable, Value) VALUES   
         ( '@cStorerKey', @cStorerKey),  
         ( '@cSKU', @cSKU)
  
         -- Print label  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            'PICKLOCLBL', -- Report type  
            @tPalletLabel, -- Report params  
            'rdtfnc_Capture_SKUInfo',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
            GOTO Quit  
      END

      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = CASE WHEN @cDefaultQty <> '' THEN @cDefaultQty ELSE '' END

      -- Go to prev screen
      SET @nScn = @nScn_UCCSKU
      SET @nStep = @nStep_UCCSKU
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

      V_UCC      = @cUCCNo,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY, 
      V_Max      = @cMax,


	   V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cOption,
      V_String5  = @cDefaultQty,
      V_string6  = @cCaptureSKUInfoDefaultValue,
      V_String7  = @cFlowThruScreen, --(cc01)

      V_String11 = @cParam1Label,
      V_String12 = @cParam2Label,
      V_String13 = @cParam3Label,
      V_String14 = @cParam4Label,
      V_String15 = @cParam5Label,
      
      V_String41 = @cParam1Value,
      V_String42 = @cParam2Value,
      V_String43 = @cParam3Value,
      V_String44 = @cParam4Value,
      V_String45 = @cParam5Value,
               
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