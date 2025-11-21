SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Store procedure: rdt_1805ExtUpdSP01                                  */              
/* Copyright      : IDS                                                 */              
/*                                                                      */              
/* Purpose: ANF Update DropID Logic                                     */              
/*                                                                      */              
/* Modifications log:                                                   */              
/* Date        Rev  Author   Purposes                                   */              
/* 2014-08-28  1.0  ChewKP   Created                                    */  
/* 2014-12-05  1.1  TLTING   Performance Tune                           */
/* 2015-03-24  1.2  SHONG    Performance Tuning                         */   
/* 2016-03-03  1.3  ChewKP   Enhancement                                */         
/* 2016-10-07  1.4  ChewKP   WMS-488 - Update rdt.rdtPTSLog (ChewKP01)  */  
/************************************************************************/              
CREATE PROC [RDT].[rdt_1805ExtUpdSP01] (              
   @nMobile     INT,              
   @nFunc       INT,              
   @cLangCode   NVARCHAR( 3),              
   @cUserName   NVARCHAR( 15),              
   @cFacility   NVARCHAR( 5),              
   @cStorerKey  NVARCHAR( 15),              
   @nStep       INT,            
   @cDROPID     NVARCHAR( 20),              
   @cOption     NVARCHAR(1),             
   @cNewToteNo  NVARCHAR(20),            
   @cNewToteScn NVARCHAR(1) OUTPUT,            
   @cDeviceProfileLogKey NVARCHAR(10) OUTPUT,             
   @nErrNo      INT OUTPUT,              
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max              
) AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF              
               
   DECLARE  @nCountTask INT            
           ,@nTranCount INT            
           ,@cDeviceID  NVARCHAR(10)            
           ,@cWaveKey   NVARCHAR(10)             
           ,@cConsigneeKey NVARCHAR(30)            
           ,@cDropLoc   NVARCHAR(10)            
           ,@cDeviceProfileKey NVARCHAR(10)             
           ,@cOrderKey  NVARCHAR(10)         
           ,@cChkStatus NVARCHAR(5)          
           ,@nTotalPickedQty INT    
           ,@nTotalPackedQty INT     
               
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
   SAVE TRAN PTSUpdate            
               
   IF @nFunc = 1805            
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
            WHERE DL.DropID = @cDropID    
            AND DL.Status <> '9'     
            AND DP.Priority = '1'     
                
            SELECT @cConsigneeKey = ConsigneeKey     
            FROM dbo.StoreToLocDetail WITH (NOLOCK)    
            WHERE Loc = @cDeviceID    
                        
            SELECT TOP 1 @cWaveKey = SourceKey            
                  --,@cDeviceID = DeviceID            
                  --,@cConsigneeKey = ConsigneeKey         
            FROM PTL.PTLTran WITH (NOLOCK)    
            WHERE ConsigneeKey = @cConsigneeKey      
            Order By EditDate Desc    
                
            --FROM dbo.Orders WITH (NOLOCK)             
            --WHERE OrderKey = @cOrderKey             
                        
--            SELECT @nCountTask = Count(Distinct PD.PickDetailKey)             
--            FROM dbo.PickDetail PD WITH (NOLOCK)             
--            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey            
--            INNER JOIN dbo.WaveDetail WD WITH (NOLOCK) ON WD.OrderKey = O.OrderKey            
--            INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKey = O.ConsigneeKey            
--            WHERE WD.WaveKEy = @cWaveKey            
--            AND PD.CaseID = ''            
--            AND PD.Qty > 0     
--            AND PD.StorerKey = @cStorerKey            
--            AND O.ConsigneeKey = @cConsigneeKey            
                
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
            
            
                        
            IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)  
                              WHERE DropID = @cDropID            
                              AND Status = '5'            
                              AND DropIDType = 'PTS'     )   
            BEGIN                             
               UPDATE dbo.DropID            
                  SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()            
               WHERE DropID = @cDropID            
               AND Status = '5'            
               AND DropIDType = 'PTS'            
                           
               IF @@ERROR <> 0             
               BEGIN            
                   SET @nErrNo = 91701            
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDropIDFail'            
                   GOTO RollBackTran            
               END         
            END       
                
            IF @cNewToteScn = '0'    
            BEGIN    
               SELECT TOP 1 @cDeviceProfileKey = DeviceProfileKey            
               FROM dbo.DeviceProfileLog WITH (NOLOCK)    
               WHERE DropID = @cDropID    
               AND Status <> '9'        
                 
               IF EXISTS ( SELECT 1 FROM  dbo.DeviceProfileLog WITH (NOLOCK)     
                                           WHERE DropID = @cDropID AND Status <> '9'   )  
               BEGIN  
                  UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)    
                  SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()     
                  WHERE DropID = @cDropID     
                      
                  IF @@ERROR <> 0             
                  BEGIN            
                      SET @nErrNo = 91710            
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
                      SET @nErrNo = 91711         
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdDeviceProfileFail'            
                      GOTO RollBackTran            
                  END        
               END    
            END    
         END            
      END            
                  
      IF @nStep = 3            
      BEGIN            
