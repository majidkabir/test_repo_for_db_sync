SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_CartonPack                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Carton packing                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2019-05-29   1.0  James    WMS9064. Created                             */
/* 2019-09-11   1.1  Ung      WMS-9064 Carton manifest after pack info     */
/*                            Clean up source                              */
/* 2020-03-13   1.2  James    WMS-12514 Carton id accept 60 chars (james01)*/  
/* 2020-07-15   1.3  Ung      WMS-13699 Remove UserDefine01                */
/*                            Add ExtendedInfo at PackInfo screen          */
/* 2021-01-15   1.4  Chermaine WMS-16081 Add Eventlog (cc01)               */
/* 2023-01-06   1.5  Ung      WMS-21489 Add DefaultCartonType              */
/*                            Move Eventlog to sub SP                      */
/* 2023-01-17   1.6  Ung      WMS-21570                                    */ 
/*                            Add @cDoc1Value to print param               */
/*                            Add conditional print pack list              */
/*                            Add ExtendedValidateSP at print pack list    */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_CartonPack](
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
   @nRowcount        INT, 
   @nTranCount       INT,
   @cSQL             NVARCHAR( MAX), 
   @cSQLParam        NVARCHAR( MAX), 
   @cPrintPackList   NVARCHAR( 1) = '', 

   @tExtVal          VariableTable, 
   @tExtUpd          VariableTable, 
   @tExtInfo         VariableTable, 
   @tConfirm         VariableTable, 
   @tPackInfo        VariableTable, 
   @tShipLabel       VariableTable, 
   @tCartonManifest  VariableTable, 
   @tPackList        VariableTable

-- RDT.RDTMobRec variables
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),

   @cPickSlipNo         NVARCHAR( 10), 
   @cCartonSKU          NVARCHAR( 20), 
   @nCartonQTY          INT, 
   
   @cCartonID           NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cPackInfoRefNo      NVARCHAR( 20),
   @cLabelNo            NVARCHAR( 20),

   @cDoc1Label          NVARCHAR( 20),
   @cDoc1Value          NVARCHAR( 20),

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20), 
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 4), 
   @cAllowCubeZero      NVARCHAR( 1),
   @cAllowWeightZero    NVARCHAR( 1),
   @cDefaultWeight      NVARCHAR( 1),  
   @cPickDetailCartonID NVARCHAR( 20),
   @cShipLabel          NVARCHAR( 10), 
   @cCartonManifest     NVARCHAR( 10), 
   @cPackList           NVARCHAR( 10),
   @cDefaultCartonType  NVARCHAR( 10), 

   @nCartonNo           INT,

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
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 

   @cPickSlipNo      = V_PickSlipNo,
   @cCartonSKU       = V_SKU,
   @nCartonQTY       = V_QTY, 

   @cCartonID           = V_String1,
   @cCartonType         = V_String2,
   @cCube               = V_String3,
   @cWeight             = V_String4,
   @cPackInfoRefNo      = V_String5,
   @cLabelNo            = V_String6,

   @cDoc1Label          = V_String10,
   @cDoc1Value          = V_String11,

   @cExtendedInfo       = V_String20,
   @cExtendedInfoSP     = V_String21,
   @cExtendedValidateSP = V_String22,
   @cExtendedUpdateSP   = V_String23,
   @cDecodeSP           = V_String24,
   @cCapturePackInfoSP  = V_String25,
   @cPackInfo           = V_String26,  
   @cAllowCubeZero      = V_String27,
   @cAllowWeightZero    = V_String28,
   @cDefaultWeight      = V_String29,  
   @cPickDetailCartonID = V_String30,
   @cShipLabel          = V_String31, 
   @cCartonManifest     = V_String32, 
   @cPackList           = V_String33,
   @cDefaultCartonType  = V_String34,

   @nCartonNo           = V_Integer1,

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
   @nStep_Doc           INT,  @nScn_Doc            INT,
   @nStep_CartonID      INT,  @nScn_CartonID       INT,
   @nStep_PrintPackList INT,  @nScn_PrintPackList  INT,
   @nStep_PackInfo      INT,  @nScn_PackInfo       INT

