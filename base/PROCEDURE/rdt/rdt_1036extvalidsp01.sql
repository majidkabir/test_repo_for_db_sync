SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1036ExtValidSP01                                */  
/* Purpose: Validate                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-07-11 1.0  ChewKP     WMS-2121 Created                          */  
/* 2017-11-23 1.1  ChewKP     WMS-3491 Check WaveKey from               */
/*                            rdt.RdtAssignloc table (ChewKP01)         */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1036ExtValidSP01] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cCloseToteNo    NVARCHAR( 20) OUTPUT, 
   @cNewToteNo      NVARCHAR( 20) OUTPUT, 
   @nCursorPosition INT           OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1036  
BEGIN  
   
    
    DECLARE  @cToteNo                  NVARCHAR(5)
            ,@cConsigneeKey            NVARCHAR(30)            
            ,@cDeviceProfileKey        NVARCHAR(10)             
            ,@cOrderKey                NVARCHAR(10)         
            ,@cChkStatus               NVARCHAR(5)          
            ,@nTotalPickedQty          INT    
            ,@nTotalPackedQty          INT    
            ,@cDeviceProfileLogKey     NVARCHAR(10)
            ,@cDeviceID                NVARCHAR(10) 
            ,@cWaveKey                 NVARCHAR(10)
            ,@cNewToteScn              NVARCHAR(1)  


    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    IF @nStep = 1 
    BEGIN
       IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                       WHERE DropID = @cCloseToteNo
                       AND Status = '5' ) 
       BEGIN
         SET @nErrNo = 112151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
         SET @cCloseToteNo = '' 
         SET @nCursorPosition = 1 
         GOTO QUIT
       END  
       
       IF NOT EXISTS ( 
                      SELECT 1 
                      FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
                      INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
                      WHERE DL.DropID = @cCloseToteNo    
                      AND DL.Status <> '9'     
                      AND DP.Priority = '1'      )
       BEGIN
     
             SET @nErrNo = 112152                
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteClose'    
             SET @cCloseToteNo = ''   
             SET @nCursorPosition = 1        
             GOTO QUIT       
       
       END 
       
       SET @cDeviceProfileKey = ''    
              
       SELECT TOP 1   @cDeviceProfileLogKey = DL.DeviceProfileLogKey            
                    , @cDeviceID            = DP.DeviceID      
                    , @cDeviceProfileKey    = DL.DeviceProfileKey         
       FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
       INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
       WHERE DL.DropID = @cCloseToteNo    
       AND DL.Status <> '9'     
       AND DP.Priority = '1'     
    
       IF ISNULL(RTRIM(@cDeviceProfileKey),'') = ''    
       BEGIN    
          SET @nErrNo = 112157                
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDPKey'             
          SET @cCloseToteNo = '' 
          SET @nCursorPosition = 1 
          GOTO QUIT       
       END    

       IF ISNULL(@cNewToteNo,'')  = '' 
       BEGIN
          SET @nErrNo = 112155
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NewToteReq'
          SET @cNewToteNo = '' 
          SET @nCursorPosition = 2
          GOTO QUIT
       END
           
           
       IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                   WHERE DropID = @cNewToteNo    
                   AND Status <> '9' )     
       BEGIN    
          SET @nErrNo = 112158                
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'             
          SET @cNewToteNo = '' 
          SET @nCursorPosition = 2
          GOTO QUIT        
       END   
          
             
                 
       SELECT TOP 1     @cDeviceID = DP.DeviceID      
       FROM dbo.DeviceProfileLog DL WITH (NOLOCK)     
       INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DL.DeviceProfileKey     
       WHERE DL.DropID = @cCloseToteNo    
       AND DL.Status <> '9'     
       AND DP.Priority = '1'     
           
       SELECT @cConsigneeKey = ConsigneeKey     
       FROM dbo.StoreToLocDetail WITH (NOLOCK)    
       WHERE Loc = @cDeviceID   
       
       -- (ChewKP01) 
--       SELECT TOP 1 @cWaveKey = SourceKey            
--       FROM PTL.PTLTran WITH (NOLOCK)    
--       WHERE ConsigneeKey = @cConsigneeKey      
--       Order By EditDate Desc   
       
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
       ELSE 
       BEGIN
         SET @cNewToteScn = '0'      
       END  
       
       IF @cNewToteScn = '0' AND @cNewToteNo <> 'FULL'
       BEGIN
          SET @nErrNo = 112156
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FullReq'
          SET @cNewToteNo = '' 
          SET @nCursorPosition = 2
          GOTO QUIT
       END
       
       IF @cNewToteScn = '1' 
       BEGIN
            
          IF LEFT ( ISNULL(@cNewToteNo,'')  , 1 ) <> 'T'
          BEGIN
             SET @nErrNo = 112153
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongFormat'
             SET @cNewToteNo = '' 
             SET @nCursorPosition = 2
             GOTO QUIT
          END
          
          
          SET @cToteNo = SUBSTRING (ISNULL(@cNewToteNo,'') , 2 , 6 ) 
          
          IF ISNUMERIC ( @cToteNo )  = 0 
          BEGIN
             SET @nErrNo = 112154
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongFormat'
             SET @cNewToteNo = '' 
             SET @nCursorPosition = 2
             GOTO QUIT
          END
          
          
            
       END
      
       
    END
    
END  
  
QUIT:  

 

GO