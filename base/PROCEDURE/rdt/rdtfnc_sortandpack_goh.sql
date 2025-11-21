SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store procedure: rdtfnc_SortAndPack_GOH                              */          
/* Copyright      : IDS                                                 */          
/*                                                                      */          
/* Purpose: Sort, then pick and pack                                    */          
/*                                                                      */          
/* Modifications log:                                                   */          
/*                                                                      */          
/* Date       Rev  Author   Purposes                                    */          
/* 2012-12-06 1.0  James    SOS262234 Created                           */          
/* 2013-04-26 1.1  James    SOS276422 Use config to filter GOH (james01)*/      
/* 2013-05-15 1.2  James    SOS277324 Add Store No screen (james02)     */      
/* 2013-08-27 1.3  James    SOS287522 - Exclude Orders with UD04 = 'M'  */      
/*                                      (james03)                       */      
/* 2013-11-13 1.4  ChewKP   Addtional Validation (ChewKP01)             */      
/* 2014-01-02 1.5  James    SOS299487 - Add decode label (james04)      */ 
/* 2016-09-30 1.6  Ung      Performance tuning                          */   
/* 2018-11-14 1.7  Gan      Performance tuning                          */   
/* 2020-04-21 1.8  YeeKung  WMS-12853 remove all customize (yeekung01)  */      
/************************************************************************/          
          
CREATE PROC [RDT].[rdtfnc_SortAndPack_GOH] (          
   @nMobile    INT,          
   @nErrNo     INT  OUTPUT,          
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max          
) AS          
          
SET NOCOUNT ON          
SET ANSI_NULLS OFF          
SET QUOTED_IDENTIFIER OFF          
SET CONCAT_NULL_YIELDS_NULL OFF          
          
-- Misc variable          
DECLARE @b_Success INT,           
   @cExtendedInfo NVARCHAR(20),          
   @cSQL          NVARCHAR(1000),           
   @cSQLParam     NVARCHAR(1000)          
          
-- RDT.RDTMobRec variable          
DECLARE          
   @nFunc       INT,          
   @nScn        INT,          
   @nStep       INT,          
   @cLangCode   NVARCHAR( 3),          
   @nInputKey   INT,          
   @nMenu       INT,          
          
   @cStorerKey  NVARCHAR( 15),          
   @cFacility   NVARCHAR( 5),          
   @cUserName   NVARCHAR(18),          
   @cPrinter    NVARCHAR(10),          
          
   @cLoadKey    NVARCHAR( 10),          
   @cSKU        NVARCHAR( 20),          
   @cSKUDescr   NVARCHAR( 60),          
   @cConsigneeKey NVARCHAR( 15),          
   @cOrderKey   NVARCHAR( 10),           
   @cLabelNo    NVARCHAR( 20),          
   @nExpQTY     INT,     
   @cUPC        NVARCHAR( 20),      
          
   @nConsCNT_Total   INT,           
   @nConsCNT_Bal     INT,           
   @nConsQTY_Total   INT,           
   @nConsQTY_Bal     INT,           
   @nOrderQTY_Total  INT,           
   @nOrderQTY_Bal    INT,           
   @nSKUQTY_Total    INT,           
   @nSKUQTY_Bal      INT,           
   @cLabelNoChkSP    NVARCHAR( 20),          
   @cPackByType      NVARCHAR( 10),          
   @nPackQTY         INT,          
   @cDefaultQTY      NVARCHAR( 5),           
   @cDisableQTYField NVARCHAR( 1),          
   @cDisableSKUField NVARCHAR( 1),          
   @cExtendedInfoSP  NVARCHAR(20),           
   @cAllowSkipTask   NVARCHAR( 1),           
      
   @cPrevOrderKey             NVARCHAR( 10),    
         
   @cRemoveConsigneePrefix    NVARCHAR( 5),       
   @cBUSR10                   NVARCHAR( 30),       
   @cCartonType               NVARCHAR( 10),       
   @cPickSlipNo               NVARCHAR( 10),       
   @cDefaultCartonType        NVARCHAR( 10),       
   @cDecodeLabelNo            NVARCHAR( 20),      
   @cDistCtr                  NVARCHAR( 4),      
   @cSection                  NVARCHAR( 1),      
   @cSeparate                 NVARCHAR( 1),      
   @cSuggestedSKU             NVARCHAR( 20),      
@nTranCount                INT,       
   @nCartonNo                 INT,       
   @nPrevScn                  INT,       
   @nPrevStp                  INT,       
   @nTActQTY      INT,      
   @nTExpQTY                  INT,      
   @nTPackQTY                 INT,      
   @nRowCnt                   INT,       
   @nScannedQTY               INT,       
   @nSumPicked                INT,                    
   @nSumPacked                INT,                    
   @nCtnQTY_Total             INT,            -- (james02)        
   @nUnPickQTY                INT,            -- (james02)        
   @nPickedQTY                INT,            -- (james02)        
   @nPrevSKUQTY_Total         INT,            -- (james02)        
         
   @cSortAndPackFilterGOH     NVARCHAR( 1),   -- (james01)      
   @cConvertQtySP             NVARCHAR( 20),  -- (james01)      
   @cStoreNo                  NVARCHAR( 15),  -- (james01)      
   @cDecodeSKU                NVARCHAR(20),   -- (james04)      
   @cExtendedInfo2            NVARCHAR(20),   -- (yeekung01)    
   @cPreventManualInput       NVARCHAR( 1), --(yeekung01)    
   @cExtendedUpdateSP         NVARCHAR(20), --(yeekung01)    
   @cSortAndPackConfirmSP     NVARCHAR(20), --(yeekung01)    
   @cSortAndPackGetTaskSP     NVARCHAR(20), --(yeekung01)    
      
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
      
DECLARE      
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),      
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),      
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),      
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),      
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)       
         
-- Load RDT.RDTMobRec          
SELECT          
   @nFunc       = Func,          
   @nScn        = Scn,          
   @nStep       = Step,          
   @nInputKey   = InputKey,          
   @nMenu       = Menu,          
   @cLangCode = Lang_code,          
          
   @cStorerKey  = StorerKey,          
   @cFacility   = Facility,          
   @cUserName   = UserName,          
   @cPrinter    = Printer,          
          
   @cLoadKey      = V_LoadKey,          
   @cSKU          = V_SKU,          
   @cSKUDescr     = V_SKUDescr,          
   @cConsigneeKey = V_ConsigneeKey,          
   @cOrderKey     = V_OrderKey,           
   @cLabelNo      = V_CaseID,          
  -- @nExpQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,  
  
   @nCartonNo     = V_Cartonno,
  
   @nExpQTY          = V_Integer1,
   @nScannedQTY      = V_Integer2,
   @nOrderQTY_Total  = V_Integer3,
   @nOrderQTY_Bal    = V_Integer4,
   @nSKUQTY_Total    = V_Integer5,
   @nSKUQTY_Bal      = V_Integer6,
   @nPackQTY         = V_Integer7,
   @cCartonType      = V_Integer8,
    
  -- @nScannedQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1,  5), 0) = 1 THEN LEFT( V_String1,  5) ELSE 0 END,    
  -- @nOrderQTY_Total  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5,  5), 0) = 1 THEN LEFT( V_String5,  5) ELSE 0 END,    
  -- @nOrderQTY_Bal    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,    
  -- @nSKUQTY_Total    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7,  5), 0) = 1 THEN LEFT( V_String7,  5) ELSE 0 END,    
  -- @nSKUQTY_Bal      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8,  5), 0) = 1 THEN LEFT( V_String8,  5) ELSE 0 END,    
  -- @nPackQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,            
   @cLabelNoChkSP    = V_String10,          
   @cPackByType      = V_String11,          
   @cDefaultQTY      = V_String12,          
   @cDisableQTYField = V_String13,          
   @cDisableSKUField = V_String14,          
   @cExtendedInfoSP  = V_String15,           
   @cAllowSkipTask   = V_String16,           
         
   @cRemoveConsigneePrefix = V_String17,       
   @cPickSlipNo            = V_String18,       
   @nCartonNo              = V_String19,        
   @cCartonType            = V_String20,     
   @cDefaultCartonType     = V_String21,       
   @cExtendedInfo          = V_String22,       
   @cSuggestedSKU          = V_String23,       
   @cSortAndPackFilterGOH  = V_String24,  -- (james01)      
   @cConvertQtySP          = V_String25,  -- (james01)      
   @cStoreNo               = V_String26,  -- (james02)      
   @cExtendedInfo2         = V_String27,  -- (yeekung01)     
   @cPreventManualInput    = V_String28,  -- (yeekung01)     
   @cExtendedUpdateSP      = V_String29,  -- (yeekung01)    
   @cSortAndPackConfirmSP  = V_String30,  -- (yeekung01)    
   @cSortAndPackGetTaskSP  = V_String31,    
             
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
          