SELECT
   @nStep_Doc           = 1,  @nScn_Doc            = 5580,
   @nStep_CartonID      = 2,  @nScn_CartonID       = 5581,
   @nStep_PrintPackList = 3,  @nScn_PrintPackList  = 5582,
   @nStep_PackInfo      = 4,  @nScn_PackInfo       = 5583

IF @nFunc = 832
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 834
   IF @nStep = 1  GOTO Step_Doc           -- Scn = 5580. Scan Doc
   IF @nStep = 2  GOTO Step_CartonID      -- Scn = 5581. Scan Carton ID
   IF @nStep = 3  GOTO Step_PrintPackList -- Scn = 5582. Print PackList
   IF @nStep = 4  GOTO Step_PackInfo      -- Scn = 5583. Pack Info
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 834
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
   SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)  

   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
   IF @cCartonManifest = '0'
      SET @cCartonManifest = ''
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''
   SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
   IF @cDefaultCartonType = '0'
      SET @cDefaultCartonType = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''
   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
   IF @cPackList = '0'
      SET @cPackList = ''
   SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)
   IF @cPickDetailCartonID NOT IN ('DropID', 'CaseID')
      SET @cPickDetailCartonID = 'DropID'
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
   IF @cDecodeSP = '0'  
      SET @cDecodeSP = ''  

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Initialise variable
   SET @cDoc1Label = ''
   SET @cDoc1Value = ''

   SELECT @cDoc1Label = UDF01
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CartonPack'
      AND Code = @nFunc
      AND StorerKey = @cStorerKey
      AND code2 = @cFacility

   IF @cDoc1Label <> ''
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cDoc1Label
      SET @cOutField02 = '' -- Doc1Value

      -- Go to doc screen
      SET @nScn = @nScn_Doc
      SET @nStep = @nStep_Doc
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- CartonID

      -- Go to carton ID screen
      SET @nScn = @nScn_CartonID
      SET @nStep = @nStep_CartonID
   END
END
GOTO Quit


/************************************************************************************
Scn = 5580. Scan Doc No
   Doc No (field01, input)
************************************************************************************/
Step_Doc:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDoc1Value = @cInField02

      -- Check blank
      IF @cDoc1Value = ''
      BEGIN
         SET @nErrNo = 144151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, ' +
               ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
               ' @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @tExtVal        VariableTable READONLY, ' + 
               ' @cDoc1Value     NVARCHAR( 20), ' + 
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cCartonSKU     NVARCHAR( 20), ' +
               ' @nCartonQTY     INT,           ' +
               ' @cPackInfo      NVARCHAR( 4),  ' + 
               ' @cCartonType    NVARCHAR( 10), ' + 
               ' @cCube          NVARCHAR( 10), ' + 
               ' @cWeight        NVARCHAR( 10), ' + 
               ' @cPackInfoRefNo NVARCHAR( 20), ' +
               ' @cPickSlipNo    NVARCHAR( 10), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cLabelNo       NVARCHAR( 20), ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, 
               @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
               @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- CartonID

      -- Go to carton ID screen
      SET @nScn = @nScn_CartonID
      SET @nStep = @nStep_CartonID
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
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
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5581. Carton ID screen
   Carton ID   (field01, input)
