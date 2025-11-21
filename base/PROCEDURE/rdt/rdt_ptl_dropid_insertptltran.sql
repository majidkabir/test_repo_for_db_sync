SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
            
/************************************************************************/              
/* Store procedure: rdt_PTL_DROPID_InsertPTLTran                        */              
/* Copyright      : LF                                                  */              
/*                                                                      */              
/* Purpose: Insert PTLTran                                              */              
/*                                                                      */              
/* Called from: rdtfnc_PTL_DROPID                                       */              
/*                                                                      */              
/* Exceed version: 5.4                                                  */              
/*                                                                      */              
/* Modifications log:                                                   */              
/*                                                                      */              
/* Date       Rev  Author   Purposes                                    */              
/* 2019-06-17 1.0  YeeKung  WMS-10055 Created                           */              
/************************************************************************/              
              
CREATE PROC [RDT].[rdt_PTL_DROPID_InsertPTLTran] (              
     @nMobile          INT              
    ,@nFunc            INT              
    ,@cFacility        NVARCHAR(5)              
    ,@cStorerKey       NVARCHAR( 15)               
    ,@cPTSZone         NVARCHAR( 10)               
    ,@cDropID          NVARCHAR( 20)               
    ,@cUserName        NVARCHAR( 18)                
    ,@cLangCode        NVARCHAR( 3)              
    ,@cLightMode       NVARCHAR( 10)              
    ,@nErrNo           INT         OUTPUT              
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max                  
 )              
AS              
BEGIN              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF              
              
   DECLARE @b_success             INT              
         , @n_err                 INT              
         , @c_errmsg              NVARCHAR(250)              
         , @nTranCount            INT              
         , @bDebug                INT              
         , @cPTLType              NVARCHAR(20)              
         , @cIPAddress            NVARCHAR(40)              
         , @cDevicePosition       NVARCHAR(10)              
         , @cOrderKey             NVARCHAR(10)              
         , @cSKU                  NVARCHAR(20)               
         , @cLoc                  NVARCHAR(10)               
         , @nExpectedQty          INT              
         , @cLot                  NVARCHAR(10)              
         , @cPickDetailKey        NVARCHAR(10)              
         , @cConsigneeKey         NVARCHAR(15)              
         , @cDeviceProfileKey     NVARCHAR(10)              
         , @cDeviceID             NVARCHAR(20)              
         , @cToteID               NVARCHAR(20)              
         , @cCaseID               NVARCHAR(20)              
         , @cLoadKey              NVARCHAR(10)              
         , @cPickSlipNo           NVARCHAR(10)              
         , @cWaveKey              NVARCHAR(10)              
         , @cDeviceProfileLogKey  NVARCHAR(10)              
         , @cLightModeSecondary   NVARCHAR(10)              
         --, @cLightMode     NVARCHAR(10)              
         , @cDevicePositionSecondary NVARCHAR(10)               
         , @cUOM                  NVARCHAR(10)        
         , @cAlphaQty             INT          
         , @cAlpha                NVARCHAR(10)    
         , @cLogicalLoc           NVARCHAR(10)                  
                     
              
   SET @cPTLType          = 'Pick2PTS'              
   SET @cIPAddress        = ''              
   SET @cDevicePosition   = ''              
   SET @cOrderKey         = ''              
   SET @cSKU              = ''              
   SET @cLoc              = ''              
   SET @nExpectedQty      = 0              
   SET @cDeviceProfileLogKey = ''              
   SET @cDeviceProfileKey = ''              
   SET @CDeviceID         = ''              
   SET @cConsigneeKey     = ''              
   SET @cToteID           = ''              
   SET @cCaseID           = ''              
   SET @cLoadKey          = ''              
   SET @cPickSlipNo       = ''              
   SET @nErrNo            = 0              
   SET @cWaveKey          = ''              
   SET @cLightModeSecondary = ''              
   --SET @cLightMode = ''              
   SET @cDevicePositionSecondary = ''               
   SET @cUOM             = ''             
   SET @cAlpha           = ''         
   SET @cAlphaQty        = 0     
   SET @cLogicalLoc      = ''       
                      
   SET @nTranCount = @@TRANCOUNT              
                  
   BEGIN TRAN              
   SAVE TRAN PTLTran_Insert              
                  
