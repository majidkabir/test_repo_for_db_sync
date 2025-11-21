SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtfnc_ECOMM                                        */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: RDT ECOMM Modular                                           */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2015-06-15 1.0  ChewKP   SOS#371222 Created                          */  
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2017-09-25 1.2  ChewKP   WMS-1042 - Bug Fixes (ChewKP01)             */ 
/* 2018-09-26 1.3  ChewKP   WMS-6445 - Add EventLog (ChewKP02)          */
/* 2018-10-11 1.4  James    WMS-6635 - Display sku error in msgqueue    */
/*                          screen (james01)                            */
/* 2020-04-22 1.5  James    WMS-13002 Fix wrong sku scanned but not     */
/*                          display error msg (james02)                 */
/* 2020-07-14 1.6  Chermaine  WMS-14163 check Weight Range (cc01)       */
/* 2020-09-02 1.7  James    WMS-14945 Add MultiSKU (james03)            */
/* 2021-01-07 1.8  James    WMS-15880 Add Capture SerialNo (james04)    */
/* 2021-03-18 1.9  James    WMS-16541 Prompt error when orders contain  */
/*                          > 1 tote (james05)                          */
/* 2021-09-13 2.0  CheeMun  JSM-19632 Extend @fLWeight length           */
/* 2022-11-06 2.1  James    WMS-21082 Add new param ExtendedInfoSP      */
/*                          Add ExtendedInfoSP into step 2 & 3 (james06)*/
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_ECOMM] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 nvarchar max  
) AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @cChkFacility NVARCHAR( 5),  
   @nSKUCnt      INT,  
   @nRowCount    INT,  
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc  
  
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
  
   @cSKU        NVARCHAR( 20),  
   @cDescr      NVARCHAR( 40),  
   @cPUOM       NVARCHAR( 1), -- Prefer UOM  
   
   @cUserName   NVARCHAR(18),   
   
   @cExtendedUpdateSP NVARCHAR(30),  
   @cExtendedValidateSP NVARCHAR(30),  
   @cExtendedInfoSP     NVARCHAR(30),
   
   @cDropID     NVARCHAR(20),
   @cDecodeLabelNo NVARCHAR(20),  
   @cPostDataCapture NVARCHAR(5),
   @cSQL                NVARCHAR(1000),   
   @cSQLParam           NVARCHAR(1000),   
   @cOption             NVARCHAR(1), 
   @cOrderKey           NVARCHAR(10),
   @cTrackNo            NVARCHAR(20),
   @cCartonType         NVARCHAR(10),
   @cWeight             NVARCHAR(20),
   @cTaskStatus         NVARCHAR(1),
   @cDropIDType         NVARCHAR(10),
   @cInSku              NVARCHAR(20),
   @b_Success           INT,
   @nUCCQTY             INT,
   @cUCC                NVARCHAR(20),
   @cTTLPickedQty       INT,
   @cTTLScannedQty      INT,
   @nCurrentStep        INT,
   @cDisplayLongErrMsg  NVARCHAR(1),
   @cUPC                NVARCHAR( 30), -- (james03)
   @cMultiSKUBarcode    NVARCHAR( 1),  -- (james03)
   @nFromScn            INT,           -- (james03)
   @nFromStep           INT,           -- (james03)
   @cSerialNo           NVARCHAR( 30), 
   @nSerialQTY          INT, 
   @nMoreSNO            INT, 
   @nBulkSNO            INT, 
   @nBulkSNOQTY         INT,
   @tVar                VariableTable,
   @cSerialNoCapture    NVARCHAR( 1),
   @cPickSlipNo         NVARCHAR( 10),
   @cMultiToteOrdersNotAllow  NVARCHAR( 1),  -- (james05)
   @nAfterStep          INT,
   @tExtendedInfo       VARIABLETABLE,
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),  
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),  
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),  
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),  
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),  
  
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
   @cFieldAttr15 NVARCHAR( 1),
  
   @cErrMsg1     NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3     NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5     NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),
   @cErrMsg7     NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),
   @cErrMsg9     NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),
   @cErrMsg11    NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),
   @cErrMsg13    NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),
   @cErrMsg15    NVARCHAR( 20) 

  
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
  
   @cSKU        = V_SKU,  
   @cDescr      = V_SKUDescr,  
   @cPUOM       = V_UOM,  
   @cOrderKey   = V_OrderKey,
  
   @nFromScn    = V_FromScn,
   @nFromStep   = V_FromStep,
   
   @cTTLPickedQty    = V_Integer1, 
   @cTTLScannedQty   = V_Integer2, 
   @nAfterStep       = V_Integer3, 
   
   @cExtendedUpdateSP   = V_String1,  
   @cExtendedValidateSP = V_String2,   
   @cDecodeLabelNo      = V_String3,
   @cPostDataCapture    = V_String4,
   @cDisplayLongErrMsg  = V_String5, 
   @cDropID             = V_String6,
   @cExtendedInfoSP     = V_String7,
   @cCartonType         = V_String8, 
   @cTrackNo            = V_String9, 
   @cWeight             = V_String10, 
   @cDropIDType         = V_String11, -- (ChewKP01) 
   @cMultiSKUBarcode    = V_String12, -- (james03)
   @cTaskStatus         = V_String13, -- (james03)
   @cSerialNoCapture    = V_String14, -- (james04)
   @cMultiToteOrdersNotAllow = V_String15, -- (james05)
   
   
  
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
IF @nFunc = 842 -- Replenish (1 stage)  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 842  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4680. DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4681. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 4682. Post Pack Option
   IF @nStep = 4 GOTO Step_4   -- Scn = 4683. Short Pack , New Pack , Exit Pack
   IF @nStep = 5 GOTO Step_5   -- Scn = 4684. More Tote
   IF @nStep = 6 GOTO Step_6   -- Scn = 3570. Multi SKU Barocde
   IF @nStep = 7 GOTO Step_7   -- Scn = 4830. Serial no
   
