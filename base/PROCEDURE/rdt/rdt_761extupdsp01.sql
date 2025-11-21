SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_761ExtUpdSP01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-10-05  1.0  ChewKP   Created                                    */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_761ExtUpdSP01] (  
   @nMobile        INT,                
   @nFunc          INT,                
   @cLangCode      NVARCHAR(3),        
   @nStep          INT,                
   @cUserName      NVARCHAR( 18),       
   @cFacility      NVARCHAR( 5),        
   @cStorerKey     NVARCHAR( 15),       
   @cDropID        NVARCHAR( 20),       
   @cSKU           NVARCHAR( 20),       
   @nQty           INT,                 
   @cLabelNo       NVARCHAR( 20),       
   @cPTSLogKey     NVARCHAR( 20),       
   @cShort         NVARCHAR(1),
   @cSuggLabelNo   NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @cOrderKey             NVARCHAR(10)
          , @cLoc                  NVARCHAR(10) 
          , @cLot                  NVARCHAR(10)
          , @cConsigneeKey         NVARCHAR(15)
          , @nTranCount            INT    
          , @cPTSPosition          NVARCHAR(20)
          , @nCartonNo             INT
          , @cLabelLine            NVARCHAR(5)
          , @cPTSStatus            NVARCHAR(5)
          , @cPickDetailKey        NVARCHAR(10)
          , @cPickSlipNo           NVARCHAR(10)
          , @cPDOrderKey           NVARCHAR(10)
          , @cUOM                  NVARCHAR(10)      
          , @nExpectedQty          INT
          , @nPDQty                INT
          , @b_success             INT     
          , @nPackQty              INT
          , @cNewPickDetailKey     NVARCHAR(10)
          , @nTotalPickedQty       INT
          , @nTotalPackedQty       INT
          , @nRemainQty            INT
          , @cPDCaseID             NVARCHAR(20) 
          , @nPacked               INT
          , @cWaveKey              NVARCHAR(10) 
          , @cPTLZone              NVARCHAR(10) 
          , @nEventLogQty          INT
          

   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
   SET @cPDCaseID             = ''
   SET @nPacked               = 0 
  
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_761ExtUpdSP01
   
   IF @nFunc = 761
   BEGIN
      
      IF @nStep = 1 
      BEGIN
          -- DELETE FROM PTL.PTLTRAN & PTLLockLoc for the Same User. -- 
          DELETE FROM PTL.PTLTran WITH (ROWLOCK) 
          WHERE AddWho = @cUserName 
          AND Status < '9' 
          
          IF @@ERROR <> 0 
          BEGIN
               SET @nErrNo = 96771    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTLTranFail    
               GOTO RollBackTran
          END
          
          DELETE FROM dbo.PTLLockLoc WITH (ROWLOCK) 
          WHERE AddWho = @cUserName 
          
          IF @@ERROR <> 0 
          BEGIN
               SET @nErrNo = 96772
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTLockLocFail   
               GOTO RollBackTran
          END
          
          DECLARE CursorPTLSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
    
          SELECT STL.Loc
               , PD.DropID
               , O.OrderKey
               , PD.StorerKey
               , PD.SKU
               , SUM(PD.Qty)
               , O.ConsigneeKey
               , PD.UOM
               , '' --, PD.Loc
               , '' --, PD.Lot
               , PD.CaseID 
          FROM dbo.PickDetail PD WITH (NOLOCK) 
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
          INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKEy = O.ConsigneeKey 
          WHERE PD.StorerKey           = @cStorerKey
            AND PD.DropID              = @cDropID
            AND PD.Status              = '5'
            AND PD.Qty > 0 
            --AND PD.CaseID = ''
            AND PD.CaseID NOT LIKE 'T%'
          GROUP BY STL.Loc, PD.DropID, O.OrderKey, PD.StorerKey, PD.SKU, O.ConsigneeKey,
                   PD.UOM, PD.CaseID--, PD.Loc, PD.Lot, PD.Qty
          ORDER BY PD.SKU
          
          
          OPEN CursorPTLSLog            
          
          FETCH NEXT FROM CursorPTLSLog INTO @cPTSPosition, @cDropID, @cOrderKey, @cStorerKey, @cSKU, 
                                             @nExpectedQty, @cConsigneeKey, @cUOM, @cLoc, @cLot, @cPDCaseID
                                             
          
          
          WHILE @@FETCH_STATUS <> -1     
          BEGIN
            
            SELECT Top 1 @cLabelNo = DPLog.DropID
            FROM dbo.DeviceProfileLog DPLog WITH (NOLOCK) 
            INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DPLog.DeviceProfileKey 
            INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.Loc = DP.DeviceID
            WHERE STL.ConsigneeKey = @cConsigneeKey
            AND DPLog.Status <> '9'
            ORDER BY DPLog.AddDate DESC
            
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                            WHERE PTSPosition = @cPTSPosition 
                            AND DropID        = @cDropID
                            AND LabelNo       = @cLabelNo
                            AND StorerKey     = @cStorerKey
                            AND ConsigneeKey  = @cConsigneeKey
                            AND OrderKey      = @cOrderKey
                            AND SKU           = @cSKU
                            AND UOM           = @cUOM -- (ChewKPXX) 
                            AND Status       <> '9' ) 
            BEGIN
               IF @cPDCaseID <> '' 
                  SET @cLabelNo = @cPDCaseID
               
               SET @nPacked = 0 
               
               IF ISNULL(@cPDCaseID,'') <> '' 
               BEGIN   
                  
                  IF EXISTS ( SELECT 1 FROM PackDetail WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerKey
                              AND LabelNo = @cPDCaseID ) 
                  BEGIN
                     SET @nPacked = 1 
                  END
               END   
               
               IF @nPacked = 0 
               BEGIN
                  INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                             ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho ) 
                  VALUES (@cPTSPosition, '0', @cDropID, @cLabelNo, @cStorerKey, @cConsigneeKey, @cOrderKey, @cSKU, @cLoc, @cLot, @cUOM,
                          @nExpectedQty, '0', '', @nFunc, GetDate(), @cUserName ) 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                      SET @nErrNo = 96751
                      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLLogFail'
                      GOTO RollBackTran
                  END
               END
               
            END
            
            FETCH NEXT FROM CursorPTLSLog INTO @cPTSPosition, @cDropID, @cOrderKey, @cStorerKey, @cSKU, 
                                               @nExpectedQty, @cConsigneeKey, @cUOM, @cLoc, @cLot, @cPDCaseID
                                             
          END
          CLOSE CursorPTLSLog            
          DEALLOCATE CursorPTLSLog   
          
         
      END
      

      
      IF @nStep = 3
      BEGIN
         
         IF ISNULL(@nQty, 0 )  = 0 
         BEGIN
               SET @nErrNo = 96773    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QtyReq    
               GOTO RollBackTran
         END
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                     WHERE PTSLogKey = @cPTSLogKey
                     AND ExpectedQty < @nQty ) 
         BEGIN
               SET @nErrNo = 96774    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidQty    
               GOTO RollBackTran
         END                     
         

         --Update PickDetail & Create PackDetail
         SET @nCartonNo = 0      
         SET @cLabelLine = '00000'   
         SET @cConsigneeKey = '' 
         
         SELECT  @cConsigneeKey = ConsigneeKey
               , @cPTSStatus    = Status
               , @cDropID       = DropID
               --, @nQty          = Qty 
               , @cLabelNo      = LabelNo
               , @cSKU          = SKU
               , @nExpectedQty  = ExpectedQty 
               , @cUOM          = UOM
               , @cPTSPosition  = PTSPosition
         FROM rdt.rdtPTSLog WITH (NOLOCK)
         WHERE PTSLogKey = @cPTSLogKey 

         SET @nRemainQty = @nExpectedQty - @nQty
         
         -- Create DeviceProfileLog & DropID -- 
         IF CHARINDEX( 'T' , @cLabelNo  ) > 0
         BEGIN
            IF NOT EXISTS ( SELECT DeviceProfileKey            
                        FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                        WHERE DropID = @cLabelNo    
                        AND Status < '9'  ) 
            BEGIN
                  SET @nErrNo = 96770    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DropIDNotExist    
                  GOTO RollBackTran
            END  
         END    

         --INSERT INTO TRACEINFO (TraceName , TimeIn , Col1, col2, col3 , col4, col5 )   
         --VALUES ( 'rdt_761ExtUpdSP01' , Getdate() , @cPTSLogKey, @cDropID , @cSKU , @cConsigneeKey, @cLabelNo )   
                 
         IF CHARINDEX( 'T' , @cLabelNo  ) > 0
         BEGIN
            
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
            SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.CaseID, PD.WaveKey
            FROM dbo.Pickdetail PD WITH (NOLOCK)      
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey      
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber      
            WHERE PD.DropID = @cDropID      
            AND PD.Status = '5'      
            AND PD.SKU    = @cSKU      
            AND ISNULL(PD.CaseID,'')  = ''     
            AND O.ConsigneeKey = @cConsigneeKey      
            ORDER BY PD.SKU      
         END
         ELSE 
         BEGIN
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
            SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.CaseID, PD.WaveKey
            FROM dbo.Pickdetail PD WITH (NOLOCK)      
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey      
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber      
            WHERE PD.DropID = @cDropID      
            AND PD.Status = '5'      
            AND PD.SKU    = @cSKU      
            ----AND ISNULL(PD.CaseID,'')  = ''     
            AND PD.CaseID = @cLabelNo
            AND O.ConsigneeKey = @cConsigneeKey      
            ORDER BY PD.SKU    
         END
         
         OPEN  CursorPickDetail      
         
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cPDCaseID, @cWaveKey
         
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
                  SET @nErrNo = 96754      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPackHFail 
                  GOTO RollBackTran      
               END      
                     
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate )       
               VALUES (@cPickSlipNo, GetDate(), suser_sname(), '')       
                     
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 96755      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickInfoFail 
                  GOTO RollBackTran      
               END      
                     
            END          
            ELSE       
            BEGIN      
               SELECT @cPickSlipNo = PickslipNo      
               FROM dbo.PackHeader WITH (NOLOCK)      
               WHERE OrderKey = @cPDOrderKey      
            END        
                                  
            IF ISNULL(@cPDCaseID,'')  = '' 
            BEGIN   
               SET @nPackQty = 0       
            
               IF @nPDQty=@nQty        
               BEGIN        
                  -- Confirm PickDetail        
                  UPDATE dbo.PickDetail WITH (ROWLOCK)        
                     SET CaseID = @cLabelNo        
                       , EditDate = GetDate()      
                       , EditWho  = suser_sname()      
                       , UOMQty   = @nQty  
                       , Trafficcop = NULL      
                  WHERE  PickDetailKey = @cPickDetailKey        
                  AND Status = '5'      
            
                  SET @nErrNo = @@ERROR        
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 96757      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail    
                     GOTO RollBackTran        
                  END        
            
                  SET @nPackQty = @nPDQty                             
               END        
               ELSE        
               IF @nQty > @nPDQty        
               BEGIN        
                  -- Confirm PickDetail        
              UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET    CaseID = @cLabelNo       
                      , EditDate = GetDate()      
                      , EditWho  = suser_sname()    
                      , UOMQty   = @nQty    
                      , Trafficcop = NULL      
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'        
                  
                  SET @nErrNo = @@ERROR        
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 96758      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
                         
                  SET @nPackQty = @nPDQty          
               END        
               ELSE        
               IF @nQty < @nPDQty AND @nQty > 0        
               BEGIN        
                  IF @nQty > 0       
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
                        SET @nErrNo = 96759        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail     
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
                        )        
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
                            ,@nPDQty - @nQty,NULL            ,'1'  --OptimizeCop,        
                            ,TaskDetailKey        
                     FROM   dbo.PickDetail WITH (NOLOCK)        
                     WHERE  PickDetailKey = @cPickDetailKey        
                  
                     IF @@ERROR <> 0        
                     BEGIN        
                        SET @nErrNo = 96760        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetFail    
                        GOTO RollBackTran        
                     END        
                                     
                     -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop        
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)        
                     UPDATE dbo.PickDetail WITH (ROWLOCK)        
                     SET    QTY = @nQty      
                           , CaseID = @cLabelNo  
                           , EditDate = GetDate()      
                           , EditWho  = suser_sname()     
                           , UOMQty   = @nQty   
                           , Trafficcop = NULL       
                     WHERE  PickDetailKey = @cPickDetailKey      
                     AND Status = '5'        
                     
                     IF @@ERROR <> 0        
                     BEGIN        
                        SET @nErrNo = 96761        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                        GOTO RollBackTran        
                     END        
                     
                     UPDATE dbo.PickDetail WITH (ROWLOCK)        
                      SET    Status = CASE WHEN @cPTSStatus  = '4' THEN @cPTSStatus ELSE '5' END
                           , EditDate = GetDate()      
                           , EditWho  = suser_sname()   
                           --, UOMQty   = @nQty    
                           , Trafficcop = NULL      
                     WHERE  PickDetailKey = @cNewPickDetailKey        
                     AND Status = '5'      
                              
                     SET @nErrNo = @@ERROR        
                     IF @nErrNo <> 0        
                     BEGIN        
                        SET @nErrNo = 96762      
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                        GOTO RollBackTran        
                     END        
                           
                     SET @nPackQty = @nQty    
                     
                      
                    
                  END      
               END -- @nQty < @nPDQty       
               ELSE IF @nQty = 0       
               BEGIN      
                  
                  -- Split rdt.rdtPTSLog 
                  SET @nExpectedQty = 0 
               
                  SELECT @nExpectedQty = ExpectedQty 
                  FROM rdt.rdtPTSLog WITH (NOLOCK)
                  WHERE PTSLogKey = @cPTSLogKey  
                  
                  IF @nExpectedQty = @nPDQty 
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
                         SET @nErrNo = 96763        
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                         GOTO RollBackTran        
                     END    
                 END    
                  SET @nPackQty = 0                   
               END -- IF @nQty = 0      
            END
            ELSE
            BEGIN
               
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerKey
                              AND LabelNo = @cPDCaseID ) 
               BEGIN
                  SET @cLabelNo = @cPDCaseID
                  SET @nPackQty = @nPDQty 
               END
               ELSE 
               BEGIN
                  SET @nPackQty = 0 
                     
               END
            END
            
                  
            IF @nPackQty > 0        
            BEGIN       
               IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)      
                         WHERE PickSlipNo = @cPickSlipNo      
                           AND LabelNo = @cLabelNo      
                           AND SKU     = @cSKU )      
               BEGIN                                        
                  UPDATE PACKDETAIL WITH (ROWLOCK)      
                    SET Qty = Qty + @nPackQty, EditDate = GETDATE(), EditWho = SUSER_SNAME()      
                  WHERE PickSlipNo = @cPickSlipNo      
                   AND DropID = @cLabelNo      
                   AND SKU = @cSKU    
                     
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 96764      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackDetFail   
                     GOTO RollBackTran      
                  END       
               END      
               ELSE      
               BEGIN      
                  INSERT INTO dbo.PACKDETAIL      
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)      
                  VALUES      
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU,      
                   @nPackQty, @cLabelNo,@cDropID)      
                  IF @@ERROR <> 0      
                  BEGIN      
                      SET @nErrNo = 96765      
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPackDetFail   
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
                    SET @nErrNo = 96766      
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHdrFail'      
                    GOTO RollBackTran      
                 END      
              END         
         
              IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                              WHERE PTSLogKey = @cPTSLogKey 
                              AND Status <> '9' ) 
    BEGIN
                           
                 -- Update rdt.rdtPTSLog    
                 UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
                 SET  Status = '9' -- In Progress 
                   , Qty = @nQty    
                   , LabelNo = @cLabelNo 
                   , EditDate = GetDate()
                 WHERE PTSLogKey = @cPTSLogKey  
           
                 IF @@ERROR <> 0     
                 BEGIN     
                     SET @nErrNo = 96752   
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
                     GOTO RollBackTran
                 END  
              END  

              SET @nQty = @nQty - @nPackQty -- OffSet PickQty       
              

                
              -- (ChewKP01)   
              IF @nQty < 0   
              BEGIN   
                  SET @nQty = 0   
              END  
                 
            END  -- IF @nQty > 0  
            
            SELECT @cPTLZone = PutawayZone
            FROM dbo.Loc WITH (NOLOCK) 
            WHERE Loc = @cPTSPosition
            AND Facility = @cFacility  

            IF @nPackQty = 0 
               SET @nEventLogQty = @nPDQty
            ELSE
               SET @nEventLogQty = @nPackQty 
            
            EXEC RDT.rdt_STD_EventLog  
                 @cActionType = '8', -- Packing  
                 @cUserID     = @cUserName,  
                 @nMobileNo   = @nMobile,  
                 @nFunctionID = @nFunc,  
                 @cFacility   = @cFacility,  
                 @cStorerKey  = @cStorerkey,  
                 @cSKU        = @cSku,  
                 @nQty        = @nEventLogQty,  
                 @cRefNo1     = @cWaveKey,  
                 @cRefNo2     = @cConsigneeKey,  
                 @cRefNo3     = @cPDCaseID,
                 @cRefNo4     = @cPTLZone,  
                 @cToLocation = @cPTSPosition,
                 @cOrderKey   = @cPDOrderKey,
                 @cDropID     = @cDropID,
                 @cUOM        = @cUOM
                 
            IF @nQty = 0       
              BREAK      
                            
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cPDCaseID, @cWaveKey                   
         END -- While Loop      
         CLOSE CursorPickDetail               
         DEALLOCATE CursorPickDetail 
         
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                      WHERE DropID = @cLabelNo
                      AND Status NOT IN ( '9' , '5' )  )
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK)
            SET Status = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()
            WHERE DropID = @cLabelNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 96775   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail    
               GOTO RollBackTran
            END
         END
         
         
         -- Split rdt.rdtPTSLog 
         IF ISNULL(@nRemainQty, 0 )  > 0 
         BEGIN
             SET @nExpectedQty = 0 
            
             SELECT @nExpectedQty = ExpectedQty 
             FROM rdt.rdtPTSLog WITH (NOLOCK)
             WHERE PTSLogKey = @cPTSLogKey  
            
             INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )   
             SELECT PTSPosition, '0', DropID, LabelNo ,StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                   ,@nRemainQty, 0, @cPTSLogKey, @nFunc, GetDate(), @cUserName   
             FROM rdt.rdtPTSLog WITH (NOLOCK)   
             WHERE PTSLogKey = @cPTSLogKey
             
             IF @@ERROR <> 0   
             BEGIN  