FROM RDTMOBREC (NOLOCK)          
WHERE Mobile = @nMobile          
          
-- Redirect to respective screen          
IF @nFunc = 542          
BEGIN          
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 542          
   IF @nStep = 1 GOTO Step_1   -- Scn = 3310. LoadKey          
   IF @nStep = 2 GOTO Step_2   -- Scn = 3311. Store No          
   IF @nStep = 3 GOTO Step_3   -- Scn = 3312. Label          
   IF @nStep = 4 GOTO Step_4   -- Scn = 3313. QTY          
   IF @nStep = 5 GOTO Step_5   -- Scn = 3314. Message. SKU completed          
   IF @nStep = 6 GOTO Step_6   -- Scn = 3315. Option. Exit packing?          
   IF @nStep = 7 GOTO Step_7   -- Scn = 3316. Carton Type          
END          
RETURN -- Do nothing if incorrect step          
          
          
/********************************************************************************          
Step 0. Called from menu          
********************************************************************************/          
Step_0:          
BEGIN          
   -- Set the entry point          
   SET @nScn = 3310          
   SET @nStep = 1          
          
   -- Init var          
          
   -- Get StorerConfig          
   SET @cAllowSkipTask = rdt.RDTGetConfig( @nFunc, 'AllowSkipTask', @cStorerKey)          
   SET @cPackByType = rdt.RDTGetConfig( @nFunc, 'PackByType', @cStorerKey)          
   SET @cLabelNoChkSP = rdt.RDTGetConfig( @nFunc, 'LabelNoChkSP', @cStorerKey)          
   IF @cLabelNoChkSP = '0'          
      SET @cLabelNoChkSP = ''          
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)          
   IF @cExtendedInfoSP = '0'          
      SET @cExtendedInfoSP = ''          
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)          
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)          
   SET @cDisableSKUField = rdt.RDTGetConfig( @nFunc, 'DisableSKUField', @cStorerKey)          
      
   -- (james02)      
   SET @cRemoveConsigneePrefix = rdt.RDTGetConfig( @nFunc, 'RemoveConsigneePrefix', @cStorerKey)             
   SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)      
      
   -- (james01)      
   SET @cSortAndPackFilterGOH = ''      
   SET @cSortAndPackFilterGOH = rdt.RDTGetConfig( @nFunc, 'SortAndPackFilterGOH', @cStorerKey)      
      
   -- (james01)      
   SET @cConvertQtySP = ''      
   SET @cConvertQtySP = rdt.RDTGetConfig( @nFunc, 'ConvertQtySP', @cStorerKey)        
    
   --(yeekung01)    
   SET @cPreventManualInput = rdt.RDTGetConfig( @nFunc, 'PreventManualInput', @cStorerKey)     
    
   --(yeekung01)    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)        
   IF @cExtendedUpdateSP = '0'        
      SET @cExtendedUpdateSP = ''            
   SET @cSortAndPackConfirmSP = rdt.RDTGetConfig( @nFunc, 'SAPConfirmSP', @cStorerKey)    
   IF @cSortAndPackConfirmSP = '0'        
      SET @cSortAndPackConfirmSP = ''    
   SET @cSortAndPackGetTaskSP = rdt.RDTGetConfig( @nFunc, 'SAPGetTaskSP', @cStorerKey)    
   IF @cSortAndPackGetTaskSP = '0'        
      SET @cSortAndPackGetTaskSP = ''    
    
   -- Logging          
   EXEC RDT.rdt_STD_EventLog          
      @cActionType = '1', -- Sign in function          
      @cUserID     = @cUserName,          
      @nMobileNo   = @nMobile,          
      @nFunctionID = @nFunc,          
      @cFacility   = @cFacility,          
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep         
          
   -- Prep next screen var          
   SET @cLoadKey = ''          
   SET @cOutField01 = ''  -- LoadKey          
          
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
          
   EXEC rdt.rdtSetFocusField @nMobile, 1          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 1. Screen = 3310          
   LOADKEY   (Field01, input)          
********************************************************************************/          
Step_1:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cLoadKey = @cInField01          
          
      -- Check blank          
      IF @cLoadKey = ''          
      BEGIN          
         SET @nErrNo = 78151          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need LoadKey          
         GOTO Step_1_Fail          
      END          
          
      -- Check valid          
      IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)          
      BEGIN          
         SET @nErrNo = 78152        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLoadKey          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Step_1_Fail          
      END          
          
      -- Check load plan status          
      IF EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Status = '9') -- 9=Closed          
      BEGIN          
         SET @nErrNo = 78153          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LoadKey Closed          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Step_1_Fail          
      END          
      
      IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)       
                     WHERE LoadKey = @cLoadKey      
                     AND   StorerKey = @cStorerKey)      
      BEGIN          
         SET @nErrNo = 78173          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLoadKey          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Step_1_Fail          
      END          
      
      -- (ChewKP01)      
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Facility = @cFacility )       
      BEGIN      
         SET @nErrNo = 78175          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffFacility          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Step_1_Fail        
      END      
            
      -- (ChewKP01)       
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey      
                      WHERE LPD.LoadKey = @cLoadKey      
                      AND O.StorerKey = @cStorerKey )       
      BEGIN      
         SET @nErrNo = 78176          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffStorer          
         EXEC rdt.rdtSetFocusField @nMobile, 3         
         GOTO Step_1_Fail        
      END      
      
      -- Prep next screen var          
      SET @cOutField01 = @cLoadKey          
      SET @cOutField02 = '' -- Store No          
          
      SET @nScn  = @nScn + 1          
      SET @nStep = @nStep + 1          
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
      SET @cLoadKey = ''          
      SET @cOutField01 = ''          
   END          
END          
GOTO Quit          
      
/********************************************************************************          
Step 2. Screen 3311          
   SKU      (Field01)          
   DESC1    (Field02)          
   DESC2    (Field03)          
   STORE    (Field04)          
   ORDERKEY (Field05)          
   LABELNO  (Field06, input)          
   STOR BAL (Field07)          
   SKU  BAL (Field08)          
********************************************************************************/     
Step_2:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cStoreNo = @cInField02        
            
      IF ISNULL(@cStoreNo, '') = ''      
      BEGIN      
         SET @nErrNo = 78170          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- STORE IS REQ          
         GOTO Step_2_Fail          
      END      
      
      --IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        --(yeekung01)    
      --               JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)      
      --               JOIN dbo.Orderdetail OD WITH (NOLOCK) ON (O.OrderKey=OD.orderkey)    
      --               WHERE LPD.LoadKey = @cLoadKey      
      --               AND   (REPLACE(O.ConsigneeKey, 'ITX', '') = @cStoreNo OR OD.userdefine02=@cStoreNo))      
      --BEGIN      
      --   SET @nErrNo = 78171          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INVALID STORE       
      --   GOTO Step_2_Fail          
      --END      
          
      -- Extended info (Get Gen Label)           
      IF @cExtendedInfoSP <> ''          
      BEGIN          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')          
         BEGIN          
            SET @cExtendedInfo = @cStoreNo     
            SET @cLabelNo =''        
                      
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +           
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +      
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' +     
               ' ,@nMobile'     
            SET @cSQLParam =          
               '@cLoadKey        NVARCHAR( 10), ' +          
               '@cOrderKey       NVARCHAR( 10), ' +       
               '@cConsigneeKey   NVARCHAR( 15), ' +          
               '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +          
               '@cStorer         NVARCHAR( 15), ' +            
               '@cSKU            NVARCHAR( 20), ' +            
               '@nExpQTY         INT,       ' +            
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +      
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +      
               '@cLangCode       NVARCHAR( 3),         ' +      
               '@bSuccess        INT           OUTPUT, ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@nMobile         INT '            
                      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT      
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
               , @nMobile    
    
            ---- Prepare extended fields          
--IF @cExtendedInfo <> ''     
            --   SET @cLabelNo = @cExtendedInfo     
                   
            IF @nErrNo <>0     
            BEGIN        
               GOTO Step_2_Fail          
            END           
         END          
      END    
      
      -- Prep next screen var          
      SET @cOutField01 = @cStoreNo          
      SET @cOutField02 = @cLabelNo -- Label No      
          
      IF  (@cPreventManualInput ='1')    
      BEGIN    
         SET @cFieldAttr02 = CASE WHEN   ISNULL(@cLabelNo,'') <>'' THEN 'O' ELSE '' END    
         SET @cSuggestedSKU =''    
         SET @cInField02 =@cLabelNo    
      END     
          
      SET @nScn  = @nScn + 1          
      SET @nStep = @nStep + 1                
   END      
      
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      SET @cLoadKey = ''          
                
      -- Prepare prev screen var          
      SET @cOutField01 = ''          
       
      -- Go to LoadKey screen          
      SET @nScn  = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
   GOTO Quit          
          
   Step_2_Fail:          
   BEGIN          
      SET @cStoreNo = ''          
      SET @cOutField02 = ''          
   END          
