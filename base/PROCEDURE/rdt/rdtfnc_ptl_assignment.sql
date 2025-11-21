SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/         
/* Copyright: IDS                                                             */         
/* Purpose: IDSUK Put To Light Order Assignment SOS#269031                    */         
/*                                                                            */         
/* Modifications log:                                                         */         
/*                                                                            */         
/* Date       Rev  Author     Purposes                                        */         
/* 2013-11-12 1.0  ChewKP     Created                                         */        
/* 2014-04-28 1.1  Chee       Bug Fix - Change @nRecordCount = 0 to > 0       */        
/*                            Add validation to make sure user confirm        */        
/*                            assignment for CartPicking                      */        
/*                            Make sure only assigned deviceprofile.status    */        
/*                            updated to '1' (Chee01)                         */        
/*2014-05-01  1.2  ChewKP     Bug Fix (ChewKP01)                              */        
/*2014-05-02  1.3  Chee       Bug Fix - if user esc without assignment, will  */        
/*                            hit PTSZoneAssigned error                       */        
/*                            Bug Fix - avoid duplicate deviceProfileLog issue*/        
/*                            Bug Fix - Concurrent user doing assignment,     */        
/*                            cannot confirm assignment until all done        */        
/*                            Bug Fix - Remove OldTote in DropID Table when   */        
/*                            overwrite (Chee02)                              */        
/*2014-05-04  1.4  ChewKP     Add to validate Tote Length (ChewKP01)          */       
/*2014-05-07  1.5  Chee       Add new screen to allow user option to reset    */      
/*                            PTSZone/CartID (Chee03)                         */       
/*2014-06-01  1.6  ChewKP     Fix Cursor Position (ChewKP02)                  */      
/*2014-06-02  1.7  ChewKP     Add Extended SP to Insert AssigLocation(ChewKP03)*/      
/*2015-01-26  1.8  ChewKP     Bug Fixes (ChewKP04)                            */     
/*2015-08-12  1.9  ChewKP     SOS#347631 Resume when disconnected (ChewKP05)  */     
/*2016-09-30  2.0  Ung        Performance tuning                              */   
/*2019-07-06  2.1  YeeKung    Add configure for THGSG                         */  
/*2021-03-01  2.2  YeeKung    Solve Ambigious column issue (yeekung02)        */   
/******************************************************************************/        
        
CREATE PROC [RDT].[rdtfnc_PTL_Assignment] (        
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
           
   @cCartID           NVARCHAR(10),        
   @cLightLoc         NVARCHAR(10),        
   @cToteID           NVARCHAR(20),        
   @cLightLocKey      NVARCHAR(10),        
   @cPTSZone          NVARCHAR(10),        
   @cAssignmentType   NVARCHAR(10),        
   @cDeviceProfileKey NVARCHAR(10),        
   @cModuleAddr       NVARCHAR(5),        
   @nTotalToteCount   INT,        
   @cOptions          NVARCHAR(1),     
   @cAssignDropID     NVARCHAR(20),        
   @cDropID           NVARCHAR(20),        
   @cDropIDSuffix     NVARCHAR(3),        
   @cSuggestedLoc     NVARCHAR(10),        
   @nStepAssignLoc    INT,        
   @nScnAssignLoc     INT,        
   @nStepWaveKey      INT,        
   @nScnWaveKey       INT,        
   @cWaveKey          NVARCHAR(10),        
   @nRecordCount      INT,        
   @cOldToteID        NVARCHAR(20), -- (Chee02)        
   @cRegExpression    NVARCHAR(60), -- (ChewKP01)        
   @cOption           NVARCHAR( 1), -- (Chee03)       
   @cDeviceID         NVARCHAR(10), -- (Chee03)      
   @nStepResetDevice  INT,          -- (Chee03)       
   @nScnResetDevice   INT,          -- (Chee03)       
   @cExtendedWaveSP   NVARCHAR(30), -- (ChewKP03)      
   @cSQL              NVARCHAR(1000), -- (ChewKP03)      
   @cSQLParam         NVARCHAR(1000), -- (ChewKP03)  
   @cConfigOrderToLOcDetail       NVARCHAR(1),      
           
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
        
           
   @cCartID     = V_String1,        
   @cLightLoc   = V_String2,        
   @cToteID     = V_String3,        
   @cPTSZone    = V_String4,         
   @cAssignmentType = V_String5,        
   @nTotalToteCount = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,          
   @cAssignDropID   = V_String7,        
   @cSuggestedLoc   = V_String8,        
   @cWaveKey        = V_string9,        
   @cExtendedWaveSP = V_String10, -- (ChewKP03)   
   @cConfigOrderToLOcDetail     = V_String11,     
           
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
        
IF @nFunc = 815  -- PTL Assignment        
BEGIN        
   SET @nStepAssignLoc    = 2            
   SET @nScnAssignLoc     = 3721               
           
   SET @nStepWaveKey      = 6        
   SET @nScnWaveKey       = 3725        
       
   -- (Chee03)      
   SET @nStepResetDevice  = 7      
   SET @nScnResetDevice   = 3726      
           
   -- Redirect to respective screen        
   IF @nStep = 0 GOTO Step_0   -- PTL Assignment        
   IF @nStep = 1 GOTO Step_1   -- Scn = 3720. Cart ID / PTS Zone        
   IF @nStep = 2 GOTO Step_2   -- Scn = 3721. Light Location and Tote ID        
   IF @nStep = 3 GOTO Step_3   -- Scn = 3722. Confirm Assignment        
   IF @nStep = 4 GOTO Step_4   -- Scn = 3723. Message        
   IF @nStep = 5 GOTO Step_5   -- Scn = 3724. Overwrite existing Tote ?        
   IF @nStep = 6 GOTO Step_6   -- Scn = 3725. WaveKey        
   IF @nStep = 7 GOTO Step_7   -- Scn = 3726. Reset Device?  (Chee03)        
           
END        
        
--IF @nStep = 3        
--BEGIN        
-- SET @cErrMsg = 'STEP 3'        
-- GOTO QUIT        
--END        
        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step 0. func = 815. Menu        
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
   EXEC RDT.rdt_STD_EventLog        
   -- EventLog - Sign In Function        
     @cActionType = '1', -- Sign in function        
     @cUserID     = @cUserName,        
     @nMobileNo   = @nMobile,        
     @nFunctionID = @nFunc,        
     @cFacility   = @cFacility,        
     @cStorerKey  = @cStorerkey        
           
           
   -- (ChewKP01)      
   SET @cExtendedWaveSP = ''      
   SET @cExtendedWaveSP = rdt.RDTGetConfig( @nFunc, 'ExtendedWaveSP', @cStorerKey)      
   IF @cExtendedWaveSP = '0'        
   BEGIN      
      SET @cExtendedWaveSP = ''      
   END  
     
   SET @cConfigOrderToLOcDetail = rdt.RDTGetConfig( @nFunc, 'ConfigOrderToLocDetail', @cStorerKey)              
           
   -- Init screen        
   SET @cOutField01 = ''         
   SET @cOutField02 = ''        
           
   SET @cCartID    = ''          
   SET @cPTSZone   = ''          
   SET @cLightLoc   = ''        
   SET @cToteID     = ''        
   SET @cAssignmentType = ''        
   SET @nTotalToteCount = 0        
   SET @cAssignDropID   = ''        
   SET @cSuggestedLoc   = ''        
   SET @cWaveKey        = ''        
        
   -- Set the entry point        
   SET @nScn = 3720        
   SET @nStep = 1        
           
   EXEC rdt.rdtSetFocusField @nMobile, 1        
           
END        
GOTO Quit        
        
        
/********************************************************************************        
Step 1. Scn = 3720.         
   CartID  (Input , Field01)        
   PTSZone (Input , Field02)        
********************************************************************************/        
Step_1:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
      SET @cCartID  = ISNULL(RTRIM(@cInField01),'')        
      SET @cPTSZone = ISNULL(RTRIM(@cInField02),'')        
              
      IF @cCartID = '' AND @cPTSZone = ''        
      BEGIN        
         SET @nErrNo = 83701        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either 1 field Req        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_1_Fail        
      END        
       
      -- Validate blank        
      IF ISNULL(RTRIM(@cCartID), '') <> ''        
      BEGIN        
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND DeviceType = 'CART' )         
            BEGIN        
               SET @nErrNo = 83702        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartID        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Step_1_Fail        
            END        
        
