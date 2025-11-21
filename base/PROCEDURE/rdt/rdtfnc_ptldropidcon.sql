SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/******************************************************************************/                 
/* Copyright: LF                                                              */                 
/* Purpose: THGSG ECom Contingency                                            */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-06-17 1.0  YeeKung    WMS-10055 Created                               */                
/******************************************************************************/                
                
CREATE PROC [RDT].[rdtfnc_PTLDROPIDCon] (                
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
   @nCount              INT,                  
   @nRowCount           INT            
            
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
   @cPrinter            NVARCHAR( 20),                   
   @cUserName           NVARCHAR( 18),                  
                     
   @nError              INT,                  
   @b_success           INT,                  
   @n_err               INT,                       
   @c_errmsg            NVARCHAR( 250),                   
   @cPUOM               NVARCHAR( 10),                      
   @bSuccess            INT,                  
                  
   @cPTSZone            NVARCHAR(10),                  
   @cUserID             NVARCHAR(18),                
   @cDropID             NVARCHAR(20),            
   @cDeviceID           NVARCHAR(60),                
   @cSQL                NVARCHAR(1000),                 
   @cSQLParam           NVARCHAR(1000),                 
   @cExtendedUpdateSP   NVARCHAR(30),                  
   @nTotalAssignDropID  INT,                
   @cOption             NVARCHAR(1),                
   @cSuggLoc            NVARCHAR(10),                
   @cSuggTote           NVARCHAR(10),    
   @cOldSuggLoc         NVARCHAR(10),    
   @cOldSuggTote        NVARCHAR(10),          
   @cLightMode          NVARCHAR(10),                
   @cPTSLoc             NVARCHAR(10),              
   @cWaveKey            NVARCHAR(10),              
   @cPTLWaveKey         NVARCHAR(10),              
   @nMaxDropID          INT,              
   @nAssignDropID       INT,        
   @cOrderkey           NVARCHAR(20),    
   @cSuggSKU            NVARCHAR(20),    
   @cSuggSKUDesc1       NVARCHAR(20),    
   @cSuggSKUDesc2       NVARCHAR(20),    
   @cSuggSKUDesc3       NVARCHAR(20),    
   @cSuggQty            NVARCHAR(5),    
   @cToteID             NVARCHAR(10),    
   @cEndRemark          NVARCHAR(10),     
    
   @cInField01 NVARCHAR( 60),    @cOutField01 NVARCHAR( 60),                  
   @cInField02 NVARCHAR( 60),    @cOutField02 NVARCHAR( 60),                  
   @cInField03 NVARCHAR( 60),    @cOutField03 NVARCHAR( 60),                  
   @cInField04 NVARCHAR( 60),    @cOutField04 NVARCHAR( 60),                  
   @cInField05 NVARCHAR( 60),    @cOutField05 NVARCHAR( 60),                  
   @cInField06 NVARCHAR( 60),    @cOutField06 NVARCHAR( 60),                   
   @cInField07 NVARCHAR( 60),    @cOutField07 NVARCHAR( 60),                   
   @cInField08 NVARCHAR( 60),    @cOutField08 NVARCHAR( 60),                   
   @cInField09 NVARCHAR( 60),    @cOutField09 NVARCHAR( 60),                   
   @cInField10 NVARCHAR( 60),    @cOutField10 NVARCHAR( 60),                   
   @cInField11 NVARCHAR( 60),    @cOutField11 NVARCHAR( 60),                   
   @cInField12 NVARCHAR( 60),    @cOutField12 NVARCHAR( 60),                   
   @cInField13 NVARCHAR( 60),    @cOutField13 NVARCHAR( 60),                   
   @cInField14 NVARCHAR( 60),    @cOutField14 NVARCHAR( 60),                   
   @cInField15 NVARCHAR( 60),    @cOutField15 NVARCHAR( 60),                  
                  
   @cFieldAttr01 NVARCHAR( 1),   @cFieldAttr02 NVARCHAR( 1),                  
   @cFieldAttr03 NVARCHAR( 1),   @cFieldAttr04 NVARCHAR( 1),                  
   @cFieldAttr05 NVARCHAR( 1),   @cFieldAttr06 NVARCHAR( 1),                  
   @cFieldAttr07 NVARCHAR( 1),   @cFieldAttr08 NVARCHAR( 1),                  
   @cFieldAttr09 NVARCHAR( 1),   @cFieldAttr10 NVARCHAR( 1),                  
   @cFieldAttr11 NVARCHAR( 1),   @cFieldAttr12 NVARCHAR( 1),                  
   @cFieldAttr13 NVARCHAR( 1),   @cFieldAttr14 NVARCHAR( 1),                  
   @cFieldAttr15 NVARCHAR( 1)                  
                     
-- Load RDT.RDTMobRec                  
SELECT                   
   @nFunc               = Func,                  
   @nScn                = Scn,                  
   @nStep               = Step,                  
   @nInputKey           = InputKey,                  
   @nMenu               = Menu,                  
   @cLangCode           = Lang_code,                  
                  
   @cStorerKey          = StorerKey,                  
   @cFacility           = Facility,                  
   @cPrinter            = Printer,                   
   @cUserName           = UserName,                  
   @cLightMode          = LightMode,              
                   
   @cPUOM               = V_UOM,                 
                     
   @cPTSZone            = V_String1,                  
   @cUserID             = V_String2,                
   @cDropID             = V_String3,                
   @cExtendedUpdateSP   = V_String4,                    
   @cSuggTote           = V_String5,            
   @cDeviceID           = V_String6,        
   @cWaveKey            = V_String7,    
   @cSuggSKU            = V_String8,    
   @cSuggSKUDesc1       = V_String9,    
   @cSuggSKUDesc2       = V_String10,    
   @cSuggSKUDesc3       = V_String11,    
   @cSuggQty            = V_String12,    
   @cSuggLoc            = V_String13,    
   @cOldSuggLoc         = V_String14,    
   @cOldSuggTote        = V_String15,    
   @cEndRemark          = V_String16,             
                    
   @nTotalAssignDropID  = V_Integer1,              
   @nMaxDropID          = V_Integer2,              
                 
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
                  
   @cFieldAttr01  =  FieldAttr01,    @cFieldAttr02    = FieldAttr02,                  
   @cFieldAttr03  =  FieldAttr03,    @cFieldAttr04    = FieldAttr04,                  
   @cFieldAttr05  =  FieldAttr05,    @cFieldAttr06    = FieldAttr06,                  
   @cFieldAttr07  =  FieldAttr07,    @cFieldAttr08    = FieldAttr08,                  
   @cFieldAttr09  =  FieldAttr09,    @cFieldAttr10    = FieldAttr10,                  
   @cFieldAttr11  =  FieldAttr11,    @cFieldAttr12    = FieldAttr12,                  
   @cFieldAttr13  =  FieldAttr13,    @cFieldAttr14    = FieldAttr14,                  
   @cFieldAttr15  =  FieldAttr15                  
                  
FROM RDTMOBREC (NOLOCK)                  
WHERE Mobile = @nMobile                  
                  
Declare @n_debug INT                  
                  
SET @n_debug = 0               
            
IF @nFunc = 1835  -- PTL DropID Cont                  
BEGIN                  
                     
   -- Redirect to respective screen                  
   IF @nStep = 0 GOTO Step_0   -- PTL DropID Cont                  
   IF @nStep = 1 GOTO Step_1   -- Scn = 5550. PTS Zone               
   IF @nStep = 2 GOTO Step_2   -- Scn = 5551. User ID               
   IF @nStep = 3 GOTO Step_3   -- Scn = 5552. DROPID                 
   IF @nStep = 4 GOTO Step_4   -- Scn = 5553. Confirm             
   IF @nStep = 5 GOTO Step_5   -- Scn = 5554. ToteID        
   IF @nStep = 6 GOTO Step_6   -- Scn = 5555. Display       
   IF @nStep = 7 GOTO Step_7   -- Scn = 5556. Display                
                     
END                  
                    
RETURN -- Do nothing if incorrect step       
    
/********************************************************************************                  
Step 0. func = 1835. Menu                  
********************************************************************************/                  
Step_0:                  
BEGIN                  
   -- Get prefer UOM                  
   SET @cPUOM = ''                  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA                  
   FROM RDT.rdtMobRec M WITH (NOLOCK)                  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)                  
   WHERE M.Mobile = @nMobile                  
                   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)                
   IF @cExtendedUpdateSP = '0'                  
   BEGIN                
      SET @cExtendedUpdateSP = ''                
   END                
                 
   SET @nMaxDropID = rdt.RDTGetConfig( @nFunc, 'MaxDropID', @cStorerKey)                
                 
   SET @nMaxDropID = ISNULL(@nMaxDropID, 0 )               
              
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
                     
   SET @cPTSZone = ''                           
                          
   -- Set the entry point                  
   SET @nScn = 5550                  
   SET @nStep = 1                  
                     
   EXEC rdt.rdtSetFocusField @nMobile, 1                  
                     