END      
GOTO Quit      
      
/********************************************************************************          
Step 3. Screen 3312          
   SKU      (Field01)          
   DESC1    (Field02)          
   DESC2    (Field03)          
   STORE    (Field04)          
   ORDERKEY (Field05)          
   LABELNO  (Field06, input)          
   STOR BAL (Field07)          
   SKU  BAL (Field08)          
********************************************************************************/          
Step_3:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cLabelNo = @cInField02          
          
      -- Get next task          
      IF @cLabelNo = ''          
      BEGIN          
         SET @nErrNo = 78154          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Label No          
         GOTO Step_3_Fail          
      END          
      
      -- Decode label      
      SET @cDecodeLabelNo = ''          
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)          
      
      IF ISNULL(@cDecodeLabelNo,'') <> ''          
      BEGIN          
         EXEC dbo.ispLabelNo_Decoding_Wrapper          
          @c_SPName     = @cDecodeLabelNo          
         ,@c_LabelNo    = @cLabelNo          
         ,@c_Storerkey  = @cStorerkey          
         ,@c_ReceiptKey = @nMobile          
         ,@c_POKey      = ''          
         ,@c_LangCode   = @cLangCode          
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- DistCtr          
         ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- Consignee          
         ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- Section          
         ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- Separate          
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
          
         SET @cDistCtr = @c_oFieled01          
         SET @cConsigneeKey = @c_oFieled02          
         SET @cSection = @c_oFieled03      
         SET @cSeparate = @c_oFieled04      
      END          
      
      --IF (ISNULL(@cConsigneeKey, '') <> '') AND (REPLACE( @cConsigneeKey, 'ITX', '') <> @cStoreNo)      
      --BEGIN          
      --   SET @nErrNo = 78172          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --STOR NOT MATCH          
      --   GOTO Step_3_Fail          
      --END          
                  
      -- LabelNo extended validation          
      IF @cLabelNoChkSP <> ''          
      BEGIN          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cLabelNoChkSP AND type = 'P')          
         BEGIN          
            SET @cExtendedInfo = ''          
            SET @cSKU = '' -- At this point no sku yet      
                      
            SET @cSQL = 'EXEC ' + RTRIM( @cLabelNoChkSP) +           
               ' @nMobile, @nFunc, @cLangCode, @cLoadKey, @cConsigneeKey, @cStorerKey, @cSKU, @cLabelNo , @nErrNo OUTPUT, @cErrMsg OUTPUT'          
            SET @cSQLParam =          
               '@nMobile       INT,        ' +          
               '@nFunc         INT,        ' +          
               '@cLangCode     NVARCHAR(3),    ' +          
               '@cLoadKey      NVARCHAR( 10),  ' +          
               '@cConsigneeKey NVARCHAR( 15),  ' +          
               '@cStorerKey    NVARCHAR(15),   ' +          
               '@cSKU          NVARCHAR(20),   ' +          
               '@cLabelNo      NVARCHAR( 20),  ' +          
               '@nErrNo        INT OUTPUT, ' +            
               '@cErrMsg       NVARCHAR( 20) OUTPUT'          
                      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
               @nMobile, @nFunc, @cLangCode, @cLoadKey, @cConsigneeKey, @cStorerKey, @cSKU, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT          
          
            IF @nErrNo <> 0          
            BEGIN          
               SET @nErrNo = 78155          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo          
               GOTO Step_3_Fail          
            END          
         END          
      END          
    
      SET @cOrderKey=''    
      
      --SELECT TOP 1 @cOrderKey = orderKey       
      --FROM dbo.Orders WITH (NOLOCK)      
      --WHERE StorerKey = @cStorerKey      
      --AND   LoadKey = @cLoadKey      
      --AND   SectionKey = @cSection      
      --AND   UserDefine02 = @cSeparate      
      --AND   Consigneekey = @cConsigneeKey      
      
      --SELECT @nRowCnt = @@ROWCOUNT    
    
      --IF (@nRowCnt=0)    
      --BEGIN    
    
      --   SET @cConsigneeKey=@cStoreNo    
    
      --   SELECT TOP 1 @cOrderKey = OD.orderKey     
      --   FROM dbo.Orders O WITH (NOLOCK)  JOIN    
      --   dbo.OrderDetail OD WITH (NOLOCK) ON O.orderkey=OD.orderkey    
      --   WHERE O.StorerKey = @cStorerKey      
      --   AND   O.LoadKey = @cLoadKey     
      --   AND   OD.userdefine02=@cStoreNo     
      --END    
    
      --IF @nRowCnt > 1      
      --BEGIN      
      --   SET @nErrNo = 78156          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --> 1 ORDERS          
      --   GOTO Step_3_Fail          
      --END      
      
      --IF ISNULL(@cOrderKey, '') = ''      
      --BEGIN      
      --   SET @nErrNo = 78157          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO ORDERKEY         
      --   GOTO Step_3_Fail          
      --END      
      
      -- Get the first suggested sku      