SET @nErrNo = 96769      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail    
                GOTO RollBackTran    
             END 
         END
         
          
         
      END
      
--      IF @nStep = 5 
--      BEGIN
--         
--         IF @cShort = '1'
--         BEGIN 
--            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
--            SET Qty  = @nQTY
--               ,Status = '4'
--               ,Editdate = GetDate()
--            WHERE PTSLogKey = @cPTSLogKey  
--              
--            IF @@ERROR <> 0     
--            BEGIN     
--                  SET @nErrNo = 96767    
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
--                  GOTO RollBackTran    
--            END        
--         END
--         ELSE
--         BEGIN
--            SET @nExpectedQty = 0 
--            
--            SELECT @nExpectedQty = ExpectedQty 
--            FROM rdt.rdtPTSLog WITH (NOLOCK)
--            WHERE PTSLogKey = @cPTSLogKey  
--            
--            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
--            SET Qty  = @nQTY
--               ,Editdate = GetDate()
--            WHERE PTSLogKey = @cPTSLogKey  
--              
--            IF @@ERROR <> 0     
--            BEGIN     
--                  SET @nErrNo = 96768    
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
--                  GOTO RollBackTran    
--            END     
--            
--            INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
--                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )   
--            SELECT PTSPosition, '0', DropID, LabelNo ,StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
--                  ,@nExpectedQTY - @nQTY, 0, @cPTSLogKey, @nFunc, GetDate(), @cUserName   
--            FROM rdt.rdtPTSLog WITH (NOLOCK)   
--            WHERE PTSLogKey = @cPTSLogKey
--            
--            IF @@ERROR <> 0   
--            BEGIN  
--               SET @nErrNo = 96769      
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail    
--               GOTO RollBackTran    
--            END  
--         END
--         
--      END
   END   



   GOTO QUIT 
   
RollBackTran:
   ROLLBACK TRAN rdt_761ExtUpdSP01 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_761ExtUpdSP01
  

END  


GO