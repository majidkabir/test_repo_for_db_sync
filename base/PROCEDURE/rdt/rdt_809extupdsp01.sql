SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_809ExtUpdSP01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Unity PTL Logic                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-08-07  1.0  ChewKP   Created                                    */    
/* 2014-12-24  1.1  Shong    Change Error Message  (SHONG01)            */
/* 2016-03-03  1.2  ChewKP   Enhancement                                */
/* 2016-08-24  1.4  ChewKP   Add Traceinfo for Reset (ChewKP01)         */
/* 2017-11-28  1.5  ChewKP   WMS-3491, extend SKU to 8 char (ChewKP02)  */
/************************************************************************/    
CREATE PROC [RDT].[rdt_809ExtUpdSP01] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode   NVARCHAR( 3),    
   @cUserName   NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cStorerKey  NVARCHAR( 15),    
   @cDROPID     NVARCHAR( 20),    
   @nStep       INT,  
   @cPTSZone    NVARCHAR(10), 
   @cOption     NVARCHAR(1), 
   @cSuggLoc    NVARCHAR(10)     OUTPUT,  
   @cLightModeColor NVARCHAR(10) OUTPUT,  
   @nErrNo      INT              OUTPUT,    
   @cErrMsg     NVARCHAR( 20)    OUTPUT  -- screen limitation, 20 char max    
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
          ,@cDeviceID            NVARCHAR(20)   
          ,@cSuggPosition        NVARCHAR(10)  
          ,@cIPAddress           NVARCHAR(40)  
          ,@nCount               INT
          ,@cSKU                 NVARCHAR(20) 
          ,@cResetDevicePosition NVARCHAR(10)
          ,@cNextResetDevicePosition NVARCHAR(10) 
          ,@cStatus              NVARCHAR(5) 

   SET @cResetDevicePosition  = ''
   SET @cNextResetDevicePosition = ''
   SET @cSKU                  = ''
   SET @nCount                = 0   
   SET @nErrNo                = 0    
   SET @cErrMsg               = ''   
   SET @cDeviceProfileLogKey  = ''  
   SET @cLightMode            = ''  
   SET @cDeviceProfileKey     = ''  
   SET @nPTLKey               = 0  
   SET @cDevicePosition       = ''  
   SET @cSuggSKU              = ''  
   SET @cDisplayValue         = ''  
   SET @cUOM                  = ''  
   SET @cDeviceID             = ''  
   SET @cSuggPosition         = ''  
   SET @cIPAddress            = ''  
   SET @nPTLKey               = 0   
     
  
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_809ExtUpdSP01  
  
  
   IF EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)   
                   WHERE AddWho = @cUserName  
                   AND DeviceProfileLogKey = ''   
                   AND Status = '0' )   
   BEGIN  
      EXECUTE nspg_getkey  
              'DeviceProfileLogKey'  
              , 10  
              , @cDeviceProfileLogKey OUTPUT  
              , @b_success OUTPUT  
              , @nErrNo OUTPUT  
              , @cErrMsg OUTPUT  
                
        
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 91301  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetKeyFail'  
       GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT @cDeviceProfileLogKey = DeviceProfileLogKey   
      FROM PTL.PTLTran WITH (NOLOCK)   
      WHERE AddWho = @cUserName  
       --AND Status = '0'  
      AND STATUS IN ( '0', '1' ) 
      ORDER BY DeviceProfilelogKey Desc
      
   END  
  
  
  
     
   DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
     
  
   SELECT DISTINCT -- D.DeviceProfileKey  
          --,DL.DropID  
             PTL.PTLKey  
            ,PTL.DeviceID  
   FROM PTL.PTLTran PTL WITH (NOLOCK)  
   --INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = PTL.DeviceID  
   --INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK ) ON DL.DeviceProfileKey = D.DeviceProfileKey   
   WHERE --DL.Status                  = '1'  
         --D.Status               = '0'  
         PTL.Status             = '0'  
         AND PTL.AddWho             = @cUserName  
         AND PTL.DeviceProfileLogKey = ''  
   ORDER BY PTL.PTLKey  
     
     
   OPEN CursorPTLTran              
     
   FETCH NEXT FROM CursorPTLTran INTO @nPTLKey, @cDeviceID  
     
     
   WHILE @@FETCH_STATUS <> -1       
   BEGIN  
  
        
      UPDATE PTL.PTLTran WITH (ROWLOCK)  
      SET DeviceProfileLogKey = @cDeviceProfileLogKey  
      WHERE PTLKey = @nPTLKey  
      AND Status = '0'  
      AND AddWho = @cUserName  
        
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 91303  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLFail'  
       GOTO RollBackTran  
      END  
  
--      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)  
--                  WHERE DeviceID = @cDeviceID   
--                  AND Status IN ( '1', '0' )  
--                  AND DeviceType = 'LOC'  )   
--      BEGIN  
--            UPDATE dbo.DeviceProfile WITH (ROWLOCK)  
--            SET DeviceProfileLogKey = @cDeviceProfileLogKey  
--               ,Status = '3'  
--            WHERE DeviceID = @cDeviceID  
--            AND Status IN ( '1', '0' )  
--              
--            IF @@ERROR <> 0   
--            BEGIN  
--               SET @nErrNo = 91305  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceFail'  
--             GOTO RollBackTran  
--            END  
--      END  
  
        
        
        
      FETCH NEXT FROM CursorPTLTran INTO  @nPTLKey, @cDeviceID  
   END  
   CLOSE CursorPTLTran              
   DEALLOCATE CursorPTLTran     
   
     
        
  
   DECLARE CursorDeviceProfile CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
     
   SELECT DISTINCT D.DeviceProfileKey  
   FROM dbo.DeviceProfileLog DL WITH (NOLOCK)  
   INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey  
   INNER JOIN PTL.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID  
   WHERE D.Status                    = '3'  
         --AND D.DeviceProfileLogKey   = @cDeviceProfileLogKey  
         AND PTL.Status              = '0'  
         AND DL.Status               = '1'  
         AND DL.DeviceProfileLogKey  = ''  
   ORDER BY D.DeviceProfileKey  
     
     
   OPEN CursorDeviceProfile              
     
   FETCH NEXT FROM CursorDeviceProfile INTO @cDeviceProfileKey  
     
     
   WHILE @@FETCH_STATUS <> -1       
   BEGIN  
         UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)  
         SET DeviceProfileLogKey = @cDeviceProfileLogKey  
            ,Status = '3'  
         WHERE DeviceProfileKey = @cDeviceProfileKey  
         AND Status = '1'  
           
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 91302  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceFail'  
          GOTO RollBackTran  
         END  
  
         FETCH NEXT FROM CursorDeviceProfile INTO @cDeviceProfileKey  
  
   END  
   CLOSE CursorDeviceProfile              
   DEALLOCATE CursorDeviceProfile     
  
   IF @cOption = '5' 
   BEGIN 
     
     IF EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK) 
                 WHERE AddWho = @cUserName 
                 AND Status = '1' ) 
     BEGIN 
   
         SELECT @nCount = Count(PTLKey) 
         FROM PTL.PTLTran WITH (NOLOCK) 
         WHERE AddWho = @cUserName 
         AND Status = '1' 
         
         
         SELECT @cSKU = SKU
               ,@cDeviceID = DeviceID  
         FROM PTL.PTLTran WITH (NOLOCK) 
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND AddWho = @cUserName 
         AND Status = '1' 

         -- (ChewKP01) 
         --INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
         --VALUES ( 'rdt_809ExtUpdSP01' , Getdate() , 'ResetData', '0', @cUserName, @cDeviceID, @cSKU, @nPTLKey, @cStatus , @nCount , '' ,'' ) 

         
         IF @nCount = 2 
         BEGIN       
            DECLARE CursorPTLReset CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
        
            SELECT PTLKey, Status 
            FROM PTL.PTLTran WITH (NOLOCK) 
            WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
            AND AddWho = @cUserName 
            AND SKU = @cSKU 
            AND DeviceID = @cDeviceID
            AND Status = '1' 
                         
            OPEN CursorPTLReset              
            
            FETCH NEXT FROM CursorPTLReset INTO @nPTLKey, @cStatus 
            
            WHILE @@FETCH_STATUS <> -1       
            BEGIN 
               
                -- (ChewKP01) 
               --INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
               --VALUES ( 'rdt_809ExtUpdSP01' , Getdate() , 'ResetData', '1', @cUserName, @cDeviceID, @cSKU, @nPTLKey, @cStatus , '' , '' ,'' ) 
               
               
               UPDATE PTL.PTLTRAN WITH (ROWLOCK) 
               SET  Status = '0' 
                  , LightSequence = CASE WHEN LightSequence <> '1' THEN '1' ELSE LightSequence END
               WHERE PTLKey = @nPTLKey 
               
               IF @@ERROR <> 0 
               BEGIN 
                  SET @nErrNo = 91312  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
                  GOTO RollBackTran  
               END
               
             
                  
               FETCH NEXT FROM CursorPTLReset INTO @nPTLKey, @cStatus 
               
            END
            CLOSE CursorPTLReset              
            DEALLOCATE CursorPTLReset    
         END
         ELSE IF @nCount = 1 
         BEGIN 


            SET @nPTLKey = 0 
            
            
            SELECT @nPTLKey = PTLKey 
                  ,@cResetDevicePosition = DevicePosition 
                  ,@cStatus = Status -- (ChewKP01) 
            FROM PTL.PTLTran WITH (NOLOCK) 
            WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
            AND AddWho = @cUserName 
            AND SKU = @cSKU 
            AND DeviceID = @cDeviceID
            AND Status = '1' -- (ChewKP01) 
            
            
            -- (ChewKP01) 
            --INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
            --VALUES ( 'rdt_809ExtUpdSP01' , Getdate() , 'ResetData', '2', @cUserName, @cDeviceID, @cSKU, @nPTLKey, @cStatus , '' , '' ,'' ) 
            
            UPDATE PTL.PTLTRAN WITH (ROWLOCK) 
               SET  Status = '0' 
                  , LightSequence = CASE WHEN LightSequence <> '1' THEN '1' ELSE LightSequence END
            WHERE PTLKey = @nPTLKey 
            
            IF @@ERROR <> 0 
            BEGIN 
               SET @nErrNo = 91313  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
               GOTO RollBackTran  
            END
            
            SELECT @cNextResetDevicePosition = DevicePosition 
            FROM dbo.DeviceProfile WITH (NOLOCK) 
            WHERE DeviceID = @cDeviceID
            AND DevicePosition <> @cResetDevicePosition
            
            SET @nPTLKey = 0 
            
            SELECT TOP 1 @nPTLKey = PTLKey 
                  ,@cResetDevicePosition = DevicePosition 
            FROM PTL.PTLTran WITH (NOLOCK) 
            WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
            AND AddWho = @cUserName 
            AND SKU = @cSKU 
            AND DeviceID = @cDeviceID
            AND DevicePosition = @cNextResetDevicePosition
            ORDER BY PTLKey
            
            UPDATE PTL.PTLTRAN WITH (ROWLOCK) 
               SET  Status = '0' 
                  , LightSequence = CASE WHEN LightSequence <> '1' THEN '1' ELSE LightSequence END
            WHERE PTLKey = @nPTLKey 
            
            IF @@ERROR <> 0 
            BEGIN 
               SET @nErrNo = 91314
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
               GOTO RollBackTran  
            END
            
            
            
         END
         
         DELETE FROM dbo.PTLLOCKLOC WITH (ROWLOCK) 
         WHERE AddWho = @cUserName
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 91316  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
            GOTO RollBackTran  
         END
                 
         
     END
     ELSE 
     BEGIN
         
         -- (ChewKP01) 
         --INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
         --VALUES ( 'rdt_809ExtUpdSP01' , Getdate() , 'ResetData', '4', @cUserName, @cDeviceID, '', '', '' , '' , '' ,'' ) 
         
         DELETE FROM dbo.PTLLOCKLOC WITH (ROWLOCK) 
         WHERE AddWho = @cUserName
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 91317  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLLOCKLOCFail'  
            GOTO RollBackTran  
         END
     END
      
   END     
   ELSE
   BEGIN
      
      
      IF EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)  
                  WHERE Status = '1' 
                  AND AddWho = @cUserName )   
      BEGIN  
         SET @nErrNo = 91315  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UserIDInUsed'  
         GOTO RollBackTran      
      END  

      
   END

    

     
   SELECT TOP 1 --@cSuggLoc   = D.DeviceID  
                @nPTLKey    = PTL.PTLKey  
                 
               ,@cLightMode = PTL.LightMode  
               ,@cSuggSKU   = PTL.SKU  
               ,@cUOM       = PTL.UOM  
               ,@cSuggPosition = PTL.DevicePosition   
               ,@cIPAddress = PTL.IPAddress  
   FROM PTL.PTLTran PTL WITH (NOLOCK)  
   INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID  
   WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey  
   AND D.Priority = '1'   
   AND PTL.Status = '0'  
   Order by D.DeviceID, PTL.SKU  
     
   SELECT Top 1 @cSuggLoc      = DeviceID  
   FROM dbo.DeviceProfile WITH (NOLOCK)  
   WHERE DevicePosition = @cSuggPosition   
   AND StorerKey = @cStorerKey   
   --AND Priority = '1'  
   AND IPAddress = @cIPAddress  
  
   SELECT Top 1 @cSuggPosition      = DevicePosition   
   FROM dbo.DeviceProfile WITH (NOLOCK)  
   WHERE DeviceID = @cSuggLoc   
   AND StorerKey = @cStorerKey   
   AND Priority = '1'  
   AND IPAddress = @cIPAddress  
  
   --INSERT INTO TRACEINFO (traceNAme , TimeIN, col1 ,col2 , col3 )   
   --VALUES ( 'PTSCarton' , Getdate(), @cSuggPosition , @cSuggLoc , @cStorerKey )   
   
  
     
   --WAITFOR DELAY '00:00:02'  -- Delay 15 seconds before checking    
     
   EXEC [dbo].[isp_LightUpLocCheck]   
               @nPTLKey                = @nPTLKey                
              ,@cStorerKey             = @cStorerKey             
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey   
              ,@cLoc                   = @cSuggLoc                   
              ,@cType                  = 'LOCK'                  
              ,@nErrNo                 = @nErrNo               OUTPUT  
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
     
   IF @nErrNo <> 0   
   BEGIN  
      SET @nErrNo = 91309  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1stLocInUse'  
      SET @cErrMsg = REPLACE(@cErrMsg, '1st', ISNULL(LEFT(RTRIM(@cSuggLoc), 3) + ' ', '1st')) -- SHONG01            
      GOTO RollBackTran  
   END  
  
     
   IF EXISTS (SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)  
              WHERE StorerKey = @cStorerKey  
              AND DeviceID = @cSuggLoc  
              AND Status = '1'   
              AND AddWho <> @cUserName  
              AND IPAddress = @cIPAddress )   
   BEGIN  
      SET @nErrNo = 91310  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1stLocInUse'  
      
      SET @cErrMsg = REPLACE(@cErrMsg, '1st', ISNULL(LEFT(RTRIM(@cSuggLoc), 3) + ' ', '1st')) -- SHONG01
      
      GOTO RollBackTran  
   END  
     
   --WAITFOR DELAY '00:00:02'  -- Delay 15 seconds before checking    
     
   IF EXISTS (SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)  
              WHERE StorerKey = @cStorerKey  
              AND DeviceID = @cSuggLoc  
              AND Status = '1'  )   
   BEGIN  
      SET @nErrNo = 91306  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1stLocInUse'  
      SET @cErrMsg = REPLACE(@cErrMsg, '1st', ISNULL(LEFT(RTRIM(@cSuggLoc), 3) + ' ', '1st')) -- SHONG01
      GOTO RollBackTran  
   END  
     
     
--   IF EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)   
--               WHERE DevicePosition = @cSuggPosition   
--               AND Remarks = 'HOLD'  
--               AND LightSequence = '0'  
--               AND IPAddress = @cIPAddress )   
--   BEGIN  
--      SET @nErrNo = 91307  
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1stLocInUse'  
--      SET @cErrMsg = REPLACE(@cErrMsg, '1st', ISNULL(LEFT(RTRIM(@cSuggLoc), 3) + ' ', '1st')) -- SHONG01
--      GOTO RollBackTran  
--   END       
  
   IF EXISTS (SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)  
              WHERE StorerKey = @cStorerKey  
              AND DevicePosition = @cSuggPosition  
              AND Status = '1'   
              AND AddWho <> @cUserName  
              AND IPAddress = @cIPAddress )   
   BEGIN  
      SET @nErrNo = 91308  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'1stLocInUse'  
      SET @cErrMsg = REPLACE(@cErrMsg, '1st', ISNULL(LEFT(RTRIM(@cSuggLoc), 3) + ' ', '1st')) -- SHONG01
      GOTO RollBackTran  
   END  
     
--   IF EXISTS ( SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)  
--               WHERE StorerKey = @cStorerKey  
--               AND Remarks = 'HOLD'  
--               AND AddWho = @cUserName   
--               AND LightSequence = '0' )   
--   BEGIN  
--      SET @nErrNo = 91311  
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UserOnHold'  
--      GOTO RollBackTran  
--   END                 
     
   SELECT @cLightModeColor = Code   
   FROM dbo.CodeLkup WITH (NOLOCK)   
   WHERE ListName = 'LiGHTMODE'  
   AND Short = @cLightMode   
   AND Code <> 'White'  
  
  
     
   -- Start to Light Up First Location --   
   DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
     
   SELECT PTLKey, DevicePosition, LightMode  
   FROM PTL.PTLTran PTL WITH (NOLOCK)  
   WHERE Status             = '0'  
     AND AddWho             = @cUserName  
     AND DeviceID           = @cSuggLoc     
     AND SKU                = @cSuggSKU  
     AND UOM                = @cUOM  
     AND DeviceProfileLogKey = @cDeviceProfileLogKey  
     AND IPAddress = @cIPAddress  
   ORDER BY DeviceID, PTLKey  
     
   OPEN CursorLightUp              
     
   FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode  
     
     
   WHILE @@FETCH_STATUS <> -1       
   BEGIN  
        
        
        
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)  
                  WHERE DeviceID = @cSuggLoc  
                  AND DevicePosition = @cDevicePosition  
                  AND Priority = '0'  
                  AND IPAddress = @cIPAddress )   
      BEGIN  
         --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) )  -- (ChewKP02) 
         SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 3 ) )  
      END                    
      ELSE  
      BEGIN  
         --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) )  -- (ChewKP02) 
         SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 4 , 5 ) )  
      END  
        
