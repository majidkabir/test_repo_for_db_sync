SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/***************************************************************************/      
/* Store procedure: rdtfnc_Mbol_ChildCreation                               */      
/* Copyright      : LF Logistics                                           */      
/*                                                                         */      
/* Purpose: Populate orders into MBOL, MBOLDetail                          */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date         Rev  Author   Purposes                                     */      
/* 2022-12-23   1.0  yeekung  WMS-21331 Created                            */     
/***************************************************************************/      
      
CREATE   PROC [RDT].[rdtfnc_Mbol_ChildCreation](      
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
   @cSQLParam      NVARCHAR(MAX)      
      
-- RDT.RDTMobRec variables      
DECLARE      
   @nFunc          INT,      
   @nScn           INT,      
   @nStep          INT,      
   @cLangCode      NVARCHAR( 3),      
   @nInputKey      INT,      
   @nMenu          INT,   
   @nCaseCnt       INT,
         
   @cStorerKey     NVARCHAR( 15),      
   @cUserName      NVARCHAR( 18),      
   @cFacility      NVARCHAR( 5),      
   @cExtendedInfo       NVARCHAR( 20),      
   @cExtendedInfoSP     NVARCHAR( 20),      
   @cExtendedUpdateSP   NVARCHAR( 20),      
   @cExtendedValidateSP NVARCHAR( 20),      
   @cOption             NVARCHAR( 1),          
   @cMBOLKey            NVARCHAR( 10),    
   @cCaseID             NVARCHAR( 20),
   @cLockFacility       NVARCHAR( 20),
   @cUserdefine02       NVARCHAR( 20),
   @nOrderCnt           INT,    
   @tMbolCreate         VARIABLETABLE,    
   @tExtValidate        VariableTable,       
   @tExtUpdate          VariableTable,       
   @tExtInfo            VariableTable,    
   @cPalletKey          NVARCHAR( 20),
   @cStoreCode          NVARCHAR( 20),
   @cDropID             NVARCHAR( 20),

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
          
   @cExtendedUpdateSP   = V_String1,      
   @cExtendedValidateSP = V_String2,      
   @cExtendedInfoSP     = V_String3,      
   @cMBOLKey            = V_String4,             
   @cPalletKey          = V_String5,       
   @cLockFacility       = V_String6,   
   @cCaseID             = V_String7,       
   @cDropID             = V_String8,       
   @cUserdefine02       = V_String9, 
       
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
   @nStep_Facility            INT,  @nScn_Facility          INT,      
   @nStep_Scan                INT,  @nScn_Scan              INT,      
   @nStep_OrderCreate         INT,  @nScn_OrderCreate       INT    
      
SELECT      
   @nStep_Facility            = 1,  @nScn_Facility             = 6180,      
   @nStep_Scan                = 2,  @nScn_Scan                 = 6181,      
   @nStep_OrderCreate         = 3,  @nScn_OrderCreate          = 6182   
      
      
IF @nFunc = 1861      
BEGIN      
   -- Redirect to respective screen      
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1861      
   IF @nStep = 1  GOTO Step_Facility         -- Scn = 6180. Facility    
   IF @nStep = 2  GOTO Step_Scan             -- Scn = 6181. Scan dropid,palletid, udf02, caseid     
   IF @nStep = 3  GOTO Step_OrderCreate      -- Scn = 6182. OrderCreated         
END      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step_Start. Func = 1861      
********************************************************************************/      
Step_Start:      
BEGIN      
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)      
   IF @cExtendedValidateSP = '0'        
      SET @cExtendedValidateSP = ''      
      
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)      
   IF @cExtendedUpdateSP = '0'        
      SET @cExtendedUpdateSP = ''      
      
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)      
   IF @cExtendedInfoSP = '0'      
      SET @cExtendedInfoSP = ''      
       
   SET @cLockFacility = rdt.rdtGetConfig( @nFunc, 'LockFacility', @cStorerKey)     

    
   -- Prepare next screen var      
   SET @cOutField01 = @cFacility      
   SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
   -- Logging      
   EXEC RDT.rdt_STD_EventLog      
      @cActionType     = '1', -- Sign-in      
      @cUserID         = @cUserName,      
      @nMobileNo       = @nMobile,      
      @nFunctionID     = @nFunc,      
      @cFacility       = @cFacility,      
      @cStorerKey      = @cStorerKey,      
      @nStep           = @nStep      
    
   SET @cMBOLKey = ''    
   SET @cPalletKey = '' 
   SET @cCaseID         = ''
   SET @cDropID         = ''     
   SET @cUserdefine02   = ''    

   -- Go to next screen      
   SET @nScn = @nScn_Facility      
   SET @nStep = @nStep_Facility      
