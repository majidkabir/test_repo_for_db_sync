SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_814ExtUpdSP01                                   */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose: Unity PTL Logic                                             */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2014-10-03  1.0  ChewKP   Created                                    */      
/************************************************************************/      
CREATE PROC [RDT].[rdt_814ExtUpdSP01] (      
  @nMobile          INT,     
  @nFunc            INT,     
  @cLangCode        NVARCHAR( 3),       
  @cUserID          NVARCHAR( 18),      
  @cFacility        NVARCHAR( 5),       
  @cStorerKey       NVARCHAR( 15),      
  @nStep            INT,                
  @cDeviceID        NVARCHAR( 10),      
  @cLightModule     NVARCHAR( 10),      
  @cPTLMTCode       NVARCHAR( 10),      
  @nErrNo           INT           OUTPUT,       
  @cErrMsg          NVARCHAR( 20) OUTPUT      
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE @cDeviceProfileLogKey NVARCHAR(10)    
          ,@cLightMode           NVARCHAR(10)    
          ,@nTranCount           INT    
          ,@b_success            INT    
          ,@cDeviceProfileKey    NVARCHAR(10)    
          ,@nPTLKey              INT    
          ,@cDevicePosition      NVARCHAR(10)    
          ,@cSuggSKU             NVARCHAR(10)    
          ,@cDisplayValue        NVARCHAR(5)    
          ,@cUOM                 NVARCHAR(10)    
          ,@cSuggPosition        NVARCHAR(10)    
          ,@cJobName             NVARCHAR(100)    
          ,@cModuleAddress       NVARCHAR(10)    
          ,@cPTLDeviceID         NVARCHAR(10)    
          ,@cLightSequence       NVARCHAR(10)    
          ,@cUserName            NVARCHAR(18)    
          ,@cRemarks             NVARCHAR(500)    
          ,@nPTLQty              INT    
          ,@cPackkey             NVARCHAR(10)    
          ,@cOrderKey            NVARCHAR(10)    
          ,@cDropID              NVARCHAR(10)    
          ,@cPrefUOM             NVARCHAR(10)     
          ,@cPutawayZone         NVARCHAR(10)    
          ,@cModuleAddressSecondary NVARCHAR(10)    
    
          ,@cWaveKey             NVARCHAR(10)    
          ,@cHoldUserID           NVARCHAR(18)    
          ,@cHoldDeviceProfileLogKey NVARCHAR(20)    
          ,@cHoldSuggSKU         NVARCHAR(20)    
          ,@cHoldUOM             NVARCHAR(10)    
          ,@cLightModeHOLD       NVARCHAR(10)    
          ,@cHoldConsigneeKey    NVARCHAR(15)    
          ,@nHoldPTLKey          INT    
          ,@nVarPTLKey           INT    
          ,@cVarLightMode        NVARCHAR(10)    
          ,@cLightModeStatic     NVARCHAR(10)    
          ,@cLightPriority       NVARCHAR(1)     
          ,@nNewPTLTranKey       INT    
          ,@cHoldDevicePosition  NVARCHAR(10)    
          ,@cHoldDeviceID        NVARCHAR(10)    
          ,@cLoc                 NVARCHAR(10)    
          ,@nCountTaskPanel      INT    
          ,@nExpectedQty         INT    
          ,@nCountLightPanelUser INT    
          ,@cHealthCheck         NVARCHAR(1)
          ,@cIPAddress           NVARCHAR(40) 
          ,@cDSPMessage          NVARCHAR(2000)

   SET @nTranCount = @@TRANCOUNT    
       
   BEGIN TRAN    
   SAVE TRAN rdt_814ExtUpdSP01    
    
   SELECT @cLightModeStatic = Short    
   FROM dbo.CodelKup WITH (NOLOCK)     
   WHERE ListName = 'LightMode'    
   AND Code = 'White'    
       
   IF @cPTLMTCode = 'SG001' -- Refresh BONDPC    
   BEGIN    
      SELECT @cJobName = ISNULL(Long,'')      
      FROM CodeLkup WITH (NOLOCK)      
      WHERE ListName = 'PTL_MT'      
      AND Code = 'SG001'    
      AND StorerKey = @cStorerKey    
          
      EXEC MASTER.dbo.isp_StartSQLJob @c_ServerName=@@SERVERNAME, @c_JobName=@cJobName              
   END    
   ELSE IF @cPTLMTCode = 'SG002' -- Terminate AllLight    
   BEGIN    
      SET @cPutawayZone = @cDeviceID     
      SET @cDeviceID = ''    
  
      SELECT TOP 1 @cDeviceID = DP.DeviceID    
      FROM dbo.DeviceProfile DP WITH (NOLOCK)     
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON DP.DeviceID = Loc.Loc    
      WHERE Loc.PutawayZone = @cPutawayZone    
  
      -- Initialize LightModules    
      EXEC [dbo].[isp_DPC_TerminateAllLight]     
            @cStorerKey    
           ,@cDeviceID      
           ,@b_Success    OUTPUT      
           ,@nErrNo       OUTPUT    
           ,@cErrMsg      OUTPUT    
                
      IF @nErrNo = 0     
      BEGIN    
         SET @nErrNo = 91951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'    
      END    
      ELSE    
      BEGIN    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
      END    
   END    
   ELSE IF @cPTLMTCode = 'SG003' -- Re-Light.    
   BEGIN    
      -- Initialize LightModules    
          
      SELECT @cModuleAddress = DevicePosition     
      FROM dbo.DeviceProfile WITH (NOLOCK)    
      WHERE DeviceID = @cLightModule    
      AND StorerKey = @cStorerKey    
      AND Priority = '1'    
          
      SELECT @cModuleAddressSecondary = DevicePosition     
      FROM dbo.DeviceProfile WITH (NOLOCK)    
      WHERE DeviceID = @cLightModule    
      AND StorerKey = @cStorerKey    
      AND Priority = '0'    
                
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)     
                  WHERE DevicePosition = @cModuleAddress     
                  AND Status IN ('1' )  )     
      BEGIN     
         SELECT TOP 1 @nPTLKey   = PTL.PTLKey    
               ,@cPTLDeviceID    = PTL.DeviceID    
               ,@cRemarks        = PTL.Remarks    
               ,@cLoc            = PTL.Loc    
               ,@cLightSequence  = PTL.LightSequence    
               ,@cLightMode      = PTL.LightMode    
               ,@cSuggSKU        = PTL.SKU    
               ,@cUOM            = PTL.UOM    
               ,@cUserName       = PTL.AddWho    
               ,@cDeviceProfileLogKey = PTL.DeviceProfileLogKey    
               ,@cDropID         = PTL.DropID    
               ,@nPTLQty         = PTL.Qty    
               ,@cOrderKey       = PTL.OrderKey    
               ,@nExpectedQty    = PTL.ExpectedQty    
         FROM dbo.PTLTran PTL WITH (NOLOCK)    
         INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DevicePosition = PTL.DevicePosition    
         WHERE PTL.DevicePosition = @cModuleAddress    
         AND DP.StorerKey = @cStorerKey    
         AND DP.Priority = '1'     
         AND PTL.Status IN ('1')     
         ORDER BY PTL.DeviceProfileLogKey    
             
         IF @cLightSequence = '1' AND ISNULL(RTRIM(@cRemarks),'')  = ''    
         BEGIN    
            INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
            VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '1', @cRemarks , @nPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))     
                
            -- Only Relight When Count = 2 , e.g. 2 Panel is status = '1'    
    
