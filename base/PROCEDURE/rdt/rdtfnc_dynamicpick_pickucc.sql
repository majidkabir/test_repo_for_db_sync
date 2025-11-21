SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtfnc_DynamicPick_PickUCC                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: RDT Dynamic Pick - Pick And Pack UCC(2)                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 20-03-2022 1.0  yeekung  WMS-19154. Created                          */
/* 07-05-2022 1.1  Ung      WMS-19982 Add swap UCC                      */
/* 07-09-2022 1.2  yeekung  fix rdtfnc_DynamicPick_PickUCC_Confirm      */
/*                           -> rdt_DynamicPick_PickUCC_Confirm         */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_DynamicPick_PickUCC] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @cUCCNo            NVARCHAR( 20),   
   @cOption           NVARCHAR( 1),   
   @cSQL              NVARCHAR( MAX),   
   @cSQLParam         NVARCHAR( MAX)  
     
-- RDT.RDTMobRec variable  
DECLARE  
   @nFunc             INT,  
   @nScn              INT,  
   @nStep             INT,  
   @cLangCode         NVARCHAR(3),  
   @nInputKey         INT,  
   @nMenu             INT,  
  
   @cStorerKey        NVARCHAR(15),  
   @cFacility         NVARCHAR(5),  
   @cUserName         NVARCHAR(15),  
   @cPrinter          NVARCHAR(10),  
   
   @cSuggSKUDescr     NVARCHAR(40),  
   @cSuggestedLOC     NVARCHAR(10),   
   @nQTY              INT,   
  
   @cWaveKey          NVARCHAR(10),   
   @cPickSlipNo       NVARCHAR(20),
   @cZone             NVARCHAR(20),  
   @cLoc              NVARCHAR(10),  
   @cDecodeLabelNo    NVARCHAR(20),  
   @cExtendedUpdateSP NVARCHAR(20),  
   @cExtendedValidateSP NVARCHAR(20),
   @cOrderKey         NVARCHAR(20),
   @cLoadKey          NVARCHAR(20),
   @cSuggSKU          NVARCHAR(20),
   @nSuggQTY          INT,
   @cDropid           NVARCHAR(20),
   @cSwapUCCSP        NVARCHAR(20),
  
   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),  
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),  
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),  
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),  
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),  
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),  
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),  
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),  
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),  
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),  
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),  
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),  
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),  
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),  
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60)  
  
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
  
   @cSuggSKU         = V_SKU,  
   @cSuggSKUDescr    = V_SKUDescr,  
   @cSuggestedLOC    = V_LOC,  
   @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,  
  
   @cPickSlipNo   = V_String1,  
   @cZone         = V_String2,  
   @cLoc          = V_String3, 
   @cDecodeLabelNo     = V_String7,  
   @cExtendedUpdateSP  = V_String8, 
   @cExtendedValidateSP = V_String9,
   @cLoadKey           = V_String10,
   @cOrderKey          = V_String11,
   @cSuggSKU           = V_String12,
   @cUCCNo             = V_String13,
   @cDropid            = V_String14,
   @cSwapUCCSP         = V_String15,

   @nSuggQTY           = V_Integer1,
  
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
  