--    SELECT TOP 1 @cLightMode = Short               
--    FROM dbo.CodeLkup WITH (NOLOCK)              
--    WHERE ListName = 'LightMode'              
--    AND Code <> 'White'              
--    AND UDF01 = '0'              
--    Order By Code             
                  
   SELECT TOP 1 @cLightModeSecondary = Short               
   FROM dbo.CodeLkup WITH (NOLOCK)              
   WHERE ListName = 'LightMode'              
      AND Code = 'White'              
      AND UDF01 = '0'              
            
   SELECT  @cAlphaQty=COUNT(DISTINCT DROPID)                 
   FROM PTL.PTLTran WITH (NOLOCK)                 
   WHERE AddWho = @cUserName                
      AND Status = '0'           
               
   IF NOT EXISTS ( SELECT  1      
   FROM dbo.PickDetail PD WITH (NOLOCK)               
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey              
   INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber              
   INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.Orderkey=O.OrderKey --OD.UserDefine02 AND STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END              
   INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = OTL.Loc              
   INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK ) ON DL.DeviceProfileKey = D.DeviceProfileKey               
   WHERE PD.StorerKey           = @cStorerKey              
      AND PD.DropID              = @cDropID                  
      --AND D.StorerKey            = @cStorerKey              
      --AND PD.CaseID = ''      
      AND OTL.PTSZone            = @cPTSZone)         
   BEGIN      
      SET @nErrNo = 140805              
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvDropid'              
      GOTO RollBackTran          
   END      
        
   DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                          
                  
   SELECT  D.IPAddress              
         , D.DevicePosition              
         , D.DeviceID              
         , PD.DropID              
         , MAX(O.OrderKey)              
         , PD.StorerKey              
         , PD.SKU              
         , SUM(PD.Qty)              
         , O.ConsigneeKey              
         , DL.DropID              
         , O.UserDefine09 -- WaveKey              
         , PD.PickSlipNo               
         , PD.UOM    
         , DL.UserDefine01              
   FROM dbo.PickDetail PD WITH (NOLOCK)               
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey              
   INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber              
   INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.Orderkey=O.OrderKey --OD.UserDefine02 AND STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END              
   INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = OTL.Loc              
   INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK ) ON DL.DeviceProfileKey = D.DeviceProfileKey               
   WHERE PD.StorerKey           = @cStorerKey              
      AND PD.DropID              = @cDropID              
      AND DL.Status              IN ( '1', '3' )               
      AND PD.Status   = '5'              
      AND D.StorerKey            = @cStorerKey              
      --AND PD.CaseID = ''      
      AND OTL.PTSZone            = @cPTSZone             
      AND PD.CaseID NOT LIKE 'T%'              
      AND PD.Qty > 0               
   GROUP BY D.IPAddress, D.DevicePosition, D.DeviceID, PD.DropID, PD.StorerKey, PD.SKU, O.ConsigneeKey,              
         DL.DeviceProfileLogKey, DL.DropID, O.UserDefine09 , PD.PickSlipNo, PD.UOM,DL.UserDefine01              
   ORDER BY PD.SKU              
                      
   OPEN CursorPTLTran                          
                  
   FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceID, @cToteID, @cOrderKey, @cStorerKey, @cSKU,               
                                       @nExpectedQty, @cConsigneeKey, @cCaseID, @cWaveKey, @cPickSlipNo, @cUOM,@cLogicalLoc               
                  
                  
   WHILE @@FETCH_STATUS <> -1                   
   BEGIN          
        
      SET @cAlpha= CHAR(@cAlphaQty +64+1)   
        
      IF NOT EXISTS(SELECT 1 FROM DeviceProfileLog WITH (NOLOCK)   
                  WHERE USERDEFINE02= @cWaveKey   
                  AND STATUS <>9)    
      BEGIN  
         SET @nErrNo = 140806              
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Wrong Wave'              
         GOTO RollBackTran    
      END  
                        
      IF @nExpectedQty > 0              
      BEGIN              
         -- UPDATE PTS TOTE DROPID to Status = '3' - PTS in Progress --               
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)              
                     WHERE DropID = @cCaseID               
                     AND Status   = '1'              
                     AND DropIDType = 'PTS')              
                     --AND DropLoc  = @cDeviceID )               
         BEGIN              
                                
            UPDATE dbo.DropID WITH (ROWLOCK)               
            SET Status     = '3'             
               ,PickSlipNo = @cPickSlipNo               
               ,DropLoc    = @cDeviceID              
            WHERE DropID = @cCaseID              
               AND Status   = '1'              
               --AND DropLoc  = @cDeviceID                 
               AND DropIDType = 'PTS'              
                                
            IF @@ERROR <> 0               
            BEGIN              
               SET @nErrNo = 140801              
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDropIDFail'              
               GOTO RollBackTran              
            END              
                              
         END              
                                             
         IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)              
                           WHERE IPAddress     = @cIPAddress               
                           AND DeviceID        = @cDeviceID              
                           AND DevicePosition  = @cDevicePosition              
                           AND OrderKey        = @cOrderKey              
                           AND SKU = @cSKU              
                           AND Status          IN ( '0','1')               
                           AND DropID          = @cDropID              
                           AND UOM             = @cUOM )               
         BEGIN                        
                                             
            -- Insert Primary PTL Record --                     
            INSERT INTO PTL.PTLTran              
            (              
               -- PTLKey -- this column value is auto-generated              
               IPAddress,  DeviceID,     DevicePosition,              
               [Status],   PTLType,     DropID,              
               OrderKey,   Storerkey,    SKU,              
               LOC,        ExpectedQty,  Qty,              
               Remarks,    Lot,              
               DeviceProfileLogKey, SourceKey, ConsigneeKey,              
               CaseID,     LightMode,    LightSequence, UOM,              
               AddWho              
                                      
            )              
            VALUES              
            (              
               @cIPAddress  ,              
               @cDeviceID   ,                 
               @cDevicePosition  ,                 
               '0'          ,              
               @cPTLType    ,                 
               @cToteID     ,           
               @cOrderKey   ,              
               @cStorerKey ,                 
               @cSKU       ,                
               @cLogicalLoc,              
               @nExpectedQty ,                 
               0           ,                 
               @cAlpha      ,              
               ''     ,              
               ''          ,              
               @cWaveKey,              
               @cConsigneeKey,              
               @cCaseID,              
               @cLightMode,              
               '1',              
               @cUOM,              
               @cUserName                                    
            )              
                                   
            IF @@ERROR <> ''              
            BEGIN              
               SET @nErrNo = 140802              
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'              
               GOTO RollBackTran              
            END                                     
         END              
      END              
      FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceID, @cToteID, @cOrderKey, @cStorerKey, @cSKU,               
                                       @nExpectedQty, @cConsigneeKey, @cCaseID, @cWaveKey, @cPickSlipNo, @cUOM,@cLogicalLoc                           
   END              
   CLOSE CursorPTLTran                          
   DEALLOCATE CursorPTLTran                 
                  
   IF EXISTS ( SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)               
               WHERE AddWho = @cUserName              
               AND Status <> '9'              
               AND DeviceProfileLogKey <> ''  )               
   BEGIN              
      SET @nErrNo = 140803              
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UserIDInUsed'              
      GOTO RollBackTran              
   END              
                  
   -- Verify is anything insert into PTLTran              
   IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK)              
                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey              
                  AND Status = '0'               
                  AND DropID = @cDropID)               
   BEGIN              
      SET @nErrNo = 140804       
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoPackTask'              
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