-- Move this to Step 7 (Chee03)      
/*      
            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status = ('3') )         
            BEGIN        
               SET @nErrNo = 83703        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartInUse        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Step_1_Fail        
            END        
                    
--            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status = '1' )         
--            BEGIN        
--               SET @nErrNo = 83721        
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartAssigned        
--               EXEC rdt.rdtSetFocusField @nMobile, 1        
--               GOTO Step_1_Fail        
--            END        
                    
            -- Update DeviceProfile Table Cart Status = '0' When all detail in LightLocLog.Status = '9'        
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK)        
                            INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey        
                            WHERE LL.DeviceID = @cCartID         
                            AND LD.Status IN('0','1','3'))        
            BEGIN                
               UPDATE dbo.DeviceProfile        
               SET   Status = '0'         
                   , DeviceProfileLogKey = ''        
               WHERE DeviceID = @cCartID        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 83704        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLightLocFail        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_1_Fail        
               END        
            END        
*/        
            SET @cAssignmentType = 'CartID'        
            SET @cPTSZone = ''        
      END        
              
      IF @cPTSZone <> ''        
      BEGIN        
         IF NOT EXISTS ( SELECT 1        
                         FROM dbo.DeviceProfile DP WITH (NOLOCK)         
                         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                         WHERE Loc.PutawayZone = @cPTSZone        
                         AND DP.DeviceType = 'LOC' )         
         BEGIN        
            SET @nErrNo = 83705        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPTSZone        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO Step_1_Fail        
         END        
        
-- Move this to Step 7 (Chee03)      
/*                    
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                     INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                     INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                     WHERE Loc.PutawayZone = @cPTSZone        
                     AND DP.DeviceType = 'LOC'                                    
                   AND DPL.Status = '3' )         
         BEGIN        
            SET @nErrNo = 83729        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTSZoneInUse        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO Step_1_Fail        
         END        
      
--            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
--                        INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
--                        INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
--                        WHERE Loc.PutawayZone = @cPTSZone        
--                        AND DP.DeviceType = 'LOC'                                    
--                        AND DPL.Status = '1' )         
--            BEGIN        
--               SET @nErrNo = 83722        
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTSZoneAssigned        
--               EXEC rdt.rdtSetFocusField @nMobile, 2        
--               GOTO Step_1_Fail        
--            END        
                 
         -- Update DeviceProfile Table Cart Status = '0' When all detail in LightLocLog.Status = '9'        
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                         INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                         WHERE Loc.PutawayZone = @cPTSZone        
                         AND DP.DeviceType = 'LOC'                                    
                         AND DPL.Status IN('0','1','3'))        
         BEGIN                
               DECLARE CursorPTLStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
               
               SELECT DISTINCT DP.DeviceProfileKey         
               FROM dbo.DeviceProfile DP WITH (NOLOCK)        
               INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
               WHERE Loc.PutawayZone = @cPTSZone        
               AND DP.DeviceType = 'LOC'                
                        
               OPEN CursorPTLStatus                    
                 
               FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey        
                       
               WHILE @@FETCH_STATUS <> -1                    
               BEGIN           
                          
                  UPDATE dbo.DeviceProfile        
                  SET   Status = '0'         
                      , DeviceProfileLogKey = ''        
                  WHERE DeviceProfileKey = @cDeviceProfileKey        
                     
                  IF @@ERROR <> 0         
                  BEGIN   
                     SET @nErrNo = 83706        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLightLocFail        
                     EXEC rdt.rdtSetFocusField @nMobile, 2        
                     GOTO Step_1_Fail        
                  END        
                          
                  FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey        
                        
               END        
               CLOSE CursorPTLStatus                    
               DEALLOCATE CursorPTLStatus           
         END        
*/                    
         SET @cAssignmentType = 'PTSZone'        
         SET @cCartID = ''        
      END        
              
-- Move this to Step 7 (Chee03)      
/*              
      IF @cPTSZone = ''        
      BEGIN        
         -- Prepare Next Screen Variable        
         SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
         SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
         SET @cOutField03 = ''        
         SET @cOutField04 = ''        
                  
         -- GOTO Next Screen        
         SET @nScn = @nScn + 1        
         SET @nStep = @nStep + 1        
                 
         EXEC rdt.rdtSetFocusField @nMobile, 3        
      END        
      ELSE        
      BEGIN        
         -- Prepare Next Screen Variable        
         SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
         SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
         SET @cOutField03 = ''        
         SET @cOutField04 = ''        
                  
         -- GOTO Next Screen        
         SET @nScn = @nScnWaveKey        
         SET @nStep = @nStepWaveKey        
                 
         EXEC rdt.rdtSetFocusField @nMobile, 3        
      END        
*/      
      
      -- GOTO Reset Device Screen        
      SET @nScn = @nScnResetDevice        
      SET @nStep = @nStepResetDevice        
      
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
      SET @cOutField02 = ''        
      --EXEC rdt.rdtSetFocusField @nMobile, 1        
   END        
           
        
END         
GOTO QUIT        
        
/********************************************************************************        
Step 2. Scn = 3721.         
   Title           (field01)        
   PTSZone / CartID(field02)        
   Light Loc       (field03, input)        
   Tote ID         (field04, input)        
           
********************************************************************************/        
Step_2:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
              
      SET @cLightLoc = ISNULL(RTRIM(@cInField03),'')        
      SET @cToteID = ISNULL(RTRIM(@cInField04),'')        
              
      SET @nTotalToteCount = 0         
        
      IF @cLightLoc = '' AND @cToteID = ''        
      BEGIN        
         IF @cAssignmentType = 'CartID'        
         BEGIN                   
            SELECT @nTotalToteCount = COUNT( DISTINCT LD.DeviceProfileKey)        
            FROM dbo.DeviceProfileLog LD WITH (NOLOCK)        
            INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = LD.DeviceProfileKey        
WHERE DP.DeviceID = @cCartID        
            AND DP.DeviceType = 'Cart'           
            AND LD.Status IN ( '0','1')         
                    
         END        
         ELSE IF @cAssignmentType = 'PTSZone'        
         BEGIN        
                    
            SELECT @nTotalToteCount = COUNT( DISTINCT DPL.DeviceProfileKey)        
            FROM dbo.DeviceProfile DP WITH (NOLOCK)        
            INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
            WHERE Loc.PutawayZone = @cPTSZone        
            AND DP.DeviceType = 'LOC'            
            AND DPL.Status IN ( '0','1')         
         END        
            
         IF @nTotalTotecount = 0         
         BEGIN        
            SET @nErrNo = 83718        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoAssignmentDone'        
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_2_Fail        
         END        
        
         -- Prepare Next Screen Variable        
         SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
         SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
         SET @cOutField03 = @nTotalToteCount        
         SET @cOutField04 = ''        
                  
         -- GOTO Next Screen        
         SET @nScn = @nScn + 1        
         SET @nStep = @nStep + 1        
                 
         EXEC rdt.rdtSetFocusField @nMobile, 4        
                 
         GOTO QUIT        
      END        
              
