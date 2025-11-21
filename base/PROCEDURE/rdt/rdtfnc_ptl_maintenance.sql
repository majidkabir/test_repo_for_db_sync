SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/   
/* Copyright: IDS                                                             */   
/* Purpose:                                                                   */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2013-07-18 1.0  ChewKP     Created                                         */  
/* 2014-11-05 1.1  ChewKP     Add Extended Update SP (ChewKP01)               */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-11-08 1.3  TungGH     Performance                                     */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_PTL_Maintenance] (    
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
       
   @nError        INT,    
   @b_success     INT,    
   @n_err         INT,         
   @c_errmsg      NVARCHAR( 250),     
   @cPUOM         NVARCHAR( 10),        
   @bSuccess      INT,    
       
   @cDeviceID         NVARCHAR(10),    
   @cPTLMTCode        NVARCHAR(10),    
   @cLightModule      NVARCHAR(10),    
   @cJobName          NVARCHAR(100),     
   @cDeviceType       NVARCHAR(10),    
   @cDeviceProfileKey NVARCHAR(10),     
   @c_DeviceID        NVARCHAR(10),    
   @cSQL              NVARCHAR(1000),       
   @cSQLParam         NVARCHAR(1000),       
   @cExtendedUpdateSP NVARCHAR(30),      
          
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
       
   @cPUOM       = V_UOM,    
     
   @cDeviceID    = V_String1,    
   @cLightModule = V_String2,    
   @cDeviceType  = V_String3,   
   @cExtendedUpdateSP = V_String4,      
       
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
    
IF @nFunc = 814  -- PTL Maintenance    
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0   -- PTL Maintenance    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3600. Cart ID    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3601. Cart ID, Type of Maintenance    
END    
    
--IF @nStep = 3    
--BEGIN    
-- SET @cErrMsg = 'STEP 3'    
-- GOTO QUIT    
--END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. func = 812. Menu    
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
       
   SET @cDeviceID         = ''    
   SET @cLightModule      = ''    
   SET @cDeviceType       = ''    
       
   -- Set the entry point    
   SET @nScn = 3600    
   SET @nStep = 1    
       
   EXEC rdt.rdtSetFocusField @nMobile, 1    
       
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Scn = 3600.     
   CART ID/PTS ZONE (Input , Field01)    
       
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cDeviceID = ISNULL(RTRIM(@cInField01),'')    
      SET @cLightModule = ISNULL(RTRIM(@cInField02),'')    
          
      -- Validate blank    
      IF ISNULL(RTRIM(@cDeviceID), '') = ''    
      BEGIN    
         SET @nErrNo = 81801    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DeviceID req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                     WHERE DeviceID = @cDeviceID     
                       AND DeviceType = 'CART')    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)       
                         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
                         WHERE Loc.PutawayZone = @cDeviceID      
                           AND DP.DeviceType = 'LOC' )       
         BEGIN    
            SET @nErrNo = 81802    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid DeviceID     
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_1_Fail    
         END    
         ELSE    
         BEGIN    
            SET @cDeviceType = 'PTSZone'    
    
            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)       
                        INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
                        WHERE Loc.PutawayZone = @cDeviceID      
                          AND DP.DeviceType = 'LOC'    
                          AND ISNULL(IPAddress,'')  = '')    
            BEGIN    
               SET @nErrNo = 81803    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidIPAddress    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_1_Fail    
            END    
    
            IF @cLightModule <> ''    
            BEGIN    
               IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)       
                               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
                               WHERE Loc.PutawayZone = @cDeviceID      
                                 AND DP.DeviceType = 'LOC'    
                                 AND DeviceID = @cLightModule)    
               BEGIN    
                  SET @nErrNo = 81804    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLightAdd    
                  EXEC rdt.rdtSetFocusField @nMobile, 1    
                  GOTO Step_1_Fail    
               END    
            END    
         END    
      END    
      ELSE    
      BEGIN      
         SET @cDeviceType = 'CartID'    
    
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                     WHERE DeviceID = @cDeviceID     
                       AND DeviceType = 'CART'     
                       AND ISNULL(IPAddress,'')  = '')    
         BEGIN    
            SET @nErrNo = 81805    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidIPAddress    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_1_Fail    
         END    
    
         IF @cLightModule <> ''    
         BEGIN    
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                            WHERE DeviceID = @cDeviceID     
                              AND DeviceType = 'CART'     
                              AND DevicePosition = @cLightModule)    
            BEGIN    
               SET @nErrNo = 81806    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLightAdd    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_1_Fail    
            END    
         END    
      END      
          
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cDeviceID    
      SET @cOutField02 = ''    
           
      -- GOTO Next Screen    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
           
      EXEC rdt.rdtSetFocusField @nMobile, 2    
   END  -- Inputkey = 1    
    
    
   IF @nInputKey = 0     
   BEGIN    
      -- EventLog - Sign In Function    
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
    
      SET @cOutField01  = ''    
      SET @cOutField02  = ''    
    
      SET @cDeviceID    = ''    
      SET @cLightModule = ''    
      SET @cDeviceType  = ''    
   END    
   GOTO Quit    
    
   STEP_1_FAIL:    
   BEGIN    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
   END    
    