--                     SET @nCountTaskPanel = 0     
--    
--                     SELECT @nCountTaskPanel = Count(PTLKey)     
--                     FROM dbo.PTLTran WITH (NOLOCK)    
--                     WHERE Status             IN ( '1' )     
--                       AND AddWho             = @cUserName    
--                       AND DeviceID           = @cLightModule       
--                       AND SKU                = @cSuggSKU    
--                       AND UOM                = @cUOM    
--                       AND DropID             = @cDropID    
--                       AND DeviceProfileLogKey = @cDeviceProfileLogKey    
--                     --ORDER BY DeviceID, PTLKey    
--                      
--                         
--    
--                     IF @nCountTaskPanel = 2     
--                     BEGIN    
       
            -- Start to Light Up First Location --     
            DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
                
            SELECT PTLKey, DevicePosition, LightMode    
            FROM dbo.PTLTran PTL WITH (NOLOCK)    
            WHERE Status             IN ( '1' )     
              AND AddWho             = @cUserName    
              AND DeviceID           = @cLightModule       
              AND SKU                = @cSuggSKU    
              AND UOM                = @cUOM    
              AND DropID             = @cDropID    
              AND DeviceProfileLogKey = @cDeviceProfileLogKey    
            ORDER BY DeviceID, PTLKey    
                
            OPEN CursorLightUp                
                
            FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode    
                
            WHILE @@FETCH_STATUS <> -1         
            BEGIN    
                   
               UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
               SET Status = '0'    
               WHERE PTLKey = @nPTLKey    
  
               IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                           WHERE DeviceID = @cLightModule    
                           AND DevicePosition = @cDevicePosition    
                           AND Priority = '0' )     
               BEGIN    
                  SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) )    
               END                      
               ELSE    
               BEGIN    
                  SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) )    
               END    
               EXEC [dbo].[isp_DPC_LightUpLoc]     
                     @c_StorerKey = @cStorerKey     
                    ,@n_PTLKey    = @nPTLKey        
                    ,@c_DeviceID  = @cLightModule      
                    ,@c_DevicePos = @cDevicePosition     
                    ,@n_LModMode  = @cLightMode      
                    ,@n_Qty       = @cDisplayValue           
                    ,@b_Success   = @b_Success   OUTPUT      
                    ,@n_Err       = @nErrNo      OUTPUT    
                    ,@c_ErrMsg    = @cErrMsg     OUTPUT     
             
               IF @@ERROR <> 0     
               BEGIN    
                     SET @nErrNo = 91952    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
                   GOTO RollBackTran    
               END    
                        
                    
               FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode    
            END    
            CLOSE CursorLightUp                
            DEALLOCATE CursorLightUp       
         END    
