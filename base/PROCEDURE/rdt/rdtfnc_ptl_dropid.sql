SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
          
/******************************************************************************/                 
/* Copyright: LF                                                              */                 
/* Purpose: THGSG ECom                                                        */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-06-17 1.0  YeeKung    WMS-9312 Created                                */                
/******************************************************************************/                
                
CREATE PROC [RDT].[rdtfnc_PTL_DROPID] (                
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
   @cLightModeColor     NVARCHAR(5),              
   @cLightMode          NVARCHAR(10),              
   @cPTSLoc             NVARCHAR(10),            
   @cWaveKey            NVARCHAR(10),            
   @cPTLWaveKey         NVARCHAR(10),            
   @nMaxDropID          INT,            
   @nAssignDropID       INT,      
   @cOrderkey           NVARCHAR(20),            
                   
                      
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
   @cLightModeColor     = V_String5,          
   @cDeviceID           = V_String6,      
   @cWaveKey            = V_String7,               
                  
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
          
IF @nFunc = 1834  -- PTL Carton                
BEGIN                
                   
   -- Redirect to respective screen                
   IF @nStep = 0 GOTO Step_0   -- PTL Carton                 
   IF @nStep = 1 GOTO Step_1   -- Scn = 5520. User ID              
   IF @nStep = 2 GOTO Step_2   -- Scn = 5521. DropID              
   IF @nStep = 3 GOTO Step_3   -- Scn = 5522. Options                
   IF @nStep = 4 GOTO Step_4   -- Scn = 5523. Message           
   IF @nStep = 5 GOTO Step_5   -- Scn = 5523. Message               
                   
END                
                  
RETURN -- Do nothing if incorrect step                
                
/********************************************************************************                
Step 0. func = 1834. Menu                
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
   --SET @cLightMode = ''              
   SET @cLightModeColor = ''              
                 
                
   -- Set the entry point                
   SET @nScn = 5520                
   SET @nStep = 1                
                   
   EXEC rdt.rdtSetFocusField @nMobile, 1                
                   
END          
GOTO Quit               
          
/********************************************************************************                
Step 1. Scn = 5520.                   
   PTSZONE         (field02, input)          
********************************************************************************/           
Step_1:                
BEGIN                
   IF @nInputKey = 1 --ENTER                
   BEGIN            
      SET @cPTSZone = ISNULL(RTRIM(@cInField01),'')                
                      
      IF @cPTSZone = ''                
      BEGIN                
         SET @nErrNo = 140451                 
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
         SET @nErrNo = 140452                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPTSZone                
         EXEC rdt.rdtSetFocusField @nMobile, 2                
         GOTO Step_1_Fail                
      END     
          
      SELECT  @cDeviceID = CODE    
      FROM  CODELKUP WITH (NOLOCK)    
      WHERE LISTNAME='tcpclient'     
      and SHORT='tv'      
      AND UDF03= @cPTSZone    
                
      -- Prepare Next Screen Variable                
      SET @cOutField01 = @cPTSZone               
      SET @cOutField02 = ''             
      SET @cOutField03 = @cDeviceID                
      SET @cOutField04 = ''                
                       
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
Step 2. Scn = 5521.                 
   PTSZone         (field01)                
   User ID         (field02, input)          
   Device ID       (field03, input)                
              
********************************************************************************/                
Step_2:                
BEGIN          
   IF @nInputKey = 1 --ENTER                
   BEGIN                
                      
      SET @cUserID = ISNULL(RTRIM(@cInField02),'')           
      SET @cDeviceID = ISNULL(RTRIM(@cInField03),'')               
      IF @cUserID = ''                
      BEGIN                
         SET @nErrNo = 140453                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UserIDReq              
         EXEC rdt.rdtSetFocusField @nMobile, 2                
         GOTO Step_2_Fail                
      END             
                
      IF @cDeviceID = ''          
      BEGIN          
         SET @nErrNo = 140454                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DeviceIDReq              
         EXEC rdt.rdtSetFocusField @nMobile, 2                
         GOTO Step_2_Fail          
      END             
                    
      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtUser WITH (NOLOCK)               
                      WHERE UserName = @cUserID )               
      BEGIN                
         SET @nErrNo = 140455              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUserID              
         EXEC rdt.rdtSetFocusField @nMobile, 2                
         GOTO Step_2_Fail                
      END          
          
      IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)               
                     WHERE DeviceID=@cDeviceID AND DeviceType='TV' )               
      BEGIN                         SET @nErrNo = 140456              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvDeviceID              
         EXEC rdt.rdtSetFocusField @nMobile, 2                
         GOTO Step_2_Fail                
      END        
      
      if  ((SELECT COUNT(*) FROM dbo.PTLTrafficDetail WITH (NOLOCK)      
               WHERE MonitorID=@cDeviceID and status=1)=2)        
      BEGIN    
         IF NOT EXISTS(SELECT 1 FROM dbo.PTLTrafficDetail WITH (NOLOCK)    
                   WHERE  MonitorID=@cDeviceID and USERID=@cUserID)    
         BEGIN    
            
            SET @nErrNo = 140466              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvDeviceID              
            EXEC rdt.rdtSetFocusField @nMobile, 2                
            GOTO Step_2_Fail      
         END     
      END      
                
      SELECT @cLightMode = DefaultLightColor             
      FROM rdt.rdtUser WITH (NOLOCK)            
      WHERE UserName = @cUserID            
                  
                  
      IF ISNULL(RTRIM(@cLightMode),'')  = ''            
      BEGIN            
         SET @nErrNo = 140457              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LightModeNotSetup              
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_2_Fail                
      END          
          
      -- Prepare Next Screen Variable                
      SET @cOutField01 = @cPTSZone              
      SET @cOutField02 = @cUserID              
      SET @cOutField03 = @cDeviceID              
              
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
   DeviceID             (field03)              
   DropID               (field04, input)                
                   