END            
GOTO Quit                 
         
/********************************************************************************                  
Step 1. Scn = 5550.                     
   PTSZONE         (field01, input)            
********************************************************************************/             
Step_1:                  
BEGIN                  
   IF @nInputKey = 1 --ENTER                  
   BEGIN              
      SET @cPTSZone = ISNULL(RTRIM(@cInField01),'')                  
      
      IF @cPTSZone = ''                  
      BEGIN                  
         SET @nErrNo = 142301                   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTSZoneReq                
         EXEC rdt.rdtSetFocusField @nMobile, 1                  
         GOTO Step_1_Fail                  
      END            
                  
      IF NOT EXISTS ( SELECT 1                  
                      FROM dbo.DeviceProfile DP WITH (NOLOCK)                   
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID                  
                      WHERE Loc.PutawayZone = @cPTSZone                  
                        AND DP.DeviceType = 'LOC' )                   
      BEGIN                  
         SET @nErrNo = 142302                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPTSZone                  
         EXEC rdt.rdtSetFocusField @nMobile, 2                  
         GOTO Step_1_Fail                  
      END       
          
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = ''               
      SET @cOutField03 = ''                  
                         
      -- GOTO Next Screen                  
      SET @nScn  = @nScn + 1                
      SET @nStep = @nStep + 1                 
                        
      EXEC rdt.rdtSetFocusField @nMobile, 2                  
                
   END            
               
   IF @nInputKey = 0                   
   BEGIN                  
       -- EventLog - Sign In Function                  
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
   GOTO Quit                  
                  
   STEP_1_FAIL:                  
   BEGIN                  
      SET @cOutField01 = ''                    
   END                  
                
