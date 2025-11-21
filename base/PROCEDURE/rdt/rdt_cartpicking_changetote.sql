SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CartPicking_ChangeTote                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Insert PTLTran                                              */  
/*                                                                      */  
/* Called from: rdtfnc_PTL_PTS                                          */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 10-02-2014 1.0  James    Created                                     */  
/* 31-05-2014 1.1  ChewKP   Fixed Tote-Reuse issues (ChewKP01)          */
/* 12-06-2014 1.2  ChewKP   IF Not Valid Tote prompt error (ChewKP02)   */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CartPicking_ChangeTote] (  
     @nMobile          INT  
    ,@nFunc            INT  
    ,@cDeviceID        NVARCHAR( 20)  
    ,@cOldToteID       NVARCHAR( 20)  
    ,@cNewToteID       NVARCHAR( 20)  
    ,@cLangCode        NVARCHAR( 3)  
    ,@nErrNo           INT          OUTPUT  
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max  
 )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @nTranCount             INT, 
      @cDeviceProfileKey      NVARCHAR( 10), 
      @cNewDeviceProfileKey   NVARCHAR( 10), 
      @cDeviceProfileLogKey   NVARCHAR( 10), 
      @cLoadKey               NVARCHAR( 10),
      @cPickSlipNo            NVARCHAR( 10),
      @cDropIDSuffix          NVARCHAR(3),  
      @b_success              INT 

      
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN PTL_Cart_ChangeTote
   

   
   SELECT @cDeviceProfileKey = DL.DeviceProfileKey, 
          @cDeviceProfileLogKey = DL.DeviceProfileLogKey, 
          @cLoadKey = DL.UserDefine02 
   FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
   JOIN dbo.DeviceProfile D WITH (NOLOCK) ON (DL.DeviceProfileKey = D.DeviceProfileKey )
   WHERE D.DeviceID = @cDeviceID
   AND   D.DeviceType = 'CART'
   AND   D.Status = '3'
   AND   DL.DropID = @cOldToteID
   AND   DL.Status = '3'

   SET @cPickSlipNo = ''
   SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
/*
   EXECUTE nspg_getkey  
      'DeviceProfileKey'  
      , 10  
      , @cNewDeviceProfileKey OUTPUT  
      , @b_success            OUTPUT  
      , @nErrNo               OUTPUT  
      , @cErrMsg              OUTPUT  

   IF NOT @b_success = 1  
   BEGIN  
      SET @nErrNo = @nErrNo  
      SET @cErrMsg = @cErrMsg  
      GOTO RollBackTran  
   END  

   -- Insert deviceprofile here
   INSERT INTO DeviceProfile ( DeviceProfileKey, DeviceProfileLogKey, IPAddress, PortNo, DeviceType, DeviceID, DevicePosition, [Status]) 
   SELECT @cNewDeviceProfileKey AS DeviceProfileKey, @cDeviceProfileLogKey AS DeviceProfileLogKey, IPAddress, PortNo, DeviceType, DeviceID, DevicePosition, '3' AS [Status] 
   FROM dbo.DeviceProfile WITH (NOLOCK) 
   WHERE DeviceID = @cDeviceID
   AND   DeviceProfileKey = @cDeviceProfileKey
   AND   [Status] = '3'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DVLOG FAIL'
      GOTO RollBackTran
   END
*/
   -- Insert deviceprofilelog here
   INSERT INTO DeviceProfileLog ( DeviceProfileKey, DeviceProfileLogKey, DropID, [Status], ConsigneeKey, UserDefine02) 
   SELECT D.DeviceProfileKey, DL.DeviceProfileLogKey, @cNewToteID, '3', ConsigneeKey, DL.UserDefine02 
   FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
   JOIN dbo.DeviceProfile D WITH (NOLOCK) ON (DL.DeviceProfileKey = D.DeviceProfileKey )
   WHERE D.DeviceID = @cDeviceID
   AND   D.Status = '3'
   AND   D.DeviceType = 'CART'
   AND   DL.Status = '3'
   AND   DL.DropID = @cOldToteID
                  
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DVLOG FAIL'
      GOTO RollBackTran
   END
   
   -- Update plttran here
   UPDATE PTLTran WITH (ROWLOCK) SET 
      DropID = @cNewToteID
   WHERE DeviceID = @cDeviceID
   AND   DeviceProfileLogKey = @cDeviceProfileLogKey
   AND   DropID = @cOldToteID
   AND   [Status] = '1'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PLTRN FAIL'
      GOTO RollBackTran
   END
   
   -- (ChewKP01) 
   -- Update Old DropID X
   UPDATE DeviceProfileLog WITH (ROWLOCK) SET 
      OrderKey = ISNULL(RTRIM(OrderKey),'') + 'X'
   WHERE DeviceProfileKey = @cDeviceProfileKey
   AND   Status = '9'
   AND   DropID = @cOldToteID

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84859
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DVLOG FAIL'
      GOTO RollBackTran
   END
   
   -- Close existing tote
   UPDATE DeviceProfileLog WITH (ROWLOCK) SET 
       [Status] = '9'
      ,OrderKey = ISNULL(RTRIM(OrderKey),'') + 'X'
   WHERE DeviceProfileKey = @cDeviceProfileKey
   AND   Status = '3'
   AND   DropID = @cOldToteID

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84854
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DVLOG FAIL'
      GOTO RollBackTran
   END
   

   
/*
   UPDATE DeviceProfile WITH (ROWLOCK) SET 
      [Status] = '9'
   WHERE DeviceProfileKey = @cDeviceProfileKey
   AND   Status = '3'
   AND   DeviceID = @cDeviceID

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 84855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DVLOG FAIL'
      GOTO RollBackTran
   END
*/

   IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)  
                  WHERE DropID = @cNewToteID   
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
         SET @nErrNo = 84857  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetKeyFail'  
         GOTO RollBackTran
      END    
       
      UPDATE dbo.DropID  
         SET DropID = RTRIM(@cNewToteID) + RTRIM(@cDropIDSuffix)  
      WHERE DropID = @cNewToteID   
      AND Status = '9'  
        
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 84858  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'  
         GOTO RollBackTran
      END  
   END     
      
   IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cNewToteID AND [Status] < '9')
   BEGIN
      INSERT INTO dbo.DROPID (DropID, DropIDType, Status, LoadKey, PickSlipNo) VALUES 
                             (@cNewToteID, 'CART', '5', @cLoadKey, @cPickSlipNo)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 84856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'
         GOTO RollBackTran
      END
   END
   
   -- (ChewKP02)
   IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                   WHERE DropID = @cNewToteID AND Status = '5' 
                   AND LoadKey = @cLoadKey
                   AND PickSLipNo = @cPickSlipNo ) 
   BEGIN
         SET @nErrNo = 84860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV TOTENO'
         GOTO RollBackTran
   END                   
   

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN PTL_Cart_ChangeTote

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN PTL_Cart_ChangeTote
        
END

GO