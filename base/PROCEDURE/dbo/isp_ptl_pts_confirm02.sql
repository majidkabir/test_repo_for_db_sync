SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_PTL_PTS_Confirm02                               */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Insert PTLTran                                              */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 19-08-2014 1.0  ChewKP   Created. SOS#316599                         */    
/* 09-11-2014 1.1  ChewKP   With Trigger Control on Location Light Up   */    
/* 23-12-2014 1.2  Shong    Fixing Error on wrong OrderKey variable     */  
/* 21-11-2014 1.3  ChewKP   Relight when <> 0 (ChewKP01)                */
/* 11-02-2015 1.4  ChewKP   Bug Fixes (ChewKP02)                        */
/* 24-03-2015 1.5  Shong    Performance Tuning                          */
/* 23-04-2021 1.6  Chermain WMS-16846 Add Channel_ID (cc01)             */
/************************************************************************/    
CREATE PROC [dbo].[isp_PTL_PTS_Confirm02] (    
     @nPTLKey              INT    
    ,@cStorerKey           NVARCHAR( 15)     
    ,@cDeviceProfileLogKey NVARCHAR(10)    
    ,@cDropID              NVARCHAR( 20)      
    ,@nQty                 INT    
    ,@nErrNo               INT          OUTPUT    
    ,@cErrMsg              NVARCHAR(20) OUTPUT -- screen limitation, 20 char max    
    ,@cStatus              NVARCHAR(2) = '9' OUTPUT     
    ,@cMessageNum          NVARCHAR(10) = ''    
 )    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_success             INT    
       , @nTranCount            INT    
       , @bDebug                INT    
       , @cOrderKey             NVARCHAR(10)    
       --, @cSKU                  NVARCHAR(20)     
       , @cLoc                  NVARCHAR(10)     
       , @cLightSequence        NVARCHAR(10)    
       , @cDevicePosition       NVARCHAR(10)    
       , @cModuleAddress        NVARCHAR(10)    
       , @cPriority             NVARCHAR(10)    
       , @cPickSlipNo           NVARCHAR(10)    
       , @cSuggLoc              NVARCHAR(10)    
       , @cSuggSKU              NVARCHAR(10)    
       , @cModuleName           NVARCHAR(30)    
       , @cAlertMessage         NVARCHAR( 255)    
       , @cUOM                  NVARCHAR(10)    
       , @cPTSLoc               NVARCHAR(10)    
       , @cPTLSKU               NVARCHAR(20)    
       , @nExpectedQty          INT    
       , @cPackKey              NVARCHAR(10)    
       , @cLightMode            NVARCHAR(10)    
       , @cDisplayValue         NVARCHAR(5)    
       , @nCartonNo             INT    
       , @cLabelLine            NVARCHAR(5)    
       , @cCaseID               NVARCHAR(20)    
       , @nTotalPickedQty       INT    
       , @nTotalPackedQty       INT    
       , @cLabelNo              NVARCHAR(20)    
       , @cConsigneeKey         NVARCHAR(15)    
       , @cGenLabelNoSP         NVARCHAR(30)    
       , @cExecStatements       NVARCHAR(4000)       
       , @cExecArguments        NVARCHAR(4000)    
       , @cPickDetailKey        NVARCHAR(10)    
       , @nPDQty                INT    
       , @cNewPickDetailKey     NVARCHAR(10)    
       , @nNewPTLTranKey        INT    
       --, @cDeviceID             NVARCHAR(20)    
          
       , @cUserName             NVARCHAR(18)    
       , @cLightModeStatic      NVARCHAR(10)    
       , @cSuggUOM              NVARCHAR(10)    
       , @cPrefUOM              NVARCHAR(10)     
       , @cWaveKey              NVARCHAR(10)    
       , @cDeviceProfileKey     NVARCHAR(10)    
       , @cDeviceID             NVARCHAR(10)    
       , @cLightModeFULL        NVARCHAR(10)    
       , @cVarLightMode         NVARCHAR(10)    
       , @cLightPriority        NVARCHAR(1)     
    
    
       , @cHoldUserID           NVARCHAR(18)    
       , @cHoldDeviceProfileLogKey NVARCHAR(20)    
       , @cHoldSuggSKU          NVARCHAR(20)    
       , @cHoldUOM              NVARCHAR(10)    
       , @cPrevDevicePosition   NVARCHAR(10)    
       , @cLightModeHOLD        NVARCHAR(10)    
       , @cHoldConsigneeKey     NVARCHAR(15)    
       , @nHoldPTLKey           INT    
       , @nVarPTLKey            INT    
       , @cFullCosngineeKey     NVARCHAR(15)    
       , @cHoldCondition        NVARCHAR(1)     
       , @cSuggDevicePosition   NVARCHAR(10)    
       , @cEndCondition         NVARCHAR(1)    
       , @cLoadKey              NVARCHAR(10)    
       , @cPTLConsigneeKey      NVARCHAR(15)    
       , @nActualQty            INT    
       , @nUOMQty               INT     
       , @cPDOrderKey           NVARCHAR(10)    
       , @nPackQty              INT    
       , @cSuggDropID           NVARCHAR(20)    
       , @nTranCount01          INT   
       , @nNewExpectedQty       INT
    
    DECLARE @c_NewLineChar NVARCHAR(2)    
    SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)     
    
   --SET @cSKU                 = ''    
   SET @cLoc                 = ''    
   SET @cPTSLoc              = ''    
   SET @cDevicePosition      = ''    
   SET @cPriority            = ''    
   SET @cPickSlipNo          = ''    
   SET @cUOM                 = ''    
   SET @cPTSLoc              = ''    
   SET @cAlertMessage        = ''    
   SET @cModuleName          = ''    
   SET @cPTLSKU              = ''    
   SET @cUOM                 = ''    
   SET @cLightMode           = ''    
   SET @cDisplayValue        = ''    
   SET @cCaseID              = ''    
   SET @cLabelNo             = ''    
   --SET @cConsigneeKey        = ''    
   SET @cGenLabelNoSP        = ''    
   SET @cExecStatements      = ''    
   SET @cExecArguments       = ''    
   SET @cPickDetailKey       = ''    
   SET @nPDQty               = 0     
   SET @cNewPickDetailKey    = ''    
   SET @nNewPTLTranKey       = 0    
   --SET @cDeviceID            = ''    
    
   SET @cUserName            = ''    
   SET @cLightModeStatic     = ''    
   SET @cSuggUOM             = ''    
   SET @cPrefUOM             = ''    
   SET @cWaveKey             = ''    
   SET @cDeviceProfileKey    = ''    
   SET @cDeviceID            = ''    
   SET @cDeviceProfileLogKey = ''    
   SET @cLightModeFULL       = ''    
   SET @cVarLightMode        = ''    
   SET @cLightPriority       = ''    
   SET @cHoldUserID          = ''    
   SET @cHoldDeviceProfileLogKey = ''    
   SET @cHoldSuggSKU         = ''    
   SET @cHoldUOM             = ''    
   SET @cPrevDevicePosition  = ''    
   SET @cLightModeHOLD       = ''    
   SET @cHoldConsigneeKey    = ''    
   SET @nHoldPTLKey          = 0     
   SET @cModuleAddress       = ''    
   SET @nVarPTLKey           = 0    
   SET @cFullCosngineeKey    = ''    
   SET @cHoldCondition       = ''    
   SET @cSuggDevicePosition  = ''    
   SET @cEndCondition        = ''    
   SET @cLoadKey             = ''    
   SET @cPTLConsigneeKey     = ''    
   SET @nActualQty           = 0    
   SET @nUOMQty              = 0     
   SET @cPDOrderKey          = ''    
   SET @nPackQty             = 0     
        
   SELECT @cLightModeStatic = Short    
   FROM dbo.CodelKup WITH (NOLOCK)     
   WHERE ListName = 'LightMode'    
   AND Code = 'White'    
    
   SELECT @cLightModeFULL = Short    
   FROM dbo.CodelKup WITH (NOLOCK)     
   WHERE ListName = 'LightMode'    
   AND Code = 'Red'    
    
   SET @nTranCount = @@TRANCOUNT    
    
   BEGIN TRAN    
   SAVE TRAN PackInsert    
        
   -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID    
   SELECT TOP 1   @cPTSLoc = PTL.DeviceID      
               ,@cPTLSKU = PTL.SKU     
               ,@nExpectedQty = PTL.ExpectedQty    
               ,@cLightSequence = PTL.LightSequence    
               ,@cOrderKey      = PTL.OrderKey    
               ,@cDropID        = PTL.DropID    
               ,@cDevicePosition = PTL.DevicePosition    
               ,@cLightMode      = PTL.LightMode    
               ,@cUOM            = PTL.UOM    
               --,@cWaveKey        = PTL.SourceKey    
               ,@cDeviceProfileLogKey = PTL.DeviceProfileLogKey    
               ,@cConsigneeKey   = PTL.ConsigneeKey    
               ,@cUserName       = PTL.AddWho    
               ,@cLoc          = PTL.Loc    
   FROM dbo.PTLTran PTL WITH (NOLOCK)       
   WHERE PTL.PTLKey = @nPTLKey    
        
   SELECT @cLoadKey = LoadKey,     
        @cWaveKey = UserDefine09      
   FROM dbo.Orders WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
        
