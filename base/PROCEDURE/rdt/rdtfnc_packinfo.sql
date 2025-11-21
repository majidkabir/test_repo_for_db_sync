SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdtfnc_PackInfo                                                    */
/* Copyright      : IDS                                                                */
/* FBR: 85867                                                                          */
/* Purpose: Print carton label                                                         */
/*                                                                                     */
/* Modifications log:                                                                  */
/*                                                                                     */
/* Date         Rev  Author     Purposes                                               */
/* 11-Mar-2012  1.0  Ung        Created                                                */
/* 21-Nov-2012  1.1  ChewKP     SOS#260734 - Various enhancement                       */
/*                              (ChewKP01)                                             */
/* 06-Feb-2014  1.2  James      SOS292770 - Add orderkey (james01)                     */
/* 03-Sep-2014  1.3  ChewKP     SOS#317797 - Add RefNo Field                           */
/*                              Merge Screen 2 & 3, Add                                */
/*                              Extended Validation Config (ChewKP02)                  */
/* 29-Apr-2015  1.4  ChewKP     SOS#340365 Exceed 7 Fixes (ChewKP03)                   */
/* 26-Jun-2015  1.5  audrey     SOS345392 - missing function     (ang01)               */
/* 20-Apr-2016  1.6  Ung        SOS368362 Fix cursor position                          */
/*                              Replace HideDropIDField   with DisableLookupField      */
/*                              Replace HideOrderKeyField with DisableLookupField      */
/*                              Replace SkipPrintLabelScn with rdt.rdtReport is setup  */
/*                              Replace SkipPackinforScn  with AllPackInfoCreated      */
/*                              Remove message screen                                  */
/*                              Move carton no to 1st screen                           */ 
/*                              Populate LWH when carton type changed                  */
/*                              Clean up source                                        */
/* 01-Sep-2016  1.7   James     Bug fix on field attr (james02)                        */
/* 30-Sep-2016  1.8   Ung       Performance tuning                                     */
/* 14-Dec-2016  1.9   Ung       WMS-459 Change report param                            */
/* 22-Feb-2017  2.0   James     Initialise screen variable (james03)                   */
/* 05-Oct-2018  2.1   TungGH    Performance                                            */
/* 08-Oct-2019  2.2   Chermaine WMS-10777 Add eventlog and change rdt_BuiltPrintJob    */
/*                              to edt_print (cc01)                                    */
/* 20-JUL-2020  2.3   Chermaine WMS-14307 Add ExtendedPrintSP (cc02)                   */
/* 02-Oct-2020  2.4   Chermaine WMS-15387 get codelkup.shot=k then display onlys (cc03)*/
/* 02-Sep-2021  2.5   James     WMS-17833 Add rdtIsValidRange (james04)                */
/* 24-May-2023  2.6   Ung       WMS-22606 Fix PackInfLBL report duplicate params       */
/***************************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PackInfo](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cPackInfo      NVARCHAR( 4)

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
   @cPaperPrinter  NVARCHAR( 10), --(cc01)
   @cPrinter       NVARCHAR( 10),

   @cOrderKey      NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @nQTY           INT,

   @cDropID        NVARCHAR( 20),
   @cLabelNo       NVARCHAR( 20),
   @cCartonNo      NVARCHAR( 5),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cLength        NVARCHAR( 10),
   @cWidth         NVARCHAR( 10),
   @cHeight        NVARCHAR( 10),   
   @cRefNo         NVARCHAR( 20),
   @nSKUCount      INT,
   @nCartonCnt     INT,
   @nTotalCarton   INT,

   @cExtendedValidateSP  NVARCHAR( 20),
   @cExtendedUpdateSP    NVARCHAR( 20),
   @cCapturePackInfoSP   NVARCHAR( 20),
   @cPromptAllPackInfoCreated  NVARCHAR( 1),
   @cDisableEditPackInfo NVARCHAR( 1),
   @cDisableLookupField  NVARCHAR( 10), 
   @cDefaultCursor       NVARCHAR( 1),
   @cExtendedPrintSP     NVARCHAR( 20), --(cc02)
   @cShort               NVARCHAR( 10),

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
   @cPaperPrinter    = Printer_Paper, --(cc01)
   @cPrinter         = Printer,

   @cOrderKey        = V_OrderKey,
   @cPickSlipNo      = V_PickSlipNo,
   @nQTY             = V_QTY,

   @cDropID          = V_String1,
   @cLabelNo         = V_String2,
   @cCartonNo        = V_String3,
   @cCartonType      = V_String4,
   @cCube            = V_String5,
   @cWeight          = V_String6,
   @cLength          = V_String7,
   @cWidth           = V_String8,
   @cHeight          = V_String9,
   @cRefNo           = V_String10,
   
   @nSKUCount        = V_Integer1,
   @nCartonCnt       = V_Integer2,
   @nTotalCarton     = V_Integer3,

   @cExtendedValidateSP       = V_String21,
   @cExtendedUpdateSP         = V_String22,
   @cCapturePackInfoSP        = V_String23,
   @cPromptAllPackInfoCreated = V_String25,
   @cDisableEditPackInfo      = V_String26,
   @cDisableLookupField       = V_String27,
   @cDefaultCursor            = V_String28,
   @cExtendedPrintSP          = V_String29, --(cc02)

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

IF @nFunc = 921
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 921
   IF @nStep = 1  GOTO Step_1  -- Scn = 3030. DropID, LabelNo, OrderKey
   IF @nStep = 2  GOTO Step_2  -- Scn = 3031. CartonType, Cube, Weight, RefNo
   IF @nStep = 3  GOTO Step_3  -- Scn = 3032. Print label?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 921
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3030
   SET @nStep = 1

   -- Storer configure
   SET @cPromptAllPackInfoCreated = rdt.RDTGetConfig( @nFunc, 'PromptAllPackInfoCreated', @cStorerKey)
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)
   SET @cDisableEditPackInfo = rdt.RDTGetConfig( @nFunc, 'DisableEditPackInfo', @cStorerKey)
   SET @cDisableLookupField = rdt.RDTGetConfig( @nFunc, 'DisableLookupField', @cStorerKey)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = 'TCWR'
   SET @cExtendedPrintSP = rdt.RDTGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)   --(cc02)
   IF @cExtendedPrintSP = '0'
      SET @cExtendedPrintSP = ''
      
   -- Prepare next screen var
   SET @cOutField01 = '' -- DropID
   SET @cOutField02 = '' -- LabelNo
   SET @cOutField03 = '' -- OrderKey
   SET @cOutField04 = '' -- CartonNo
   
   -- Disable field
   SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'D', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
   SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'L', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
   SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
   SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END

   -- EventLog (cc01)
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
    	@cUserID     = @cUserName,
    	@nMobileNo   = @nMobile,
    	@nFunctionID = @nFunc,
    	@cFacility   = @cFacility,
    	@cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Scn = 3030. Scan DropID/LabelNo/OrderKey
   DropID      (field01, input)
   LabelNo     (field02, input)
   OrderKey    (field03, input)
   CartonNo    (field04, intput)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cDropID = ''
      SET @cLabelNo = ''
      SET @cOrderKey = ''
      SET @cCartonNo = ''

      -- Screen mapping
      SET @cDropID = @cInField01
      SET @cLabelNo = @cInField02
      SET @cOrderKey = @cInField03
      SET @cCartonNo = @cInField04

      -- Calc option keyed-in
      DECLARE @nCnt INT
      SET @nCnt = 0
      IF @cDropID   <> '' SET @nCnt = @nCnt + 1
      IF @cLabelNo  <> '' SET @nCnt = @nCnt + 1
      IF @cOrderKey <> '' SET @nCnt = @nCnt + 1

      -- Check all field blank
      IF @nCnt = 0
      BEGIN
         SET @nErrNo = 75351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check more then 1 field key-in
      IF @nCnt > 1
      BEGIN
         SET @nErrNo = 75352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OneOptionOnly
         GOTO Quit
      END

      -- DropID
      IF @cDropID <> ''
      BEGIN
         -- Get PickSlipNo, CartonNo
         SET @cPickSlipNo = ''
         SET @cCartonNo = ''
         SELECT TOP 1
            @cPickSlipNo = PickSlipNo,
            @cCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cDropID
         ORDER BY PickSlipNo DESC -- (ChewKP02)

         -- Check valid DropID
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 75353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- DropID
            GOTO Quit
         END

         -- Get SKU count
         SELECT
            @nSKUCount = COUNT( DISTINCT SKU),
            @nQTY = SUM( QTY)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND DropID = @cDropID
      END

      -- LabelNo
      IF @cLabelNo <> ''
      BEGIN
         -- Get PickSlipNo, CartonNo
         SET @cPickSlipNo = ''
         SET @cCartonNo = ''
         SELECT TOP 1
            @cPickSlipNo = PickslipNo,
            @cCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cLabelNo
         ORDER BY PickSlipNo DESC -- (ChewKP02)

         -- Check valid LabelNo
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 75354
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LABEL NO
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = '' -- LabelNo
            GOTO Quit
         END

         -- Get SKU count
         SELECT
            @nSKUCount = COUNT( DISTINCT SKU),
            @nQTY = SUM( QTY)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cLabelNo
      END

      -- OrderKey
      IF @cOrderKey <> ''
      BEGIN
         -- Get PickSlipNo
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey

         -- Check valid OrderKey
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 75355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV ORDERKEY
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = '' -- OrderKey
            GOTO Quit
         END
         SET @cOutField03 = @cOrderKey

         -- Check carton blank
         IF @cCartonNo = ''
         BEGIN
            SET @nErrNo = 75356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CARTON NO REQ
            EXEC rdt.rdtSetFocusField @nMobile, 4
            SET @cOutField04 = '' -- CartonNo
            GOTO Quit
         END

         -- Check carton valid
         IF RDT.rdtIsValidQTY( @cCartonNo, 1) = 0
         BEGIN
            SET @nErrNo = 75357
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CARTON NO
            EXEC rdt.rdtSetFocusField @nMobile, 4
            SET @cOutField04 = '' -- CartonNo
            GOTO Quit
         END

         -- Check if valid carton no
         IF NOT EXISTS ( SELECT 1
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @cCartonNo)
         BEGIN
            SET @nErrNo = 75358
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN NOT EXISTS
            EXEC rdt.rdtSetFocusField @nMobile, 4
            SET @cOutField04 = '' -- CartonNo
            GOTO Quit
         END

         -- Get SKU count
         SELECT
            @nSKUCount = COUNT( DISTINCT SKU),
            @nQTY = SUM( QTY)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @cCartonNo
      END

      -- Get PackInfo
      SET @cCartonType = ''
      SET @cWeight = ''
      SET @cCube = ''
      SET @cLength = ''
      SET @cWidth = ''
      SET @cHeight = ''
      SET @cRefNo = ''
      SELECT
         @cCartonType = CartonType,
         @cWeight = rdt.rdtFormatFloat( Weight),
         @cCube = rdt.rdtFormatFloat( Cube),
         @cLength = rdt.rdtFormatFloat( Length),
         @cWidth = rdt.rdtFormatFloat( Width),
         @cHeight = rdt.rdtFormatFloat( Height),
         @cRefNo = RefNo
      FROM dbo.PackInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo  = @cCartonNo

      -- Check edit PackInfo
      IF @@ROWCOUNT = 1
      BEGIN
         IF @cDisableEditPackInfo = '1'
         BEGIN
            SET @nErrNo = 75359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackInfoExist
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@nInputKey      INT,           ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLabelNo       NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cCartonNo      NVARCHAR( 5),  ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@cCartonType    NVARCHAR( 10), ' +
               '@cCube          NVARCHAR( 10), ' +
               '@cWeight        NVARCHAR( 10), ' +
               '@cLength        NVARCHAR( 10), ' +
               '@cWidth         NVARCHAR( 10), ' +
               '@cHeight        NVARCHAR( 10), ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

      -- Get total carton
      SELECT @nCartonCnt = COUNT(1) FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nTotalCarton = COUNT( DISTINCT LabelNo) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickSlipNo

      -- Prepare next screen var
      SET @cOutField01 = CASE
                           WHEN @cDropID <> '' THEN @cDropID
                           WHEN @cLabelNo <> '' THEN @cLabelNo
                           WHEN @cOrderKey <> '' THEN @cOrderKey
                           ELSE ''
                         END
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cCartonNo
      SET @cOutField04 = CAST( @nSKUCount AS NVARCHAR( 5)) + '-' + CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField05 = CAST( @nCartonCnt AS NVARCHAR( 5)) + '/' + CAST( @nTotalCarton AS NVARCHAR( 5))
      SET @cOutField06 = @cCartonType
      SET @cOutField07 = @cCube
      SET @cOutField08 = @cWeight
      SET @cOutField09 = @cLength
      SET @cOutField10 = @cWidth
      SET @cOutField11 = @cHeight
      SET @cOutField12 = @cRefNo

      -- Enable field
      SET @cFieldAttr01 = '' -- DropID
      SET @cFieldAttr02 = '' -- LabelNo
      SET @cFieldAttr03 = '' -- OrderKey
      SET @cFieldAttr04 = '' -- CartonNo
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'CartonType') SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Cube'      ) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O'
      --IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'    ) SET @cFieldAttr08 = '' ELSE SET @cFieldAttr08 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Length'    ) SET @cFieldAttr09 = '' ELSE SET @cFieldAttr09 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Width'     ) SET @cFieldAttr10 = '' ELSE SET @cFieldAttr10 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Height'    ) SET @cFieldAttr11 = '' ELSE SET @cFieldAttr11 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'RefNo'     ) SET @cFieldAttr12 = '' ELSE SET @cFieldAttr12 = 'O'

      --(cc03)
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'    ) 
      BEGIN
      	SET @cFieldAttr08 = ''
     	
      	SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'
      	
      	IF @cWeight <> '' AND CHARINDEX( 'K', @cShort) > 0  -- K=Keep
      	BEGIN
      		SET @cFieldAttr08 = 'O'
      		SET @cOutField08 = @cWeight
      	END
      END
      ELSE
      BEGIN
      	SET @cFieldAttr08 = 'O'
      END

      -- Position cursor
      IF @cDefaultCursor <> '' EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor        ELSE
      IF @cFieldAttr06 = '' AND @cOutField06 = 'O' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
      IF @cFieldAttr07 = '' AND @cOutField07 = 'O' EXEC rdt.rdtSetFocusField @nMobile, 7  ELSE
      IF @cFieldAttr08 = '' AND @cOutField08 = '0' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
      IF @cFieldAttr09 = '' AND @cOutField09 = '0' EXEC rdt.rdtSetFocusField @nMobile, 9  ELSE
      IF @cFieldAttr10 = '' AND @cOutField10 = '0' EXEC rdt.rdtSetFocusField @nMobile, 10 ELSE
      IF @cFieldAttr11 = '' AND @cOutField11 = '0' EXEC rdt.rdtSetFocusField @nMobile, 11 ELSE
      IF @cFieldAttr12 = '' AND @cOutField12 = '0' EXEC rdt.rdtSetFocusField @nMobile, 12 

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
    
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cFieldAttr01 = '' -- DropID
      SET @cFieldAttr02 = '' -- LabelNo
      SET @cFieldAttr03 = '' -- OrderKey
      SET @cFieldAttr04 = '' -- CartonNo
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
      
      -- EventLog (cc01)
      EXEC RDT.rdt_STD_EventLog
      	@cActionType = '9', -- Sign-out
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey

         
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Scn = 3031. PackInfo screen
   Drop/Label/Order  (field01)
   Pickslip No (field02)
   Carton no   (field03)
   SKU-QTY     (field04)
   Scan/Total  (field05)
   Carton Type (field06, input)
   Cube        (field07, input)
   Weight      (field08, input)
   Lenght      (field09, input)
   Width       (field10, input)
   Height      (field11, input)
   RefNo       (field12, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)

      -- Screen mapping
      SET @cChkCartonType  = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cCube           = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END
      SET @cWeight         = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cLength         = CASE WHEN @cFieldAttr09 = '' THEN @cInField09 ELSE @cOutField09 END
      SET @cWidth          = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END
      SET @cHeight         = CASE WHEN @cFieldAttr11 = '' THEN @cInField11 ELSE @cOutField11 END
      SET @cRefNo          = CASE WHEN @cFieldAttr12 = '' THEN @cInField12 ELSE @cOutField12 END

      -- Carton type
      IF @cFieldAttr06 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'CartonType'

         -- Check blank
         IF @cChkCartonType = '' AND CHARINDEX( 'R', @cShort) > 0
         BEGIN
            SET @nErrNo = 75360
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END
         
         -- Check valid
         IF @cChkCartonType <> ''
         BEGIN
            -- Get default
            DECLARE @nDefaultCube   FLOAT
            DECLARE @nDefaultLength FLOAT
            DECLARE @nDefaultWidth  FLOAT
            DECLARE @nDefaultHeight FLOAT
            SELECT 
               @nDefaultCube = Cube, 
               @nDefaultLength = ISNULL( CartonLength, 0), 
               @nDefaultWidth = ISNULL( CartonWidth, 0), 
               @nDefaultHeight = ISNULL( CartonHeight, 0)
            FROM Cartonization WITH (NOLOCK)
               INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
            WHERE Storer.StorerKey = @cStorerKey
               AND Cartonization.CartonType = @cChkCartonType
   
            -- Check if valid
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 75361
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE
               EXEC rdt.rdtSetFocusField @nMobile, 6
               GOTO Quit
            END

            -- Different carton type scanned
            IF @cChkCartonType <> @cCartonType
            BEGIN
               SET @cCartonType = @cChkCartonType
               SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)
               
               --(cc03)
               SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'
               IF NOT (@cWeight <> '' AND CHARINDEX( 'K', @cShort) > 0 ) -- K=Keep
               BEGIN
               	SET @cWeight = ''
               END
               
               SET @cLength = rdt.rdtFormatFloat( @nDefaultLength)
               SET @cWidth = rdt.rdtFormatFloat( @nDefaultWidth)
               SET @cHeight = rdt.rdtFormatFloat( @nDefaultHeight)
   
               SET @cOutField06 = @cChkCartonType
               SET @cOutField07 = @cCube
               SET @cOutField08 = @cWeight
               SET @cOutField09 = @cLength
               SET @cOutField10 = @cWidth
               SET @cOutField11 = @cHeight
            END
         END
         SET @cCartonType = @cChkCartonType
      END

      -- Cube
      IF @cFieldAttr07 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Cube'

         -- Check blank
         IF @cCube = '' AND CHARINDEX( 'R', @cShort) > 0  -- R=Required
         BEGIN
            SET @nErrNo = 75362
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Quit
         END
   
         -- Check cube valid
         IF @cCube <> ''
         BEGIN 
            IF CHARINDEX( 'Z', @cShort) > 0 -- Z=Allow zero
               SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20) -- Not check zero
            ELSE
               SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)
   
            IF @nErrNo = 0
            BEGIN
               SET @nErrNo = 75363
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
               EXEC rdt.rdtSetFocusField @nMobile, 7
               SET @cOutField07 = ''
               GOTO QUIT
            END
            SET @nErrNo = 0

            -- Check valid cube range  
            IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'CUBE', 'FLOAT', @cCube) = 0  
            BEGIN  
               SET @nErrNo = 75379
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
               EXEC rdt.rdtSetFocusField @nMobile, 7
               SET @cOutField07 = ''
               GOTO QUIT
            END
            SET @cOutField07 = @cCube
         END
      END
      
      -- Weight
      IF @cFieldAttr08 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'

         -- Check blank
         IF @cWeight = '' AND CHARINDEX( 'R', @cShort) > 0  -- R=Required
         BEGIN
            SET @nErrNo = 75364
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Quit
         END
         
         -- Check weight valid
         IF @cWeight <> ''
         BEGIN
            IF CHARINDEX( 'Z', @cShort) = 0
               SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)
            ELSE
               SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)
   
            IF @nErrNo = 0
            BEGIN
               SET @nErrNo = 75365
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
               EXEC rdt.rdtSetFocusField @nMobile, 8
               SET @cOutField08 = ''
               GOTO QUIT
            END
            SET @nErrNo = 0

            -- Check valid weight range  
            IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'WEIGHT', 'FLOAT', @cWeight) = 0  
            BEGIN  
               SET @nErrNo = 75380
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
               EXEC rdt.rdtSetFocusField @nMobile, 8
               SET @cOutField08 = ''
               GOTO QUIT
            END
         END
         SET @cOutField08 = @cWeight
      END

      -- Length
      IF @cFieldAttr09 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Length'

         -- Check blank
         IF @cLength = '' AND CHARINDEX( 'R', @cShort) > 0  -- R=Required
         BEGIN
            SET @nErrNo = 75366
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Length
            EXEC rdt.rdtSetFocusField @nMobile, 9
            GOTO Quit
         END
   
         -- Check length valid
         IF @cLength <> ''
         BEGIN
            IF CHARINDEX( 'Z', @cShort) = 0
               SET @nErrNo = rdt.rdtIsValidQty( @cLength, 21)
            ELSE
               SET @nErrNo = rdt.rdtIsValidQty( @cLength, 20)
   
            IF @nErrNo = 0
            BEGIN
               SET @nErrNo = 75367
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length
               EXEC rdt.rdtSetFocusField @nMobile, 9
               SET @cOutField09 = ''
               GOTO QUIT
            END
            SET @nErrNo = 0

            -- Check valid length range  
            IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'LENGTH', 'FLOAT', @cLength) = 0  
            BEGIN  
               SET @nErrNo = 75381
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
               EXEC rdt.rdtSetFocusField @nMobile, 9
               SET @cOutField09 = ''
               GOTO QUIT
            END
         END
         SET @cOutField09 = @cLength
      END

      -- Width
      IF @cFieldAttr10 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Width'

         -- Check blank
         IF @cWidth = '' AND CHARINDEX( 'R', @cShort) > 0  -- R=Required
         BEGIN
            SET @nErrNo = 75368
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Width
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Quit
         END
   
         -- Check width valid
         IF @cWidth <> ''
         BEGIN
            IF CHARINDEX( 'Z', @cShort) = 0
               SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 21)
            ELSE
               SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 20)
   
            IF @nErrNo = 0
            BEGIN
               SET @nErrNo = 75369
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid width
               EXEC rdt.rdtSetFocusField @nMobile, 10
               SET @cOutField10 = ''
               GOTO QUIT
            END
            SET @nErrNo = 0

            -- Check valid width range  
            IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'WIDTH', 'FLOAT', @cWidth) = 0  
            BEGIN  
               SET @nErrNo = 75382
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
               EXEC rdt.rdtSetFocusField @nMobile, 10
               SET @cOutField10 = ''
               GOTO QUIT
            END
         END
         SET @cOutField10 = @cWidth
      END

      -- Height
      IF @cFieldAttr11 = ''
      BEGIN
         -- Get checking flag
         SELECT @cShort = ISNULL( Short, '') FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Height'

         -- Check blank
         IF @cHeight = '' AND CHARINDEX( 'R', @cShort) > 0  -- R=Required
         BEGIN
            SET @nErrNo = 75370
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height
            EXEC rdt.rdtSetFocusField @nMobile, 11
            GOTO Quit
         END
                  
         -- Check height valid
         IF @cHeight <> ''
         BEGIN
            IF CHARINDEX( 'Z', @cShort) = 0
               SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 21)
            ELSE
               SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 20)
   
            IF @nErrNo = 0
            BEGIN
               SET @nErrNo = 75371
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid height
               EXEC rdt.rdtSetFocusField @nMobile, 11
               SET @cOutField11 = ''
               GOTO QUIT
            END
            SET @nErrNo = 0

            -- Check valid height range  
            IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'HEIGHT', 'FLOAT', @cHeight) = 0  
            BEGIN  
               SET @nErrNo = 75383
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
               EXEC rdt.rdtSetFocusField @nMobile, 11
               SET @cOutField11 = ''
               GOTO QUIT
            END
         END
         SET @cOutField11 = @cHeight
      END


      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@nInputKey      INT,           ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLabelNo       NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cCartonNo      NVARCHAR( 5),  ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@cCartonType    NVARCHAR( 10), ' +
               '@cCube          NVARCHAR( 10), ' +
               '@cWeight        NVARCHAR( 10), ' +
               '@cLength        NVARCHAR( 10), ' +
               '@cWidth         NVARCHAR( 10), ' +
               '@cHeight        NVARCHAR( 10), ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

      DECLARE @fCube FLOAT
      DECLARE @fWeight FLOAT
      DECLARE @fLength FLOAT
      DECLARE @fWidth FLOAT
      DECLARE @fHeight FLOAT
         
 
      SET @fCube = CAST( @cCube AS FLOAT)
      SET @fWeight = CAST( @cWeight AS FLOAT)
      SET @fLength = CAST( @cLength AS FLOAT)
      SET @fWidth = CAST( @cWidth AS FLOAT)
      SET @fHeight = CAST( @cHeight AS FLOAT)

      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @cCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, Length, Width, Height, CartonType, RefNo)
         VALUES (@cPickSlipNo, @cCartonNo, @nQTY, @fWeight, @fCube, @fLength, @fWidth, @fHeight, @cCartonType, @cRefNo)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 75372
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            CartonType = @cCartonType,
            Weight = @fWeight,
            Cube = @fCube,
            Length = @fLength,
            Width = @fWidth,
            Height = @fHeight,
            RefNo = @cRefNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @cCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 75373
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
               ' @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@nInputKey      INT,           ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLabelNo       NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cCartonNo      NVARCHAR( 5),  ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@cCartonType    NVARCHAR( 10), ' +
               '@cCube          NVARCHAR( 10), ' +
               '@cWeight        NVARCHAR( 10), ' +
               '@cLength        NVARCHAR( 10), ' +
               '@cWidth         NVARCHAR( 10), ' +
               '@cHeight        NVARCHAR( 10), ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
               @cDropID, @cLabelNo, @cOrderKey, @cCartonNo, @cPickSlipNo, @cCartonType, @cCube, @cWeight, @cLength, @cWidth, @cHeight, @cRefNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

      -- All PackInfo record created
      IF @cPromptAllPackInfoCreated = '1'
      BEGIN
         -- Get total carton
         SELECT @nCartonCnt = COUNT(1) FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
         SELECT @nTotalCarton = COUNT( DISTINCT LabelNo) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickSlipNo

         IF @nCartonCnt = @nTotalCarton
         BEGIN
            DECLARE @cErrMsg1 NVARCHAR(20)
            SET @nErrNo = 75374
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ALL Packinfo created
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         END
      END

      -- Pack info label setup
      IF EXISTS( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReportType = 'PackInfLBL')
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Enable field
         SET @cFieldAttr06 = '' -- Carton type
         SET @cFieldAttr07 = '' -- Cube
         SET @cFieldAttr08 = '' -- Weight
         SET @cFieldAttr09 = '' -- Length
         SET @cFieldAttr10 = '' -- Width
         SET @cFieldAttr11 = '' -- Height
         SET @cFieldAttr12 = '' -- RefNo

         -- Go to print label screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      --Event Log (cc01)
      EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '3',     
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerkey,    
         @cLabelNo 		= @cLabelNo,
         @cCartonType	= @cCartonType,
         @fWeight			= @fWeight,
         @fLength       = @fLength,
         @fWidth			= @fWidth,
         @fHeight			= @fHeight

      -- Prepare prev screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutfield02 = '' -- LabelNo
      SET @cOutfield03 = '' -- OrderKey
      SET @cOutField04 = '' -- CartonNo

      -- (james03)
      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField03 = ''
      SET @cInField04 = ''
      SET @cInField05 = ''
      SET @cInField06 = ''
      SET @cInField07 = ''
      SET @cInField08 = ''
      SET @cInField09 = ''
      SET @cInField10 = ''
      SET @cInField11 = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @cInField14 = ''
      SET @cInField15 = ''

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

      -- Disable field
      SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'D', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'L', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END

			-- (james02)
      --SET @cInField01 = CASE WHEN @cFieldAttr01 = 'O' THEN '' ELSE @cInField01 END
      --SET @cInField02 = CASE WHEN @cFieldAttr02 = 'O' THEN '' ELSE @cInField02 END
      --SET @cInField03 = CASE WHEN @cFieldAttr03 = 'O' THEN '' ELSE @cInField03 END
      --SET @cInField04 = CASE WHEN @cFieldAttr04 = 'O' THEN '' ELSE @cInField04 END

      -- Position cursor
      IF @cDropID   <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cLabelNo  <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cOrderKey <> '' EXEC rdt.rdtSetFocusField @nMobile, 3

      -- Back to Drop/Label/Order screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutfield02 = '' -- LabelNo
      SET @cOutfield03 = '' -- OrderKey
      SET @cOutField04 = '' -- CartonNo
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = ''
      SET @cOutField14 = ''
      SET @cOutField15 = ''

      -- (james03)
      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField03 = ''
      SET @cInField04 = ''
      SET @cInField05 = ''
      SET @cInField06 = ''
      SET @cInField07 = ''
      SET @cInField08 = ''
      SET @cInField09 = ''
      SET @cInField10 = ''
      SET @cInField11 = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @cInField14 = ''
      SET @cInField15 = ''

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = '' -- Carton type
      SET @cFieldAttr07 = '' -- Cube
      SET @cFieldAttr08 = '' -- Weight
      SET @cFieldAttr09 = '' -- Length
      SET @cFieldAttr10 = '' -- Width
      SET @cFieldAttr11 = '' -- Height
      SET @cFieldAttr12 = '' -- RefNo
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      -- Disable field
      SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'D', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'L', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END  
  
      -- Enable field
      --SET @cFieldAttr06 = '' -- Carton type
      --SET @cFieldAttr07 = '' -- Cube
      --SET @cFieldAttr08 = '' -- Weight
      --SET @cFieldAttr09 = '' -- Length
      --SET @cFieldAttr10 = '' -- Width
      --SET @cFieldAttr11 = '' -- Height
      --SET @cFieldAttr12 = '' -- RefNo

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      
      -- Position cursor
      IF @cDropID   <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cLabelNo  <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cOrderKey <> '' EXEC rdt.rdtSetFocusField @nMobile, 3
   END
END
GOTO Quit


/********************************************************************************
Scn = 3033. Print label screen
   PRINT LABEL?
   1 = YES
   2 = NO
   OPTION (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 75375
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
      	--(cc02)
         IF @cExtendedPrintSP <> ''
         BEGIN
            DECLARE @cSQL1       NVARCHAR(MAX)
            DECLARE @cSQLParam1  NVARCHAR(MAX)
               
            -- Execute label/report stored procedure   
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedPrintSP AND type = 'P')  
            BEGIN    
         	   SET @cSQL1 = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +  
                  ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam1 =  
                  '@nMobile    INT,           ' +  
                  '@nFunc      INT,           ' +  
                  '@nStep      INT,           ' +   
                  '@cLangCode  NVARCHAR( 3),  ' +  
                  '@cStorerKey NVARCHAR( 15), ' +   
                  '@cOption    NVARCHAR( 1),  ' +  
                  '@cParam1    NVARCHAR(60),  ' + --(ChewKP03)  
                  '@cParam2    NVARCHAR(60),  ' + --(ChewKP03)  
                  '@cParam3    NVARCHAR(60),  ' + --(ChewKP03)  
                  '@cParam4    NVARCHAR(60),  ' + --(ChewKP03)  
                  '@cParam5    NVARCHAR(60),  ' + --(ChewKP03)  
                  '@nErrNo     INT OUTPUT,    ' +  
                  '@cErrMsg    NVARCHAR( 20) OUTPUT'  
  
               EXEC sp_ExecuteSQL @cSQL1, @cSQLParam1,  
                  @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, '2', @cDropID, '', '', '', '',   
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
            END
               IF @nErrNo <> 0  
               GOTO Quit  
         END
         ELSE
         BEGIN
            -- Check login printer
            IF @cPrinter = ''
            BEGIN
               SET @nErrNo = 75376
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
               GOTO Quit
            END
            
            -- Get report info
            DECLARE @cDataWindow NVARCHAR( 50)
            DECLARE @cTargetDB   NVARCHAR( 20)
            SELECT
               @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
               @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ReportType = 'PackInfLBL'

            -- Check data window
            IF ISNULL( @cDataWindow, '') = ''
            BEGIN
               SET @nErrNo = 75377
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
               GOTO Quit
            END

            -- Check database
            IF ISNULL( @cTargetDB, '') = ''
            BEGIN
               SET @nErrNo = 75378
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
               GOTO Quit
            END

            -- Print carton label
            --EXEC RDT.rdt_BuiltPrintJob
            --   @nMobile,
            --   @cStorerKey,
            --   'PackInfLBL',       -- ReportType
            --   'PRINT_PackInfLBL', -- PrintJobName
            --   @cDataWindow,
            --   @cPrinter,
            --   @cTargetDB,
            --   @cLangCode,
            --   @nErrNo  OUTPUT,
            --   @cErrMsg OUTPUT,
            --   @cStorerKey, 
            --   @cPickSlipNo,
            --   @cCartonNo,
            --   @cCartonNo

            DECLARE @tShipLabel AS VariableTable
            INSERT INTO @tShipLabel (Variable, Value) VALUES 
               ( '@cStorerKey',  @cStorerKey), 
               ( '@cPickSlipNo', @cPickSlipNo), 
               ( '@nCartonNo',   CAST( @cCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinter, @cPaperPrinter, 
               'PackInfLBL', -- Report type
               @tShipLabel, -- Report params
               'rdtfnc_PackInfo', --source type
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare prev screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutfield02 = '' -- LabelNo
      SET @cOutfield03 = '' -- OrderKey
      SET @cOutField04 = '' -- CartonNo

      -- (james03)
      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField03 = ''
      SET @cInField04 = ''
      SET @cInField05 = ''
      SET @cInField06 = ''
      SET @cInField07 = ''
      SET @cInField08 = ''
      SET @cInField09 = ''
      SET @cInField10 = ''
      SET @cInField11 = ''
      SET @cInField12 = ''
      SET @cInField13 = ''
      SET @cInField14 = ''
      SET @cInField15 = ''

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

      -- Disable field
      SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'D', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'L', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'O', @cDisableLookupField) > 0 THEN 'O' ELSE '' END

			-- (james02)
      --SET @cInField01 = CASE WHEN @cFieldAttr01 = 'O' THEN '' ELSE @cInField01 END
      --SET @cInField02 = CASE WHEN @cFieldAttr02 = 'O' THEN '' ELSE @cInField02 END
      --SET @cInField03 = CASE WHEN @cFieldAttr03 = 'O' THEN '' ELSE @cInField03 END
      --SET @cInField04 = CASE WHEN @cFieldAttr04 = 'O' THEN '' ELSE @cInField04 END

      -- Position cursor
      IF @cDropID   <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cLabelNo  <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cOrderKey <> '' EXEC rdt.rdtSetFocusField @nMobile, 3

      --Event log (cc01)
      EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '3',     
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerkey,    
         @cLabelNo 		= @cLabelNo,
         @cCartonType	= @cCartonType,
         @fWeight			= @cWeight,
         @fLength       = @cLength,
         @fWidth			= @cWidth,
         @fHeight			= @cHeight,
         @cOption		 	= @cOption

      -- Back to Drop/Label/Order screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = CASE
                           WHEN @cDropID <> '' THEN @cDropID
                           WHEN @cLabelNo <> '' THEN @cLabelNo
                           WHEN @cOrderKey <> '' THEN @cOrderKey
                           ELSE ''
                         END
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cCartonNo
      SET @cOutField04 = CAST( @nSKUCount AS NVARCHAR( 5)) + '-' + CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField05 = CAST( @nCartonCnt AS NVARCHAR( 5)) + '/' + CAST( @nTotalCarton AS NVARCHAR( 5))
      SET @cOutField06 = @cCartonType
      SET @cOutField07 = @cCube
      SET @cOutField08 = @cWeight
      SET @cOutField09 = @cLength
      SET @cOutField10 = @cWidth
      SET @cOutField11 = @cHeight
      SET @cOutField12 = @cRefNo

      -- Enable field
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'CartonType') SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Cube'      ) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Weight'    ) SET @cFieldAttr08 = '' ELSE SET @cFieldAttr08 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Length'    ) SET @cFieldAttr09 = '' ELSE SET @cFieldAttr09 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Width'     ) SET @cFieldAttr10 = '' ELSE SET @cFieldAttr10 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'Height'    ) SET @cFieldAttr11 = '' ELSE SET @cFieldAttr11 = 'O'
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'PackInfo' AND StorerKey = @cStorerKey AND Code = 'RefNo'     ) SET @cFieldAttr12 = '' ELSE SET @cFieldAttr12 = 'O'

/*
      -- Position cursor
      IF @cFieldAttr07 = '' EXEC rdt.rdtSetFocusField @nMobile, 7 ELSE
      IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
      IF @cFieldAttr09 = '' EXEC rdt.rdtSetFocusField @nMobile, 9 ELSE
      IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
*/
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer_Paper  = @cPaperPrinter, --(cc01)
      Printer      = @cPrinter,

      V_OrderKey   = @cOrderKey,
      V_PickSlipNo = @cPickSlipNo,
      V_QTY        = @nQTY,

      V_String1    = @cDropID, 
      V_String2    = @cLabelNo, 
      V_String3    = @cCartonNo, 
      V_String4    = @cCartonType, 
      V_String5    = @cCube, 
      V_String6    = @cWeight, 
      V_String7    = @cLength,
      V_String8    = @cWidth,
      V_String9    = @cHeight,
      V_String10   = @cRefNo,
       
      V_Integer1   = @nSKUCount, 
      V_Integer2   = @nCartonCnt,
      V_Integer3   = @nTotalCarton,

      V_String21   = @cExtendedValidateSP, 
      V_String22   = @cExtendedUpdateSP, 
      V_String23   = @cCapturePackInfoSP, 
      V_String25   = @cPromptAllPackInfoCreated, 
      V_String26   = @cDisableEditPackInfo, 
      V_String27   = @cDisableLookupField, 
      V_String28   = @cDefaultCursor,
      V_String29   = @cExtendedPrintSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15  = @cFieldAttr15
   WHERE Mobile = @nMobile
END

GO