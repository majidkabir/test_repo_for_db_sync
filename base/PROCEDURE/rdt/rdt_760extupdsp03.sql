SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_760ExtUpdSP03                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-07-19  1.0  ChewKP   SOS#372470 Created                         */ 
/* 2018-02-02  1.1  JHTAN    INC0122293 Wrong Position return (JH01)    */   
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_760ExtUpdSP03] (  
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


   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
  
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_760ExtUpdSP03
   
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
                SET @nErrNo = 102501
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvDropID'
                GOTO RollBackTran
          END


          IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                          INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PD.Loc
                          WHERE PD.StorerKey = @cStorerKey
                          AND PD.DropID = @cDropID
                          AND PD.Status = '5'
                          AND PD.CaseID = ''
                          AND PD.Qty > 0 
                          AND Loc.LocationCategory = 'WIP' ) 
          BEGIN
                SET @nErrNo = 102516
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvDropID'
                GOTO RollBackTran
          END         
          
          
          DECLARE CursorPTLSLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
    
          SELECT O.LoadKey
               , O.ConsigneeKey
               , PD.DropID
               , O.OrderKey
               , PD.SKU
               , SUM(PD.Qty)
               --, PD.PickSlipNo
               --, PD.UOM
               , PD.Loc
               --, PD.Lot
               , PD.WaveKey
               , PZ.Inloc 
          FROM dbo.PickDetail PD WITH (NOLOCK) 
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
          INNER JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON O.OrderKey = PTL.OrderKey AND O.UserDefine09 = PTL.WaveKey 
          INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc AND Loc.Facility = O.Facility 
          INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.PutawayZone
          WHERE PD.StorerKey           = @cStorerKey
            AND PD.DropID              = @cDropID
            AND PD.Status              = '5'
            AND PD.Qty > 0 
            AND PD.CaseID = ''
          GROUP BY O.LoadKey, O.ConsigneeKey, PD.DropID, O.OrderKey, PD.StorerKey, PD.SKU, --PD.PickSlipNo,O.OrderKey, 
                   PD.Loc, PD.WaveKey, PZ.Inloc 
          ORDER BY PD.SKU
          
          
          OPEN CursorPTLSLog            
          
          FETCH NEXT FROM CursorPTLSLog INTO @cLoadKey, @cConsigneeKey, @cDropID, @cOrderKey, @cSKU, 
                                             @nExpectedQty, @cLoc, @cWaveKey, @cPTSLoc
                                             
          
          
          WHILE @@FETCH_STATUS <> -1     
          BEGIN
            
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
                            WHERE OrderKey IN ( SELECT DISTINCT Orderkey FROM dbo.PickDetail WITH (NOLOCK) 
                                                WHERE StorerKey  = @cStorerKey
                                                AND DropID       = @cDropID
                                                AND Status       = '5'
                                                AND Qty          > 0 
                                                AND CaseID       = ''
                                                AND WaveKey      = @cWaveKey ) )
            BEGIN
                SET @nErrNo = 102502
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OrderNotAssign'
                GOTO RollBackTran
            END
            
            --SET @cPTSLoc = ''
            
            SET @cPTSPosition = '' 
            
            SELECT @cPackKey = ISNULL(PackKey,'')  
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU 
            
            SELECT @nCaseCnt = ISNULL(CaseCnt,0)  
            FROM dbo.Pack WITH (NOLOCK) 
            WHERE PackKey = @cPackKey 
            
            IF @nCaseCnt = 0 
            BEGIN 
                SET @nErrNo = 102522
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvalidCaseCnt'
                GOTO RollBackTran
            END
            
            SET @nPQTY = @nExpectedQTY / @nCaseCnt  -- Calc QTY in preferred UOM    
            SET @nMQTY = @nExpectedQTY % @nCaseCnt  -- Calc the remaining in master unit    
            
            
            IF ISNULL(@nMQTY,0)  <> '0'
            BEGIN 
            
               SELECT TOP 1 @cPTSPosition = PZ.InLoc 
               FROM dbo.PutawayZone PZ  WITH (NOLOCK) 
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON ( Loc.PutawayZone = PZ.PutawayZone  AND Loc.Facility = PZ.Facility ) 
               WHERE Loc.Facility = @cFacility 
               AND Loc.Loc = @cPTSLoc 
   
               
               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey
                               AND DropID = @cDropID
                               --AND OrderKey = @cOrderKey 
                               --AND ConsigneeKey = @cConsigneeKey  
                               AND Status <> '9' 
                               AND PTSPosition = @cPTSPosition
                               AND AddWho = @cUserName  ) 
               BEGIN
                  INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                             ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho ) 
                  VALUES (@cPTSPosition, '0', @cDropID, '', @cStorerKey, @cConsigneeKey, '', @cSKU, @cLoc, @cLot, '6',
                          @nMQTY, '0', '', @nFunc, GetDate(), @cUserName ) 
               
                  IF @@ERROR <> 0 
                  BEGIN
                      SET @nErrNo = 102503
                      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLLogFail'
                      GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  
                  UPDATE rdt.rdtPTSLog WITH (ROWLOCK) 
                  SET ExpectedQty = ExpectedQty + @nMQTY 
                  WHERE StorerKey = @cStorerKey
                    AND DropID = @cDropID
                    AND Status <> '9' 
                    AND AddWho = @cUserName 
                    AND PTSPosition = @cPTSPosition 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                      SET @nErrNo = 102524
                      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLLogFail'
                      GOTO RollBackTran
                  END
                  
               END
            END
            
            IF ISNULL(@nPQTY,0)  <> 0 
            BEGIN
               
                  
                  SELECT @cPTSPosition = Long 
                  FROM dbo.Codelkup WITH (NOLOCK) 
                  WHERE ListName = 'PSTOLOC'
                  AND Code = 'FPTOLOC'
                  AND StorerKey = @cStorerKey  --(JH01) 
                  
                   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey
                               AND DropID = @cDropID
                               --AND OrderKey = @cOrderKey 
                               --AND ConsigneeKey = @cConsigneeKey  
                               AND Status <> '9' 
                               AND PTSPosition = @cPTSPosition
                               AND AddWho = @cUserName  ) 
                  BEGIN                                
                  
                     INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM  
                                                ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho ) 
                     VALUES (@cPTSPosition, '0', @cDropID, '', @cStorerKey, @cConsigneeKey, '', @cSKU, @cLoc, @cLot, '2',
                             (@nPQTY * @nCaseCnt), '0', '', @nFunc, GetDate(), @cUserName ) 
                  
                     IF @@ERROR <> 0 
                     BEGIN
                         SET @nErrNo = 102518 
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPTLLogFail'
                         GOTO RollBackTran
                     END
                  END   
                  ELSE
                  BEGIN
                      UPDATE rdt.rdtPTSLog WITH (ROWLOCK) 
                      SET ExpectedQty = ExpectedQty + (@nPQTY * @nCaseCnt)
                      WHERE StorerKey = @cStorerKey
                        AND DropID = @cDropID
                        AND Status <> '9' 
                        AND AddWho = @cUserName 
                        AND PTSPosition = @cPTSPosition 
                     
                      IF @@ERROR <> 0 
                      BEGIN
                          SET @nErrNo = 102523
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLLogFail'
                          GOTO RollBackTran
                      END
                     
                  END  
                  