--    SELECT @cPickSlipNo = PickHeaderKey     
--    FROM dbo.PickHeader WITH (NOLOCK)    
--    WHERE ExternOrderKey = @cLoadKey        
--    SELECT @cWaveKey = UserDefine09     
--    FROM dbo.Orders WITH (NOLOCK)    
--    WHERE OrderKey = @cOrderKey    
     
   IF @cLightSequence = '1' -- Display UOM & Qty    
   BEGIN    
      -- ReLight For Quantity    
      SET @cStatus = '1'         
    
      SELECT TOP 1 --@cUOM = PD.UOM     
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

      DECLARE @nPTLTranKey BIGINT

      DECLARE CUR_UPDATE_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey 
      FROM dbo.PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
      AND DeviceID = @cPTSLoc    
      AND DevicePosition <> @cDevicePosition    
      AND Status = '1'    
      AND UOM = @cUOM    
      AND StorerKey = @cStorerKey    

      OPEN CUR_UPDATE_PTLTRAN 
      FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey             
      WHILE @@FETCH_STATUS <> -1
      BEGIN                      
         UPDATE dbo.PTLTran WITH (ROWLOCK)     
            SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()     
         WHERE PTLKey = @nPTLTranKey
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 91502    
            SET @cErrMsg = 'Update PTLTran Fail'    
            GOTO RollBackTran      
         END     
         FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey                
      END
      CLOSE CUR_UPDATE_PTLTRAN
      DEALLOCATE CUR_UPDATE_PTLTRAN                          
             
      -- Terminate Primary Display    
      EXEC [dbo].[isp_DPC_TerminateModule]       
            @cStorerKey      
           ,@cPTSLoc        
           ,'1'    
           ,@b_Success    OUTPUT        
           ,@nErrNo       OUTPUT      
           ,@cErrMsg      OUTPUT      
                                                    
      UPDATE dbo.PTLTran WITH (ROWLOCK)    
      SET Status = '0', EditDate = GETDATE(), EditWho = SUSER_SNAME()    
      WHERE PTLKey = @nPTLKey    
    
      IF @@ERROR <> 0       
      BEGIN      
          SET @nErrNo = 91517    
          SET @cErrMsg = 'Update PTLTran Fail'    
          GOTO RollBackTran      
      END      
    
      SET @cDisplayValue = RIGHT(RTRIM(@cPrefUOM),2) + RIGHT('   ' + CAST(@nExpectedQty AS NVARCHAR(3)), 3)     
    
      EXEC [dbo].[isp_DPC_LightUpLoc]     
           @c_StorerKey = @cStorerKey     
          ,@n_PTLKey    = @nPTLKey        
          ,@c_DeviceID  = @cPTSLoc      
          ,@c_DevicePos = @cDevicePosition     
          ,@n_LModMode  = @cLightMode      
          ,@n_Qty       = @cDisplayValue           
          ,@b_Success   = @b_Success   OUTPUT      
          ,@n_Err       = @nErrNo      OUTPUT    
          ,@c_ErrMsg    = @cErrMsg     OUTPUT    
    
      UPDATE dbo.PTLTran WITH (ROWLOCK)     
      SET LightSequence = LightSequence + 1, EditDate = GETDATE(), EditWho = SUSER_SNAME()     
      WHERE PTLKey = @nPTLKey    
      IF @nErrNo <> 0       
      BEGIN      
          SET @nErrNo = 91503    
          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTran Fail'    
          SET @cErrMsg = 'Update PTLTran Fail'    
          GOTO RollBackTran      
      END     
   END -- IF @cLightSequence = '1'    
   IF @cLightSequence = '2'    
   BEGIN    
      IF @nQty > @nExpectedQty    
      BEGIN    
         SET @nQty = @nExpectedQty    
         --SET @nPTLQty = @nExpectedQty    
      END    
    
      /***************************************************/    
      /* Insert PackDetail                               */    
      /***************************************************/    
      SET @nCartonNo = 0    
      SET @cLabelLine = '00000'    
    
      -- Get Actual Qty --    
      SET @cPackKey = ''    
      SELECT @cPackKey = PackKey    
      FROM SKU (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   SKU = @cPTLSKU    
    
    
      SELECT     
        @nUOMQty = CASE @cUOM    
                   WHEN '1' THEN Pallet     
                   WHEN '2' THEN CaseCnt     
                   WHEN '3' THEN InnerPack     
                   WHEN '4' THEN CONVERT(INT,OtherUnit1)     
                   WHEN '5' THEN CONVERT(INT,OtherUnit2)     
                   WHEN '6' THEN 1     
                   WHEN '7' THEN 1     
                   ELSE 0     
                   END     
      FROM PACK (NOLOCK)     
      WHERE PackKey = @cPackKey     
                 
      SET @nActualQty = @nQty * @nUOMQty    
           
                          
--      DECLARE CursorPackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
--      SELECT DISTINCT     
--        PTL.CaseID -- @cCaseID    
--      , PD.CaseID  -- @cLabelNo    
--      , PTL.ConsigneeKey     
--      FROM dbo.PTLTran PTL WITH (NOLOCK)    
--      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.SKU = PTL.SKU AND PD.UOM = PTL.UOM    
--      WHERE PTL.Status            = '1'    
--      AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey    
--      AND PTL.PTLKey              = @nPTLKey    
--      AND PTL.SKU                 = @cPTLSKU    
--      AND PTL.UOM                 = @cUOM    
--      AND PD.Status               = '5'    
--      AND PD.StorerKey            = @cStorerKey    
--      AND PD.WaveKey              = @cWaveKey    
--      -- GROUP BY PTL.CaseID, PD.CaseID, PTL.ConsigneeKey    
--      ORDER BY PTL.CaseID    

      SELECT @cCaseID = PTL.CaseID, 
             @cPTLConsigneeKey = PTL.ConsigneeKey
      FROM dbo.PTLTran PTL WITH (NOLOCK) 
      WHERE PTL.PTLKey = @nPTLKey 
      AND   PTL.Status = '1'
    
      DECLARE CursorPackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT PD.CaseID       
      FROM dbo.WAVEDETAIL AS WD WITH (INDEX(IX_WAVEDETAIL_WaveKey), NOLOCK)     
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey AND PD.WaveKey = @cWaveKey
      WHERE PD.StorerKey = @cStorerKey  
      AND PD.SKU     = @cPTLSKU 
      AND PD.UOM     = @cUOM    
      AND PD.Status  = '5'        
      AND WD.WaveKey = @cWaveKey        
                          
      OPEN CursorPackDetail                
    
      --FETCH NEXT FROM CursorPackDetail INTO @cCaseID, @cLabelNo, @cPTLConsigneeKey     
      FETCH NEXT FROM CursorPackDetail INTO @cLabelNo     
     
      WHILE @@FETCH_STATUS <> -1         
      BEGIN    
       IF ISNULL(RTRIM(@cLabelNo),'') = ''     
       BEGIN    
            -- Update PickDetail.CaseID = LabelNo, Split Line if there is Short Pick and Create PackDetail    
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
            SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey    
            FROM dbo.Pickdetail PD WITH (NOLOCK)    
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber    
            WHERE PD.DropID = @cDropID    
            AND PD.Status = '5'    
            AND PD.SKU    = @cPTLSKU    
            AND ISNULL(PD.CaseID,'')  = ''    
            AND PD.UOM = @cUOM    
            AND O.ConsigneeKey = @cPTLConsigneeKey    
            ORDER BY PD.SKU    
    
            OPEN  CursorPickDetail    
    
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey    
    
            WHILE @@FETCH_STATUS <> -1         
            BEGIN    
               /***************************************************/    
               /* Insert PackHeader                               */    
               /***************************************************/    
           
               SET @cPickSlipNo = ''    
               IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE OrderKey = ISNULL(RTRIM(@cPDOrderKey),''))    
               BEGIN    
                  EXECUTE nspg_GetKey             
                    'PICKSLIP'          
                  ,  9          
                  ,  @cPickslipno       OUTPUT          
                  ,  @b_success         OUTPUT    
                  ,  @nErrNo            OUTPUT      
                  ,  @cErrMsg           OUTPUT      
                          
                  SET @cPickslipno = 'P' + @cPickslipno       
    
                  INSERT INTO dbo.PACKHEADER    
                  (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS])     
                  VALUES    
                  (@cPickSlipNo, @cStorerKey, @cPDOrderKey, '', '', '', '', 0, '', '0')     
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 91504    
                     SET @cErrMsg = 'Error Update PackDetail table.'    
                     GOTO RollBackTran    
                  END    
                      
                  INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate )     
                  VALUES (@cPickSlipNo, GetDate(), suser_sname(), '')     
                      
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 91530    
                     SET @cErrMsg = 'Error Ins PickingInfo table.'    
                     GOTO RollBackTran    
                  END    
                      
               END        
               ELSE     
               BEGIN    
                  SELECT @cPickSlipNo = PickslipNo    
                  FROM dbo.PackHeader WITH (NOLOCK)    
                  WHERE OrderKey = @cPDOrderKey    
               END      
                                   
                 
               SET @nPackQty = 0     
    
               IF @nPDQty=@nActualQty      
               BEGIN      
                  -- Confirm PickDetail      
                  UPDATE dbo.PickDetail WITH (ROWLOCK)      
                     SET CaseID = @cCaseID      
                       , EditDate = GetDate()    
                       , EditWho  = suser_sname()    
                       , UOMQty   = @nQty
                       , Trafficcop = NULL    
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'    
    
                  SET @nErrNo = @@ERROR      
                  IF @nErrNo <> 0      
                  BEGIN      
                     SET @nErrNo = 91510    
                     SET @cErrMsg = 'Update PickDetail Fail'    
                     GOTO RollBackTran      
                  END      
    
                  SET @nPackQty = @nPDQty                           
               END      
               ELSE      
               IF @nActualQty > @nPDQty      
               BEGIN      
                  -- Confirm PickDetail      
                  UPDATE dbo.PickDetail WITH (ROWLOCK)      
                  SET    CaseID = @cCaseID     
                      , EditDate = GetDate()    
                      , EditWho  = suser_sname()  
                      , UOMQty   = @nQty  
                      , Trafficcop = NULL    
                  WHERE  PickDetailKey = @cPickDetailKey    
                  AND Status = '5'      
                   
                  SET @nErrNo = @@ERROR      
                  IF @nErrNo <> 0      
                  BEGIN      
                     SET @nErrNo = 91511    
                     SET @cErrMsg = 'Update PickDetail Fail'    
                     GOTO RollBackTran      
                  END      
                       
                  SET @nPackQty = @nPDQty        
               END      
               ELSE      
               IF @nActualQty < @nPDQty AND @nActualQty > 0      
               BEGIN      
                  IF @nActualQty > 0     
                  BEGIN                         
                     EXECUTE dbo.nspg_GetKey      
                            'PICKDETAILKEY',      
                            10 ,      
                            @cNewPickDetailKey OUTPUT,      
                            @b_success         OUTPUT,      
                            @nErrNo            OUTPUT,      
                            @cErrMsg           OUTPUT      
    
                     IF @b_success<>1      
                     BEGIN      
                        SET @nErrNo = 91512      
                        SET @cErrMsg = 'Get PickDetailKey Fail'    
                        GOTO RollBackTran      
                     END      
                   
                     -- Create a new PickDetail to hold the balance      
                     INSERT INTO dbo.PICKDETAIL (      
                          CaseID                  ,PickHeaderKey   ,OrderKey      
                         ,OrderLineNumber         ,LOT             ,StorerKey      
                         ,SKU                     ,AltSKU          ,UOM      
                         ,UOMQTY                  ,QTYMoved        ,STATUS      
                         ,DropID                  ,LOC             ,ID      
                         ,PackKey                 ,UpdateSource    ,CartonGroup      
                         ,CartonType              ,ToLoc           ,DoReplenish      
                         ,ReplenishZone           ,DoCartonize     ,PickMethod      
                         ,WaveKey                 ,EffectiveDate   ,ArchiveCop      
                         ,ShipFlag                ,PickSlipNo      ,PickDetailKey      
                         ,QTY                     ,TrafficCop      ,OptimizeCop      
                         ,TaskDetailkey      
                         ,Channel_ID )      --(cc01)
                     SELECT  CaseID               ,PickHeaderKey   ,OrderKey      
                            ,OrderLineNumber      ,Lot             ,StorerKey      
                            ,SKU                  ,AltSku          ,UOM      
                            ,UOMQTY               ,QTYMoved        ,Status    
                            ,DropID               ,LOC             ,ID      
                            ,PackKey              ,UpdateSource    ,CartonGroup      
                            ,CartonType           ,ToLoc           ,DoReplenish      
                            ,ReplenishZone        ,DoCartonize     ,PickMethod      
                            ,WaveKey              ,EffectiveDate   ,ArchiveCop      
                            ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey      
                            ,@nPDQty - @nActualQty,NULL            ,'1'  --OptimizeCop,      
                            ,TaskDetailKey 
                            ,Channel_ID --(cc01)     
                     FROM   dbo.PickDetail WITH (NOLOCK)      
                     WHERE  PickDetailKey = @cPickDetailKey      
                
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @nErrNo = 91513      
                        SET @cErrMsg = 'Insert PickDetail Fail'    
                        GOTO RollBackTran      
                     END      
                                   
                     -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop      
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)      
                     UPDATE dbo.PickDetail WITH (ROWLOCK)      
                     SET    QTY = @nActualQty    
                           , EditDate = GetDate()    
                           , EditWho  = suser_sname()   
                           , UOMQty   = @nQty 
                           , Trafficcop = NULL     
                     WHERE  PickDetailKey = @cPickDetailKey    
                     AND Status = '5'      
                   
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @nErrNo = 91514      
                        SET @cErrMsg = 'Update PickDetail Fail'    
                        GOTO RollBackTran      
                     END      
                                     
                     -- Confirm orginal PickDetail with exact QTY      
                     UPDATE dbo.PickDetail WITH (ROWLOCK)      
                     SET    CaseID = @cCaseID    
                           , EditDate = GetDate()    
                           , EditWho  = suser_sname() 
                           , UOMQty   = @nQty  
                           , Trafficcop = NULL    
                     WHERE  PickDetailKey = @cPickDetailKey      
                     AND Status = '5'    
                            
                     SET @nErrNo = @@ERROR      
                     IF @nErrNo <> 0      
                     BEGIN      
                        SET @nErrNo = 91515    
                        SET @cErrMsg = 'Update PickDetail Fail'    
                        GOTO RollBackTran      
                     END      
                         
                     SET @nPackQty = @nActualQty     
                  
                  END    
               END -- @nActualQty < @nPDQty     
               ELSE IF @nActualQty = 0     
               BEGIN    
              
                  UPDATE dbo.PickDetail WITH (ROWLOCK)      
                  SET    Status = '4'    
                        , EditDate = GetDate()    
                        , EditWho  = suser_sname()    
                        --, Trafficcop = NULL (ChewKP02)    
                  WHERE  PickDetailKey = @cPickDetailKey    
                  AND Status = '5'      
                   
                  IF @@ERROR <> 0      
                  BEGIN      
                      SET @nErrNo = 91516      
                      SET @cErrMsg = 'Update PickDetail Fail'    
                      GOTO RollBackTran      
                  END      
                  SET @nPackQty = 0                 
               END -- IF @nActualQty = 0    
                   
               IF @nActualQty > 0      
               BEGIN     
                  IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                            WHERE PickSlipNo = @cPickSlipNo    
                              AND LabelNo = @cCaseID    
                              AND SKU     = @cPTLSKU )    
                  BEGIN                                      
                     UPDATE PACKDETAIL WITH (ROWLOCK)    
                       SET Qty = Qty + @nPackQty, EditDate = GETDATE(), EditWho = SUSER_SNAME()    
                     WHERE PickSlipNo = @cPickSlipNo    
                      AND DropID = @cCaseID    
                      AND SKU = @cPTLSKU    
                     IF @@ERROR <> 0     
                     BEGIN    
                        SET @nErrNo = 91506    
                        SET @cErrMsg = 'Update PackDetail Table Fail'    
                        GOTO RollBackTran    
                     END     
                  END    
                  ELSE    
                  BEGIN    
                     INSERT INTO dbo.PACKDETAIL    
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)    
                     VALUES    
                     (@cPickSlipNo, @nCartonNo, @cCaseID, @cLabelLine, @cStorerKey, @cPTLSKU,    
                      @nPackQty, @cCaseID,@cDropID)    
                     IF @@ERROR <> 0    
                     BEGIN    
                         SET @nErrNo = 91507    
                         SET @cErrMsg = 'Insert PackDetail Table failed'                             
                         GOTO RollBackTran    
                     END    
                  END    
                                   
                 -- Pack Confirm --     
                 SET @nTotalPickedQty = 0    
                 SET @nTotalPackedQty = 0    
                     
                 SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
                 FROM dbo.PickDetail PD WITH (NOLOCK)     
                 WHERE PD.OrderKey = @cPDOrderKey    
                   AND PD.StorerKey = @cStorerKey    
                   AND PD.Status    IN ('0', '5')    
                
                 SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0)     
                 FROM dbo.PackDetail PD WITH (NOLOCK)     
                 WHERE PD.PickSlipNo = @cPickSlipNo     
    
                   
                 IF @nTotalPickedQty = @nTotalPackedQty    
                 BEGIN    
                    UPDATE PackHeader WITH (ROWLOCK)    
                    SET Status = '9'    
                    WHERE PickSlipNo = @cPickSlipNo    
                        
                    IF @@ERROR <> 0     
                    BEGIN    
                       SET @nErrNo = 91522    
                       --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHdrFail'    
                       SET @cErrMsg = 'Update PackHeader'     
                       GOTO RollBackTran    
                    END    
                 END       
    
                 SET @nActualQty = @nActualQty - @nPDQty -- OffSet PickQty     
                 
                 -- (ChewKP01) 
                 IF @nActualQty < 0 
                 BEGIN 
                     SET @nActualQty = 0 
                 END
                  
              END  -- IF @nActualQty > 0     
                  
              IF @nActualQty = 0     
                 BREAK    
                             
              FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey                 
          END -- While Loop    
          CLOSE CursorPickDetail             
          DEALLOCATE CursorPickDetail    
       END -- @cLabelNo = ''    
       ELSE     
       BEGIN -- If @cLabelNo <> ''    
          SET @cPickDetailKey = ''     
          SET @nPDQty         = ''    
          SET @cPDOrderKey    = ''    
                                
          DECLARE CursorPackCaseID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
          SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey    
          FROM dbo.Pickdetail PD WITH (NOLOCK)    
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
          INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber    
          WHERE PD.DropID = @cDropID    
          AND PD.Status = '5'    
          AND PD.SKU    = @cPTLSKU    
          AND ISNULL(PD.CaseID,'')  = @cLabelNo    
          AND PD.UOM = @cUOM    
          AND O.ConsigneeKey = @cPTLConsigneeKey    
          ORDER BY PD.SKU    
                                
          OPEN  CursorPackCaseID    
              
          FETCH NEXT FROM CursorPackCaseID INTO @cPickDetailKey, @nPDQty, @cPDOrderKey    
              
          WHILE @@FETCH_STATUS <> -1         
          BEGIN      
                
             SET @cPickSlipNo = ''    
             IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE OrderKey = ISNULL(RTRIM(@cPDOrderKey),''))    
             BEGIN    
                EXECUTE nspg_GetKey             
                     'PICKSLIP'          
                  ,  9          
                  ,  @cPickslipno       OUTPUT          
                  ,  @b_success         OUTPUT    
                  ,  @nErrNo            OUTPUT      
                  ,  @cErrMsg           OUTPUT      
                             
                SET @cPickslipno = 'P' + @cPickslipno       
                    
                INSERT INTO dbo.PACKHEADER    
                (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS])     
                VALUES    
                (@cPickSlipNo, @cStorerKey, @cPDOrderKey, '', '', '', '', 0, '', '0')     
                    
                IF @@ERROR <> 0    
                BEGIN    
                   SET @nErrNo = 91525    
                   SET @cErrMsg = 'Error Update PackDetail table.'    
                   GOTO RollBackTran    
                END    
             END        
             ELSE     
             BEGIN    
                SELECT @cPickSlipNo = PickslipNo    
                FROM dbo.PackHeader WITH (NOLOCK)    
                WHERE OrderKey = @cPDOrderKey    
             END      
                 
                 
             IF @nActualQty > 0      
             BEGIN     
                    
                    
                -- Prevent OverPack --     
                SET @nTotalPickedQty = 0    
                SET @nTotalPackedQty = 0    
                    
                SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
                FROM dbo.PickDetail PD WITH (NOLOCK)     
                WHERE PD.OrderKey = @cPDOrderKey    
                  AND PD.StorerKey = @cStorerKey    
                  AND PD.Status    IN ( '0', '5' )     
                  AND PD.SKU = @cPTLSKU    
            
                SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0)     
                FROM dbo.PackDetail PD WITH (NOLOCK)     
                WHERE PD.PickSlipNo = @cPickSlipNo     
                AND PD.SKU = @cPTLSKU    
                 
                IF (ISNULL(@nTotalPackedQty,0) + ISNULL(@nPDQty,0)) > ISNULL(@nTotalPickedQty,0)    
                BEGIN    
                   GOTO PROCESS_PACKCONFIRM    
                END     
                    
                IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                          WHERE PickSlipNo = @cPickSlipNo    
                          AND LabelNo = @cLabelNo    
                          AND SKU     = @cPTLSKU )    
                BEGIN                                      
                   UPDATE PACKDETAIL WITH (ROWLOCK)    
                     SET Qty = Qty + @nPDQty, EditDate = GETDATE(), EditWho = SUSER_SNAME()    
                   WHERE PickSlipNo = @cPickSlipNo    
                     AND DropID = @cLabelNo    
                     AND SKU = @cPTLSKU    
                         
                   IF @@ERROR <> 0     
                   BEGIN    
                      SET @nErrNo = 91523    
                      SET @cErrMsg = 'Update PackDetail Table Fail'    
                      GOTO RollBackTran    
                   END     
                END    
                ELSE    
                BEGIN    
                   INSERT INTO dbo.PACKDETAIL    
                   (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)    
                   VALUES    
                   (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPTLSKU,    
                    @nPDQty, @cLabelNo,@cLabelNo)    
                                              
                   IF @@ERROR <> 0    
                   BEGIN    
                        SET @nErrNo = 91524    
                        SET @cErrMsg = 'Insert PackDetail Table failed'    
                        GOTO RollBackTran    
                   END    
                END             
                    
                PROCESS_PACKCONFIRM:    
                          
                -- Pack Confirm --     
                SET @nTotalPickedQty = 0    
                SET @nTotalPackedQty = 0    
                    
                SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
                FROM dbo.PickDetail PD WITH (NOLOCK)     
                WHERE PD.OrderKey = @cPDOrderKey    
                  AND PD.StorerKey = @cStorerKey    
                  AND PD.Status    IN ( '0', '5' )     
             
                SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0)     
                FROM dbo.PackDetail PD WITH (NOLOCK)     
                WHERE PD.PickSlipNo = @cPickSlipNo     
    
                  
                IF @nTotalPickedQty = @nTotalPackedQty    
                BEGIN    
                   UPDATE PackHeader WITH (ROWLOCK)    
                   SET Status = '9'    
                   WHERE PickSlipNo = @cPickSlipNo    
                                            
                   IF @@ERROR <> 0     
                   BEGIN    
                      SET @nErrNo = 91522    
                      SET @cErrMsg = 'Update PackHeader'     
                      GOTO RollBackTran    
                   END    
                END       
                       
                SET @nActualQty = @nActualQty - @nPDQty -- OffSet PickQty      
             END -- IF @nActualQty > 0     
             IF @nActualQty = 0     
                BREAK    
                      
             FETCH NEXT FROM CursorPackCaseID INTO @cPickDetailKey, @nPDQty, @cPDOrderKey    
          END    
          CLOSE CursorPackCaseID             
          DEALLOCATE CursorPackCaseID                                
       END    
       --FETCH NEXT FROM CursorPackDetail INTO @cCaseID, @cLabelNo, @cPTLConsigneeKey      
       FETCH NEXT FROM CursorPackDetail INTO @cLabelNo 
    END    
    CLOSE CursorPackDetail                
    DEALLOCATE CursorPackDetail       
        
      
                    
    UPDATE PTLTRAN WITH (ROWLOCK)               
       SET STATUS  = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()             
    WHERE PTLKey = @nPTLKey      
      
    IF @@ERROR <> 0   
    BEGIN  
        
      UPDATE PTLTRAN WITH (ROWLOCK)               
       SET STATUS  = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()             
      WHERE PTLKey = @nPTLKey      
        
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 91531    
         SET @cErrMsg = 'Update PTLTRAN Failed'     
         GOTO RollBackTran    
      END  
    END      
      
      
                    
    -- Terminate Primary Display    
    EXEC [dbo].[isp_DPC_TerminateModule]       
           @cStorerKey      
          ,@cPTSLoc        
          ,'1'    
          ,@b_Success    OUTPUT        
          ,@nErrNo       OUTPUT      
          ,@cErrMsg      OUTPUT      
                          
    UPDATE dbo.DropID WITH (ROWLOCK)    
    SET Status = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()     
    WHERE DropID = @cCaseID    
    IF @@ERROR <> 0    
    BEGIN    
       SET @nErrNo = 91520    
       SET @cErrMsg = 'Update DropID Fail'     
       GOTO RollBackTran    
    END     
    
    -- Relight when Qty <> 0 -- (ChewKP01)
    SET @nNewExpectedQty = @nExpectedQty - @nQty 
   
   
    IF @nNewExpectedQty > 0 AND @nQty <> 0 
    BEGIN 
        -- INSERT Remaining Qty -- 
        INSERT INTO PTLTran
            (
               -- PTLKey -- this column value is auto-generated
               IPAddress,  DeviceID,     DevicePosition,
               [Status],   PTL_Type,     DropID,
               OrderKey,   Storerkey,    SKU,
               LOC,        ExpectedQty,  Qty,
               Remarks,    MessageNum,   Lot,
               DeviceProfileLogKey, RefPTLKey, ConsigneeKey,
               CaseID, LightMode, LightSequence, AddWho, SourceKey, UOM
            )
        SELECT  IPAddress,  DeviceID,     DevicePosition,
               '0',   PTL_Type,     DropID,
               OrderKey,   Storerkey,    SKU,
               LOC,        @nExpectedQty - @nQty, 0,
               Remarks,    '',   Lot,
               DeviceProfileLogKey, @nPTLKey, ConsigneeKey,
               CaseID, LightMode, '2', AddWho, SourceKey, UOM
        FROM dbo.PTLTran WITH (NOLOCK)
        WHERE PTLKEy = @nPTLKey
   
       
        SELECT @nNewPTLTranKey  = PTLKey
        FROM dbo.PTLTran WITH (NOLOCK)
        WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))
        AND Status = '0'
        AND SKU = @cPTLSKU
        AND DeviceID = @cPTSLoc
        AND LightSequence = '2'
           
            
        SELECT @cPrefUOM = Short     
        FROM dbo.CodeLkup WITH (NOLOCK)    
        WHERE ListName = 'LightUOM'    
        AND Code = @cUOM    
        
        SET @cDisplayValue = ''
        SET @cDisplayValue = RIGHT(RTRIM(@cPrefUOM),2) + RIGHT('   ' + CAST(@nNewExpectedQty AS NVARCHAR(3)), 3)   
      
        
   
        EXEC [dbo].[isp_DPC_LightUpLoc] 
         @c_StorerKey = @cStorerKey 
        ,@n_PTLKey    = @nNewPTLTranKey    
        ,@c_DeviceID  = @cPTSLoc  
        ,@c_DevicePos = @cDevicePosition 
        ,@n_LModMode  = @cLightMode  
        ,@n_Qty       = @cDisplayValue     
        ,@b_Success   = @b_Success   OUTPUT  
        ,@n_Err       = @nErrNo      OUTPUT
        ,@c_ErrMsg    = @cErrMsg     OUTPUT  
        
        
        SET @nNewPTLTranKey = 0 

        -- Update PTLTranKey to 9 
        UPDATE dbo.PTLTran
        SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()
        WHERE PTLKey = @nPTLKey
        
        GOTO QUIT
    END  
    
    IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                    WHERE SourceKey = @cWaveKey     
                    AND Status IN ('0', '1' )     
                    AND PTLKey <> @nPTLKey    
                    AND AddWho = @cUserName  )     
    BEGIN    
