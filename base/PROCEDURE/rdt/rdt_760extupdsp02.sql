SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_760ExtUpdSP02                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-03-01  1.0  ChewKP   Created                                    */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_760ExtUpdSP02] (  
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
          , @cConsigneeTag         NVARCHAR(20)
          

   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
  
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_760ExtUpdSP02
   
   IF @nFunc = 760
   BEGIN
      
      IF @nStep = 1 
      BEGIN
          
          
          DECLARE CursorPTLSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
    
          SELECT O.OrderGroup
               , PD.DropID
               , O.OrderKey
               , PD.StorerKey
               , PD.SKU
               , SUM(PD.Qty)
               , O.ConsigneeKey
               , PD.UOM
               , PD.Loc
               , PD.Lot
          FROM dbo.PickDetail PD WITH (NOLOCK) 
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
          WHERE PD.StorerKey           = @cStorerKey
            AND PD.DropID              = @cDropID
            AND PD.Status              = '5'
            AND PD.Qty > 0 
            --AND PD.CaseID = ''
          GROUP BY O.OrderGroup, PD.DropID, O.OrderKey, PD.StorerKey, PD.SKU, O.ConsigneeKey,
                   PD.UOM, PD.Loc, PD.Lot
          ORDER BY PD.SKU
          
          
          OPEN CursorPTLSLog            
          
          FETCH NEXT FROM CursorPTLSLog INTO @cPTSPosition, @cDropID, @cOrderKey, @cStorerKey, @cSKU, 
                                             @nExpectedQty, @cConsigneeKey, @cUOM, @cLoc, @cLot
                                             
          
          
          WHILE @@FETCH_STATUS <> -1     
          BEGIN
            
--            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
--                        WHERE StorerKey         = @cStorerKey
--                        AND DropID              = @cDropID
--                        AND Status = '5'
--                        AND CaseID = @cPTSPosition ) 
--            BEGIN
--                SET @nErrNo = 98520
--                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'DropIDSorted'
--                GOTO RollBackTran
--            END
            SET @nTotalPackedQty = 0
            SET @nTotalPickedQty = 0

            SELECT @nTotalPickedQty = SUM(QTY) 
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey           = @cStorerKey
            AND DropID              = @cDropID
            AND Status              = '5'
            AND Qty > 0 
            
            
            SELECT @cPickSlipNo = PickSlipNo 
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            
            SELECT @nTotalPackedQty = SUM(QTY) 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey     = @cStorerKey
            AND PickSlipNo      = @cPickSlipNo 
            
            IF @nTotalPackedQty >= @nTotalPickedQty
            BEGIN
                SET @nErrNo = 98520
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'DropIDSorted'
                GOTO RollBackTran
            END
            
            IF NOT  EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey 
                        AND SKU = @cSKU
                        AND Loc = @cLoc
                        AND Lot = @cLot
                        AND OrderKey = @cOrderKey 
                        AND CaseID = @cPTSPosition ) 
            BEGIN 
               INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                          ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho ) 
               VALUES (@cPTSPosition, '0', @cDropID, '', @cStorerKey, @cConsigneeKey, @cOrderKey, @cSKU, @cLoc, @cLot, @cUOM,
                       @nExpectedQty, '0', '', @nFunc, GetDate(), @cUserName ) 
            
               IF @@ERROR <> 0 
               BEGIN
                   SET @nErrNo = 98501
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLLogFail'
                   GOTO RollBackTran
               END
            END
            
            
            
            FETCH NEXT FROM CursorPTLSLog INTO @cPTSPosition, @cDropID, @cOrderKey, @cStorerKey, @cSKU, 
                                               @nExpectedQty, @cConsigneeKey, @cUOM, @cLoc, @cLot
                                             
          END
          CLOSE CursorPTLSLog            
          DEALLOCATE CursorPTLSLog   
          
          IF NOT EXISTS (SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND DropID = @cDropID
                         AND Status = 0  )
          BEGIN
             SET @nErrNo = 98522
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvalidDropID'
             GOTO RollBackTran
          END
         
         
      END
      
      IF @nStep = 3
      BEGIN
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                     WHERE PTSLogKey = @cPTSLogKey
                     AND ExpectedQty < @nQty ) 
         BEGIN 
               SET @nErrNo = 98521    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidQty    
               GOTO RollBackTran
         END
         
         UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
         SET  Status = '5' -- In Progress    
            , Qty  = Qty + @nQty
            , EditDate = GetDate()
         WHERE PTSLogKey = @cPTSLogKey  
         
         IF @@ERROR <> 0     
         BEGIN     
               SET @nErrNo = 98502    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
               GOTO RollBackTran
         END    
         
         SELECT @cSuggLabelNo = PTSPosition 
         FROM rdt.rdtPTSLog WITH (NOLOCK) 
         WHERE PTSLogKey = @cPTSLogKey 

         --INSERT INTO TraceInfo (TraceName , TimeIN, col1, col2 ) 
         --VALUES ( 'rdt_760ExtUpdSP02' , getdate() , @cPTSLogKey , @cSuggLabelNo ) 
         
      END
      
      IF @nStep = 4 
      BEGIN
         
         IF @nQty = 0 
         BEGIN 
            GOTO QUIT 
         END

         

         --Update PickDetail & Create PackDetail
         SET @nCartonNo = 0      
         SET @cLabelLine = '00000'   
         SET @cConsigneeKey = '' 
         
         
          
         SELECT  @cConsigneeTag = PTSPosition
               , @cPTSStatus    = Status
               , @cDropID       = DropID
               , @nQty          = Qty 
         FROM rdt.rdtPTSLog WITH (NOLOCK)
         WHERE PTSLogKey = @cPTSLogKey 
         
         

         IF @cLabelNo <> @cConsigneeTag
         BEGIN
             SET @cSuggLabelNo = @cConsigneeTag
             SET @nErrNo = 98519      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidToLabel 
             GOTO RollBackTran      
         END
         
         
         
         
         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
         SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey      
         FROM dbo.Pickdetail PD WITH (NOLOCK)      
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey      
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber      
         WHERE PD.DropID = @cDropID      
         AND PD.Status = '5'      
         AND PD.SKU    = @cSKU      
         AND ISNULL(PD.CaseID,'')  <> @cLabelNo      
         AND O.OrderGroup = @cConsigneeTag      
         ORDER BY PD.SKU , PD.PickDetailKey   
         
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
                  SET @nErrNo = 98503      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPackHFail 
                  GOTO RollBackTran      
               END      
                     
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate )       
               VALUES (@cPickSlipNo, GetDate(), suser_sname(), '')       
                     
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 98504      
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
                                  
               
            SET @nPackQty = 0       
            
            

            IF @nPDQty=@nQty        
            BEGIN        
               -- Confirm PickDetail        
               UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET CaseID = @cLabelNo        
                    , EditDate = GetDate()      
                    , EditWho  = suser_sname()      
                    , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey        
               AND Status = '5'      
         
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 98505      
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
                   , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey      
               AND Status = '5'        
               
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 98506      
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
                     SET @nErrNo = 98507        
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
                     SET @nErrNo = 98508        
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
                        , Trafficcop = NULL       
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'        
                  
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 98509        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
                  
                  UPDATE dbo.PickDetail WITH (ROWLOCK)        
                   SET    Status = CASE WHEN @cPTSStatus  = '4' THEN @cPTSStatus ELSE '5' END
                        , EditDate = GetDate()      
                        , EditWho  = suser_sname()   
                        , Trafficcop = NULL      
                  WHERE  PickDetailKey = @cNewPickDetailKey        
                  AND Status = '5'      
                           
                  SET @nErrNo = @@ERROR        
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 98510      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
                        
                  SET @nPackQty = @nQty       
                 
               END      
            END -- @nQty < @nPDQty       
            ELSE IF @nQty = 0       
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
                   SET @nErrNo = 98511        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                   GOTO RollBackTran        
               END        
               SET @nPackQty = 0                   
            END -- IF @nQty = 0      
                  
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
                   AND LabelNo = @cLabelNo      
                   AND SKU = @cSKU    
                     
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 98512      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackDetFail   
                     GOTO RollBackTran      
                  END       
               END      
               ELSE      
               BEGIN      
                  INSERT INTO dbo.PACKDETAIL      
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID)      
                  VALUES      
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU,      
                   @nPackQty,@cDropID)      
                  IF @@ERROR <> 0      
                  BEGIN      
                      SET @nErrNo = 98513      
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
                    SET @nErrNo = 98514      
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHdrFail'      
                    GOTO RollBackTran      
                 END      
              END         
         
              
              SET @nQty = @nQty - @nPackQty -- OffSet PickQty       
                
              
              IF @nQty < 0   
              BEGIN   
                  SET @nQty = 0   
              END  
                 
            END  -- IF @nQty > 0  
            
            
                 
            IF @nQty = 0       
              BREAK      
                            
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey                   
         END -- While Loop      
         CLOSE CursorPickDetail               
         DEALLOCATE CursorPickDetail 
         
         -- Update rdt.rdtPTSLog    
         UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
         SET  Status = '9' -- In Progress    
            , LabelNo = @cLabelNo 
            , EditDate = GetDate()
         WHERE PTSLogKey = @cPTSLogKey  
           
         IF @@ERROR <> 0     
         BEGIN     
               SET @nErrNo = 98515   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
               GOTO RollBackTran
         END    
         
      END
      
      IF @nStep = 5 
      BEGIN
         SELECT @cSuggLabelNo = PTSPosition 
         FROM rdt.rdtPTSLog WITH (NOLOCK) 
         WHERE PTSLogKey = @cPTSLogKey 
         
         IF @cShort = '1'
         BEGIN 
            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
            SET Qty  = @nQTY
               ,Status = '4'
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey  
              
            IF @@ERROR <> 0     
            BEGIN     
                  SET @nErrNo = 98516    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
                  GOTO RollBackTran    
            END        
         END
         ELSE
         BEGIN
            SET @nExpectedQty = 0 
            
            SELECT @nExpectedQty = ExpectedQty 
            FROM rdt.rdtPTSLog WITH (NOLOCK)
            WHERE PTSLogKey = @cPTSLogKey  
            
            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
            SET Qty  = @nQTY
               ,Status = CASE WHEN @nQty = 0 THEN '9' ELSE Status END
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey  
              
            IF @@ERROR <> 0     
            BEGIN     
                  SET @nErrNo = 98517    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
                  GOTO RollBackTran    
            END     
            
            IF @nQTY <>  0 
            BEGIN  
               INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                        ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )   
               SELECT PTSPosition, '0', DropID, LabelNo ,StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                     ,@nExpectedQTY - @nQTY, 0, @cPTSLogKey, @nFunc, GetDate(), @cUserName   
               FROM rdt.rdtPTSLog WITH (NOLOCK)   
               WHERE PTSLogKey = @cPTSLogKey
            
               IF @@ERROR <> 0   
               BEGIN  
                  SET @nErrNo = 98518      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail    
                  GOTO RollBackTran    
               END  
            END
         END
         
      END
   END   



   GOTO QUIT 
   
RollBackTran:
   ROLLBACK TRAN rdt_760ExtUpdSP02 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760ExtUpdSP02
  

END  

GO