END      
GOTO Quit      
      
/************************************************************************************      
Scn = 6180. Scan Facility      
   Facility    (field01, input)      
************************************************************************************/      
Step_Facility:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping        
      SET @cFacility = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END     
      SET @cMBOLKey =  @cInField02
        
      -- Check blank        
      IF @cFacility = ''        
      BEGIN        
         SET @nErrNo = 195151        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Facility        
         GOTO Step_Facility_Fail        
      END        
        
      -- Check facility valid        
      IF NOT EXISTS( SELECT 1 FROM dbo.FACILITY WITH (NOLOCK) WHERE Facility = @cFacility)        
      BEGIN        
         SET @nErrNo = 195152        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Facility        
         GOTO Step_Facility_Fail        
      END   

      IF ISNULL(@cMBOLKey,'') <>''
      BEGIN
         
         -- Check facility valid        
         IF NOT EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKEY= @cMBOLKey )        
         BEGIN        
            SET @nErrNo = 195153      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv MBOL       
            GOTO Step_Facility_Fail        
         END    

               -- Check facility valid        
         IF  EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKEY= @cMBOLKey AND STATUS='9')        
         BEGIN        
            SET @nErrNo = 195154        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv MBOL       
            GOTO Step_Facility_Fail        
         END    
      END
        
      -- Extended validate      
      IF @cExtendedValidateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cPalletKey, @cCaseID, @cDropID, @cUserdefine02, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '      
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cMBOLKey       NVARCHAR( 10), ' +      
               ' @cPalletKey     NVARCHAR( 20), ' +      
               ' @cCaseID        NVARCHAR( 20), ' +      
               ' @cDropID        NVARCHAR( 20), ' +      
               ' @cUserdefine02  NVARCHAR( 20), ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cPalletKey, @cCaseID, @cDropID, @cUserdefine02,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT      
      
            IF @nErrNo <> 0       
               GOTO Step_Facility_Fail      
         END      
      END      
    
      -- Prepare next screen var      
      SET @cOutField01 = @cMBOLKey      
      SET @cOutField02 = ''      
      SET @cOutField03 = ''      
      SET @cOutField04 = ''      
      SET @cOutField15 = ''    

      SET @cPalletKey = '' 
      SET @cCaseID         = ''
      SET @cDropID         = ''     
      SET @cUserdefine02   = ''    

      EXEC rdt.rdtSetFocusField @nMobile, 2    
          
      -- Go to next screen      
      SET @nScn = @nScn_Scan      
      SET @nStep = @nStep_Scan       
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
      
   Step_Facility_Fail:      
   BEGIN      
      SET @cFacility = ''      
      SET @cOutField01 = ''      
   END      
         
   GOTO Quit      
END      
GOTO Quit      
      