--        SET @nTotalPickedQty = 0    
--        SET @nTotalPackedQty = 0    
--                        
--        SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
--        FROM dbo.PickDetail PD WITH (NOLOCK)     
--        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
--        WHERE PD.StorerKey = @cStorerKey    
--          AND PD.Status    IN ('0','5')    
--          AND O.ConsigneeKey = @cConsigneeKey    
--          AND PD.WaveKey     = @cWaveKey    
--                           
--        SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)     
--        FROM dbo.PackDetail PackD WITH (NOLOCK)    
--        INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo     
--        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey    
--        WHERE O.ConsigneeKey = @cConsigneeKey    
--        AND O.UserDefine09 = @cWaveKey                        
                        
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
               CaseID, LightMode, LightSequence, AddWho, SourceKey    
            )    
        SELECT  IPAddress,  DeviceID,     DevicePosition,    
               '0',         PTL_Type,     DropID,    
               OrderKey,    Storerkey,    SKU,    
               LOC,         @nExpectedQty,  0,    
               'END',       @cMessageNum,   Lot,    
               DeviceProfileLogKey, @nPTLKey, ConsigneeKey,    
               CaseID, @cLightMode, '4', AddWho, SourceKey    
        FROM dbo.PTLTran WITH (NOLOCK)    
        WHERE PTLKEy = @nPTLKey    
                       
        SELECT @nNewPTLTranKey  = PTLKey    
        FROM dbo.PTLTran WITH (NOLOCK)    
        WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
        AND Status = '0'    
        AND Remarks = 'END'    
            
        EXEC [dbo].[isp_DPC_LightUpLoc]     
         @c_StorerKey = @cStorerKey     
        ,@n_PTLKey    = @nNewPTLTranKey        
        ,@c_DeviceID  = @cPTSLoc      
        ,@c_DevicePos = @cDevicePosition     
        ,@n_LModMode  = @cLightMode      
        ,@n_Qty       = 'END'           
        ,@b_Success   = @b_Success   OUTPUT      
        ,@n_Err       = @nErrNo      OUTPUT    
        ,@c_ErrMsg    = @cErrMsg     OUTPUT      
                       
        SET @nNewPTLTranKey = 0   
            
        -- No More Record Goto Quit -- Check Other Location     
        SET @cEndCondition = '1'     
        GOTO PROCESS_HOLD_LOC            
    END -- records not exisys in PTLTran    
    ELSE   
    BEGIN   
      -- Start Logging   
      DECLARE @cSQLCondition NVARCHAR(10)   
            , @nCountLoc     INT  
        
      SELECT @nCountLoc = Count(Distinct DeviceID)   
      FROM dbo.PTLTran WITH (NOLOCK)   
      WHERE SourceKey = @cWaveKey  
      AND AddWho = @cUserName  
      AND Status In ( '0' , '1' )   
        
      IF @nCountLoc <= 3  
      BEGIN  
           
         INSERT INTO PTLTranLog    
            (    
               PTLKey, -- PTLKey -- this column value is auto-generated    
               IPAddress,  DeviceID,     DevicePosition,    
               [Status],   PTL_Type,     DropID,    
               OrderKey,   Storerkey,    SKU,    
               LOC,        ExpectedQty,  Qty,    
               Remarks,    MessageNum,   Lot,    
               DeviceProfileLogKey, RefPTLKey, ConsigneeKey,    
               CaseID, LightMode, LightSequence, AddWho, SourceKey , Editdate  
            )    
        SELECT  PTLKEy, IPAddress,  DeviceID,     DevicePosition,    
               Status,         PTL_Type,     DropID,    
               OrderKey,    Storerkey,    SKU,    
               LOC,         ExpectedQty,  Qty,    
               Remarks,       MessageNum,   Lot,    
               DeviceProfileLogKey, RefPTLKey, ConsigneeKey,    
               CaseID, LightMode,LightSequence, AddWho, SourceKey  , Editdate   
        FROM dbo.PTLTran WITH (NOLOCK)    
        WHERE SourceKey = @cWaveKey  
        AND AddWho = @cUserName  
        AND Status In ( '0' , '1' )   
          
          
      ENd  
        
        
    END  
      
  
                    
     -- If Same Location have more SKU to be PTS     
     IF EXISTS ( SELECT 1 FROM dbo.PTLTran PTL WITH (NOLOCK)    
                 --INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileLogKey = PTL.DeviceProfileLogKey    
                 WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey    
                 --AND D.Priority = '1'     
                 AND PTL.Status = '0'    
                 AND PTL.DeviceID = @cPTSLoc    
                 AND PTL.StorerKey  = @cStorerKey  )      
     BEGIN     
        SELECT TOP 1 @cSuggLoc       = D.DeviceID    
                    ,@cSuggSKU       = PTL.SKU    
                    ,@cSuggUOM       = PTL.UOM    
        FROM dbo.PTLTran PTL WITH (NOLOCK)    
        INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey    
        WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey    
        AND D.Priority = '1'     
        AND PTL.Status = '0'    
        AND PTL.DeviceID = @cPTSLoc     
        AND D.StorerKey  = @cStorerKey    
        Order by D.DeviceID, PTL.SKU    
    
        SELECT @cSuggDevicePosition = DevicePosition     
        FROM dbo.DeviceProfile WITH (NOLOCK)     
        WHERE DeviceID = @cSuggLoc    
        AND Priority = '1'    
        AND StorerKey = @cStorerKey    
            
                       
        DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
            
        SELECT PTLKey, DevicePosition, LightMode    
        FROM dbo.PTLTran PTL WITH (NOLOCK)    
        WHERE Status             = '0'    
          --AND AddWho             = @cUserName    
          AND DeviceID           = @cSuggLoc       
          AND SKU                = @cSuggSKU    
          AND UOM                = @cSuggUOM    
          AND DeviceProfileLogKey = @cDeviceProfileLogKey    
        ORDER BY DeviceID, PTLKey    
            
        OPEN CursorLightUp                
            
        FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode    
            
            
        WHILE @@FETCH_STATUS <> -1         
        BEGIN    
               
           IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
     WHERE DeviceID = @cSuggLoc    
                       AND DevicePosition = @cModuleAddress    
                       AND Priority = '0'    
                       AND StorerKey = @cStorerKey )     
           BEGIN    
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) )    
           END                      
           ELSE    
           BEGIN    
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) )    
           END    
               
             
               
           EXEC [dbo].[isp_DPC_LightUpLoc]     
                 @c_StorerKey = @cStorerKey     
                ,@n_PTLKey    = @nVarPTLKey        
                ,@c_DeviceID  = @cSuggLoc      
                ,@c_DevicePos = @cModuleAddress     
                ,@n_LModMode  = @cLightMode      
                ,@n_Qty       = @cDisplayValue           
                ,@b_Success   = @b_Success   OUTPUT      
                ,@n_Err       = @nErrNo      OUTPUT    
                ,@c_ErrMsg    = @cErrMsg     OUTPUT     
            
