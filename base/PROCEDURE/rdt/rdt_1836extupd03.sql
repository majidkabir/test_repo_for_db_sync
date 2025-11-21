SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1836ExtUpd03                                    */    
/* Purpose: Adidas update pick task from status H -> 0                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2021-08-16   Chermaine 1.0   WMS-17384 Created                       */    
/* 2022-02-21   James     1.1   Fix update pickdetail with taskdetail   */
/*                              error (james01)                         */
/* 2022-06-28   BeeTin    1.2   added traceinfo (bttest)                */    
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1836ExtUpd03]    
   @nMobile         INT,    
   @nFunc           INT,    
   @cLangCode       NVARCHAR( 3),    
   @nStep           INT,    
   @nInputKey       INT,    
   @cTaskdetailKey  NVARCHAR( 10),    
   @cFinalLOC       NVARCHAR( 10),    
   @nErrNo          INT             OUTPUT,    
   @cErrMsg         NVARCHAR( 20)   OUTPUT,
   @bDebug          INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount        INT    
   DECLARE @cTaskKey          NVARCHAR( 10)    
   DECLARE @cTaskType         NVARCHAR( 10)    
   DECLARE @cCaseID           NVARCHAR( 20)    
   DECLARE @cStorerKey        NVARCHAR( 15)    
   DECLARE @cPickDetailKey    NVARCHAR( 15)    
   DECLARE @cWaveKey          NVARCHAR( 10)    
   DECLARE @cTDWaveKey        NVARCHAR( 10)  
   DECLARE @cFacility         NVARCHAR( 5)    
   DECLARE @cOrderKey         NVARCHAR( 10)    
   DECLARE @cLot              NVARCHAR( 10)    
   DECLARE @cLoc              NVARCHAR( 10)    
   DECLARE @cId               NVARCHAR( 10)   
   DECLARE @cSKU              NVARCHAR( 20)  
   DECLARE @nQty              INT  
   DECLARE @nPDQty            INT      
   DECLARE @nBalQty           INT  
   DECLARE @curTask           CURSOR    
   DECLARE @curPD             CURSOR    
   DECLARE @curCPK            CURSOR    
   DECLARE @bSuccess          INT
   DECLARE @cNewPickDetailKey NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_1836ExtUpd03    

   SELECT @cFacility = FACILITY    
   FROM rdt.RDTMOBREC WITH (NOLOCK)     
   WHERE Mobile = @nMobile    
    
   -- TM Replen From    
   IF @nFunc = 1836    
   BEGIN    
      IF @nStep = 1 -- Final Loc    
      BEGIN    
         DECLARE @tWaveKey TABLE    
         (    
            waveKey NVARCHAR( 10) NOT NULL  
            PRIMARY KEY CLUSTERED         
          (        
           [waveKey]        
          )        
         )   

         DECLARE @tPickDetailKey TABLE    
         (    
            PickDetailKey NVARCHAR( 10) NOT NULL  
            PRIMARY KEY CLUSTERED         
          (        
           [PickDetailKey]        
          )        
         )   
         -- Get task info    
         SELECT    
            @cTaskType = TaskType,    
            @cStorerKey = Storerkey,    
            @cWaveKey = WaveKey    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskdetailKey = @cTaskdetailKey    
           
         INSERT INTO @tWaveKey  
         SELECT DISTINCT WaveKey  
         FROM PickDetail (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND DropID IN ( SELECT CaseID FROM TaskDetail (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'RPF' AND WaveKey = @cWaveKey )  
                     
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)    
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.ToLoc = LOC.Loc)    
                     WHERE TD.Storerkey = @cStorerKey    
                     AND   TD.WaveKey = @cWaveKey    
                     AND   TD.TaskType = 'RPF'    
                     AND   TD.[Status] < '9'    
                     AND   loc.Facility = @cFacility    
                     AND   LOC.LocationGroup NOT IN ('PACKING','SORTING') )    
            GOTO RollBackTran    
           
         -- Only update pickdetail.taskDetailKey when all ASTRPT task is completed to prevent mismatch  
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)    
                     WHERE TD.Storerkey = @cStorerKey    
                     AND   TD.WaveKey = @cWaveKey    
                     AND   TD.TaskType = 'ASTRPT'    
                     AND   TD.[Status] <> '9' )    
            GOTO RollBackTran    

         -- Update pick task from status H -> 0    
         IF @cTaskType = 'ASTRPT'    
         BEGIN
            -- Check if currently the CPK/ASTCPK task has invalid task status
            IF EXISTS ( SELECT 1 
               FROM dbo.TaskDetail TD WITH (NOLOCK)        
               JOIN @tWaveKey TW ON (TD.waveKey = TW.waveKey)      
               WHERE StorerKey = @cStorerKey        
               AND   TaskType in ('CPK','ASTCPK')        
               AND   [Status] <> 'H'
               AND   ISNULL(ReasonKey,'') = '')        
            BEGIN    
               SET @nErrNo = 170212    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- TaskStatusErr    
               GOTO RollBackTran    
            END  
         
            -- Loop tasks    
            -- If all RPF task for this wave has completed then     
            -- release all CPK task    
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT TaskDetailKey, CaseID, OrderKey, Lot, FromLoc, FromID, TaskType, QTY, SKU, TD.WaveKey    
               FROM dbo.TaskDetail TD WITH (NOLOCK)    
               JOIN @tWaveKey TW ON (TD.waveKey = TW.waveKey)  
               WHERE StorerKey = @cStorerKey    
               AND   TaskType in ('CPK','ASTCPK')    
               AND   [Status] = 'H'    
               --AND   WaveKey = @cWaveKey    
               AND   ISNULL(ReasonKey,'') = ''
            OPEN @curTask    
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId, @cTaskType, @nQty, @cSKU, @cTDWaveKey    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               SET @nBalQty = @nQty  
               --INSERT INTO TRACEinfo  (tracename, TIMEIN,step1,step2, step3,step4,step5,col1,col2,col3,col4,col5)  --bttest
               --values('bttest2',getdate(),@cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId, @cTaskType, @nQty, @cSKU, @cTDWaveKey  )

               IF @cTaskType = 'CPK'    
               BEGIN                        
               	IF EXISTS ( SELECT 1
               	            FROM dbo.PICKDETAIL WITH (NOLOCK)    
                              WHERE Storerkey = @cStorerKey    
                              AND   OrderKey = @cOrderKey    
                              AND   CaseID = @cCaseID                      
                              AND   Loc = @cLoc    
                              AND   ID = @cId    
                              AND   SKU = @cSKU  
                              AND   [Status] NOT IN ( '0', '3'))
                  BEGIN    
                     SET @nErrNo = 170213    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PDTLStatusErr    
                     GOTO RollBackTran    
                  END 
                           
                  SET @curCPK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT PickDetailKey, QTY    
                     FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
                     WHERE Storerkey = @cStorerKey    
                     AND   OrderKey = @cOrderKey    
                     AND   CaseID = @cCaseID                      
                     AND   Loc = @cLoc    
                     AND   ID = @cId    
                     AND   SKU = @cSKU  
                     AND   [Status] IN ( '0', '3')    
                     --AND   Lot = @cLot
                     AND   NOT EXISTS ( SELECT 1 FROM @tPickDetailKey t WHERE t.PickDetailKey = PD.PickDetailKey)
                     ORDER BY editDate  
                     OPEN @curCPK    
                     FETCH NEXT FROM @curCPK INTO @cPickDetailKey, @nPDQty    
                     WHILE @@FETCH_STATUS = 0    
                     BEGIN    
	                     --INSERT INTO TRACEinfo  (tracename, TIMEIN,step1,step2, step3,step4,step5, Col1, Col2, Col3, Col4)  --bttest
                        --values('bttest-pd',getdate(),@cTaskKey,@cPickDetailKey,@cLoc,@cId,@cSKU, @nPDQty, @nBalQty, @cTDWaveKey, @cCaseID)
                     	
                        IF @nPDQty <= @nBalQty 
                        BEGIN
                           UPDATE dbo.PickDetail SET    
                              TaskDetailKey = @cTaskKey,    
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE()    
                           WHERE PickDetailKey = @cPickDetailKey    
                      
                           IF @@ERROR <> 0    
                           BEGIN    
                              SET @nErrNo = 170201    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail    
                              GOTO RollBackTran    
                           END   
                           
                           SET @nBalQty = @nBalQty - @nPDQty 
                           INSERT INTO @tPickDetailKey(PickDetailKey) VALUES (@cPickDetailKey)
                        END
                        ELSE IF @nPDQty > @nBalQty
                        BEGIN
                           -- Get new PickDetailkey  
                           EXECUTE dbo.nspg_GetKey  
                              'PICKDETAILKEY',  
                              10 ,  
                              @cNewPickDetailKey OUTPUT,  
                              @bSuccess          OUTPUT,  
                              @nErrNo            OUTPUT,  
                              @cErrMsg           OUTPUT  
                           IF @bSuccess <> 1  
                           BEGIN  
                              SET @nErrNo = 170204  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                              GOTO RollBackTran  
                           END  
  
                           -- Create new a PickDetail to hold the balance  
                           INSERT INTO dbo.PickDetail (  
                              CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,  
                              UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                              PickDetailKey,  
                              Status,  
                              QTY,  
                              TrafficCop,  
                              OptimizeCop,
                              Channel_ID)  
                           SELECT  
                              CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
                              UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
                              CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                              @cNewPickDetailKey,  
                              Status,  
                              @nPDQty - @nBalQty, -- QTY  
                              NULL, -- TrafficCop  
                              '1',  -- OptimizeCop  
                              Channel_ID
                           FROM dbo.PickDetail WITH (NOLOCK)  
                           WHERE PickDetailKey = @cPickDetailKey  
                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @nErrNo = 170205  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                              GOTO RollBackTran  
                           END  
  
                           -- Split RefKeyLookup  
                           IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
                           BEGIN  
                              -- Insert into  
                              INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)  
                              SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
                              FROM RefKeyLookup WITH (NOLOCK)  
                              WHERE PickDetailKey = @cPickDetailKey  
                              IF @@ERROR <> 0  
                              BEGIN  
                                 SET @nErrNo = 170206  
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                                 GOTO RollBackTran  
                              END  
                           END  

                          UPDATE dbo.PickDetail SET    
                              Qty = @nBalQty,
                              TaskDetailKey = @cTaskKey,    
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE(),
                              TrafficCop = NULL    
                           WHERE PickDetailKey = @cPickDetailKey    
                      
                           IF @@ERROR <> 0    
                           BEGIN    
                              SET @nErrNo = 170207    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail    
                              GOTO RollBackTran    
                           END    
                           
                           SET @nBalQty = 0 
                           INSERT INTO @tPickDetailKey(PickDetailKey) VALUES (@cPickDetailKey)
                        END
                                               
                        IF @nBalQty = 0  
                           BREAK  
                             
                          
                        FETCH NEXT FROM @curCPK INTO @cPickDetailKey, @nPDQty    
                     END    
                     CLOSE @curCPK    
                     DEALLOCATE @curCPK    
                END    
                 
                IF @cTaskType = 'ASTCPK'    
                BEGIN    
               	IF EXISTS ( SELECT 1
               	            FROM dbo.PICKDETAIL WITH (NOLOCK)    
                              WHERE Storerkey = @cStorerKey    
                              AND   WaveKey = @cTDWaveKey    
                              AND   CaseID = @cCaseID                      
                              AND   Loc = @cLoc    
                              AND   ID = @cId    
                              AND   SKU = @cSKU  
                              AND   [Status] NOT IN ( '0', '3'))
                  BEGIN    
                     SET @nErrNo = 170214    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PDTLStatusErr    
                     GOTO RollBackTran    
                  END 
                  
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT PickDetailKey, Qty    
                     FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
                     WHERE Storerkey = @cStorerKey    
                     AND   WaveKey = @cTDWaveKey    
                     AND   CaseID = @cCaseID    
                     AND   Loc = @cLoc    
                     AND   ID = @cId    
                     AND   SKU = @cSKU  
                     AND   [Status] IN ( '0', '3')    
                     --AND   Lot = @cLot
                     AND   NOT EXISTS ( SELECT 1 FROM @tPickDetailKey t WHERE t.PickDetailKey = PD.PickDetailKey)
                     ORDER BY editDate  
                     OPEN @curPD    
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty      
                     WHILE @@FETCH_STATUS = 0    
                     BEGIN    
                  	   --INSERT INTO TRACEinfo  (tracename, TIMEIN,step1,step2, step3,step4,step5, Col1, Col2, Col3, Col4)  --bttest
                        --values('bttest-pd',getdate(),@cTaskKey,@cPickDetailKey,@cLoc,@cId,@cSKU, @nPDQty, @nBalQty, @cTDWaveKey, @cCaseID)

                        IF @nPDQty <= @nBalQty 
                        BEGIN
                           UPDATE dbo.PickDetail SET    
                              TaskDetailKey = @cTaskKey,    
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE()    
                           WHERE PickDetailKey = @cPickDetailKey    
                      
                           IF @@ERROR <> 0    
                           BEGIN    
                              SET @nErrNo = 170202    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail    
                              GOTO RollBackTran    
                           END    
                           SET @nBalQty = @nBalQty - @nPDQty
                           INSERT INTO @tPickDetailKey(PickDetailKey) VALUES (@cPickDetailKey)
                        END
                        ELSE IF @nPDQty > @nBalQty                       
                        BEGIN
                           -- Get new PickDetailkey  
                           EXECUTE dbo.nspg_GetKey  
                              'PICKDETAILKEY',  
                              10 ,  
                              @cNewPickDetailKey OUTPUT,  
                              @bSuccess          OUTPUT,  
                              @nErrNo            OUTPUT,  
                              @cErrMsg           OUTPUT  
                           IF @bSuccess <> 1  
                           BEGIN  
                              SET @nErrNo = 170208  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                              GOTO RollBackTran  
                           END  
  
                           -- Create new a PickDetail to hold the balance  
                           INSERT INTO dbo.PickDetail (  
                              CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,  
                              UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                              PickDetailKey,  
                              Status,  
                              QTY,  
                              TrafficCop,  
                              OptimizeCop,
                              Channel_ID)  
                           SELECT  
                              CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
                              UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
                              CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                              EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                              @cNewPickDetailKey,  
                              Status,  
                              @nPDQty - @nBalQty, -- QTY  
                              NULL, -- TrafficCop  
                              '1',  -- OptimizeCop  
                              Channel_ID
                           FROM dbo.PickDetail WITH (NOLOCK)  
                           WHERE PickDetailKey = @cPickDetailKey  
                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @nErrNo = 170209  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                              GOTO RollBackTran  
                           END  
  
                           -- Split RefKeyLookup  
                           IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
                           BEGIN  
                              -- Insert into  
                              INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)  
                              SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
                              FROM RefKeyLookup WITH (NOLOCK)  
                              WHERE PickDetailKey = @cPickDetailKey  
                              IF @@ERROR <> 0  
                              BEGIN  
                                 SET @nErrNo = 170210  
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                                 GOTO RollBackTran  
                              END  
                           END  

                          UPDATE dbo.PickDetail SET    
                              Qty = @nBalQty,
                              TaskDetailKey = @cTaskKey,    
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE(), 
                              TrafficCop = NULL    
                           WHERE PickDetailKey = @cPickDetailKey    
                      
                           IF @@ERROR <> 0    
                           BEGIN    
                              SET @nErrNo = 170211    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail    
                              GOTO RollBackTran    
                           END    
                           
                           SET @nBalQty = 0 
                           INSERT INTO @tPickDetailKey(PickDetailKey) VALUES (@cPickDetailKey)
                        END

                        IF @nBalQty = 0  
                           BREAK  
    
                        FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty      
                     END    
                     CLOSE @curPD    
                     DEALLOCATE @curPD    
                END    
                   
               -- Update Task    
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET    
                  [Status] = '0', -- Ready    
                  EditWho = SUSER_SNAME(),     
                  EditDate = GETDATE(),    
                  Trafficcop = NULL    
               WHERE TaskDetailKey = @cTaskKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 170203    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail    
                  GOTO RollBackTran    
               END    
    
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId, @cTaskType, @nQty, @cSKU, @cTDWaveKey    
            END    
         END    

         -- Check if any taskdetailkey mismatch between taskdetail and pickdetail
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     WHERE TD.WaveKey = @cWaveKey
                     AND   TD.TaskType IN ('CPK', 'ASTCPK')
                     AND   TD.[Status] = '0'
                     AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                                        JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                                        WHERE TD.TaskDetailKey = PD.TaskDetailKey
                                        AND   PD.Status IN ('0', '3')
                                        AND   WD.WaveKey = @cWaveKey))
         BEGIN
         	IF @bDebug = 1
         	BEGIN
               SELECT * FROM dbo.TaskDetail TD WITH (NOLOCK)
                     WHERE TD.WaveKey = @cWaveKey
                     AND   TD.TaskType IN ('CPK', 'ASTCPK')
                     AND   TD.[Status] = '0'
                     AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                                        JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
                                        WHERE TD.TaskDetailKey = PD.TaskDetailKey
                                        AND   PD.Status IN ('0', '3')
                                        AND   WD.WaveKey = @cWaveKey)
   --SELECT WaveKey, taskdetailkey, *  FROM TaskDetail (NOLOCK) WHERE caseid = '0007111092' AND Sku = 'GZ5898-560'
   --SELECT wavekey, taskdetailkey, * FROM PickDetail (NOLOCK) WHERE caseid = '0007111092' AND Sku = 'GZ5898-560'
   --SELECT * FROM TraceInfo (NOLOCK) WHERE TraceName = 'bttest-pd' AND col4 = '0007111092' AND Step5 = 'GZ5898-560'

            END
            SET @nErrNo = 170215    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task Mismatch    
            GOTO RollBackTran    
         END
      END    
   END    

   COMMIT TRAN rdt_1836ExtUpd03 -- Only commit change made here    
               
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_1836ExtUpd03 -- Only rollback change made here    
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END  

GO