--      IF @cLightLoc = ''        
--      BEGIN        
--         SET @nErrNo = 83707        
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightLoc Req'        
--         SET @cLightLoc = ''        
--         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position        
--         GOTO Step_2_Fail        
--      END        
              
      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)            
                       WHERE Listname = 'XValidTote'            
                       AND Code = SUBSTRING(RTRIM(@cToteID), 1, 1))            
      BEGIN            
           SET @nErrNo = 83725            
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvToteNo            
           EXEC rdt.rdtSetFocusField @nMobile, 3          
           GOTO Step_2_Fail            
      END           
              
      SET @cRegExpression = ''        
      SELECT TOP 1 @cRegExpression = UDF01         
      FROM dbo.Codelkup WITH (NOLOCK)         
      WHERE ListName = 'XValidTote'        
              
      IF ISNULL(RTRIM(@cRegExpression),'')  <> ''        
      BEGIN        
         IF master.dbo.RegExIsMatch(@cRegExpression, RTRIM( @cToteID), 1) <> 1   -- (ChewKP01)          
         BEGIN        
            SET @nErrNo = 87802            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteID            
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)        
            GOTO Step_2_Fail          
         END         
      END        
                    
      IF @cAssignmentType = 'CartID'        
      BEGIN        
         SET @cModuleAddr = @cLightLoc          
                   
         SELECT TOP 1 @cDeviceProfileKey = DeviceProfileKey          
         FROM dbo.DeviceProfile WITH (NOLOCK)          
         WHERE DeviceID     = @cCartID          
         AND DevicePosition = @cModuleAddr           
         ORDER BY Priority DESC      
                                        
      END        
      ELSE IF @cAssignmentType = 'PTSZone'        
      BEGIN        
         --SET @cModuleAddr = RIGHT(@cLightLoc,4)        
                 
         IF @cLightLoc <> @cSuggestedLoc         
         BEGIN        
            SET @nErrNo = 83743        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LocNotSame'        
            SET @cLightLoc = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position        
            GOTO Step_2_Fail        
         END        
                 
         SELECT TOP 1 @cDeviceProfileKey = DeviceProfileKey          
                , @cModuleAddr = DevicePosition        
         FROM dbo.DeviceProfile WITH (NOLOCK)          
         WHERE DeviceID = @cLightLoc        
         Order By Priority DESC      
                 
        
         IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)        
                        WHERE Loc = @cLightLoc        
                        AND PutawayZone = ISNULL(RTRIM(@cPTSZone),''))        
         BEGIN        
            SET @nErrNo = 83709        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightLocDiffZone'        
            SET @cLightLoc = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position        
            GOTO Step_2_Fail        
         END                 
                                
      END        
        
      IF ISNULL(@cDevicePRofileKey,'') = ''        
      BEGIN        
         SET @nErrNo = 83719        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidPosition'        
         SET @cLightLoc = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position        
         GOTO Step_2_Fail        
      END        
              
              
--      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)        
--                     WHERE DeviceProfileKey = @cDeviceProfileKey         
--                     AND Status = '1' )         
--      BEGIN        
--            SET @nErrNo = 83708        
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightLocAssigned'        
--            SET @cLightLoc = ''        
--            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position        
--            GOTO Step_2_Fail        
--      END        
              
      IF @cToteID = ''        
      BEGIN        
         SET @nErrNo = 83710        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteID Req'        
         SET @cToteID = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID        
         GOTO Step_2_Fail        
      END              
              
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)        
                  WHERE DropID = @cToteID         
                  AND Status IN ( '0','1','3') )        
      BEGIN        
         SET @nErrNo = 83726        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteAssigned'        
         SET @cToteID = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID        
         GOTO Step_2_Fail        
      END        
              
      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)         
                  WHERE DropID = @cToteID        
                  AND Status IN ('0', '3', '5'))        
      BEGIN        
         SET @nErrNo = 83736        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidToteID'        
         SET @cToteID = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID        
         GOTO Step_2_Fail        
      END        
        
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)        
                  WHERE DeviceProfileKey = @cDeviceProfileKey        
                  AND   DropID <> @cToteID        
                  AND   Status IN ( '0','1','3') )         
      BEGIN                 
         SET @cAssignDropID = ''        
         SELECT @cAssignDropID = DropID         
         FROM dbo.DeviceProfileLog WITH (NOLOCK)         
         WHERE DeviceProfileKey = @cDeviceProfileKey        
         AND Status IN ( '0'  ,'1' )       
               
          -- Prepare Next Screen Variable                 SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
         SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
         SET @cOutField03 = @cModuleAddr        
         SET @cOutField04 = @cAssignDropID        
         SET @cOutField05 = ''        
         SET @cOutField06 = @cToteID        
        
         -- GOTO OverWrite Screen        
         SET @nScn = @nScn + 3        
         SET @nStep = @nStep + 3         
                 
         EXEC rdt.rdtSetFocusField @nMobile, 5        
         GOTO QUIT        
      END                    
        
      -- Insert into LightLoc_Detail Table        
      -- (Chee02)        
--      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)        
--                     WHERE DeviceProfileKey = @cDeviceProfileKey        
--                     AND DropID = @cToteID         
--                     AND Status = '0' )          
--      BEGIN        
        
      IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)        
                 WHERE DeviceProfileKey = @cDeviceProfileKey)        
      BEGIN        
         DELETE FROM dbo.DeviceProfileLog        
         WHERE DeviceProfileKey = @cDeviceProfileKey         
         
         IF @@ERROR <> 0         
         BEGIN        
            SET @nErrNo = 83750        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelDProfileLogFail'        
            EXEC rdt.rdtSetFocusField @nMobile, 3        
            GOTO Step_2_Fail        
         END        
      END        
        
     INSERT INTO dbo.DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey)        
     VALUES ( @cDeviceProfileKey, '', @cToteID, '0', '')        
             
     IF @@ERROR <> 0         
     BEGIN        
        SET @nErrNo = 83711        
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDProfileLogFail'        
        EXEC rdt.rdtSetFocusField @nMobile, 3        
        GOTO Step_2_Fail        
     END        