END                   
GOTO QUIT              
    
/********************************************************************************                  
Step 2. Scn = 5551.                   
   PTSZone         (field01)                  
   User ID         (field02, input)                     
                
********************************************************************************/                  
Step_2:                  
BEGIN            
   IF @nInputKey = 1 --ENTER                  
   BEGIN                  
                        
      SET @cUserID = ISNULL(RTRIM(@cInField02),'')                         
      IF @cUserID = ''                  
      BEGIN                  
         SET @nErrNo = 142303                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UserIDReq                
         EXEC rdt.rdtSetFocusField @nMobile, 2                  
         GOTO Step_2_Fail                  
      END               
                  
      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtUser WITH (NOLOCK)                 
                      WHERE UserName = @cUserID )                 
      BEGIN                  
         SET @nErrNo = 142304                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUserID                
         EXEC rdt.rdtSetFocusField @nMobile, 2                  
         GOTO Step_2_Fail                  
      END            
                      
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                
      SET @cOutField02 = @cUserID                         
                
      -- GOTO Next Screen                    
      SET @nScn = @nScn + 1                    
      SET @nStep = @nStep + 1                    
                            
   END            
               
   IF @nInputKey = 0                   
   BEGIN               
                          
      -- Go To Previous screen              
      SET @nScn  = @nScn-1                  
      SET @nStep = @nStep-1                  
      SET @cOutField01 = ''            
      SET @cOutField02 = ''             
      SET @cOutField03 = ''                   
              
   END                  
   GOTO Quit                  
                  
   STEP_2_FAIL:                  
   BEGIN                  
                
      -- Prepare Next Screen Variable                  
      SET @cOutField02 = ''             
      SET @cOutField03 = ''                 
                  
   END            
END                    
GOTO Quit            
    
