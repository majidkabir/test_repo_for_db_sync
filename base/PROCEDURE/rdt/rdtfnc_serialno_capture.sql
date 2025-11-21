SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
     
/******************************************************************************/       
/* Copyright: LF                                                              */       
/* Purpose:                                                                   */       
/*                                                                            */       
/* Modifications log:                                                         */       
/*                                                                            */       
/* Date       Rev  Author     Purposes                                        */       
/* 2017-06-20 1.0  ChewKP     Created. WMS-2266                               */    
/* 2018-10-05 1.1  Gan        Performance tuning                              */  
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_SerialNo_Capture] (      
   @nMobile    int,      
   @nErrNo     int  OUTPUT,      
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max      
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
-- Misc variable      
DECLARE       
   @nCount      INT,      
   @nRowCount   INT      
      
-- RDT.RDTMobRec variable      
DECLARE       
   @nFunc      INT,      
   @nScn       INT,      
   @nStep      INT,      
   @cLangCode  NVARCHAR( 3),      
   @nInputKey  INT,      
   @nMenu      INT,      
      
   @cStorerKey NVARCHAR( 15),      
   @cFacility  NVARCHAR( 5),       
   @cPrinter   NVARCHAR( 20),       
   @cUserName  NVARCHAR( 18),      
         
   @nError            INT,      
   @b_success         INT,      
   @n_err             INT,           
   @c_errmsg          NVARCHAR( 250),       
   @cPUOM             NVARCHAR( 10),          
   @bSuccess          INT,      
   @cDataWindow		 NVARCHAR( 50),  
   @cTargetDB    		 NVARCHAR( 20), 
   @cWorkOrderNo      NVARCHAR( 10),
   @cSerialNo         NVARCHAR( 20),
   @cMasterSerialNo   NVARCHAR(20), 
   @cSQL              NVARCHAR(1000), 
   @cSQLParam         NVARCHAR(1000), 
   @cDataWindowGTIN   NVARCHAR(50),
   @cPrinter9L        NVARCHAR( 20),      
   @cPrinterInner     NVARCHAR( 20),      
   @cPrinterMaster    NVARCHAR( 20),      
   @cPrinterGTIN      NVARCHAR( 20),
   @cSKUInput         NVARCHAR( 20), 
   @cSKU              NVARCHAR( 20),
   @cToteID           NVARCHAR( 20),
   @nSKUCnt           INT,
   @cOption           NVARCHAR(1),
   
 
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
   @cFieldAttr15 NVARCHAR( 1)      
         
-- Load RDT.RDTMobRec      
SELECT       
   @nFunc      = Func,      
   @nScn       = Scn,      
   @nStep      = Step,      
   @nInputKey  = InputKey,      
   @nMenu      = Menu,      
   @cLangCode  = Lang_code,      
      
   @cStorerKey = StorerKey,      
   @cFacility  = Facility,      
   @cPrinter   = Printer,       
   @cUserName  = UserName,      
   --@cLightMode  = LightMode,  
   @cSKU       = V_SKU,  
   --@cSKUDescr   = V_SKUDescr,  
   
   --@cLot        = V_Lot,  
   @cPUOM     = V_UOM,     
   
         
   @cToteID             = V_String1,    
   @cMasterSerialNo     = V_String2, 
   
         
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,      
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,      
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,      
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,      
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,      
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,      
   @cFieldAttr15 =  FieldAttr15      
      
FROM RDTMOBREC (NOLOCK)      
WHERE Mobile = @nMobile      
      
Declare @n_debug INT      
      
SET @n_debug = 0      
      
      
IF @nFunc = 824  -- Serial No SKU Change
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- Serial No Capture
   IF @nStep = 1 GOTO Step_1   -- Scn = 4940. Tote ID 
   IF @nStep = 2 GOTO Step_2   -- Scn = 4941. SKU 
   IF @nStep = 3 GOTO Step_3   -- Scn = 4942. MasterSerialNo
   IF @nStep = 4 GOTO Step_4   -- Scn = 4943. SerialNo 
   IF @nStep = 5 GOTO Step_5   -- Scn = 4944. Print Label
         
END      
      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 824. Menu      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Get prefer UOM      
   SET @cPUOM = ''      
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA      
   FROM RDT.rdtMobRec M WITH (NOLOCK)      
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)      
   WHERE M.Mobile = @nMobile      
       
       
      
   -- Initiate var      
   -- EventLog - Sign In Function      
   EXEC RDT.rdt_STD_EventLog      
     @cActionType = '1', -- Sign in function      
     @cUserID     = @cUserName,      
     @nMobileNo   = @nMobile,      
     @nFunctionID = @nFunc,      
     @cFacility   = @cFacility,      
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep      
           
   
   
   -- Init screen      
   SET @cOutField01 = ''       
   SET @cOutField02 = ''      
     

      
   -- Set the entry point      
   SET @nScn = 4940      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Scn = 4940.      
   ToteID     (field01 , input)      
     
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cToteID = ISNULL(RTRIM(@cInField01),'')      
          
      IF @cWorkOrderNo = ''
      BEGIN
         SET @nErrNo = 111351      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteIDReq    
         GOTO Step_1_Fail  
      END
      
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
          
       -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = @cToteID  
      SET @cOutField02 = ''
      
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
      EXEC RDT.rdt_STD_EventLog      
        @cActionType = '9', -- Sign in function      
        @cUserID     = @cUserName,      
        @nMobileNo   = @nMobile,      
        @nFunctionID = @nFunc,      
        @cFacility   = @cFacility,      
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep      
              
      --go to main menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = ''      
  
   END      
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''    
     
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 4941.       
       
   Tote ID         (field01)      
   To SKU          (field02, input)    
   
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cSKUInput     = ISNULL(RTRIM(@cInField02),'')      
  
      
      IF @cSKUInput = ''      
      BEGIN      
         SET @nErrNo = 111352      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'    
         GOTO Step_2_Fail    
      END      
      
      -- Get SKU barcode count    
      --DECLARE @nSKUCnt INT    
      EXEC rdt.rdt_GETSKUCNT    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      -- Check SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 111353    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         GOTO Step_2_Fail    
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 111354    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         GOTO Step_2_Fail    
      END    
      
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput     OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      IF @nErrNo = 0 
      BEGIN
         SET @cSKU = @cSKUInput
      END
      
      