--      END        
        
      IF @cAssignmentType = 'CartID'        
      BEGIN        
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)        
                     WHERE DropID = @cToteID         
                     AND Status <> '9'        
                     AND DropIDType = 'CART' )        
         BEGIN        
               SET @nErrNo = 83730        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidToteID'        
               EXEC rdt.rdtSetFocusField @nMobile, 3        
               GOTO Step_2_Fail        
         END        
      END        
      ELSE IF @cAssignmentType = 'PTSZone'        
      BEGIN        
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)        
                     WHERE DropID = @cToteID         
                     AND Status <> '9'        
                     AND DropIDType = 'PTS' )        
         BEGIN        
               SET @nErrNo = 83731        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidToteID'        
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)        
               GOTO Step_2_Fail        
         END        
      END        
              
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)        
                     WHERE DropID = @cToteID         
                     AND   Status = '9' )         
      BEGIN        
                 
         -- Update Old DropID Record with Suffix before Insert New One --        
         EXECUTE dbo.nspg_GetKey          
                  'DropIDSuffix',          
                  3 ,          
                  @cDropIDSuffix     OUTPUT,          
                  @b_success         OUTPUT,          
                  @nErrNo            OUTPUT,          
                  @cErrMsg           OUTPUT          
                 
         IF @b_success<>1          
         BEGIN          
             SET @nErrNo = 83733        
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetKeyFail'        
             EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)        
             GOTO Step_2_Fail          
         END          
                 
        
        
         UPDATE dbo.DropIDDetail        
            SET DropID = RTRIM(@cToteID) + RTRIM(@cDropIDSuffix)        
         WHERE DropID = @cToteID         
                 
         IF @@ERROR <> 0         
         BEGIN        
             SET @nErrNo = 83734        
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDDetFail'        
             EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)        
             GOTO Step_2_Fail          
         END        
                 
         UPDATE dbo.DropID        
            SET DropID = RTRIM(@cToteID) + RTRIM(@cDropIDSuffix)        
         WHERE DropID = @cToteID         
         AND Status = '9'        
                 
         IF @@ERROR <> 0         
         BEGIN        
             SET @nErrNo = 83735        
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'        
             EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)      
             GOTO Step_2_Fail          
         END        
                 
                                    
         INSERT INTO dbo.DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey )          
         VALUES (@cToteID , '' , CASE WHEN @cAssignmentType = 'CarTID' THEN 'CART' ELSE 'PTS' END, '0' , '')          
          
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 83723          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'         
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)      
            GOTO Step_2_Fail          
         END          
      END           
              
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)        
                     WHERE DropID = @cToteID )         
      BEGIN        
                 
         INSERT INTO dbo.DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey )          
         VALUES (@cToteID , '' , CASE WHEN @cAssignmentType = 'CarTID' THEN 'CART' ELSE 'PTS' END, '0' , '')          
          
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 83732         
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'         
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- (ChewKP02)      
            GOTO Step_2_Fail          
         END          
      END                              
                             
              
      EXEC RDT.rdt_STD_EventLog        
        @cActionType = '3',         
        @cUserID     = @cUserName,        
        @nMobileNo   = @nMobile,        
        @nFunctionID = @nFunc,        
        @cFacility   = @cFacility,        
        @cStorerKey  = @cStorerkey,        
        @cRefNo1     = @cCartID,        
        @cRefNo2     = @cPTSZone,        
        @cRefNo3     = @cLightLoc,        
        @cRefNo4     = @cToteID        
            
      SET @nTotalToteCount = 0         
              
      IF @cAssignmentType = 'CartID'        
      BEGIN        
         SELECT @nTotalToteCount = COUNT( DISTINCT LD.DeviceProfileKey)        
         FROM dbo.DeviceProfileLog LD WITH (NOLOCK)        
         INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = LD.DeviceProfileKey        
         WHERE DP.DeviceID = @cCartID        
         AND DP.DeviceType = 'Cart'           
         AND LD.Status = '0'        
                 
      END        
      ELSE IF @cAssignmentType = 'PTSZone'        
      BEGIN        
         SELECT @nTotalToteCount = COUNT( DISTINCT DPL.DeviceProfileKey)        
         FROM dbo.DeviceProfile DP WITH (NOLOCK)        
         INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
         WHERE Loc.PutawayZone = @cPTSZone        
         AND DP.DeviceType = 'LOC'            
         AND DPL.Status = '0'        
      END        
              
      -- Prepare Next Screen Variable        
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
              
      IF @cAssignmentType = 'PTSZone'        
      BEGIN        
         UPDATE rdt.rdtAssignLoc        
         SET Status = '9'        
         WHERE PTSLoc = @cLightLoc        
         AND WaveKEy = @cWaveKey        
                 
         IF @@ERROR <> 0         
         BEGIN        
               SET @nErrNo = 83745        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdAssignLocFail'        
               EXEC rdt.rdtSetFocusField @nMobile, 4        
               GOTO Step_2_Fail        
         END        
                 
         IF (@cConfigOrderToLOcDetail = 1)  
         BEGIN 
               SELECT Top 1 @cSuggestedLoc = PTSLoc        
               FROM rdt.rdtAssignLoc AL WITH (NOLOCK) JOIN DBO.LOC LC WITH (NOLOCK)
               ON AL.PTSLoc=LC.Loc        
               WHERE WaveKey = @cWaveKey        
               AND PTSZone = @cPTSZone        
               AND AL.Status  = '0'        --yeekung02
               ORDER BY  LC.LogicalLocation    
         END
         ELSE
         BEGIN      
        
            SELECT Top 1 @cSuggestedLoc = PTSLoc        
            FROM rdt.rdtAssignLoc WITH (NOLOCK)         
            WHERE WaveKey = @cWaveKey        
            AND PTSZone = @cPTSZone        
            AND Status  = '0'        --yeekung02
            ORDER BY PTSPosition 
         END        
                 
                 
         IF @@ROWCOUNT = 0         
         BEGIN        
              -- Go to Confirm Screen        
             SET @cOutField01 = RTRIM(@cAssignmentType) + ':'          
             SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END          
             SET @cOutField03 = @nTotalToteCount          
             SET @cOutField04 = ''          
                                  
                      
             -- GOTO Next Screen          
             SET @nScn = @nScn + 1          
             SET @nStep = @nStep + 1          
                       
             EXEC rdt.rdtSetFocusField @nMobile, 4          
         END        
                 
  SET @cOutField05 = @cSuggestedLoc         
                 
      END        
      ELSE        
      BEGIN        
         SET @cOutField05 = ''        
      END        
              
      EXEC rdt.rdtSetFocusField @nMobile, 3        
              
   END  -- Inputkey = 1        
        
   IF @nInputKey = 0         
   BEGIN        
      IF @cAssignmentType = 'CartID'        
      BEGIN        
         -- (Chee01)        
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                     INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                     AND DP.DeviceType = 'Cart'            
                     AND DPL.Status = '0' )         
         BEGIN        
            SET @nErrNo = 83749        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AssignNotConfirm'        
            EXEC rdt.rdtSetFocusField @nMobile, 4        
            GOTO Step_2_Fail        
         END        
      END        
      ELSE IF @cAssignmentType = 'PTSZone'        
      BEGIN        
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                     INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                     INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                     WHERE Loc.PutawayZone = @cPTSZone        
                     AND DP.DeviceType = 'LOC'            
                     AND DPL.Status = '0' )         
         BEGIN        
            SET @nErrNo = 83747        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AssignNotConfirm'        
            EXEC rdt.rdtSetFocusField @nMobile, 4        
            GOTO Step_2_Fail     
         END        
      END        
                       
      SET @cOutField01 = ''        
      SET @cOutField02 = ''          
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
        
      -- GOTO Previous Screen        
      SET @nScn = @nScn - 1        
      SET @nStep = @nStep - 1        
                  
      EXEC rdt.rdtSetFocusField @nMobile, 1         
   END        
   GOTO Quit        
        
   STEP_2_FAIL:        
   BEGIN        
              
      -- Prepare Next Screen Variable        
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = @cLightLoc        
      SET @cOutField04 = '' --@cAssignDropID (CheWKP01)        
      SET @cOutField05 = @cSuggestedLoc        
        
   END        