END     
GOTO QUIT    
    
/********************************************************************************    
Step 2. Scn = 3601.     
   CART ID/PTS ZONE    (field01)    
   Type Of Maintenance (field02, input)    
       
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cPTLMTCode = ISNULL(RTRIM(@cInField02),'')    
          
      IF ISNULL(@cPTLMTCode, '') = ''     
      BEGIN    
         SET @nErrNo = 81807    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'    
         GOTO Step_2_Fail    
      END    
          
    
    
      IF @cExtendedUpdateSP <> ''      
      BEGIN      
                
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')      
          BEGIN      
                   
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cDeviceID, @cLightModule, @cPTLMTCode, @nErrNo OUTPUT, @cErrMsg OUTPUT '      
             SET @cSQLParam =      
                '@nMobile          INT, ' +      
                '@nFunc            INT, ' +      
                '@cLangCode        NVARCHAR( 3),  ' +      
                '@cUserName        NVARCHAR( 18), ' +      
                '@cFacility        NVARCHAR( 5),  ' +      
                '@cStorerKey       NVARCHAR( 15), ' +      
                '@nStep            INT,           ' +      
                '@cDeviceID        NVARCHAR( 10), ' +      
                '@cLightModule     NVARCHAR( 10), ' +      
                '@cPTLMTCode       NVARCHAR( 10), ' +      
                '@nErrNo           INT           OUTPUT, ' +       
                '@cErrMsg          NVARCHAR( 20) OUTPUT'      
                      
          
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cDeviceID, @cLightModule, @cPTLMTCode, @nErrNo OUTPUT, @cErrMsg OUTPUT     
          
             IF @nErrNo <> 0       
                GOTO Step_2_Fail      
                      
          END      
      END       
      ELSE    
      BEGIN    
         IF @cPTLMTCode = 'M001' -- Refresh BONDPC    
         BEGIN    
               SELECT @cJobName = ISNULL(Long,'')      
               FROM CodeLkup WITH (NOLOCK)      
               WHERE ListName = 'PTL_MT'      
               AND Code = 'M001'    
                   
               EXEC MASTER.dbo.isp_StartSQLJob @c_ServerName=@@SERVERNAME, @c_JobName=@cJobName      
                   
   --         EXEC [dbo].[isp_DPC_RefreshBondDPC]    
   --            @cStorerKey     
   --           ,@cDeviceID    
   --           ,@b_Success   OUTPUT      
   --           ,@nErrNo      OUTPUT    
   --           ,@cErrMsg     OUTPUT    
   --             
   --         IF @nErrNo = 0     
   --         BEGIN    
   --            SET @nErrNo = 81807    
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
   --         END    
   --         ELSE    
   --         BEGIN    
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
   --         END               
                
END    
         ELSE IF @cPTLMTCode = 'M002' -- Create JunctionBox    
         BEGIN    
            EXEC [dbo].[isp_DPC_CreateJunctionBox]    
               @cStorerKey     
              ,@cDeviceID    
              ,@b_Success   OUTPUT      
              ,@nErrNo      OUTPUT    
              ,@cErrMsg     OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81808    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END               
                  
         END    
         ELSE IF @cPTLMTCode = 'M003' -- Destroy JunctionBox    
         BEGIN    
            EXEC [dbo].[isp_DPC_DestroyJunctionBox]    
               @cStorerKey     
              ,@cDeviceID    
              ,@b_Success   OUTPUT      
              ,@nErrNo      OUTPUT    
              ,@cErrMsg     OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81809    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END               
                
         END    
         ELSE IF @cPTLMTCode = 'M004' -- Terminate All Light    
         BEGIN    
                
             -- Initialize LightModules    
            EXEC [dbo].[isp_DPC_TerminateAllLight]     
                  @cStorerKey    
                 ,@cDeviceID      
                 ,@b_Success    OUTPUT      
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81810    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END    
                
         END    
         ELSE IF @cPTLMTCode = 'M005' -- LightUp Module    
         BEGIN    
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                            WHERE DeviceID = @cDeviceID    
                            AND DevicePosition = @cLightModule )     
            BEGIN    
               SET @nErrNo = 81811    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LightAddNotFound    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_1_Fail    
            END     
                
            IF @cLightModule = ''    
            BEGIN    
               SET @nErrNo = 81812    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightModuleReq'    
               GOTO STEP_2_FAIL    
            END    
                
             -- Initialize LightModules    
            EXEC [dbo].[isp_DPC_LightUpLocMaintenance]     
                  @cStorerKey    
                 ,@cDeviceID      
                 ,@cLightModule    
                 ,''    
                 ,@b_Success    OUTPUT      
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81813    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END    
                
         END    
         ELSE IF @cPTLMTCode = 'M006' -- Set Module Address    
         BEGIN    
                
            IF @cLightModule = ''    
            BEGIN    
            SET @nErrNo = 81814    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightModuleReq'    
               GOTO STEP_2_FAIL    
            END    
                
             -- Initialize LightModules    
            EXEC [dbo].[isp_DPC_LightUpLocMaintenance]     
                  @cStorerKey    
                 ,@cDeviceID      
                 ,@cLightModule    
                 ,''    
                 ,@b_Success    OUTPUT      
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81815    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END    
                
         END    
         ELSE IF @cPTLMTCode = 'M007' -- LightUp Module with Beep and Blinking    
         BEGIN    
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                            WHERE DeviceID = @cDeviceID    
                            AND DevicePosition = @cLightModule )     
            BEGIN    
               SET @nErrNo = 81816    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LightAddNotFound    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_1_Fail    
            END     
                
            IF @cLightModule = ''    
            BEGIN    
               SET @nErrNo = 81817    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightModuleReq'    
               GOTO STEP_2_FAIL    
            END    
                
             -- Initialize LightModules    
            EXEC [dbo].[isp_DPC_LightUpLocMaintenance]     
                  @cStorerKey    
                 ,@cDeviceID      
                 ,@cLightModule    
                 ,'12'    
                 ,@b_Success    OUTPUT      
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
                
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81818    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            END           
         END    
         ELSE IF @cPTLMTCode = 'M008' -- Reset DeviceProfile, DeviceProfileLog, PTTran & DropID Table related to Cart/PTSZone    
         BEGIN    
            IF @cDeviceType = 'CartID'     
            BEGIN    
               -- Update DropID Status to 9    
               IF EXISTS(SELECT 1     
                         FROM dbo.DropID D WITH (NOLOCK)    
                         JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID    
                         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey    
                         WHERE DP.DeviceType = 'Cart'    
                           AND DP.DeviceID = @cDeviceID    
                           AND D.DropIDType = 'Cart'    
                           AND DPL.Status <> '9'    
                           AND D.Status <> '9' )    
               BEGIN    
                  UPDATE D    
                  SET Status = '9'    
                  FROM dbo.DropID D WITH (NOLOCK)    
                  JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID    
                  JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey    
                  WHERE DP.DeviceType = 'Cart'    
                    AND DP.DeviceID = @cDeviceID    
                    AND D.DropIDType = 'Cart'    
                    AND DPL.Status <> '9'    
                    AND D.Status <> '9'    
       
                 IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81819     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIDFail     
                     GOTO STEP_2_FAIL      
                  END      
               END      
       
               -- Update PTLTran Table Status to 9    
               IF EXISTS(SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) WHERE DeviceID = @cDeviceID AND Status <> '9')    
               BEGIN    
                  UPDATE dbo.PTLTran WITH (ROWLOCK)    
                  SET   Status = '9'     
                  WHERE DeviceID = @cDeviceID      
                    AND Status <> '9'    
                     
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81820    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPTLTranFail      
                     GOTO STEP_2_FAIL      
                  END      
               END    
       
               IF EXISTS(SELECT 1 FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)     
                         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey    
                         WHERE DP.DeviceType = 'Cart'    
                    AND DP.DeviceID = @cDeviceID    
                           AND DPL.Status <> '9')    
               BEGIN    
                  -- Update DeviceProfileLog Table Status to 9    
                  UPDATE DPL     
                  SET Status = '9'    
                  FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)    
                  JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey    
                  WHERE DP.DeviceType = 'Cart'    
                    AND DP.DeviceID = @cDeviceID    
                    AND DPL.Status <> '9'    
       
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81821    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileLogFail      
                     GOTO STEP_2_FAIL      
                  END      
               END    
       
               -- Update DeviceProfile Table Status to 9         
               UPDATE dbo.DeviceProfile WITH (ROWLOCK)    
               SET   Status = '9'       
                   , DeviceProfileLogKey = ''      
               WHERE DeviceType = 'Cart'    
                 AND DeviceID = @cDeviceID      
                     
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 81822    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail      
                  GOTO STEP_2_FAIL      
               END      
            END    
            ELSE    
            BEGIN    
               -- Update DropID Status to 9    
               IF EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)     
                         JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID       
                         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey     
                         JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
                         WHERE DP.DeviceType = 'LOC'      
                           AND Loc.PutawayZone = @cDeviceID     
                           AND DPL.Status <> '9'    
                           AND D.Status < '9')    
               BEGIN    
                  UPDATE D     
                  SET Status = '9', ArchiveCop = '1'    
                  FROM dbo.DropID D WITH (NOLOCK)     
                  JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID       
                  JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey     
                  JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
                  WHERE DP.DeviceType = 'LOC'      
                  AND Loc.PutawayZone = @cDeviceID     
                    AND DPL.Status <> '9'    
                    AND D.Status < '9'    
       
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81823     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIDFail     
                     GOTO STEP_2_FAIL      
                  END      
               END      
       
               DECLARE CursorPTLStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
               SELECT DISTINCT DP.DeviceProfileKey, DeviceID      
               FROM dbo.DeviceProfile DP WITH (NOLOCK)      
               INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey       
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID      
               WHERE Loc.PutawayZone = @cDeviceID      
               AND DP.DeviceType = 'LOC'              
                      
               OPEN CursorPTLStatus                      
               FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey, @c_DeviceID    
                     
               WHILE @@FETCH_STATUS <> -1                  
               BEGIN         
                  IF EXISTS(SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) WHERE DeviceID = @c_DeviceID AND Status <> '9')    
                  BEGIN    
                     -- Update PTLTran Table Status to 9    
                     UPDATE dbo.PTLTran WITH (ROWLOCK)    
                     SET   Status = '9'     
                     WHERE DeviceID = @c_DeviceID      
                       AND Status <> '9'    
                        
                     IF @@ERROR <> 0       
                     BEGIN      
                        SET @nErrNo = 81824     
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPTLTranFail      
                        GOTO STEP_2_FAIL      
                     END      
                  END    
       
                  IF EXISTS(SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK) WHERE DeviceProfileKey = @cDeviceProfileKey AND Status <> '9')    
                  BEGIN    
                     -- Update DeviceProfileLog Table Status to 9    
                     UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)     
                     SET   Status = '9'      
                     WHERE DeviceProfileKey = @cDeviceProfileKey      
                       AND Status <> '9'    
       
                     IF @@ERROR <> 0       
                     BEGIN      
                        SET @nErrNo = 81825     
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileLogFail      
                        GOTO STEP_2_FAIL      
                     END      
                  END    
       
                  -- Update DeviceProfile Table Status to 9         
                  UPDATE dbo.DeviceProfile WITH (ROWLOCK)    
                  SET   Status = '9'       
                      , DeviceProfileLogKey = ''      
                  WHERE DeviceProfileKey = @cDeviceProfileKey       
                        
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81826    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail      
                     GOTO STEP_2_FAIL      
                  END                      
       
                  FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey, @c_DeviceID                    
               END      
               CLOSE CursorPTLStatus                  
               DEALLOCATE CursorPTLStatus         
       
               -- Delete all PTSZone record in rdt.rdtAssignLoc    
               IF EXISTS(SELECT 1 FROM rdt.rdtAssignLoc WITH (NOLOCK) WHERE PTSZone = @cDeviceID)    
               BEGIN    
                  DELETE FROM rdt.rdtAssignLoc    
                  WHERE PTSZone = @cDeviceID    
       
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 81827    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelRdtAssignLocFail      
                     GOTO STEP_2_FAIL      
                  END       
               END    
       
            END  -- IF @cDeviceType <> 'CartID'     
       
            IF @nErrNo = 0     
            BEGIN    
               SET @nErrNo = 81828    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Reset Complete'        
            END    
         END          
      END    
   END  -- Inputkey = 1    
    
   IF @nInputKey = 0     
   BEGIN           
      -- Prepare Previous Screen Variable    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
    
      SET @cDeviceID    = ''    
      SET @cLightModule = ''    
      SET @cDeviceType  = ''    
             
      -- GOTO Previous Screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
           
      EXEC rdt.rdtSetFocusField @nMobile, 1     
   END    
   GOTO Quit    
    
   STEP_2_FAIL:    
   BEGIN    
      SET @cOutField01 = @cDeviceID    
      SET @cOutField02 = ''    
   END    
    
END     
GOTO QUIT    
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
      Printer   = @cPrinter,     
      -- UserName  = @cUserName,    
      InputKey  = @nInputKey,    
    
      V_UOM = @cPUOM,    
          
      V_String1 = @cDeviceID,    
      V_STring2 = @cLightModule,    
      V_String3 = @cDeviceType,    
      V_String4 = @cExtendedUpdateSP,    
          
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