--               ELSE IF @cLightSequence = '1' AND ISNULL(RTRIM(@cRemarks),'')  = 'HOLD'    
--               BEGIN    
--                       UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
--                           SET Status = '0'    
--                       WHERE PTLKey = @nPTLKey    
--    
--                       EXEC [dbo].[isp_DPC_LightUpLoc]     
--                              @c_StorerKey = @cStorerKey     
--                             ,@n_PTLKey    = @nPTLKey        
--                             ,@c_DeviceID  = @cLightModule      
--                             ,@c_DevicePos = @cModuleAddress     
--                             ,@n_LModMode  = @cLightMode      
--                             ,@n_Qty       = @cRemarks           
--                             ,@b_Success   = @b_Success   OUTPUT      
--                             ,@n_Err       = @nErrNo      OUTPUT    
--                             ,@c_ErrMsg    = @cErrMsg     OUTPUT     
--                      
--                        IF @@ERROR <> 0     
--                        BEGIN    
--                              SET @nErrNo = 91953    
--                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
--                            GOTO RollBackTran    
--                        END    
--               END    
         ELSE IF @cLightSequence = '3' AND ISNULL(RTRIM(@cRemarks),'')  NOT IN ('END', 'FULL', ' HOLD')     
         BEGIN    
           INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
           VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '3', @cRemarks , @nPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))      
             
           UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
               SET Status = '0'    
           WHERE PTLKey = @nPTLKey    
    
           EXEC [dbo].[isp_DPC_LightUpLoc]     
                  @c_StorerKey = @cStorerKey     
                 ,@n_PTLKey    = @nPTLKey        
                 ,@c_DeviceID  = @cPTLDeviceID      
                 ,@c_DevicePos = @cModuleAddress     
                 ,@n_LModMode  = @cLightMode      
                 ,@n_Qty       = @cRemarks           
                 ,@b_Success   = @b_Success   OUTPUT      
                 ,@n_Err       = @nErrNo      OUTPUT    
                 ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                      
            IF @@ERROR <> 0     
            BEGIN    
                  SET @nErrNo = 91953    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
                GOTO RollBackTran    
            END    
         END    
         ELSE IF @cLightSequence = '4' AND ISNULL(RTRIM(@cRemarks),'')  = 'END'    
         BEGIN    
           INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
           VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '4', @cRemarks , @nPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))     
         
           UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
               SET Status = '0'    
           WHERE PTLKey = @nPTLKey    
  
           EXEC [dbo].[isp_DPC_LightUpLoc]     
                  @c_StorerKey = @cStorerKey     
                 ,@n_PTLKey    = @nPTLKey        
                 ,@c_DeviceID  = @cLightModule      
                 ,@c_DevicePos = @cModuleAddress     
                 ,@n_LModMode  = @cLightMode      
                 ,@n_Qty       = @cRemarks           
                 ,@b_Success   = @b_Success   OUTPUT      
                 ,@n_Err       = @nErrNo      OUTPUT    
                 ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                            
         IF @@ERROR <> 0     
         BEGIN    
            SET @nErrNo = 91953    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
            GOTO RollBackTran    
         END    
      END    
   ELSE IF @cLightSequence = '5' AND ISNULL(RTRIM(@cRemarks),'')  = 'FULL'    
   BEGIN    
       INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
       VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '5', @cRemarks , @nPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))     
                             
