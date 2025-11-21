SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1036ExtValidSP02                                */    
/* Purpose: Validate                                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2019-07-16 1.0  YeeKung    WMS-9312 Created                          */     
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1036ExtValidSP02] (    
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
            ,@cOrderKeyloc             NVARCHAR(10)    
  
  
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
            
         
    END  
      
END    
    
QUIT:   

SET QUOTED_IDENTIFIER OFF

GO