END         
GOTO QUIT        
        
        
/********************************************************************************        
Step 3. Scn = 3722.         
           
   Title                (field01)        
   PTSZone / CartID     (field02)        
   TTL TOTE ASSIGNED:   (field03)        
   CONFIRM ASSIGNMENT?        
   1 = YES | 9 = NO        
   OPTIONS:             (field04, input)        
           
           
********************************************************************************/        
Step_3:        
BEGIN        
   IF @nInputKey = 1        
   BEGIN        
      SET @cOptions = ISNULL(RTRIM(@cInField04),'')        
              
      IF @cOptions = ''        
      BEGIN        
         SET @nErrNo = 83712        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'        
         EXEC rdt.rdtSetFocusField @nMobile, 4        
         GOTO Step_3_Fail        
      END        
              
      IF @cOptions NOT IN ('1','9')        
      BEGIN        
         SET @nErrNo = 83713        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'        
         EXEC rdt.rdtSetFocusField @nMobile, 4        
         GOTO Step_3_Fail        
      END        
              
      IF @cOptions = '1'        
      BEGIN        
            SET @cDeviceProfileKey = ''        
                    
            IF @cAssignmentType = 'CartID'        
            BEGIN        
                  DECLARE CursorPTLConfirm CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
                  
                  SELECT DISTINCT DP.DeviceProfileKey         
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)         
                  WHERE DP.DeviceID = @cCartID        
                  AND DP.DeviceType = 'Cart'           
                  AND DP.Status IN ('0','1')         
                  ORDER BY DP.DeviceProfileKey      
                       
            END        
            ELSE IF @cAssignmentType = 'PTSZone'        
            BEGIN        
                  IF EXISTS ( SELECT 1 FROM rdt.rdtAssignLoc WITH (NOLOCK)         
                              WHERE WaveKey = @cWaveKey        
                              AND PTSZone = @cPTSZone -- (Chee02)        
                              AND Status = '0' )         
                  BEGIN        
                     SET @nErrNo = 83748        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AssignNotComplete'        
                     EXEC rdt.rdtSetFocusField @nMobile, 4        
                     GOTO Step_3_Fail        
                  END                           
                          
                  DECLARE CursorPTLConfirm CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
                  
                  SELECT DISTINCT DP.DeviceProfileKey         
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                  INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                  WHERE Loc.PutawayZone = @cPTSZone        
                  AND DP.DeviceType = 'LOC'    
                  AND DP.Status IN ( '0' ,'1')         
                  ORDER BY DP.DeviceProfileKey      
                        
            END                  
            OPEN CursorPTLConfirm        
                    
            FETCH NEXT FROM CursorPTLConfirm INTO @cDeviceProfileKey        
                    
            WHILE @@FETCH_STATUS <> -1          
            BEGIN           
                     
                     
               IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)         
                          WHERE DeviceProfileKey = @cDeviceProfileKey        
                          AND Status = '0' )         
               BEGIN        
                  UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)        
                  SET   Status = '1'         
                  WHERE DeviceProfileKey = @cDeviceProfileKey        
     AND Status = '0'        
                          
                  IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 83714        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileLogFail        
                     EXEC rdt.rdtSetFocusField @nMobile, 4        
                     GOTO Step_3_Fail        
                  END        
        
                  -- Chee01        
                  UPDATE dbo.DeviceProfile        
                  SET Status = '1'        
                  WHERE DeviceProfileKey = @cDeviceProfileKey        
                  AND Status = '0'        
                       
                  IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 83720        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail        
                     EXEC rdt.rdtSetFocusField @nMobile, 4        
                     GOTO Step_3_Fail        
                  END        
               END        
        
-- Chee01        
--               UPDATE dbo.DeviceProfile        
--               SET Status = '1'        
--               WHERE DeviceProfileKey = @cDeviceProfileKey        
--               AND Status = '0'        
--                       
--               IF @@ERROR <> 0         
--               BEGIN        
--                     SET @nErrNo = 83720        
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail        
--                     EXEC rdt.rdtSetFocusField @nMobile, 4        
--                     GOTO Step_3_Fail        
--               END        
    
               -- Update DropID to Status = '1'        
               SET @cDropID = ''        
               SELECT @cDropID = DropID         
               FROM dbo.DeviceProfileLog WITH (NOLOCK)        
               WHERE DeviceProfileKey = @cDeviceProfileKey        
               AND Status = '1'        
                 
               UPDATE DropID         
               SET Status = '1'        
               WHERE DropID = @cDropID        
               AND Status = '0'        
        
               IF @@ERROR <> 0         
               BEGIN        
                     SET @nErrNo = 83727        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIDFailed        
                     EXEC rdt.rdtSetFocusField @nMobile, 4        
                     GOTO Step_3_Fail        
               END        
               FETCH NEXT FROM CursorPTLConfirm INTO @cDeviceProfileKey        
                     
            END        
            CLOSE CursorPTLConfirm                    
            DEALLOCATE CursorPTLConfirm         
                    
            -- Prepare Next Screen Variable        
            SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
            SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
                          
            -- GOTO Next Screen        
            SET @nScn = @nScn + 1        
            SET @nStep = @nStep + 1        
        
      END        
      ELSE IF @cOptions = '9'        
      BEGIN        
                                
            -- Prepare Next Screen Variable        
            SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
            SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
            SET @cOutField03 = ''        
            SET @cOutField04 = ''        
            SET @cOutField05 = @cSuggestedLoc        
                    
                    
            -- GOTO Next Screen        
            SET @nScn = @nScn - 1        
            SET @nStep = @nStep - 1        
                    
            EXEC rdt.rdtSetFocusField @nMobile, 3        
                    
      END        
              
              
   END  -- Inputkey = 1        
           
   IF @nInputKey = 0         
   BEGIN        
       -- Prepare Previous Screen Variable        
       SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
       SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
       SET @cOutField03 = ''        
       SET @cOutField04 = ''        
       SET @cOutField05 = @cSuggestedLoc        
           
       -- GOTO Previous Screen        
       SET @nScn = @nScn - 1        
       SET @nStep = @nStep - 1        
               
       EXEC rdt.rdtSetFocusField @nMobile, 3        
   END        
   GOTO Quit        
           
   STEP_3_FAIL:        
   BEGIN        
              
      -- Prepare Next Screen Variable        
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = @nTotalToteCount        
      SET @cOutField04 = ''        
              
   END        
        
END         
GOTO QUIT        
        
/********************************************************************************        
Step 4. Scn = 3723.         
           
   Assignment Success Message        
           
           
********************************************************************************/        
Step_4:        
BEGIN        
   IF @nInputKey = 1 OR @nInputKey = 0         
   BEGIN        
      -- Prepare Next Screen Variable        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''        
             
      -- GOTO Screen 1        
      SET @nScn = @nScn - 3        
      SET @nStep = @nStep - 3        
              
      EXEC rdt.rdtSetFocusField @nMobile, 1        
   END  -- Inputkey = 1        
END         
GOTO QUIT        
        