END  

RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 895)  
********************************************************************************/  
Step_0:  
BEGIN  
     
  
     
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
   IF @cExtendedUpdateSP = '0'  
   BEGIN  
        SET @cExtendedUpdateSP = ''  
   END  
     
     
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedValidateSP = '0'  
   BEGIN  
        SET @cExtendedValidateSP = ''  
   END  
  
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)  
   IF @cDecodeLabelNo = '0'  
      SET @cDecodeLabelNo = ''  
  
   SET @cPostDataCapture = rdt.RDTGetConfig( @nFunc, 'PostDataCapture', @cStorerKey)  
   IF @cPostDataCapture = '0'  
      SET @cPostDataCapture = ''  
      
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
   IF @cExtendedInfoSP = '0'  
      SET @cExtendedInfoSP = ''     
   
--   SET @cGetTaskSP = rdt.RDTGetConfig( @nFunc, 'GetTaskSP', @cStorerKey)    
--   IF @cGetTaskSP = '0'      
--   BEGIN    
--      SET @cGetNextTaskSP = ''    
--   END         
      
   -- (james01)
   SET @cDisplayLongErrMsg = rdt.RDTGetConfig( @nFunc, 'DisplayLongErrMsg', @cStorerKey)  

   -- (james03)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- (james04)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)
   
   -- (james05)
   SET @cMultiToteOrdersNotAllow = rdt.RDTGetConfig( @nFunc, 'MultiToteOrdersNotAllow', @cStorerKey)
   
   -- Set the entry point  
   SET @nScn = 4680 
   SET @nStep = 1  
   SET @nAfterStep = 1

  
   -- Get prefer UOM  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M (NOLOCK)  
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
    --  EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey  
  
  
   -- Prep next screen var  
   SET @cDropID = ''  
   SET @cOutField01 = '' 
   
  
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
Step 1. Scn = 4680.       
   ToteNo         (field01, input)      
         
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
      SET @nCurrentStep = @nStep
      
      SET @cDropID = ISNULL(RTRIM(@cInField01),'')      
      
    
      IF @cDropID = ''      
      BEGIN      
         SET @nErrNo = 101401      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq    
         GOTO Step_1_Fail      
      END      
      
           
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),    ' +     
               '@cOrderKey      NVARCHAR( 10),  ' +     
               '@cTrackNo       NVARCHAR( 20),  ' +     
               '@cCartonType    NVARCHAR( 10),  ' +  
               '@cWeight        NVARCHAR( 20), ' +    
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END    
      END  -- IF @cExtendedValidateSP <> ''  

      
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, ' + 
               ' @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, 
               @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    

		
        
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
    
      SELECT @cDropIDType = DropIDType
      FROM dbo.DropID WITH (NOlOCK) 
      WHERE DropID = @cDropID

	   

      
      
      -- Task Status = '1' = MULTIS Orders 
      -- Task Status = '9' = SINGLES Orders
      IF @cTaskStatus = '1' 
      BEGIN
         --(james05)
         IF @cMultiToteOrdersNotAllow = '1'
         BEGIN
            SET @nErrNo = 101418      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi Tote Ord    
            GOTO Step_1_Fail      
         END

         SET @cOutField07 = ''
         
          -- GOTO Next Screen        
         SET @nScn = @nScn + 4        
         SET @nStep = @nStep + 4        
         SET @nAfterStep = @nStep
         
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
         
         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty
         
         -- GOTO Next Screen        
         SET @nScn = @nScn + 1        
         SET @nStep = @nStep + 1        
         SET @nAfterStep = @nStep
         
         EXEC rdt.rdtSetFocusField @nMobile, 4        
      END
      
       
      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @nStep       = @nCurrentStep 
        
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0       
   BEGIN      
      -- Delete ReplenishmentLog When UserLogin   
      --DELETE FROM rdt.rdtReplenishmentLog  
      --WHERE AddWho = @cUserName       
              