--           IF @@ERROR <> 0     
--           BEGIN    
--                 SET @nErrNo = 91304    
--                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightUpFail'    
--               GOTO RollBackTran    
--           END    
                    
                
           FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode    
        END    
        CLOSE CursorLightUp                
        DEALLOCATE CursorLightUp      
     END         
     ELSE         
     BEGIN        
               
        SELECT TOP 1 @cSuggLoc       = D.DeviceID    
                               ,@cSuggSKU       = PTL.SKU    
                               ,@cSuggUOM       = PTL.UOM    
                               --,@nNewPTLTranKey = PTL.PTLKey    
                               ,@cSuggDropID    = PTL.DropID    
                               --,@cSuggDevicePosition = PTL.DevicePosition    
        FROM dbo.PTLTran PTL WITH (NOLOCK)    
        INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey    
        WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey    
        AND D.Priority = '1'     
        AND PTL.Status = '0'    
        AND PTL.StorerKey = @cStorerKey    
        Order by D.DeviceID, PTL.SKU    
                  
        SELECT @cSuggDevicePosition = DevicePosition     
        FROM dbo.DeviceProfile WITH (NOLOCK)     
        WHERE DeviceID = @cSuggLoc    
        AND Priority = '1'    
        AND StorerKey = @cStorerKey    
            
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
           SET @cHoldCondition = '1'    
        END    
            
        IF EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)     
                    WHERE DevicePosition = @cSuggDevicePosition     
                    AND Status  = '1' )     
        BEGIN     
           SET @cHoldCondition = '1'    
        END       
    
        IF EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)     
                    WHERE DevicePosition = @cSuggDevicePosition     
                    AND Remarks = 'HOLD'    
                    AND LightSequence = '0' )     
        BEGIN     
           SET @cHoldCondition = '1'    
        END       
                  
        IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                    WHERE Status = '1'    
                    AND DeviceID = @cSuggLoc    
                    AND DeviceProfileLogKey <> @cDeviceProfileLogKey  )     
        BEGIN     
           SET @cHoldCondition = '1'    
        END       
                  
        IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                    WHERE Status = '1'    
                    AND DevicePosition = @cSuggDevicePosition     
                    AND DeviceProfileLogKey <> @cDeviceProfileLogKey  )     
        BEGIN     
           SET @cHoldCondition = '1'    
        END       
            
        IF @cHoldCondition = '1'    
        BEGIN     
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
           SELECT  IPAddress,  @cSuggLoc,     DevicePosition,    
                   '0',   PTL_Type,     DropID,    
                   OrderKey,   Storerkey,    @cSuggSKU,    
                   LOC,        ExpectedQty,  0,    
                   'HOLD',    @cMessageNum,   Lot,    
                   DeviceProfileLogKey, @nPTLKey, ConsigneeKey,    
                   CaseID, @cLightModeStatic, '0', AddWho, @cSuggUOM, SourceKey    
           FROM dbo.PTLTran WITH (NOLOCK)    
           WHERE PTLKEy = @nPTLKey    
            
               
           SELECT @nNewPTLTranKey  = PTLKey    
           FROM dbo.PTLTran WITH (NOLOCK)    
           WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
           AND Status = '0'    
           AND Remarks = 'HOLD'    
                          
          
           EXEC [dbo].[isp_DPC_LightUpLoc]     
            @c_StorerKey = @cStorerKey     
           ,@n_PTLKey    = @nNewPTLTranKey        
           ,@c_DeviceID  = @cPTSLoc      
           ,@c_DevicePos = @cDevicePosition     
           ,@n_LModMode  = @cLightModeStatic      
           ,@n_Qty       = 'HOLD'           
           ,@b_Success   = @b_Success   OUTPUT      
           ,@n_Err       = @nErrNo      OUTPUT    
           ,@c_ErrMsg    = @cErrMsg     OUTPUT      
               
               
           UPDATE  PTLTran WITH (ROWLOCK)     
           SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME()    
           WHERE PTLKey = @nNewPTLTranKey    
               
           SET @nNewPTLTranKey = 0     
               
           -- No More Record Goto Quit     
           GOTO QUIT    
        END -- IF @cHoldCondition = '1'    
     END -- Not Exists in PTLTran    
         
                    
     -- Start to Light Up Next Location --     
     -- Display Next Location on Current Light Position --     
         
      
         
     IF ISNULL(RTRIM(@cPTSLoc),'' )  <> ISNULL(RTRIM(@cSuggLoc),'')  AND ISNULL(RTRIM(@cSuggLoc),'')  <> ''    
     BEGIN     
        DECLARE CursorLightUpNextLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
        SELECT DevicePosition     
        FROM dbo.DeviceProfile WITH (NOLOCK)    
        WHERE DeviceID           = @cPTSLoc    
          AND StorerKey          = @cStorerKey    
          AND Priority           = '1'    
        ORDER BY DeviceID    
            
        OPEN CursorLightUpNextLoc                
            
        FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress    
            
        WHILE @@FETCH_STATUS <> -1         
        BEGIN    