--                        IF ISNULL(RTRIM(@cLoc),'') = @cLightModule AND ISNULL(RTRIM(@cRemarks),'') = @cLightModule    
--                        BEGIN    
--                               
--                           UPDATE dbo.PTLTran WITH (ROWLOCK)    
--                           SET Status = '9'    
--                           WHERE PTLKey = @nPTLKey    
--                               
--                           SET @nErrNo = 91954      
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PlsRestartUser'      
--                               
--                               
--                        END    
    
        UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
            SET Status = '0'    
        WHERE PTLKey = @nPTLKey    
  
        EXEC [dbo].[isp_DPC_LightUpLoc]     
               @c_StorerKey = @cStorerKey     
              ,@n_PTLKey    = @nPTLKey        
              ,@c_DeviceID  = @cLightModule      
              ,@c_DevicePos = @cModuleAddress     
              ,@n_LModMode  = @cLightMode      
              ,@n_Qty       = @cRemarks           
              ,@b_Success   = @b_Success   OUTPUT      
              ,@n_Err       = @nErrNo      OUTPUT    
              ,@c_ErrMsg    = @cErrMsg     OUTPUT     
       
         IF @@ERROR <> 0     
         BEGIN    
               SET @nErrNo = 91955    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
             GOTO RollBackTran    
         END    
      END    
      ELSE IF @cLightSequence = '2'     
      BEGIN    
         INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
         VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '2', @cRemarks ,@nPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))     
  
        SELECT --@cUOM = PD.UOM     
              @cPackkey = SKU.PackKey    
        FROM dbo.PickDetail PD WITH (NOLOCK)    
        INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey    
        WHERE PD.StorerKey = @cStorerKey    
          AND PD.OrderKey  = @cOrderKey    
          AND PD.DropID    = @cDropID    
          AND PD.Status    = '5'    
            
        SELECT @cPrefUOM = Short     
        FROM dbo.CodeLkup WITH (NOLOCK)    
        WHERE ListName = 'LightUOM'    
        AND Code = @cUOM    
            
        SET @cDisplayValue = RIGHT(RTRIM(@cPrefUOM),2) + RIGHT('   ' + CAST(@nExpectedQty AS NVARCHAR(3)), 3)     
  
        UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
               SET Status = '0'    
        WHERE PTLKey = @nPTLKey  
            
        INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5, TotalTime)     
        VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '1', '2', '2.1',@nPTLKey, @cPTLMTCode,  
                 @cPackkey, @cPrefUOM ,@cDisplayValue, @nPTLKey, @cDropID, RIGHT(SUSER_SNAME(), 12))     
  
        EXEC [dbo].[isp_DPC_LightUpLoc]     
              @c_StorerKey = @cStorerKey     
             ,@n_PTLKey    = @nPTLKey        
             ,@c_DeviceID  = @cLightModule     
             ,@c_DevicePos = @cModuleAddress     
             ,@n_LModMode  = @cLightMode      
             ,@n_Qty       = @cDisplayValue           
             ,@b_Success   = @b_Success   OUTPUT      
             ,@n_Err       = @nErrNo      OUTPUT    
             ,@c_ErrMsg    = @cErrMsg     OUTPUT    
                   
                   
      END    
   END  -- Status IN ('1' )   
   ELSE     
   BEGIN     
      INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5, TotalTime )    
      VALUES( 'rdt_814ExtUpdSP01' , Getdate() , '1' , '0', '', @nPTLKey, @cPTLMTCode, @cLightModule  , @cUserName, @cWaveKey, '', '', RIGHT(SUSER_SNAME(), 12))     
    
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)     
                      WHERE DevicePosition = @cModuleAddress     
                      AND Status = '9'     
                      AND Remarks = 'HOLD'    
                      AND LightSequence = '0')     
      BEGIN    
         SELECT TOP 1 @nPTLKey   = PTL.PTLKey    
               ,@cUserName       = PTL.AddWho    
               ,@cWaveKey        = PTL.SourceKey    
         FROM dbo.PTLTran PTL WITH (NOLOCK)    
         INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DevicePosition = PTL.DevicePosition    
         WHERE PTL.DevicePosition = @cModuleAddress    
         AND DP.StorerKey = @cStorerKey    
         AND DP.Priority = '1'     
         AND PTL.Status IN ('9')     
         AND Remarks = 'HOLD'    
         AND LightSequence = '0'    
         ORDER BY PTL.EditDate DESC  
             
         INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5, TotalTime )    
         VALUES( 'rdt_814ExtUpdSP01' , Getdate() , '1' , '0', '0.1', @nPTLKey, @cPTLMTCode, @cLightModule  , @cUserName, @cWaveKey, '', '', RIGHT(SUSER_SNAME(), 12))   
                                                      
         -- Process for Hold Location --     
         IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                         WHERE DeviceID = @cLightModule    
                         AND Status = '1'    
                         AND SourceKey = @cWaveKey    
                         AND AddWho <> @cUserName     
                         AND Remarks NOT IN ('HOLD', 'FULL', 'END') )     
         BEGIN    
            SELECT TOP 1  @cHoldUserID = AddWho     
                        , @cHoldDeviceProfileLogKey = DeviceProfileLogKey    
                        , @cHoldSuggSKU = SKU    
                        , @cHoldUOM     = UOM    
                        , @cHoldConsigneeKey = ConsigneeKey    
                        , @cHoldDeviceID = DeviceID    
                        , @nHoldPTLKey  = PTLKey    
            FROM dbo.PTLTran WITH (NOLOCK)    
            WHERE Remarks = 'HOLD'    
            AND DevicePosition = @cModuleAddress    
            AND LightSequence = '0'    
            AND AddWho =  @cUserName    
            Order By DeviceProfileLogKey    
    
            SELECT @cHoldDevicePosition =  DevicePosition    
            FROM dbo.DeviceProfile WITH (NOLOCK)     
            WHERE DeviceID = @cLightModule    
            AND Priority = '1'    
            AND StorerKey = @cStorerKey     
                
            SELECT @cLightModeHOLD = DefaultLightColor     
            FROM rdt.rdtUser WITH (NOLOCK)    
            WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')     
                
            INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5, TotalTime )    
            VALUES( 'rdt_814ExtUpdSP01' , Getdate() , '11' , @cLightModule , @cHoldUserID , @cHoldDeviceProfileLogKey,   
                    @cHoldSuggSKU, @cHoldUOM, @cHoldConsigneeKey , @nHoldPTLKey , @cHoldDeviceID , @cHoldDevicePosition, RIGHT(SUSER_SNAME(), 12) )      
  
       
            IF ISNULL(@cHoldDeviceProfileLogKey,'')  <> ''    
            BEGIN    
               SELECT @cLightModeHOLD = DefaultLightColor     
               FROM rdt.rdtUser WITH (NOLOCK)    
               WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')     
             
               -- ChecK If It is First Record ? -- If Yes Light Up From RDT PTS Carton --     
               IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                               WHERE Status = '9'    
                               AND DeviceProfileLogKey = @cHoldDeviceProfileLogKey )     
               BEGIN    
                  GOTO QUIT    
               END    
               -- Not More PTLTran Quit --     
               IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                               WHERE Status NOT IN ( '5','9' )     
                               AND SourceKey = @cWaveKey    
                               AND AddWho = @cHoldUserID )     
               BEGIN    
                  GOTO QUIT     
               END    
                               
               -- Unlock Current User --       
               EXEC [dbo].[isp_LightUpLocCheck]       
                  @nPTLKey                = @nHoldPTLKey                    
                 ,@cStorerKey             = @cStorerKey                 
                 ,@cDeviceProfileLogKey   = @cHoldDeviceProfileLogKey       
                 ,@cLoc                   = @cLightModule                       
                 ,@cType                  = 'UNLOCK'                      
                 ,@nErrNo                 = @nErrNo               OUTPUT      
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max      
                     
               -- Lock Next User --      
               EXEC [dbo].[isp_LightUpLocCheck]       
          @nPTLKey                = @nHoldPTLKey                    
                 ,@cStorerKey             = @cStorerKey                 
                 ,@cDeviceProfileLogKey   = @cHoldDeviceProfileLogKey       
                 ,@cLoc                   = @cHoldDeviceID                       
                 ,@cType                  = 'LOCK'                      
                 ,@nErrNo                 = @nErrNo               OUTPUT      
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max      
                                
               IF @nErrNo <> 0     
               BEGIN    
                  EXEC [dbo].[isp_LightUpLocCheck]       
                  @nPTLKey                = @nHoldPTLKey                    
                 ,@cStorerKey             = @cStorerKey                 
                 ,@cDeviceProfileLogKey   = @cHoldDeviceProfileLogKey       
                 ,@cLoc                   = @cLightModule                       
                 ,@cType                  = 'LOCK'                      
                 ,@nErrNo                 = @nErrNo               OUTPUT      
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max      
                                 
                 SET @nErrNo = 91956    
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReLight Fail'    
                 GOTO QUIT    
               END    
       
               DECLARE CursorLightUpNextLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
               SELECT DevicePosition     
               FROM dbo.DeviceProfile WITH (NOLOCK)    
               WHERE DeviceID           = @cLightModule    
                 AND StorerKey          = @cStorerKey    
                 AND Priority           = '1'    
               ORDER BY DeviceID, DevicePosition    
                   
               OPEN CursorLightUpNextLoc                
                               
               FETCH NEXT FROM CursorLightUpNextLoc INTO @cDevicePosition    
               WHILE @@FETCH_STATUS <> -1         
               BEGIN    
                 IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                             WHERE DeviceID = @cLightModule    
                              AND DevicePosition = @cDevicePosition    
                              AND Priority = '0'    
                              AND StorerKey = @cStorerKey )     
                  BEGIN    
                     SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cHoldDeviceID) , 1 , 5 ) )    
                     SET @cVarLightMode = @cLightModeStatic    
                     SET @cLightPriority = '0'    
                  END                           
                  ELSE    
                  BEGIN    
                     SET @cDisplayValue = RTRIM(@cHoldDeviceID)    
                     SET @cVarLightMode = @cLightModeHold    
                     SET @cLightPriority = '1'    
                  END    
                  -- INSERT END --     
                  INSERT INTO PTLTran    
                       (    
                          -- PTLKey -- this column value is auto-generated    
                          IPAddress,  DeviceID,     DevicePosition,    
                          [Status],   PTL_Type,     DropID,    
                          OrderKey,   Storerkey,    SKU,    
                          LOC,        ExpectedQty,  Qty,    
                          Remarks,    MessageNum,   Lot,    
                          DeviceProfileLogKey, RefPTLKey, ConsigneeKey,    
                          CaseID, LightMode, LightSequence, AddWho, UOM, SourceKey    
                       )    
                  SELECT  IPAddress,  @cLightModule,     @cHoldDevicePosition,    
                          '0',   PTL_Type,     DropID,    
                          OrderKey,   Storerkey,    @cHoldSuggSKU,    
                          @cHoldDeviceID,     ExpectedQty,  0,    
                          @cHoldDeviceID,    '',   Lot,    
                          @cHoldDeviceProfileLogKey, @nPTLKey, @cHoldConsigneeKey,    
                          CaseID, @cLightModeHold, '3', @cHoldUserID, @cHoldUOM, SourceKey    
                  FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE PTLKEy = @nPTLKey    
                                  
                  SELECT @nNewPTLTranKey  = PTLKey    
                  FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
                  AND Status = '0'    
                  AND DevicePosition = @cDevicePosition    
          
                  EXEC [dbo].[isp_DPC_LightUpLoc]     
                        @c_StorerKey = @cStorerKey     
                       ,@n_PTLKey    = @nNewPTLTranKey        
                       ,@c_DeviceID  = @cLightModule      
                       ,@c_DevicePos = @cDevicePosition     
                       ,@n_LModMode  = @cVarLightMode    
                       ,@n_Qty       = @cDisplayValue           
                       ,@b_Success   = @b_Success   OUTPUT      
                       ,@n_Err       = @nErrNo      OUTPUT    
                       ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                      
                  IF @cLightPriority = '0'    
                  BEGIN    
                       UPDATE PTLTran WITH (ROWLOCK)    
                       SET Status = '9'    
                       WHERE PTLKey = @nNewPTLTranKey    
                  END    
       
                          
                  SET @nNewPTLTranKey = 0     
                      
                       
                  FETCH NEXT FROM CursorLightUpNextLoc INTO @cDevicePosition      
               END    
               CLOSE CursorLightUpNextLoc                
               DEALLOCATE CursorLightUpNextLoc  
                         
               -- Update LightSequence of HOLD  = 5 --     
               UPDATE PTLTran WITH (ROWLOCK)     
               SET LightSequence = '5'    
               WHERE PTLKey = @nHoldPTLKey    
                   
               INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, Step5, TotalTime)     
               VALUES( 'rdt_814ExtUpdSP01' , Getdate() , '12' , '0', '', @nHoldPTLKey, @cPTLMTCode, RIGHT(SUSER_SNAME(), 12))    
                   
            END       
            --GOTO QUIT    
         END    
         GOTO QUIT      
      END    
          
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE DevicePosition = @cModuleAddress     
                  AND Status = '0'    
                  AND LightSequence = '3' )     
      BEGIN    
         INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, TotalTime)     
         VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '0', '3', @cRemarks , @nPTLKey, RIGHT(SUSER_SNAME(), 12))     
                
         SET @nPTLKey    = 0     
         SET @cLightMode = ''    
         SET @cRemarks   = ''    
         SET @cPTLDeviceID = ''    
             
         SELECT @nPTLKey    = PTLKey    
               ,@cLightMode = LightMode    
               ,@cRemarks   = Remarks     
               ,@cPTLDeviceID = DeviceID    
         FROM dbo.PTLTran WITH (NOLOCK)     
         WHERE DevicePosition = @cModuleAddress     
         AND Status = '0'    
         AND LightSequence = '3'    
             
             
         EXEC [dbo].[isp_DPC_LightUpLoc]     
               @c_StorerKey = @cStorerKey     
              ,@n_PTLKey    = @nPTLKey        
              ,@c_DeviceID  = @cPTLDeviceID      
              ,@c_DevicePos = @cModuleAddress     
              ,@n_LModMode  = @cLightMode      
              ,@n_Qty       = @cRemarks           
              ,@b_Success   = @b_Success   OUTPUT      
              ,@n_Err       = @nErrNo      OUTPUT    
              ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                  
         GOTO QUIT     
      END    
         
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE DevicePosition = @cModuleAddress     
                  AND Status = '0'    
                  AND LightSequence = '4' )     
      BEGIN    
         INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, TotalTime)     
         VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '0', '4', @cRemarks , @nPTLKey, RIGHT(SUSER_SNAME(), 12))     
             
         SET @nPTLKey    = 0     
         SET @cLightMode = ''    
         SET @cRemarks   = ''    
             
         SELECT @nPTLKey    = PTLKey    
               ,@cLightMode = LightMode    
               ,@cRemarks   = Remarks     
         FROM dbo.PTLTran WITH (NOLOCK)     
         WHERE DevicePosition = @cModuleAddress     
         AND Status = '0'    
         AND LightSequence = '4'    
             
             
         EXEC [dbo].[isp_DPC_LightUpLoc]     
               @c_StorerKey = @cStorerKey     
              ,@n_PTLKey    = @nPTLKey        
              ,@c_DeviceID  = @cLightModule      
              ,@c_DevicePos = @cModuleAddress     
              ,@n_LModMode  = @cLightMode      
              ,@n_Qty       = @cRemarks           
              ,@b_Success   = @b_Success   OUTPUT      
              ,@n_Err       = @nErrNo      OUTPUT    
              ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                  
         GOTO QUIT     
      END    
                   
      IF EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                  WHERE DevicePosition = @cModuleAddressSecondary                      
                  AND Status = '1'     
                  AND LightSequence = '1' )     
      BEGIN    
         IF EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                     WHERE DevicePosition = @cModuleAddress                      
                     AND Status = '1'     
                     AND LightSequence = '1' )     
         BEGIN    
                INSERT INTO TRACEINFO (TRACENAME, TimeIN, Step1, Step2, Step3, Step4, TotalTime)     
                VALUES ( 'rdt_814ExtUpdSP01', GETDATE() , '0', '1', @cRemarks , @nPTLKey, RIGHT(SUSER_SNAME(), 12))     
                   
                   
                SELECT TOP 1 @nPTLKey   = PTL.PTLKey    
                     ,@cPTLDeviceID    = PTL.DeviceID    
                     ,@cRemarks        = PTL.Remarks    
                     ,@cLoc            = PTL.Loc    
                     ,@cLightSequence  = PTL.LightSequence    
                     ,@cLightMode      = PTL.LightMode    
                     ,@cSuggSKU        = PTL.SKU    
                     ,@cUOM            = PTL.UOM    
                     ,@cUserName       = PTL.AddWho    
                     ,@cDeviceProfileLogKey = PTL.DeviceProfileLogKey    
                     ,@cDropID         = PTL.DropID    
                     ,@nPTLQty         = PTL.Qty    
                     ,@cOrderKey       = PTL.OrderKey    
                     ,@nExpectedQty    = PTL.ExpectedQty    
               FROM dbo.PTLTran PTL WITH (NOLOCK)    
               INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DevicePosition = PTL.DevicePosition    
               WHERE PTL.DevicePosition = @cModuleAddressSecondary    
               AND DP.StorerKey = @cStorerKey    
               AND DP.Priority = '0'     
               AND PTL.Status IN ('1')     
               ORDER BY PTL.DeviceProfileLogKey    
                   
               -- Start to Light Up First Location --     
               DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
                   
               SELECT PTLKey, DevicePosition, LightMode    
               FROM dbo.PTLTran PTL WITH (NOLOCK)    
               WHERE Status             IN ( '1' )     
                 AND AddWho             = @cUserName    
                 AND DeviceID           = @cPTLDeviceID       
                 AND SKU                = @cSuggSKU    
                 AND UOM                = @cUOM    
               AND DropID             = @cDropID    
                 AND DeviceProfileLogKey = @cDeviceProfileLogKey    
               ORDER BY DeviceID, PTLKey    
                   
               OPEN CursorLightUp                
                   
               FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode    
                   
                   
               WHILE @@FETCH_STATUS <> -1         
               BEGIN    
                      
                  UPDATE dbo.PTLTRAN WITH (ROWLOCK)     
                  SET Status = '0'    
                  WHERE PTLKey = @nPTLKey    
       
                  IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                                       WHERE DeviceID = @cLightModule    
                                       AND DevicePosition = @cDevicePosition    
                                       AND Priority = '0' )     
                  BEGIN    
                     SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) )    
                  END                      
                  ELSE    
                  BEGIN    
                     SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) )    
                  END    
                      
                      
                  EXEC [dbo].[isp_DPC_LightUpLoc]     
                        @c_StorerKey = @cStorerKey     
                       ,@n_PTLKey    = @nPTLKey        
                       ,@c_DeviceID  = @cLightModule      
                       ,@c_DevicePos = @cDevicePosition     
                       ,@n_LModMode  = @cLightMode      
                       ,@n_Qty       = @cDisplayValue           
                       ,@b_Success   = @b_Success   OUTPUT      
                       ,@n_Err       = @nErrNo      OUTPUT    
                       ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                
                  IF @@ERROR <> 0     
                  BEGIN    
                        SET @nErrNo = 91952    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
                      GOTO RollBackTran    
                  END    
                  FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode    
               END    
               CLOSE CursorLightUp                
               DEALLOCATE CursorLightUp         
         END             
      END    
   END    