***********************************************************************************/
Step_CartonID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60) 

      -- Prepare next screen var
      SET @cCartonID = LEFT( @cInField01, 20)
      SET @cBarcode = @cInField01         -- (james01)  

      -- Check blank
      IF @cCartonID = ''
      BEGIN
         SET @nErrNo = 144152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton ID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
      BEGIN
         SET @nErrNo = 144153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode
               ,@cUserDefine01 = @cCartonID  OUTPUT
               -- ,@cUPC       = @cCartonSKU OUTPUT
               -- ,@nQTY       = @nCartonQTY OUTPUT
               ,@nErrNo        = @nErrNo     OUTPUT  
               ,@cErrMsg       = @cErrMsg    OUTPUT

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cCartonID OUTPUT, @cCartonSKU OUTPUT, @nCartonQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
            SET @cSQLParam =
               ' @nMobile        INT,             ' +
               ' @nFunc          INT,             ' +
               ' @cLangCode      NVARCHAR( 3),    ' +
               ' @nStep          INT,             ' +
               ' @nInputKey      INT,             ' +
               ' @cStorerKey     NVARCHAR( 15),   ' +
               ' @cFacility      NVARCHAR( 5),    ' +
               ' @cBarcode       NVARCHAR( 60),   ' +
               ' @cCartonID      NVARCHAR( 20)  OUTPUT, ' +
               ' @cCartonSKU     NVARCHAR( 20)  OUTPUT, ' +
               ' @nCartonQTY     INT            OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cCartonID OUTPUT, @cCartonSKU OUTPUT, @nCartonQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, ' +
               ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
               ' @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @tExtVal        VariableTable READONLY, ' + 
               ' @cDoc1Value     NVARCHAR( 20), ' + 
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cCartonSKU     NVARCHAR( 20), ' +
               ' @nCartonQTY     INT,           ' +
               ' @cPackInfo      NVARCHAR( 4),  ' + 
               ' @cCartonType    NVARCHAR( 10), ' + 
               ' @cCube          NVARCHAR( 10), ' + 
               ' @cWeight        NVARCHAR( 10), ' + 
               ' @cPackInfoRefNo NVARCHAR( 20), ' +
               ' @cPickSlipNo    NVARCHAR( 10), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cLabelNo       NVARCHAR( 20), ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, 
               @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
               @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      SET @cCartonType = @cDefaultCartonType

      -- Custom PackInfo field setup
      SET @cPackInfo = ''
      IF @cCapturePackInfoSP <> ''
      BEGIN
         -- Custom SP to get PackInfo setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tPackInfo, ' + 
               ' @cPackInfo OUTPUT, @cCartonType OUTPUT @cWeight OUTPUT, @cCube OUTPUT, @cPackInfoRefNo OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tPackInfo       VariableTable READONLY, ' +
               '@cPackInfo       NVARCHAR( 3)  OUTPUT, ' +
               '@cCartonType     NVARCHAR( 10) OUTPUT, ' +
               '@cWeight         NVARCHAR( 10) OUTPUT, ' +
               '@cCube           NVARCHAR( 10) OUTPUT, ' +
               '@cPackInfoRefNo  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tPackInfo, 
               @cPackInfo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cCube OUTPUT, @cPackInfoRefNo OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
         ELSE
            -- Setup is non SP
            SET @cPackInfo = @cCapturePackInfoSP
      END

      -- Capture pack info
      IF @cPackInfo <> ''
      BEGIN
         -- Check
         EXEC rdt.rdt_CartonPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CHECK', @tConfirm
            ,@cDoc1Value      = @cDoc1Value
            ,@cCartonID       = @cCartonID
            ,@cCartonSKU      = @cCartonSKU
            ,@nCartonQTY      = @nCartonQTY
            ,@cPickSlipNo     = @cPickSlipNo    OUTPUT
            ,@nCartonNo       = @nCartonNo      OUTPUT
            ,@cLabelNo        = @cLabelNo       OUTPUT
            ,@cPrintPackList  = @cPrintPackList OUTPUT
            ,@nErrNo          = @nErrNo         OUTPUT
            ,@cErrMsg         = @cErrMsg        OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Get PackInfo
         -- SET @cCartonType = ''
         SET @cWeight = ''
         SET @cCube = ''
         SET @cPackInfoRefNo = ''
      
         -- Prepare LOC screen var
         SET @cOutField01 = @cCartonType
         SET @cOutField02 = '' -- @cWeight
         SET @cOutField03 = '' -- @cCube  
         SET @cOutField04 = '' -- @cPackInfoRefNo
         SET @cOutField05 = '' -- @cExtendedInfo
      
         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr08 = '' -- QTY
      
         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4
      
         -- Go to next screen
         SET @nScn = @nScn_PackInfo
         SET @nStep = @nStep_PackInfo
            
         GOTO Step_CartonID_Quit
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_CartonPack

      -- Confirm
      EXEC rdt.rdt_CartonPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CONFIRM', @tConfirm
         ,@cDoc1Value      = @cDoc1Value
         ,@cCartonID       = @cCartonID
         ,@cCartonSKU      = @cCartonSKU
         ,@nCartonQTY      = @nCartonQTY
         ,@cPickSlipNo     = @cPickSlipNo    OUTPUT
         ,@nCartonNo       = @nCartonNo      OUTPUT
         ,@cLabelNo        = @cLabelNo       OUTPUT
         ,@cPrintPackList  = @cPrintPackList OUTPUT
         ,@nErrNo          = @nErrNo         OUTPUT
         ,@cErrMsg         = @cErrMsg        OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_CartonPack
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtUpd, ' +
               ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
               ' @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @tExtUpd        VariableTable READONLY, ' + 
               ' @cDoc1Value     NVARCHAR( 20), ' + 
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cCartonSKU     NVARCHAR( 20), ' +
               ' @nCartonQTY     INT,           ' +
               ' @cPackInfo      NVARCHAR( 4),  ' + 
               ' @cCartonType    NVARCHAR( 10), ' + 
               ' @cCube          NVARCHAR( 10), ' + 
               ' @cWeight        NVARCHAR( 10), ' + 
               ' @cPackInfoRefNo NVARCHAR( 20)  ' +
               ' @cPickSlipNo    NVARCHAR( 10), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cLabelNo       NVARCHAR( 20), ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtUpd, 
               @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
               @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_CartonPack
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_CartonPack
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
      
      IF @cShipLabel <> ''
      BEGIN
         -- Common params
         INSERT INTO @tShipLabel (Variable, Value) VALUES 
            ('@cStorerKey',   @cStorerKey), 
            ('@cPickSlipNo',  @cPickSlipNo), 
            ('@cCartonID',    @cCartonID), 
            ('@nCartonNo',    CAST( @nCartonNo AS NVARCHAR( 10))), 
            ('@cLabelNo',     @cLabelNo), 
            ('@cDoc1Value',   @cDoc1Value)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter, 
            @cShipLabel, -- Report type
            @tShipLabel, -- Report params
            'rdtfnc_CartonPack', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            SET @nErrNo = 0 -- Ignore error
      END
               
      -- Carton manifest
      IF @cCartonManifest <> ''
      BEGIN
         -- Get session info
         SELECT 
            @cLabelPrinter = Printer,
            @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile
         
         -- Common params
         INSERT INTO @tCartonManifest (Variable, Value) VALUES 
            ('@cStorerKey',   @cStorerKey), 
            ('@cPickSlipNo',  @cPickSlipNo), 
            ('@cCartonID',    @cCartonID), 
            ('@nCartonNo',    CAST( @nCartonNo AS NVARCHAR( 10))), 
            ('@cLabelNo',     @cLabelNo), 
            ('@cDoc1Value',   @cDoc1Value)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
            @cCartonManifest, -- Report type
            @tCartonManifest, -- Report params
            'rdtfnc_CartonPack', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            SET @nErrNo = 0 -- Ignore error
      END

      IF @cPackList <> ''
      BEGIN
         -- Check pack confirm
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9') OR @cPrintPackList = 'Y'
         BEGIN
            SET @cOutField01 = '' -- Option

            SET @nScn = @nScn_PrintPackList
            SET @nStep = @nStep_PrintPackList

            GOTO Quit
         END
      END

      -- Remain in current screen
      SET @cOutField01 = '' -- CartonID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cDoc1Label <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cDoc1Label
         SET @cOutField02 = '' -- Doc1Value

         -- Go to doc screen
         SET @nScn = @nScn_Doc
         SET @nStep = @nStep_Doc
      END
      ELSE
      BEGIN
         -- Logging
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign Out function
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
      END
   END

