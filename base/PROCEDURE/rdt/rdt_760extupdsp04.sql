SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_760ExtUpdSP04                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2017-10-30  1.0  ChewKP   WMS-3342 Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_760ExtUpdSP04] (  
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
          , @cConsigneeTag         NVARCHAR(10)
          , @cLoadKey              NVARCHAR(10)
          , @cWaveKey              NVARCHAR(10)
          , @cFromLoc              NVARCHAR(10)
          , @nMVQty                INT
          , @cFromID               NVARCHAR(18)
          , @cPTSLoc               NVARCHAR(10) 
          , @nPQty                 INT
          , @nMQty                 INT
          , @cPackKey              NVARCHAR(10) 
          , @nCaseCnt              INT
          , @nCountTask            INT
          , @nTotalLLIQty          INT
          , @nTotalPDQty           INT
          , @cPutawayZone          NVARCHAR(10) 
          , @nRemainder            INT
          , @nAvailableCaseQty     INT 
          , @nCountWIPTask         INT
          , @cWIPLoc               NVARCHAR(10) 
          , @nTotalOrderQty        INT
          , @cCountry              NVARCHAR(30) 



   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
  
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_760ExtUpdSP04
   
   IF @nFunc = 760
   BEGIN
      
      IF @nStep = 1 
      BEGIN
          
          IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                          WHERE StorerKey = @cStorerKey
                          AND DropID = @cDropID
                          AND Status = '5'
                          AND CaseID = ''
                          AND Qty > 0  ) 
          BEGIN
                SET @nErrNo = 116301
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvDropID'
                GOTO RollBackTran
          END
                 
          
          
          DECLARE CursorPTLSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
    
          SELECT O.C_Country
               , O.OrderKey
               , PD.SKU
               , SUM(PD.Qty)
               , PD.WaveKey
          FROM dbo.PickDetail PD WITH (NOLOCK) 
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
          WHERE PD.StorerKey           = @cStorerKey
            AND PD.DropID              = @cDropID
            AND PD.Status              = '5'
            AND PD.Qty > 0 
            AND PD.CaseID = ''
          GROUP BY O.C_Country, O.OrderKey, PD.SKU, PD.WaveKey
          ORDER BY PD.SKU
          
          
          OPEN CursorPTLSLog            
          
          FETCH NEXT FROM CursorPTLSLog INTO @cCountry, @cOrderKey, @cSKU, @nExpectedQty, @cWaveKey
                                                       
          
          WHILE @@FETCH_STATUS <> -1     
          BEGIN
            
            --SET @cPTSLoc = ''
            
            SET @cPTSPosition = '' 
            
            SET @cPTSPosition = @cCountry + Substring(@cOrderKey,7,10)
            
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey
                               AND DropID = @cDropID
                               AND OrderKey = @cOrderKey 
                               AND Status <> '9' 
                               --AND PTSPosition = @cPTSPosition
                               AND SKU = @cSKU 
                               AND AddWho = @cUserName  ) 
            BEGIN
               INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                          ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho ) 
               VALUES (@cPTSPosition, '0', @cDropID, '', @cStorerKey, '', @cOrderKey, @cSKU, '', '', '6',
                       @nExpectedQty, '0', '', @nFunc, GetDate(), @cUserName ) 
            
               IF @@ERROR <> 0 
               BEGIN
                   SET @nErrNo = 116302
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLLogFail'
                   GOTO RollBackTran
               END
            END
             
            
            FETCH NEXT FROM CursorPTLSLog INTO @cCountry, @cOrderKey, @cSKU, @nExpectedQty, @cWaveKey
          
                                             
          END
          CLOSE CursorPTLSLog            
          DEALLOCATE CursorPTLSLog   
         
         
      END
      
      IF @nStep = 3
      BEGIN
         
         
         UPDATE rdt.rdtPTSLog WITH (ROWLOCK)  
         SET  Status = '5' -- In Progress    
            , Qty  = Qty + @nQty
            , EditDate = GetDate()
         WHERE PTSLogKey = @cPTSLogKey  
         
         IF @@ERROR <> 0     
         BEGIN     
               SET @nErrNo = 116303    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
               GOTO RollBackTran
         END    
         
      END
      
      IF @nStep = 4 
      BEGIN
         
         --Update PickDetail 
         SELECT  
                 @cPTSStatus    = Status
               , @cDropID       = DropID
               , @nQty          = Qty 
               --, @cOrderKey     = OrderKey     
               , @cPTSPosition  = PTSPosition
               , @cUOM          = UOM
               , @cSKU          = SKU
         FROM rdt.rdtPTSLog WITH (NOLOCK)
         WHERE PTSLogKey = @cPTSLogKey 
         
                
         
         -- First Loop Exact Match with CaseCnt
         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
         SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.ID
         FROM dbo.Pickdetail PD WITH (NOLOCK)     
         WHERE PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cDropID      
         AND PD.Status = '5'      
         AND PD.SKU    = @cSKU    
         AND ISNULL(PD.CaseID,'')  = ''      
         ORDER BY PD.OrderKey, PD.SKU, PD.Qty Desc
         
         OPEN  CursorPickDetail      
         
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey,  @cFromID    
         
         WHILE @@FETCH_STATUS <> -1           
         BEGIN      
            


            IF @nPDQty=@nQty 
            BEGIN        
               -- Confirm PickDetail        
               UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET DropID = @cLabelNo        
                    , EditDate = GetDate()      
                    , EditWho  = suser_sname()      
                    , CaseID   = 'SORTED'
                    , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey        
               AND Status = '5'      
         
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 116304      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail    
                  GOTO RollBackTran        
               END        
               
               SET @nQty = @nQty - @nPDQty        
                                  
            END        
            ELSE        
            IF @nQty > @nPDQty 
            BEGIN        
               
               -- Confirm PickDetail        
               UPDATE dbo.PickDetail WITH (ROWLOCK)        
               SET   DropID = @cLabelNo       
                   , EditDate = GetDate()      
                   , EditWho  = suser_sname()  
                   , CaseID   = 'SORTED'  
                   , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey      
               AND Status = '5'        
               
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 116305      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                  GOTO RollBackTran        
               END        
                      
               SET @nQty = @nQty - @nPDQty 
               

               
               
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
                     SET @nErrNo = 116306        
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
                         ,ReplenishZone        ,DoCartonize ,PickMethod        
                         ,WaveKey              ,EffectiveDate   ,ArchiveCop        
                         ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey        
                         ,@nPDQty - @nQty,NULL            ,'1'  --OptimizeCop,        
                         ,TaskDetailKey        
                  FROM   dbo.PickDetail WITH (NOLOCK)        
                  WHERE  PickDetailKey = @cPickDetailKey        
               
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 116307        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetFail    
                     GOTO RollBackTran        
                  END        
                                  
                  -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop        
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)        
                  UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET    QTY = @nQty      
                        , DropID = @cLabelNo  
                        , EditDate = GetDate()      
                        , EditWho  = suser_sname()  
                        , CaseID   = 'SORTED'   
                        , Trafficcop = NULL       
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'        
                  
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 116308        
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
                     SET @nErrNo = 116309      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
            
                      
                  SET @nQty = 0
                  
                 
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
                   SET @nErrNo = 116310        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                   GOTO RollBackTran        
               END        
               --SET @nPackQty = 0   
               --SET @nMVQty = 0                  
            END -- IF @nQty = 0      
            

            IF @nQty = 0       
              BREAK      
            
                     
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cFromID                   
            
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
               SET @nErrNo = 116311   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
               GOTO RollBackTran
         END    
         
      END
      
      IF @nStep = 5 
      BEGIN
         
         IF @cShort = '1'
         BEGIN 
            UPDATE rdt.rdtPTSLog WITH (ROWLOCK)    
            SET Qty  = @nQTY
               ,Status = '4'
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey  
              
            IF @@ERROR <> 0     
            BEGIN     
                  SET @nErrNo = 116312    
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
               ,Editdate = GetDate()
            WHERE PTSLogKey = @cPTSLogKey  
              
            IF @@ERROR <> 0     
            BEGIN     
                  SET @nErrNo = 116313    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail    
                  GOTO RollBackTran    
            END     
                       
            INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )   
            SELECT PTSPosition, '0', DropID, LabelNo ,StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                  ,@nExpectedQTY - @nQTY, 0, @cPTSLogKey, @nFunc, GetDate(), @cUserName   
            FROM rdt.rdtPTSLog WITH (NOLOCK)   
            WHERE PTSLogKey = @cPTSLogKey
            
            IF @@ERROR <> 0   
            BEGIN  
               SET @nErrNo = 116314      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail    
               GOTO RollBackTran    
            END  
         END
         
      END
   END 



   GOTO QUIT 
   
RollBackTran:
   ROLLBACK TRAN rdt_760ExtUpdSP04 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760ExtUpdSP04
  

END  



GO