--               END
            END
            
            FETCH NEXT FROM CursorPTLSLog INTO @cLoadKey, @cConsigneeKey, @cDropID, @cOrderKey, @cSKU, 
                                             @nExpectedQty, @cLoc, @cWaveKey, @cPTSLoc
          
                                             
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
               SET @nErrNo = 102504    
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
         
         SELECT @cPutawayZone = ISNULL(PutawayZone ,'' ) 
         FROM dbo.Loc WITH (NOLOCK) 
         WHERE Loc = @cPTSPosition
         AND Facility = @cFacility
         
         SELECT @cFromLoc = Long
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE Code = 'PPTOLOC'
         AND StorerKey = @cStorerKey 
         
         SET @nCountTask = 0 
         SELECT @nCountTask = Count(Distinct PTSLogKey) 
         FROM rdt.rdtPTSLog WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND Status <> '9'

         
         
         IF ISNULL(@nCountTask,0) <> 1 AND @cLabelNo = @cDropID
         BEGIN
            SET @nErrNo = 102519      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidToLabel    
            GOTO RollBackTran    
         END   
    
         SELECT @nCountWIPTask = Count(Distinct LLI.Loc ) 
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.ID = @cLabelNo
         AND LLI.Qty > 0
         AND Loc.Facility = @cFacility
         AND Loc.LocationType = 'WIP'
         
         IF @nCountWIPTask = 1 
         BEGIN
              
            SELECT @cWIPLoc  = LLI.Loc 
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.ID = @cLabelNo
            AND LLI.Qty > 0
            AND Loc.Facility = @cFacility
            AND Loc.LocationType = 'WIP'

            IF @cWIPLoc <> @cFromLoc
            BEGIN
               SET @nErrNo = 102538      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvDropID    
               GOTO RollBackTran    
            END
            ELSE
            BEGIN
               IF NOT EXISTS (SELECT 1 
                              FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                              INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
                              WHERE LLI.StorerKey = @cStorerKey
                              AND LLI.ID = @cDropID
                              AND LLI.Qty > 0
                              AND Loc.Facility = @cFacility
                              AND Loc.LocationType = 'WIP'
                              AND Loc.Loc = @cWIPLoc )
               BEGIN
                  SET @nErrNo = 102539      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvDropID    
                  GOTO RollBackTran    
               END
            END
         END
         ELSE IF @nCountWIPTask > 1 
         BEGIN
               
               --SELECT @nCountWIPTask = Count(Distinct Loc) 
               --FROM dbo.LotxLocxID WITH (NOLOCK) 
               --WHERE StorerKey = @cStorerKey
               --AND ID = @cDropID
               --AND Loc = @cFromLoc 

               --IF @nCountWIPTask > 1 
               --BEGIN
                  SET @nErrNo = 102525      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvDropID    
                  GOTO RollBackTran    
               ---END
         END    

            
         

         
         
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKEy = @cStorerKey
                     AND Status = '5'
                     AND CaseID <> ''
                     AND SKU    <> @cSKU
                     AND DropID = @cDropID ) 
         BEGIN
            SET @nErrNo = 102521      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidToLabel    
            GOTO RollBackTran    
         END              
         
      
         
         