--           IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
--                       WHERE DeviceID = @cPTSLoc    
--                        AND DevicePosition = @cModuleAddress    
--                        AND Priority = '0'    
--                        AND StorerKey = @cStorerKey )     
--           BEGIN    
--          SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggLoc) , 1 , 5 ) )    
--              SET @cVarLightMode = @cLightModeStatic    
--              SET @cLightPriority = '0'    
--           END                           
--           ELSE    
--           BEGIN    
              SET @cDisplayValue = RTRIM(@cSuggLoc)    
              SET @cVarLightMode = @cLightMode    
              SET @cLightPriority = '1'    
--           END    
               
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
            SELECT  IPAddress,  DeviceID,     @cModuleAddress,    
                    '0',   PTL_Type,     DropID,    
                    OrderKey,   Storerkey,    @cSuggSKU,    
                    @cSuggLoc,        @nExpectedQty,  0,    
                    @cSuggLoc,    '',   Lot,    
                    DeviceProfileLogKey, @nPTLKey, ConsigneeKey,    
                    CaseID, @cVarLightMode, '3', AddWho, @cSuggUOM, SourceKey    
            FROM dbo.PTLTran WITH (NOLOCK)    
            WHERE PTLKEy = @nPTLKey    
                 
                           
            SELECT @nNewPTLTranKey  = PTLKey    
            FROM dbo.PTLTran WITH (NOLOCK)    
            WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
            AND Status = '0'    
            AND DevicePosition = @cModuleAddress    
            AND Remarks = @cSuggLoc    
            AND LightSequence = '3'  
                 
              
    
            EXEC [dbo].[isp_DPC_LightUpLoc]     
                  @c_StorerKey = @cStorerKey     
                 ,@n_PTLKey    = @nNewPTLTranKey        
                 ,@c_DeviceID  = @cPTSLoc      
                 ,@c_DevicePos = @cModuleAddress     
                 ,@n_LModMode  = @cVarLightMode    
                 ,@n_Qty       = @cDisplayValue           
                 ,@b_Success   = @b_Success   OUTPUT      
                 ,@n_Err       = @nErrNo      OUTPUT    
                 ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                
                
    
--            IF @cLightPriority = '0'    
--            BEGIN    
--               UPDATE PTLTran WITH (ROWLOCK)     
--               SET Status = '9'    
--               WHERE PTLKey = @nNewPTLTranKey    
--            END    
              
            SET @nNewPTLTranKey = 0     
                
                 
            FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress      
         END    
         CLOSE CursorLightUpNextLoc                
         DEALLOCATE CursorLightUpNextLoc           
     END    
                    
          
       
      -- LIGHT UP HOLD LOCATION LOGIC --    
      -- Release Task for Next User on Previous Loc --    
      PROCESS_HOLD_LOC:    
                   
--      IF @cEndCondition = '1'     
--      BEGIN     
--         IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
--                         WHERE DeviceID = @cPTSLoc    
--                         AND Status = '1'    
--                         AND SourceKey = @cWaveKey    
--                         AND PTLKey <> @nPTLKey     
--                         AND Remarks NOT IN ('HOLD', 'FULL', 'END') )     
--         BEGIN    
--            SELECT TOP 1  @cHoldUserID = AddWho     
--                        , @cHoldDeviceProfileLogKey = DeviceProfileLogKey    
--                        , @cHoldSuggSKU = SKU    
--                        , @cHoldUOM     = UOM    
--                        , @cPrevDevicePosition = DevicePosition     
--                      , @cHoldConsigneeKey = ConsigneeKey    
--                        , @nHoldPTLKey  = PTLKey    
--            FROM dbo.PTLTran WITH (NOLOCK)    
--            WHERE Remarks = 'HOLD'    
--            AND DeviceID = @cPTSLoc    
--            AND LightSequence = '0'    
--            AND AddWho <> @cUserName    
--            Order By DeviceProfileLogKey    
--                
--            SELECT @cDeviceID = DeviceID     
--            FROM dbo.DeviceProfile WITH (NOLOCK)    
--            WHERE DevicePosition = @cPrevDevicePosition    
--    
--            SELECT @cLightModeHOLD = DefaultLightColor     
--            FROM rdt.rdtUser WITH (NOLOCK)    
--            WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')     
--    
--                
--            INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
--            VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '4', @cStorerKey , @nPTLKey , @cPTSLoc , @cHoldDeviceProfileLogKey,     
--                   @cDeviceID, @cPrevDevicePosition, @cHoldSuggSKU , @cHoldUOM , @cHoldConsigneeKey   )     
--    
--                
--            -- ChecK If It is First Record ? -- If Yes Light Up From RDT PTS Carton --     
--            IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
--                            WHERE Status = '9'    
--                            AND DeviceProfileLogKey = @cHoldDeviceProfileLogKey )     
--            BEGIN    
--               GOTO QUIT    
--            END    
--               
--            -- Not More PTLTran Quit --     
--      IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                            WHERE Status NOT IN ( '5','9' )     
--                            AND SourceKey = @cWaveKey    
--                            AND PTLKey <> @nPTLKey )     
--            BEGIN    
--               GOTO QUIT     
--            END    
--                
--            DECLARE CursorLightUpNextLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
--            SELECT DevicePosition     
--            FROM dbo.DeviceProfile WITH (NOLOCK)    
--            WHERE DeviceID           = @cDeviceID    
--              AND StorerKey          = @cStorerKey    
--              AND Priority           = '1'    
--            ORDER BY DeviceID, DevicePosition    
--                         
--            OPEN CursorLightUpNextLoc                
--                
--            FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress    
--                
--                
--            WHILE @@FETCH_STATUS <> -1         
--            BEGIN    
--              IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
--                          WHERE DeviceID = @cDeviceID    
--                           AND DevicePosition = @cModuleAddress    
--                           AND Priority = '0'    
--                           AND StorerKey = @cStorerKey )     
--               BEGIN    
--                  SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cPTSLoc) , 1 , 5 ) )    
--                  SET @cVarLightMode = @cLightModeStatic    
--                  SET @cLightPriority = '0'    
--               END                           
--               ELSE    
--               BEGIN    
--                  SET @cDisplayValue = RTRIM(@cPTSLoc)    
--                  SET @cVarLightMode = @cLightModeHold    
--                  SET @cLightPriority = '1'    
--               END    
--               INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
--               VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '4.1', @cDropID, @nPTLKey , @cPTSLoc , @cHoldDeviceProfileLogKey,     
--                      @cDeviceID, @cDevicePosition, @cModuleAddress , '' , ''   )     
--                   
--               -- INSERT END --     
--               INSERT INTO PTLTran    
--                    (    
--                       -- PTLKey -- this column value is auto-generated    
--                       IPAddress,  DeviceID,     DevicePosition,    
--                       [Status],   PTL_Type,     DropID,    
--                       OrderKey,   Storerkey,    SKU,    
--                       LOC,        ExpectedQty,  Qty,    
--                       Remarks,    MessageNum,   Lot,    
--                       DeviceProfileLogKey, RefPTLKey, ConsigneeKey,    
--                       CaseID, LightMode, LightSequence, AddWho, UOM, SourceKey    
--                    )    
--               SELECT  IPAddress,      DeviceID,      @cModuleAddress,    
--                       '0',            PTL_Type,      DropID,    
--                       OrderKey,       Storerkey,     @cHoldSuggSKU,    
--                       @cPTSLoc,       @nExpectedQty, 0,    
--                       @cPTSLoc,       '',            Lot,    
--                       @cHoldDeviceProfileLogKey,     @nPTLKey, @cHoldConsigneeKey,    
--                       CaseID,         @cLightModeHold, '3',     
--                       @cHoldUserID,   @cHoldUOM,     SourceKey    
--               FROM dbo.PTLTran WITH (NOLOCK)    
--               WHERE PTLKEy = @nPTLKey    
--                             
--                      
--               SELECT @nNewPTLTranKey  = PTLKey    
--               FROM dbo.PTLTran WITH (NOLOCK)    
--               WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
--               AND Status = '0'    
--               AND DevicePosition = @cModuleAddress    
--    
--               INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
--               VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '4.2', @cDropID, @nPTLKey , @cPTSLoc , @cHoldDeviceProfileLogKey,     
--                      @cDeviceID, @cModuleAddress, @cVarLightMode , @cDisplayValue , @nNewPTLTranKey  )     
--    
--                    
--               EXEC [dbo].[isp_DPC_LightUpLoc]     
--                     @c_StorerKey = @cStorerKey     
--                    ,@n_PTLKey    = @nNewPTLTranKey        
--                    ,@c_DeviceID  = @cDeviceID      
--                    ,@c_DevicePos = @cModuleAddress     
--                    ,@n_LModMode  = @cVarLightMode    
--                    ,@n_Qty       = @cDisplayValue           
--                    ,@b_Success   = @b_Success   OUTPUT      
--                    ,@n_Err       = @nErrNo      OUTPUT    
--                    ,@c_ErrMsg    = @cErrMsg     OUTPUT     
--          
--               -- Check If Consingee still have Picks to PTS --     
--       
--               IF @cLightPriority = '0'    
--               BEGIN    
--                    UPDATE PTLTran WITH (ROWLOCK)    
--                    SET Status = '9'    
--                    WHERE PTLKey = @nNewPTLTranKey    
--               END    
--               SET @nNewPTLTranKey = 0     
--                   
--               FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress      
--            END    
--            CLOSE CursorLightUpNextLoc                
--            DEALLOCATE CursorLightUpNextLoc          
--                
--            -- Update LightSequence of HOLD  = 5 --     
--            UPDATE PTLTran WITH (ROWLOCK)     
--            SET LightSequence = '5'    
--            WHERE PTLKey = @nHoldPTLKey    
--                
--            GOTO QUIT    
--                
--         END    
--      END    
   END -- @cLightSequence = '2'    
       
   IF @cLightSequence = '3'    
   BEGIN    
      --STEP_3:    
      SELECT @cPTSLoc = DeviceID     
      FROM dbo.DeviceProfile (NOLOCK)    
      WHERE DevicePosition = @cDevicePosition     
          
