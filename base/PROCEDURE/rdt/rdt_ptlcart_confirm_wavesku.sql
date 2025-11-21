SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store procedure: rdt_PTLCart_Confirm_WaveSKU                         */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Close working batch                                         */    
/*                                                                      */    
/* Date       Rev  Author      Purposes                                 */    
/* 25-05-2015 1.0  Ung         SOS336312 Created                        */    
/* 31-07-2015 1.1  Ung         SOS348740 Add PickDetailStatus           */    
/* 24-09-2018 1.2  James       Remove orderdetail.loadkey (james01)     */    
/* 26-01-2018 1.3  Ung         Change to PTL.Schema                     */ 
/* 14-08-2018 1.4  James       WMS5770-Add eventlog (james01)           */
/* 01-09-2022 1.5  KuanYee     INC1896195 Add Channel_ID (KY01)         */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_PTLCart_Confirm_WaveSKU] (    
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
   DECLARE @cUserName      NVARCHAR( 18)  
    
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

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
    
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
         SAVE TRAN rdt_PTLCart_Confirm_WaveSKU -- For rollback or commit only our own transaction    
             
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
            SET @nErrNo = 54851    
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
               SET @nErrNo = 54852    
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
                  SET @nErrNo = 54853    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                  GOTO RollBackTran    
               END    
               FETCH NEXT FROM @curPD INTO @cPickDetailKey    
            END    
         END    
             
         -- Commit order level    
         COMMIT TRAN rdt_PTLCart_Confirm_WaveSKU    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN    
             
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY    
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
      SAVE TRAN rdt_PTLCart_Confirm_WaveSKU -- For rollback or commit only our own transaction    
          
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
                  SET @nErrNo = 54854    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail    
                  GOTO RollBackTran    
               END   
               ELSE  
               BEGIN  
                  -- Event log  
                  EXEC RDT.rdt_STD_EventLog  
                     @cActionType   = '3', -- Picking  
                     @cUserID       = @cUserName,  
                     @nMobileNo     = @nMobile,  
                     @nFunctionID   = @nFunc,  
                     @cFacility     = @cFacility,  
                     @cStorerKey    = @cStorerkey,  
                     @cWaveKey      = @cWaveKey,  
                     @cSKU          = @cSKU,  
                     @cLocation     = @cLOC,  
                     @nQTY          = @nExpectedQTY,  
                     @cDropID       = @cToteID,  
                     @cRefNo1       = @cType,  
                     @cRefNo2       = @cDPLKey,  
                     @cRefNo3       = @nPTLKey,  
                     @cRefNo4       = @cPosition,  
                     @cRefNo5       = @cCartID  
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
                  SET @nErrNo = 54855    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                  GOTO RollBackTran    
               END 
               ELSE  
               BEGIN  
                  -- Event log  
                  EXEC RDT.rdt_STD_EventLog  
                     @cActionType   = '3', -- Picking  
                     @cUserID       = @cUserName,  
                     @nMobileNo     = @nMobile,  
                     @nFunctionID   = @nFunc,  
                     @cFacility     = @cFacility,  
                     @cStorerKey    = @cStorerkey,  
                     @cWaveKey      = @cWaveKey,  
                     @cSKU          = @cSKU,  
                     @cLocation     = @cLOC,  
                     @nQTY          = @nExpectedQTY,  
                     @cDropID       = @cToteID,  
                     @cRefNo1       = @cType,  
                     @cRefNo2       = @cDPLKey,  
                     @cRefNo3       = @nPTLKey,  
                     @cRefNo4       = @cPosition,  
                     @cRefNo5       = @cCartID  
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
                     SET @nErrNo = 54856    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                     GOTO RollBackTran    
                  END    
                  ELSE  
                  BEGIN  
                     -- Event log  
                     EXEC RDT.rdt_STD_EventLog  
                        @cActionType   = '3', -- Picking  
                        @cUserID       = @cUserName,  
                        @nMobileNo     = @nMobile,  
                        @nFunctionID   = @nFunc,  
                        @cFacility     = @cFacility,  
                        @cStorerKey    = @cStorerkey,  
                        @cWaveKey      = @cWaveKey,  
                        @cSKU          = @cSKU,  
                        @cLocation     = @cLOC,  
                        @nQTY          = @nExpectedQTY,  
                        @cDropID       = @cToteID,  
                        @cRefNo1       = @cType,  
                        @cRefNo2       = @cDPLKey,  
                        @cRefNo3       = @nPTLKey,  
                        @cRefNo4       = @cPosition,  
                        @cRefNo5       = @cCartID  
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
                     SET @nErrNo = 54857    
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
                     SET @nErrNo = 54858    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
                     GOTO RollBackTran    
                  END
                  ELSE  
                  BEGIN  
                     -- Event log  
                     EXEC RDT.rdt_STD_EventLog  
                        @cActionType   = '3', -- Picking  
                        @cUserID       = @cUserName,  
                        @nMobileNo     = @nMobile,  
                        @nFunctionID   = @nFunc,  
                        @cFacility     = @cFacility,  
                        @cStorerKey    = @cStorerkey,  
                        @cWaveKey      = @cWaveKey,  
                        @cSKU          = @cSKU,  
                        @cLocation     = @cLOC,  
                        @nQTY          = @nExpectedQTY,  
                        @cDropID       = @cToteID,  
                        @cRefNo1       = @cType,  
                        @cRefNo2       = @cDPLKey,  
                        @cRefNo3       = @nPTLKey,  
                        @cRefNo4       = @cPosition,  
                        @cRefNo5       = @cCartID  
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
               SET @nErrNo = 54859    
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
                     SET @nErrNo = 54860    
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
                     SET @nErrNo = 54861    
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
                        SET @nErrNo = 54862    
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
                        SET @nErrNo = 54863    
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
                    SET @nErrNo = 54864    
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
                           SET @nErrNo = 54865    
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
                        SET @nErrNo = 54866    
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
                        SET @nErrNo = 54867    
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
         SELECT @nRowRef = RowRef FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID    
             
         -- Change Tote on rdtPTLCartLog    
         UPDATE rdt.rdtPTLCartLog SET    
            ToteID = @cNewToteID    
         WHERE RowRef = @nRowRef     
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 54868    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail    
            GOTO RollBackTran    
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
                  SET @nErrNo = 54869    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail    
                  GOTO RollBackTran    
               END 
               ELSE  
               BEGIN  
                  -- Event log  
                  EXEC RDT.rdt_STD_EventLog  
                     @cActionType   = '3', -- Picking  
                     @cUserID       = @cUserName,  
                     @nMobileNo     = @nMobile,  
                     @nFunctionID   = @nFunc,  
                     @cFacility     = @cFacility,  
                     @cStorerKey    = @cStorerkey,  
                     @cWaveKey      = @cWaveKey,  
                     @cSKU          = @cSKU,  
                     @cLocation     = @cLOC,  
                     @nQTY          = @nExpectedQTY,  
                     @cDropID       = @cToteID,  
                     @cRefNo1       = @cType,  
                     @cRefNo2       = @cDPLKey,  
                     @cRefNo3       = @nPTLKey,  
                     @cRefNo4       = @cPosition,  
                     @cRefNo5       = @cCartID  
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
                     SET @nErrNo = 54870    
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
                        SET @nErrNo = 54871    
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
    
      COMMIT TRAN rdt_PTLCart_Confirm_WaveSKU    
   END    
   GOTO Quit    
       
RollBackTran:    
   ROLLBACK TRAN rdt_PTLCart_Confirm_WaveSKU -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO