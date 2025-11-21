SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdtfnc_PackByDropID                                       */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date         Rev  Author     Purposes                                      */    
/* 2019-02-27   1.0  Ung        WMS-8034 Created                              */    
/* 2019-05-09   1.1  Ung        WMS-8034 Bug fix                              */    
/* 2019-05-09   1.2  Ung        WMS-8034 Add drop ID counter                  */   
/* 2019-05-27   1.3  YeeKung    WMS-9199 Add RDT Eventlog                     */  
/* 2019-11-26   1.4  James      WMS-11186 Add ExtValiSP @ step 1 (james01)    */  
/* 2020-02-26   1.5  James      WMS-12148 Add PackIndo config (james02)       */
/*                              Add config to check whether allow weight blank*/
/* 2020-08-06   1.6  Chermaine  WMS-14593 Add RDT Eventlog (cc01)             */  
/* 2020-09-14   1.7  Chermaine  WMS-15046 Add Print Packing List (cc02)       */
/* 2021-06-21   1.8  Chermaine  WMS-17288 Add CheckUom Config (cc03)          */
/******************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_PackByDropID] (    
   @nMobile    int,    
   @nErrNo     int  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 VARCHAR max    
)    
AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variables    
DECLARE    
   @bSuccess       INT,    
   @cOption        NVARCHAR( 1),    
   @cSQL           NVARCHAR( MAX),    
   @cSQLParam      NVARCHAR( MAX),     
   @tVar           VariableTable    
       
-- RDT.RDTMobRec variables    
DECLARE    
   @nFunc          INT,    
   @nScn           INT,    
   @nStep          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nInputKey      INT,    
   @nMenu          INT,    
    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cUserName      NVARCHAR( 18),    
   @cPaperPrinter  NVARCHAR( 10),     
   @cLabelPrinter  NVARCHAR( 10),     
    
   @cPickSlipNo         NVARCHAR( 10),    
   @cDropID             NVARCHAR( 20),    
   @nCartonNo           INT,     
   @nFromStep           INT,     
    
   @cLabelNo            NVARCHAR( 20),    
   @cCartonType         NVARCHAR( 10),    
   @cWeight             NVARCHAR( 10),    
   @cDropIDAdded        NVARCHAR( 1),    
   @cScanPickSlipNo     NVARCHAR( 1),    
    
   @cExtendedValidateSP NVARCHAR( 20),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cExtendedInfoSP     NVARCHAR( 20),    
   @cExtendedInfo       NVARCHAR( 20),    
   @cDefaultOption      NVARCHAR( 1),    
   @cShipLabel          NVARCHAR( 10),
   @cPackList           NVARCHAR( 10),       --(cc02)
   @cCheckUOM           NVARCHAR( 10),       --(cc03)
    
   @nTotalCarton        INT,     
   @nTotalPick          INT,     
   @nTotalPack          INT,     
   @nScanned            INT,    
   @tExtValidVar        VARIABLETABLE,
   @cAllowWeightZero    NVARCHAR( 1),
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 4), 
   @cCube               NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),

    
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
    
-- Getting Mobile information    
SELECT    
   @nFunc            = Func,    
   @nScn             = Scn,    
   @nStep            = Step,    
   @nInputKey        = InputKey,    
   @nMenu            = Menu,    
   @cLangCode        = Lang_code,    
    
   @cFacility        = Facility,    
   @cStorerKey       = StorerKey,    
   @cUserName        = UserName,    
   @cPaperPrinter    = Printer_Paper,     
   @cLabelPrinter    = Printer,     
       
   @cPickSlipNo      = V_PickSlipNo,    
   @cLabelNo         = V_CaseID,     
   @nCartonNo        = V_CartonNo,     
   @nFromStep        = V_FromStep,     
    
   @cDropID             = V_String1,    
   @cCartonType         = V_String2,    
   @cWeight             = V_String3,    
   @cDropIDAdded        = V_String4,    
   @cScanPickSlipNo     = V_String5,    
   @cAllowWeightZero    = V_String6,
   @cCapturePackInfoSP  = V_String7,
   @cPackInfo           = V_String8,
   @cCheckUOM           = V_String9,  --(cc03)

    
   @cExtendedValidateSP = V_String21,    
   @cExtendedUpdateSP   = V_String22,    
   @cExtendedInfoSP     = V_String23,    
   @cExtendedInfo       = V_String24,    
   @cDefaultOption      = V_String25,    
   @cShipLabel          = V_String26,  
   @cPackList           = V_String27,  --(cc02)
    
   @nTotalCarton        = V_Integer1,     
   @nTotalPick          = V_Integer2,     
   @nTotalPack          = V_Integer3,     
   @nScanned            = V_Integer4,     
    
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
    
IF @nFunc = 843 -- Pack    
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 838    
   IF @nStep = 1  GOTO Step_1  -- Scn = 5340. PickSlipNo, DropID    
   IF @nStep = 2  GOTO Step_2  -- Scn = 5341. Statistic, carton, option    
   IF @nStep = 3  GOTO Step_3  -- Scn = 5342. DropID    
   IF @nStep = 4  GOTO Step_4  -- Scn = 5343. Weight, Cube    
   IF @nStep = 5  GOTO Step_5  -- Scn = 5344. Confrim repack?    
END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step_0. Func = 838    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get storer configure    
   SET @cDefaultOption = rdt.rdtGetConfig( @nFunc, 'DefaultOption', @cStorerKey)    
   IF @cDefaultOption = '0'    
      SET @cDefaultOption = ''    
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''    
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)    
   IF @cShipLabel = '0'    
      SET @cShipLabel = ''    

   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''

   -- (james02)
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
   
   --(cc02)
   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)    
   IF @cPackList = '0'    
      SET @cPackList = ''  
      
   --(cc03) 
   SET @cCheckUOM = rdt.RDTGetConfig( @nFunc, 'CheckUOM', @cStorerKey)    
   IF @cCheckUOM = '0'    
      SET @cCheckUOM = '2' 

   -- EventLog    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign-in    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerKey,    
      @nStep       = @nStep    
    
   -- Prepare next screen var    
   SET @cOutField01 = '' -- PickSlipNo    
   SET @cOutField02 = '' -- DropID    
       
   EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo    
       
   -- Go to PickSlipNo screen    
   SET @nScn = 5340    
   SET @nStep = 1    
END    
GOTO Quit    
    
    
/************************************************************************************    
Scn = 5340. PickSlipNo screen    
   PSNO      (field01, input)    
   DROPID    (field02, input)    
************************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cPickSlipNo = @cInField01    
      SET @cDropID = @cInField02    
    
      -- Check blank    
      IF @cPickSlipNo = '' AND @cDropID = ''     
      BEGIN    
         SET @nErrNo = 135301    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PS/DropID    
         GOTO Quit    
      END    
    
      -- Check both key-in    
      IF @cPickSlipNo <> '' AND @cDropID <> ''     
      BEGIN    
         SET @nErrNo = 135302    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS or DropID    
         GOTO Quit    
      END    
          
      -- Pick slip    
      IF @cPickSlipNo <> ''    
      BEGIN    
         -- Check pick slip valid    
         IF NOT EXISTS( SELECT TOP 1 1 FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)    
         BEGIN    
            SET @nErrNo = 135303    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO    
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- DropID    
            SET @cOutField01 = ''    
            GOTO Quit    
         END    
         SET @cScanPickSlipNo = 'Y'    
      END    
    
      -- Drop ID    
      IF @cDropID <> ''     
      BEGIN    
         -- Get drop ID info    
         DECLARE @cOrderKey NVARCHAR(10)    
         DECLARE @cUOM NVARCHAR(10)    
         SET @cOrderKey = ''    
         SELECT TOP 1    
            @cOrderKey = OrderKey,     
            @cUOM = UOM    
         FROM PickDetail WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey     
            AND DropID = @cDropID    
            AND Status <> '4'    
            AND Status < '5'    
    
         -- Check DropID valid    
         IF @cOrderKey = ''    
         BEGIN    
            SET @nErrNo = 135304    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID    
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID    
            SET @cOutField02 = ''    
            GOTO Quit    
         END    
             
         -- Get drop ID info    
         DECLARE @cLoadKey NVARCHAR(10)    
         SET @cLoadKey = ''    
         SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey    
         IF @cLoadKey <> ''    
            SELECT @cPickSlipNo = PickHeaderKey    
            FROM PickHeader WITH (NOLOCK)    
            WHERE ExternOrderKey = @cLoadKey    
               AND OrderKey = ''    
    
         -- Check PickHeader    
         IF @cPickSlipNo = ''    
         BEGIN    
            SET @nErrNo = 135305    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickHdr    
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- ToDropID    
            SET @cOutField02 = ''    
            GOTO Quit    
         END    
   
         SET @cScanPickSlipNo = 'N'    
      END    

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cPickSlipNo, @cDropID, @nCartonNo, @cLabelNo, @cOption, @cCartonType, @cWeight, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' + 
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@nCartonNo     INT,           ' +
               '@cLabelNo      NVARCHAR( 20), ' +
               '@cOption       NVARCHAR( 1), ' +
               '@cCartonType   NVARCHAR( 10), ' +
               '@cWeight       NVARCHAR( 10), ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPickSlipNo, @cDropID, @nCartonNo, @cLabelNo, @cOption, @cCartonType, @cWeight,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Full carton    
      IF (select CHARINDEX(@cUOM, @cCheckUOM))>0  AND @cDropID <> ''  --(cc03)
      --IF @cUOM = '2' AND @cDropID <> ''
      BEGIN    
         SET @nCartonNo = 0    
         SET @cLabelNo = ''    
         EXEC rdt.rdt_PackByDropID_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
            ,@cPickSlipNo    
            ,@cDropID    
            ,@nCartonNo  OUTPUT    
            ,@cLabelNo   OUTPUT    
            ,@nErrNo     OUTPUT    
            ,@cErrMsg    OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         SET @nFromStep = @nStep    
              
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = CAST( @nCartonNo AS NVARCHAR(5))    
         SET @cOutField03 = '' -- Weight    
         SET @cOutField04 = '' -- Cube    
                
         -- Go to weight, cube screen    
         SET @nScn = @nScn + 3    
         SET @nStep = @nStep + 3    
                
         GOTO Quit    
      END    
         
      -- Get statistic    
      EXEC rdt.rdt_PackByDropID_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cPickSlipNo    
         ,@nTotalPick   OUTPUT    
         ,@nTotalPack   OUTPUT    
         ,@nTotalCarton OUTPUT    
         ,@nErrNo       OUTPUT    
         ,@cErrMsg      OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Prepare next screen var    
      SET @cOutField01 = @cPickSlipNo    
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))    
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))    
      SET @cOutField04 = CAST( @nTotalCarton AS NVARCHAR(5))    
      SET @cOutField05 = '' -- carton no    
      SET @cOutField06 = @cDefaultOption    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6  -- Option    
          
      -- Go to statistic screen    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- EventLog    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign-out    
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
END    
GOTO Quit    
    
    
/********************************************************************************    
Scn = 5341. Statistic screen    
   CARTONNO  (field05, input)    
   OPTION    (field06, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cCartonNo NVARCHAR(5)    
    
      -- Screen mapping    
      SET @cCartonNo = @cInField05    
      SET @cOption = @cInField06    
    
      -- Validate option    
      IF @cOption NOT IN ('1', '2', '3')    
      BEGIN    
         SET @nErrNo = 135306    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         SET @cOutField06 = '' -- Option    
         GOTO Quit    
      END    
      SET @cOutField06 = @cOption    
          
      -- Check valid carton    
      IF @cOption IN ('2', '3')    
      BEGIN    
         -- Check blank    
         IF @cCartonNo = ''    
         BEGIN    
            SET @nErrNo = 135307    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton no    
            EXEC rdt.rdtSetFocusField @nMobile, 5  -- CartonNo    
            GOTO Quit    
         END    
    
         -- Check carton no    
         IF @cCartonNo <> ''    
         BEGIN    
            IF RDT.rdtIsValidQTY( @cCartonNo, 1) = 0 --Check zero    
            BEGIN    
               SET @nErrNo = 135320    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CTN No    
               EXEC rdt.rdtSetFocusField @nMobile, 5  -- CartonNo    
               GOTO Quit    
            END    
         END    
             
         -- Get PackDetail info    
         SET @cLabelNo = ''    
         SELECT TOP 1    
            @cLabelNo = LabelNo    
         FROM PackDetail WITH (NOLOCK)     
         WHERE PickSlipNo = @cPickSlipNo     
            AND CartonNo = @cCartonNo    
    
         -- Check carton valid    
         IF @cLabelNo = ''    
         BEGIN    
            SET @nErrNo = 135308    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN not found    
            EXEC rdt.rdtSetFocusField @nMobile, 5  -- CartonNo    
            GOTO Quit    
         END    
             
         -- Check full carton edit / repack    
         IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CaseID = @cLabelNo AND UOM = '2')    
         BEGIN    
            SET @nErrNo = 135321    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Full CTN NoChg    
            EXEC rdt.rdtSetFocusField @nMobile, 5  -- CartonNo    
            GOTO Quit    
         END    
      END    
    
      SET @nCartonNo = @cCartonNo    
      SET @cDropIDAdded = 'N'    
    
      -- New carton    
      IF @cOption = '1'    
      BEGIN    
         SET @nCartonNo = 0    
         SET @cCartonNo = '0'    
         SET @cLabelNo = ''    
         SET @nScanned = 0    
             
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = @cCartonNo    
         SET @cOutField03 = ''  -- DropID    
         SET @cOutField04 = ''  -- Scanned       
       
         -- Go DropID screen    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
      END    
    
      -- Edit carton    
      ELSE IF @cOption = '2'    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = @cCartonNo    
         SET @cOutField03 = ''  -- DropID    
         SET @cOutField04 = ''  -- Scanned    
       
         -- Go DropID screen    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
      END    
    
      -- Repack carton    
      ELSE IF @cOption = '3'    
      BEGIN    
         -- Repack    
         EXEC rdt.rdt_PackByDropID_Repack @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
            ,@cPickSlipNo    
            ,@nCartonNo    
            ,@nErrNo    OUTPUT    
            ,@cErrMsg   OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Prepare next screen var    
         SET @cOutField01 = @cCartonNo    
         SET @cOutField02 = '' -- Option    
    
         -- Go to repack screen    
         SET @nScn = @nScn + 3    
         SET @nStep = @nStep + 3    
      END          
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare prev screen var    
      SET @cOutField01 = '' -- PickSlipNo    
      SET @cOutField02 = '' -- DropID    
          
      IF @cScanPickSlipNo = 'Y'    
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- DropID    
          
      -- Go to PickSlipNo screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Scn = 5342. Drop ID screen    
   PSNO        (field01)    
   CARTON NO   (field02)    
   DROP ID     (field03, input)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cDropID = @cInField03 -- DropID    
    
      -- Check packed    
      IF @cDropID = ''    
      BEGIN    
         SET @nErrNo = 135309    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Drop ID    
         GOTO Quit    
      END    
  
      -- Confirm    
      EXEC rdt.rdt_PackByDropID_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cPickSlipNo    
         ,@cDropID    
         ,@nCartonNo OUTPUT    
         ,@cLabelNo   OUTPUT    
         ,@nErrNo    OUTPUT    
         ,@cErrMsg   OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      SET @cDropIDAdded = 'Y'    
      SET @nScanned = @nScanned + 1    
      
      --(cc01)        
      EXEC RDT.rdt_STD_EventLog               
         @cActionType   = '3',    
         @nFunctionID   = @nFunc,       
         @nMobileNo     = @nMobile,    
         @cStorerKey    = @cStorerkey,                 
         @cFacility     = @cFacility,     
         @cPickSlipNo   = @cPickSlipNo,    
         @cUCC          = @cDropID,    
         @cRefNo1       = @nCartonNo
    
      -- Remain in current screen    
      SET @cOutField01 = @cPickSlipNo    
      SET @cOutField02 = CAST( @nCartonNo AS NVARCHAR( 5))    
      SET @cOutField03 = '' -- DropID    
      SET @cOutField04 = CAST( @nScanned AS NVARCHAR( 5))    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Repack without add drop ID    
      IF @nCartonNo > 0     
      BEGIN    
         -- Empty carton    
         IF NOT EXISTS( SELECT TOP 1 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND QTY > 0)    
         BEGIN    
            -- Handling transaction    
            DECLARE @nTranCount INT    
            SET @nTranCount = @@TRANCOUNT    
            BEGIN TRAN  -- Begin our own transaction    
            SAVE TRAN rdtfnc_PackByDropID -- For rollback or commit only our own transaction    
                
            -- PackInfo    
            IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
            BEGIN    
               DELETE PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo    
               IF @@ERROR <> 0    
               BEGIN    
                  ROLLBACK TRAN rdtfnc_PackByDropID    
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                     COMMIT TRAN    
                  SET @nErrNo = 135310    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PKInfoFail    
                  GOTO Quit    
               END    
            END    
    
            -- PackDetail (delete the booking record, 1 line with blank SKU)    
            IF EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
            BEGIN    
               DELETE PackDetail WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo    
               IF @@ERROR <> 0    
               BEGIN    
                  ROLLBACK TRAN rdtfnc_PackByDropID    
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                     COMMIT TRAN    
                  SET @nErrNo = 135311    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PAKDtlFail    
                  GOTO Quit    
               END    
            END    
    
            COMMIT TRAN rdtfnc_PackByDropID    
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
               COMMIT TRAN    
         END    
      END    
             
      -- Packed    
      IF @cDropIDAdded = 'Y'    
      BEGIN    
         -- Custom PackInfo field setup
         SET @cPackInfo = ''
         IF @cCapturePackInfoSP <> ''
         BEGIN
            -- Custom SP to get PackInfo setup
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @nCartonNo, @cLabelNo, ' + 
                  ' @nErrNo      OUTPUT, ' + 
                  ' @cErrMsg     OUTPUT, ' +
                  ' @cPackInfo   OUTPUT, ' +
                  ' @cWeight     OUTPUT, ' +
                  ' @cCube       OUTPUT, ' +
                  ' @cRefNo      OUTPUT, ' +
                  ' @cCartonType OUTPUT'
               SET @cSQLParam =
                  '@nMobile     INT,           ' +
                  '@nFunc       INT,           ' +
                  '@cLangCode   NVARCHAR( 3),  ' +
                  '@nStep       INT,           ' +
                  '@nInputKey   INT,           ' +
                  '@cFacility   NVARCHAR( 5),  ' +
                  '@cStorerKey  NVARCHAR( 15), ' +
                  '@cPickSlipNo NVARCHAR( 10), ' +
                  '@cFromDropID NVARCHAR( 20), ' +
                  '@nCartonNo   INT,           ' +
                  '@cLabelNo    NVARCHAR( 20), ' +
                  '@nErrNo      INT           OUTPUT, ' +
                  '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +
                  '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +
                  '@cWeight     NVARCHAR( 10) OUTPUT, ' +
                  '@cCube       NVARCHAR( 10) OUTPUT, ' +
                  '@cRefNo      NVARCHAR( 20) OUTPUT, ' +
                  '@cCartonType NVARCHAR( 10) OUTPUT  '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cDropID, @nCartonNo, @cLabelNo,
                  @nErrNo      OUTPUT, 
                  @cErrMsg     OUTPUT,
                  @cPackInfo   OUTPUT,
                  @cWeight     OUTPUT,
                  @cCube       OUTPUT,
                  @cRefNo      OUTPUT,
                  @cCartonType OUTPUT
            END
            ELSE
               -- Setup is non SP
               SET @cPackInfo = @cCapturePackInfoSP
         END
   
         -- Capture pack info
         IF @cPackInfo <> ''
         BEGIN
            -- Get PackInfo
            SET @cCartonType = ''
            SET @cWeight = ''
            SET @cCube = ''
            SET @cRefNo = ''
            SELECT
               @cCartonType = CartonType,
               @cWeight = rdt.rdtFormatFloat( Weight),
               @cCube = rdt.rdtFormatFloat( [Cube]),
               @cRefNo = RefNo
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo  = @nCartonNo
      
            -- Prepare LOC screen var
            SET @cOutField03 = @cCartonType
            SET @cOutField04 = CASE WHEN ISNULL( @cWeight, '') = '' THEN '0' ELSE @cWeight END
      
            -- Enable disable field
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END

            -- Position cursor
            IF @cFieldAttr03 = '' AND @cOutField03 = ''  EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE -- Carton Type 
            IF @cFieldAttr04 = '' AND @cOutField04 = '0' EXEC rdt.rdtSetFocusField @nMobile, 4      -- Weight 
            
            SET @nFromStep = @nStep    
    
            -- Prepare next screen var    
            SET @cOutField01 = @cPickSlipNo    
            SET @cOutField02 = CAST( @nCartonNo AS NVARCHAR(5))    
    
            -- Go to weight, cube screen    
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
             
            GOTO Quit    
         END
      END    
    
      -- Get statistic    
      EXEC rdt.rdt_PackByDropID_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cPickSlipNo    
         ,@nTotalPick   OUTPUT    
         ,@nTotalPack   OUTPUT    
         ,@nTotalCarton OUTPUT    
         ,@nErrNo       OUTPUT    
         ,@cErrMsg      OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Prepare next screen var    
      SET @cOutField01 = @cPickSlipNo    
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))    
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))    
      SET @cOutField04 = CAST( @nTotalCarton AS NVARCHAR(5))    
      SET @cOutField05 = '' -- carton no    
      SET @cOutField06 = ''    
          
      EXEC rdt.rdtSetFocusField @nMobile, 6  -- Option    
          
      -- Go to statistic screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Scn = 5343. Weight, cube screen    
   PSNO        (field01)    
   CartonNo    (field02)    
   CartonType  (field03, input)    
   Weight      (field04, input)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @fCube FLOAT    
      DECLARE @fWeight FLOAT    
    
      -- Screen mapping
      SET @cCartonType  = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cWeight      = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
          
      -- CartonType    
      -- Check blank    
      IF @cFieldAttr03 = ''
      BEGIN
         IF @cCartonType = ''    
         BEGIN    
            SET @nErrNo = 135312    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CartonType    
            GOTO Quit    
         END    
             
         -- Get default cube    
         SELECT @fCube = [Cube]    
         FROM Cartonization WITH (NOLOCK)    
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)    
         WHERE Storer.StorerKey = @cStorerKey    
            AND Cartonization.CartonType = @cCartonType    
    
         -- Check if valid    
         IF @@ROWCOUNT = 0    
         BEGIN    
            SET @nErrNo = 135313    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CartonType    
            SET @cOutField03 = ''    
            GOTO Quit    
         END    

         SET @cOutField03 = @cCartonType     
      END

      -- Weight
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank    
         IF @cWeight = ''    
         BEGIN    
            SET @nErrNo = 135314    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight    
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight    
            GOTO Quit    
         END    
    
         -- Check format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'WEIGHT', @cWeight) = 0    
         BEGIN    
            SET @nErrNo = 100233    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight    
            SET @cOutField04 = ''    
            GOTO Quit    
         END    

         -- (james02)
         -- Check weight valid
         IF @cAllowWeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 135315    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight    
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight    
            SET @cOutField04 = ''    
            GOTO QUIT    
         END    
         SET @nErrNo = 0    
         SET @cOutField04 = @cWeight    
    
         SET @fWeight = CAST( @cWeight AS FLOAT)     
      END

      -- PackInfo    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
      BEGIN    
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType)    
         VALUES (@cPickSlipNo, @nCartonNo, 0, @fWeight, @fCube, @cCartonType)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 135316    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail    
            GOTO Quit    
         END    
      END   
      ELSE    
      BEGIN    
         UPDATE dbo.PackInfo SET    
            CartonType = @cCartonType,    
            Weight = @fWeight,    
            [Cube] = @fCube    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nCartonNo    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 135317    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail    
            GOTO Quit    
         END    
      END    
    
      -- Ship label    
      IF @cShipLabel <> ''     
      BEGIN    
         -- Common params    
         DECLARE @tShipLabel AS VariableTable    
         INSERT INTO @tShipLabel (Variable, Value) VALUES     
            ( '@cStorerKey',     @cStorerKey),     
            ( '@cPickSlipNo',    @cPickSlipNo),     
            ( '@cLabelNo',       @cLabelNo),     
            ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))    
    
         -- Print label    
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,     
            @cShipLabel, -- Report type    
            @tShipLabel, -- Report params    
            'rdtfnc_PackByDropID',     
            @nErrNo  OUTPUT,    
            @cErrMsg OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      -- Pack confirm    
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')    
      BEGIN    
         -- Pack confirm    
         EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
            ,@cPickSlipNo    
            ,'' -- @cFromDropID    
            ,'' -- @cPackDtlDropID    
            ,'' -- @cPrintPackList OUTPUT    
            ,@nErrNo         OUTPUT    
            ,@cErrMsg        OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
      
      -- Packing List --(cc02)    
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')    
      BEGIN 
      	IF @cPackList <> ''     
         BEGIN    
            -- Common params    
            DECLARE @tPackList AS VariableTable    
            INSERT INTO @tPackList (Variable, Value) VALUES        
               ( '@cPickSlipNo',    @cPickSlipNo)   
    
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,     
               @cPackList, -- Report type    
               @tPackList, -- Report params    
               'rdtfnc_PackByDropID',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT    
            IF @nErrNo <> 0    
               GOTO Quit    
         END  
      END

      --(yeekung01)        
      EXEC RDT.rdt_STD_EventLog               
         @cActionType   = '3',    
         @nFunctionID   = @nFunc,       
         @nMobileNo     = @nMobile,    
         @cStorerKey    = @cStorerkey,                 
         @cFacility     = @cFacility,     
         @cPickSlipNo   = @cPickSlipNo,    
         @cUCC          = @cDropID,    
         @cRefNo1       = @nCartonNo,    
         @cCartonType   = @cCartonType,    
         @fWeight       = @fWeight
            
      IF @nFromStep = 1 -- PickSlipNo    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = '' -- @cPickSlipNo    
         SET @cOutField02 = '' -- DropID    
             
         IF @cScanPickSlipNo = 'Y'    
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- DropID    
             
         -- Go to PickSlipNo screen    
         SET @nScn = @nScn - 3    
         SET @nStep = @nStep - 3          
      END    
      ELSE    
      BEGIN    
         -- Get statistic    
         EXEC rdt.rdt_PackByDropID_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
            ,@cPickSlipNo    
            ,@nTotalPick   OUTPUT    
            ,@nTotalPack   OUTPUT    
            ,@nTotalCarton OUTPUT    
            ,@nErrNo       OUTPUT    
            ,@cErrMsg      OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))    
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))    
         SET @cOutField04 = CAST( @nTotalCarton AS NVARCHAR(5))    
         SET @cOutField05 = '' -- carton no    
         SET @cOutField06 = @cDefaultOption    
             
         EXEC rdt.rdtSetFocusField @nMobile, 6  -- Option    
             
         -- Go to statistic screen    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @nFromStep = 1 -- Pick slip no    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = '' -- PickSlipNo    
         SET @cOutField02 = '' -- DropID    
    
         IF @cScanPickSlipNo = 'Y'    
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- DropID    
    
         -- Go to PickSlipNo screen    
         SET @nScn = @nScn - 3    
         SET @nStep = @nStep - 3    
      END    
      ELSE    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = CAST( @nCartonNo AS NVARCHAR(5))    
         SET @cOutField03 = '' -- DropID    
         SET @cOutField04 = CAST( @nScanned AS NVARCHAR(5))    
    
         -- Go to DropID screen    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Scn = 5344. Confirm repack?    
   Option (field02, input)    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField02    
    
      -- Validate blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 135318    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired    
         GOTO Quit    
      END    
    
      -- Validate option    
      IF @cOption <> '1' AND @cOption <> '2'    
      BEGIN    
         SET @nErrNo = 135319    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         SET @cOutField01 = ''    
         GOTO Quit    
      END    
    
      IF @cOption = '1'  -- Yes    
      BEGIN    
         EXEC rdt.rdt_PackByDropID_Repack @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
            ,@cPickSlipNo    
            ,@nCartonNo    
            ,@nErrNo    
            ,@cErrMsg    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Prepare next screen var    
         SET @cOutField01 = @cPickSlipNo    
         SET @cOutField02 = CAST( @nCartonNo AS NVARCHAR( 5))    
         SET @cOutField03 = ''  -- DropID    
         SET @cOutField04 = ''  -- Scanned    
       
         SET @nScanned = 0    
       
         -- Go to DropID screen    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
             
         GOTO Quit    
      END    
   END    
       
   -- Get statistic    
   EXEC rdt.rdt_PackByDropID_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
      ,@cPickSlipNo    
      ,@nTotalPick   OUTPUT    
      ,@nTotalPack   OUTPUT    
      ,@nTotalCarton OUTPUT    
      ,@nErrNo       OUTPUT    
      ,@cErrMsg      OUTPUT    
   IF @nErrNo <> 0    
      GOTO Quit    
    
   -- Prepare next screen var    
   SET @cOutField01 = @cPickSlipNo    
   SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))    
   SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))    
   SET @cOutField04 = CAST( @nTotalCarton AS NVARCHAR(5))    
   SET @cOutField05 = '' -- carton no    
   SET @cOutField06 = '' -- option    
    
   EXEC rdt.rdtSetFocusField @nMobile, 6  -- Option    
       
   -- Go to statistic screen    
   SET @nScn = @nScn - 3    
   SET @nStep = @nStep - 3    
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
    
      StorerKey      = @cStorerKey,    
      Facility       = @cFacility,    
      Printer_Paper  = @cPaperPrinter,     
      Printer        = @cLabelPrinter,     
       
      V_PickSlipNo   = @cPickSlipNo,    
      V_CaseID       = @cLabelNo,     
      V_CartonNo     = @nCartonNo,     
      V_FromStep     = @nFromStep,     
    
      V_String1      = @cDropID,    
      V_String2      = @cCartonType,     
      V_String3      = @cWeight,     
      V_String4      = @cDropIDAdded,    
      V_String5      = @cScanPickSlipNo,    
      V_String6      = @cAllowWeightZero,      
      V_String7      = @cCapturePackInfoSP, 
      V_String8      = @cPackInfo,
      V_String9      = @cCheckUOM,  --(cc03)
    
      V_String21     = @cExtendedValidateSP,    
      V_String22     = @cExtendedUpdateSP,     
      V_String23     = @cExtendedInfoSP,     
      V_String24     = @cExtendedInfo,     
      V_String25     = @cDefaultOption,    
      V_String26     = @cShipLabel,
      V_String27     = @cPackList,    --(cc02)    
    
      V_Integer1     = @nTotalCarton,     
      V_Integer2     = @nTotalPick,     
      V_Integer3     = @nTotalPack,        
      V_Integer4     = @nScanned,     
    
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