SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_CartPicking_InsertPTLTran                       */  
/* Copyright      : LFL                                                 */  
/*                                                                      */  
/* Purpose: Insert PTLTran                                              */  
/*                                                                      */  
/* Called from: rdtfnc_TM_CartPicking                                   */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 18-04-2014 1.0  Chee     Created                                     */  
/* 03-04-2014 1.1  ChewKP   Changes (ChewKP01)                          */
/* 21-08-2017 1.2  ChewKP   Performance Fixes (ChewKP02)                */
/* 24-09-2018 1.3  James    WMS7751-Remove orderdetail.loadkey (james01)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CartPicking_InsertPTLTran] (  
     @nMobile          INT  
    ,@nFunc            INT  
    ,@cFacility        NVARCHAR(5)  
    ,@cStorerKey       NVARCHAR( 15)   
    ,@cDeviceID        NVARCHAR( 20)  
    ,@cFromLOC         NVARCHAR( 10)  
    ,@cSKU             NVARCHAR( 20)  
    ,@cWaveKey         NVARCHAR( 10)  
    ,@cTaskDetailKey   NVARCHAR( 10)   
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
     @b_success             INT   
   , @nTranCount            INT  
   , @bDebug                INT  
   , @cUserName             NVARCHAR(18)  
   , @cDeviceProfileKey     NVARCHAR(10)
   , @cDeviceProfileLogKey  NVARCHAR(10)  
   , @cConsigneeKey         NVARCHAR(15)  
   , @cLoadKey              NVARCHAR(10)  
   , @cIPAddress            NVARCHAR(40)  
   , @cDevicePosition       NVARCHAR(10)   
   , @cToteID               NVARCHAR(20)  
   , @nExpectedQty          INT  
   , @cPickSlipNo           NVARCHAR(10)  

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT  
      
   BEGIN TRAN  
   SAVE TRAN PTLTran_Insert  
      
   -- Assign / Get DeviceProfileLogKey
   IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)  
               WHERE DeviceID = @cDeviceID
               AND   Status = '1'  
               AND   DeviceType = 'CART' )   
   BEGIN  
      EXECUTE nspg_getkey  
         'DeviceProfileLogKey'  
         , 10  
         , @cDeviceProfileLogKey OUTPUT  
         , @b_success            OUTPUT  
         , @nErrNo               OUTPUT  
         , @cErrMsg              OUTPUT  
        
      UPDATE  DeviceProfile WITH (ROWLOCK) SET 
         DeviceProfileLogKey = @cDeviceProfileLogKey, 
         Status = '3'  
      WHERE DeviceID = @cDeviceID
      AND   Status = '1'  
      AND   DeviceType = 'CART' 

      IF @@ERROR <> ''  
      BEGIN  
         SET @nErrNo = 84651  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPfileFail'  
         GOTO RollBackTran  
      END  
   END 
   ELSE
   BEGIN
      SELECT @cDeviceProfileLogKey = DeviceProfileLogKey 
      FROM dbo.DeviceProfile WITH (NOLOCK) 
      WHERE DeviceID = @cDeviceID
      AND   Status = '3'
      AND   DeviceType = 'CART'
   END

   -- Update any remaining DeviceProfileLog.Status = '1'
   UPDATE DL WITH (ROWLOCK) SET 
      DeviceProfileLogKey = @cDeviceProfileLogKey, 
      Status = '3' 
   FROM dbo.DeviceProfilelog DL 
   JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey  -- (CheWKP02) 
      WHERE D.DeviceID = @cDeviceID
      AND   D.Status = '3'
      AND   D.DeviceType = 'CART'
      AND   DL.Status = '1'

   -- Loop TaskDetail
   DECLARE CUR_TaskDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT TD.Message03, O.LoadKey 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
   JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)
   WHERE PD.LOC = @cFromLOC
   AND   PD.SKU = @cSKU
   AND   PD.StorerKey = @cStorerKey
   AND   PD.Status = '0'
   AND   TD.WaveKey = @cWaveKey
   AND   TD.Status = '3'
   AND   TD.UserKey = @cUserName
   GROUP BY TD.Message03, O.LoadKey -- diff load cannot assign to same tote although same consignee
   ORDER BY 1

   OPEN CUR_TaskDetail
   FETCH NEXT FROM CUR_TaskDetail INTO @cConsigneeKey, @cLoadKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Update new ConsigneeKey & LoadKey to available empty Tote if not exists already
      IF NOT EXISTS(SELECT 1 FROM dbo.DeviceProfilelog DL WITH (NOLOCK) 
                    JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey 
                    WHERE D.DeviceID = @cDeviceID
                    AND   D.Status = '3'
                    AND   D.DeviceType = 'CART'
                    AND   DL.Status = '3'                
                    AND   ISNULL( DL.ConsigneeKey, '') = @cConsigneeKey
                    AND   ISNULL( DL.Userdefine02, '') = @cLoadKey)
      BEGIN
         SET @cDeviceProfileKey = ''
         SELECT TOP 1 @cDeviceProfileKey = DL.DeviceProfileKey 
         FROM dbo.DeviceProfilelog DL WITH (NOLOCK) 
         JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey 
         WHERE D.DeviceID = @cDeviceID
         AND   D.Status = '3'
         AND   D.DeviceType = 'CART'
         AND   DL.Status = '3'      
         AND   ISNULL( DL.ConsigneeKey, '') = ''
         AND   ISNULL( DL.Userdefine02, '') = ''
         ORDER BY D.DevicePosition
      
         IF ISNULL(@cDeviceProfileKey, '') <> ''
         BEGIN
            UPDATE dbo.DeviceProfilelog WITH (ROWLOCK) SET 
               ConsigneeKey = @cConsigneeKey, 
               UserDefine02 = @cLoadKey 
            WHERE DeviceProfileKey = @cDeviceProfileKey
            AND   [Status] = '3'
            AND   ISNULL( ConsigneeKey, '') = ''
            AND   ISNULL( Userdefine02, '') = ''

            IF @@ERROR <> ''  
            BEGIN  
               SET @nErrNo = 84652  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPfileLFail'  
               GOTO RollBackTran  
            END  
         END
      END

      -- Check if exists tote with same ConsigneeKey & LoadKey, Insert/Update PTLTran & Update DropID
      DECLARE CUR_DeviceProfile CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT IPAddress, DeviceID, DevicePosition, DropID
      FROM dbo.DeviceProfilelog DL WITH (NOLOCK) 
      JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey 
      WHERE D.DeviceID = @cDeviceID
      AND   D.Status = '3'
      AND   D.DeviceType = 'CART'
      AND   DL.Status = '3'
      AND   ISNULL( DL.ConsigneeKey, '') = @cConsigneeKey
      AND   ISNULL( DL.Userdefine02, '') = @cLoadKey
      ORDER BY 1

      OPEN CUR_DeviceProfile
      FETCH NEXT FROM CUR_DeviceProfile INTO @cIPAddress, @cDeviceID, @cDevicePosition, @cToteID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)  
                         WHERE IPAddress     = @cIPAddress   
                         AND   DeviceID        = @cDeviceID  
                         AND   DevicePosition  = @cDevicePosition  
                         AND   Status < '9'  )
         BEGIN            
            SET @nExpectedQty = 0                  
            SELECT @nExpectedQty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            WHERE PD.LOC = @cFromLOC
            AND   PD.SKU = @cSKU
            AND   PD.Status = '0'
            AND   O.UserDefine09 = @cWaveKey
            AND   OD.UserDefine02 = @cConsigneeKey
            AND   O.LoadKey = @cLoadKey

            IF @nExpectedQty <= 0  
            BEGIN  
               SET @nErrNo = 84653  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLTranFail'  
               GOTO RollBackTran  
            END  

            INSERT INTO PTLTran  
            (  
               -- PTLKey -- this column value is auto-generated  
               IPAddress,  DeviceID,     DevicePosition,  
               [Status],   PTL_Type,     DropID,  
               OrderKey,   Storerkey,    SKU,  
               LOC,        ExpectedQty,  Qty,  
               Remarks,    MessageNum,   Lot,  
               DeviceProfileLogKey, SourceKey, ConsigneeKey,  
               CaseID  
                 
            ) VALUES  
            (  
               @cIPAddress,  
               @cDeviceID,     
               @cDevicePosition,     
               '0',  
               'Pick2Cart', -- (ChewKP01)    
               @cToteID,     
               '',  
               @cStorerKey,     
               @cSKU,    
               @cFromLOC,  
               @nExpectedQty,     
               0,     
               '',  
               '',  
               '',  
               @cDeviceProfileLogKey,  
               @cWaveKey,  
               @cConsigneeKey,  
               ''  
            )  
                    
            IF @@ERROR <> ''  
            BEGIN  
               SET @nErrNo = 84654  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLTranFail'  
               GOTO RollBackTran  
            END  
         END  
         ELSE
         BEGIN
            UPDATE dbo.PTLTran WITH (ROWLOCK) SET 
               [Status] = '0'
             WHERE IPAddress       = @cIPAddress   
             AND   DeviceID        = @cDeviceID  
             AND   DevicePosition  = @cDevicePosition  
             AND   Status < '9'  

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 84655  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'  
               GOTO RollBackTran  
            END
         END

         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
         
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cToteID
                     AND   [Status] = '1')
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK) SET 
               [Status] = '5', 
               LoadKey = @cLoadKey, 
               PickSlipNo = @cPickSlipNo 
            WHERE DropID = @cToteID
            --AND   DropIDType = 'CART'   uniquekey is dropid
            AND   [Status] = '1'
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 84656  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDropIDFail'  
               GOTO RollBackTran  
            END
         END
         
         FETCH NEXT FROM CUR_DeviceProfile INTO @cIPAddress, @cDeviceID, @cDevicePosition, @cToteID
      END              
      CLOSE CUR_DeviceProfile              
      DEALLOCATE CUR_DeviceProfile  

      FETCH NEXT FROM CUR_TaskDetail INTO @cConsigneeKey, @cLoadKey
   END
   CLOSE CUR_TaskDetail
   DEALLOCATE CUR_TaskDetail

   -- (ChewKP01) 
   IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                   WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
                   AND   StorerKey = @cStorerKey
                   AND   SKU       = @cSKU 
                   AND   Loc       = @cFromLoc
                   AND   SourceKey = @cWaveKey
                   AND   Status    = '0' ) -- (ChewKP01)
   BEGIN
      SET @nErrNo = 84657
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDropIDFail'  
      GOTO RollBackTran  
   END 
   GOTO QUIT  
      
   RollBackTran:  
   ROLLBACK TRAN PTLTran_Insert  
      
   Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
      COMMIT TRAN PTLTran_Insert  
END  

GO