/********************************************************************************                  
Step 3. Scn = 5522.                   
                   
   PTSZone              (field01)                  
   UserID               (field02)                      
   DropID               (field03, input)                  
                     
********************************************************************************/                  
Step_3:                  
BEGIN                  
   IF @nInputKey = 1                  
   BEGIN                  
      SET @cDropID = ISNULL(RTRIM(@cInField03),'')                  
                    
      IF @cDropID = ''                  
      BEGIN                  
         IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)                
                     WHERE StorerKey = @cStorerKey                
                     AND AddWho = @cUserID                
                     AND Status IN (  '0','1' )  )                 
         BEGIN                
            SET @nErrNo = 142305                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WorkLoadNotFound'                  
            EXEC rdt.rdtSetFocusField @nMobile, 3                  
            GOTO Step_3_Fail                  
         END                
                       
         SELECT @nTotalAssignDropID = Count(Distinct DropID )            
         FROM PTL.PTLTran WITH (NOLOCK)               
         WHERE AddWho = @cUserID              
            AND Status = '0'           
                    
         SELECT @cWaveKey = sourcekey           
         FROM PTL.PTLTran WITH (NOLOCK)               
         WHERE AddWho = @cUserID              
            AND Status = '0'        
        
         SET @cOutField01 = @cPTSZone                
         SET @cOutField02 = @cUserID                
         SET @cOutField03 = @nTotalAssignDropID                         
         SET @cOutField04 = ''                
                         
         -- GOTO Next Screen                  
         SET @nScn = @nScn + 1                  
         SET @nStep = @nStep + 1                  
                            
         EXEC rdt.rdtSetFocusField @nMobile, 4                  
                         
         GOTO QUIT                
                         
      END             
        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0    
      BEGIN    
         SET @nErrNo = 142314    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
         GOTO Step_3_Fail    
      END              
                        
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)                
                WHERE StorerKey = @cStorerKey                
                      AND Status = '5'                 
                      AND DropID = @cDropID )                 
      BEGIN                  
         SET @nErrNo = 142306                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_3_Fail                  
      END                 
                    
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)                
                  WHERE StorerKey = @cStorerKey                
                     AND Status = '0'                 
                     AND DropID = @cDropID )                 
      BEGIN                  
         SET @nErrNo = 142307                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_3_Fail                  
      END                 
                          
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)                 
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey                
                      INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.OrderKey = O.OrderKey            
                      WHERE PD.StorerKey = @cStorerKey                
                         AND PD.Status = '5'                
                         AND DropID = @cDropID )                 
      BEGIN                
         SET @nErrNo = 142308                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OTLNotSetup'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_3_Fail                    
      END                     
                    
      SELECT @cPTSLoc = OTL.Loc              
            ,@cWaveKey = PD.WaveKey        
            ,@cOrderkey= O.OrderKey              
      FROM dbo.PickDetail PD WITH (NOLOCK)               
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey              
      INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.OrderKey = O.OrderKey              
      WHERE PD.DropID = @cDropID              
         AND PD.StorerKey = @cStorerKey              
                      
      SELECT Top 1 @cPTLWaveKey = SourceKey              
      FROM PTL.PTLTran WITH (NOLOCK)               
      WHERE AddWho = @cUserID              
         AND Status = '0'         
        
      IF ISNULL(RTRIM(@cPTLWaveKey),'' )  <> ''               
      BEGIN              
         IF ISNULL(RTRIM(@cPTLWaveKey),'')  <> ISNULL(RTRIM(@cWaveKey),'')               
         BEGIN              
            SET @nErrNo = 142309              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffWaveKey'                  
            EXEC rdt.rdtSetFocusField @nMobile, 3                  
            GOTO Step_2_Fail                 
         END              
      END              
                    
      IF @nMaxDropID <> 0               
      BEGIN              
         SELECT @nAssignDropID = Count(Distinct DropID )               
         FROM PTL.PTLTran WITH (NOLOCK)               
         WHERE AddWho = @cUserID              
         AND Status = '0'              
                       
         IF (@nAssignDropID + 1) > @nMaxDropID               
         BEGIN              
            SET @nErrNo = 142310                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaxDropIDReached'                  
            EXEC rdt.rdtSetFocusField @nMobile, 3                  
            GOTO Step_3_Fail                 
         END              
      END              
                              
      EXEC [RDT].[rdt_PTL_DROPID_InsertPTLTran]                     
         @nMobile     =  @nMobile                              
         ,@nFunc       =  @nFunc                                
         ,@cFacility   =  @cFacility                            
         ,@cStorerKey  =  @cStorerKey                           
         ,@cPTSZone    =  @cPTSZone                    
         ,@cDropID     =  @cDropID                    
         ,@cUserName   =  @cUserID                
         ,@cLangCode   =  @cLangCode                 
         ,@cLightMode  =  @cLightMode                    
         ,@nErrNo      =  @nErrNo       OUTPUT                        
         ,@cErrMsg     =  @cErrMsg      OUTPUT                    
                             
      IF @nErrNo <> 0                     
      BEGIN                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')                     
         EXEC rdt.rdtSetFocusField @nMobile, 1                    
         GOTO Step_3_Fail                    
      END           
                    
      SELECT @nTotalAssignDropID = Count(Distinct DropID )               
      FROM PTL.PTLTran WITH (NOLOCK)               
      WHERE AddWho = @cUserID              
         AND Status = '0'            
                                                
      -- Prepare Next Screen Variable                  
      SET @cOutField01  = @cPTSZone                
      SET @cOutField02  = @cUserID                
      SET @cOutField03  = ''           
      SET @cOutField04  = ''          
      SET @cOutField05  =@cDropID             
                
   END  -- Inputkey = 1                  
                     
   IF @nInputKey = 0                   
   BEGIN                  
      -- Prepare Previous Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = ''                
      SET @cOutField03 = ''                        
                            
      -- GOTO Previous Screen                  
      SET @nScn = @nScn - 1                  
      SET @nStep = @nStep - 1                  
                 
   END                  
   GOTO Quit                  
                     
   Step_3_Fail:                  
   BEGIN                  
                        
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                
      SET @cOutField02 = @cUserID                
      SET @cOutField03  =''          
      SET @cOutField04  =''          
      SET @cOutField05 = ''    
      SET @cOutField06 = ''      
      SET @cOutField07 = ''         
      SET @cOutField08 = ''      
      SET @cOutField09 = ''                                
                        
   END                  
                  