--      SELECT TOP 1 @cSuggestedSKU = PD.SKU       
--      FROM dbo.PickDetail PD WITH (NOLOCK)       
--      JOIN dbo.SKU S WITH (NOLOCK) ON PD.SKU = S.SKU AND PD.StorerKey = S.StorerKey      
--      WHERE PD.StorerKey = @cStorerKey      
--      AND   PD.OrderKey = @cOrderKey      
--      AND   PD.Status = '0'      
--      AND   S.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE S.Measurement END   -- (james01)      
      
      -- Get next task          
    
      --EXEC rdt.rdt_SortAndPack_GOH_GetTask @nMobile, @nFunc, @cLangCode, @cStorerKey, @cLabelNo, @cSuggestedSKU, @cLoadKey, @cOrderKey      
      --   ,@nExpQTY         OUTPUT          
      --   ,@nOrderQTY_Total OUTPUT          
      --   ,@nOrderQTY_Bal   OUTPUT          
      --   ,@nSKUQTY_Total   OUTPUT          
      --   ,@nSKUQTY_Bal     OUTPUT         
      --   ,@nScannedQTY     OUTPUT      
      --   ,@nCtnQTY_Total   OUTPUT      
      --   ,@nUnPickQTY      OUTPUT      
      --   ,@nPickedQTY      OUTPUT      
      --   ,@nErrNo          OUTPUT          
      --   ,@cErrMsg         OUTPUT          
      --IF @nErrNo <> 0          
      --   GOTO Step_3_Fail          
      
      --IF @nExpQTY > 0      
      --   SET @cSKU = @cSuggestedSKU      
      --ELSE      
      --BEGIN      
      --   SET @nErrNo = 78165          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO TASK         
      --   GOTO Step_3_Fail          
      --END      
            
      ---- Get PickSlipNo (PickHeader)        
      --SET @cPickSlipNo = ''        
      --SELECT @cPickSlipNo = PickHeaderKey        
      --FROM dbo.PickHeader WITH (NOLOCK)        
      --WHERE ExternOrderKey = @cLoadKey        
      --   AND OrderKey = @cOrderKey        
      
      --IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)        
      --BEGIN        
      --   -- Get PickSlipNo (PackHeader)        
      --   DECLARE @cPSNO NVARCHAR( 10)        
      --   SET @cPSNO = ''        
      --   SELECT @cPSNO = PickSlipNo        
      --   FROM dbo.PackHeader WITH (NOLOCK)        
      --   WHERE LoadKey = @cLoadKey        
      --      AND OrderKey = @cOrderKey        
      
      --   IF @cPSNO <> ''        
      --      SET @cPickSlipNo = @cPSNO        
      --END      
      
      SET @nCartonNo = 0      
      SELECT TOP 1 @nCartonNo = ISNULL(CartonNo, 0)      
      FROM dbo.PackDetail WITH (NOLOCK)       
      WHERE PickSlipNo = @cPickSlipNo      
      AND   LabelNo = @cLabelNo      
      AND   StorerKey = @cStorerKey      
      
      -- If packinfo not exists then goto capture carton type screen      
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)       
                     WHERE PickSlipNo = @cPickSlipNo       
                     AND   CartonNo = @nCartonNo)      
      BEGIN      
         -- Remember current screen      
         SET @nPrevScn = @nScn      
         SET @nPrevStp = @nStep      
      
         -- Prepare next screen      
         SET @cOutField01 = @cLoadKey          
         SET @cOutField02 = @cOrderKey          
         SET @cOutField03 = @cLabelNo          
         SET @cOutField04 = CASE WHEN ISNULL(@cDefaultCartonType, '') <> '' THEN @cDefaultCartonType ELSE '' END       
         SET @cOutField05 = ''          
         SET @cOutField06 = ''          
         SET @cOutField07 = ''          
         SET @cOutField08 = ''          
         SET @cOutField09 = ''          
         SET @cOutField10 = ''          
         SET @cOutField11 = ''          
         SET @cOutField12 = ''          
         SET @cOutField13 = ''          
            
         -- Go to QTY screen          
         SET @nScn  = @nScn + 4          
         SET @nStep = @nStep + 4      
               
         GOTO Quit          
      END      
      
      -- Extended info          
      IF @cExtendedInfoSP <> ''          
      BEGIN          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')          
         BEGIN          
            SET @cExtendedInfo = ''          
                      
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +           
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +      
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' +     
               ' ,@nMobile'     
            SET @cSQLParam =          
               '@cLoadKey        NVARCHAR( 10), ' +          
               '@cOrderKey       NVARCHAR( 10), ' +       
               '@cConsigneeKey   NVARCHAR( 15), ' +          
               '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +          
               '@cStorer         NVARCHAR( 15), ' +            
               '@cSKU            NVARCHAR( 20), ' +            
               '@nExpQTY         INT,       ' +            
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +      
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +      
               '@cLangCode       NVARCHAR( 3),         ' +      
               '@bSuccess        INT           OUTPUT, ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@nMobile         INT '            
                      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT      
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
               , @nMobile          
          
            -- Prepare extended fields          
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo          
         END          
      END          
            
      -- Get SKU info          
      SELECT       
         @cSKUDescr = Descr,       
         @cBUSR10 = BUSR10    -- (james02)      
      FROM dbo.SKU WITH (NOLOCK)       
      WHERE StorerKey = @cStorerKey       
      AND   SKU = @cSKU         
      
      -- Prepare next screen var          
      SET @nPackQTY = 0          
      SET @cOutField01 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END      
      SET @cOutField02 = @cOrderKey          
      SET @cOutField04 = @cLabelNo          
      SET @cOutField05 = ''      
      SET @cOutField06 = CASE WHEN @cDefaultQTY >= '1' THEN @cDefaultQTY ELSE '' END --ActQTY          
      --SET @cOutField07 = @nScannedQTY      
      --SET @cOutField08 = '0/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))  --**       
      SET @cOutField08 = CAST( @nOrderQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(5))      
      SET @cOutField09 = CAST( @nOrderQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(5))      
      SET @cOutField10 = ''--@cExtendedInfo          
      SET @cOutField11 = CAST( @nCtnQTY_Total AS NVARCHAR(5))      
      
      -- Diable Qty field. Only when config turn on and default qty set >=1      
      SET @cFieldAttr06 = CASE WHEN @cDisableQtyField = '1' AND @cDefaultQTY >= '1' THEN 'O' ELSE '' END      
            
      -- Go to QTY screen          
      SET @nScn  = @nScn + 1          
      SET @nStep = @nStep + 1          
   END          
          
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      --SET @cConsigneeKey = 'ITX' + @cOutField01    
    
      SELECT @nPickedQTY=Sum(PD.qty)     
      FROM dbo.Pickdetail PD WITH (NOLOCK)       
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderlineNumber)      
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.StorerKey = O.StorerKey AND OD.OrderKey = O.OrderKey)      
      WHERE O.LoadKey = @cLoadKey      
      AND   O.StorerKey = @cStorerKey    
      AND   OD.Userdefine02=@cStoreNo    
      AND   PD.Status IN ('3', '5' )     
    
      SELECT @nPackQTY=Sum(PD.qty)      
      FROM dbo.PackDetail PD WITH (NOLOCK)           
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)          
      JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')           
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)          
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)          
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)          
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)          
      WHERE LPD.LoadKey = @cLoadKey        
      AND   O.StorerKey = @cStorerKey    
      AND   OD.Userdefine02=@cStoreNo    
      
      -- Check if packing completed for this store      
      IF (@nPackQTY <>@nPickedQTY)    
      BEGIN          
         -- If still got outstanding task not complete then goto screen 6      
         -- Prepare prev screen var          
         SET @cOutField01 = '' --Option    
         SET @cFieldAttr02 =''    
                   
         -- Go to Exit packing screen          
         SET @nScn  = @nScn + 3          
         SET @nStep = @nStep + 3          
      END          
      ELSE          
      BEGIN    
          
         IF @cExtendedUpdateSP <> ''        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +         
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +         
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'        
               SET @cSQLParam =        
                  '@nMobile        INT,            ' +        
                  '@nFunc          INT,            ' +        
                  '@cLangCode      NVARCHAR(3),    ' +        
                  '@nStep          INT,            ' +        
                  '@cUserName      NVARCHAR( 18),  ' +         
                  '@cFacility      NVARCHAR( 5),   ' +         
                  '@cStorerKey     NVARCHAR( 15),  ' +         
                  '@cLabelPrinter  NVARCHAR( 10),  ' +         
                  '@cCloseCartonID NVARCHAR( 20),  ' +         
                  '@cLoadKey       NVARCHAR( 10),  ' +         
                  '@cLabelNo       NVARCHAR( 20),  ' +         
                  '@nErrNo         INT OUTPUT, ' +          
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'        
                       
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,        
                  @nErrNo OUTPUT, @cErrMsg OUTPUT        
              
               IF @nErrNo <> 0        
                  GOTO Step_3_Fail     
                       
            END        
         END      
         -- IF @cExtendedUpdateSP <> ''              
         -- Go to Packing completed screen     
         SET @cFieldAttr02 =''         
         SET @nScn  = @nScn + 2          
         SET @nStep = @nStep + 2          
      END          
   END          
   GOTO Quit          
          
   Step_3_Fail:          
          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 4. Screen 3313          
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
Step_4:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      DECLARE @cActQTY NVARCHAR(5)          
      DECLARE @nActQTY INT          
                
      -- Screen mapping          
      SET @cSKU = @cInField05    
      SET @cActQTY = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END      
      
      -- Decode SKU (james04)      
      SET @cDecodeSKU = ''          
      SET @cDecodeSKU = rdt.RDTGetConfig( @nFunc, 'DecodeSKU', @cStorerkey)          
      
      IF ISNULL(@cDecodeSKU,'') NOT IN ('', '0')          
      BEGIN          
         EXEC dbo.ispLabelNo_Decoding_Wrapper          
          @c_SPName     = @cDecodeSKU          
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
            GOTO Step_4_Fail          
         END          
          
         SET @cSKU = @c_oFieled01      -- assign output to sku code      
         SET @c_oFieled01 = ''         -- Reinitiase the variable      
      END             
    
      -- Check blank    
      IF ISNULL(@cSKU, '') = ''    
      BEGIN    
         SET @nErrNo = 78167    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU    
         GOTO Step_4_Fail    
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
         SET @nErrNo = 78168          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU          
         GOTO Step_4_Fail          
      END          
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)       
                      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
                      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)      
                      WHERE PD.StorerKey = @cStorerKey      
                      AND   PD.SKU = @cSKU      
                      AND   O.LoadKey = @cLoadKey      
                      AND   ISNULL(OD.UserDefine04, '') <> 'M') -- (james03)      
      BEGIN          
         SET @nErrNo = 78174          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn Load          
         GOTO Step_4_Fail          
      END          
            
      -- Validate barcode return multiple SKU          
      IF @nSKUCnt > 1          
      BEGIN          
         SET @nErrNo = 78169          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU          
         GOTO Step_4_Fail          
      END          
          
      -- Get SKU          
      EXEC [RDT].[rdt_GETSKU]          
          @cStorerKey  = @cStorerKey          
         ,@cSKU        = @cSKU          OUTPUT          
         ,@bSuccess    = @b_Success     OUTPUT          
         ,@nErr        = @nErrNo        OUTPUT          
         ,@cErrMsg     = @cErrMsg       OUTPUT                
          
      IF rdt.rdtIsValidQty( @cActQty, 1) = 0     
      BEGIN    
         SELECT TOP 1 @cOrderKey=OD.orderkey    
         FROM ORDERDETAIL OD(NOLOCK) JOIN ORDERS O (NOLOCK) ON    
         O.orderkey=OD.orderkey  JOIN PICKDETAIL PD (NOLOCK) ON   
         OD.orderkey=PD.orderkey and OD.orderlinenumber =PD.orderlinenumber  
      WHERE OD.SKU=@cSKU    
         AND OD.storerkey=@cStorerkey    
         AND O.loadkey=@cLoadkey    
         AND OD.userdefine02=@cStoreno    
         AND PD.pickdetailkey NOT IN (select refno   
                                       from packheader PH (NOLOCK) JOIN packdetail PD (NOLOCK)   
                                       ON PH.pickslipno=PD.pickslipno  
                                       where PH.loadkey=@cLoadkey and PD.storerkey=@cstorerkey and PD.SKU=@cSKU)  
    
         SET @nSKUQTY_Bal=0    
         SET @nOrderQTY_Bal=0    
    
         IF (@cSortAndPackGetTaskSP <>'')    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSortAndPackGetTaskSP AND type = 'P')          
            BEGIN               
                      
               SET @cSQL = 'EXEC ' +'rdt.'+ RTRIM( @cSortAndPackGetTaskSP) +           
                  ' @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo,@cSKU,@cOrderKey, @nExpQTY OUTPUT,'+    
                  ' @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,' +      
                  ' @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'      
               SET @cSQLParam =     
                  ' @nMobile         INT,'+            
                  ' @nFunc           INT,'+            
                  ' @cLangCode       NVARCHAR( 3),'+            
                  ' @cStorerKey      NVARCHAR( 15),'+           
                  ' @cLabelNo        NVARCHAR( 20),'+           
                  ' @cLoadKey        NVARCHAR( 20),'+    
                  ' @cStoreNo        NVARCHAR( 15),'+            
                  ' @cSKU            NVARCHAR( 20),'+           
                  ' @cOrderKey       NVARCHAR( 10),'+           
                  ' @nExpQTY         INT      OUTPUT,'+         
                  ' @nOrderQTY_Total INT      OUTPUT,'+         
                  ' @nOrderQTY_Bal   INT      OUTPUT,'+         
                  ' @nSKUQTY_Total   INT      OUTPUT,'+         
                  ' @nSKUQTY_Bal     INT      OUTPUT,'+         
                  ' @nScannedQTY     INT      OUTPUT,'+         
                  ' @nCtnQTY_Total   INT      OUTPUT,'+       
                  ' @nUnPickQTY      INT      OUTPUT,'+       
                  ' @nPickedQTY      INT      OUTPUT,'+       
                  ' @nErrNo          INT      OUTPUT,'+       
                  ' @cErrMsg         NVARCHAR( 20) OUTPUT'    
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
                @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo ,@cSKU,@cOrderKey, @nExpQTY OUTPUT,    
                @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,      
                @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                     
    
         END     
         END    
         ELSE    
         BEGIN    
            --Get next task          
            EXEC rdt.rdt_SortAndPack_GOH_GetTask @nMobile, @nFunc, @cLangCode, @cStorerKey, @cLabelNo, @cSuggestedSKU, @cLoadKey, @cOrderKey      
               ,@nExpQTY         OUTPUT          
               ,@nOrderQTY_Total OUTPUT          
               ,@nOrderQTY_Bal   OUTPUT          
               ,@nSKUQTY_Total   OUTPUT          
               ,@nSKUQTY_Bal     OUTPUT          
               ,@nScannedQTY     OUTPUT      
               ,@nCtnQTY_Total   OUTPUT      
               ,@nUnPickQTY      OUTPUT      
               ,@nPickedQTY      OUTPUT      
               ,@nErrNo          OUTPUT          
               ,@cErrMsg         OUTPUT          
            IF @nErrNo <> 0          
               GOTO Step_4_Fail     
         END         
      
         -- Get SKU info          
         SELECT       
            @cSKUDescr = Descr,       
            @cBUSR10 = BUSR10    -- (james02)      
         FROM dbo.SKU WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey       
         AND   SKU = @cSKU         
    
         IF @nExpQTY<=0    
         BEGIN          
            SET @nErrNo = 78177          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU          
            GOTO Step_4_Fail          
         END       
            
         -- Prepare next screen var          
         SET @nPackQTY = 0          
         SET @cOutField01 = @cStoreNo--CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END      
         SET @cOutField02 = @cOrderKey          
         SET @cOutField04 = @cLabelNo     
         SET @cInField05 = @cSKU           
         SET @cOutField05 = @cSKU      
         SET @cOutField06 = CASE WHEN @cDefaultQTY >= '1' THEN @cDefaultQTY ELSE '' END --ActQTY          
         --SET @cOutField07 = @nScannedQTY      
         SET @cOutField08 = CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))  --**       
         SET @cOutField09 = CAST( @nOrderQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(5))      
         SET @cOutField10 = ''--@cExtendedInfo          
         SET @cOutField11 = CAST( @nCtnQTY_Total AS NVARCHAR(5))      
      
         -- Diable Qty field. Only when config turn on and default qty set >=1      
         SET @cFieldAttr06 = CASE WHEN @cDisableQtyField = '1' THEN 'O' ELSE '' END    
         EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY     
              
         GOTO QUIT     
      END    
        
      -- Check valid QTY          
      IF rdt.rdtIsValidQty( @cActQty, 1) = 0          
      BEGIN          
         SET @nErrNo = 78158          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY          
         EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY          
         GOTO Step_4_Fail          
      END    
  
      IF (@cActQty+@nSKUQTY_Bal)> @nSKUQTY_Total-- @nSKUQTY_Total  
      BEGIN          
         SET @nErrNo = 78178          
         SET @cErrMsg =rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY          
         EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY          
         GOTO Step_4_Fail          
      END    
    
      ---- Check if Pack > Exp          
      --IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''      
      --BEGIN      
      --   IF (@cSortAndPackGetTaskSP <>'')    
      --   BEGIN    
      --      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSortAndPackGetTaskSP AND type = 'P')          
      --      BEGIN               
                      
      --         SET @cSQL = 'EXEC ' +'rdt.'+ RTRIM( @cSortAndPackGetTaskSP) +           
      --            ' @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo,@cSKU,@cOrderKey, @nExpQTY OUTPUT,'+    
      --            ' @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,' +      
      --            ' @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'      
      --         SET @cSQLParam =     
      --            ' @nMobile         INT,'+            
      --            ' @nFunc           INT,'+            
      --            ' @cLangCode       NVARCHAR( 3),'+            
      --            ' @cStorerKey      NVARCHAR( 15),'+           
      --            ' @cLabelNo        NVARCHAR( 20),'+           
      --            ' @cLoadKey        NVARCHAR( 20),'+    
      --            ' @cStoreNo        NVARCHAR( 15),'+            
      --            ' @cSKU            NVARCHAR( 20),'+           
      --            ' @cOrderKey       NVARCHAR( 10),'+           
      --            ' @nExpQTY         INT      OUTPUT,'+         
      --            ' @nOrderQTY_Total INT      OUTPUT,'+         
      --            ' @nOrderQTY_Bal   INT      OUTPUT,'+         
      --            ' @nSKUQTY_Total   INT      OUTPUT,'+         
      --            ' @nSKUQTY_Bal     INT      OUTPUT,'+         
      --            ' @nScannedQTY     INT      OUTPUT,'+         
      --            ' @nCtnQTY_Total   INT      OUTPUT,'+       
      --            ' @nUnPickQTY      INT      OUTPUT,'+       
      --            ' @nPickedQTY      INT      OUTPUT,'+       
      --            ' @nErrNo          INT      OUTPUT,'+       
      --            ' @cErrMsg         NVARCHAR( 20) OUTPUT'    
           
      --      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
      --          @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo ,@cSKU,@cOrderKey, @nExpQTY OUTPUT,    
      --          @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,      
      --          @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                     
    
      --   END     
      --   END    
      --   ELSE    
      --   BEGIN    
      --      --Get next task          
      --      EXEC rdt.rdt_SortAndPack_GOH_GetTask @nMobile, @nFunc, @cLangCode, @cStorerKey, @cLabelNo, @cSuggestedSKU, @cLoadKey, @cOrderKey      
      --         ,@nExpQTY         OUTPUT          
      --         ,@nOrderQTY_Total OUTPUT          
      --         ,@nOrderQTY_Bal   OUTPUT          
      --         ,@nSKUQTY_Total   OUTPUT          
      --         ,@nSKUQTY_Bal     OUTPUT          
      --         ,@nScannedQTY     OUTPUT      
      --         ,@nCtnQTY_Total   OUTPUT      
      --         ,@nUnPickQTY      OUTPUT      
      --         ,@nPickedQTY      OUTPUT      
      --         ,@nErrNo          OUTPUT          
      --         ,@cErrMsg         OUTPUT          
      --      IF @nErrNo <> 0          
      --         GOTO Step_4_Fail     
      --   END           
      
      --   SET @nTActQTY = CAST( @cActQTY AS INT)      
      --   SET @nTExpQTY = @nExpQTY      
      --   SET @nTPackQTY = CASE WHEN @nPackQTY > 0 THEN @nPackQTY ELSE 0 END      
      
      --   -- Convert qty          
      --   IF @cConvertQtySP <> ''          
      --   BEGIN          
      --      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQtySP AND type = 'P')          
      --      BEGIN          
      --         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +           
      --            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'          
      --         SET @cSQLParam =          
      --            '@cType      NVARCHAR( 10), ' +          
      --            '@cStorerKey NVARCHAR( 15), ' +          
      --            '@cSKU       NVARCHAR( 20), ' +            
      --            '@nQTY       INT OUTPUT    '       
                         
      --         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
      --            'ToBaseQTY', @cStorerkey, @cSKU, @nTActQTY OUTPUT          
      
      --         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +           
      --            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'          
      --         SET @cSQLParam =          
      --            '@cType      NVARCHAR( 10), ' +          
      --            '@cStorerKey NVARCHAR( 15), ' +          
      --            '@cSKU       NVARCHAR( 20), ' +            
      --            '@nQTY       INT OUTPUT    '       
                         
      --         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
      --            'ToBaseQTY', @cStorerkey, @cSKU, @nTExpQTY OUTPUT          
      
      --         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +           
      --            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'          
      --         SET @cSQLParam =          
      --            '@cType      NVARCHAR( 10), ' +          
      --            '@cStorerKey NVARCHAR( 15), ' +          
      --            '@cSKU       NVARCHAR( 20), ' +            
      --            '@nQTY       INT OUTPUT    '       
                         
      --         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
      --            'ToBaseQTY', @cStorerkey, @cSKU, @nTPackQTY OUTPUT          
      --      END          
      --   END          
            
      --   IF @nTActQTY <= 0 OR @nTExpQTY <= 0       
      --   BEGIN      
      --      SET @nErrNo = 78159          
      --      SET @cErrMsg = @cSKU--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY          
      --      EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY          
      --      GOTO Step_4_Fail          
      --   END      
      
      --   IF @nTPackQTY + @nTActQTY > @nTExpQTY          
      --   BEGIN          
      --      SET @nErrNo = 78160          
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY          
      --      EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY          
      --      GOTO Step_4_Fail          
      --   END          
      --   ELSE      
      --   BEGIN      
      --      -- Convert to base qty      
      --      SET @nPackQTY = @nTPackQTY      
      --      SET @cActQTY = @nTActQTY      
      --      SET @nExpQTY = @nTExpQTY      
      --   END      
      --END      
      --ELSE      
      --IF @nPackQTY + CAST( @cActQTY AS INT) > @nExpQTY          
      --BEGIN          
      --   SET @nErrNo = 78161          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack > ExpQTY          
      --   EXEC rdt.rdtSetFocusField @nMobile, 7 --QTY          
      --   GOTO Step_4_Fail          
      --END          
      
      SET @nActQTY = @cActQTY          
          
      IF (@cSortAndPackConfirmSP<>'')    
      BEGIN    
              
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSortAndPackConfirmSP AND type = 'P')          
         BEGIN               
                      
            SET @cSQL = 'EXEC ' +'rdt.'+ RTRIM( @cSortAndPackConfirmSP) +           
               ' @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cStoreNo, @cStorerKey, @cSKU, @nQTY, @cLabelNo, @cCartonType,' +      
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'      
            SET @cSQLParam =     
               '@nMobile       INT,'      +          
               '@nFunc         INT,'      +          
               '@cLangCode     NVARCHAR( 3),'+          
               '@cPackByType   NVARCHAR( 10),'+           
               '@cLoadKey      NVARCHAR( 10),'+          
               '@cOrderKey     NVARCHAR( 10),'+           
               '@cStoreNo      NVARCHAR( 15),'+          
               '@cStorerKey    NVARCHAR( 15),'+          
               '@cSKU          NVARCHAR( 20),'+          
               '@nQTY          INT,'+           
               '@cLabelNo      NVARCHAR( 20),'+          
               '@cCartonType   NVARCHAR( 10),'+             
               '@nErrNo        INT  OUTPUT,'+          
               '@cErrMsg       NVARCHAR( 20) OUTPUT'       
                      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
                @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cStoreNo, @cStorerKey, @cSKU, @nActQTY, @cLabelNo, @cCartonType      
               , @nErrNo OUTPUT, @cErrMsg OUTPUT     
    
            IF @nErrNo <> 0          
               GOTO Step_4_Fail      
         END              
      END    
      ELSE    
      BEGIN    
                
         -- Confirm task          
         EXEC rdt.rdt_SortAndPack_GOH_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @nActQTY, @cLabelNo, @cCartonType           
            ,@nErrNo        OUTPUT          
            ,@cErrMsg       OUTPUT          
         IF @nErrNo <> 0          
            GOTO Step_4_Fail         
      END     
                   
      -- Event log          
      EXEC RDT.rdt_STD_EventLog          
         @cActionType   = '3', -- Picking          
         @cUserID = @cUserName,          
         @nMobileNo     = @nMobile,          
         @nFunctionID   = @nFunc,          
         @cFacility     = @cFacility,          
         @cStorerKey    = @cStorerkey,          
         @cSKU          = @cSKU,          
         @nQTY          = @nActQTY,          
         @cLoadKey      = @cLoadKey,          
        	@cDropID       = @cLabelNo,
         @nStep         = @nStep       
      
      -- Set prev qty total b4 been overwrite      
      SET @nPrevSKUQTY_Total = @nSKUQTY_Total      
    
      IF (@cSortAndPackGetTaskSP <>'')    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSortAndPackGetTaskSP AND type = 'P')          
         BEGIN               
                      
            SET @cSQL = 'EXEC ' +'rdt.'+ RTRIM( @cSortAndPackGetTaskSP) +           
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo,@cSKU,@cOrderKey, @nExpQTY OUTPUT,'+    
               ' @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,' +      
               ' @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'      
            SET @cSQLParam =     
               ' @nMobile         INT,'+            
               ' @nFunc           INT,'+            
               ' @cLangCode       NVARCHAR( 3),'+            
               ' @cStorerKey      NVARCHAR( 15),'+           
               ' @cLabelNo        NVARCHAR( 20),'+           
               ' @cLoadKey        NVARCHAR( 20),'+    
               ' @cStoreNo        NVARCHAR( 15),'+            
               ' @cSKU            NVARCHAR( 20),'+           
               ' @cOrderKey       NVARCHAR( 10),'+           
               ' @nExpQTY         INT      OUTPUT,'+         
               ' @nOrderQTY_Total INT      OUTPUT,'+         
               ' @nOrderQTY_Bal   INT      OUTPUT,'+         
               ' @nSKUQTY_Total   INT      OUTPUT,'+         
               ' @nSKUQTY_Bal     INT      OUTPUT,'+         
               ' @nScannedQTY     INT      OUTPUT,'+         
               ' @nCtnQTY_Total   INT      OUTPUT,'+       
               ' @nUnPickQTY      INT      OUTPUT,'+       
               ' @nPickedQTY      INT      OUTPUT,'+       
               ' @nErrNo          INT      OUTPUT,'+       
               ' @cErrMsg         NVARCHAR( 20) OUTPUT'    
           
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
               @nMobile, @nFunc, @cLangCode, @cStorerKey,@cLabelNo, @cLoadKey,@cStoreNo ,@cSKU,@cOrderKey, @nExpQTY OUTPUT,    
               @nOrderQTY_Total OUTPUT,@nOrderQTY_Bal OUTPUT,@nSKUQTY_Total OUTPUT,@nSKUQTY_Bal  OUTPUT,@nScannedQTY OUTPUT,@nCtnQTY_Total OUTPUT,      
               @nUnPickQTY OUTPUT, @nPickedQTY  OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
      END     
      END    
      ELSE    
      BEGIN    
         --Get next task          
         EXEC rdt.rdt_SortAndPack_GOH_GetTask @nMobile, @nFunc, @cLangCode, @cStorerKey, @cLabelNo, @cSuggestedSKU, @cLoadKey, @cOrderKey      
            ,@nExpQTY         OUTPUT          
            ,@nOrderQTY_Total OUTPUT          
            ,@nOrderQTY_Bal   OUTPUT          
            ,@nSKUQTY_Total   OUTPUT          
            ,@nSKUQTY_Bal     OUTPUT          
            ,@nScannedQTY     OUTPUT      
            ,@nCtnQTY_Total   OUTPUT      
            ,@nUnPickQTY      OUTPUT      
            ,@nPickedQTY      OUTPUT      
            ,@nErrNo          OUTPUT          
            ,@cErrMsg         OUTPUT          
         IF @nErrNo <> 0          
     GOTO Step_4_Fail     
      END            
    
      IF @nExpQTY > 0 -- More task          
      BEGIN          
         -- Extended info          
         IF @cExtendedInfoSP <> ''          
         BEGIN          
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')          
            BEGIN          
               SET @cExtendedInfo = ''          
                  
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +           
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +      
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' +     
                  ' ,@nMobile'     
               SET @cSQLParam =          
                  '@cLoadKey        NVARCHAR( 10), ' +          
                  '@cOrderKey       NVARCHAR( 10), ' +       
                  '@cConsigneeKey   NVARCHAR( 15), ' +          
                  '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +          
                  '@cStorer         NVARCHAR( 15), ' +            
                  '@cSKU            NVARCHAR( 20), ' +            
                  '@nExpQTY         INT,       ' +            
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +      
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +      
                  '@cLangCode       NVARCHAR( 3),         ' +      
                  '@bSuccess        INT           OUTPUT, ' +      
                  '@nErrNo          INT           OUTPUT, ' +      
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
                  '@nMobile         INT '            
                      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT      
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
                  , @nMobile         
             
               -- Prepare extended fields          
               IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo          
            END          
                  
            -- Get SKU info          
            SELECT       
               @cSKUDescr = Descr,       
               @cBUSR10 = BUSR10    -- (james02)      
            FROM dbo.SKU WITH (NOLOCK)       
            WHERE StorerKey = @cStorerKey       
            AND   SKU = @cSKU    
         
      
                
         END       
             
         -- Prepare next screen var          
         SET @nPackQTY = 0          
         SET @cOutField01 = @cstoreNo--CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cstoreNo END      
         SET @cOutField02 = @cOrderKey          
         SET @cOutField04 = @cLabelNo          
         SET @cInField05  = @cSKU           
         SET @cOutField05 = @cSKU       
         SET @cOutField06 = CASE WHEN @cDefaultQTY >= '1' THEN @cDefaultQTY ELSE '' END --ActQTY          
         --SET @cOutField07 = @nScannedQTY      
         SET @cOutField08 = CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5))         
         SET @cOutField09 = CAST( @nOrderQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(5))      
         SET @cOutField10 = @cExtendedInfo          
         SET @cOutField11 = CAST( @nCtnQTY_Total AS NVARCHAR(5))      
      
         -- Diable Qty field. Only when config turn on and default qty set >=1      
         SET @cFieldAttr06 = CASE WHEN @cDisableQtyField = '1' THEN 'O' ELSE '' END    
             
         EXEC rdt.rdtSetFocusField @nMobile, 5        
      END      
      ELSE      
      BEGIN      
    
         SET @cSKU =''     
         SET @cOrderKey=''         
      
         -- Prepare next screen var          
         SET @nPackQTY = 0          
         SET @cOutField01 = CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cStoreNo END      
         SET @cOutField02 = @cOrderKey          
         SET @cOutField04 = @cLabelNo    
         SET @cInField05 = ''           
         SET @cOutField05 = ''      
         SET @cOutField06 = CASE WHEN @cDefaultQTY >= '1' THEN @cDefaultQTY ELSE '' END --ActQTY          
         --SET @cOutField07 = '0'      
         SET @cOutField08 = CAST(@nSKUQTY_Bal AS NVARCHAR(5))+'/' + CAST( @nPrevSKUQTY_Total AS NVARCHAR(5)) --**      
         SET @cOutField09 = CAST( @nOrderQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nOrderQTY_Total AS NVARCHAR(5))      
         SET @cOutField10 = ''--@cExtendedInfo          
         SET @cOutField11 = CAST( @nCtnQTY_Total AS NVARCHAR(5))      
      
         -- Diable Qty field. Only when config turn on and default qty set >=1      
         SET @cFieldAttr06 = CASE WHEN @cDisableQtyField = '1' THEN 'O' ELSE '' END    
         EXEC rdt.rdtSetFocusField @nMobile, 5       
      END          
   END          
          
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      IF @cDisableQTYField = '1' AND @nPackQTY > 0          
      BEGIN          
         -- Confirm task          
         EXEC rdt.rdt_SortAndPack_GOH_Confirm @nMobile, @nFunc, @cLangCode, @cPackByType, @cLoadKey, @cOrderKey, @cConsigneeKey, @cStorerKey, @cSKU, @nPackQTY, @cLabelNo, @cCartonType          
            ,@nErrNo        OUTPUT          
            ,@cErrMsg       OUTPUT          
         IF @nErrNo <> 0          
            GOTO Step_4_Fail          
      END       
             
      -- Prep next screen var          
      SET @cOutField01 = @cStoreNo     
          
      IF  (@cPreventManualInput ='1')    
      BEGIN    
         SET @cFieldAttr02 = CASE WHEN   ISNULL(@cLabelNo,'') <>'' THEN 'O' ELSE '' END    
         SET @cSuggestedSKU =''    
         SET @cOutField02 =@cLabelNo    
      END     
      ELSE    
      BEGIN        
         SET @cOutField02 = '' -- SKU         
      END     
          
      -- Go to label screen          
      SET @nScn  = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
   GOTO Quit          
          
   Step_4_Fail:          
   BEGIN      
      SET @nExpQTY = ''    
      SET @cActQTY=''    
      SET @nActQTY=''    
      SET @cOrderKey=''    
      SET @cSKU=''      
   END      
          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 5. Screen 3314          
   PACKING COMPLETED          
   FOR THIS SKU          