--      SELECT @cPrinter9L = UDF01 
--            ,@cPrinterInner = UDF02 
--            ,@cPrinterMaster = UDF03
--            ,@cPrinterGTIN = UDF04
--      FROM dbo.CodeLkup WITH (NOLOCK) 
--      WHERE ListName = 'SERIALPRN'
--      AND StorerKey = @cStorerKey
--      AND Code = @cUserName 
      
      
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
        
      SET @cOutField01 = @cToteID   
      SET @cOutField02 = @cSKU
      SET @cOutField03 = ''      
      
      
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
         
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
         
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
 
      SET @cOutField02 = ''
            
   END      
      
END       
GOTO QUIT      
      

/********************************************************************************      
Step 3. Scn = 4942.       
       
   Tote ID         (field01)      
   SKU             (field02)    
   MasterSerialNo  (field03, input)    
   
         
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cMasterSerialNo     = ISNULL(RTRIM(@cInField03),'')      
  
      
      IF @cMasterSerialNo = ''      
      BEGIN      
         SET @nErrNo = 111355      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MasterSerialReq'    
         GOTO Step_3_Fail    
      END      
      
      IF RIGHT( RTRIM(@cMasterSerialNo) , 1 ) NOT IN ( 'M', 'C' ) 
      BEGIN
         SET @nErrNo = 111356      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvMasterSerialNo'    
         GOTO Step_3_Fail   
      END
      
      
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
        
      SET @cOutField01 = @cToteID   
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cMasterSerialNo    
      SET @cOutField04 = ''
      
      
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = @cToteID 
       SET @cOutField02 = ''
         
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
         
   END      
   GOTO Quit      
         
   Step_3_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
 
      SET @cOutField03 = ''
            
   END      
      
END       
GOTO QUIT    


/********************************************************************************      
Step 4. Scn = 4943.       
       
   Tote ID         (field01)      
   SKU             (field02)    
   MasterSerialNo  (field03)    
   SerialNo        (field04, input)    
   
         
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cSerialNo     = ISNULL(RTRIM(@cInField04),'')      
  
      
      IF @cSerialNo = ''      
      BEGIN      
         SET @nErrNo = 111357      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SerialNoReq'    
         GOTO Step_4_Fail    
      END      
      
      IF RIGHT( RTRIM(@cSerialNo) , 1 ) NOT IN ( '9', 'C' ) 
      BEGIN
         SET @nErrNo = 111358      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvSerialNo'    
         GOTO Step_4_Fail   
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtDataCapture WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND Facility  = @cFacility 
                  AND V_String1 = @cToteID 
                  AND V_SKU     = @cSKU
                  AND V_String2 = @cMasterSerialNo
                  AND V_String3 = @cSerialNo ) 
      BEGIN
         SET @nErrNo = 111362      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SerialNoScanned'    
         GOTO Step_4_Fail  
      END
      
      -- Insert into Data Capture Table
      
      INSERT INTO rdt.rdtDataCapture (StorerKey, Facility, V_SKU, V_String1, V_String2, V_String3 )  
      VALUES(@cStorerKey, @cFacility, @cSKU, @cToteID, @cMasterSerialNo, @cSerialNo )
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 111359      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDataCaptureFail'    
         GOTO Step_4_Fail  
      END  
      
      
      
      SET @cOutField01 = @cToteID   
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cMasterSerialNo    
      SET @cOutField04 = ''
      
      
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = @cToteID 
       SET @cOutField02 = @cSKU
       SET @cOutField03 = @cMasterSerialNo    
       SET @cOutField04 = ''
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn + 1      
       SET @nStep = @nStep + 1      
             
         
   END      
   GOTO Quit      
         
   Step_4_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
 
      SET @cOutField04 = ''
            
   END      
      
END       
GOTO QUIT    


/********************************************************************************      
Step 5. Scn = 4944.       
       
   Tote ID         (field01)      
   SKU             (field02)    
   MasterSerialNo  (field03)    
   Option          (field04, input)  
   
         
********************************************************************************/      
Step_5:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cOption     = ISNULL(RTRIM(@cInField04),'')      
  
      
      IF @cOption = ''      
      BEGIN      
         SET @nErrNo = 111360      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'    
         GOTO Step_5_Fail    
      END      
      
      IF ISNULL(@cOption, '')  NOT IN ( '1', '9' ) 
      BEGIN
         SET @nErrNo = 111361  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvOption'    
         GOTO Step_5_Fail   
      END
      
      IF @cOption = '1'
      BEGIN
          
          EXEC RDT.rdt_BuiltPrintJob      
                @nMobile,      
                @cStorerKey,      
                'SERIALLBL',    -- ReportType      
                'SERIALLBL',    -- PrintJobName      
                @cDataWindow,      
                @cPrinter,      
                @cTargetDB,      
                @cLangCode,      
                @nErrNo  OUTPUT,      
                @cErrMsg OUTPUT,    
                @cToteID,   
                @cSKU, 
                @cMasterSerialNo
         
         IF @nErrNo <> 0 
         BEGIN
            GOTO Step_5_Fail
         END
                
         
         SET @cOutField01 = @cToteID   
         SET @cOutField02 = ''
         
         -- Goto SKU Screen 
         SET @nScn = @nScn - 3    
         SET @nStep = @nStep - 3 
      
      END
      ELSE IF @cOption = '9'
      BEGIN
      
         
         SET @cOutField01 = @cToteID   
         SET @cOutField02 = @cSKU
         SET @cOutField03 = @cMasterSerialNo    
         SET @cOutField04 = ''
         
         SET @nScn = @nScn - 1      
         SET @nStep = @nStep - 1    
      END
      
      
      
      
      
      
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = @cToteID 
       SET @cOutField02 = @cSKU
       SET @cOutField03 = @cMasterSerialNo    
       SET @cOutField04 = ''
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
         
   END      
   GOTO Quit      
         
   Step_5_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
 
      SET @cOutField04 = ''
            
   END      
      
END       
GOTO QUIT   
      
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
      
      StorerKey = @cStorerKey,      
      Facility  = @cFacility,       
      Printer   = @cPrinter,       
      --UserName  = @cUserName,     
      EditDate  = GetDate() ,  
      InputKey  = @nInputKey,   
      --LightMode = @cLightMode,  
            
      --V_SKUDescr = @cSKUDescr,  
      --V_UOM = @cPUOM,  
      V_SKU = @cSKU,   
      --V_Qty = @nExpectedQTY,  
      --V_Lot = @cLot,
    
      V_String1 = @cToteID,  
      V_String2 = @cMasterSerialNo,
      

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