--      SET @cSuggDevicePosition = ''    
--     
--      SELECT @cSuggDevicePosition = DevicePosition     
--      FROM dbo.DeviceProfile WITH (NOLOCK)     
--      WHERE DeviceID = @cLoc    
--      AND Priority = '1'    
--      AND StorerKey = @cStorerKey    
--    
--      INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
--      VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '5.2x' , @cPTSLoc , @cStorerKey , @cSuggDevicePosition, @cLoc, '', '' , '' , '' , '' )     
--    
--      IF EXISTS( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                 WHERE DevicePosition = @cSuggDevicePosition    
--                 AND Status = '1' )     
--      BEGIN    
--          SET @cHoldCondition = '1'    
--      END    
--          
--      IF EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)     
--                  WHERE DevicePosition = @cSuggDevicePosition     
--                  AND Remarks = 'HOLD'    
--                  AND LightSequence = '0' )     
--      BEGIN     
--         SET @cHoldCondition = '1'    
--      END    
--          
--      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                  WHERE Status = '1'    
--                  AND DeviceID = @cLoc    
--                  AND DeviceProfileLogKey <> @cDeviceProfileLogKey  )     
--      BEGIN    
--         SET @cHoldCondition = '1'    
--      END    
--          
--      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                  WHERE Status = '1'    
--                  AND DevicePosition = @cSuggDevicePosition     
--                  AND DeviceProfileLogKey <> @cDeviceProfileLogKey  )     
--      BEGIN    
--         SET @cHoldCondition = '1'    
--      END    
--          
--      IF @cHoldCondition = '1'    
--      BEGIN    
--          INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
--          VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '3-HOLD' , @cSuggDevicePosition , @nPTLKey , @cPTSLoc, @cPTLSKU, @cUOM, @cDeviceProfileLogKey , '' , '' , '' )     
--              
--          -- INSERT END --     
--          INSERT INTO PTLTran    
--              (    
--                 -- PTLKey -- this column value is auto-generated    
--      IPAddress,            DeviceID,     DevicePosition,    
--                 [Status],             PTL_Type,     DropID,    
--                 OrderKey,             Storerkey,    SKU,    
--                 LOC,                  ExpectedQty,  Qty,    
--                 Remarks,              MessageNum,   Lot,    
--                 DeviceProfileLogKey,  RefPTLKey,    ConsigneeKey,    
--                 CaseID,               LightMode,    LightSequence,     
--                 AddWho,               UOM,          SourceKey    
--              )    
--         SELECT  IPAddress,            @cLoc,     DevicePosition,    
--                 '0',                  PTL_Type,     DropID,    
--                 OrderKey,             Storerkey,    SKU,    
--                 '',                  ExpectedQty,  0,    
--                 'HOLD',               @cMessageNum, Lot,    
--                 DeviceProfileLogKey,  @nPTLKey,     ConsigneeKey,    
--                 CaseID,               @cLightModeStatic, '0',     
--                 AddWho,               UOM,          SourceKey    
--         FROM dbo.PTLTran WITH (NOLOCK)    
--         WHERE PTLKEy = @nPTLKey    
--          
--             
--         SELECT @nNewPTLTranKey  = PTLKey    
--         FROM dbo.PTLTran WITH (NOLOCK)    
--         WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
--         AND Status = '0'    
--         AND Remarks = 'HOLD'    
--             
--         EXEC [dbo].[isp_DPC_LightUpLoc]     
--           @c_StorerKey = @cStorerKey     
--          ,@n_PTLKey    = @nNewPTLTranKey        
--          ,@c_DeviceID  = @cPTSLoc      
--          ,@c_DevicePos = @cDevicePosition     
--          ,@n_LModMode  = @cLightModeStatic      
--          ,@n_Qty       = 'HOLD'           
--          ,@b_Success   = @b_Success   OUTPUT      
--          ,@n_Err       = @nErrNo      OUTPUT    
--          ,@c_ErrMsg    = @cErrMsg     OUTPUT      
--              
--              
--          UPDATE  PTLTran WITH (ROWLOCK)     
--          SET Status = '9'    
--          WHERE PTLKey = @nNewPTLTranKey    --              
--          SET @nNewPTLTranKey = 0     
--              
--          -- No More Record Goto Quit     
--          GOTO QUIT    
--      END    
                       
    
      -- Terminate Primary Display    
      EXEC [dbo].[isp_DPC_TerminateModule]       
         @cStorerKey      
        ,@cPTSLoc        
        ,'1'    
        ,@b_Success    OUTPUT        
        ,@nErrNo       OUTPUT      
        ,@cErrMsg      OUTPUT      
          
          
      -- Light Up SKU After Confirm on Next Loc --    
      BEGIN    
                
            
    
          DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
          SELECT PTLKey, DevicePosition, LightMode    
          FROM dbo.PTLTran PTL WITH (NOLOCK)    
          WHERE Status             = '0'    
            --AND AddWho             = @cUserName    
            AND DeviceID           = @cLoc       
            AND SKU                = @cPTLSKU    
            AND UOM                = @cUOM    
            AND DeviceProfileLogKey = @cDeviceProfileLogKey    
          ORDER BY DeviceID, PTLKey    
           
          OPEN CursorLightUp                
              
          FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode    
              
          WHILE @@FETCH_STATUS <> -1         
          BEGIN    
             IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
                         WHERE DeviceID = @cLoc    
                         AND DevicePosition = @cModuleAddress    
                         AND Priority = '0'    
                         AND StorerKey = @cStorerKey )     
             BEGIN    
                SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cPTLSKU) , 1 , 2 ) )    
             END                      
             ELSE    
             BEGIN    
                SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cPTLSKU) , 3 , 5 ) )    
             END    
                 
                       
             EXEC [dbo].[isp_DPC_LightUpLoc]     
                   @c_StorerKey = @cStorerKey     
                  ,@n_PTLKey    = @nVarPTLKey        
                  ,@c_DeviceID  = @cLoc      
                  ,@c_DevicePos = @cModuleAddress     
                  ,@n_LModMode  = @cLightMode      
                  ,@n_Qty       = @cDisplayValue           
                  ,@b_Success   = @b_Success   OUTPUT      
                  ,@n_Err       = @nErrNo      OUTPUT    
                  ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                    
             -- IF PLTKey = 0 , Relight Again one more time.  
             IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)  
                         WHERE PTLKey = @nVarPTLKey  
                         AND Status = '0' )   
             BEGIN  
                  INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
                  VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , '1' , 'Re-Do', @cLoc , @cModuleAddress , @nVarPTLKey,  '', '' , '' , '' , '' )     
  
                  EXEC [dbo].[isp_DPC_LightUpLoc]     
                      @c_StorerKey = @cStorerKey     
                     ,@n_PTLKey    = @nVarPTLKey        
                     ,@c_DeviceID  = @cLoc      
                     ,@c_DevicePos = @cModuleAddress     
                     ,@n_LModMode  = @cLightMode      
                     ,@n_Qty       = @cDisplayValue           
                     ,@b_Success   = @b_Success   OUTPUT      
                     ,@n_Err       = @nErrNo      OUTPUT    
                     ,@c_ErrMsg    = @cErrMsg     OUTPUT    
             END  
               
                  
             FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode    
          END    
          CLOSE CursorLightUp                
          DEALLOCATE CursorLightUp      
       END    
           
         
           
          
       -- Process for Hold Location --     
       IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                      WHERE DeviceID = @cPTSLoc    
                      AND Status = '1'    
                      AND SourceKey = @cWaveKey    
                      AND PTLKey <> @nPTLKey     
                      AND Remarks NOT IN ('HOLD', 'FULL', 'END') )     
      BEGIN    
             
             
         SELECT TOP 1  @cHoldUserID = AddWho     
                     , @cHoldDeviceProfileLogKey = DeviceProfileLogKey    
                     , @cHoldSuggSKU = SKU    
                     , @cHoldUOM     = UOM    
                     , @cPrevDevicePosition = DevicePosition     
                     , @cHoldConsigneeKey = ConsigneeKey    
                     , @nHoldPTLKey  = PTLKey    
         FROM dbo.PTLTran WITH (NOLOCK)    
         WHERE Remarks = 'HOLD'    
         AND DeviceID = @cPTSLoc    
         AND LightSequence = '0'    
         AND AddWho <> @cUserName    
         Order By DeviceProfileLogKey    
    
         IF ISNULL(@cHoldDeviceProfileLogKey,'')  <> ''    
         BEGIN    
            SELECT @cDeviceID = DeviceID     
            FROM dbo.DeviceProfile WITH (NOLOCK)    
            WHERE DevicePosition = @cPrevDevicePosition    
       
            SELECT @cLightModeHOLD = DefaultLightColor     
            FROM rdt.rdtUser WITH (NOLOCK)    
            WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')     
       
                
              
                
            -- ChecK If It is First Record ? -- If Yes Light Up From RDT PTS Carton --     
            IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                            WHERE Status = '9'    
                            AND DeviceProfileLogKey = @cHoldDeviceProfileLogKey )     
            BEGIN    
                   
               EXEC [dbo].[isp_LightUpLocCheck]     
                     @nPTLKey                = @nPTLKey                  
                    ,@cStorerKey             = @cStorerKey               
                    ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
                    ,@cLoc                   = @cPTSLoc                     
                    ,@cType                  = 'UNLOCK'                    
                    ,@nErrNo                 = @nErrNo               OUTPUT    
                    ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
                  
               GOTO QUIT    
            END    
                
            -- Not More PTLTran Quit --     
            IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                            WHERE Status NOT IN ( '5','9' )     
                            AND SourceKey = @cWaveKey    
                            AND PTLKey <> @nPTLKey )     
            BEGIN    
               GOTO PROCESS_FULL_LOC     
            END    
              
            INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )      
            VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , 'Step3' , @cUserName , @cPTSLoc , @cDeviceProfileLogKey, @nPTLKey, @nHoldPTLKey, @cHoldDeviceProfileLogKey , '' , '' , '' )       
      
            SET @nTranCount01 = 0   
            SET @nTranCount01  = @@TRANCOUNT  
              
            BEGIN TRAN      
            SAVE TRAN isp_LightUpLocCheck_01  
              
               -- Unlock Current User --     
               EXEC [dbo].[isp_LightUpLocCheck]     
                  @nPTLKey                = @nPTLKey                  
                 ,@cStorerKey             = @cStorerKey               
                 ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
                 ,@cLoc                   = @cPTSLoc                     
                 ,@cType                  = 'UNLOCK'                   
                 ,@nErrNo                 = @nErrNo               OUTPUT    
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
              
  IF @nErrNo <> 0   
               BEGIN  
                  ROLLBACK TRAN isp_LightUpLocCheck_01   
                    
                  WHILE @@TRANCOUNT>@nTranCount01 -- Commit until the level we started      
                  COMMIT TRAN  
                    
                  GOTO PROCESS_FULL_LOC  
               END  
              
               -- Lock Next User --    
               EXEC [dbo].[isp_LightUpLocCheck]     
                  @nPTLKey                = @nHoldPTLKey                  
                 ,@cStorerKey             = @cStorerKey               
                 ,@cDeviceProfileLogKey   = @cHoldDeviceProfileLogKey     
                 ,@cLoc                   = @cPTSLoc                     
                 ,@cType                  = 'LOCK'                    
                 ,@nErrNo                 = @nErrNo               OUTPUT    
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
    
               IF @nErrNo <> 0   
               BEGIN  
                   
     
   --               EXEC [dbo].[isp_LightUpLocCheck]     
   --               @nPTLKey                = @nPTLKey                  
   --              ,@cStorerKey             = @cStorerKey               
   --              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
   --              ,@cLoc                   = @cPTSLoc                     
   --              ,@cType                  = 'LOCK'                    
   --              ,@nErrNo                 = @nErrNo               OUTPUT    
   --              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
                    
                  ROLLBACK TRAN isp_LightUpLocCheck_01      
                    
                  WHILE @@TRANCOUNT>@nTranCount01 -- Commit until the level we started      
                  COMMIT TRAN  
                    
                  GOTO PROCESS_FULL_LOC  
                    
               END  
               ELSE   
               BEGIN  
                  COMMIT TRAN isp_LightUpLocCheck_01   
               END  
              
              
            DECLARE CursorLightUpNextLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
            SELECT DevicePosition     
            FROM dbo.DeviceProfile WITH (NOLOCK)    
            WHERE DeviceID           = @cDeviceID    
              AND StorerKey          = @cStorerKey    
              AND Priority           = '1'    
            ORDER BY DeviceID, DevicePosition    
                
            OPEN CursorLightUpNextLoc                
                
            FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress    
                
                
            WHILE @@FETCH_STATUS <> -1         
            BEGIN    
       
