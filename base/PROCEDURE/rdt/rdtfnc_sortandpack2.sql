SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdtfnc_SortAndPack2                                 */    
/* Copyright      : LFL                                                 */    
/*                                                                      */    
/* Purpose: Sort, then pick and pack                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-05-25 1.0  James    WMS5163 - Created                           */    
/* 2018-10-11 1.1  TungGH   Performance                                 */
/* 2021-12-31 1.2  YeeKung  WMS-18493 add pass through (yeekung01)      */
/************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_SortAndPack2] (    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max    
) AS    
    
SET NOCOUNT ON    
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE 
   @b_Success     INT,     
   @cExtendedInfo NVARCHAR(20),    
   @cSQL          NVARCHAR(1000),     
   @cSQLParam     NVARCHAR(1000)    
    
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
   @cUserName           NVARCHAR(18),    
   @cPrinter            NVARCHAR(10),    
    
   @cLoadKey            NVARCHAR( 10),    
   @cSKU                NVARCHAR( 20),    
   @cSKUDescr           NVARCHAR( 60),    
   @cConsigneeKey       NVARCHAR( 15),    
   @cOrderKey           NVARCHAR( 10),     
   @cLabelNo            NVARCHAR( 20),    
   @nExpQTY             INT,    
   @nPCKQty             INT,
   @nTranCount          INT, 
   @nCartonNo           INT, 

   @cDefaultQTY         NVARCHAR( 5),     
   @cDefaultToEXPQTY    NVARCHAR( 1),     
   @cDefaultCartonType  NVARCHAR(10), 
   @cCartonType         NVARCHAR(10), 
   @cExtendedInfo1      NVARCHAR( 20),
   @cExtendedInfo2      NVARCHAR(20),     
   @cExtendedUpdateSP   NVARCHAR(20),  
   @cExtendedValidateSP NVARCHAR(20),  
   @cExtendedInfoSP     NVARCHAR(20),     
   @nQTY                      INT,     
   @cDecodeLabelNo            NVARCHAR( 20),
   @cPassThroughStep1   NVARCHAR(20),      

   @cRetainParm1Value   NVARCHAR( 1),
   @cRetainParm2Value   NVARCHAR( 1),
   @cRetainParm3Value   NVARCHAR( 1),
   @cRetainParm4Value   NVARCHAR( 1),
   @cRetainParm5Value   NVARCHAR( 1),

   @cParam1    NVARCHAR( 20), @cParamLabel1 NVARCHAR( 20),
   @cParam2    NVARCHAR( 20), @cParamLabel2 NVARCHAR( 20),
   @cParam3    NVARCHAR( 20), @cParamLabel3 NVARCHAR( 20),
   @cParam4    NVARCHAR( 20), @cParamLabel4 NVARCHAR( 20),
   @cParam5    NVARCHAR( 20), @cParamLabel5 NVARCHAR( 20),

   @c_oFieled01 NVARCHAR( 20), @c_oFieled02 NVARCHAR( 20),
   @c_oFieled03 NVARCHAR( 20), @c_oFieled04 NVARCHAR( 20),
   @c_oFieled05 NVARCHAR( 20), @c_oFieled06 NVARCHAR( 20),
   @c_oFieled07 NVARCHAR( 20), @c_oFieled08 NVARCHAR( 20),
   @c_oFieled09 NVARCHAR( 20), @c_oFieled10 NVARCHAR( 20),
   @c_oFieled11 NVARCHAR( 20), @c_oFieled12 NVARCHAR( 20),
   @c_oFieled13 NVARCHAR( 20), @c_oFieled14 NVARCHAR( 20),
   @c_oFieled15 NVARCHAR( 20),

   @c_ExecStatements          NVARCHAR(4000),
   @c_ExecArguments           NVARCHAR(4000),

   @cGetTaskSP                NVARCHAR(20),
   @cConfirmTaskSP            NVARCHAR(20),
   @cSortnPackSearchCriteria  NVARCHAR( 20),

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
    
-- Load RDT.RDTMobRec    
SELECT    
   @nFunc       = Func,    
   @nScn        = Scn,    
   @nStep       = Step,    
   @nInputKey   = InputKey,    
   @nMenu       = Menu,    
   @cLangCode   = Lang_code,    
    
   @cStorerKey  = StorerKey,    
   @cFacility   = Facility,    
   @cUserName   = UserName,    
   @cPrinter    = Printer,    
    
   @cLoadKey         = V_LoadKey,    
   @cSKU             = V_SKU,    
   @cSKUDescr        = V_SKUDescr,    
   @cConsigneeKey    = V_ConsigneeKey,    
   @cOrderKey        = V_OrderKey,     
   @cLabelNo         = V_CaseID,    
   
   @nExpQTY          = V_QTY,    
   
   @cDefaultToEXPQTY = V_String1,    
   @cDefaultQTY      = V_String2,    
   @cExtendedInfoSP  = V_String3,     
   @cConfirmTaskSP   = V_String4,     
   
   @nCartonNo           = V_Cartonno,
      
   @cGetTaskSP          = V_String5,     
   @cCartonType         = V_String7, 
   @cDefaultCartonType  = V_String8, 
   @cExtendedInfo       = V_String9, 
   @cExtendedUpdateSP   = V_String10, 
   @cExtendedValidateSP = V_String11, 
   @cExtendedInfo2      = V_String12, 
   @cGetTaskSP          = V_String13, 
   @cParam1             = V_String14,
   @cParam2             = V_String15,
   @cParam3             = V_String16,
   @cParam4             = V_String17,
   @cParam5             = V_String18,
   @cParamLabel1        = V_String19,
   @cParamLabel2        = V_String20,
   @cParamLabel3        = V_String21,
   @cParamLabel4        = V_String22,
   @cParamLabel5        = V_String23,

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
    
FROM rdt.RDTMOBREC WITH (NOLOCK)    
WHERE Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 1831
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 540    
   IF @nStep = 1 GOTO Step_1   -- Scn = 5170. LoadKey    
   IF @nStep = 2 GOTO Step_2   -- Scn = 5171. SKU    
   IF @nStep = 3 GOTO Step_3   -- Scn = 5172. QTY    
   IF @nStep = 4 GOTO Step_4   -- Scn = 5173. Label No

END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Called from menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Init variable
   SET @cParam1 = ''
   SET @cParam2 = ''
   SET @cParam3 = ''
   SET @cParam4 = ''
   SET @cParam5 = ''

   SET @cSortnPackSearchCriteria = rdt.RDTGetConfig( @nFunc, 'SortnPackSearchCriteria', @cStorerkey)
   IF @cSortnPackSearchCriteria IN ('0', '')
      SET @cSortnPackSearchCriteria = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   SET @cConfirmTaskSP = rdt.RDTGetConfig( @nFunc, 'ConfirmTaskSP', @cStorerKey)
   IF @cConfirmTaskSP = '0'
      SET @cConfirmTaskSP = ''

   SET @cGetTaskSP = rdt.RDTGetConfig( @nFunc, 'GetTaskSP', @cStorerKey)
   IF @cGetTaskSP = '0'
      SET @cGetTaskSP = ''

   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)    
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''

   SET @cDefaultToEXPQTY = rdt.RDTGetConfig( @nFunc, 'DefaultToEXPQTY', @cStorerKey)    
   IF @cDefaultToEXPQTY = '0'
      SET @cDefaultToEXPQTY = ''

   SET @cRetainParm1Value = rdt.RDTGetConfig( @nFunc, 'RetainParm1Value', @cStorerKey)
   SET @cRetainParm2Value = rdt.RDTGetConfig( @nFunc, 'RetainParm2Value', @cStorerKey)
   SET @cRetainParm3Value = rdt.RDTGetConfig( @nFunc, 'RetainParm3Value', @cStorerKey)
   SET @cRetainParm4Value = rdt.RDTGetConfig( @nFunc, 'RetainParm4Value', @cStorerKey)
   SET @cRetainParm5Value = rdt.RDTGetConfig( @nFunc, 'RetainParm5Value', @cStorerKey)

   -- Extended update
   IF @cExtendedUpdateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
            ' @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cParam1       NVARCHAR( 20),  ' +
            '@cParam2       NVARCHAR( 20),  ' +
            '@cParam3       NVARCHAR( 20),  ' +
            '@cParam4       NVARCHAR( 20),  ' +
            '@cParam5       NVARCHAR( 20),  ' +
            '@cSKU          NVARCHAR( 20),  ' +
            '@nQty          INT,            ' +
            '@cLabelNo      NVARCHAR( 20),  ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
            @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   SELECT @cParamLabel1 = UDF01,
          @cParamLabel2 = UDF02,
          @cParamLabel3 = UDF03,
          @cParamLabel4 = UDF04,
          @cParamLabel5 = UDF05
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'SEARCHFLD'
   AND   Code = @cSortnPackSearchCriteria
   AND   StorerKey = @cStorerKey
   AND   Code2 = @nFunc

   -- Check pallet criteria setup
   IF @cParamLabel1 = '' AND
      @cParamLabel2 = '' AND
      @cParamLabel3 = '' AND
      @cParamLabel4 = '' AND
      @cParamLabel5 = '' 
   BEGIN
      SET @nErrNo = 124401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
      GOTO Quit
   END

   -- Enable / disable field
   SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

   -- Clear optional in field
   SET @cInField02 = ''
   SET @cInField04 = ''
   SET @cInField06 = ''
   SET @cInField08 = ''
   SET @cInField10 = ''

   -- Prepare next screen var
   SET @cOutField01 = @cParamLabel1
   SET @cOutField02 = ''
   SET @cOutField03 = @cParamLabel2
   SET @cOutField04 = ''
   SET @cOutField05 = @cParamLabel3
   SET @cOutField06 = ''
   SET @cOutField07 = @cParamLabel4
   SET @cOutField08 = ''
   SET @cOutField09 = @cParamLabel5
   SET @cOutField10 = ''
   SET @cOutField11 = ''
   SET @cOutField12 = ''

   SET @nScn = 5170
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 2

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 5170    
   SEARCH CRITERIA   (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cParam1 = @cInField02    
      SET @cParam2 = @cInField04
      SET @cParam3 = @cInField06
      SET @cParam4 = @cInField08
      SET @cParam5 = @cInField10

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      -- Check pallet criteria setup
      IF @cParam1 = '' AND
         @cParam2 = '' AND
         @cParam3 = '' AND
         @cParam4 = '' AND
         @cParam5 = '' 
      BEGIN
         IF EXISTS ( SELECT 1 
            FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
            WHERE AddWho = @cUserName
            AND   Status < '9')
         BEGIN
            -- Prep next screen var    
            SET @cOutField01 = '' -- SKU    
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

            SET @nScn  = @nScn + 1    
            SET @nStep = @nStep + 1    

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 124402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value Required
            GOTO Step_1_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@nQty          INT,            ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@nQty          INT,            ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Extended update
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cParam1         NVARCHAR( 20),  ' +
               '@cParam2         NVARCHAR( 20),  ' +
               '@cParam3         NVARCHAR( 20),  ' +
               '@cParam4         NVARCHAR( 20),  ' +
               '@cParam5         NVARCHAR( 20),  ' +
               '@cSKU            NVARCHAR( 20),  ' +
               '@nQty            INT,            ' +
               '@cLabelNo        NVARCHAR( 20),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT
         END
      END


      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = ''
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = ''
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = ''
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = ''
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = ''
      SET @cOutField11 = @cExtendedInfo1
      SET @cOutField12 = @cExtendedInfo2

      SET @cPassThroughStep1='1'

      IF @cPassThroughStep1='1'
      BEGIN
         -- Prep next screen var    
         SET @cOutField01 = '' -- SKU    
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

         SET @nScn  = @nScn + 1    
         SET @nStep = @nStep + 1    
      END

   END    
    
   IF @nInputKey = 0 -- ESC    
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
      SET @cOutField01 = '' -- Clean up for menu option    
      
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
      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam1 ELSE '' END
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = CASE WHEN @cRetainParm2Value = '1' THEN @cParam2 ELSE '' END
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = CASE WHEN @cRetainParm3Value = '1' THEN @cParam3 ELSE '' END
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = CASE WHEN @cRetainParm4Value = '1' THEN @cParam4 ELSE '' END
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = CASE WHEN @cRetainParm5Value = '1' THEN @cParam5 ELSE '' END   
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Screen = 3231    
   SKU       
   (Field01, input)  
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cSKU = @cInField01    
    
      -- Check blank    
      IF @cSKU = '' 
      BEGIN    
         SET @nErrNo = 124403    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU    
         GOTO Step_2_Fail    
      END    

      SET @cDecodeLabelNo = ''    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    

      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('', '0')
      BEGIN    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
            @c_SPName     = @cDecodeLabelNo    
         ,@c_LabelNo    = @cSKU    
         ,@c_Storerkey  = @cStorerkey    
         ,@c_ReceiptKey = @nMobile    
         ,@c_POKey      = ''    
         ,@c_LangCode   = @cLangCode    
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
         ,@c_oFieled02  = @c_oFieled02 OUTPUT       
         ,@c_oFieled03  = @c_oFieled03 OUTPUT       
         ,@c_oFieled04  = @c_oFieled04 OUTPUT       
         ,@c_oFieled05  = @c_oFieled05 OUTPUT        
         ,@c_oFieled06  = @c_oFieled06 OUTPUT        
         ,@c_oFieled07  = @c_oFieled07 OUTPUT    
         ,@c_oFieled08  = @c_oFieled08 OUTPUT    
         ,@c_oFieled09  = @c_oFieled09 OUTPUT    
         ,@c_oFieled10  = @c_oFieled10 OUTPUT    
         ,@b_Success    = @b_Success   OUTPUT    
         ,@n_ErrNo      = @nErrNo      OUTPUT    
         ,@c_ErrMsg     = @cErrMsg     OUTPUT   
       
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            SET @cErrMsg = @cErrMsg    
            GOTO Step_2_Fail    
         END    
       
         SET @cSKU = @c_oFieled01      -- assign output to sku code
         SET @c_oFieled01 = ''         -- Reinitiase the variable
      END    

      -- Get SKU count    
      DECLARE @nSKUCnt INT    
      EXEC [RDT].[rdt_GETSKUCNT]    
            @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 124404    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_2_Fail    
      END    
       
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 124405    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
         GOTO Step_2_Fail    
      END    
       
      -- Get SKU    
      EXEC [RDT].[rdt_GETSKU]    
            @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKU          OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU    
       
      -- Get next task    
      IF @cGetTaskSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetTaskSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetTaskSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @cLabelNo, @nEXPQty OUTPUT, @nPCKQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nEXPQty       INT OUTPUT ,            ' +
               '@nPCKQty       INT OUTPUT,            ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @cLabelNo, @nEXPQty OUTPUT, @nPCKQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_2_Fail    
            END   
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@nQty          INT,            ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Extended info    
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cParam1         NVARCHAR( 20),  ' +
               '@cParam2         NVARCHAR( 20),  ' +
               '@cParam3         NVARCHAR( 20),  ' +
               '@cParam4         NVARCHAR( 20),  ' +
               '@cParam5         NVARCHAR( 20),  ' +
               '@cSKU            NVARCHAR( 20),  ' +
               '@nQty            INT,            ' +
               '@cLabelNo        NVARCHAR( 20),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT
         END
      END

      -- Prepare next screen var    
      SET @cOutField01 = @cSKU   
      SET @cOutField02 = @cSKU--''
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)    
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)    
      SET @cOutField05 = @nExpQTY
      SET @cOutField06 = CASE WHEN @cDefaultToEXPQTY = '1' THEN @nExpQTY
                              WHEN @cDefaultQTY <> '' THEN @cDefaultQTY 
                              ELSE '' END
      SET @cOutField07 = @cExtendedInfo1
      SET @cOutField08 = @cExtendedInfo2

      EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY 

      -- Go to next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1  
   END  -- IF @nInputKey = 1 -- ENTER  
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam1 ELSE '' END
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = CASE WHEN @cRetainParm2Value = '1' THEN @cParam2 ELSE '' END
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = CASE WHEN @cRetainParm3Value = '1' THEN @cParam3 ELSE '' END
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = CASE WHEN @cRetainParm4Value = '1' THEN @cParam4 ELSE '' END
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = CASE WHEN @cRetainParm5Value = '1' THEN @cParam5 ELSE '' END
      SET @cOutField11 = ''
      SET @cOutField12 = ''

      -- Go to prev screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cSKU = ''  
      SET @cOutField01 = '' --SKU    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 3. Screen 3233    
   STORE    (Field01)    
   ORDERKEY (Field02)    
   LABELNO  (Field03)    
   SKU      (Field04)    
   EXP  QTY (Field05)    
   PACK QTY (Field06, input)    
   STOR QTY (Field07)    
   ORD  QTY (Field08)    
   EXT INFO (Field09)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cActQTY NVARCHAR(5)    
      DECLARE @nActQTY INT    
      DECLARE @cActSKU NVARCHAR(20)    
          
      -- Screen mapping    
      SET @cActSKU = CASE WHEN ISNULL(@csku,'')<>'' THEN @csku ELSE @cInField02 END
      SET @cActQTY = @cInField06    



      -- Decode SKU (james08)
      SET @cDecodeLabelNo = ''    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    

      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('', '0')
      BEGIN    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
             @c_SPName     = @cDecodeLabelNo    
            ,@c_LabelNo    = @cInField04    
            ,@c_Storerkey  = @cStorerkey    
            ,@c_ReceiptKey = @nMobile    
            ,@c_POKey      = ''    
            ,@c_LangCode   = @cLangCode    
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
            ,@c_oFieled02  = @c_oFieled02 OUTPUT       
            ,@c_oFieled03  = @c_oFieled03 OUTPUT       
            ,@c_oFieled04  = @c_oFieled04 OUTPUT       
            ,@c_oFieled05  = @c_oFieled05 OUTPUT        
            ,@c_oFieled06  = @c_oFieled06 OUTPUT        
            ,@c_oFieled07  = @c_oFieled07 OUTPUT    
            ,@c_oFieled08  = @c_oFieled08 OUTPUT    
            ,@c_oFieled09  = @c_oFieled09 OUTPUT    
            ,@c_oFieled10  = @c_oFieled10 OUTPUT    
            ,@b_Success    = @b_Success   OUTPUT    
            ,@n_ErrNo      = @nErrNo      OUTPUT    
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   
       
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            SET @cErrMsg = @cErrMsg    
            GOTO Step_3_Fail    
         END    
       
         SET @cActSKU = @c_oFieled01      -- assign output to sku code
         SET @c_oFieled01 = ''         -- Reinitiase the variable
      END    

      -- Get SKU count    
      EXEC [RDT].[rdt_GETSKUCNT]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cActSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 124406    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_3_Fail    
      END    
       
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 124407    
         SET @cErrMsg =@cActSKU-- rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
         GOTO Step_3_Fail    
      END    
       
      -- Get SKU    
      EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cActSKU       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
       
      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cActSKU    

      -- Check valid QTY    
      IF rdt.rdtIsValidQty( @cActQty, 1) = 0    
      BEGIN    
         SET @nErrNo = 124408    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY    
         GOTO Step_3_Fail    
      END    

      IF @nExpQTY < CAST( @cActQTY AS INT)
      BEGIN    
         SET @nErrNo = 124409    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY
         EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY    
         GOTO Step_3_Fail    
      END

      SET @nActQTY = @cActQTY    

      -- Get confirm task    
      IF @cConfirmTaskSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmTaskSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cConfirmTaskSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @cLabelNo, @nEXPQty, @nPCKQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nEXPQty       INT,            ' +
               '@nPCKQty       INT,            ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @cLabelNo, @nEXPQty, @nActQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_3_Fail    
            END   
         END
      END

      -- Event log    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '3', -- Picking    
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerkey,    
         @cSKU          = @cSKU,    
         @nQTY          = @nActQTY,    
         @cLoadKey      = @cLoadKey,    
         --@cDropID       = @cLabelNo    
         @cLabelNo      = @cLabelNo, -- (ChewKP01)
         @nStep         = @nStep

      -- Get next task    
      IF @cGetTaskSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetTaskSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetTaskSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @cLabelNo, @nEXPQty OUTPUT, @nPCKQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nEXPQty       INT OUTPUT ,            ' +
               '@nPCKQty       INT OUTPUT,            ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @cLabelNo, @nEXPQty OUTPUT, @nPCKQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nEXPQty = 0
            BEGIN    
               -- Prep next screen var    
               SET @cOutField01 = '' -- SKU    

               SET @nScn  = @nScn - 1    
               SET @nStep = @nStep - 1    

               GOTO Quit
            END   
         END
      END

      -- Extended info    
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cParam1         NVARCHAR( 20),  ' +
               '@cParam2         NVARCHAR( 20),  ' +
               '@cParam3         NVARCHAR( 20),  ' +
               '@cParam4         NVARCHAR( 20),  ' +
               '@cParam5         NVARCHAR( 20),  ' +
               '@cSKU            NVARCHAR( 20),  ' +
               '@nQty            INT,            ' +
               '@cLabelNo        NVARCHAR( 20),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Prepare same screen var    
         SET @cOutField01 = @cSKU   
         SET @cOutField02 = ''
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)    
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)    
         SET @cOutField05 = @nExpQTY
         SET @cOutField06 = CASE WHEN @cDefaultToEXPQTY = '1' THEN @nExpQTY
                                 WHEN @cDefaultQTY <> '' THEN @cDefaultQTY 
                                 ELSE '' END
         SET @cOutField07 = @cExtendedInfo1
         SET @cOutField08 = @cExtendedInfo2
      END
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cSKU          NVARCHAR( 20),  ' +
               '@nQty          INT,            ' +
               '@cLabelNo      NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Extended info    
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' + 
               ' @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cParam1         NVARCHAR( 20),  ' +
               '@cParam2         NVARCHAR( 20),  ' +
               '@cParam3         NVARCHAR( 20),  ' +
               '@cParam4         NVARCHAR( 20),  ' +
               '@cParam5         NVARCHAR( 20),  ' +
               '@cSKU            NVARCHAR( 20),  ' +
               '@nQty            INT,            ' +
               '@cLabelNo        NVARCHAR( 20),  ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
               @cSKU, @nQty, @cLabelNo, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT
         END
      END

      -- Prepare prev screen var    
      SET @cSKU = ''
      SET @cOutField01 = @cSKU    
    
      -- Go to SKU screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN
      SET @nExpQTY = @cOutField05
   END
END    
GOTO Quit    

/********************************************************************************    
Step 4. Screen 3234    
   PACKING COMPLETED    
   (Field01) 

   PRESS ESC for next 
   SKU packing
********************************************************************************/    
Step_4:    
BEGIN     
   SET @cConsigneeKey = ''

   -- Prepare prev screen var    
   SET @cOutField01 = @cLoadKey    
   SET @cOutField02 = '' --SKU    
   SET @cOutField03 = '' --UCC    
   
   -- Reset variable when finish packing the SKU
   SET @cOrderKey = ''
   SET @cSKU = ''
   SET @cLabelNo = ''
   
   -- Back to SKU screen    
   SET @nScn  = @nScn - 3    
   SET @nStep = @nStep - 3    
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
      Func   = @nFunc,    
      Step   = @nStep,    
      Scn    = @nScn,    
    
      StorerKey  = @cStorerKey,    
      Facility   = @cFacility,    
      Printer    = @cPrinter,    
    
      V_LoadKey  = @cLoadKey,    
      V_SKU      = @cSKU,    
      V_SKUDescr = @cSKUDescr,    
      V_ConsigneeKey = @cConsigneeKey,    
      V_OrderKey = @cOrderKey,     
      V_CaseID   = @cLabelNo,
          
      V_QTY      = @nExpQTY,    
    
      V_String1  = @cDefaultToEXPQTY,    
      V_String2  = @cDefaultQTY,    
      V_String3  = @cExtendedInfoSP,     
      V_String4  = @cConfirmTaskSP,     
      V_String5  = @cGetTaskSP,      
      V_String7  = @cCartonType, 
      V_String8  = @cDefaultCartonType, 
      V_String9  = @cExtendedInfo,
      V_String10 = @cExtendedUpdateSP, 
      V_String11 = @cExtendedValidateSP,
      V_String12 = @cExtendedInfo2,
      V_String13 = @cGetTaskSP,
      V_String14 = @cParam1,
      V_String15 = @cParam2,
      V_String16 = @cParam3,
      V_String17 = @cParam4,
      V_String18 = @cParam5,
      V_String19 = @cParamLabel1,
      V_String20 = @cParamLabel2,
      V_String21 = @cParamLabel3,
      V_String22 = @cParamLabel4,
      V_String23 = @cParamLabel5,
      
      V_Cartonno = @nCartonNo,
      
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