--    -- EventLog - Sign In Function      
      EXEC RDT.rdt_STD_EventLog      
        @cActionType = '9', -- Sign in function      
        @cUserID     = @cUserName,      
        @nMobileNo   = @nMobile,      
        @nFunctionID = @nFunc,      
        @cFacility   = @cFacility,      
        @cStorerKey  = @cStorerkey      
              
      --go to main menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = ''      
        
  
  
   END      

   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, ' + 
            ' @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, ' +     
            ' @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile        INT,            ' +    
            '@nFunc          INT,            ' +    
            '@cLangCode      NVARCHAR(3),    ' +    
            '@nStep          INT,            ' +    
            '@nAfterStep     INT,            ' +
            '@nInputKey      INT,            ' +
            '@cUserName      NVARCHAR( 18),  ' +     
            '@cFacility      NVARCHAR( 5),   ' +     
            '@cStorerKey     NVARCHAR( 15),  ' +     
            '@cDropID        NVARCHAR( 20),  ' +     
            '@cSKU           NVARCHAR( 20),  ' +
            '@cOrderKey      NVARCHAR( 20),  ' +
            '@cOutField01    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField02    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField03    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField04    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField05    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField06    NVARCHAR( 20) OUTPUT,  ' +
            '@tExtendedInfo  VariableTable READONLY,   ' +
            '@nErrNo         INT OUTPUT, ' +      
            '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nCurrentStep, @nAfterStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, 
               @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, 
               @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT
           
         IF @nErrNo <> 0    
            GOTO Step_1_Fail    
      END    
   END  -- IF @cExtendedInfoSP <> ''    
         
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
    
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''   
          
      
   END      