/********************************************************************************        
Step 5. Scn = 3724.         
   Title           (field01)        
   PTSZone / CartID(field02)        
   Light Loc       (field03)        
   Tote ID         (field04)        
   Options         (field05, input)        
           
********************************************************************************/        
Step_5:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
              
      SET @cOptions = ISNULL(RTRIM(@cInField05),'')        
              
      IF @cOptions = ''        
      BEGIN        
         SET @nErrNo = 83715        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'        
         EXEC rdt.rdtSetFocusField @nMobile, 5        
         GOTO Step_5_Fail        
      END        
              
      IF @cOptions NOT IN ('1','9')        
      BEGIN        
         SET @nErrNo = 83716        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'        
         EXEC rdt.rdtSetFocusField @nMobile, 5        
         GOTO Step_5_Fail        
      END        
              
      IF @cOptions = '1'        
      BEGIN        
         IF @cAssignmentType = 'CartID'        
         BEGIN        
            SET @cModuleAddr = @cLightLoc        
                    
            SELECT @cDeviceProfileKey = DeviceProfileKey        
            FROM dbo.DeviceProfile WITH (NOLOCK)        
            WHERE DeviceID     = @cCartID        
            AND DevicePosition = @cModuleAddr         
                                           
         END        
         ELSE IF @cAssignmentType = 'PTSZone'        
         BEGIN        
            --SET @cModuleAddr = RIGHT(@cLightLoc,4)        
                    
            SELECT @cDeviceProfileKey = DeviceProfileKey          
                 , @cModuleAddr = DevicePosition        
            FROM dbo.DeviceProfile WITH (NOLOCK)          
            WHERE DeviceID = @cLightLoc         
         END        
        
         -- (Chee02)        
         SELECT @cOldToteID = DropID         
         FROM dbo.DeviceProfileLog WITH (NOLOCK)        
         WHERE DeviceProfileKey = @cDeviceProfileKey        
         AND Status IN ( '0', '1')                  
        
         IF EXISTS(SELECT 1 FROM dbo.DropID WITH (NOLOCK)         
                   WHERE DropID = @cOldToteID        
                     AND Status = '0')        
         BEGIN        
            DELETE FROM dbo.DropID        
            WHERE DropID = @cOldToteID        
        
            IF @@ERROR <> 0         
            BEGIN        
               SET @nErrNo = 87801        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelDropIDFail'        
               EXEC rdt.rdtSetFocusField @nMobile, 5        
               GOTO Step_5_Fail        
            END        
         END        
        
         UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)        
         SET DropID = @cToteID        
         WHERE DeviceProfileKey = @cDeviceProfileKey        
         AND Status IN ( '0', '1')         
                 
         IF @@ERROR <> 0         
         BEGIN        
            SET @nErrNo = 83717        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDProfileLogFail'        
            EXEC rdt.rdtSetFocusField @nMobile, 5        
            GOTO Step_5_Fail        
         END        
                 
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)         
                     WHERE DropID = @cToteID         
                     AND Status = '9' )         
         BEGIN        
            -- Update Old DropID Record with Suffix before Insert New One --        
            EXECUTE dbo.nspg_GetKey          
                     'DropIDSuffix',          
                     3 ,          
                     @cDropIDSuffix     OUTPUT,          
                     @b_success         OUTPUT,          
                     @nErrNo            OUTPUT,          
                     @cErrMsg           OUTPUT          
                    
            IF @b_success<>1          
            BEGIN          
                SET @nErrNo = 83737        
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetKeyFail'        
                EXEC rdt.rdtSetFocusField @nMobile, 3        
                GOTO Step_5_Fail          
            END          
           
            UPDATE dbo.DropIDDetail        
               SET DropID = RTRIM(@cToteID) + RTRIM(@cDropIDSuffix)        
            WHERE DropID = @cToteID         
                    
            IF @@ERROR <> 0         
            BEGIN        
                SET @nErrNo = 83738        
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDDetFail'        
                EXEC rdt.rdtSetFocusField @nMobile, 3        
                GOTO Step_5_Fail          
            END        
                    
            UPDATE dbo.DropID        
               SET DropID = RTRIM(@cToteID) + RTRIM(@cDropIDSuffix)        
            WHERE DropID = @cToteID         
            AND Status = '9'        
                    
            IF @@ERROR <> 0         
            BEGIN        
                SET @nErrNo = 83739        
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'        
                EXEC rdt.rdtSetFocusField @nMobile, 3        
                GOTO Step_5_Fail          
            END        
                    
            INSERT INTO dbo.DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey )          
            VALUES (@cToteID , '' , CASE WHEN @cAssignmentType = 'CarTID' THEN 'CART' ELSE 'PTS' END, '0' , '')          
             
            IF @@ERROR <> 0          
            BEGIN          
               SET @nErrNo = 83740          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'          
               EXEC rdt.rdtSetFocusField @nMobile, 5        
               GOTO Step_5_Fail          
            END          
         END        
                 
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)        
                        WHERE DropID = @cToteID )         
         BEGIN         
            INSERT INTO dbo.DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey )          
            VALUES (@cToteID , '' , CASE WHEN @cAssignmentType = 'CarTID' THEN 'CART' ELSE 'PTS' END, '0' , '')          
             
            IF @@ERROR <> 0          
            BEGIN          
               SET @nErrNo = 83728          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'          
               EXEC rdt.rdtSetFocusField @nMobile, 5        
               GOTO Step_5_Fail          
            END          
         END           
      END        
            
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
              
      IF  @cAssignmentType = 'PTSZone'        
      BEGIN        
         UPDATE rdt.rdtAssignLoc        
         SET Status = '9'        
         WHERE PTSLoc = @cLightLoc        
         AND WaveKEy = @cWaveKey        
                 
         IF @@ERROR <> 0         
         BEGIN        
              SET @nErrNo = 83746        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdAssignLocFail'        
               EXEC rdt.rdtSetFocusField @nMobile, 4        
               GOTO Step_5_Fail        
         END        
        
        
         SELECT TOP 1 @cSuggestedLoc = PTSLoc         
         FROM rdt.rdtAssignLoc WITH (NOLOCK)        
         WHERE WaveKey = @cWaveKey        
         AND PTSZone = @cPTSZone        
         --AND PTSPosition > @cSuggestedLoc        
         AND Status = '0'        
         Order By PTSPosition        
        
         SET @cOutField05 = @cSuggestedLoc        
        
      END        
      ELSE        
      BEGIN        
         SET @cOutField05 = ''        
      END        
           
      -- GOTO Previous Screen        
      SET @nScn = @nScn - 3        
      SET @nStep = @nStep - 3        
              
      EXEC rdt.rdtSetFocusField @nMobile, 3        
              
              
   END  -- Inputkey = 1        
        
        
   IF @nInputKey = 0         
   BEGIN        
             
          SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
          SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
          SET @cOutField03 = ''        
          SET @cOutField04 = ''        
          SET @cOutField05 = @cSuggestedLoc        
        
          -- GOTO Previous Screen        
          SET @nScn = @nScn - 3        
          SET @nStep = @nStep - 3        
                  
          EXEC rdt.rdtSetFocusField @nMobile, 3        
               
   END        
   GOTO Quit        
        
   STEP_5_FAIL:        
   BEGIN        
              
      -- Prepare Next Screen Variable        
      SET @cOutField05 = ''        
      SET @cOptions = ''        
              
   END        
         
        