--         IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
--                     WHERE StorerKey = @cStorerKey
--                     AND ID = @cDropID
--                     AND Loc = @cFromLoc
--                     AND Qty > 0 ) 
--         BEGIN
--            SET @nErrNo = 102537      
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvDropID    
--            GOTO RollBackTran    
--         END                   
                
         
         SELECT @nTotalLLIQty = SUM(Qty)
         FROM dbo.LotxLocxID WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND ID = @cDropID 
         
         SELECT @nTotalPDQty = SUM(QTY) 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND ID = @cDropID 
         
         IF ISNULL(@nTotalLLIQty,0)  > ISNULL(@nTotalPDQty ,0 ) 
         BEGIN 
            IF @cLabelNo = @cDropID 
            BEGIN
               SET @nErrNo = 102520      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidToLabel    
               GOTO RollBackTran    
            END
         END

      
         --Declare @nTestQty INT 
         --SET @nTestQty = 0 
         
         -- First Loop Exact Match with CaseCnt
         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
         SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.ID
         FROM dbo.Pickdetail PD WITH (NOLOCK)     
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey      
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber     
         INNER JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON O.OrderKey = PTL.OrderKey 
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc 
         WHERE PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cDropID      
         AND PD.Status = '5'      
         AND PD.SKU    = @cSKU    
         --AND PD.OrderKey = @cOrderKey  
         AND ISNULL(PD.CaseID,'')  = ''      
         --AND PD.UOM = @cUOM 
         AND PD.Loc = @cFromLoc
         AND Loc.PutawayZone = CASE WHEN @cUOM = '2' THEN Loc.PutawayZone ELSE @cPutawayZone END
         ORDER BY PD.OrderKey, PD.SKU, PD.Qty Desc
         
         OPEN  CursorPickDetail      
         
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey,  @cFromID    
         
         WHILE @@FETCH_STATUS <> -1           
         BEGIN      
            

            SET @nMVQty = 0 
            
            SET @cPackKey = '' 
            SET @nCaseCnt = 0

            SELECT @cPackKey = ISNULL(PackKey,'')  
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU 
            
            SELECT @nCaseCnt = ISNULL(CaseCnt,0)  
            FROM dbo.Pack WITH (NOLOCK) 
            WHERE PackKey = @cPackKey 
            
            
            -- Get Qty that able to Match CaseCnt first 
            
            IF @cUOM = '2' 
            BEGIN 
              SET @nRemainder = 0 
               SET @nAvailableCaseQty = 0 
   
               SET @nRemainder = ISNULL(@nPDQty % @nCaseCnt, 0 ) 
               SET @nAvailableCaseQty = (@nPDQty / @nCaseCnt) * @nCaseCnt
 
            END
            ELSE
            BEGIN
               SET @nRemainder = 0 
               SET @nAvailableCaseQty = 0 
            END
  

            IF @nPDQty=@nQty AND @nRemainder = 0   
            BEGIN        
               -- Confirm PickDetail        
               UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET DropID = @cLabelNo        
                    , EditDate = GetDate()      
                    , EditWho  = suser_sname()      
                    , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey        
               AND Status = '5'      
         
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 102505      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail    
                  GOTO RollBackTran        
               END        

               
               SET @nMVQty = @nPDQty 
               SET @nQty = @nQty - @nPDQty        
                                  
            END        
            ELSE        
            IF @nQty > @nPDQty AND @nRemainder = 0         
            BEGIN        
               
               -- Confirm PickDetail        
               UPDATE dbo.PickDetail WITH (ROWLOCK)        
               SET   DropID = @cLabelNo       
                   , EditDate = GetDate()      
                   , EditWho  = suser_sname()    
                   , Trafficcop = NULL      
               WHERE  PickDetailKey = @cPickDetailKey      
               AND Status = '5'        
               
               SET @nErrNo = @@ERROR        
               IF @nErrNo <> 0        
               BEGIN        
                  SET @nErrNo = 102506      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                  GOTO RollBackTran        
               END        
                      
               SET @nQty = @nQty - @nPDQty 
               SET @nMVQty = @nPDQty 

               
               
            END        
            ELSE        
            IF @nQty < @nPDQty AND @nQty > 0  AND @nRemainder = 0        
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
                     SET @nErrNo = 102507        
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
                     SET @nErrNo = 102508        
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
                        , Trafficcop = NULL       
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'        
                  
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 102509        
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
                     SET @nErrNo = 102510      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
            
                  SET @nMVQty = @nQty       
                  SET @nQty = 0
                  
                 
               END      
            END -- @nQty < @nPDQty     
            ELSE IF @nRemainder <> 0 --@nQty >= @nPDQty ANd @nRemainder <> 0 
            BEGIN
               SET @nTotalOrderQty = 0 
               SELECT @nTotalOrderQty = SUM(Qty) 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
               AND OrderKey = @cPDOrderKey 
               AND DropID IN (  @cDropID , @cLabelNo ) 
               AND Status = '5' 
                              
               

               IF ISNULL(@nTotalOrderQty % @nCaseCnt,0 )  = 0 
               BEGIN
                 

                   -- Confirm PickDetail        
                  UPDATE dbo.PickDetail WITH (ROWLOCK)        
                     SET DropID = @cLabelNo        
                       , EditDate = GetDate()      
                       , EditWho  = suser_sname()      
                       , Trafficcop = NULL      
                  WHERE  PickDetailKey = @cPickDetailKey        
                  AND Status = '5'      
            
                  SET @nErrNo = @@ERROR        
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 102540      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail    
                     GOTO RollBackTran        
                  END        
   
                  
                  SET @nMVQty = @nPDQty 
                  SET @nQty = @nQty - @nPDQty    
               END
               ELSE            
               IF @nPDQty > @nAvailableCaseQty AND @nAvailableCaseQty > 0 
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
                     SET @nErrNo = 102533        
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
                         ,@nPDQty - @nAvailableCaseQty,NULL            ,'1'  --OptimizeCop,        
                         ,TaskDetailKey        
                  FROM   dbo.PickDetail WITH (NOLOCK)        
                  WHERE  PickDetailKey = @cPickDetailKey        
               
                  

                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 102534        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetFail    
                     GOTO RollBackTran        
                  END        
                  
                  

                  -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop        
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)        
                  UPDATE dbo.PickDetail WITH (ROWLOCK)        
                  SET    QTY = @nAvailableCaseQty      
                        , DropID = @cLabelNo  
                        , EditDate = GetDate()      
                        , EditWho  = suser_sname()     
                        , Trafficcop = NULL       
                  WHERE  PickDetailKey = @cPickDetailKey      
                  AND Status = '5'        
                  
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 102535        
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
                     SET @nErrNo = 102536      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                     GOTO RollBackTran        
                  END        
            
                  SET @nMVQty = @nAvailableCaseQty       
                  SET @nQty = @nQty - @nAvailableCaseQty 
                  
                 
               END      
            END
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
                   SET @nErrNo = 102511        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail 
                   GOTO RollBackTran        
               END        
               --SET @nPackQty = 0   
               SET @nMVQty = 0                  
            END -- IF @nQty = 0      
            
            
            IF @nMVQTY > 0 
            BEGIN 
               ---- Perform MOVE --
               EXECUTE rdt.rdt_Move    
                   @nMobile     = @nMobile,    
                   @cLangCode   = @cLangCode,    
                   @nErrNo      = @nErrNo  OUTPUT,    
                   @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max    
                   @cSourceType = 'rdt_760ExtUpdSP03',    
                   @cStorerKey  = @cStorerKey,    
                   @cFacility   = @cFacility,    
                   @cFromLOC    = @cFromLOC,    
                   @cToLOC      = @cPTSPosition,    
                   @cFromID     = @cFromID,           -- NULL means not filter by ID. Blank is a valid ID    
                   @cToID       = @cLabelNo,          -- NULL means not changing ID. Blank consider a valid ID    
                   @cSKU        = @cSKU,    
                   @nQTY        = @nMVQTY,   
                   @nFunc       = @nFunc,
                   @nQTYPick    = @nMVQTY,   
                   @cDropID     = @cLabelNo
            
               IF @nErrNo <> 0 
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO RollBackTran
               END
            END
            
            

            IF @nQty = 0       
              BREAK      
            
            NextCursor:                
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
               SET @nErrNo = 102512   
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
                  SET @nErrNo = 102513    
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
                  SET @nErrNo = 102514    
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
               SET @nErrNo = 102515      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail    
               GOTO RollBackTran    
            END  
         END
         
      END
   END 



   GOTO QUIT 
   
RollBackTran:
   ROLLBACK TRAN rdt_760ExtUpdSP03 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760ExtUpdSP03
  

END  



GO