********************************************************************************/          
Step_5:          
BEGIN          
    
   IF (@nInputKey='1')    
   BEGIN    
      -- Prepare prev screen var          
      SET @cOutField01 = @cLoadKey    
      SET @cOutField02 = ''       
      SET @cStoreNo=''    
          
      -- Back to Store No screen          
      SET @nScn  = @nScn - 3          
      SET @nStep = @nStep - 3      
   END    
       
   IF (@nInputKey='0')    
   BEGIN    
      -- Prepare prev screen var          
      SET @cOutField01 = ''       
          
      -- Back to Store No screen          
      SET @nScn  = @nScn - 4          
      SET @nStep = @nStep - 4      
   END        
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 6. Screen 3315          
   EXIT PACKING?          
   1=YES          
   2=NO          
   OPTION:   (Field01)          
********************************************************************************/          
Step_6:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      DECLARE @cOption NVARCHAR( 1)          
          
      -- Screen mapping          
      SET @cOption = @cInField01          
          
      -- Validate blank          
      IF @cOption = ''          
      BEGIN          
         SET @nErrNo = 78162          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed          
         GOTO Step_6_Fail          
      END          
          
      -- Check option valid          
      IF @cOption NOT IN ('1', '2','3')          
      BEGIN          
         SET @nErrNo = 78163          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option          
         GOTO Step_6_Fail          
      END          
          
      IF @cOption = '1' --YES          
      BEGIN          
         -- Prepare prev screen var         
         SET @cOutField01 = @cLoadKey           
         SET @cOutField02 = ''      
             
         IF @cExtendedUpdateSP <> ''        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +         
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +         
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'        
               SET @cSQLParam =        
                  '@nMobile        INT,            ' +        
                  '@nFunc          INT,            ' +        
                  '@cLangCode      NVARCHAR(3),    ' +        
                  '@nStep          INT,            ' +        
                  '@cUserName      NVARCHAR( 18),  ' +         
                  '@cFacility      NVARCHAR( 5),   ' +         
                  '@cStorerKey     NVARCHAR( 15),  ' +         
                  '@cLabelPrinter  NVARCHAR( 10),  ' +         
                  '@cCloseCartonID NVARCHAR( 20),  ' +         
                  '@cLoadKey       NVARCHAR( 10),  ' +         
                  '@cLabelNo       NVARCHAR( 20),  ' +         
                  '@nErrNo         INT OUTPUT, ' +          
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'        
                       
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,        
                  @nErrNo OUTPUT, @cErrMsg OUTPUT        
              
               IF @nErrNo <> 0        
                  GOTO Step_6_Fail     
                       
            END        
         END  -- IF @cExtendedUpdateSP <> ''            
          
         -- Back to Store No screen          
         SET @nScn  = @nScn - 4          
         SET @nStep = @nStep - 4          
      END          
          
      IF @cOption = '2' --NO          
      BEGIN           
             
         -- Prep next screen var          
         SET @cOutField01 = @cStoreNo          
         IF  (@cPreventManualInput ='1')    
         BEGIN    
            SET @cOutField02 = @cLabelNo    
            SET @cFieldAttr02 = CASE WHEN   ISNULL(@cLabelNo,'') <>'' THEN 'O' ELSE '' END     
         END    
         ELSE    
         BEGIN    
            SET @cOutField02 = ''    
            SET @cFieldAttr02=''       
         END    
               
         -- Back to label no screen          
         SET @nScn  = @nScn - 3          
         SET @nStep = @nStep - 3          
      END       
          
      IF @cOption = '3' --CLOSE          
      BEGIN      
          
         IF @cExtendedUpdateSP <> ''        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +         
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cLabelPrinter, @cCloseCartonID, @cLoadKey, @cLabelNo, ' +         
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'        
               SET @cSQLParam =        
                  '@nMobile        INT,            ' +        
                  '@nFunc          INT,            ' +        
                  '@cLangCode      NVARCHAR(3),    ' +        
                  '@nStep          INT,            ' +        
                  '@cUserName      NVARCHAR( 18),  ' +         
                  '@cFacility  NVARCHAR( 5),   ' +         
                  '@cStorerKey     NVARCHAR( 15),  ' +         
                  '@cLabelPrinter  NVARCHAR( 10),  ' +         
                  '@cCloseCartonID NVARCHAR( 20),  ' +         
                  '@cLoadKey       NVARCHAR( 10),  ' +         
                  '@cLabelNo       NVARCHAR( 20),  ' +         
                  '@nErrNo         INT OUTPUT, ' +          
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'        
                       
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cPrinter, @cLabelNo, @cLoadKey, @cLabelNo,        
                  @nErrNo OUTPUT, @cErrMsg OUTPUT        
              
               IF @nErrNo <> 0        
                  GOTO Step_6_Fail     
                       
            END        
         END  -- IF @cExtendedUpdateSP <> ''             
          
         -- Extended info (Get Gen Label)           
         IF @cExtendedInfoSP <> ''          
         BEGIN          
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')          
            BEGIN          
               SET @cExtendedInfo = @cStoreNo     
               SET @cLabelNo =''        
                      
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +           
                  ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +      
                  ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' +     
                  ' ,@nMobile'     
               SET @cSQLParam =          
                  '@cLoadKey        NVARCHAR( 10), ' +          
                  '@cOrderKey       NVARCHAR( 10), ' +       
                  '@cConsigneeKey   NVARCHAR( 15), ' +          
                  '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +          
                  '@cStorer         NVARCHAR( 15), ' +            
                  '@cSKU            NVARCHAR( 20), ' +            
                  '@nExpQTY         INT,       ' +            
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +      
                  '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +      
                  '@cLangCode       NVARCHAR( 3),         ' +      
                  '@bSuccess        INT           OUTPUT, ' +      
                  '@nErrNo          INT           OUTPUT, ' +      
                  '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
                  '@nMobile         INT '            
                      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
                  @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT      
                  , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
                  , @nMobile    
    
               ---- Prepare extended fields          
               --IF @cExtendedInfo <> ''     
               --   SET @cLabelNo = @cExtendedInfo     
                   
               IF @nErrNo <>0     
               BEGIN        
                  GOTO Step_3_Fail          
               END           
            END          
         END    
    
    
      
         -- Prep next screen var          
         SET @cOutField01 = @cStoreNo          
         SET @cOutField02 = @cLabelNo -- Label No      
          
         IF  (@cPreventManualInput ='1')    
         BEGIN    
            SET @cFieldAttr02 = CASE WHEN   ISNULL(@cLabelNo,'') <>'' THEN 'O' ELSE '' END    
            SET @cSuggestedSKU =''    
            SET @cInField02 =@cLabelNo    
         END     
               
         -- Back to Store No screen          
         SET @nScn  = @nScn - 3         
         SET @nStep = @nStep - 3      
      END         
   END          
          
   GOTO Quit          
          
   Step_6_Fail:   
   BEGIN          
      SET @cOption = ''          
      SET @cOutField01 = '' -- Option          
   END          