END                   
GOTO QUIT            
     
             
/********************************************************************************                  
Step 4. Scn = 5553.                   
                   
   Confirm WorkLoad                 
   PTSzone      (field01)                
   USerID       (field02)                
   Total DropID (field03)                
   Option       (input, field04)                 
             
********************************************************************************/                  
Step_4:                  
BEGIN                  
   IF @nInputKey = 1                 
   BEGIN                  
      SET @cOption = ISNULL(RTRIM(@cInField04),'')                  
                      
      IF @cOption = ''                
      BEGIN                
         SET @nErrNo = 142311                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_4_Fail                  
      END                
                      
      IF @cOption NOT IN ( '1' , '5' , '9' )                 
      BEGIN                
         SET @nErrNo = 142312                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvOption'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_4_Fail                  
      END                
                      
      IF @cOption = '1'  OR @cOption = '5'              
      BEGIN                
                         
         IF @cExtendedUpdateSP <> ''                
         BEGIN                
                                
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')                
            BEGIN                
                                   
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                
                  ' @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDevID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cSuggTote OUTPUT,@cSuggSKU OUTPUT,@cSuggSKUDesc1 OUTPUT,@cSuggSKUDesc2 OUTPUT,@cSuggSKUDesc3 OUTPUT,
                  @cSuggQty OUTPUT,@cEndRemark OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT '                
               SET @cSQLParam =                
                  '@nMobile          INT, ' +                
                  '@nFunc            INT, ' +                
                  '@cLangCode        NVARCHAR( 3),  ' +                
                  '@cUserID          NVARCHAR( 18), ' +                
                  '@cFacility        NVARCHAR( 5),  ' +                
                  '@cStorerKey       NVARCHAR( 15), ' +                
                  '@cWaveKey         NVARCHAR( 20), ' +                
                  '@nStep            INT,           ' +            
                  '@cDevID           NVARCHAR( 20), ' +                
                  '@cPTSZone         NVARCHAR( 10), ' +                
                  '@cOption          NVARCHAR( 1),  ' +                
                  '@cSuggLoc         NVARCHAR( 10) OUTPUT, ' +                
                  '@cSuggTote        NVARCHAR (10) OUTPUT, ' +    
                  '@cSuggSKU         NVARCHAR(20)  OUTPUT, ' +    
                  '@cSuggSKUDesc1    NVARCHAR(20)  OUTPUT, ' +    
                  '@cSuggSKUDesc2    NVARCHAR(20)  OUTPUT, ' +    
                  '@cSuggSKUDesc3    NVARCHAR(20)  OUTPUT, ' +      
                  '@cSuggQty         NVARCHAR(20)  OUTPUT, ' +    
                  '@cEndRemark       NVARCHAR(10)   OUTPUT, ' +    
                  '@nErrNo           INT           OUTPUT, ' +                 
                  '@cErrMsg          NVARCHAR( 20) OUTPUT'                
                                      
                         
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                
                  @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDeviceID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cSuggTote OUTPUT,@cSuggSKU OUTPUT,@cSuggSKUDesc1 OUTPUT,@cSuggSKUDesc2 OUTPUT,@cSuggSKUDesc3 OUTPUT,
                  @cSuggQty OUTPUT,@cEndRemark OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                 
                         
               IF @nErrNo <> 0                 
                  GOTO Step_4_Fail                
                                      
            END                
         END    

         -- Prepare Next Screen Variable                  
         SET @cOutField01 = @cPTSZone                 
         SET @cOutField02 = @cUserID    
         SET @cOutField03 = @cSuggLoc                     
         SET @cOutField04 = @cSuggTote      
         SET @cOutField05 = ''                   
     
         -- GOTO Screen 1                  
         SET @nScn = @nScn + 1                
         SET @nStep = @nStep + 1                             
      END                
      ELSE IF @cOption = '9'                
      BEGIN                
            
         -- Prepare Next Screen Variable                  
         SET @cOutField01 = @cPTSZone                
         SET @cOutField02 = @cUserID                
         SET @cOutField03 = ''                     
         SET @cOutField04 = ''      
         SET @cOutField05 = ''                 
                             
         -- GOTO Screen 1                  
         SET @nScn  = @nScn - 1                
         SET @nStep = @nStep - 1                
                         
      END                
                      
   END  -- Inputkey = 1                 
                   
   IF @nInputKey = 0                   
   BEGIN                        
      -- Prepare Next Screen Variable                  
      SET @cOutField01  = @cPTSZone                
      SET @cOutField02  = @cUserID                    
      SET @cOutField03  =''          
      SET @cOutField04  =''          
      SET @cOutField05 = @cDropID             
                            
      -- GOTO Previous Screen                  
      SET @nScn = @nScn - 1                  
      SET @nStep = @nStep - 1                  
                         
      EXEC rdt.rdtSetFocusField @nMobile, 4                  
   END           
   GOTO Quit                  
                     
   Step_4_Fail:                  
   BEGIN                             
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                
      SET @cOutField02 = @cUserID                
      SET @cOutField03 = @nTotalAssignDropID                 
      SET @cOutField04 = ''                                    
   END                 
