SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_801PFL_Confirm02                                */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 05-11-2020 1.0  YeeKung  WMS-15125 Created                           */    
/************************************************************************/    
    
CREATE PROC [PTL].[isp_801PFL_Confirm02] (    
   @cIPAddress    NVARCHAR(30),     
   @cPosition     NVARCHAR(20),    
   @cFuncKey      NVARCHAR(2),     
   @nSerialNo     INT,    
   @cInputValue   NVARCHAR(20),    
   @nErrNo        INT           OUTPUT,      
   @cErrMsg       NVARCHAR(125) OUTPUT,      
   @cDebug        NVARCHAR( 1) = ''    
)    
AS    
BEGIN TRY    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount     INT    
   DECLARE @bSuccess       INT    
   DECLARE @nSPErrNo       INT     
   DECLARE @cSPErrMSG      NVARCHAR(125)     
   DECLARE @cDisplayValue  NVARCHAR( 5)    
       
   DECLARE @cLangCode      NVARCHAR( 3)    
   DECLARE @cUserName      NVARCHAR( 18)    
   DECLARE @nFunc          INT    
   DECLARE @cStation       NVARCHAR( 10)    
   DECLARE @cWaveKey       NVARCHAR( 10)    
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cStorerKey     NVARCHAR( 15)    
   DECLARE @cSKU           NVARCHAR( 20)    
   DECLARE @cLOC           NVARCHAR( 10)    
   DECLARE @cDropID        NVARCHAR(20)    
    
   DECLARE @cType          NVARCHAR( 10)    
   DECLARE @nExpectedQTY   INT    
   DECLARE @nQTY           INT    
   DECLARE @nQTY_PTL       INT    
   DECLARE @nQTY_PD        INT    
   DECLARE @nQTY_Bal       INT    
   DECLARE @nPTLKey        INT    
   DECLARE @cPickDetailKey NVARCHAR( 10)    
    
   DECLARE @cLightMode         NVARCHAR( 4)    
   DECLARE @cUpdatePickDetail  NVARCHAR( 1)    
   DECLARE @cPickConfirmStatus NVARCHAR( 1)    
    
   DECLARE @curPTL CURSOR    
   DECLARE @curPD  CURSOR    
    
   SET @nFunc = 801 -- PFL station (rdt.rdtfnc_PFLStation)    
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))    
             
   -- Get light info    
   SELECT     
      @cStation = DeviceID,     
      @cDisplayValue = LEFT( expectedqty, 5),     
      @cStorerKey = StorerKey    
   FROM PTL.ptltran WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress    
      AND DevicePosition = @cPosition  
      and status='1'  
       
   ---- Check over put    
   --IF CAST( @cInputValue AS INT) > CAST( @cDisplayValue AS INT)    
   --BEGIN    
   --   if @cDebug = '1'    
   --      SELECT @cInputValue '@cInputValue', @cDisplayValue '@cDisplayValue'    
   --   RAISERROR ('', 16, 1) WITH SETERROR -- Raise error to go to catch block    
   --END   
   
    
   -- Get storer config    
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)    
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)    
       
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus NOT IN ('3', '5')    
      SET @cPickConfirmStatus = '5'    
    
   -- Get station info    
   SELECT       
      @cLoadKey = loadkey,     
      @cDropID = DropID,
      @cOrderkey  = orderkey  
   FROM rdt.rdtPFLStationLog WITH (NOLOCK)    
   WHERE Station = @cStation    

   -- Get PTLTran info    
   SELECT TOP 1    
      @cLOC = LOC,     
      @cSKU = SKU,     
      @cUserName = EditWho    
   FROM PTL.PTLTran WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress    
      AND DevicePosition = @cPosition    
      AND Func = 801    
      AND Status = '1' -- Lighted up    
    
   -- Calc QTY    
   IF @cInputValue = ''    
      SET @nQTY = 0    
   ELSE    
      SET @nQTY = CAST( @cInputValue AS INT)    
    
   -- Determine action    
   IF @nQTY = 0    
      SET @cType = 'SHORTTOTE'    
   ELSE    
      SET @cType = 'CLOSETOTE'    
    
   if @cDebug = '1'     
      select @cIPAddress '@cIPAddress', @cPosition '@cPosition', @cStation '@cStation',     
      @cStorerKey '@cStorerKey', @cOrderKey '@cOrderKey', @cDropID '@cDropID', @cSKU '@cSKU',     
      @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName'    
    
   -- Get inner    
   DECLARE @nInnerPack INT    
   SELECT @nInnerPack = Pack.InnerPack    
   FROM SKU WITH (NOLOCK)    
   JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
   WHERE SKU.StorerKey = @cStorerKey    
      AND SKU.SKU = @cSKU    
          
   -- Convert to inner    
   IF @nInnerPack > 0    
      SET @nQTY = @nQTY * @nInnerPack    
    
   -- For calc balance    
   SET @nQTY_Bal = @nQTY    
    
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN isp_801PFL_Confirm02 -- For rollback or commit only our own transaction    
    
   -- PTLTran    
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PTLKey, ExpectedQTY    
      FROM PTL.PTLTran WITH (NOLOCK)    
      WHERE IPAddress = @cIPAddress    
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
            LightUp = '0',     
            QTY = ExpectedQTY,    
            DropID = @cDropID,    
            EditWho = SUSER_SNAME(),    
            EditDate = GETDATE(),    
            TrafficCop = NULL    
         WHERE PTLKey = @nPTLKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 160751    
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
            LightUp = '0',     
            QTY = ExpectedQTY,    
            DropID = @cDropID,    
            EditDate = GETDATE(),    
            EditWho  = SUSER_SNAME(),    
            TrafficCop = NULL    
         WHERE PTLKey = @nPTLKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 160752    
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
               LightUp = '0',     
               QTY = 0,    
               DropID = @cDropID,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               TrafficCop = NULL    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 160753    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail    
               GOTO RollBackTran    
            END    
         END    
         ELSE    
         BEGIN -- Have balance, need to split    
            -- Create new a PTLTran to hold the balance    
            INSERT INTO PTL.PTLTran (    
               ExpectedQty, QTY, TrafficCop,     
               IPAddress, DeviceID, DevicePosition, Status, LightUp, LightMode, LightSequence, PTLType, SourceKey, DropID, CaseID, RefPTLKey,     
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, SourceType, ArchiveCop)    
            SELECT     
               @nQTY_PTL - @nQTY_Bal, 0, NULL,     
               IPAddress, DeviceID, DevicePosition, Status, LightUp, LightMode, LightSequence, PTLType, SourceKey, DropID, CaseID, RefPTLKey,     
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_801PFL_Confirm02', ArchiveCop    
            FROM PTL.PTLTran WITH (NOLOCK)    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 160754    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail    
               GOTO RollBackTran    
            END    
    
            -- Confirm orginal PTLTran with exact QTY    
            UPDATE PTL.PTLTran WITH (ROWLOCK) SET    
               Status = '9',    
               LightUp = '0',     
               ExpectedQty = @nQTY_Bal,    
               QTY = @nQTY_Bal,    
               DropID = @cDropID,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               Trafficcop = NULL    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 160755    
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
      IF  ISNULL(@cdropid,'')<>''
      BEGIN
         -- Get PickDetail tally PTLTran    
         SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
         FROM Orders O WITH (NOLOCK)    
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
         WHERE PD.caseid=@cdropid    
            AND PD.LOC = @cLOC    
            AND PD.StorerKey = @cStorerKey     
            AND PD.SKU = @cSKU    
            AND PD.Status < @cPickConfirmStatus    
            AND PD.Status <> '4'    
            AND PD.QTY > 0    
            AND O.Status <> 'CANC'    
            AND O.SOStatus <> 'CANC'    
      END
 
      ELSE IF  ISNULL(@cloadkey,'')<>''
      BEGIN
         -- Get PickDetail tally PTLTran    
         SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
         FROM Orders O WITH (NOLOCK)    
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
         WHERE O.loadkey=@cloadkey
            AND PD.LOC = @cLOC    
            AND PD.StorerKey = @cStorerKey     
            AND PD.SKU = @cSKU    
            AND PD.Status < @cPickConfirmStatus    
            AND PD.Status <> '4'    
            AND PD.QTY > 0    
            AND O.Status <> 'CANC'    
            AND O.SOStatus <> 'CANC'    
      END

      ELSE IF  ISNULL(@cOrderkey,'')<>''
      BEGIN
         -- Get PickDetail tally PTLTran    
         SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
         FROM Orders O WITH (NOLOCK)    
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
         WHERE O.orderkey=@cOrderkey
            AND PD.LOC = @cLOC    
            AND PD.StorerKey = @cStorerKey     
            AND PD.SKU = @cSKU    
            AND PD.Status < @cPickConfirmStatus    
            AND PD.Status <> '4'    
            AND PD.QTY > 0    
            AND O.Status <> 'CANC'    
            AND O.SOStatus <> 'CANC'    
      END
          
      IF @nQTY_PD <> @nExpectedQTY    
      BEGIN    
         SET @nErrNo = 160756   
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
         WHERE O.OrderKey = case when ISNULL(@cOrderKey,'') <>'' THEN @cOrderKey ELSE O.orderkey END   
            AND PD.LOC = @cLOC    
            AND PD.caseid = case when ISNULL(@cdropid,'') <>'' THEN @cdropid ELSE PD.caseid END
            AND O.loadkey = case when ISNULL(@cloadkey,'') <>'' THEN @cloadkey ELSE O.loadkey END
            AND PD.StorerKey = @cStorerKey     
            AND PD.SKU = @cSKU    
            AND PD.Status < @cPickConfirmStatus    
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
               Status = @cPickConfirmStatus,    
               DropID = case when ISNULL(@cdropid,'') <>'' THEN @cDropID ELSE '' END,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 160757    
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
               Status = @cPickConfirmStatus,    
               DropID = case when ISNULL(@cdropid,'') <>'' THEN @cDropID ELSE '' END, 
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
               --TrafficCop = NULL --INC0831212    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 160758    
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
                  --DropID = @cDropID,    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME()    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 160759    
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
                  SET @nErrNo = 160760    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey    
                  GOTO RollBackTran    
               END    
    
               -- Create new a PickDetail to hold the balance    
               INSERT INTO dbo.PickDetail (    
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,    
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,    
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
                  PickDetailKey,    
                  QTY,    
                  TrafficCop,    
                  OptimizeCop,
                  channel_id)    
               SELECT    
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
                  @cNewPickDetailKey,    
                  @nQTY_PD - @nQTY_Bal, -- QTY    
                  NULL, -- TrafficCop    
                  '1' ,
                  channel_id  -- OptimizeCop    
               FROM dbo.PickDetail WITH (NOLOCK)    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 160761    
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
                     SET @nErrNo = 160762    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail    
                     GOTO RollBackTran    
                  END    
               END    
    
               -- Change orginal PickDetail with exact QTY (with TrafficCop)    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  QTY = @nQTY_Bal,    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME(),    
                  Trafficcop = NULL    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 160763   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                  GOTO RollBackTran    
               END    
    
               -- Confirm orginal PickDetail with exact QTY    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  Status = @cPickConfirmStatus,    
                  DropID = @cDropID,    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME()    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 160764    
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
    
   -- Get remain task    
   SET @nPTLKey = ''    
   SET @nExpectedQTY = 0    
   SELECT TOP 1    
      @nPTLKey = PTLKey,    
      @nExpectedQTY = ExpectedQTY    
   FROM PTL.PTLTran WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress    
      AND DevicePosition = @cPosition    
      AND Status <> '9'    
    
   -- Re-light up    
   IF @nExpectedQTY > 0    
   BEGIN    
    
      DECLARE @cQTY NVARCHAR(10)    
      SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(10))    
      IF LEN( @cQTY) > 4    
         SET @cQTY = '*'    
      ELSE    
         SET @cQTY = LEFT( @cQTY, 4)    
          
      EXEC PTL.isp_PTL_LightUpLoc    
         @n_Func           = @nFunc    
        ,@n_PTLKey         = @nPTLKey    
        ,@c_DisplayValue   = @cQTY     
        ,@b_Success        = @bSuccess    OUTPUT        
        ,@n_Err            = @nErrNo      OUTPUT      
        ,@c_ErrMsg         = @cErrMsg     OUTPUT    
        ,@c_DeviceID       = @cStation    
        ,@c_DevicePos      = @cPosition    
        ,@c_DeviceIP       = @cIPAddress      
        ,@c_LModMode       = @cLightMode    
      IF @nErrNo <> 0    
         GOTO RollBackTran    
   END    
       
   /* Pick face don't need to show "END"    
   ELSE    
   BEGIN    
      -- RelightUp     
      EXEC PTL.isp_PTL_LightUpLoc    
         @n_Func           = @nFunc    
        ,@n_PTLKey         = 0    
        ,@c_DisplayValue   = 'EnD'    
        ,@b_Success        = @bSuccess    OUTPUT        
        ,@n_Err            = @nErrNo      OUTPUT      
        ,@c_ErrMsg         = @cErrMsg     OUTPUT    
        ,@c_DeviceID       = @cStation    
        ,@c_DevicePos      = @cPosition    
        ,@c_DeviceIP       = @cIPAddress      
        ,@c_LModMode       = '19'    
   END    
   */    
    
   COMMIT TRAN isp_801PFL_Confirm02    
   GOTO Quit    
    
   RollBackTran:    
   ROLLBACK TRAN isp_801PFL_Confirm02 -- Only rollback change made here    
       
   -- Raise error to go to catch block    
   RAISERROR ('', 16, 1) WITH SETERROR    
    
END TRY    
BEGIN CATCH    
       
   SET @nSPErrNo = @nErrNo     
   SET @cSPErrMSG = @cErrMsg    
    
   -- RelightUp     
   EXEC PTL.isp_PTL_LightUpLoc    
      @n_Func           = @nFunc    
     ,@n_PTLKey         = 0    
     ,@c_DisplayValue   = @cDisplayValue    
     ,@b_Success        = @bSuccess    OUTPUT        
     ,@n_Err = @nErrNo      OUTPUT      
     ,@c_ErrMsg         = @cErrMsg     OUTPUT    
     ,@c_DeviceID       = @cStation    
     ,@c_DevicePos      = @cPosition    
     ,@c_DeviceIP       = @cIPAddress      
     ,@c_LModMode       = '99'    
    
   IF ISNULL(@nSPErrNo , 0 ) <> '0'  AND ISNULL(@nErrNo , 0 ) = '0'    
   BEGIN    
      SET @nErrNo = @nSPErrNo    
      SET @cErrMsg = @cSPErrMSG    
   END    
    
END CATCH    
    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN


GO