Step_CartonID_Quit:
   -- ExtendedInfoSP
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, ' +
            ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
            ' @cPickSlipNo, @nCartonNo, @cLabelNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @tExtVal        VariableTable READONLY, ' + 
            ' @cDoc1Value     NVARCHAR( 20), ' + 
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cCartonSKU     NVARCHAR( 20), ' +
            ' @nCartonQTY     INT,           ' +
            ' @cPackInfo      NVARCHAR( 4),  ' + 
            ' @cCartonType    NVARCHAR( 10), ' + 
            ' @cCube          NVARCHAR( 10), ' + 
            ' @cWeight        NVARCHAR( 10), ' + 
            ' @cPackInfoRefNo NVARCHAR( 20), ' +
            ' @cPickSlipNo    NVARCHAR( 10), ' + 
            ' @nCartonNo      INT,           ' + 
            ' @cLabelNo       NVARCHAR( 20), ' + 
            ' @cExtendedInfo NVARCHAR( 20)  OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_CartonID, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, 
            @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
            @cPickSlipNo, @nCartonNo, @cLabelNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Quit
            
         SET @cOutField15 = @cExtendedInfo
      END
   END

END
GOTO Quit


/********************************************************************************
Scn = 5582. Print packing list?
   Option (field01, input)
********************************************************************************/
Step_PrintPackList:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Need 2 chars to prompt error for contineous scan carton ID wihtout look at screen
      DECLARE @cOption NVARCHAR( 2) 
      
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 144154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 144155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtVal (Variable, Value) VALUES ('@cOption', @cOption)
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, ' +
               ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
               ' @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @tExtVal        VariableTable READONLY, ' + 
               ' @cDoc1Value     NVARCHAR( 20), ' + 
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cCartonSKU     NVARCHAR( 20), ' +
               ' @nCartonQTY     INT,           ' +
               ' @cPackInfo      NVARCHAR( 4),  ' + 
               ' @cCartonType    NVARCHAR( 10), ' + 
               ' @cCube          NVARCHAR( 10), ' + 
               ' @cWeight        NVARCHAR( 10), ' + 
               ' @cPackInfoRefNo NVARCHAR( 20), ' +
               ' @cPickSlipNo    NVARCHAR( 10), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cLabelNo       NVARCHAR( 20), ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtVal, 
               @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
               @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Common param
         INSERT INTO @tPackList (Variable, Value) VALUES 
            ('@cPickSlipNo', @cPickSlipNo), 
            ('@cDoc1Value',  @cDoc1Value)

         -- Print packing list
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
            @cPackList, -- Report type
            @tPackList, -- Report params
            'rdtfnc_CartonPack', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            SET @nErrNo = 0 -- Ignore error
      END
   END

   IF @cDoc1Label <> ''
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cDoc1Label
      SET @cOutField02 = '' -- Doc1Value

      -- Go to doc screen
      SET @nScn = @nScn_Doc
      SET @nStep = @nStep_Doc
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- CartonID

      -- Go to carton ID screen
      SET @nScn = @nScn_CartonID
      SET @nStep = @nStep_CartonID
   END      