FROM rdt.RDTMobRec WITH (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 958 -- Dynamic UCC Pick & Pack   
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 958  
   IF @nStep = 1 GOTO Step_1   -- Scn = 6030. PickSlipNo  
   IF @nStep = 2 GOTO Step_2   -- Scn = 6031. LOC  
   IF @nStep = 3 GOTO Step_3   -- Scn = 6032. UCC  
   IF @nStep = 4 GOTO Step_4   -- Scn = 6033. Confirm Short Pick  
   IF @nStep = 5 GOTO Step_5   -- Scn = 6034. DropID  
END  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. Called from menu (func = 958)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn = 6030  
   SET @nStep = 1  
  
   -- Init var  
   SET @cLoc = ''  
   SET @cSuggSKU = ''  
   SET @cSuggSKUDescr = ''  
  
   -- Get StorerConfig  
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)  
   IF @cDecodeLabelNo = '0'  
      SET @cDecodeLabelNo = ''  
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''  
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''  
   SET @cSwapUCCSP = rdt.RDTGetConfig( @nFunc, 'SwapUCCSP', @cStorerKey)
   IF @cSwapUCCSP = '0'
      SET @cSwapUCCSP = ''
      
   -- Prep next screen var  
   SET @cOutField01 = '' -- PickSlipno  
  
    -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign-in  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerKey  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Screen = 6030  
   PickSlipNo  (field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPickSlipNo = @cInField01  
  
      -- Check WaveKey blank  
      IF @cPickSlipNo = '' -- WaveKey  
      BEGIN  
         --SET @cOutField01 = ''  
         SET @nErrNo = 184451  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need PickSlipNo'  
         GOTO Step_1_Fail  
      END  
  
      SET @cOrderKey = ''          
      SET @cLoadKey = ''          
      SET @cZone = ''    

      SELECT TOP 1          
         @cOrderKey = OrderKey,          
         @cLoadKey = ExternOrderKey,          
         @cZone = Zone          
      FROM dbo.PickHeader WITH (NOLOCK)          
      WHERE PickHeaderKey = @cPickSlipNo     
      
      -- Cross dock PickSlip          
      IF @cZone IN ('XD', 'LB', 'LP')          
      BEGIN          
         -- Check PickSlipNo valid          
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)          
         BEGIN          
            SET @nErrNo = 184452          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO          
            GOTO Step_1_Fail          
         END                   
      END          
          
      -- Discrete PickSlip          
      ELSE IF @cOrderKey <> ''          
      BEGIN          
         DECLARE @cChkStorerKey NVARCHAR( 15)          
         DECLARE @cChkStatus    NVARCHAR( 10)          
          
         -- Get Order info          
         SELECT          
            @cChkStorerKey = StorerKey,          
            @cChkStatus = Status          
         FROM dbo.Orders WITH (NOLOCK)          
         WHERE OrderKey = @cOrderKey          
          
         -- Check PickSlipNo valid          
         IF @@ROWCOUNT = 0          
         BEGIN          
            SET @nErrNo = 184453          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO          
            GOTO Step_1_Fail          
         END          
          
         -- Check order shipped          
         IF @cChkStatus >= '5'          
         BEGIN          
            SET @nErrNo = 184454          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked          
            GOTO Step_1_Fail          
         END          
          
         -- Check storer          
         IF @cChkStorerKey <> @cStorerKey          
         BEGIN          
            SET @nErrNo = 184455          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff storer          
            GOTO Step_1_Fail          
         END          
      END          
          
      -- Conso PickSlip          
      ELSE IF @cLoadKey <> ''          
      BEGIN          
         -- Check PickSlip valid          
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)          
         BEGIN          
            SET @nErrNo = 184456          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO          
            GOTO Step_1_Fail          
         END          

         IF EXISTS( SELECT TOP 1 1         
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)          
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)          
            WHERE LPD.LoadKey = @cLoadKey          
               AND O.StorerKey <> @cStorerKey)          
         BEGIN          
            SET @nErrNo = 184457          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer          
            GOTO Step_1_Fail          
         END          
      END          
          
      -- Custom PickSlip          
      ELSE          
      BEGIN          
         -- Check PickSlip valid          
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)          
         BEGIN          
            SET @nErrNo = 184458          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO          
            GOTO Step_1_Fail          
         END          

         IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey <> @cStorerKey)          
         BEGIN          
            SET @nErrNo = 184459          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer          
            GOTO Step_1_Fail          
         END          
      END    
      
      DECLARE @dScanInDate DATETIME          
      DECLARE @dScanOutDate DATETIME   
      
      -- Get picking info          
      SELECT TOP 1          
         @dScanInDate = ScanInDate,          
         @dScanOutDate = ScanOutDate          
      FROM dbo.PickingInfo WITH (NOLOCK)          
      WHERE PickSlipNo = @cPickSlipNo          
          
      IF @@ROWCOUNT = 0          
      BEGIN          
         INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)          
         VALUES (@cPickSlipNo, GETDATE(), @cUserName)          
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 184460          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in          
            GOTO Step_1_Fail          
         END          
      END          
      ELSE          
      BEGIN          
         -- Scan-in          
         IF @dScanInDate IS NULL          
         BEGIN          
            UPDATE dbo.PickingInfo WITH (ROWLOCK)
            SET          
               ScanInDate = GETDATE(),          
               PickerID = @cUserName          
            WHERE PickSlipNo = @cPickSlipNo          
            IF @@ERROR <> 0          
            BEGIN          
               SET @nErrNo = 184461          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in          
               GOTO Step_1_Fail          
            END          
         END          
          
         -- Check already scan out          
         IF @dScanOutDate IS NOT NULL          
         BEGIN          
            SET @nErrNo = 184462          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS scanned out          
            GOTO Step_1_Fail          
         END          
      END  
   
      -- Get first LOC to pick  
      SET @cSuggestedLoc = ''  
      EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextLoc',  
         @cPickSlipNo,  
         @cSuggestedLOC OUTPUT,
         @cSuggSKU OUTPUT,
         @nSuggQTY OUTPUT,
         @cUCCNo  OUTPUT,
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit

      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey ' +  
               ',@cFacility      ' +  
               ',@cStorerKey     ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cSuggSKU           ' +  
               ',@nQTY           ' +  
               ',@cUCCNo         ' + 
               ',@cDropID        ' +
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT'  
            SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT ' +  
               ',@cFacility       NVARCHAR( 5)   ' +  
               ',@cStorerKey      NVARCHAR( 15)  ' +  
               ',@cPickSlipNo     NVARCHAR( 20)  ' +    
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cSuggSKU        NVARCHAR( 20)  ' +  
               ',@nQTY            INT        ' +  
               ',@cUCCNo          NVARCHAR( 20)  ' + 
               ',@cDropID         NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep,@nInputKey  
               ,@cFacility  
               ,@cStorerKey  
               ,@cPickSlipNo
               ,@cSuggestedLOC  
               ,@cSuggSKU  
               ,@nQTY  
               ,@cUCCNo
               ,@cDropID 
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
         
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey, ' +  
               ',@cFacility      ' +  
               ',@cStorerKey     ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cSuggSKU           ' +  
               ',@nQTY           ' +  
               ',@cUCCNo         ' +
               ',@cDropID        ' +
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT'  
            SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT, ' +  
               ',@cFacility       NVARCHAR( 5)   ' +  
               ',@cStorerKey      NVARCHAR( 15)  ' +  
               ',@cPickSlipNo     NVARCHAR( 20)  ' +  
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cSuggSKU        NVARCHAR( 20)  ' +  
               ',@nQTY            INT        ' +  
               ',@cUCCNo          NVARCHAR( 20)  ' +
               ',@cDropID         NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep  
               ,@cFacility  
               ,@cStorerKey  
               ,@cPickSlipNo
               ,@cSuggestedLOC  
               ,@cSuggSKU  
               ,@nQTY  
               ,@cUCCNo  
               ,@cDropID
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Clear next screen variable  
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSuggestedLOC  
      SET @cOutField03 = '' -- LOC  
  
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
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
       @cRefNo1     = 'Pick And Pack'  
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Clean up for menu option  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   SET @cOutField01 = ''  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Screen 3561  
   SUGGEST LOC (Field01)  
   LOC         (Field02, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cLOC = @cInField03  
  
      -- Skip LOC  
      IF @cLOC = ''  
      BEGIN   
         EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey, 'NextLoc',  
            @cPickSlipNo,  
            @cSuggestedLOC OUTPUT,
            @cSuggSKU OUTPUT,
            @nSuggQTY OUTPUT,
            @cUCCNo  OUTPUT,
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  

         IF @nErrNo <> 0  
            GOTO Quit  
  
         SET @cOutField02 = @cSuggestedLOC  
         SET @cOutField03 = '' -- LOC  
         GOTO Quit  
      END  
  
      -- Check LOC same as suggested  
      IF @cLOC <> @cSuggestedLOC  
      BEGIN  
         SET @nErrNo = 184463  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC  
         GOTO Step_2_Fail  
      END  

      SET @cSuggSKU=''

      EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextSKU',   
      @cPickSlipNo,  
      @cSuggestedLOC OUTPUT,
      @cSuggSKU OUTPUT,
      @nSuggQTY OUTPUT,
      @cUCCNo  OUTPUT,
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT  

      IF @nErrNo<>0
         GOTO QUIT

      SELECT @cSuggSKUDescr=DESCR
      FROM dbo.SKU (NOLOCK)
      WHERE SKU=@cSuggSKU
  
      -- Prep next screen var  
      SET @cOutField01 = @cSuggSKU  
      SET @cOutField02 = SUBSTRING( @cSuggSKUDescr, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cSuggSKUDescr, 21, 20)  
      SET @cOutField04 = @cUCCNo 
      SET @cOutField05 = '' -- UCC  
      SET @cOutField06 = @nSuggQTY  
  
      -- Go to next screen  
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1  
  
      EXEC rdt.rdtSetFocusField @nMobile, 5
   END  
  
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      -- Prepare prev screen var  
      SET @cOutField01 = '' -- PickSlipNo  
  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cOutField03 = '' -- LOC  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. Screen 3562  
   SKU       (Field01)  
   SKU Desc1 (Field02)  
   SKU Desc2 (Field03)  
   Lottable1 (Field04)  
   Lottable2 (Field05)  
   Lottable3 (Field06)  
   Lottable4 (Field07)  
   UCC       (Field08, input)  
   QTY       (Field09)  
   BAL       (Field10)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      DECLARE @cSuggUCCNo NVARCHAR(20)
      SET @cSuggUCCNo = @cInField05  
        
      -- Check if blank  
      IF @cSuggUCCNo = ''  
      BEGIN  
         -- Go to confirm short screen  
         SET @cOutField01 = '' -- Option  
         SET @nScn  = @nScn + 1  
         SET @nStep = @nStep + 1  
         GOTO Quit  
      END  

      -- Check if blank  
      IF @cSuggUCCNo <> @cUCCno
      BEGIN  
         -- Swap UCC (must be same FromLOC, FromID, SKU, QTY)
         IF @cSwapUCCSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSwapUCCSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapUCCSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPickSlipNo, @cLOC, @cSuggSKU, @nSuggQTY, @cSuggUCCNo,  ' + 
                  ' @cUCCNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile            INT,           ' +
                  '@nFunc              INT,           ' +
                  '@cLangCode          NVARCHAR( 3),  ' +
                  '@nStep              INT,           ' +
                  '@nInputKey          INT,           ' +
                  '@cFacility          NVARCHAR( 5),  ' +  
                  '@cStorerKey         NVARCHAR( 15), ' +  
                  '@cPickSlipNo        NVARCHAR( 20), ' +  
                  '@cLOC               NVARCHAR( 10), ' +
                  '@cSuggSKU           NVARCHAR( 20), ' +
                  '@nSuggQTY           INT,           ' +
                  '@cSuggUCCNo         NVARCHAR( 20), ' +
                  '@cUCCNo             NVARCHAR( 20)  OUTPUT,' +
                  '@nErrNo             INT            OUTPUT, ' +
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cPickSlipNo, @cLOC, @cSuggSKU, @nSuggQTY, @cSuggUCCNo, 
                  @cUCCNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrno= 184464
            SET @cErrMSg= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC
            GOTO Quit  
         END
      END 
        
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey, ' +  
               ',@cFacility      ' +  
               ',@cStorerKey     ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cSuggSKU       ' +  
               ',@nQTY           ' +  
               ',@cUCCNo         ' +
               ',@cDropID        ' +
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT'  
            SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT, ' +  
               ',@cFacility       NVARCHAR( 5)   ' +  
               ',@cStorerKey      NVARCHAR( 15)  ' +  
               ',@cPickSlipNo     NVARCHAR( 20)  ' +  
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cSuggSKU        NVARCHAR( 20)  ' +  
               ',@nQTY            INT        ' +  
               ',@cUCCNo          NVARCHAR( 20)  ' +
               ',@cDropID         NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep  
               ,@cFacility  
               ,@cStorerKey  
               ,@cPickSlipNo
               ,@cSuggestedLOC  
               ,@cSuggSKU  
               ,@nQTY  
               ,@cUCCNo  
               ,@cDropID
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  

      -- Prep prev screen var  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField02 = ''  

      -- Go to prev screen  
      SET @nScn  = @nScn + 2  
      SET @nStep = @nStep + 2  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prep prev screen var  
      SET @cOutField01 = @cPickSlipNo  
      SET @cOutField02 = @cSuggestedLOC  
      SET @cOutField03 = '' -- LOC  
  
      -- Go to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cOutField08 = '' -- UCC  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Screen = 3563  
   CONFIRM SHORT PICK?  
   1=YES  
   2=NO  
   Option (Field01, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 184465  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'  
         GOTO Step_4_Fail  
      END  
  
      -- Check valid option  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 184466  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_4_Fail  
      END  
  
      IF @cOption = '1' -- Short  
      BEGIN

         EXECUTE rdt.rdt_DynamicPick_PickUCC_Confirm @nMobile, @nFunc,@cLangCode, @cUserName,@cFacility,@cStorerKey,  
            @cSuggestedLOC,
            @cPickSlipNo,  
            @cSuggSKU,
            @cUCCNo,
            @cDropID,
            0,
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  

         -- Extended update  
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey, ' +  
                  ',@cFacility      ' +  
                  ',@cStorerKey     ' +  
                  ',@cPickSlipNo    ' +  
                  ',@cSuggestedLOC  ' +  
                  ',@cSuggSKU       ' +  
                  ',@nQTY           ' +  
                  ',@cUCCNo         ' +
                  ',@cDropID        ' +
                  ',@cOption        ' +  
                  ',@nErrNo  OUTPUT ' +  
                  ',@cErrMsg OUTPUT'  
               SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT, ' +  
                  ',@cFacility       NVARCHAR( 5)   ' +  
                  ',@cStorerKey      NVARCHAR( 15)  ' +  
                  ',@cPickSlipNo     NVARCHAR( 20)  ' +  
                  ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
                  ',@cSuggSKU        NVARCHAR( 20)  ' +  
                  ',@nQTY            INT        ' +  
                  ',@cUCCNo          NVARCHAR( 20)  ' +
                  ',@cDropID         NVARCHAR( 20)  ' +
                  ',@cOption         NVARCHAR( 1)   ' +  
                  ',@nErrNo          INT OUTPUT ' +  
                  ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep  
                  ,@cFacility  
                  ,@cStorerKey  
                  ,@cPickSlipNo
                  ,@cSuggestedLOC  
                  ,@cSuggSKU  
                  ,@nQTY  
                  ,@cUCCNo  
                  ,@cDropID
                  ,@cOption  
                  ,@nErrNo  OUTPUT  
                  ,@cErrMsg OUTPUT  
               IF @nErrNo <> 0  
                  GOTO Quit  
            END  
         END  

         -- Get next task to pick  
         SET @nErrNo = 0  
         EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextSKU',   
            @cPickSlipNo,  
            @cSuggestedLOC OUTPUT,
            @cSuggSKU OUTPUT,
            @nSuggQTY OUTPUT,
            @cUCCNo  OUTPUT,
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  

           
         IF @nErrNo = 0 -- More task on same LOC  
         BEGIN  
            SELECT @cSuggSKUDescr=DESCR
            FROM dbo.SKU (NOLOCK)
            WHERE SKU=@cSuggSKU

            SET @cOutField01 = @cSuggSKU  
            SET @cOutField02 = SUBSTRING( @cSuggSKUDescr, 1, 20)  
            SET @cOutField03 = SUBSTRING( @cSuggSKUDescr, 21, 20)  
            SET @cOutField04 = @cUCCNo  
            SET @cOutField05 = '' -- UCC  
            SET @cOutField06 = CAST( @nSuggQTY AS NVARCHAR( 5))  
         
            SET @nStep=@nStep-1
            SET @nScn=@nScn-1
            GOTO QUIT
         END  
         ELSE
         BEGIN
            -- Get next task to pick  
            SET @nErrNo = 0  
            EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextLoc',   
               @cPickSlipNo,  
               @cSuggestedLOC OUTPUT,
               @cSuggSKU OUTPUT,
               @nSuggQTY OUTPUT,
               @cUCCNo  OUTPUT,
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT  
           
            IF @nErrNo = 0 -- More task on pickslipno
            BEGIN  
               -- Clear next screen variable  
               SET @cOutField01 = @cPickSlipNo
               SET @cOutField02 = @cSuggestedLOC  
               SET @cOutField03 = '' -- LOC  
  
               -- Go to next screen  
               SET @nScn  = @nScn - 2  
               SET @nStep = @nStep - 2  
  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
               GOTO QUIT
            END  
            ELSE
            BEGIN
               SET @cOutField01 =''

               -- Go to next screen  
               SET @nScn  = @nScn - 3
               SET @nStep = @nStep - 3 

               EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNO
               GOTO QUIT
            END
         END
      END
   END  

   IF @nInputKey = 0
   BEGIN
     
      -- Prepare prev screen variable  
      SET @cOutField01 = @cSuggSKU  
      SET @cOutField02 = SUBSTRING( @cSuggSKUDescr, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cSuggSKUDescr, 21, 20)   
      SET @cOutField04 = @cUCCNo 
      SET @cOutField08 = '' -- UCC  
      SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))  

      -- Go to previous screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
      GOTO Quit  
   END
  
   Step_4_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField01 = '' --Option  
   END  