END                   
GOTO QUIT    
/********************************************************************************                  
Step 5. Scn = 5554.                   
PTS-DropID
PTS Zone:  (field01)
User ID:
(field02)

Please Proceed to
Loc: (field03)
ToteID: (field04)
ToteID: (field05)                   
********************************************************************************/                  
Step_5:                  
BEGIN    
   IF @nInputKey = 1                 
   BEGIN    
          
      SET @cToteID=@cInField05    
    
      IF NOT EXISTS ( SELECT 1 from ptl.ptltran with (nolock)     
                     where addwho=@cUserID    
                     AND status=1    
                     and caseid=@cToteID)    
      BEGIN    
         SET @nErrNo = 142313                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvtoteID'                  
         EXEC rdt.rdtSetFocusField @nMobile, 3                  
         GOTO Step_5_Fail       
      END    
    
      SET     @cOldSuggLoc =@cSuggLoc    
      SET     @cOldSuggTote=@cSuggTote       
    
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = @cUserID    
      SET @cOutField03 = @cSuggLoc                     
      SET @cOutField04 = @cSuggTote      
      SET @cOutField05 = @cSuggSKU    
      SET @cOutField06 = isnull(@cSuggSKUDesc1,'')    
      SET @cOutField07 = isnull(@cSuggSKUDesc2,'')    
      SET @cOutField08 = isnull(@cSuggSKUDesc3,'')    
      SET @cOutField09 = @cSuggQty       
          
      -- GOTO Next Screen                  
      SET @nScn = @nScn + 1                  
      SET @nStep = @nStep + 1       
   END    
        
       
   IF @nInputKey = 0                 
   BEGIN    
          
      SET @cOutField01 = @cPTSZone                
      SET @cOutField02 = @cUserID                
      SET @cOutField03 = @nTotalAssignDropID                 
      SET @cOutField04 = ''        
    
      -- GOTO Previous Screen                  
      SET @nScn = @nScn - 1                  
      SET @nStep = @nStep - 1       
   END    
   GOTO Quit     
       
   Step_5_Fail:                  
   BEGIN                  
                        
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = @cUserID    
      SET @cOutField03 = @cSuggLoc                     
      SET @cOutField04 = @cSuggTote      
      SET @cOutField05 = ''                                
   END     
   GOTO Quit      
END     
    