END          
GOTO Quit          
          
/********************************************************************************          
Step 7. Screen = 3316          
   OrderKey       (Field01)          
   Label No       (Field02)          
   Carton Type    (Field03, input)        ********************************************************************************/          
Step_7:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cCartonType = @cInField04          
      
      IF NOT EXISTS (SELECT 1 FROM Cartonization CZ WITH (NOLOCK)       
                     JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup      
                     WHERE CartonType = @cCartonType      
                     AND   ST.StorerKey = @cStorerKey)      
      BEGIN        
         SET @nErrNo = 78164        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV CTN TYPE'        
         GOTO Step_7_Fail        
      END        
      
      IF @cExtendedInfoSP <> ''          
      BEGIN          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')          
         BEGIN          
            SET @cExtendedInfo = ''          
                      
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +           
               ' @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT' +      
               ' ,@cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT' +     
               ' ,@nMobile'     
            SET @cSQLParam =          
               '@cLoadKey        NVARCHAR( 10), ' +          
               '@cOrderKey       NVARCHAR( 10), ' +       
               '@cConsigneeKey   NVARCHAR( 15), ' +          
               '@cLabelNo        NVARCHAR( 20) OUTPUT, ' +          
               '@cStorer         NVARCHAR( 15), ' +            
               '@cSKU            NVARCHAR( 20), ' +            
               '@nExpQTY         INT,       ' +            
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +      
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +      
               '@cLangCode       NVARCHAR( 3),         ' +      
               '@bSuccess        INT           OUTPUT, ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@nMobile         INT '            
                      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
               @cLoadKey, @cOrderKey, @cConsigneeKey, @cLabelNo OUTPUT, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT      
               , @cLangCode, @b_Success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
               , @nMobile    
    
            -- Prepare extended fields          
            IF @cExtendedInfo <> '' SET @cOutField07 = @cExtendedInfo          
         END          
      END          
      
          
      SET @cActQty=0         
      SET @cSKU=''    
      SET @cOrderKey=''    
    
      -- Prepare next screen var          
      SET @nPackQTY = 0          
      SET @cOutField01 = @cStoreNo--CASE WHEN ISNULL(@cRemoveConsigneePrefix, '') > '' THEN REPLACE(RTRIM(@cConsigneeKey), RTRIM(@cRemoveConsigneePrefix), '') ELSE @cConsigneeKey END      
      SET @cOutField02 = @cOrderKey          
      SET @cOutField04 = @cLabelNo          
      SET @cOutField05 = ''      
      SET @cOutField06 = ''    
      
      -- Diable Qty field. Only when config turn on and default qty set >=1      
      SET @cFieldAttr06 = CASE WHEN @cDisableQtyField = '1' THEN 'O' ELSE '' END    
      EXEC rdt.rdtSetFocusField @nMobile, 5     
            
      -- Go to QTY screen          
      SET @nScn  = @nScn - 3          
     SET @nStep = @nStep - 3          
   END      
      
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      -- Prepare next screen var          
      SET @cOutField01 = @cStoreNo          
    
      IF  (@cPreventManualInput ='1')    
      BEGIN    
         SET @cOutField02 = @cLabelNo    
         SET @cFieldAttr02 = CASE WHEN   ISNULL(@cLabelNo,'') <>'' THEN 'O' ELSE '' END     
      END    
      ELSE    
      BEGIN    
         SET @cOutField02 = ''    
         SET @cFieldAttr02=''       
      END    
    
           
      -- Back to LabelNo screen          
      SET @nScn  = @nScn - 4          
      SET @nStep = @nStep - 4          
   END          
   GOTO Quit          
         
   Step_7_Fail:          
   BEGIN          
      SET @cCartonType = ''      
      SET @cOutField04 = ''        
   END          