END         
GOTO QUIT        
        
        
/********************************************************************************        
Step 6. Scn = 3725.         
   Title           (field01)        
   PTSZone / CartID(field02)        
   WaveKey         (field03, input)        
           
********************************************************************************/        
Step_6:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
              
      SET @cWaveKey = ISNULL(RTRIM(@cInField03),'')        
              
        
        
      IF @cWaveKey = ''        
      BEGIN        
         SET @nErrNo = 83741        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WaveKey Req'        
         EXEC rdt.rdtSetFocusField @nMobile, 3        
         GOTO Step_6_Fail        
      END        
              
      IF NOT EXISTS ( SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey )         
      BEGIN        
         SET @nErrNo = 83742        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidWaveKey'        
         EXEC rdt.rdtSetFocusField @nMobile, 5        
         GOTO Step_6_Fail        
      END        
        
      SET @nRecordCount = 0         
          
      IF ISNULL(RTRIM(@cExtendedWaveSP),'' )  = '' -- (ChewKP05)    
      BEGIN    
         IF EXISTS ( SELECT 1 FROM rdt.rdtAssignLoc WITH (NOLOCK)         
                     WHERE WaveKey = @cWaveKey )         
         BEGIN        
            SELECT @nRecordCount = COUNT(DISTINCT RowRef )        
            FROM rdt.rdtAssignLoc WITH (NOLOCK)        
            WHERE WaveKey = @cWaveKey        
            AND PTSZone = @cPTSZone        
            -- AND Status = '0' (Chee02)        
            AND Status = '9'        
                  
            IF @nRecordCount > 0 -- (Chee01)         
            BEGIN        
               SET @nErrNo = 83744        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSZoneAssigned'        
               EXEC rdt.rdtSetFocusField @nMobile, 5        
               GOTO Step_6_Fail        
            END        
         END        
      END    
        
      --IF NOT EXISTS ( SELECT 1 FROM rdt.RdtAssignLoc WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND PTSZone = @cPTSZone )  -- (ChewKP05)      
      --BEGIN        
      IF @cExtendedWaveSP <> ''      
      BEGIN      
                  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWaveSP AND type = 'P')      
            BEGIN      
                     
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedWaveSP) +      
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cWaveKey, @cPTSZone, @nErrNo OUTPUT, @cErrMsg OUTPUT '      
               SET @cSQLParam =      
                  '@nMobile        INT, ' +      
                  '@nFunc          INT, ' +      
                  '@cLangCode      NVARCHAR( 3), ' +      
                  '@cUserName      NVARCHAR( 18), ' +      
                  '@cFacility      NVARCHAR( 5), ' +      
                  '@cStorerKey     NVARCHAR( 15), ' +      
                  '@nStep          INT, ' +      
                  '@cWaveKey       NVARCHAR( 10), ' +      
                  '@cPTSZone       NVARCHAR( 10), ' +      
                  '@nErrNo         INT           OUTPUT, ' +       
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'      
                        
            
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cWaveKey, @cPTSZone,  @nErrNo OUTPUT, @cErrMsg OUTPUT       
            
               IF @nErrNo <> 0       
               BEGIN      
                  --SET @nErrNo = 87812        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenAssignmentFail'        
                  EXEC rdt.rdtSetFocusField @nMobile, 5        
                  GOTO Step_6_Fail       
               END      
           END      
      END      
      ELSE      
      BEGIN      
           
         IF (@cConfigOrderToLOcDetail = 1)  
         BEGIN  
  
            INSERT INTO Rdt.rdtAssignLoc ( WaveKey, PTSZone, PTSLoc, PTSPosition, Status )         
            SELECT  DISTINCT @cWaveKey, Loc.PutawayZone, OTL.Loc, D.DevicePosition, '0' -- (ChewKP01)         
            FROM dbo.WaveDetail WD WITH (NOLOCK)         
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey        
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey        
            INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.OrderKey = OD.OrderKey  
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = OTL.Loc        
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = Loc.Loc        
            WHERE WD.WaveKey = @cWaveKey        
            AND Loc.PutawayZone = @cPTSZone        
            AND D.DeviceType = 'LOC'  
        END  
        ELSE  
        BEGIN  
            INSERT INTO Rdt.rdtAssignLoc ( WaveKey, PTSZone, PTSLoc, PTSPosition, Status )         
            SELECT  DISTINCT @cWaveKey, Loc.PutawayZone, STL.Loc, D.DevicePosition, '0' -- (ChewKP01)         
            FROM dbo.WaveDetail WD WITH (NOLOCK)         
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey        
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey        
            INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKey = OD.UserDefine02 AND STL.StoreGroup = CASE WHEN O.Type = 'N' THEN O.OrderGroup +  O.SectionKey ELSE 'OTHERS' END        
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc        
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = Loc.Loc        
            WHERE WD.WaveKey = @cWaveKey        
            AND Loc.PutawayZone = @cPTSZone        
            AND D.DeviceType = 'LOC'  
        END        
      END      
               
      --END            
            
                
      SET @cSuggestedLoc = '' 
      
      IF (@cConfigOrderToLOcDetail = 1)  
      BEGIN 
            SELECT Top 1 @cSuggestedLoc = PTSLoc        
            FROM rdt.rdtAssignLoc AL WITH (NOLOCK) JOIN DBO.LOC LC WITH (NOLOCK)
            ON AL.PTSLoc=LC.Loc        
            WHERE WaveKey = @cWaveKey        
            AND PTSZone = @cPTSZone        
            AND AL.Status  = '0'        
            ORDER BY  LC.LogicalLocation    
      END
      ELSE
      BEGIN      
        
         SELECT Top 1 @cSuggestedLoc = PTSLoc        
         FROM rdt.rdtAssignLoc WITH (NOLOCK)         
         WHERE WaveKey = @cWaveKey        
         AND PTSZone = @cPTSZone        
         AND Status  = '0'        
         ORDER BY PTSPosition 
      END       
              
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
      SET @cOutField05 = @cSuggestedLoc        
           
      -- GOTO Previous Screen        
      SET @nScn = @nScnAssignLoc        
      SET @nStep = @nStepAssignLoc        
              
      EXEC rdt.rdtSetFocusField @nMobile, 3        
              
   END  -- Inputkey = 1        
        
   IF @nInputKey = 0         
   BEGIN                  
          SET @cOutField01 = ''        
          SET @cOutField02 = ''        
          SET @cOutField03 = ''        
          SET @cOutField04 = ''        
                  
          -- GOTO Previous Screen        
          SET @nScn = 3720        
          SET @nStep = 1        
                  
          --EXEC rdt.rdtSetFocusField @nMobile, 3        
   END        
   GOTO Quit        
        
   STEP_6_FAIL:        
   BEGIN       
      -- Prepare Next Screen Variable        
      SET @cOutField03 = ''        
      SET @cWaveKey = ''            
   END        
      
END         
GOTO QUIT        
       
