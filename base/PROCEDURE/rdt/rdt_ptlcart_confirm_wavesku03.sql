SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store procedure: rdt_PTLCart_Confirm_WaveSKU03                       */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Close working batch                                         */    
/*                                                                      */    
/* Date       Rev  Author      Purposes                                 */    
/* 05-09-2022 1.0  yeekung     WMS-20705 Created                        */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_PTLCart_Confirm_WaveSKU03] (    
    @nMobile    INT    
   ,@nFunc      INT    
   ,@cLangCode  NVARCHAR( 3)    
   ,@nStep      INT    
   ,@nInputKey  INT    
   ,@cFacility  NVARCHAR(5)    
   ,@cStorerKey NVARCHAR( 15)    
   ,@cType      NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote    
   ,@cDPLKey    NVARCHAR( 10)    
   ,@cCartID    NVARCHAR( 10)     
   ,@cToteID    NVARCHAR( 20) -- Required for confirm tote    
   ,@cLOC       NVARCHAR( 10)    
   ,@cSKU       NVARCHAR( 20)    
   ,@nQTY       INT    
   ,@cNewToteID NVARCHAR( 20) -- For close tote with balance    
   ,@nErrNo     INT           OUTPUT    
   ,@cErrMsg    NVARCHAR(250) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @bSuccess       INT    
   DECLARE @nTranCount     INT    
   DECLARE @nRowRef        INT    
   DECLARE @nPTLKey        INT    
   DECLARE @nQTY_PTL       INT    
   DECLARE @nQTY_PD        INT    
   DECLARE @nQTY_Bal       INT    
   DECLARE @nExpectedQTY   INT    
                               
   DECLARE @cActToteID     NVARCHAR( 20)    
   DECLARE @cPosition      NVARCHAR( 10)    
   DECLARE @cWaveKey       NVARCHAR( 10)    
   DECLARE @cPickDetailKey NVARCHAR( 10)    
   DECLARE @cshort         NVARCHAR( 20)
    
   DECLARE @cUpdatePickDetail NVARCHAR(1)    
   DECLARE @cPickDetailStatus NVARCHAR(1)    
       
   DECLARE @curPTL CURSOR    
   DECLARE @curPD  CURSOR    
    
   -- Get storer config    
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)    
   SET @cPickDetailStatus = rdt.rdtGetConfig( @nFunc, 'PickDetailStatus', @cStorerKey)    
   IF @cPickDetailStatus <> '3'     -- 3=Pick in progress    
      SET @cPickDetailStatus = '5'  -- 5=Pick confirm    
    
   SET @nQTY_Bal = @nQTY    
    
   /***********************************************************************************************    
    
                                                CONFIRM LOC     
    
   ***********************************************************************************************/    
   IF @cType = 'LOC'     
   BEGIN    
      -- Confirm entire LOC    
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PTLKey, DevicePosition, ExpectedQTY    
         FROM PTL.PTLTran WITH (NOLOCK)    
         WHERE DeviceProfileLogKey = @cDPLKey    
            AND LOC = @cLOC    
            AND SKU = @cSKU    
            AND Status <> '9'    
      OPEN @curPTL    
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         -- Get tote    
         SELECT     
            @cActToteID = ToteID,     
            @cWaveKey = WaveKey    
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)     
         WHERE CartID = @cCartID     
            AND Position = @cPosition    
             
         -- Transaction at order level    
         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN  -- Begin our own transaction    
         SAVE TRAN rdt_PTLCart_Confirm_WaveSKU03 -- For rollback or commit only our own transaction    
             
         -- Confirm PTLTran    
         UPDATE PTL.PTLTran SET    
            Status = '9',     
            QTY = ExpectedQTY,     
            DropID = @cActToteID,     
            EditWho = SUSER_SNAME(),     
            EditDate = GETDATE(),     
            TrafficCop = NULL    
         WHERE PTLKey = @nPTLKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 190901    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail    
            GOTO RollBackTran    
         END    
             
         -- Update PickDetail    
         IF @cUpdatePickDetail = '1'    
         BEGIN    
            -- Get PickDetail tally PTLTran    
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
            FROM Orders O WITH (NOLOCK)    
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
            WHERE O.UserDefine09 = @cWaveKey    
               AND PD.StorerKey = @cStorerKey    
               AND PD.SKU = @cSKU    
               AND PD.LOC = @cLOC    
               AND PD.Status < @cPickDetailStatus    
               AND PD.Status <> '4'    
               AND PD.QTY > 0    
               AND O.Status <> 'CANC'    
               AND O.SOStatus <> 'CANC'    
            IF @nQTY_PD <> @nExpectedQTY    
            BEGIN    
               SET @nErrNo = 190902    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed    
               GOTO RollBackTran    
            END    
                
            -- Loop PickDetail    
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT PickDetailKey    
               FROM Orders O WITH (NOLOCK)    
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
               WHERE O.UserDefine09 = @cWaveKey    
                  AND PD.StorerKey = @cStorerKey    
                  AND PD.SKU = @cSKU    
                  AND PD.LOC = @cLOC    
                  AND PD.Status < @cPickDetailStatus    
                  AND PD.Status <> '4'    
                  AND PD.QTY > 0    
                  AND O.Status <> 'CANC'    
                  AND O.SOStatus <> 'CANC'    
            OPEN @curPD    
            FETCH NEXT FROM @curPD INTO @cPickDetailKey    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               -- Confirm PickDetail    
               UPDATE PickDetail SET    
                  Status = @cPickDetailStatus,     
                  DropID = @cActToteID,     
                  EditWho = SUSER_SNAME(),     
                  EditDate = GETDATE()    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 190903    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                  GOTO RollBackTran    
               END    
               FETCH NEXT FROM @curPD INTO @cPickDetailKey    
            END    
         END    
             
         -- Commit order level    
         COMMIT TRAN rdt_PTLCart_Confirm_WaveSKU03    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN    
             
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY    

                  
         IF EXISTS (SELECT 1 from wave (Nolock)
                    WHERE wavekey=@cwavekey
                    AND DispatchPiecePickMethod  in(select code 
                                                    From codelkup (nolock)
                                                    where listname='ANFAGVDTP'
                                                    and storerkey=@cstorerkey)
                     AND userdefine08<>'Y')
         BEGIN
            select @cshort=short 
            From codelkup (nolock)
            where listname='ANFAGVDTP'
            and storerkey=@cstorerkey
            
             -- Insert transmitlog2 here (trigger S272)  
            SET @bSuccess = 1  
            EXEC ispGenTransmitLog2   
                @c_TableName        = @cshort  
               ,@c_Key1             = @cwavekey  
               ,@c_Key2             = ''  
               ,@c_Key3             = @cStorerkey  
               ,@c_TransmitBatch    = ''  
               ,@b_Success          = @bSuccess    OUTPUT  
               ,@n_err              = @nErrNo      OUTPUT  
               ,@c_errmsg           = @cErrMsg     OUTPUT      
         END
      END    
   END    
    
    
   /***********************************************************************************************    
    
                                                CONFIRM TOTE     
    
   ***********************************************************************************************/    
   -- Confirm tote    
   IF @cType <> 'LOC'    
   BEGIN    
      -- Handling transaction    
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_PTLCart_Confirm_WaveSKU03 -- For rollback or commit only our own transaction    
          
      -- Close with QTY or short     
      IF (@cType = 'CLOSETOTE' AND @nQTY > 0) OR    
         (@cType = 'SHORTTOTE')    
      BEGIN    
         -- Get tote info    
         SELECT     
            @cPosition = Position,     
            @cWaveKey = WaveKey    
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)     
         WHERE CartID = @cCartID     
            AND ToteID = @cToteID    
    
         SET @nExpectedQTY = NULL    
    
         -- PTLTran    
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PTLKey, ExpectedQTY    
            FROM PTL.PTLTran WITH (NOLOCK)    
            WHERE DeviceProfileLogKey = @cDPLKey    
               AND LOC = @cLOC    
               AND SKU = @cSKU    
               AND DevicePosition = @cPosition    
               AND Status <> '9'        
         OPEN @curPTL    
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            IF @nExpectedQTY IS NULL    
               SET @nExpectedQTY = @nQTY_PTL    
                
            -- Exact match    
            IF @nQTY_PTL = @nQTY_Bal    
            BEGIN    
               -- Confirm PTLTran    
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET     
                  Status = '9',     
                  QTY = ExpectedQTY,     
                  DropID = @cToteID,     
                  EditWho = SUSER_SNAME(),     
                  EditDate = GETDATE(),     
                  TrafficCop = NULL    
               WHERE PTLKey = @nPTLKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 190904    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail    
                  GOTO RollBackTran    
               END    
          
               SET @nQTY_Bal = 0 -- Reduce balance    
            END    
                
            -- PTLTran have less    
            ELSE IF @nQTY_PTL < @nQTY_Bal    
            BEGIN    
               -- Confirm PickDetail    
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET     
                  Status = '9',    
                  QTY = ExpectedQTY,     
                  DropID = @cToteID,     
                  EditDate = GETDATE(),     
                  EditWho  = SUSER_SNAME(),     
                  TrafficCop = NULL    
               WHERE PTLKey = @nPTLKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 190905    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                  GOTO RollBackTran    
               END    
          
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance    
            END    
                
            -- PTLTran have more    
            ELSE IF @nQTY_PTL > @nQTY_Bal    
            BEGIN    
               -- Short pick    
               IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split    
               BEGIN    
                  -- Confirm PTLTran    
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET     
                     Status = '9',    
                     QTY = 0,     
                     DropID = @cToteID,     
                     TrafficCop = NULL,     
                     EditDate = GETDATE(),     
                     EditWho  = SUSER_SNAME()     
                  WHERE PTLKey = @nPTLKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 190906    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                     GOTO RollBackTran    
                  END    
               END    
               ELSE    
               BEGIN -- Have balance, need to split    
                  -- Create new a PTLTran to hold the balance    
                  INSERT INTO PTL.PTLTran (    
                     ExpectedQty, QTY, TrafficCop,     
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, DropID, OrderKey, Storerkey, SKU, LOC, LOT, Remarks,     
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey)    
                  SELECT     
                     @nQTY_PTL - @nQTY_Bal, @nQTY_PTL - @nQTY_Bal, NULL,     
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, '', OrderKey, Storerkey, SKU, LOC, LOT, Remarks,     
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey    
                  FROM PTL.PTLTran WITH (NOLOCK)     
                  WHERE PTLKey = @nPTLKey                   
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 190907    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail    
                     GOTO RollBackTran    
                  END    
             
                  -- Confirm orginal PTLTran with exact QTY    
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET     
                     Status = '9',    
                     ExpectedQty = @nQTY_Bal,     
                     QTY = @nQTY_Bal,     
                     DropID = @cToteID,     
                     EditDate = GETDATE(),     
                     EditWho  = SUSER_SNAME(),     
                     Trafficcop = NULL    
                  WHERE PTLKey = @nPTLKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 190908    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                     GOTO RollBackTran    
                  END    
             
                  SET @nQTY_Bal = 0 -- Reduce balance    
               END    
            END    
                
            -- Exit condition    
            IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0    
               BREAK    
                
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL    
         END    
                   
         -- PickDetail    
         IF @cUpdatePickDetail = '1'    
         BEGIN                
            -- Get PickDetail tally PTLTran    
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
            FROM Orders O WITH (NOLOCK)    
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
            WHERE O.UserDefine09 = @cWaveKey    
               AND PD.StorerKey = @cStorerKey    
               AND PD.SKU = @cSKU    
               AND PD.LOC = @cLOC    
               AND PD.Status < @cPickDetailStatus    
               AND PD.Status <> '4'    
               AND PD.QTY > 0    
               AND O.Status <> 'CANC'    
               AND O.SOStatus <> 'CANC'    
    
            IF @nQTY_PD <> @nExpectedQTY    
            BEGIN    
               SET @nErrNo = 190909    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed    
               GOTO RollBackTran    
            END    
                
            -- For calculation    
            SET @nQTY_Bal = @nQTY    
             
            -- Get PickDetail candidate    
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
               SELECT PickDetailKey, QTY    
               FROM Orders O WITH (NOLOCK)    
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
               WHERE O.UserDefine09 = @cWaveKey    
                  AND PD.StorerKey = @cStorerKey    
                  AND PD.SKU = @cSKU    
                  AND PD.LOC = @cLOC    
                  AND PD.Status < @cPickDetailStatus    
                  AND PD.Status <> '4'    
                  AND PD.QTY > 0    
                  AND O.Status <> 'CANC'    
                  AND O.SOStatus <> 'CANC'    
            OPEN @curPD    
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD     
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               -- Exact match    
               IF @nQTY_PD = @nQTY_Bal    
               BEGIN    
                  -- Confirm PickDetail    
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
                     Status = @cPickDetailStatus,    
                     DropID = @cToteID,     
                     EditDate = GETDATE(),     
                     EditWho  = SUSER_SNAME()     
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 190910    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                     GOTO RollBackTran    
                  END    
             
                  SET @nQTY_Bal = 0 -- Reduce balance    
               END    
                   
               -- PickDetail have less    
               ELSE IF @nQTY_PD < @nQTY_Bal    
               BEGIN    
                  -- Confirm PickDetail    
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
                     Status = @cPickDetailStatus,    
                     DropID = @cToteID,     
                     EditDate = GETDATE(),     
                     EditWho  = SUSER_SNAME()     
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 190911    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                     GOTO RollBackTran    
                  END    
             
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance    
               END    
                   
               -- PickDetail have more    
               ELSE IF @nQTY_PD > @nQTY_Bal    
               BEGIN    
                  -- Short pick    
                  IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split    
                  BEGIN    
                     -- Confirm PickDetail    
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
                        Status = '4',    
                        DropID = @cToteID,     
                        EditDate = GETDATE(),     
                        EditWho  = SUSER_SNAME(),    
                        TrafficCop = NULL    
                     WHERE PickDetailKey = @cPickDetailKey    
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @nErrNo = 190912    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                        GOTO RollBackTran    
                     END    
                  END    
                  ELSE    
                  BEGIN -- Have balance, need to split    
             
                     -- Get new PickDetailkey    
                     DECLARE @cNewPickDetailKey NVARCHAR( 10)    
                     EXECUTE dbo.nspg_GetKey    
                        'PICKDETAILKEY',     
                        10 ,    
                        @cNewPickDetailKey OUTPUT,    
                        @bSuccess          OUTPUT,    
                        @nErrNo            OUTPUT,    
                        @cErrMsg           OUTPUT    
                     IF @bSuccess <> 1    
                     BEGIN    
                        SET @nErrNo = 190913    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKeyFail   
                        GOTO RollBackTran    
                     END    
                
                     -- Create new a PickDetail to hold the balance    
                     INSERT INTO dbo.PickDetail (    
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,     
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,     
                    ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,     
                        PickDetailKey,     
                        QTY,     
                        Status,     
                        TrafficCop,    
                        OptimizeCop,   
                        Channel_ID)   --KY01  
                     SELECT     
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,     
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,     
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,     
                        @cNewPickDetailKey,     
                        @nQTY_PD - @nQTY_Bal, -- QTY    
                        CASE WHEN @cType = 'SHORTTOTE' THEN '4' ELSE Status END,     
                        NULL, -- TrafficCop    
                        '1'   -- OptimizeCop   
                        , Channel_ID            --KY01  
                     FROM dbo.PickDetail WITH (NOLOCK)     
                     WHERE PickDetailKey = @cPickDetailKey                   
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @nErrNo = 190914    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail    
                        GOTO RollBackTran    
                     END    
                
                     -- Split RefKeyLookup    
                     IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)    
                     BEGIN    
                        -- Insert into     
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)    
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey    
                        FROM RefKeyLookup WITH (NOLOCK)     
                        WHERE PickDetailKey = @cPickDetailKey    
                        IF @@ERROR <> 0    
                        BEGIN    
                           SET @nErrNo = 190915    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail    
                           GOTO RollBackTran    
                        END    
                     END    
                         
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)    
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
                        QTY = @nQTY_Bal,     
                        DropID = @cToteID,     
                        EditDate = GETDATE(),     
                        EditWho  = SUSER_SNAME(),     
                        Trafficcop = NULL    
                     WHERE PickDetailKey = @cPickDetailKey     
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @nErrNo = 190916    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                        GOTO RollBackTran    
                     END    
                
                     -- Confirm orginal PickDetail with exact QTY    
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
                        Status = @cPickDetailStatus,    
                        EditDate = GETDATE(),     
                        EditWho  = SUSER_SNAME()     
                     WHERE PickDetailKey = @cPickDetailKey    
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @nErrNo = 190917    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                       GOTO RollBackTran    
                     END    
                
                     SET @nQTY_Bal = 0 -- Reduce balance    
                  END    
               END    
             
               -- Exit condition    
               IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0    
                  BREAK    
             
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD     
            END     
         END    
      END    
          
      -- Update new tote    
      IF @cType = 'CLOSETOTE' AND @cNewToteID <> ''    
      BEGIN    
         -- Get RowRef    
         SELECT @nRowRef = RowRef,@cwavekey=wavekey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID    
             
         -- Change Tote on rdtPTLCartLog    
         UPDATE rdt.rdtPTLCartLog SET    
            ToteID = @cNewToteID    
         WHERE RowRef = @nRowRef     
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 190918    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail    
            GOTO RollBackTran    
         END   
         
         IF EXISTS (SELECT 1 from wave (Nolock)
                    WHERE wavekey=@cwavekey
                    AND DispatchPiecePickMethod  in(select code 
                                                    From codelkup (nolock)
                                                    where listname='ANFAGVDTP'
                                                    and storerkey=@cstorerkey)
                     AND userdefine08<>'Y')
         BEGIN
            SELECT @cshort=short 
            From codelkup (nolock)
            where listname='ANFAGVDTP'
            and storerkey=@cstorerkey
            
             -- Insert transmitlog2 here (trigger S272)  
            SET @bSuccess = 1  
            EXEC ispGenTransmitLog2   
                @c_TableName        = @cshort  
               ,@c_Key1             = @cwavekey  
               ,@c_Key2             = ''  
               ,@c_Key3             = @cStorerkey  
               ,@c_TransmitBatch    = ''  
               ,@b_Success          = @bSuccess    OUTPUT  
               ,@n_err              = @nErrNo      OUTPUT  
               ,@c_errmsg           = @cErrMsg     OUTPUT      
         END
      END    
          
      -- Auto short all subsequence tote    
      IF @cType = 'SHORTTOTE'    
      BEGIN    
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'    
        BEGIN    
            SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT PTLKey, DevicePosition, ExpectedQTY    
               FROM PTL.PTLTran WITH (NOLOCK)    
               WHERE DeviceProfileLogKey = @cDPLKey    
                  AND LOC = @cLOC    
                  AND SKU = @cSKU    
                  AND Status <> '9'    
          
            OPEN @curPTL    
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               -- Get tote    
               SELECT     
                  @cActToteID = ToteID,     
                  @cWaveKey = WaveKey    
               FROM rdt.rdtPTLCartLog WITH (NOLOCK)     
               WHERE CartID = @cCartID     
                  AND Position = @cPosition    
                   
               -- Confirm PTLTran    
               UPDATE PTL.PTLTran SET    
                  Status = '9',     
                  QTY = 0,     
                  DropID = @cActToteID,     
                  EditWho = SUSER_SNAME(),     
                  EditDate = GETDATE(),     
                  TrafficCop = NULL    
               WHERE PTLKey = @nPTLKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 190919    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail    
                  GOTO RollBackTran    
               END    
                   
               -- Update PickDetail    
               IF @cUpdatePickDetail = '1'    
               BEGIN    
                  -- Get PickDetail tally PTLTran    
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
                  FROM Orders O WITH (NOLOCK)    
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
                  WHERE O.UserDefine09 = @cWaveKey    
                     AND PD.StorerKey = @cStorerKey    
                     AND PD.SKU = @cSKU    
                     AND PD.LOC = @cLOC    
                     AND PD.Status < @cPickDetailStatus    
                     AND PD.Status <> '4'    
                     AND PD.QTY > 0    
                     AND O.Status <> 'CANC'    
                     AND O.SOStatus <> 'CANC'    
                  IF @nQTY_PD <> @nExpectedQTY    
                  BEGIN    
                     SET @nErrNo = 190920    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed    
                     GOTO RollBackTran    
                  END    
                      
                  -- Loop PickDetail    
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT PickDetailKey    
                     FROM Orders O WITH (NOLOCK)    
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
                     WHERE O.UserDefine09 = @cWaveKey    
                        AND PD.StorerKey = @cStorerKey    
                        AND PD.SKU = @cSKU    
                        AND PD.LOC = @cLOC    
                        AND PD.Status < @cPickDetailStatus    
                        AND PD.Status <> '4'    
                        AND PD.QTY > 0    
                        AND O.Status <> 'CANC'    
                        AND O.SOStatus <> 'CANC'    
                  OPEN @curPD    
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey    
                  WHILE @@FETCH_STATUS = 0    
                  BEGIN    
                     -- Confirm PickDetail    
                     UPDATE PickDetail SET    
                        Status = '4',     
                        DropID = @cActToteID,     
                        EditWho = SUSER_SNAME(),     
                        EditDate = GETDATE()    
                     WHERE PickDetailKey = @cPickDetailKey    
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @nErrNo = 190921    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                        GOTO RollBackTran    
                     END    
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey    
                  END    
               END    
                   
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY    
            END    
         END    
      END    
    
      COMMIT TRAN rdt_PTLCart_Confirm_WaveSKU03    
   END    
   GOTO Quit    
       
RollBackTran:    
   ROLLBACK TRAN rdt_PTLCart_Confirm_WaveSKU03 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO