SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Store procedure: rdt_1036ExtUpdSP01                                  */              
/* Copyright      : IDS                                                 */              
/*                                                                      */              
/* Purpose: ANF Update DropID Logic                                     */              
/*                                                                      */              
/* Modifications log:                                                   */              
/* Date        Rev  Author   Purposes                                   */              
/* 2017-07-11  1.0  ChewKP   Created WMS-2121                           */  
/* 2017-11-23  1.1  ChewKP   WMS-3491 Check WaveKey from                */
/*                           rdt.RdtAssignloc table (ChewKP01)          */
/************************************************************************/              
CREATE PROC [RDT].[rdt_1036ExtUpdSP01] (              
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cCloseToteNo    NVARCHAR( 20) , 
   @cNewToteNo      NVARCHAR( 20) OUTPUT, 
   @cOption         NVARCHAR(1),
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT           
) AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF              
               
   DECLARE  @nCountTask             INT            
           ,@nTranCount             INT            
           ,@cDeviceID              NVARCHAR(10)            
           ,@cWaveKey               NVARCHAR(10)             
           ,@cConsigneeKey          NVARCHAR(30)            
           ,@cDropLoc               NVARCHAR(10)            
           ,@cDeviceProfileKey      NVARCHAR(10)             
           ,@cOrderKey              NVARCHAR(10)         
           ,@cChkStatus             NVARCHAR(5)          
           ,@nTotalPickedQty        INT    
           ,@nTotalPackedQty        INT   
           ,@cNewToteScn            NVARCHAR(1)    
           ,@cDeviceProfileLogKey     NVARCHAR(10)
           
               
   SET @nErrNo   = 0              
   SET @cErrMsg  = ''             
   SET @nCountTask     = 0            
   SET @cNewToteScn = '0'            
   SET @cDeviceID = ''            
   SET @cWaveKey = ''            
   SET @cConsigneeKEy = ''            
   SET @cDropLoc = ''             
   SET @cDeviceProfileKey = ''            
   SET @cOrderKey = ''            
   SET @cChkStatus = ''      
               
   SET @nTranCount = @@TRANCOUNT            
                
   BEGIN TRAN            
   SAVE TRAN rdt_1036ExtUpdSP01            
               
   IF @nFunc = 1036            
   BEGIN               
      IF @nStep = 2             
      BEGIN             
         IF @cOption = '1'            
         BEGIN            
            SET @cDeviceProfileKey = ''    
                
            SELECT TOP 1   --@cDeviceProfileLogKey = DL.DeviceProfileLogKey            
                             @cDeviceID            = DP.DeviceID      
                         --, @cDeviceProfileKey    = DL.DeviceProfileKey         
            FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
            INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
            WHERE DL.DropID = @cCloseToteNo    
            AND DL.Status <> '9'     
            AND DP.Priority = '1'     
                
            SELECT @cConsigneeKey = ConsigneeKey     
            FROM dbo.StoreToLocDetail WITH (NOLOCK)    
            WHERE Loc = @cDeviceID    
            
            -- (ChewKP01) 
--            SELECT TOP 1 @cWaveKey = SourceKey            
--                  --,@cDeviceID = DeviceID            
--                  --,@cConsigneeKey = ConsigneeKey         
--            FROM PTL.PTLTran WITH (NOLOCK)    
--            WHERE ConsigneeKey = @cConsigneeKey      
--            Order By EditDate Desc    
            
            SELECT TOP 1 @cWaveKey = WaveKey            
            FROM RDT.RDTAssignLoc WITH (NOLOCK)    
            Order By EditDate Desc    
                       
                
            SET @nTotalPickedQty = 0    
            SET @nTotalPackedQty = 0    
                
            SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
            FROM dbo.PickDetail PD WITH (NOLOCK)     
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
            WHERE PD.StorerKey = @cStorerKey    
              AND PD.Status    IN ('0', '5' )     
              AND PD.Qty > 0     
              AND O.ConsigneeKey = @cConsigneeKey    
              AND PD.WaveKey = @cWaveKey    
                   
            SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)     
            FROM dbo.PackDetail PackD WITH (NOLOCK)    
            INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo     
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey    
            WHERE O.ConsigneeKey = @cConsigneeKey    
            AND O.UserDefine09 = @cWaveKey    
            
                
            IF @nTotalPickedQty <> @nTotalPackedQty    
            BEGIN    
               SET @cNewToteScn = '1'      
            END       
            
                
            IF @cNewToteScn = '0'    
            BEGIN    
               IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)  
                                 WHERE DropID = @cCloseToteNo            
                                 AND Status = '5'            
                                 AND DropIDType = 'PTS'     )   
               BEGIN                             
                  UPDATE dbo.DropID            
                     SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()            
                  WHERE DropID = @cCloseToteNo            
                  AND Status = '5'            
                  AND DropIDType = 'PTS'            
                                 
                  IF @@ERROR <> 0             
                  BEGIN            
                        SET @nErrNo = 112201            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDropIDFail'            
                        GOTO RollBackTran            
                  END         
               END       

               SELECT TOP 1 @cDeviceProfileKey = DeviceProfileKey            
               FROM dbo.DeviceProfileLog WITH (NOLOCK)    
               WHERE DropID = @cCloseToteNo    
               AND Status <> '9'        
                 
               IF EXISTS ( SELECT 1 FROM  dbo.DeviceProfileLog WITH (NOLOCK)     
                                           WHERE DropID = @cCloseToteNo AND Status <> '9'   )  
               BEGIN  
                  UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)    
                  SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()     
                  WHERE DropID = @cCloseToteNo     
                  
                  IF @@ERROR <> 0             
                  BEGIN            
                      SET @nErrNo = 112202            
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDPLogFail'            
                      GOTO RollBackTran            
                  END        
                  
               END  
                 
                 
               IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)     
                           WHERE DeviceProfileKey = @cDeviceProfileKey AND Status <> '9' )  
               BEGIN              
                  UPDATE dbo.DeviceProfile WITH (ROWLOCK)     
                  SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()   
                  WHERE DeviceProfileKey = @cDeviceProfileKey    
                  AND Status <> '9'    
                      
                  IF @@ERROR <> 0             
                  BEGIN            
                      SET @nErrNo = 112203         
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDeviceProfileFail'            
                      GOTO RollBackTran            
                  END        
               END  
               
            END   
            ELSE
            BEGIN
                SET @cDeviceProfileKey = ''    
                 
                SELECT TOP 1   @cDeviceProfileLogKey = DL.DeviceProfileLogKey            
                             , @cDeviceID            = DP.DeviceID      
                             , @cDeviceProfileKey    = DL.DeviceProfileKey         
                FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
                INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
                WHERE DL.DropID = @cCloseToteNo    
                AND DL.Status <> '9'     
                AND DP.Priority = '1'     
                
                
                            
                -- Insert into LightLoc_Detail Table                
                IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)                
                WHERE DeviceProfileKey = @cDeviceProfileKey                
                               AND DropID = @cNewToteNo                
                               AND Status <> '9' )                 
                BEGIN                
                   INSERT INTO DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey, ConsigneeKey, UserDefine02)                
                   SELECT TOP 1 @cDeviceProfileKey, '', @cNewToteNo, '3' , DeviceProfileLogKey, ConsigneeKey, UserDefine02              
                   FROM dbo.DeviceProfileLog WITH (NOLOCK)               
                   WHERE DropID = @cCloseToteNo            
                   ORDER By EditDate Desc            
                   --AND Status = '3'              
                                
                   IF @@ERROR <> 0                 
                   BEGIN                
                      SET @nErrNo = 112204                
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDPLogFail'           
                      GOTO RollBackTran                
                   END       
                                
                END          
          
                       
                               
               IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)                
                              WHERE DropID = @cNewToteNo )                 
               BEGIN                
                              
                  SELECT @cDropLoc = DropLoc            
                  FROM dbo.DropID WITH (NOLOCK)            
                  WHERE DropID = @cNewToteNo -- Check             
                  AND Status = '9'            
                  Order By EditDate DESC            
                                    
                  INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )               
                  VALUES ( @cNewToteNo, '' , 'PTS', '5' , '' , '' )               
                                
                  IF @@ERROR <> 0                  
                  BEGIN                  
                     SET @nErrNo = 112205                  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'               
                     GOTO RollBackTran                  
                  END                  
               END             
               ELSE     
               BEGIN                
                  UPDATE dbo.DropID    
                  Set Status = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()    
                  WHERE DropID = @cNewToteNo    
               END                            
        
        
               IF EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)              
                           WHERE DeviceID = @cDeviceID            
                           AND CaseID = @cCloseToteNo              
                           AND Status <> '9'       )  
               BEGIN              
                  -- Update PTLTran to New Carton ID -- 
                  DECLARE @nPTLTranKey BIGINT

                  DECLARE CUR_UPDATE_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PTLKey 
                  FROM PTL.PTLTran WITH (NOLOCK)
                  WHERE DeviceID = @cDeviceID            
                  AND CaseID = @cCloseToteNo              
                  AND Status <> '9'
                  
                  OPEN CUR_UPDATE_PTLTRAN 
                  FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey             
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     UPDATE PTL.PTLTran WITH (ROWLOCK)              
                       SET CaseID = @cNewToteNo, 
                           EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE PTLKey = @nPTLTranKey
                                   
                     IF @@ERROR <> 0               
                     BEGIN              
                        SET @nErrNo = 112206       
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLFail'                 
                        GOTO RollBackTran                  
                     END              
                     FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey                
                  END
                  CLOSE CUR_UPDATE_PTLTRAN
                  DEALLOCATE CUR_UPDATE_PTLTRAN                          
               END      
                     
               SELECT @cChkStatus = Status       
               FROM dbo.DeviceProfileLog WITH (NOLOCK)           
               WHERE DeviceProfileKey = @cDeviceProfileKey              
               AND DropID = @cCloseToteNo              
               AND Status <> '9'          
                     
               IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)               
                           WHERE DeviceProfileKey = @cDeviceProfileKey              
                           AND DropID = @cCloseToteNo              
                           AND Status <> '9'  )  
               BEGIN                         
                  -- Update DeviceProfileLog.Status = '9'              
                  UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)               
                  SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()              
                  WHERE DeviceProfileKey = @cDeviceProfileKey              
                  AND DropID = @cCloseToteNo              
                  AND Status <> '9'            
                                
                  IF @@ERROR <> 0               
                  BEGIN                
                     SET @nErrNo = 112207                
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFail'                
                     GOTO RollBackTran                
                  END              
               END 
               
               -- (ChewKP01) 
               IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey 
                           AND LabelNo = @cCloseToteNo 
                           AND Status <> '9' )
               BEGIN
                   -- Update rdt.rdtPTSLog to New Carton ID -- 
                  DECLARE @nPTSLogKey BIGINT

                  DECLARE CUR_UPDATE_rdtPTSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PTSLogKey
                  FROM rdt.rdtPTSLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey       
                  AND LabelNo = @cCloseToteNo      
                  AND Status <> '9'
                  
                  OPEN CUR_UPDATE_rdtPTSLog 
                  FETCH NEXT FROM CUR_UPDATE_rdtPTSLog INTO @nPTSLogKey             
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     UPDATE rdt.rdtPTSLog WITH (ROWLOCK)              
                       SET LabelNo = @cNewToteNo
                           --EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE PTSLogKey = @nPTSLogKey         
                                   
                     IF @@ERROR <> 0               
                     BEGIN              
                        SET @nErrNo = 112208       
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTSLogFail'                 
                        GOTO RollBackTran                  
                     END              
                     FETCH NEXT FROM CUR_UPDATE_rdtPTSLog INTO @nPTSLogKey                
                  END
                  CLOSE CUR_UPDATE_rdtPTSLog
                  DEALLOCATE CUR_UPDATE_rdtPTSLog         
                  
               END   
               
               IF EXISTS ( SELECT 1 FROM  dbo.DeviceProfileLog WITH (NOLOCK)     
                                              WHERE DropID = @cCloseToteNo AND Status <> '9'   )  
               BEGIN  
                     UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)    
                     SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()     
                     WHERE DropID = @cCloseToteNo     
                         
                     IF @@ERROR <> 0             
                     BEGIN            
                         SET @nErrNo = 91710            
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDPLogFail'            
                         GOTO RollBackTran            
                     END        
               END          
               
               IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)  
                                 WHERE DropID = @cCloseToteNo            
                                 AND Status = '5'            
                                 AND DropIDType = 'PTS'     )   
               BEGIN                             
                  UPDATE dbo.DropID            
                     SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()            
                  WHERE DropID = @cCloseToteNo            
                  AND Status = '5'            
                  AND DropIDType = 'PTS'            
                              
                  IF @@ERROR <> 0             
                  BEGIN            
                      SET @nErrNo = 112209            
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDropIDFail'            
                      GOTO RollBackTran            
                  END     
               END      

            END
             
         END            
      END            
      
       
   END            
            
   GOTO QUIT            
                
            
   RollBackTran:            
   ROLLBACK TRAN rdt_1036ExtUpdSP01        
                
   Quit:            
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started            
          COMMIT TRAN rdt_1036ExtUpdSP01            
               
              
Fail:              
END 




GO