--              IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
--                          WHERE DeviceID = @cDeviceID    
--                           AND DevicePosition = @cModuleAddress    
--                           AND Priority = '0'    
--                           AND StorerKey = @cStorerKey )     
--               BEGIN    
--                  SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cPTSLoc) , 1 , 5 ) )    
--                  SET @cVarLightMode = @cLightModeStatic    
--                  SET @cLightPriority = '0'    
--               END                           
--               ELSE    
--               BEGIN    
                  SET @cDisplayValue = RTRIM(@cPTSLoc)    
                  SET @cVarLightMode = @cLightModeHold    
                  SET @cLightPriority = '1'    
--               END    
       
                 
                   
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
               SELECT  IPAddress,  DeviceID,     @cModuleAddress,    
                       '0',   PTL_Type,     DropID,    
                       OrderKey,   Storerkey,    @cHoldSuggSKU,    
                       @cPTSLoc,        @nExpectedQty,  0,    
                       @cPTSLoc,    '',   Lot,    
                       @cHoldDeviceProfileLogKey, @nPTLKey, @cHoldConsigneeKey,    
                       CaseID, @cLightModeHold, '3', @cHoldUserID, @cHoldUOM, SourceKey    
               FROM dbo.PTLTran WITH (NOLOCK)    
               WHERE PTLKEy = @nPTLKey    
                    
                      
               SELECT @nNewPTLTranKey  = PTLKey    
               FROM dbo.PTLTran WITH (NOLOCK)    
               WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
               AND Status = '0'    
               AND DevicePosition = @cModuleAddress    
               AND LightSequence = '3'  
       
                 
                    
               EXEC [dbo].[isp_DPC_LightUpLoc]     
                     @c_StorerKey = @cStorerKey     
                    ,@n_PTLKey    = @nNewPTLTranKey        
                    ,@c_DeviceID  = @cDeviceID      
                    ,@c_DevicePos = @cModuleAddress     
                    ,@n_LModMode  = @cVarLightMode    
                    ,@n_Qty       = @cDisplayValue           
                    ,@b_Success   = @b_Success   OUTPUT      
                    ,@n_Err       = @nErrNo      OUTPUT    
                    ,@c_ErrMsg    = @cErrMsg     OUTPUT     
                   
    
                   
       
--               IF @cLightPriority = '0'    
--               BEGIN    
--                    UPDATE PTLTran WITH (ROWLOCK)    
--                    SET Status = '9'    
--                    WHERE PTLKey = @nNewPTLTranKey    
--               END    
    
                       
               SET @nNewPTLTranKey = 0     
                   
                    
               FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress      
            END    
            CLOSE CursorLightUpNextLoc                
            DEALLOCATE CursorLightUpNextLoc          
                
                
            -- Update LightSequence of HOLD  = 5 --     
            UPDATE PTLTran WITH (ROWLOCK)     
            SET LightSequence = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()    
            WHERE PTLKey = @nHoldPTLKey    
                
         END       
         --GOTO QUIT    
             
      END    
          
      PROCESS_FULL_LOC:    
    
      -- Pack Confirm --     
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
                                         
                                         
      INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )    
      VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , 'FULL' , @cWaveKey, @cConsigneeKey , @nTotalPickedQty , @nTotalPackedQty,  '', '' , '' , '' , '' ) 
    
      IF @nTotalPickedQty = @nTotalPackedQty    
      BEGIN    
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
                  CaseID, LightMode, LightSequence, AddWho, SourceKey    
               )    
          SELECT  IPAddress,  DeviceID,     DevicePosition,    
                  '0',   PTL_Type,     DropID,    
                  OrderKey,   Storerkey,    SKU,    
                  LOC,        @nExpectedQty,  0,    
                  'FULL',    @cMessageNum,   Lot,    
                  DeviceProfileLogKey, @nPTLKey, ConsigneeKey,    
                  CaseID, @cLightModeStatic, '4', AddWho, SourceKey    
          FROM dbo.PTLTran WITH (NOLOCK)    
          WHERE PTLKEy = @nPTLKey    
       
                    
          SELECT @nNewPTLTranKey  = PTLKey    
          FROM dbo.PTLTran WITH (NOLOCK)    
          WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
          AND Status = '0'    
    
          EXEC [dbo].[isp_DPC_LightUpLoc]     
            @c_StorerKey = @cStorerKey     
           ,@n_PTLKey    = @nNewPTLTranKey        
           ,@c_DeviceID  = @cPTSLoc      
           ,@c_DevicePos = @cDevicePosition     
           ,@n_LModMode  = @cLightModeFULL      
           ,@n_Qty       = 'FULL'           
           ,@b_Success   = @b_Success   OUTPUT      
           ,@n_Err       = @nErrNo      OUTPUT    
           ,@c_ErrMsg    = @cErrMsg     OUTPUT      
                     
                     
           UPDATE  PTLTran WITH (ROWLOCK)     
           SET LightSequence = LightSequence + 1 , Status = '9', 
               EditDate = GETDATE(), EditWho = SUSER_SNAME()    
           WHERE PTLKey = @nNewPTLTranKey    
           AND Remarks = 'FULL'    
               
           SET @nNewPTLTranKey = 0     
      END    
          
          
          
          
      EXEC [dbo].[isp_LightUpLocCheck]     
               @nPTLKey                = @nPTLKey                  
              ,@cStorerKey             = @cStorerKey               
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
              ,@cLoc                   = @cPTSLoc                     
              ,@cType                  = 'UNLOCK'                    
              ,@nErrNo                 = @nErrNo               OUTPUT    
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
          
   END -- @cLightSequence = '3'    
       
   IF @cLightSequence = '4'    
   BEGIN    
           
       -- Process for Hold Location --     
       IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                       WHERE DeviceID = @cPTSLoc    
                       AND Status = '1'    
                       AND SourceKey = @cWaveKey    
                       AND PTLKey <> @nPTLKey     
                       AND Remarks NOT IN ('HOLD', 'FULL', 'END') )     
       BEGIN    
              
          SELECT TOP 1  @cHoldUserID = AddWho     
                      , @cHoldDeviceProfileLogKey = DeviceProfileLogKey    
                      , @cHoldSuggSKU = SKU    
                      , @cHoldUOM     = UOM    
                      , @cPrevDevicePosition = DevicePosition     
                      , @cHoldConsigneeKey = ConsigneeKey    
                      , @nHoldPTLKey  = PTLKey    
          FROM dbo.PTLTran WITH (NOLOCK)    
          WHERE Remarks = 'HOLD'    
          AND DeviceID = @cPTSLoc    
          AND LightSequence = '0'    
          AND AddWho <> @cUserName    
          Order By DeviceProfileLogKey    
       
          IF ISNULL(@cHoldDeviceProfileLogKey,'')  <> ''    
          BEGIN    
             SELECT @cDeviceID = DeviceID     
             FROM dbo.DeviceProfile WITH (NOLOCK)    
             WHERE DevicePosition = @cPrevDevicePosition    
          
             SELECT @cLightModeHOLD = DefaultLightColor     
             FROM rdt.rdtUser WITH (NOLOCK)    
             WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')     
          
                 
             -- ChecK If It is First Record ? -- If Yes Light Up From RDT PTS Carton --     
             IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTRAN WITH (NOLOCK)    
                             WHERE Status = '9'    
                             AND DeviceProfileLogKey = @cHoldDeviceProfileLogKey )     
             BEGIN    
                EXEC [dbo].[isp_LightUpLocCheck]     
                  @nPTLKey                = @nPTLKey                  
                 ,@cStorerKey             = @cStorerKey               
                 ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
                 ,@cLoc                   = @cPTSLoc                     
                 ,@cType                  = 'UNLOCK'                    
                 ,@nErrNo                 = @nErrNo               OUTPUT    
                 ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
                  
                GOTO QUIT    
             END    
                 
             -- Not More PTLTran Quit --     
             IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                             WHERE Status NOT IN ( '5','9' )     
                             AND SourceKey = @cWaveKey    
                             AND PTLKey <> @nPTLKey )     
             BEGIN    
                GOTO PROCESS_FULL_LOC_4    
             END    
    
            INSERT INTO TraceINFO ( TraceName , TimeIN , Step1, Step2, Step3, Step4, Step5, Col1, Col2, col3,Col4,col5 )      
            VALUES( 'isp_PTL_PTS_Confirm02' , Getdate() , 'Step4' , @cUserName , @cPTSLoc , @cDeviceProfileLogKey, @nPTLKey, @nHoldPTLKey, @cHoldDeviceProfileLogKey , '' , '' , '' )       
              
            SET @nTranCount01 = 0   
            SET @nTranCount01  = @@TRANCOUNT  
              
            BEGIN TRAN      
            SAVE TRAN isp_LightUpLocCheck_02  
              
            -- Unlock Current User --     
            EXEC [dbo].[isp_LightUpLocCheck]     
               @nPTLKey                = @nPTLKey                  
              ,@cStorerKey             = @cStorerKey               
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
              ,@cLoc                   = @cPTSLoc                     
              ,@cType                  = 'UNLOCK'                    
              ,@nErrNo                 = @nErrNo               OUTPUT    
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
    
            IF @nErrNo <> 0   
            BEGIN  
                  ROLLBACK TRAN isp_LightUpLocCheck_02   
                    
                  WHILE @@TRANCOUNT>@nTranCount01 -- Commit until the level we started      
                  COMMIT TRAN  
                    
                  GOTO PROCESS_FULL_LOC_4  
            END  
              
            -- Lock Next User --    
            EXEC [dbo].[isp_LightUpLocCheck]     
               @nPTLKey                = @nHoldPTLKey                  
              ,@cStorerKey             = @cStorerKey               
              ,@cDeviceProfileLogKey   = @cHoldDeviceProfileLogKey     
              ,@cLoc                   = @cPTSLoc                     
              ,@cType                  = 'LOCK'                    
              ,@nErrNo                 = @nErrNo               OUTPUT    
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
               
            IF @nErrNo <> 0   
            BEGIN  
                
      