END  
GOTO Quit  

/********************************************************************************  
Step 5. Screen = 3563  
   UCC:  
   (Field01, DIsplay)  
   DropID:  
   (Field02, DIsplay) 
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cDropid = @cInField02  

      -- Check DropID format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0        
      BEGIN        
         SET @nErrNo = 184467        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
         GOTO Step_5_Fail        
      END  

      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey ' +  
               ',@cFacility      ' +  
               ',@cStorerKey     ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cSuggSKU           ' +  
               ',@nQTY           ' +  
               ',@cUCCNo         ' + 
               ',@cDropID        ' +
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT'  
            SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT ' +  
               ',@cFacility       NVARCHAR( 5)   ' +  
               ',@cStorerKey      NVARCHAR( 15)  ' +  
               ',@cPickSlipNo     NVARCHAR( 20)  ' +    
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cSuggSKU        NVARCHAR( 20)  ' +  
               ',@nQTY            INT        ' +  
               ',@cUCCNo          NVARCHAR( 20)  ' + 
               ',@cDropID         NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep,@nInputKey  
               ,@cFacility  
               ,@cStorerKey  
               ,@cPickSlipNo
               ,@cSuggestedLOC  
               ,@cSuggSKU  
               ,@nQTY  
               ,@cUCCNo
               ,@cDropID 
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  

      EXECUTE rdt.rdt_DynamicPick_PickUCC_Confirm @nMobile, @nFunc,@cLangCode, @cUserName,@cFacility,@cStorerKey,  
         @cSuggestedLOC,
         @cPickSlipNo,  
         @cSuggSKU,
         @cUCCNo,
         @cDropID,
         @nSuggQTY,
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
         GOTO Quit  
         
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) + ' @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey, ' +  
               ',@cFacility      ' +  
               ',@cStorerKey     ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cSuggSKU       ' +  
               ',@nQTY           ' +  
               ',@cUCCNo         ' +  
               ',@cOption        ' +  
               ',@cDropID        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT'  
            SET @cSQLParam = '@nMobile INT, @nFunc INT, @cLangCode NVARCHAR( 3), @nStep INT,@nInputKey INT, ' +  
               ',@cFacility       NVARCHAR( 5)   ' +  
               ',@cStorerKey      NVARCHAR( 15)  ' +  
               ',@cPickSlipNo     NVARCHAR( 20)  ' +    
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cSuggSKU        NVARCHAR( 20)  ' +  
               ',@nQTY            INT        ' +  
               ',@cUCCNo          NVARCHAR( 20)  ' +  
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@cDropID         NVARCHAR( 20)  ' +  
               ',@nErrNo          INT OUTPUT ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep  
               ,@cFacility  
               ,@cStorerKey  
               ,@cPickSlipNo
               ,@cSuggestedLOC  
               ,@cSuggSKU  
               ,@nQTY  
               ,@cUCCNo  
               ,@cOption 
               ,@cDropID
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Get next task to pick  
      SET @nErrNo = 0  
      EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextSKU',   
         @cPickSlipNo,  
         @cSuggestedLOC OUTPUT,
         @cSuggSKU OUTPUT,
         @nSuggQTY OUTPUT,
         @cUCCNo  OUTPUT,
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT
         

      IF @nErrNo=0 -- More task on same LOC  
      BEGIN  
         SELECT @cSuggSKUDescr=DESCR
         FROM dbo.SKU (NOLOCK)
         WHERE SKU=@cSuggSKU

         SET @cOutField01 = @cSuggSKU  
         SET @cOutField02 = SUBSTRING( @cSuggSKUDescr, 1, 20)  
         SET @cOutField03 = SUBSTRING( @cSuggSKUDescr, 21, 20)  
         SET @cOutField04 = @cUCCNo  
         SET @cOutField05 = '' -- UCC  
         SET @cOutField06 = CAST( @nSuggQTY AS NVARCHAR( 5))  
         
         SET @nStep=@nStep-2
         SET @nScn=@nScn-2
         GOTO QUIT
      END  
      ELSE
      BEGIN
         -- Get next task to pick  
         SET @nErrNo = 0  
         EXECUTE rdt.rdt_DynamicPick_PickUCC_GetNextTask @nMobile, @nFunc, @cLangCode,@nStep,@nInputKey,@cFacility,@cStorerKey,'NextLoc',   
            @cPickSlipNo,  
            @cSuggestedLOC OUTPUT,
            @cSuggSKU OUTPUT,
            @nSuggQTY OUTPUT,
            @cUCCNo  OUTPUT,
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  
           
         IF @nErrNo=0 -- More task on same LOC  
         BEGIN  
            -- Clear next screen variable  
            SET @cOutField01 = @cPickSlipNo
            SET @cOutField02 = @cSuggestedLOC  
            SET @cOutField03 = '' -- LOC  
  
            -- Go to next screen  
            SET @nScn  = @nScn - 3  
            SET @nStep = @nStep - 3  
  
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
            GOTO QUIT
         END  
         ELSE
         BEGIN
            SET @cOutField01 =''

            -- Go to next screen  
            SET @nScn  = @nScn - 4
            SET @nStep = @nStep - 4 

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNO
            GOTO QUIT
         END
      END
   END
   
   IF @nInputkey=0
   BEGIN
      SELECT @cSuggSKUDescr=DESCR
      FROM dbo.SKU (NOLOCK)
      WHERE SKU=@cSuggSKU

      SET @cOutField01 = @cSuggSKU  
      SET @cOutField02 = SUBSTRING( @cSuggSKUDescr, 1, 20)  
      SET @cOutField03 = SUBSTRING( @cSuggSKUDescr, 21, 20)  
      SET @cOutField04 = @cUCCNo  
      SET @cOutField05 = '' -- UCC  
      SET @cOutField06 = CAST( @nSuggQTY AS NVARCHAR( 5))  
         
      SET @nStep=@nStep-2
      SET @nScn=@nScn-2
   END
  
   Step_5_Fail:  
   BEGIN  
      SET @cDropID = ''  
      SET @cOutField02 = '' --Option  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
      ErrMsg   = @cErrMsg,  
      Func     = @nFunc,  
      Step     = @nStep,  
      Scn      = @nScn,  
  
      StorerKey  = @cStorerKey,  
      Facility   = @cFacility,  
      Printer    = @cPrinter,  
  
      V_SKU       = @cSuggSKU,  
      V_SKUDescr  = @cSuggSKUDescr,  
      V_LOC        = @cSuggestedLOC,  
      V_QTY        = @nQTY,  
  
      V_String1    = @cPickSlipNo,  
      V_String2    = @cZone,  
      V_String3    = @cLoc,   
      V_String7    = @cDecodeLabelNo,  
      V_String8    = @cExtendedUpdateSP,  
      V_String9    = @cExtendedValidateSP,
      V_String10   = @cLoadKey,
      V_String11   = @cOrderKey,
      V_String12   = @cSuggSKU,
      V_String13   = @cUCCNo,
      V_String14   = @cDropid,
      V_String15   = @cSwapUCCSP,

      V_Integer1  = @nSuggQTY,
  
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