/********************************************************************************                  
Step 6. Scn = 5555.
PTS Zone : (Field01)
User ID:
(field02)
Please Proceed to
Loc : (field03)
ToteId: (fiedl04)
SKU:
(field05)
(field06)
(field07)
(field08)
Qty: (field09)                      
********************************************************************************/                  
Step_6:                  
BEGIN    
   IF @nInputKey = 1                 
   BEGIN    
    
      IF @cExtendedUpdateSP <> ''                
      BEGIN                             
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')                
         BEGIN                
                                   
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                
               ' @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDevID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cSuggTote OUTPUT,@cSuggSKU OUTPUT,@cSuggSKUDesc1 OUTPUT,@cSuggSKUDesc2 OUTPUT,@cSuggSKUDesc3 OUTPUT,@cSuggQty OUTPUT,
               @cEndRemark OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '                
            SET @cSQLParam =                
               '@nMobile          INT, ' +                
               '@nFunc            INT, ' +                
               '@cLangCode        NVARCHAR( 3),  ' +                
               '@cUserID          NVARCHAR( 18), ' +                
               '@cFacility        NVARCHAR( 5),  ' +               
               '@cStorerKey       NVARCHAR( 15), ' +                
               '@cWaveKey         NVARCHAR( 20), ' +                
               '@nStep            INT,           ' +            
               '@cDevID           NVARCHAR( 20), ' +                
               '@cPTSZone         NVARCHAR( 10), ' +                
               '@cOption          NVARCHAR( 1),  ' +                
               '@cSuggLoc         NVARCHAR( 10) OUTPUT, ' +                
               '@cSuggTote        NVARCHAR (10) OUTPUT, ' +    
               '@cSuggSKU         NVARCHAR(20)  OUTPUT, ' +    
               '@cSuggSKUDesc1    NVARCHAR(20)  OUTPUT, ' +    
               '@cSuggSKUDesc2    NVARCHAR(20)  OUTPUT, ' +    
               '@cSuggSKUDesc3    NVARCHAR(20)  OUTPUT, ' +    
               '@cSuggQty         NVARCHAR(20)  OUTPUT, ' +    
               '@cEndRemark       NVARCHAR(10)   OUTPUT, ' +    
               '@nErrNo           INT           OUTPUT, ' +                 
               '@cErrMsg          NVARCHAR( 20) OUTPUT'                
                                      
                         
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                
               @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDeviceID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cSuggTote OUTPUT,@cSuggSKU OUTPUT,@cSuggSKUDesc1 OUTPUT,@cSuggSKUDesc2 OUTPUT,@cSuggSKUDesc3 OUTPUT,@cSuggQty OUTPUT,
               @cEndRemark OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                 
                         
            IF @nErrNo <> 0                 
               GOTO Step_6_Fail                
                                      
         END                
                         
      END    
    
      IF ISNULL(@cEndRemark,'') <> ''    
      BEGIN    
         SET @cOutField01 = @cOldSuggLoc                     
         SET @cOutField02 = @cOldSuggTote     
             
         IF (@cEndRemark = 'END')    
            SET @cOutField03 = 'Order Finished'    
         ELSE IF (@cEndRemark = 'WAVEEND')    
            SET @cOutField03 = 'Wave Finished'    
              
         -- GOTO Previous Screen                  
         SET @nScn = @nScn + 1                  
         SET @nStep = @nStep + 1       
      END    
      ELSE IF EXISTS(  SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)    
      WHERE AddWho=@cUserID AND STATUS IN (0,1)    
         AND sourcekey=@cWaveKey)    
      BEGIN     
         -- Prepare Next Screen Variable                  
         SET @cOutField01 = @cPTSZone                 
         SET @cOutField02 = @cUserID    
         SET @cOutField03 = @cSuggLoc                     
         SET @cOutField04 = @cSuggTote      
         SET @cOutField05 = ''         
         SET @cOutField06 = ''      
         SET @cOutField07 = ''         
         SET @cOutField08 = ''      
         SET @cOutField09 = ''     
                
         -- GOTO Previous Screen                  
         SET @nScn = @nScn - 1                  
         SET @nStep = @nStep - 1     
      END    
      ELSE    
      BEGIN    
         -- Prepare Next Screen Variable                  
         SET @cOutField01  = @cPTSZone                
         SET @cOutField02  = @cUserID                    
         SET @cOutField03  =''          
         SET @cOutField04  =''          
         SET @cOutField05 = ''    
         SET @cOutField06 = ''      
         SET @cOutField07 = ''         
         SET @cOutField08 = ''      
         SET @cOutField09 = ''          
                        
         SET @nScn = @nScn - 3                  
         SET @nStep = @nStep - 3     
      END    
   END      
       
   IF @nInputKey = 0                 
   BEGIN               
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = @cUserID    
      SET @cOutField03 = @cSuggLoc                     
      SET @cOutField04 = @cSuggTote      
      SET @cOutField05 = ''    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''      
      SET @cOutField09 = ''       
          
      -- GOTO Previous Screen                  
      SET @nScn = @nScn - 1                  
      SET @nStep = @nStep - 1            
             
   END    
   GOTO Quit    
       
   Step_6_Fail:                  
   BEGIN                                 
      -- Prepare Next Screen Variable                  
      SET @cOutField01 = @cPTSZone                 
      SET @cOutField02 = @cUserID    
      SET @cOutField03 = @cSuggLoc                     
      SET @cOutField04 = @cSuggTote      
      SET @cOutField05 = @cSuggSKU    
      SET @cOutField06 = isnull(@cSuggSKUDesc1,'')    
      SET @cOutField07 = isnull(@cSuggSKUDesc2,'')    
      SET @cOutField08 = isnull(@cSuggSKUDesc3,'')    
      SET @cOutField09 = @cSuggQty                       
                        
   END           