--      EXEC [dbo].[isp_DPC_LightUpLoc]   
--            @c_StorerKey = @cStorerKey   
--           ,@n_PTLKey    = @nPTLKey      
--           ,@c_DeviceID  = @cSuggLoc    
--           ,@c_DevicePos = @cDevicePosition   
--           ,@n_LModMode  = @cLightMode    
--           ,@n_Qty       = @cDisplayValue         
--           ,@b_Success   = @b_Success   OUTPUT    
--           ,@n_Err       = @nErrNo      OUTPUT  
--           ,@c_ErrMsg    = @cErrMsg     OUTPUT   

      
      EXEC [ptl].[isp_PTL_LightUpLoc]
               @n_Func         = @nFunc 
              ,@n_PTLKey       = @nPTLKey  
              ,@c_DisplayValue = @cDisplayValue  
              ,@b_Success      = @b_success   OUTPUT  
              ,@n_Err          = @nErrNo      OUTPUT  
              ,@c_ErrMsg       = @cErrMsg     OUTPUT  
              ,@c_ForceColor   = '' --@c_ForceColor  
  
      IF @@ERROR <> 0   
      BEGIN  
            
            SET @nErrNo = 91304  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'  
            --SET @cERRMSG = @nPTLKey
          GOTO RollBackTran  
      END  
             
      -- (ChewKP01) 
      --INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
      --VALUES ( 'rdt_809ExtUpdSP01' , Getdate() , 'LightUpData', '3', @cUserName, @cSuggLoc, @cDevicePosition, @nPTLKey, @cDeviceProfileLogKey, @cSuggSKU, '' , ''   )    

   
      FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition, @cLightMode  
   END  
   CLOSE CursorLightUp              
   DEALLOCATE CursorLightUp     
  
     
     
  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_809ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_809ExtUpdSP01  
    
  
END      

GO