END          
GOTO Quit          
/********************************************************************************          
Quit. Update back to I/O table, ready to be pick up by JBOSS          
********************************************************************************/          
Quit:          
BEGIN          
   UPDATE RDTMOBREC WITH (ROWLOCK) SET          
      ErrMsg = @cErrMsg,          
      Func   = @nFunc,          
      Step   = @nStep,          
      Scn    = @nScn,          
          
      StorerKey  = @cStorerKey,          
      Facility   = @cFacility,          
      -- UserName   = @cUserName,    
      Printer    = @cPrinter,    
    
      V_LoadKey  = @cLoadKey,    
      V_SKU      = @cSKU,    
      V_SKUDescr = @cSKUDescr,    
      V_ConsigneeKey = @cConsigneeKey,    
      V_OrderKey = @cOrderKey,     
      V_CaseID   = @cLabelNo,    
      --V_QTY      = @nExpQTY,    
             
          
      V_Integer1 = @nExpQTY,
      V_Integer2 = @nScannedQTY,
      V_Integer3 = @nOrderQTY_Total,
      V_Integer4 = @nOrderQTY_Bal,
      V_Integer5 = @nSKUQTY_Total,
      V_Integer6 = @nSKUQTY_Bal,
      V_Integer7 = @nPackQTY,
      V_Integer8 = @cCartonType,
    
      --V_String1  = @nScannedQTY,     
      --V_String5  = @nOrderQTY_Total,     
      --V_String6  = @nOrderQTY_Bal,     
      --V_String7  = @nSKUQTY_Total,     
      --V_String8  = @nSKUQTY_Bal,     
      --V_String9  = @nPackQTY,   	        
      V_String10 = @cLabelNoChkSP,          
      V_String11 = @cPackByType,          
      V_String12 = @cDefaultQTY,          
      V_String13 = @cDisableQTYField,          
      V_String14 = @cDisableSKUField,          
      V_String15 = @cExtendedInfoSP,           
      V_String16 = @cAllowSkipTask,           
      V_String17 = @cRemoveConsigneePrefix,        
      V_String18 = @cPickSlipNo,       
      V_String19 = @nCartonNo,          
      V_String20 = @cCartonType,       
      V_String21 = @cDefaultCartonType,       
      V_String22 = @cExtendedInfo,      
      V_String23 = @cSuggestedSKU,       
      V_String24 = @cSortAndPackFilterGOH,   -- (james01)      
      V_String25 = @cConvertQtySP,           -- (james01)      
      V_String26 = @cStoreNo,                -- (james02)      
      V_String27 = @cExtendedInfo2,          -- (yeekung01)    
      V_String28 = @cPreventManualInput,            -- (yeekung01)    
      V_String29 = @cExtendedUpdateSP,              -- (yeekung01)    
      V_String30 = @cSortAndPackConfirmSP,          -- (yeekung01)    
      V_String31 = @cSortAndPackGetTaskSP,          -- (yeekung01)    
    
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