END       
GOTO QUIT      
  
  
/********************************************************************************      
Step 2. Scn = 4681.       
   Tote Type       (field01)      
   Tote No         (field02)      
   OrderKey        (field03)      
   SKU / UPC       (field04, input)      
   TTL PICK        (field05)      
   TTL SCAN        (field06)      
    
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @nCurrentStep  = @nStep
      
      SET @cInSku    = ISNULL(@cInField04,'' ) 
      
      IF @cInSKU = ''
      BEGIN
         SET @nErrNo = 101404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Req
         GOTO Step_2_Fail
      END
    

      IF @cDecodeLabelNo <> ''
      BEGIN
            --SET @c_oFieled09 = @cDropID
            --SET @c_oFieled10 = @cTaskDetailKey

            SET @cErrMsg = ''
            SET @nErrNo = 0
            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cInSku
               ,@c_Storerkey  = @cStorerKey
               ,@c_ReceiptKey = ''
               ,@c_POKey      = ''
               ,@c_LangCode   = @cLangCode
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC
               ,@c_oFieled09  = @c_oFieled09 OUTPUT
               ,@c_oFieled10  = @c_oFieled10 OUTPUT
               ,@b_Success    = @b_Success   OUTPUT
               ,@n_ErrNo      = @nErrNo      OUTPUT
               ,@c_ErrMsg     = @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail

            SET @cSKU    = ISNULL( @c_oFieled01, '')  
            SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)  
            SET @cUCC    = ISNULL( @c_oFieled08, '')  

      END
      ELSE 
      BEGIN
         SET @cSKU = @cInSKU 
      END

       -- Get SKU barcode count
      SET @nSKUCnt = 0

      EXEC rdt.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 101402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   -- Invalid SKU
         
         IF @cDisplayLongErrMsg = '1'
         BEGIN
            SET @cErrMsg1 = @cErrMsg 
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END   
         END

         GOTO Step_2_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            SET @cUPC = @cSKU
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorerKey,
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               '',    -- DocType
               ''

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep
               SET @nScn = 3570
               SET @nStep = @nStep + 4
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
            BEGIN
               SET @nErrNo = 0
               SET @cSKU = @cUPC
            END
         END         
         ELSE
         BEGIN
            SET @nErrNo = 101403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
            GOTO Step_2_Fail
         END
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT


      SET @cCartonType = ''
      SET @cTrackNo    = ''
      SET @cWeight     = ''

      -- check if sku exists in tote  
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                     WHERE ToteNo = @cDropID  
                     AND SKU = @cSKU  
                     AND AddWho = @cUserName  
                     AND Status IN ('0', '1') )  
      BEGIN  
          SET @nErrNo = 101416  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote  
          GOTO Step_2_Fail  
      END  

      IF EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) 
                 GROUP BY ToteNo, SKU , Status , AddWho 
                 HAVING ToteNo = @cDropID  
                 AND SKU = @cSKU  
                 AND SUM(ExpectedQty) < SUM(ScannedQty) + 1 
                 AND Status < '5'  
                 AND AddWho = @cUserName)  
      BEGIN  
         SET @nErrNo = 101417  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded  
         GOTO Step_2_Fail  
      END  
   
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),    ' +     
               '@cOrderKey      NVARCHAR( 10),  ' +     
               '@cTrackNo       NVARCHAR( 20),  ' +     
               '@cCartonType    NVARCHAR( 10),  ' +  
               '@cWeight        NVARCHAR( 20), ' +    
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_2_Fail    
         END    
      END  -- IF @cExtendedValidateSP <> ''  

      -- Serial No
      IF @cSerialNoCapture IN ('1', '3')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cDescr, 1, 'CHECK', 'PICKSLIP', @cPickSlipNo, 
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT, 
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0, 
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '3'
         
         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep
            SET @nScn = 4830
            SET @nStep = @nStep + 5

            GOTO Quit
         END
      END
      
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, ' + 
               ' @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, 
               @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_2_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''  
	  
	     --NICK
   DECLARE @NICKMSG NVARCHAR(200)
   SET @NICKMSG = CONCAT_WS(',', 'rdtfnc_ECOMM', @cTaskStatus )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)

      
      -- 1 = Tote Still have remaining to pack
      -- 9 = Tote need to go to Pack Info screen after Pack by Orders
      IF @cTaskStatus = '1'
      BEGIN
         SET @nAfterStep = @nStep
         
         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty
         
         EXEC rdt.rdtSetFocusField @nMobile, 4     
         
      END
      ELSE IF @cTaskStatus = '5' -- FOR MULTI HAVE Remaining --
      BEGIN
           -- GOTO Next Screen        
            SET @nScn = @nScn - 1        
            SET @nStep = @nStep - 1        
            SET @nAfterStep = @nStep
            
            SET @cOutField01 = ''
                    
            EXEC rdt.rdtSetFocusField @nMobile, 1
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
         
         IF @cPostDataCapture <> ''
         BEGIN
            
            SET @cOutField02 = '' 
            SET @cOutField04 = '' 
            SET @cOutField06 = '' 
            
            IF CHARINDEX ( 'T', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField02 = 'TRACK NO:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr03 = 'O'
            END
            
            
            IF CHARINDEX ( 'C', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField04 = 'CARTON TYPE:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr05 = 'O'
            END
            
            IF CHARINDEX ( 'W', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField06 = 'WEIGHT:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr07 = 'O'
            END
            
            SET @cOutField01 = @cOrderKey 
            SET @cOutField03 = @cTrackNo 
            SET @cOutField05 = @cCartonType 
            SET @cOutField07 = @cWeight
            
            -- GOTO Next Screen        
            SET @nScn = @nScn + 1        
            SET @nStep = @nStep + 1        
            SET @nAfterStep = @nStep
            
            EXEC rdt.rdtSetFocusField @nMobile, 4     
         END
         ELSE
         BEGIN
            
             -- GOTO Next Screen        
            SET @nScn = @nScn - 1        
            SET @nStep = @nStep - 1        
            SET @nAfterStep = @nStep
            
            SET @cOutField01 = ''
                    
            EXEC rdt.rdtSetFocusField @nMobile, 1
         END
      END

      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @cSKU        = @cSKU,
        @nQty        = 1,
        @nStep       = @nCurrentStep 

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      
    

      -- Remember the current scn & step
      SET @nScn = @nScn + 2   --ESC screen
      SET @nStep = @nStep + 2

   END
   
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, ' + 
            ' @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, ' +     
            ' @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile        INT,            ' +    
            '@nFunc          INT,            ' +    
            '@cLangCode      NVARCHAR(3),    ' +    
            '@nStep          INT,            ' +    
            '@nAfterStep     INT,            ' +
            '@nInputKey      INT,            ' +
            '@cUserName      NVARCHAR( 18),  ' +     
            '@cFacility      NVARCHAR( 5),   ' +     
            '@cStorerKey     NVARCHAR( 15),  ' +     
            '@cDropID        NVARCHAR( 20),  ' +     
            '@cSKU           NVARCHAR( 20),  ' +
            '@cOrderKey      NVARCHAR( 20),  ' +
            '@cOutField01    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField02    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField03    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField04    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField05    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField06    NVARCHAR( 20) OUTPUT,  ' +
            '@tExtendedInfo  VariableTable READONLY,   ' +
            '@nErrNo         INT OUTPUT, ' +      
            '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nCurrentStep, @nAfterStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, 
               @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, 
               @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT
           
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END  -- IF @cExtendedInfoSP <> ''    

   GOTO Quit

   Step_2_Fail:
   BEGIN
         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID --'' --@cSku  -- (Vicky02)
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
   END
END  
GOTO Quit   



/********************************************************************************      
Step 3. Scn = 4682.       
   TrackNo            (field03, input)      
   CartonType         (field05, input)      
   Weight             (field07, input)      
         
    
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
      SET @nCurrentStep  = @nStep
      SET @cTrackNo = ISNULL(RTRIM(@cInField03),'')      
      SET @cCartonType = ISNULL(RTRIM(@cInField05),'')      
      SET @cWeight = ISNULL(RTRIM(@cInField07),'')      
      
      
      IF CHARINDEX ( 'T', @cPostDataCapture ) > 0
      BEGIN
         IF @cTrackNo = ''      
         BEGIN      
            SET @nErrNo = 101405      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoReq   
            EXEC rdt.rdtSetFocusField @nMobile, 3 
            GOTO Step_3_Fail      
         END  
      END
      
      
      IF CHARINDEX ( 'C', @cPostDataCapture ) > 0
      BEGIN
         IF @cCartonType = ''      
         BEGIN      
            SET @nErrNo = 101407  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnTypeReq    
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_3_Fail      
         END  
      END
      
      IF CHARINDEX ( 'W', @cPostDataCapture ) > 0
      BEGIN
         IF @cWeight = ''      
         BEGIN      
            SET @nErrNo = 101408 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WeightReq   
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_3_Fail      
         END  
      END
      
      IF @cTrackNo <> '' 
      BEGIN
                
         IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND TrackingNo = @cTrackNo
                     AND OrderKey <> @cOrderKey ) 
         BEGIN
            SET @nErrNo = 101406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoExist    
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cTrackNo = ''
            GOTO Step_3_Fail    
         END
      END    
      
      IF @cCartonType <> '' 
      BEGIN
         
         IF NOT EXISTS (SELECT 1 FROM dbo.Cartonization WITH (NOLOCK) 
                        WHERE CartonType = @cCartonType )
         BEGIN
            SET @nErrNo = 101409
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvCtnType    
            EXEC rdt.rdtSetFocusField @nMobile, 5
            SET @cCartonType = ''
            GOTO Step_3_Fail    
         END
      END
      
      IF @cWeight <> ''
      BEGIN
      	IF rdt.rdtIsValidQTY( @cWeight, 21) = 0
         BEGIN
            SET @nErrNo = 101410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidWeight'
            EXEC rdt.rdtSetFocusField @nMobile, 7
            SET @cWeight = ''
            GOTO Step_3_Fail
         END
         
         DECLARE @fLWeight DECIMAL (18,2) --(cc01)  --JSM-19632
      
         SET @fLWeight = CAST(@cWeight AS DECIMAL(18,2))
         
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'WgtChk', @fLWeight) = 0  --(cc01)
         BEGIN  
            SET @nErrNo = 101415 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WgtOutOfRange  
            SET @cOutField04 = ''  
            GOTO QUIT  
         END 
         
      END
      
      
      
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),    ' +     
               '@cOrderKey      NVARCHAR( 10),  ' +     
               '@cTrackNo       NVARCHAR( 20),  ' +     
               '@cCartonType    NVARCHAR( 10),  ' +  
               '@cWeight        NVARCHAR( 20), ' +    
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey, @cTrackNo, @cCartonType, @cWeight,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_3_Fail    
         END    
      END  -- IF @cExtendedValidateSP <> ''  
      
      
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_3_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
      
      SET @cTrackNo = ISNULL(RTRIM(@cInField03),'')      
      SET @cCartonType = ISNULL(RTRIM(@cInField05),'')      
      SET @cWeight = ISNULL(RTRIM(@cInField07),'')      
      
      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @cSKU        = @cSKU,
        @cTrackingNo    = @cTrackNo, 
        @cCartonType = @cCartonType,
        @fWeight     = @cWeight,
        @nStep       = @nStep 
      
      -- TaskStatus = '1' , Continue to SKU Scanning 
      -- TaskStatus = '9' , Go to Screen 1 
      IF @cTaskStatus = '1'
      BEGIN
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
  

         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty
         
   
         -- Remember the current scn & step
         SET @nCurrentStep = @nStep
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         SET @nAfterStep = @nStep
      END 
      ELSE IF @cTaskStatus = '9'
      BEGIN

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
  
         -- Back to Screen 1 
       
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         
         -- GOTO Next Screen        
         SET @nCurrentStep = @nStep
         SET @nScn = @nScn - 2        
         SET @nStep = @nStep - 2        
         SET @nAfterStep = @nStep
      END
    
        
            
   END  -- Inputkey = 1      
      
   --IF @nInputKey = 0       
   --BEGIN      

      
      
      
   --   SET @cOutField01 = @cDropIDType
   --   SET @cOutField02 = @cDropID
   --   SET @cOutField03 = @cOrderKey
   --   SET @cOutField04 = ''
   --   SET @cOutField05 = ''
   --   SET @cOutField06 = ''
      

   --   -- Remember the current scn & step
   --   SET @nScn = @nScn - 1
   --   SET @nStep = @nStep - 1

        
  
  
   --END      
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, ' + 
            ' @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, ' +     
            ' @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile        INT,            ' +    
            '@nFunc          INT,            ' +    
            '@cLangCode      NVARCHAR(3),    ' +    
            '@nStep          INT,            ' +    
            '@nAfterStep     INT,            ' +
            '@nInputKey      INT,            ' +
            '@cUserName      NVARCHAR( 18),  ' +     
            '@cFacility      NVARCHAR( 5),   ' +     
            '@cStorerKey     NVARCHAR( 15),  ' +     
            '@cDropID        NVARCHAR( 20),  ' +     
            '@cSKU           NVARCHAR( 20),  ' +
            '@cOrderKey      NVARCHAR( 20),  ' +
            '@cOutField01    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField02    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField03    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField04    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField05    NVARCHAR( 20) OUTPUT,  ' +
            '@cOutField06    NVARCHAR( 20) OUTPUT,  ' +
            '@tExtendedInfo  VariableTable READONLY,   ' +
            '@nErrNo         INT OUTPUT, ' +      
            '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nCurrentStep, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOrderKey, 
               @cOutfield01 OUTPUT, @cOutfield02 OUTPUT, @cOutfield03 OUTPUT, @cOutfield04 OUTPUT, @cOutfield05 OUTPUT, @cOutfield06 OUTPUT, 
               @tExtendedInfo, @nErrNo OUTPUT, @cErrMsg OUTPUT
           
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END  -- IF @cExtendedInfoSP <> ''    
   GOTO Quit      
      
   STEP_3_FAIL:      
   BEGIN      
    
      -- Prepare Next Screen Variable      
      SET @cOutField03 = @cTrackNo
      SET @cOutField05 = @cCartonType
      SET @cOutField07 = @cWeight
          
      
   END      
END       
GOTO QUIT      

/********************************************************************************      
Step 4. Scn = 4683.       
   
   1 = SHORT PACK
   5 = NEW PACK
   9 = EXIT PACK
   Option (field01, input)      
         
    
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cOption = ISNULL(RTRIM(@cInField01),'')      
      

    
      IF @cOption = ''      
      BEGIN      
         SET @nErrNo = 101411      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq    
         GOTO Step_4_Fail      
      END    
      
      IF @cOption NOT IN ( '1', '5', '9' ) 
      BEGIN
         SET @nErrNo = 101412
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption    
         GOTO Step_4_Fail     
      END  
      
      
      
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_4_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
      
      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @cSKU        = @cSKU,
        @cTrackingNo    = @cTrackNo, 
        @cCartonType = @cCartonType,
        @fWeight     = @cWeight ,
        @cOption     = @cOption,
        @nStep       = @nStep 
      
      -- 1 = Tote Still have remaining to pack
      -- 5 = Go to Pack Info Screen
      -- 9 = Exit
      IF @cTaskStatus = '1'
      BEGIN
         
         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty
         
         -- Remember the current scn & step
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         
         EXEC rdt.rdtSetFocusField @nMobile, 4     
         
      END
      ELSE IF @cTaskStatus = '5'
      BEGIN
         
         IF @cPostDataCapture <> '0'
         BEGIN
            
            SET @cOutField02 = '' 
            SET @cOutField04 = '' 
            SET @cOutField06 = '' 
            
            IF CHARINDEX ( 'T', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField02 = 'TRACK NO:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr03 = 'O'
            END
            
            
            IF CHARINDEX ( 'C', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField04 = 'CARTON TYPE:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr05 = 'O'
            END
            
            IF CHARINDEX ( 'W', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField06 = 'WEIGHT:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr07 = 'O'
            END
            
            SET @cOutField01 = @cOrderKey 
            SET @cOutField03 = @cTrackNo 
            SET @cOutField05 = @cCartonType 
            SET @cOutField07 = @cWeight
            
            -- GOTO Next Screen        
            SET @nScn = @nScn - 1        
            SET @nStep = @nStep - 1        
                    
            
         END
         ELSE
         BEGIN
            
            SET @cOutField01 = ''
            
            -- Back to Screen 1      
            SET @nScn = @nScn - 3        
            SET @nStep = @nStep - 3   
                    
            
         END
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
            SET @cOutField01 = ''
            
            -- Back to Screen 1      
            SET @nScn = @nScn - 3        
            SET @nStep = @nStep - 3   
            
      END

    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0       
   BEGIN      
     
        
      SET @cOutField01 = @cDropIDType
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      

      -- Remember the current scn & step
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

        
  
   END      
   GOTO Quit      
      
   STEP_4_FAIL:      
   BEGIN      
    
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''   
          
      
   END      
END       
GOTO QUIT   

   
  
/********************************************************************************      
Step 5. Scn = 4684.       
   Tote
   Option         (field07, input)      
         
    
********************************************************************************/      
Step_5:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
      
      SET @cOption = ISNULL(RTRIM(@cInField07),'')      
      
    
      IF @cOption = ''      
      BEGIN      
         SET @nErrNo = 101413      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq    
         GOTO Step_5_Fail      
      END     
      
      IF @cOption NOT IN ( '1', '9' ) 
      BEGIN      
         SET @nErrNo = 101414      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID    
         GOTO Step_5_Fail      
      END    
      
      
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_4_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
      
      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @cSKU        = @cSKU,
        @cTrackingNo    = @cTrackNo, 
        @cCartonType = @cCartonType,
        @fWeight     = @cWeight ,
        @cOption     = @cOption,
        @nStep       = @nStep 
    
      IF @cTaskStatus = '1' 
      BEGIN
          
         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty
      
         -- Go to Screen 2       
         SET @nScn = @nScn - 3        
         SET @nStep = @nStep - 3   
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         
         -- Back to Screen 1        
         SET @nScn = @nScn - 4        
         SET @nStep = @nStep - 4        
      END
      
      
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0       
   BEGIN      
      
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      
      -- Back to Screen 1        
      SET @nScn = @nScn - 4        
      SET @nStep = @nStep - 4        
        
  
  
   END      
   GOTO Quit      
      
   STEP_5_FAIL:      
   BEGIN      
    
      -- Prepare Next Screen Variable      
      SET @cOutField07 = ''   
          
      
   END      