********************************************************************************/                
Step_3:                
BEGIN                
   IF @nInputKey = 1                
   BEGIN                
      SET @cDropID = ISNULL(RTRIM(@cInField04),'')                
                  
      IF @cDropID = ''                
      BEGIN                
         IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)              
                     WHERE StorerKey = @cStorerKey              
                     AND AddWho = @cUserID              
                     AND Status IN (  '0','1' )  )               
         BEGIN              
            SET @nErrNo = 140458                
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
         SET @nErrNo = 140467    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
         GOTO Step_3_Fail    
      END                   
                      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)              
                WHERE StorerKey = @cStorerKey              
                      AND Status = '5'               
                      AND DropID = @cDropID )               
      BEGIN                
         SET @nErrNo = 140459                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'                
         EXEC rdt.rdtSetFocusField @nMobile, 3                
         GOTO Step_3_Fail                
      END               
                  
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)              
                  WHERE StorerKey = @cStorerKey              
                     AND Status = '0'               
                     AND DropID = @cDropID )               
      BEGIN                
         SET @nErrNo = 140460                
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
         SET @nErrNo = 140461                
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
               SET @nErrNo = 140462            
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
            SET @nErrNo = 140463                
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
      SET @cOutField03  = @cDeviceID         
      SET @cOutField04  =''        
      SET @cOutField05  =''        
      SET @cOutField06 = @cDropID        
              
   END  -- Inputkey = 1                
                   
   IF @nInputKey = 0                 
   BEGIN                
       -- Prepare Previous Screen Variable                
       SET @cOutField01 = @cPTSZone               
       SET @cOutField02 = ''              
      SET @cOutField03 = ''                
       SET @cOutField04 = ''                
       SET @cOutField05 = ''              
                          
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
      SET @cOutField03 = @cDeviceID              
      SET @cOutField04 = ''                
                      
   END                
                
END                 
GOTO QUIT          
          
/********************************************************************************                
Step 4. Scn = 5523.                 
                 
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
         SET @nErrNo = 140464                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OptionReq'                
         EXEC rdt.rdtSetFocusField @nMobile, 3                
         GOTO Step_4_Fail                
      END              
                    
      IF @cOption NOT IN ( '1' , '5' , '9' )               
      BEGIN              
        SET @nErrNo = 140465                
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
                      ' @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDevID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cLightModeColor OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '              
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
                      '@cLightModeColor  NVARCHAR( 10) OUTPUT, ' +              
                      '@nErrNo           INT           OUTPUT, ' +               
                      '@cErrMsg          NVARCHAR( 20) OUTPUT'              
                                    
                       
                   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,              
                      @nMobile, @nFunc, @cLangCode, @cUserID, @cFacility, @cStorerKey, @cWaveKey, @nStep,@cDeviceID, @cPTSZone, @cOption, @cSuggLoc OUTPUT, @cLightModeColor OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT               
                       
                   IF @nErrNo <> 0               
                      GOTO Step_4_Fail              
                                    
                END              
            END               
--         SELECT TOP 1 @cSuggLoc = Loc              
--         FROM dbo.PTLTran WITH (NOLOCK)               
--         WHERE StorerKey = @cStorerKey              
--         AND Status = '0'              
--         AND AddWho = @cUserID              
                       
         -- Prepare Next Screen Variable                
         SET @cOutField01 = @cPTSZone               
         SET @cOutField02 = @cUserID              
         SET @cOutField03 = @cLightModeColor              
         SET @cOutField04 = @cSuggLoc              
                     
                                 
         -- GOTO Screen 1                
         SET @nScn = @nScn + 1              
         SET @nStep = @nStep + 1              
                         
                       
      END              
      ELSE IF @cOption = '9'              
      BEGIN              
          
         -- Prepare Next Screen Variable                
         SET @cOutField01 = @cPTSZone              
         SET @cOutField02 = @cUserID              
         SET @cOutField03 = @cDeviceID              
                           
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
      SET @cOutField03  = @cDeviceID         
      SET @cOutField04  =''        
      SET @cOutField05  =''        
      SET @cOutField06 = @cDropID           
                          
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
Step 5. Scn = 5524.                 
              
   PTSZone / CartID(field01)                
   UserId          (field02)                
   Suggested Loc   (field03)                 
                   
********************************************************************************/                
Step_5:                
BEGIN                
   IF @nInputKey = 0 --ENTER / ESC              
   BEGIN                
                  
      --SET @cOutField01 = ''               
      --SET @cOutField02 = ''              
      --SET @cOutField03 = ''                
      --SET @cOutField04 = ''          
      --SET @cOutField05 = ''                
                    
      -- GOTO Previous Screen                
      SET @nScn = @nScn - 1                
      SET @nStep = @nStep - 1              
                      
      EXEC rdt.rdtSetFocusField @nMobile, 1                
                      
   END  -- Inputkey = 1                
                
   GOTO Quit                
                   
END                 
GOTO QUIT                                     
          
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
      V_String5      = @cLightModeColor,              
      V_String6      = @cDeviceID,      
      V_String7      = @cWaveKey,      
                  
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