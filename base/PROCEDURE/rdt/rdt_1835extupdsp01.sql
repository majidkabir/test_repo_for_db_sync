SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
             
                          
/************************************************************************/                              
/* Store procedure: rdt_1835ExtUpdSP01                                  */                              
/* Copyright      : LF                                                  */                              
/*                                                                      */                              
/* Purpose: THG PTL Logic                                               */                              
/*                                                                      */                              
/* Modifications log:                                                   */                              
/* Date        Rev  Author   Purposes                                   */                              
/* 2019-06-18 1.0  YeeKung   WMS-10050 Created                          */                               
/************************************************************************/                              
CREATE PROC [RDT].[rdt_1835ExtUpdSP01] (                              
   @nMobile          INT,                              
   @nFunc            INT,                              
   @cLangCode        NVARCHAR( 3),                              
   @cUserName        NVARCHAR( 15),                              
   @cFacility        NVARCHAR( 5),                              
   @cStorerKey       NVARCHAR( 15),                              
   @cWaveKey         NVARCHAR( 20),                              
   @nStep            INT,                        
   @cDevID           NVARCHAR( 20),                              
   @cPTSZone         NVARCHAR(10),                           
   @cOption          NVARCHAR(1),                           
   @cSuggLoc         NVARCHAR(10)     OUTPUT,                            
   @cSuggTote        NVARCHAR(10)     OUTPUT,   
   @cSuggSKU         NVARCHAR(20)     OUTPUT,   
   @cSuggSKUDesc1    NVARCHAR(20)     OUTPUT,   
   @cSuggSKUDesc2    NVARCHAR(20)     OUTPUT,  
   @cSuggSKUDesc3    NVARCHAR(20)     OUTPUT,  
   @cSuggQty         NVARCHAR(5)      OUTPUT,  
   @cEndRemark       NVARCHAR(10)      OUTPUT,               
   @nErrNo           INT              OUTPUT,                              
   @cErrMsg          NVARCHAR( 20)    OUTPUT  -- screen limitation, 20 char max                              
) AS                              
BEGIN                              
   SET NOCOUNT ON                              
   SET ANSI_NULLS OFF                              
   SET QUOTED_IDENTIFIER OFF                              
   SET CONCAT_NULL_YIELDS_NULL OFF                              
                               
   DECLARE @cDeviceProfileLogKey       NVARCHAR(10)                                       
          ,@nTranCount                 INT                            
          ,@b_success                  INT                            
          ,@cDeviceProfileKey          NVARCHAR(10)                            
          ,@nPTLKey                    INT                            
          ,@cDevicePosition            NVARCHAR(10)                                          
          ,@cDisplayValue              NVARCHAR(5)                            
          ,@cUOM                       NVARCHAR(10)                      
          ,@cPrefUOM                   NVARCHAR(10)                            
          ,@cDeviceID                  NVARCHAR(20)                             
          ,@cSuggPosition              NVARCHAR(10)                            
          ,@cIPAddress                 NVARCHAR(40)                            
          ,@nCount                     INT                          
          ,@cSKU                       NVARCHAR(20)                           
          ,@cResetDevicePosition       NVARCHAR(10)                          
          ,@cNextResetDevicePosition   NVARCHAR(10)                           
          ,@cStatus                    NVARCHAR(5)                        
          ,@cQty                       INT              
          ,@cRemark                    NVARCHAR(2)            
          ,@cDropid                    NVARCHAR(20)  
          ,@cLoc                       NVARCHAR(10)  
          ,@cOrderKey                  NVARCHAR(20)  
          ,@cPickDetailKey             NVARCHAR(10)  
          ,@cLabelNo                   NVARCHAR(20)  
          ,@cCaseID                    NVARCHAR(20)  
          ,@nPDQty                     INT  
          ,@cPDOrderKey                NVARCHAR(20)  
          ,@nNewExpectedQty            INT  
          ,@nNewPTLKey                 NVARCHAR(20)  
          ,@cSuggUOM                   NVARCHAR(6)  
          ,@cSuggDropID                NVARCHAR(10)  
  
   SET @cResetDevicePosition     = ''                
   SET @cNextResetDevicePosition = ''                          
   SET @cSKU                     = ''           
   SET @nCount                   = 0                             
   SET @nErrNo                   = 0                              
   SET @cErrMsg                  = ''                             
   SET @cDeviceProfileLogKey     = ''                                                
   SET @cDeviceProfileKey        = ''                            
   SET @nPTLKey                  = 0              
   SET @cDevicePosition          = ''                            
   SET @cSuggSKU                 = ''                            
   SET @cDisplayValue            = ''                      
   SET @cPrefUOM                 = ''                          
   SET @cUOM                     = ''                            
   SET @cDeviceID                = ''                            
   SET @cSuggPosition            = ''                            
   SET @cIPAddress               = ''                         
   SET @nPTLKey                  = 0                         
   SET @cQty                     = 0             
   SET @cDropid                  = ''   
   SET @cLoc                     = ''  
   SET @cOrderKey                = ''  
   SET @cPickDetailKey           = ''  
   SET @cLabelNo                 = ''  
   SET @cCaseID                  = ''  
   SET @nPDQty                   = ''   
   Set @cPDOrderKey              = ''   
   SET @cEndRemark               = ''                
                            
   SET @nTranCount = @@TRANCOUNT                        
                               
   BEGIN TRAN                            
   SAVE TRAN rdt_1835ExtUpdSP01                    
      
   IF (@nFunc=1835)  
   BEGIN  
      IF (@nStep=4)  
      BEGIN                   
                            
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
               SET @nErrNo = 142601                            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetKeyFail'                            
               GOTO RollBackTran                            
            END                            
         END                            
         ELSE                            
         BEGIN                            
            SELECT @cDeviceProfileLogKey = DeviceProfileLogKey                             
            FROM PTL.PTLTran WITH (NOLOCK)                             
            WHERE AddWho = @cUserName                                                        
               AND STATUS IN ( '0', '1' )                           
            ORDER BY DeviceProfilelogKey Desc                          
                                
         END                            
                               
         DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                        
                                                     
         SELECT DISTINCT                         
             PTL.PTLKey                            
            ,PTL.DeviceID                         
         FROM PTL.PTLTran PTL WITH (NOLOCK)                            
         WHERE PTL.Status                    = '0'                            
               AND PTL.AddWho                = @cUserName                            
               AND PTL.DeviceProfileLogKey   = ''                            
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
               --AND SourceKey=@cWaveKey                            
                                  
            IF @@ERROR <> 0                             
            BEGIN                            
               SET @nErrNo = 142602                 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLFail'                            
               GOTO RollBackTran                            
            END                            
                              
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
               SET @nErrNo = 142603                            
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
                                           
                     UPDATE PTL.PTLTRAN WITH (ROWLOCK)                           
                     SET  Status = '0'                           
                        , LightSequence = CASE WHEN LightSequence <> '1' THEN '1' ELSE LightSequence END                          
                     WHERE PTLKey = @nPTLKey                           
                                         
                     IF @@ERROR <> 0      
                     BEGIN                           
                        SET @nErrNo = 142604                            
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
                                      
                  UPDATE PTL.PTLTRAN WITH (ROWLOCK)                           
                  SET  Status = '0'                           
                     , LightSequence = CASE WHEN LightSequence <> '1' THEN '1' ELSE LightSequence END                          
                  WHERE PTLKey = @nPTLKey                           
                                      
                  IF @@ERROR <> 0                           
                  BEGIN                           
                     SET @nErrNo = 142605                            
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
                     SET @nErrNo = 142606                          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'                            
                     GOTO RollBackTran                            
                  END                          
                                       
               END                                                           
                                   
               IF @@ERROR <> 0                           
               BEGIN                          
                  SET @nErrNo = 142607                            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'                            
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
               SET @nErrNo = 142608                            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UserIDInUsed'                            
               GOTO RollBackTran                                
            END                            
         END                          
                               
         SELECT TOP 1 @nPTLKey    = PTL.PTLKey                                 
                     ,@cSuggSKU   = PTL.SKU                        
                     ,@cQty       = PTL.ExpectedQty                            
                     ,@cUOM       = PTL.UOM                            
                     ,@cSuggPosition = PTL.DevicePosition                             
                     ,@cIPAddress = PTL.IPAddress             
                     ,@cDropid    = PTL.Dropid  
                     ,@cSuggTote  = PTL.Caseid                           
         FROM PTL.PTLTran PTL WITH (NOLOCK)                            
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID                            
         WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey                            
            AND D.Priority = '1'                             
            AND PTL.Status = '0'                            
         Order by PTL.Loc,D.DeviceID, PTL.Remarks,PTL.SKU                          
                                                
         SELECT Top 1 @cSuggLoc      = DeviceID                            
         FROM dbo.DeviceProfile WITH (NOLOCK)                            
         WHERE DevicePosition = @cSuggPosition                             
            AND StorerKey = @cStorerKey                             
            AND IPAddress = @cIPAddress                      
                                       
         --WAITFOR DELAY '00:00:02'  -- Delay 15 seconds before checking                                                                                   
                                                             
         SELECT @cPrefUOM = Short                        
         FROM dbo.CodeLkup WITH (NOLOCK)                        
         WHERE ListName = 'LightUOM'                        
         AND Code = @cUOM                             
                               
         -- Start to Light Up First Location --                             
         DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                  
                               
         SELECT PTLKey, DevicePosition,Remarks,ExpectedQty                           
         FROM PTL.PTLTran PTL WITH (NOLOCK)                            
         WHERE Status             = '0'                            
            AND AddWho             = @cUserName                            
            AND DeviceID           = @cSuggLoc            
            AND Dropid             = @cDropid                               
            AND SKU                = @cSuggSKU                            
            AND UOM                = @cUOM                            
            AND DeviceProfileLogKey = @cDeviceProfileLogKey                            
            AND IPAddress = @cIPAddress                            
         ORDER BY Loc,DeviceID, PTLKey                            
                               
         OPEN CursorLightUp                                        
                               
         FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition,@cRemark,@cQty                            
                                          
         WHILE @@FETCH_STATUS <> -1                                 
         BEGIN                
                                     
            IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)                            
                        WHERE DeviceID = @cSuggLoc                            
                        AND DevicePosition = @cDevicePosition                            
                        AND Priority = '0'                            
                        AND IPAddress = @cIPAddress )                             
            BEGIN                        
               IF @cQty <=9                           
                  SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@cQty AS NVARCHAR(3))              
               ELSE IF @cQty >=10 AND @cQty<=99              
                   SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@cQty AS NVARCHAR(3))                
               ELSE IF @cQty >=100               
                   SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@cQty AS NVARCHAR(3))                    
            END                                              
            ELSE                            
            BEGIN                            
               --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) )  -- (ChewKP02)                           
              IF @cQty <=9                           
                  SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@cQty AS NVARCHAR(3))              
               ELSE IF @cQty >=10 AND @cQty<=99              
                   SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@cQty AS NVARCHAR(3))                
               ELSE IF @cQty >=100               
                  SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@cQty AS NVARCHAR(3))                         
            END   
           
            SET @cSuggQty=@cDisplayValue    
              
            SELECT     @cSuggSKUDesc1= SUBSTRING(Descr, 1, 20)   -- SKU desc 1              
                     , @cSuggSKUDesc2 = SUBSTRING(Descr, 21, 20)  -- SKU desc 2  
                     , @cSuggSKUDesc3 = SUBSTRING(Descr, 41, 60)  -- SKU desc 2    
            FROM SKU WITH (NOLOCK)  
            WHERE SKU=@cSuggSKU    
              
            UPDATE PTL.PTLTRAN WITH (ROWLOCK)  
            SET   Status=1,  
                  Lightup = 1,  
                  EditDate = GETDATE(),                         
                  EditWho = SUSER_SNAME()      
            WHERE PTLKEY=  @nPTLKey  
              
            IF (@@ERROR <> 0)  
            BEGIN  
               SET @nErrNo = 142609                              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLUpdateFail'                                 
               GOTO RollBackTran     
            END                         
                                                          
            FETCH NEXT FROM CursorLightUp INTO @nPTLKey, @cDevicePosition,@cRemark,@cQty                            
         END                            
         CLOSE CursorLightUp                                        
         DEALLOCATE CursorLightUp  
  
      END   
        
      ELSE IF (@nStep=6)  
      BEGIN  
           
         -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID                                
         SELECT TOP 1 @cSuggLoc    = PTL.DeviceID                                
                     ,@cSuggSKU     = PTL.SKU                                
                     ,@cQty         = PTL.ExpectedQty                                               
                     ,@cOrderKey      = PTL.OrderKey                                
                     ,@cDropID        = PTL.DropID                                
                     ,@cCaseID        = PTL.CaseID                              
                     ,@cUOM            = PTL.UOM                                
                     ,@cWaveKey        = PTL.SourceKey                                
                     ,@cDeviceProfileLogKey = PTL.DeviceProfileLogKey                       
                     ,@cUserName       = PTL.AddWho                                
                     ,@cLoc            = PTL.Loc                                
                     ,@nPTLKey         = PTL.PTLKey                                
                     ,@cStorerKey      = PTL.StorerKey                               
         FROM PTL.PTLTran PTL WITH (NOLOCK)                                
         WHERE AddWho=@cUserName                                
            AND Status = '1'                                
         Order By PTLKey    
  
  
         IF ISNULL(@nPTLKey,0 ) = 0                                
         BEGIN                                
            SET @nErrNo = 142610                                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLKeyNotFound'                               
            GOTO RollBackTran                                
         END  
            
          -- Update PickDetail.CaseID = LabelNo, Split Line if there is Short Pick and Create PackDetail                              
         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
         SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.CaseID                              
         FROM dbo.Pickdetail PD WITH (NOLOCK)                              
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey                              
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber                              
         WHERE PD.DropID = @cDropID                              
            AND PD.Status = '5'                              
            AND PD.SKU    = @cSuggSKU                                                           
            AND PD.UOM = @cUOM                              
            AND PD.Qty > 0                              
            AND O.Orderkey = @cOrderKey                   
         ORDER BY PD.SKU                            
                            
         OPEN  CursorPickDetail                              
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo  
           
         WHILE @@FETCH_STATUS <> -1   
         BEGIN                             
  
            -- Confirm PickDetail                          
            UPDATE dbo.PickDetail WITH (ROWLOCK)                          
               SET CaseID = 'Sorted'                        
                  , DropID = @cCaseID                        
                  , EditDate = GetDate()                          
                  , EditWho  = suser_sname()                          
                  --, UOMQty   = @nQty                          
                  , Trafficcop = NULL                          
            WHERE  PickDetailKey = @cPickDetailKey                          
            AND Status = '5'                          
                          
            SET @nErrNo = @@ERROR                          
            IF @nErrNo <> 0                          
            BEGIN                  
               SET @nErrNo = 142611                                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PDUpdateFail'                               
               GOTO RollBackTran                         
            END  
                               
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo  
         END -- While Loop                                                          
         CLOSE CursorPickDetail                              
         DEALLOCATE CursorPickDetail                              
                              
                              
         UPDATE PTL.PTLTRAN WITH (ROWLOCK)                              
         SET STATUS  = '9',                              
             Qty = @cQty,                         
             EditDate = GETDATE(),                         
             EditWho = SUSER_SNAME()           
         WHERE PTLKey = @nPTLKey                              
      IF @@ERROR <> 0                              
      BEGIN                              
         SET @nErrNo = 142612                              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLUpdateFail'                                 
         GOTO RollBackTran                              
      END  
  
      -- If Same Location have more SKU to be PTS                                
      IF EXISTS ( SELECT 1 FROM PTL.PTLTran PTL WITH (NOLOCK)                                
      WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey                                
            AND PTL.Status = '0'                                
            AND PTL.DeviceID = @cSuggLoc                         
            AND PTL.StorerKey  = @cStorerKey  )                                
      BEGIN                                
         SELECT TOP 1 --@cSuggLoc       = D.DeviceID                                
                      @cSuggSKU         = PTL.SKU                                
                     ,@cSuggUOM         = PTL.UOM                           
                     ,@nNewExpectedQty  = PTL.ExpectedQty        
                     ,@cDropID          = PTL.DropID     
                     ,@nPTLKey          = PTL.PtlKey  
                     ,@cQty             = PTL.ExpectedQty  
                     ,@cRemark          = PTL.Remarks   
                     ,@cSuggTote        = PTL.Caseid                            
         FROM PTL.PTLTran PTL WITH (NOLOCK)                                
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey                                
         WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey                                
            AND D.Priority = '1'                                
            AND PTL.Status = '0'                                
            AND PTL.DeviceID = @cSuggLoc                                
            AND D.StorerKey  = @cStorerKey                                
         Order by D.DeviceID,PTL.Remarks, PTL.SKU                                

         IF @cQty <=9                         
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@cQty AS NVARCHAR(3))            
         ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99            
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@cQty AS NVARCHAR(3))              
         ELSE IF @nNewExpectedQty >=100             
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@cQty AS NVARCHAR(3))                               
                                                 
         SET @cSuggQty=@cDisplayValue    
              
         SELECT     @cSuggSKUDesc1= SUBSTRING(Descr, 1, 20)   -- SKU desc 1              
                  , @cSuggSKUDesc2 = SUBSTRING(Descr, 21, 20)  -- SKU desc 2   
                  , @cSuggSKUDesc3 = SUBSTRING(Descr, 41, 60)  -- SKU desc 2   
         FROM SKU WITH (NOLOCK)  
         WHERE SKU=@cSuggSKU    
              
         UPDATE PTL.PTLTRAN WITH (ROWLOCK)  
         SET   Status=1,  
               Lightup = 1,  
               EditDate = GETDATE(),                         
               EditWho = SUSER_SNAME()      
         WHERE PTLKEY=  @nPTLKey  
              
         IF (@@ERROR <> 0)  
         BEGIN  
            SET @nErrNo = 142613                              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLUpdateFail'         
            GOTO RollBackTran   
         END                                                             
                                
         GOTO QUIT                                
      END  
      ELSE -- Task for Next Location                                
      BEGIN  
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND CaseID <> 'SORTED')                          
         BEGIN  
              
            IF  NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK)   
                     WHERE Wavekey=@cWaveKey   
                     AND  CaseID ='')  
            BEGIN  
               SET @cEndRemark = 'WAVEEND'      
            END  
            ELSE  
            BEGIN  
               SET @cEndRemark = 'END'      
            END  
                     
            UPDATE dbo.dropid with (rowlock)                        
            set status='9'                  
               , EditDate = GetDate()                          
               , EditWho  = suser_sname()                         
            where dropid=@cCaseID   
              
            IF (@@ERROR <> 0)  
            BEGIN  
               SET @nErrNo = 142614                              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'IDUpdateFail'         
               GOTO RollBackTran   
            END                   
                           
            UPDATE DBO.ORDERTOLOCDETAIL WITH (ROWLOCK)                  
            SET STATUS=9                  
               , EditDate = GetDate()                          
               , EditWho  = suser_sname()                     
            WHERE ORDERKEY=  @cOrderKey AND WAVEKEY=   @cWaveKey  
              
            IF (@@ERROR <> 0)  
            BEGIN  
               SET @nErrNo = 142615                              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OTLUpdateFail'         
               GOTO RollBackTran   
            END                        
                        
            UPDATE dbo.DeviceProfileLog with (rowlock)                        
            SET status='9'                        
            where dropid=@cCaseID                        
                        
            IF @nErrNo <> 0                          
            BEGIN  
               SET @nErrNo = 142616                              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DPLUpdateFail'         
               GOTO RollBackTran  
            END                       
         END       
           
         SELECT TOP 1       @cSuggLoc       = D.DeviceID                                
                           ,@cSuggSKU       = PTL.SKU                                
                           ,@cSuggUOM       = PTL.UOM                                
                           ,@nNewPTLKey     = PTL.PTLKey                                
                           ,@cSuggDropID    = PTL.DropID                           
                           ,@nNewExpectedQty = PTL.ExpectedQty                         
                           ,@cRemark         = PTL.Remarks   
                           ,@cSuggTote  = PTL.Caseid                               
                           --,@cSuggDevicePosition = PTL.DevicePosition                                
         FROM PTL.PTLTran PTL WITH (NOLOCK)                                
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey                              
         WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey               
            AND D.Priority = '1'                                
            AND PTL.Status = '0'                                
            AND PTL.StorerKey = @cStorerKey                                
         Order by PTL.LOC,D.DeviceID,PTL.Remarks, PTL.SKU        
  
         IF @nNewExpectedQty <=9                         
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@nNewExpectedQty AS NVARCHAR(3))            
         ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99            
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@nNewExpectedQty AS NVARCHAR(3))              
         ELSE IF @nNewExpectedQty >=100             
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@nNewExpectedQty AS NVARCHAR(3))  
             
         SET @cSuggQty=@cDisplayValue    
              
         SELECT     @cSuggSKUDesc1= SUBSTRING(Descr, 1, 20)   -- SKU desc 1              
                  , @cSuggSKUDesc2 = SUBSTRING(Descr, 21, 20)  -- SKU desc 2  
                  , @cSuggSKUDesc3 = SUBSTRING(Descr, 41, 60)  -- SKU desc 3    
         FROM SKU WITH (NOLOCK)  
         WHERE SKU=@cSuggSKU    
              
         UPDATE PTL.PTLTRAN WITH (ROWLOCK)  
         SET   Status=1,  
               Lightup = 1,  
               EditDate = GETDATE(),                         
               EditWho = SUSER_SNAME()      
         WHERE PTLKEY=  @nNewPTLKey  
              
         IF (@@ERROR <> 0)  
         BEGIN  
            SET @nErrNo = 142617                              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLUpdateFail'         
            GOTO RollBackTran  
         END  
       END  
    END  
      
    END                              
                       
    GOTO QUIT                           
                               
RollBackTran:                            
   ROLLBACK TRAN rdt_1835ExtUpdSP01 -- Only rollback change made here                            
                            
Quit:                            
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                            
      COMMIT TRAN rdt_1835ExtUpdSP01                         
END  

GO