END -- IF @cPTLMTCode = 'SG003'   
ELSE IF @cPTLMTCode = 'SG004' -- Re-Light.    
BEGIN    
   SET @cPutawayZone = @cDeviceID     
   SET @cDeviceID = ''    
  
   SELECT TOP 1 @cDeviceID = DP.DeviceID    
   FROM dbo.DeviceProfile DP WITH (NOLOCK)     
   INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON DP.DeviceID = Loc.Loc    
   WHERE Loc.PutawayZone = @cPutawayZone    
  
   -- Initialize LightModules      
   EXEC [dbo].[isp_DPC_DoMaintenance]       
         @cStorerKey      
        ,@cDeviceID        
        ,@b_Success    OUTPUT        
        ,@nErrNo       OUTPUT      
        ,@cErrMsg      OUTPUT      
                  
   IF @nErrNo = 0       
   BEGIN      
      SET @nErrNo = 91951      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'      
   END      
   ELSE      
   BEGIN      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')       
   END      
END  -- IF @cPTLMTCode = 'SG004'  
ELSE IF @cPTLMTCode = 'SG005' -- Do Initialize    
BEGIN    
   -- Clean Off Active Task    
   DELETE FROM BondDPC.dbo.DPC_JB_Task WITH (ROWLOCK)    
   WHERE Task_Status = 'ACTIVE'    
       
   UPDATE dbo.PTLTran WITH (ROWLOCK)     
   SET Status = '9'     
   WHERE Status IN ('0' , '1')     
       
   UPDATE dbo.PTLTran WITH (ROWLOCK)     
   SET LightSequence = '5'    
   WHERE Remarks = 'HOLD'    
   AND LightSequence <> '5'    
       
   SET @cPutawayZone = @cDeviceID     
   SET @cDeviceID = ''    
  
   SELECT TOP 1 @cDeviceID = DP.DeviceID    
   FROM dbo.DeviceProfile DP WITH (NOLOCK)     
   INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON DP.DeviceID = Loc.Loc    
   WHERE Loc.PutawayZone = @cPutawayZone    
  
   -- Initialize LightModules      
   EXEC [dbo].[isp_DPC_DoInitialize]       
         @cStorerKey      
        ,@cDeviceID        
        ,@b_Success    OUTPUT        
        ,@nErrNo       OUTPUT      
        ,@cErrMsg      OUTPUT      
         
   IF @nErrNo = 0       
   BEGIN      
      SET @nErrNo = 91951      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MaintenanceComplete'      
   END      
   ELSE      
   BEGIN      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')       
   END      
END -- IF @cPTLMTCode = 'SG005'   

  
GOTO QUIT     
       
RollBackTran:    
   ROLLBACK TRAN rdt_814ExtUpdSP01 -- Only rollback change made here    
    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN rdt_814ExtUpdSP01    
    
END 

GO