/***********************************************************************************      
Scn = 6181. Scan screen      
   Facility    (field01)               
   OrderKey    (field02, input)          
   palletid    (field03, input)          
   RefNo1      (field04, input)           
   RefNo2      (field05, input)     
   RefNo3      (field06, input)          
***********************************************************************************/      
Step_Scan:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping         
      SET @cPalletKey = @cInField02      
      SET @cCaseID = @cInField03    
      SET @cDropID = @cInField04    
      SET @cUserdefine02 = @cInField05
      
      IF ISNULL( @cCaseID, '') = ''
         AND ISNULL( @cPalletKey, '') = ''  
         AND  ISNULL( @cDropID, '') =  ''   
         AND  ISNULL( @cUserdefine02, '') =  ''   
      BEGIN      
         SET @nErrNo = 195155      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req      
         GOTO Step_Scan_Fail      
      END      
          
      -- LoadKey    
      IF @cPalletKey <> ''    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.Palletdetail PD WITH (NOLOCK)   
                           JOIN LOC LOC (NOLOCK) ON PD.LOC=LOC.LOC
                         WHERE palletkey = @cPalletKey    
                         AND   LOC.Facility = @cFacility)  
         BEGIN      
            SET @nErrNo = 195156     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid   pallet
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Step_Scan_Fail      
         END      
      END    

      IF @cDropID <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dropid (NOLOCK)
                 WHERE dropid = @cDropID
                 AND dropidType ='B')  
         BEGIN      
            SET @nErrNo = 195157      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid dropid      
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Step_Scan_Fail      
         END 
      END

      IF @cCaseid <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM pickdetail (NOLOCK)
                 WHERE caseid = @cCaseid
                 AND Storerkey =@cStorerkey
                 AND status IN ( '3','5'))  
         BEGIN      
            SET @nErrNo = 195158      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid dropid      
            EXEC rdt.rdtSetFocusField @nMobile, 4 
            GOTO Step_Scan_Fail      
         END 
      END
    
      -- Extended validate      
      IF @cExtendedValidateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cPalletKey, @cCaseID, @cDropID, @cUserdefine02, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '      
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cMBOLKey       NVARCHAR( 10), ' +      
               ' @cPalletKey     NVARCHAR( 20), ' +      
               ' @cCaseID        NVARCHAR( 20), ' +      
               ' @cDropID        NVARCHAR( 20), ' +      
               ' @cUserdefine02  NVARCHAR( 20), ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cPalletKey, @cCaseID, @cDropID, @cUserdefine02,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT      

            IF @nErrNo <> 0       
               GOTO Step_Scan_Fail      
         END      
      END      

      EXEC rdt.rdt_MbolChildCreation    
          @nMobile      = @nMobile    
         ,@nFunc        = @nFunc    
         ,@cLangCode    = @cLangCode    
         ,@nStep        = @nStep    
         ,@nInputKey    = @nInputKey    
         ,@cFacility    = @cFacility    
         ,@cStorerKey   = @cStorerKey       
         ,@cPalletKey   = @cPalletKey  
         ,@cCaseID      = @cCaseID 
         ,@cDropID      = @cDropID  
         ,@cUserdefine02  = @cUserdefine02      
         ,@cMBOLKey     = @cMBOLKey    OUTPUT    
         ,@cStoreCode   = @cStoreCode   OUTPUT 
         ,@nCaseCnt     = @nCaseCnt    OUTPUT 
         ,@nErrNo       = @nErrNo      OUTPUT    
         ,@cErrMsg      = @cErrMsg     OUTPUT    
    
      IF @nErrNo <> 0    
         GOTO Step_Scan_Fail   

      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = @cStoreCode
      SET @cOutField03 = @nCaseCnt
         
      -- Go to next screen      
      SET @nScn = @nScn_OrderCreate      
      SET @nStep = @nStep_OrderCreate 

   END      
   IF @nInputKey = 0 -- ESC      
   BEGIN        
      -- Prepare next screen var      
      SET @cOutField01 = @cFacility      
      SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
      SET @cMBOLKey = ''     
      SET @cPalletKey = '' 
      SET @cCaseID         = ''
      SET @cDropID         = ''     
      SET @cUserdefine02   = ''    
      
      -- Go to next screen      
      SET @nScn = @nScn_Facility     
      SET @nStep = @nStep_Facility      
   END      
   GOTO Quit      
    
   Step_Scan_Fail:    
   BEGIN    
      SET @cOutField01 = @cMBOLKey         
      SET @cOutField02 = ''       
      SET @cOutField03 = ''    
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Scn = 6182. Order Completed Scan       
   MBOLKey  (field01)      
   StoreCode (field02, input)      
********************************************************************************/      
Step_OrderCreate:      
BEGIN  
   SET @cOutField01 = @cMBOLKey         
   SET @cOutField02 = ''       
   SET @cOutField03 = ''    
          
   
   -- Go to next screen      
   SET @nScn = @nScn_Scan     
   SET @nStep = @nStep_Scan   
        
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
      
      V_Integer1 = @nOrderCnt,      
  
      V_String1  = @cExtendedUpdateSP,      
      V_String2  = @cExtendedValidateSP,    
      V_String3  = @cExtendedInfoSP,      
      V_String4  = @cMBOLKey     ,
      V_String5  = @cPalletKey   ,
      V_String6  = @cLockFacility,
      V_String7  = @cCaseID      ,
      V_String8  = @cDropID      ,
      V_String9  = @cUserdefine02,
          
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