--          SELECT TOP 1 @cDeviceProfileLogKey = DeviceProfileLogKey            
--                     , @cDeviceID            = DeviceID            
--          FROM dbo.PTLTran WITH (NOLOCK)             
--          WHERE CaseID = @cDropID             
--          ORDER BY Editdate DESC         
          SET @cDeviceProfileKey = ''    
              
          SELECT TOP 1   @cDeviceProfileLogKey = DL.DeviceProfileLogKey            
                       , @cDeviceID            = DP.DeviceID      
                       , @cDeviceProfileKey    = DL.DeviceProfileKey         
          FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
          INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
          WHERE DL.DropID = @cDropID    
          AND DL.Status <> '9'     
          AND DP.Priority = '1'     
              
--          SELECT @cDeviceProfileKey = DeviceProfileKey            
--          FROM dbo.DeviceProfile WITH (NOLOCK)            
--          WHERE DeviceID = @cDeviceID            
--          AND StorerKey = @cStorerKey            
--          AND Priority = '1'            
    
          IF ISNULL(RTRIM(@cDeviceProfileKey),'') = ''    
          BEGIN    
             SET @nErrNo = 91712                
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDPKey'             
             GOTO RollBackTran       
          END    
              
              
          IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                      WHERE DropID = @cNewToteNo    
                      AND Status <> '9' )     
          BEGIN    
             SET @nErrNo = 91709                
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'             
             GOTO RollBackTran        
          END     
                      
          -- Insert into LightLoc_Detail Table                
          IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)                
          WHERE DeviceProfileKey = @cDeviceProfileKey                
                         AND DropID = @cNewToteNo                
                         AND Status <> '9' )                 
          BEGIN                
             INSERT INTO DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey, ConsigneeKey, UserDefine02)                
             SELECT TOP 1 @cDeviceProfileKey, '', @cNewToteNo, '3' , DeviceProfileLogKey, ConsigneeKey, UserDefine02              
             FROM dbo.DeviceProfileLog WITH (NOLOCK)               
             WHERE DropID = @cDropID            
             ORDER By EditDate Desc            
             --AND Status = '3'              
                          
             IF @@ERROR <> 0                 
             BEGIN                
                SET @nErrNo = 91703                
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDPLogFail'           
                GOTO RollBackTran                
             END       
                          
          END          
--          ELSE     
--          BEGIN    
--            UPDATE Dbo.DeviceProfileLog    
--            SET Status = '3'    
--            WHERE DeviceProfileKey = @cDeviceProfileKey    
--            AND DropID = @cNewToteNo       
--          END      
                 
                         
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)                
                        WHERE DropID = @cNewToteNo )                 
         BEGIN                
                        
            SELECT @cDropLoc = DropLoc            
            FROM dbo.DropID WITH (NOLOCK)            
            WHERE DropID = @cDropID             
            AND Status = '9'            
            Order By EditDate DESC            
                              
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )               
            VALUES ( @cNewToteNo, '' , 'PTS', '5' , '' , '' )               
                          
            IF @@ERROR <> 0                  
            BEGIN                  
               SET @nErrNo = 91704                  
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
                     AND CaseID = @cDropID              
                     AND Status <> '9'       )  
         BEGIN              
            -- Update PTLTran to New Carton ID -- 
            DECLARE @nPTLTranKey BIGINT

            DECLARE CUR_UPDATE_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey 
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DeviceID = @cDeviceID            
            AND CaseID = @cDropID              
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
                  SET @nErrNo = 91702       
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
         AND DropID = @cDropID              
         AND Status <> '9'          
               
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)               
                     WHERE DeviceProfileKey = @cDeviceProfileKey              
                     AND DropID = @cDropID              
                     AND Status <> '9'  )  
         BEGIN                         
            -- Update DeviceProfileLog.Status = '9'              
            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)               
            SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()              
            WHERE DeviceProfileKey = @cDeviceProfileKey              
            AND DropID = @cDropID              
            AND Status <> '9'            
                          
            IF @@ERROR <> 0               
            BEGIN                
               SET @nErrNo = 91705                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFail'                
               GOTO RollBackTran                
            END              
         END 
         
         -- (ChewKP01) 
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                     AND LabelNo = @cDropID 
                     AND Status <> '9' )
         BEGIN
             -- Update rdt.rdtPTSLog to New Carton ID -- 
            DECLARE @nPTSLogKey BIGINT

            DECLARE CUR_UPDATE_rdtPTSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTSLogKey
            FROM rdt.rdtPTSLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey       
            AND LabelNo = @cDropID      
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
                  SET @nErrNo = 91713       
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTSLogFail'                 
                  GOTO RollBackTran                  
               END              
               FETCH NEXT FROM CUR_UPDATE_rdtPTSLog INTO @nPTSLogKey                
            END
            CLOSE CUR_UPDATE_rdtPTSLog
            DEALLOCATE CUR_UPDATE_rdtPTSLog         
            
         END           
         
      END            
   END            
            
   GOTO QUIT            
                
            
   RollBackTran:            
   ROLLBACK TRAN PTSUpdate        
                
   Quit:            
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started            
          COMMIT TRAN PTSUpdate            
               
              
Fail:              
END 




GO