/********************************************************************************        
Step 7. Scn = 3726.        
   RESET DEVICE?       
   1 = YES      
   OPTIONS:        (field01, input)        
********************************************************************************/        
Step_7:        
BEGIN        
  -- (Chee03)      
   -- Screen mapping          
   SET @cOption = @cInField01      
       
   IF @nInputKey = 1 -- ENTER          
   BEGIN        
      -- Check option valid          
      IF @cOption <> '' AND @cOption NOT IN ('1')      
      BEGIN          
         SET @nErrNo = 87803          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option          
         GOTO Step_7_Fail          
      END          
          
      -- Reset Device      
      IF @cOption = '1' --YES          
      BEGIN      
         IF @cAssignmentType = 'CartID'       
         BEGIN      
            IF EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)      
                      JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID      
                      JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey        
                      WHERE DP.DeviceType = 'Cart'       
                        AND DP.DeviceID = @cCartID      
                        AND D.Status < '9' )      
            BEGIN      
               SET @nErrNo = 87804      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotClose        
               GOTO Step_7_Fail        
            END        
      
            IF EXISTS(SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status <> '9')      
            BEGIN      
               -- Update PTLTran Table Status to 9      
               UPDATE dbo.PTLTran WITH (ROWLOCK)      
               SET Status = '9',       
                   EditDate = GETDATE(),      
                   EditWho = SUSER_SNAME()           
               WHERE DeviceID = @cCartID        
                 AND Status <> '9'      
                    
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 87805      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPTLTranFail        
                  GOTO Step_7_Fail        
               END        
            END      
      
            IF EXISTS(SELECT 1 FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)       
                      JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey      
                      WHERE DP.DeviceType = 'Cart'      
                        AND DP.DeviceID = @cCartID      
                        AND DPL.Status <> '9')      
            BEGIN      
               -- Update DeviceProfileLog Table Status to 9      
               UPDATE DPL       
               SET Status = '9'      
               FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)      
               JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey      
               WHERE DP.DeviceType = 'Cart'      
                 AND DP.DeviceID = @cCartID      
                 AND DPL.Status <> '9'      
      
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 87806       
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileLogFail        
                  GOTO Step_7_Fail        
               END        
            END      
      
            -- Update DeviceProfile Table Status to 0           
            UPDATE dbo.DeviceProfile WITH (ROWLOCK)      
            SET   Status = '0'         
                , DeviceProfileLogKey = ''        
            WHERE DeviceType = 'Cart'      
              AND DeviceID = @cCartID        
                    
            IF @@ERROR <> 0         
            BEGIN        
               SET @nErrNo = 83707      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail        
               GOTO Step_7_Fail        
            END        
         END      
         ELSE      
         BEGIN      
            IF EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)       
                      JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID     
                      JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey       
                      JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                      WHERE DP.DeviceType = 'LOC'        
                        AND Loc.PutawayZone = @cPTSZone       
                        AND D.Status < '9')      
            BEGIN      
               SET @nErrNo = 87808      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotClose        
               GOTO Step_7_Fail        
            END        
      
            DECLARE CursorPTLStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                 
            SELECT DISTINCT DP.DeviceProfileKey, DeviceID        
            FROM dbo.DeviceProfile DP WITH (NOLOCK)        
            INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
            WHERE Loc.PutawayZone = @cPTSZone        
            AND DP.DeviceType = 'LOC'                
                     
            OPEN CursorPTLStatus                        
            FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey, @cDeviceID      
                    
            WHILE @@FETCH_STATUS <> -1                    
            BEGIN           
               IF EXISTS(SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status <> '9')      
               BEGIN      
                  -- Update PTLTran Table Status to 9      
                  UPDATE dbo.PTLTran WITH (ROWLOCK)      
                  SET Status = '9',       
                      EditDate = GETDATE(),      
                      EditWho = SUSER_SNAME()           
                  WHERE DeviceID = @cDeviceID        
                    AND Status <> '9'      
                       
                  IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 87809       
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPTLTranFail        
                     GOTO Step_7_Fail        
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
                     SET @nErrNo = 87810       
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileLogFail        
                     GOTO Step_7_Fail        
                  END        
               END      
      
               -- Update DeviceProfile Table Status to 0           
               UPDATE dbo.DeviceProfile WITH (ROWLOCK)      
               SET   Status = '0'         
                   , DeviceProfileLogKey = ''        
               WHERE DeviceProfileKey = @cDeviceProfileKey         
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 83711      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDProfileFail        
                  GOTO Step_7_Fail        
               END                        
      
               FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey, @cDeviceID                      
            END        
            CLOSE CursorPTLStatus                    
            DEALLOCATE CursorPTLStatus           
         END      
      END -- IF @cOption = '1'      
      ELSE      
      BEGIN      
         IF @cAssignmentType = 'CartID'         
         BEGIN        
            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status = ('3') )         
            BEGIN        
               SET @nErrNo = 83703        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartInUse        
               GOTO Step_7_Fail        
            END        
                    
            -- Update DeviceProfile Table Cart Status = '0' When all detail in LightLocLog.Status = '9'        
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK)        
                            INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey        
                            WHERE LL.DeviceID = @cCartID         
                      AND LD.Status IN('0','1','3'))        
            BEGIN                
               UPDATE dbo.DeviceProfile        
               SET   Status = '0'         
              , DeviceProfileLogKey = ''        
               WHERE DeviceID = @cCartID        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 83704        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLightLocFail          
                  GOTO Step_7_Fail        
               END        
            END          
         END        
         ELSE      
         BEGIN        
            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                        INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                        INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                        WHERE Loc.PutawayZone = @cPTSZone        
                        AND DP.DeviceType = 'LOC'                                    
                        AND DPL.Status = '3' )         
            BEGIN        
               SET @nErrNo = 83729        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTSZoneInUse        
               GOTO Step_7_Fail        
            END        
                                  
            -- Update DeviceProfile Table Cart Status = '0' When all detail in LightLocLog.Status = '9'        
            IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)        
                            INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey         
                            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
                            WHERE Loc.PutawayZone = @cPTSZone        
                            AND DP.DeviceType = 'LOC'                                    
                            AND DPL.Status IN('0','1','3'))        
            BEGIN                
               DECLARE CursorPTLStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
               SELECT DISTINCT DP.DeviceProfileKey         
               FROM dbo.DeviceProfile DP WITH (NOLOCK)        
               --INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey   -- (ChewKP04)      
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID        
               WHERE Loc.PutawayZone = @cPTSZone        
               AND DP.DeviceType = 'LOC'                
                        
               OPEN CursorPTLStatus                        
               FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey        
                       
               WHILE @@FETCH_STATUS <> -1                    
               BEGIN           
                  UPDATE dbo.DeviceProfile        
                  SET   Status = '0'         
                      , DeviceProfileLogKey = ''        
                  WHERE DeviceProfileKey = @cDeviceProfileKey        
                     
      IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 83706        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLightLocFail        
                     GOTO Step_7_Fail        
                  END        
                          
                  FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey                      
               END        
               CLOSE CursorPTLStatus                    
               DEALLOCATE CursorPTLStatus           
            END       
         END        
      END      
      
      -- Prepare Next Screen Variable        
      SET @cOutField01 = RTRIM(@cAssignmentType) + ':'        
      SET @cOutField02 = CASE WHEN @cAssignmentType = 'CartID' THEN @cCartID ELSE @cPTSZone END        
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
      
      -- GOTO Next Screen        
      SET @nScn = CASE WHEN @cAssignmentType = 'CartID' THEN @nScnAssignLoc ELSE @nScnWaveKey END       
      SET @nStep = CASE WHEN @cAssignmentType = 'CartID' THEN @nStepAssignLoc ELSE @nStepWaveKey END     
      
      EXEC rdt.rdtSetFocusField @nMobile, 3         
      
   END  -- Inputkey = 1        
        
   IF @nInputKey = 0         
   BEGIN                  
      SET @cOutField01 = ''        
      SET @cOutField02 = ''        
      
      -- GOTO Previous Screen        
      SET @nScn = 3720        
      SET @nStep = 1        
   END        
   GOTO Quit        
        
   STEP_7_FAIL:        
   BEGIN       
      -- Prepare Next Screen Variable        
      SET @cOutField01 = ''           
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
              
      V_String1 = @cCartID,        
      V_String2 = @cLightLoc,        
      V_String3 = @cToteID,        
      V_String4 = @cPTSZone,        
      V_String5 = @cAssignmentType,        
      V_String6 = @nTotalToteCount,        
      V_String7 = @cAssignDropID,        
      V_String8 = @cSuggestedLoc,        
      V_String9 = @cWaveKey,        
      V_String10 = @cExtendedWaveSP, -- (ChewKP03)  
      V_String11 = @cConfigOrderToLOcDetail,      
         
              
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