--               EXEC [dbo].[isp_LightUpLocCheck]     
--               @nPTLKey                = @nPTLKey                  
--              ,@cStorerKey             = @cStorerKey               
--              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
--              ,@cLoc                   = @cPTSLoc                     
--              ,@cType                  = 'LOCK'                    
--          ,@nErrNo                 = @nErrNo               OUTPUT    
--              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
                ROLLBACK TRAN isp_LightUpLocCheck_02      
                    
                WHILE @@TRANCOUNT>@nTranCount01 -- Commit until the level we started      
                COMMIT TRAN  
                  
                GOTO PROCESS_FULL_LOC_4  
            END  
            ELSE   
            BEGIN  
               COMMIT TRAN isp_LightUpLocCheck_02  
            END  
                 
             DECLARE CursorLightUpNextLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
             SELECT DevicePosition     
             FROM dbo.DeviceProfile WITH (NOLOCK)    
             WHERE DeviceID           = @cDeviceID    
               AND StorerKey          = @cStorerKey    
               AND Priority           = '1'    
             ORDER BY DeviceID, DevicePosition    
                 
             OPEN CursorLightUpNextLoc                
                 
             FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress    
             WHILE @@FETCH_STATUS <> -1         
             BEGIN    
          
--               IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)    
--                           WHERE DeviceID = @cDeviceID    
--                            AND DevicePosition = @cModuleAddress    
--                            AND Priority = '0'    
--                            AND StorerKey = @cStorerKey )     
--                BEGIN    
--                   SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cPTSLoc) , 1 , 5 ) )    
--                   SET @cVarLightMode = @cLightModeStatic    
--                   SET @cLightPriority = '0'    
--                END                           
--                ELSE    
--                BEGIN    
                   SET @cDisplayValue = RTRIM(@cPTSLoc)    
                   SET @cVarLightMode = @cLightModeHold    
                   SET @cLightPriority = '1'    
--                END    
                    
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
                SELECT  IPAddress,  DeviceID,       @cModuleAddress,    
                        '0',        PTL_Type,       DropID,    
                        OrderKey,   Storerkey,      @cHoldSuggSKU,    
                        @cPTSLoc,   @nExpectedQty,  0,    
                        @cPTSLoc,   '',             Lot,    
                        @cHoldDeviceProfileLogKey,  @nPTLKey, @cHoldConsigneeKey,    
                        CaseID, @cLightModeHold, '3', @cHoldUserID, @cHoldUOM, SourceKey    
                FROM dbo.PTLTran WITH (NOLOCK)    
                WHERE PTLKEy = @nPTLKey    
                     
                       
                SELECT @nNewPTLTranKey  = PTLKey    
                FROM dbo.PTLTran WITH (NOLOCK)    
                WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
                AND Status = '0'    
                AND DevicePosition = @cModuleAddress    
                AND LightSequence = '3'  
          
                EXEC [dbo].[isp_DPC_LightUpLoc]     
                      @c_StorerKey = @cStorerKey     
                     ,@n_PTLKey    = @nNewPTLTranKey        
                     ,@c_DeviceID  = @cDeviceID      
                     ,@c_DevicePos = @cModuleAddress     
                     ,@n_LModMode  = @cVarLightMode    
                     ,@n_Qty       = @cDisplayValue           
                     ,@b_Success   = @b_Success   OUTPUT      
                     ,@n_Err       = @nErrNo      OUTPUT    
                     ,@c_ErrMsg    = @cErrMsg     OUTPUT     
          
--                IF @cLightPriority = '0'    
--                BEGIN    
--                     UPDATE PTLTran WITH (ROWLOCK)    
--                     SET Status = '9'    
--                     WHERE PTLKey = @nNewPTLTranKey    
--                END    
       
                        
                SET @nNewPTLTranKey = 0     
                FETCH NEXT FROM CursorLightUpNextLoc INTO @cModuleAddress      
             END    
             CLOSE CursorLightUpNextLoc                
             DEALLOCATE CursorLightUpNextLoc          
                 
             -- Update LightSequence of HOLD  = 5 --     
             UPDATE PTLTran WITH (ROWLOCK)     
             SET LightSequence = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()    
             WHERE PTLKey = @nHoldPTLKey    
          END       
          --GOTO QUIT    
       END -- Not exisits in PTLTran    
          
       PROCESS_FULL_LOC_4:    
           
       SET @nTotalPickedQty = 0    
       SET @nTotalPackedQty = 0    
           
       SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)    
       FROM dbo.PickDetail PD WITH (NOLOCK)     
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
       WHERE PD.StorerKey = @cStorerKey    
         AND PD.Status    IN ('0', '5')    
         AND PD.Qty > 0     
         AND O.ConsigneeKey = @cConsigneeKey    
         AND PD.WaveKey = @cWaveKey    
              
       SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)     
       FROM dbo.PackDetail PackD WITH (NOLOCK)    
       INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo     
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey    
       WHERE O.ConsigneeKey = @cConsigneeKey    
       AND O.UserDefine09 = @cWaveKey    
                   
       IF @nTotalPickedQty = @nTotalPackedQty    
       BEGIN    
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
                  CaseID, LightMode, LightSequence, AddWho, SourceKey    
               )    
          SELECT  IPAddress,  DeviceID,     DevicePosition,    
                  '0',   PTL_Type,     DropID,    
                  OrderKey,   Storerkey,    SKU,    
                  LOC,        @nExpectedQty,  0,    
                  'FULL',    @cMessageNum,   Lot,    
                  DeviceProfileLogKey, @nPTLKey, ConsigneeKey,    
                  CaseID, @cLightModeStatic, '4', AddWho, SourceKey    
          FROM dbo.PTLTran WITH (NOLOCK)    
          WHERE PTLKEy = @nPTLKey    
                       
          SELECT @nNewPTLTranKey  = PTLKey    
          FROM dbo.PTLTran WITH (NOLOCK)    
          WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))    
          AND Status = '0'    
             
          EXEC [dbo].[isp_DPC_LightUpLoc]     
            @c_StorerKey = @cStorerKey     
           ,@n_PTLKey    = @nNewPTLTranKey        
           ,@c_DeviceID  = @cPTSLoc      
           ,@c_DevicePos = @cDevicePosition     
           ,@n_LModMode  = @cLightModeFULL      
           ,@n_Qty       = 'FULL'           
           ,@b_Success   = @b_Success   OUTPUT      
           ,@n_Err       = @nErrNo      OUTPUT    
           ,@c_ErrMsg    = @cErrMsg     OUTPUT      
               
           UPDATE  PTLTran WITH (ROWLOCK)     
           SET LightSequence = LightSequence + 1 , Status = '9', 
               EditDate = GETDATE(), EditWho = SUSER_SNAME()    
           WHERE PTLKey = @nNewPTLTranKey    
           AND Remarks = 'FULL'    
               
           SET @nNewPTLTranKey = 0     
       END    
            
        EXEC [dbo].[isp_LightUpLocCheck]     
               @nPTLKey                = @nPTLKey                  
              ,@cStorerKey             = @cStorerKey               
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey     
              ,@cLoc                   = @cPTSLoc                     
              ,@cType                  = 'UNLOCK'                    
              ,@nErrNo                 = @nErrNo               OUTPUT    
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max    
   END    
        
    GOTO QUIT    
    
    RollBackTran:    
    ROLLBACK TRAN PackInsert    
        
    SELECT @cModuleName = 'PTS'    
        
    SET @cAlertMessage = 'DropID : ' + @cDropID + @c_NewLineChar    
                         + 'PTLKey : ' + CAST(@nPTLKey AS NVARCHAR(10))  + @c_NewLineChar    
                         + 'Error Code: ' + CAST(@nErrNo AS VARCHAR) + @c_NewLineChar     
                         + ' Error Message: ' + @cErrMsg     
        
    EXEC nspLogAlert    
            @c_modulename       = @cModuleName    
          , @c_AlertMessage     = @cAlertMessage    
          , @n_Severity         = '5'    
          , @b_success          = @b_success     OUTPUT    
          , @n_err              = @nErrNo        OUTPUT    
          , @c_errmsg           = @cErrMsg       OUTPUT    
          , @c_Activity         = 'PTS'    
          , @c_Storerkey      = @cStorerKey    
          , @c_SKU            = ''    
          , @c_UOM            = ''    
          , @c_UOMQty         = ''    
          , @c_Qty            = @nActualQty    
          , @c_Lot            = ''    
          , @c_Loc            = ''    
          , @c_ID               = ''    
          , @c_TaskDetailKey   = ''    
          , @c_UCCNo            = ''    
        
    Quit:    
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started    
          COMMIT TRAN PackInsert    
END 

GO