END
GOTO Quit


/********************************************************************************
Scn = 5583. Capture pack info
   Carton Type (field01, input)
   Cube        (field02, input)
   Weight      (field03, input)
   RefNo       (field04, input)
********************************************************************************/
Step_PackInfo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)

      -- Screen mapping
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cPackInfoRefNo  = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Carton type
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cChkCartonType = ''
         BEGIN
            SET @nErrNo = 144156
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         
         -- Get default cube
         DECLARE @nDefaultCube FLOAT
         SELECT @nDefaultCube = [Cube]
         FROM Cartonization WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
         WHERE Storer.StorerKey = @cStorerKey
            AND Cartonization.CartonType = @cChkCartonType

         -- Check if valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 144157
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Different carton type scanned
         IF @cChkCartonType <> @cCartonType
         BEGIN
            SET @cCartonType = @cChkCartonType
            SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)
            SET @cWeight = ''

            SET @cOutField01 = @cCartonType
            SET @cOutField02 = @cWeight
            SET @cOutField03 = @cCube
         END
      END

      -- Weight
      IF @cFieldAttr02 = ''
      BEGIN
         SET @cWeight = TRIM( @cWeight)
         
         -- Check blank
         IF @cWeight = ''
         BEGIN
            SET @nErrNo = 144158
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0
         BEGIN
            SET @nErrNo = 144159
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check weight valid
         IF @cAllowWeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 144160
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField02 = @cWeight
      END
      
      -- Default weight  
      ELSE IF @cDefaultWeight IN ('2', '3')  
      BEGIN  
         -- Weight (SKU only)
         DECLARE @nWeight FLOAT

         -- Get pick filter
         DECLARE @cPickFilter NVARCHAR( MAX) = ''
         SELECT @cPickFilter = ISNULL( Long, '')
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'PickFilter'
            AND Code = @nFunc 
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility

         SET @cSQL = 
            ' SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0) ' + 
            ' FROM dbo.PickDetail PD (NOLOCK) ' + 
               ' JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU) ' + 
            ' WHERE PD.StorerKey = @cStorerKey ' + 
               ' AND PD.Status <= ''5'' ' + 
               ' AND PD.Status <> ''4'' ' + 
               ' AND PD.QTY > 0 ' + 
               ' AND PD.' + TRIM( @cPickDetailCartonID) + ' = @cCartonID ' + 
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
         SET @cSQLParam = 
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cCartonID   NVARCHAR( 20), ' + 
            ' @nWeight     FLOAT OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam
            ,@cStorerKey
            ,@cCartonID 
            ,@nWeight OUTPUT
         
         -- Weight (SKU + carton)  
         IF @cDefaultWeight = '3'  
         BEGIN           
            -- Get carton type info  
            DECLARE @nCartonWeight FLOAT  
            SELECT @nCartonWeight = CartonWeight  
            FROM Cartonization C WITH (NOLOCK)  
               JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)  
            WHERE S.StorerKey = @cStorerKey  
               AND C.CartonType = @cCartonType  
                 
            SET @nWeight = @nWeight + @nCartonWeight  
         END  
         SET @cWeight = rdt.rdtFormatFloat( @nWeight)  
      END  

      -- Cube
      IF @cFieldAttr03 = ''
      BEGIN
         SET @cCube = TRIM( @cCube)

         -- Check blank
         IF @cCube = ''
         BEGIN
            SET @nErrNo = 144161
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Cube', @cCube) = 0
         BEGIN
            SET @nErrNo = 144162
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowCubeZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 144163
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField03 = @cCube
      END

      DECLARE @fCube   FLOAT 
      DECLARE @fWeight FLOAT 
      SET @fCube = CAST( @cCube AS FLOAT)
      SET @fWeight = CAST( @cWeight AS FLOAT)

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_CartonPack

      -- Confirm
      EXEC rdt.rdt_CartonPack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CONFIRM', @tConfirm
         ,@cDoc1Value     = @cDoc1Value
         ,@cCartonID      = @cCartonID
         ,@cCartonSKU     = @cCartonSKU
         ,@nCartonQTY     = @nCartonQTY
         ,@cPackInfo      = @cPackInfo
         ,@cCartonType    = @cCartonType
         ,@fCube          = @fCube
         ,@fWeight        = @fWeight
         ,@cPackInfoRefNo = @cPackInfoRefNo
         ,@cPickSlipNo    = @cPickSlipNo    OUTPUT
         ,@nCartonNo      = @nCartonNo      OUTPUT
         ,@cLabelNo       = @cLabelNo       OUTPUT
         ,@cPrintPackList = @cPrintPackList OUTPUT
         ,@nErrNo         = @nErrNo         OUTPUT
         ,@cErrMsg        = @cErrMsg        OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_CartonPack
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtUpd, ' +
               ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, ' + 
               ' @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @tExtUpd        VariableTable READONLY, ' + 
               ' @cDoc1Value     NVARCHAR( 20), ' + 
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cCartonSKU     NVARCHAR( 20), ' +
               ' @nCartonQTY     INT,           ' +
               ' @cPackInfo      NVARCHAR( 4),  ' + 
               ' @cCartonType    NVARCHAR( 10), ' + 
               ' @cCube          NVARCHAR( 10), ' + 
               ' @cWeight        NVARCHAR( 10), ' + 
               ' @cPackInfoRefNo NVARCHAR( 20), ' +
               ' @cPickSlipNo    NVARCHAR( 10), ' + 
               ' @nCartonNo      INT,           ' + 
               ' @cLabelNo       NVARCHAR( 20), ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtUpd, 
               @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @cCube, @cWeight, @cPackInfoRefNo, 
               @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_CartonPack
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_CartonPack
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
         
      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo

      IF @cShipLabel <> ''
      BEGIN
         INSERT INTO @tShipLabel (Variable, Value) VALUES 
            ('@cStorerKey',   @cStorerKey), 
            ('@cPickSlipNo',  @cPickSlipNo), 
            ('@cCartonID',    @cCartonID), 
            ('@nCartonNo',    CAST( @nCartonNo AS NVARCHAR( 10))), 
            ('@cLabelNo',     @cLabelNo), 
            ('@cDoc1Value',   @cDoc1Value)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter, 
            @cShipLabel, -- Report type
            @tShipLabel, -- Report params
            'rdtfnc_CartonPack', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
         IF @nErrNo <> 0
            SET @nErrNo = 0 -- Ignore error
      END

      -- Carton manifest
      IF @cCartonManifest <> ''
      BEGIN
         -- Get session info
         SELECT 
            @cLabelPrinter = Printer,
            @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile
         
         -- Common params
         INSERT INTO @tCartonManifest (Variable, Value) VALUES 
            ('@cStorerKey',   @cStorerKey), 
            ('@cPickSlipNo',  @cPickSlipNo), 
            ('@cCartonID',    @cCartonID), 
            ('@nCartonNo',    CAST( @nCartonNo AS NVARCHAR( 10))), 
            ('@cLabelNo',     @cLabelNo), 
            ('@cDoc1Value',   @cDoc1Value)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
            @cCartonManifest, -- Report type
            @tCartonManifest, -- Report params
            'rdtfnc_CartonPack', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            SET @nErrNo = 0 -- Ignore error
      END

      IF @cPackList <> ''
      BEGIN
         -- Check pack confirm
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9') OR @cPrintPackList = 'Y'
         BEGIN
            SET @cOutField01 = '' -- Option

            SET @nScn = @nScn_PrintPackList
            SET @nStep = @nStep_PrintPackList

            GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- CartonID

      -- Go to carton ID screen
      SET @nScn = @nScn_CartonID
      SET @nStep = @nStep_CartonID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- Carton ID

      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo

      -- Go to next screen
      SET @nScn = @nScn_CartonID
      SET @nStep = @nStep_CartonID
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

      V_PickSlipNo = @cPickSlipNo,
      V_SKU        = @cCartonSKU,
      V_QTY        = @nCartonQTY, 

      V_String1  = @cCartonID,
      V_String2  = @cCartonType,
      V_String3  = @cCube,
      V_String4  = @cWeight,
      V_String5  = @cPackInfoRefNo,
      V_String6  = @cLabelNo,

      V_String10 = @cDoc1Label,
      V_String11 = @cDoc1Value,

      V_String20 = @cExtendedInfo,
      V_String21 = @cExtendedInfoSP,
      V_String22 = @cExtendedValidateSP,
	   V_String23 = @cExtendedUpdateSP,
	   V_String24 = @cDecodeSP,
      V_String25 = @cCapturePackInfoSP,
      V_String26 = @cPackInfo,  
      V_String27 = @cAllowCubeZero,
      V_String28 = @cAllowWeightZero,
      V_String29 = @cDefaultWeight,  
      V_String30 = @cPickDetailCartonID,
      V_String31 = @cShipLabel,
      V_String32 = @cCartonManifest, 
      V_String33 = @cPackList,
      V_String34 = @cDefaultCartonType,

      V_Integer1 = @nCartonNo,

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