END     
    
/********************************************************************************                  
Step 7. Scn = 5556.                   
Loc: (field01)
ToteID: (Field02)
(field03)                  
             
********************************************************************************/                  
Step_7:                  
BEGIN    
   IF @nInputKey in(0,1)                 
   BEGIN    
    
      IF EXISTS(  SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)    
      WHERE AddWho=@cUserID AND STATUS IN (0,1)    
         AND sourcekey=@cWaveKey)    
      BEGIN     
         -- Prepare Next Screen Variable                  
         SET @cOutField01 = @cPTSZone                 
         SET @cOutField02 = @cUserID    
         SET @cOutField03 = @cSuggLoc                     
         SET @cOutField04 = @cSuggTote      
         SET @cOutField05 = ''         
         SET @cOutField06 = ''      
         SET @cOutField07 = ''         
         SET @cOutField08 = ''      
         SET @cOutField09 = ''     
                
         -- GOTO Previous Screen                  
         SET @nScn = @nScn - 2                  
         SET @nStep = @nStep - 2     
      END    
      ELSE    
      BEGIN    
         -- Prepare Next Screen Variable                  
         SET @cOutField01  = @cPTSZone                
         SET @cOutField02  = @cUserID                    
         SET @cOutField03  =''          
         SET @cOutField04  =''          
         SET @cOutField05 = ''    
         SET @cOutField06 = ''      
         SET @cOutField07 = ''         
         SET @cOutField08 = ''      
         SET @cOutField09 = ''                    
         SET @nScn = @nScn - 4                  
         SET @nStep = @nStep - 4     
      END    
   END     
   GOTO Quit    
        
END     

/********************************************************************************                  
Quit. Update back to I/O table, ready to be pick up by JBOSS                  
********************************************************************************/                  
Quit:                  
                  
BEGIN                  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET                   
      EditDate       = GETDATE(),               
      ErrMsg         = @cErrMsg,                   
      Func           = @nFunc,                  
      Step           = @nStep,                  
      Scn            = @nScn,                  
                  
      StorerKey      = @cStorerKey,                  
      Facility       = @cFacility,                   
      Printer        = @cPrinter,                         
      InputKey       = @nInputKey,               
      LightMode      = @cLightMode,              
                        
      V_UOM          = @cPUOM,              
            
      V_String1      = @cPTSZone,                
      V_String2      = @cUserID,                
      V_String3      = @cDropID,                
      V_String4      = @cExtendedUpdateSP,                 
      V_String5      = @cSuggTote,                
      V_String6      = @cDeviceID,        
      V_String7      = @cWaveKey,    
      V_String8      = @cSuggSKU,    
      V_String9      = @cSuggSKUDesc1,    
      V_String10     = @cSuggSKUDesc2,    
      V_String11     = @cSuggSKUDesc3,    
      V_String12     = @cSuggQty,    
      V_String13     = @cSuggLoc,    
      V_String14     = @cOldSuggLoc,    
      V_String15     = @cOldSuggTote,    
      V_String16     = @cEndRemark,    
    
      V_Integer1     = @nTotalAssignDropID,              
      V_Integer2     = @nMaxDropID,              
                        
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