END       
GOTO QUIT  

/********************************************************************************
Step 6. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cStorerKey,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
   END

   SELECT @cDropIDType = DropIDType
   FROM dbo.DropID WITH (NOlOCK) 
   WHERE DropID = @cDropID

   SET @cOutField01 = @cDropIDType
   SET @cOutField02 = @cDropID
   SET @cOutField03 = @cOrderKey
   SET @cOutField04 = @cSKU
   SET @cOutField05 = @cTTLPickedQty
   SET @cOutField06 = @cTTLScannedQty
         
   EXEC rdt.rdtSetFocusField @nMobile, 4        
      
   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nFromStep

END
GOTO Quit

/********************************************************************************
Step 7. Screen = 4830. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cDescr, 1, 'UPDATE', 'PICKSLIP', @cPickSlipNo, 
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT, 
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn, 
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '3'

      IF @nErrNo <> 0
         GOTO Quit

      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@cOption        NVARCHAR( 1),   ' +     
               '@cOrderKey      NVARCHAR( 10) OUTPUT,  ' +     
               '@cTrackNo       NVARCHAR( 20) OUTPUT,  ' +     
               '@cCartonType    NVARCHAR( 10) OUTPUT,  ' +  
               '@cWeight        NVARCHAR( 20) OUTPUT,  ' +    
               '@cTaskStatus    NVARCHAR( 20) OUTPUT,  ' +    
               '@cTTLPickedQty  NVARCHAR( 10) OUTPUT,  ' + 
               '@cTTLScannedQty NVARCHAR( 10) OUTPUT,  ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @cOption, @cOrderKey OUTPUT, @cTrackNo OUTPUT, @cCartonType OUTPUT, @cWeight OUTPUT, @cTaskStatus OUTPUT, @cTTLPickedQty OUTPUT, @cTTLScannedQty OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
        
            IF @nErrNo <> 0    
               GOTO Step_7_Quit    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
      
      -- 1 = Tote Still have remaining to pack
      -- 9 = Tote need to go to Pack Info screen after Pack by Orders
      IF @cTaskStatus = '1'
      BEGIN

         SET @cOutField01 = @cDropIDType
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTLPickedQty
         SET @cOutField06 = @cTTLScannedQty

         -- GOTO Next Screen        
         SET @nScn = @nFromScn       
         SET @nStep = @nFromStep        
                 
         EXEC rdt.rdtSetFocusField @nMobile, 4     
         
      END
      ELSE IF @cTaskStatus = '5' -- FOR MULTI HAVE Remaining --
      BEGIN
           -- GOTO Next Screen        
            SET @nScn = @nFromScn - 1        
            SET @nStep = @nFromStep - 1        
            
            SET @cOutField01 = ''
                    
            EXEC rdt.rdtSetFocusField @nMobile, 1
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
         
         IF @cPostDataCapture <> ''
         BEGIN
            
            SET @cOutField02 = '' 
            SET @cOutField04 = '' 
            SET @cOutField06 = '' 
            
            IF CHARINDEX ( 'T', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField02 = 'TRACK NO:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr03 = 'O'
            END
            
            
            IF CHARINDEX ( 'C', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField04 = 'CARTON TYPE:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr05 = 'O'
            END
            
            IF CHARINDEX ( 'W', @cPostDataCapture ) > 0
            BEGIN
               SET @cOutField06 = 'WEIGHT:'
            END
            ELSE 
            BEGIN
               SET @cFieldAttr07 = 'O'
            END
            
            SET @cOutField01 = @cOrderKey 
            SET @cOutField03 = @cTrackNo 
            SET @cOutField05 = @cCartonType 
            SET @cOutField07 = @cWeight
            
            -- GOTO Next Screen        
            SET @nScn = @nFromScn + 1       
            SET @nStep = @nFromStep + 1        
                   
            EXEC rdt.rdtSetFocusField @nMobile, 4     
         END
         ELSE
         BEGIN
            -- GOTO Next Screen        
            SET @nScn = @nFromScn - 1        
            SET @nStep = @nFromStep - 1        
            
            SET @cOutField01 = ''
                    
            EXEC rdt.rdtSetFocusField @nMobile, 1
         END
      END

      EXEC RDT.rdt_STD_EventLog  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cDropID     = @cDropID,
        @cSKU        = @cSKU,
        @nQty        = 1,
        @nStep       = @nCurrentStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @cDropIDType = DropIDType
      FROM dbo.DropID WITH (NOlOCK) 
      WHERE DropID = @cDropID

      SET @cOutField01 = @cDropIDType
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = ''
      SET @cOutField05 = @cTTLPickedQty
      SET @cOutField06 = @cTTLScannedQty
         
      -- GOTO Next Screen        
      SET @nScn = @nFromScn        
      SET @nStep = @nFromStep        
                 
      EXEC rdt.rdtSetFocusField @nMobile, 4        
   END
   
   Step_7_Quit:
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
  
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,  
      -- UserName  = @cUserName,  
  
      V_SKU     = @cSKU,  
      V_SKUDescr= @cDescr,  
      V_UOM     = @cPUOM,  
      V_OrderKey = @cOrderKey, 

      V_FromScn  = @nFromScn,
      V_FromStep = @nFromStep,
   
      V_Integer1 = @cTTLPickedQty, 
      V_Integer2 = @cTTLScannedQty,
      V_Integer3 = @nAfterStep,

      V_String1 = @cExtendedUpdateSP   ,   
      V_String2 = @cExtendedValidateSP ,   
      V_String3 = @cDecodeLabelNo      ,
      V_String4 = @cPostDataCapture    ,
      V_String5 = @cDisplayLongErrMsg  , 
      V_String6 = @cDropID             , 
      V_String7 = @cExtendedInfoSP     ,
      V_String8   = @cCartonType       ,
      V_String9   = @cTrackNo          ,    
      V_String10  = @cWeight           ,     
      V_String11  = @cDropIDType       , -- (ChewKP01) 
      V_String12  = @cMultiSKUBarcode  , -- (james03)
      V_String13  = @cTaskStatus       , -- (james03)
      V_String14  = @cSerialNoCapture  , -- (james04)
      V_String15  = @cMultiToteOrdersNotAllow,  -- (james05)
      
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