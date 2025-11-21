SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: isp_805PTL_Confirm09                                */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 25-09-2020 1.0  YeeKung  WMS-14910 Created                           */    
/************************************************************************/    
    
CREATE PROC [PTL].[isp_805PTL_Confirm09] (    
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
    
   DECLARE @cLangCode      NVARCHAR( 3)    
   DECLARE @cUserName      NVARCHAR( 18)    
   DECLARE @nTranCount     INT    
   DECLARE @bSuccess       INT    
   DECLARE @nFunc          INT    
   DECLARE @nQTY           INT    
   DECLARE @nPTLKey        INT    
   DECLARE @nQTY_PTL       INT    
   DECLARE @nQTY_PD        INT    
   DECLARE @nQTY_Bal       INT    
   DECLARE @nExpectedQTY   INT    
   DECLARE @nGroupKey      INT    
   DECLARE @nCartonNo      INT    
   DECLARE @cStation       NVARCHAR( 10)    
   DECLARE @cStation1      NVARCHAR( 10)    
   DECLARE @cStation2      NVARCHAR( 10)    
   DECLARE @cStation3      NVARCHAR( 10)    
   DECLARE @cStation4      NVARCHAR( 10)    
   DECLARE @cStation5      NVARCHAR( 10)    
   DECLARE @cCartonID      NVARCHAR( 20)    
   DECLARE @cSKU           NVARCHAR( 20)    
   DECLARE @cDropID        NVARCHAR( 20)    
   DECLARE @cType          NVARCHAR( 10)    
   DECLARE @cWaveKey       NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cPickSlipNo    NVARCHAR( 10)    
   DECLARE @cPickDetailKey NVARCHAR( 10)    
   DECLARE @cLightMode     NVARCHAR( 4)    
   DECLARE @cLabelLine     NVARCHAR( 5)    
   DECLARE @cCriteria1     NVARCHAR( 30)    
   DECLARE @cCriteria2     NVARCHAR( 30)    
   DECLARE @cLabelNo       NVARCHAR( 20)    
   DECLARE @nTotalExpectedQTY INT,
           @nSPErrNo       INT,     
           @cSPErrMSG      NVARCHAR(125),
           @nMobile        INT,
           @nStep          INT,
           @cFacility      NVARCHAR(20)      
    
   DECLARE @curPTL CURSOR    
   DECLARE @curPD  CURSOR    
    
   SET @nFunc = 805 -- PTL station (rdt.rdtfnc_PTLStation)    
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))    
    
   -- Get storer     
   DECLARE @cStorerKey NVARCHAR(15)    

   -- Get booking info    
   SELECT            
      @cCartonID = CartonID  ,
      @cStorerKey= StorerKey 
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress    
    AND position = @cPosition    

   -- Get storer config    
   DECLARE @cUpdatePickDetail NVARCHAR(1)    
   DECLARE @cUpdatePackDetail NVARCHAR(1)    
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)    
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)    
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)    
    
   -- Get device profile info    
   SELECT @cStation = DeviceID    
   FROM dbo.DeviceProfile WITH (NOLOCK)      
   WHERE IPAddress = @cIPAddress    
      AND DevicePosition = @cPosition    
      AND DeviceType = 'STATION'    
      AND DeviceID <> ''    
          
   -- Get PTLTran info    
   SELECT TOP 1    
      @nGroupKey = GroupKey,     
      @cOrderKey = OrderKey,     
      @cDropID = DropID,     
      @cSKU = SKU,     
      @cUserName = EditWho    
   FROM PTL.PTLTran WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress    
      AND DevicePosition = @cPosition    
      AND Func = 805    
      AND Status = '1' -- Lighted up  
    
   
   SELECT @nMobile=mobile,
          @nStep=step,
          @cFacility=facility,
          @cStorerKey = CASE WHEN ISNULL(@cStorerKey,'') <>''THEN @cStorerKey ELSE StorerKey END
   FROM rdt.rdtmobrec (NOLOCK)
   WHERE username=@cUserName 
    
   -- Calc QTY    
   IF @cInputValue = ''
   BEGIN    
      SET @nQTY = 0    
   END
   ELSE IF @cInputValue = 'EnD'  
   BEGIN    
      -- Print label  
      EXEC rdt.rdt_PTLStation_PrintLabel @nMobile, 805, @cLangCode, @nStep, '1', @cFacility, @cStorerKey, 'CLOSECARTON'  
         ,@cStation  
         ,''  
         ,''  
         ,''  
         ,''  
         ,''  
         ,@cCartonID  
         ,@nErrNo     OUTPUT  
         ,@cErrMsg    OUTPUT  
      IF @nErrNo <> 0  
      begin
         if @cDebug = '1'     
         select @cErrMsg '@cErrMsg', @cStorerKey '@cStorerKey', @cIPAddress '@nGroupKey', @cPosition '@cOrderKey', @cCartonID '@cCartonID', @cSKU '@cSKU',     
         @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName'    
         GOTO Quit  
      end
      --no error
      GOTO Quit     
   END 
   ELSE
   BEGIN
      SET @nQTY = CAST( @cInputValue AS INT)  
   END  

   -- Determine action    
   IF @nQTY = 0    
      SET @cType = 'SHORTTOTE'    
   ELSE    
      SET @cType = 'CLOSETOTE'    
    
   if @cDebug = '1'     
      select @cStorerKey '@cStorerKey', @cStation '@cStation', @nGroupKey '@nGroupKey', @cOrderKey '@cOrderKey', @cCartonID '@cCartonID', @cSKU '@cSKU',     
      @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName' ,@cIPAddress  ,@cPosition ,@cDropID
    
   -- For calc balance    
   SET @nQTY_Bal =  @nQTY    
    
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN -- Begin our own transaction    
   SAVE TRAN isp_805PTLStation_Confirm -- For rollback or commit only our own transaction    
       
   SET @nExpectedQTY = 0    
       
   -- PTLTran    
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PTLKey, ExpectedQTY    
      FROM PTL.PTLTran WITH (NOLOCK)    
      WHERE IPAddress = @cIPAddress    
         AND DevicePosition = @cPosition    
         AND GroupKey = @nGroupKey    
         AND DropID = @cDropID    
         AND SKU = @cSKU    
         AND Status <> '9'    
   OPEN @curPTL    
   FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      SET @nExpectedQTY = @nExpectedQTY + @nQTY_PTL    
    
      -- Exact match    
      IF @nQTY_PTL = @nQTY_Bal    
      BEGIN    
         -- Confirm PTLTran    
         UPDATE PTL.PTLTran WITH (ROWLOCK) SET    
            Status = '9',    
            LightUp = '0',     
            QTY = ExpectedQTY,    
            CaseID = @cCartonID,    
            -- MessageNum = @cMessageNum,    
            EditWho = SUSER_SNAME(),    
            EditDate = GETDATE(),    
            TrafficCop = NULL    
         WHERE PTLKey = @nPTLKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 159451     
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
            CaseID = @cCartonID,    
            -- MessageNum = @cMessageNum,    
            EditDate = GETDATE(),    
            EditWho  = SUSER_SNAME(),    
            TrafficCop = NULL    
         WHERE PTLKey = @nPTLKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 159452    
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
               CaseID = @cCartonID,    
               -- MessageNum = @cMessageNum,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               TrafficCop = NULL    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159453    
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
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_805PTL_Confirm09', ArchiveCop    
            FROM PTL.PTLTran WITH (NOLOCK)    
               WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159454    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail    
               GOTO RollBackTran    
            END    
    
            -- Confirm orginal PTLTran with exact QTY    
            UPDATE PTL.PTLTran WITH (ROWLOCK) SET    
               Status = '9',    
               LightUp = '0',     
               ExpectedQty = @nQTY_Bal,    
               QTY = @nQTY_Bal,    
               -- MessageNum = @cMessageNum,    
               CaseID = @cCartonID,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               Trafficcop = NULL    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159455    
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
    
   CLOSE @curPTL
   deallocate  @curPTL
   -- PackDetail    
   IF @cUpdatePackDetail = '1'    
   BEGIN    
      -- Get PickSlipNo    
      SET @cPickSlipNo = ''    

      -- Get LoadKey  
      SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

      SELECT @cPickSlipNo = pickslipno FROM dbo.packheader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
       

      -- PackHeader    
      IF ISNULL(@cPickSlipNo,'')  = ''    
      BEGIN  
      
         SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
 
         IF @cPickSlipNo = ''    
         BEGIN    
            -- Generate PickSlipNo    
            EXECUTE dbo.nspg_GetKey    
               'PICKSLIP',    
               9,    
               @cPickslipNo   OUTPUT,    
               @bSuccess      OUTPUT,    
               @nErrNo        OUTPUT,    
               @cErrMsg       OUTPUT      
            IF @nErrNo <> 0    
               GOTO RollBackTran    
       
            SET @cPickslipNo = 'P' + @cPickslipNo    
         END    
             
         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, ConsigneeKey, OrderKey)    
         VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, '', @cOrderKey)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 159456    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail    
            GOTO RollBackTran    
         END    
      END   
      
      SET @nCartonNo = 0  
      SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID   
          
      -- PackDetail    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID and sku=@csku)    
      BEGIN                    
      
         -- Get next LabelLine  
         IF @nCartonNo = 0  
            SET @cLabelLine = ''  
         ELSE  
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM dbo.PackDetail (NOLOCK)  
            WHERE Pickslipno = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID               

         -- Insert PackDetail    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine,dropid, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, RefNo)    
         VALUES    
            (@cPickSlipNo, @nCartonNo, @cCartonid, @cLabelLine,@cCartonid, @cStorerKey, @cSKU, @nQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cCartonID)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 159457    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail    
            GOTO RollBackTran    
         END         
      END    
      ELSE    
      BEGIN 
      
         -- Update Packdetail    
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET       
            QTY = QTY + @nQTY,     
            EditWho = 'rdt.' + SUSER_SNAME(),     
            EditDate = GETDATE(),     
            ArchiveCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
            AND labelno = @cCartonID 
            and sku=@csku     
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 159458    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
            GOTO RollBackTran       
         END    
      END    
   END    
    
   -- PickDetail    
   IF @cUpdatePickDetail = '1'    
   BEGIN    
      -- Get PickDetail tally PTLTran    
      SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)    
      FROM Orders O WITH (NOLOCK)  
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
        -- JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey )  
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.Orderkey=@cOrderkey  
         AND PD.DropID = @cDropID    
         AND PD.SKU = @cSKU    
         AND PD.Status <= '5'    
         AND PD.CaseID = ''    
         AND PD.QTY > 0    
         AND PD.Status <> '4'    
         AND O.Status <> 'CANC'    
         AND O.SOStatus <> 'CANC'    
    
      IF @nQTY_PD <> @nExpectedQTY    
      BEGIN    
         if @cDebug = '1' SELECT @nQTY_PD '@nQTY_PD', @nExpectedQTY '@nExpectedQTY'    
         SET @nErrNo = 159459    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed    
         GOTO RollBackTran    
      END    
    
      -- For calculation    
      SET @nQTY_Bal = @nQTY    
    
      -- Get PickDetail candidate    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.PickDetailKey, PD.QTY    
         FROM Orders O WITH (NOLOCK)  
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
           -- JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey )  
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.Orderkey=@cOrderkey  
            AND PD.DropID = @cDropID    
            AND PD.SKU = @cSKU    
            AND PD.Status <= '5'    
            AND PD.CaseID = ''    
            AND PD.QTY > 0    
            AND PD.Status <> '4'    
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
               Status = '5',    
               dropid = @cCartonID,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159460    
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
               Status = '5',    
               dropid = @cCartonID,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159461    
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
                  -- CaseID = @cCartonID,    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME()    
                  -- TrafficCop = NULL    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 159462    
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
                  SET @nErrNo = 159463    
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
                  OptimizeCop)    
               SELECT    
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
                  UOMQTY, QTYMoved, '3', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
                  @cNewPickDetailKey,    
                  @nQTY_PD - @nQTY_Bal, -- QTY    
                  NULL, -- TrafficCop    
                  '1'   -- OptimizeCop    
               FROM dbo.PickDetail WITH (NOLOCK)    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 159464    
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
                     SET @nErrNo = 159465    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail    
                     GOTO RollBackTran    
                  END    
               END    
    
               -- Change orginal PickDetail with exact QTY (with TrafficCop)    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  QTY = @nQTY_Bal,    
                  dropid = @cCartonID,    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME(),    
                  Trafficcop = NULL    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 159466    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                  GOTO RollBackTran    
               END    
    
               -- Confirm orginal PickDetail with exact QTY    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  Status = '5',    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME()    
               WHERE PickDetailKey = @cPickDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 159467    
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
    
   -- Auto short all subsequence tote    
   IF @cType = 'SHORTTOTE'    
   BEGIN    
      IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainCarton', @cStorerKey) = '1'    
      BEGIN    
         -- Get station    
         SELECT     
            @cStation1 = V_String1,     
            @cStation2 = V_String2,     
            @cStation2 = V_String3,     
            @cStation3 = V_String4,     
            @cStation5 = V_String5    
         FROM rdt.rdtMobRec WITH (NOLOCK)    
         WHERE UserName = @cUserName    
             
         SET @nExpectedQTY = 0    
             
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY    
            FROM PTL.PTLTran WITH (NOLOCK)    
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
               AND DropID = @cDropID    
               AND SKU = @cSKU    
               AND Status <> '9'    
       
         OPEN @curPTL    
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY_PTL    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            SET @nExpectedQTY = @nExpectedQTY + @nQTY_PTL    
                
            -- Get carton    
            SELECT @cCartonID = CartonID    
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)     
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
               AND IPAddress = @cIPAddress    
               AND Position = @cPosition    
    
            -- Confirm PTLTran    
            UPDATE PTL.PTLTran SET    
               Status = '9',    
               LightUp = '0',     
               QTY = 0,    
               CaseID = @cCartonID,    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE(),    
               TrafficCop = NULL    
            WHERE PTLKey = @nPTLKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 159468    
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
                  --JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey )  
               WHERE PD.StorerKey = @cStorerKey  
                  AND PD.Orderkey=@cOrderkey    
                  AND PD.DropID = @cDropID    
                  AND PD.SKU = @cSKU    
                  AND PD.Status <= '5'    
                  AND PD.CaseID = ''    
                  AND PD.QTY > 0    
                  AND PD.Status <> '4'    
                  AND O.Status <> 'CANC'    
                  AND O.SOStatus <> 'CANC'    
               IF @nQTY_PD <> @nExpectedQTY    
               BEGIN    
                  SET @nErrNo = 159469    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed    
                  GOTO RollBackTran    
               END    
    
               -- Loop PickDetail    
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT PickDetailKey    
                  FROM Orders O WITH (NOLOCK)  
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
                    -- JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey )  
                  WHERE PD.StorerKey = @cStorerKey  
                     AND PD.Orderkey=@cOrderkey  
                     AND PD.DropID = @cDropID    
                     AND PD.SKU = @cSKU    
                     AND PD.Status <= '5'    
                     AND PD.CaseID = ''    
                     AND PD.QTY > 0    
                     AND PD.Status <> '4'    
                     AND O.Status <> 'CANC'    
                     AND O.SOStatus <> 'CANC'    
               OPEN @curPD    
               FETCH NEXT FROM @curPD INTO @cPickDetailKey    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
                  -- Confirm PickDetail    
                  UPDATE PickDetail SET    
                     Status = '4',    
                     -- CaseID = @cCartonID,    
                     EditWho = SUSER_SNAME(),    
                     EditDate = GETDATE()    
                  WHERE PickDetailKey = @cPickDetailKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 159470    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail    
                     GOTO RollBackTran    
                  END    
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey    
               END    
            END    
    
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY_PTL    
         END    
    
         -- Turn all Light off in station    
         DECLARE @i INT    
         SET @i = 1    
         WHILE @i = 1    
         BEGIN    
            SET @cStation = ''    
            IF @i = 1 SET @cStation = @cStation1 ELSE    
            IF @i = 2 SET @cStation = @cStation2 ELSE    
            IF @i = 3 SET @cStation = @cStation3 ELSE    
            IF @i = 4 SET @cStation = @cStation4 ELSE    
            IF @i = 5 SET @cStation = @cStation5    
                
            IF @cStation <> ''     
            BEGIN    
               -- Off all lights    
               EXEC PTL.isp_PTL_TerminateModule    
                   @cStorerKey    
                  ,@nFunc    
                  ,@cStation    
                 ,'STATION'    
                  ,@bSuccess    OUTPUT    
                  ,@nErrNo      OUTPUT    
                  ,@cErrMsg     OUTPUT    
               IF @nErrNo <> 0    
                  GOTO RollBackTran    
            END    
            SET @i = @i + 1    
         END    
      END    
   END    
    
   -- Re-light up    
   IF @cType = 'CLOSETOTE'    
   BEGIN    
      SET @nPTLKey = ''    
      SET @nExpectedQTY = 0    
      SELECT TOP 1    
         @nPTLKey = PTLKey,    
         @nExpectedQTY = ExpectedQTY    
      FROM PTL.PTLTran WITH (NOLOCK)    
      WHERE IPAddress = @cIPAddress    
         AND DevicePosition = @cPosition    
         AND GroupKey = @nGroupKey    
         AND DropID = @cDropID    
         AND SKU = @cSKU    
         AND Status <> '9'    
             
      IF @cDebug = '1'    
         SELECT @cType '@cType', @cIPAddress '@cIPAddress', @cPosition '@cPosition', @nGroupKey '@nGroupKey', @cDropID '@cDropID', @cSKU '@cSKU', @nExpectedQTY '@nExpectedQTY'    
             
      IF @nExpectedQTY > 0    
      BEGIN    
         DECLARE @cQTY NVARCHAR(10)    
         SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(10))    
         IF LEN( @cQTY) > 5    
            SET @cQTY = '*'    
         ELSE    
            SET @cQTY = LEFT( @cQTY, 5)    
             
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
            GOTO Rollbacktran    
      END    
   END    

   declare @nTTLPickedQty int,@nTTLPackedQty INT

   SET @nTTLPickedQty=0
   SET @nTTLPackedQty=0

   -- IF Pick and Pack matched light up with END and Light Flash.    
   SELECT @nTTLPickedQty = SUM(QTY)     
   FROM dbo.PickDetail WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND OrderKey = @cOrderKey       
   AND status <>'4'
       
   SELECT @nTTLPackedQty = SUM(QTY)     
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey  
   AND PickSlipNo = @cPickSlipNo  

   IF ISNULL(@nTTLPickedQty,0)   = ISNULL(@nTTLPackedQty,0)     
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
        ,@c_LModMode       = '18'  
        
      IF @nErrNo <> 0    
         GOTO Rollbacktran     
            
   END    
    
   COMMIT TRAN isp_805PTLStation_Confirm    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN isp_805PTLStation_Confirm -- Only rollback change made here    
  -- Raise error to go to catch block    
   RAISERROR ('', 16, 1) WITH SETERROR    
    
END TRY    
BEGIN CATCH    
       
   SET @nSPErrNo = @nErrNo     
   SET @cSPErrMSG = @cErrMsg    
    
   ---- RelightUp     
   --EXEC PTL.isp_PTL_LightUpLoc    
   --   @n_Func           = @nFunc    
   --  ,@n_PTLKey         = 0    
   --  ,@c_DisplayValue   = @nQty    
   --  ,@b_Success        = @bSuccess    OUTPUT        
   --  ,@n_Err            = @nErrNo      OUTPUT      
   --  ,@c_ErrMsg         = @cErrMsg     OUTPUT    
   --  ,@c_DeviceID       = @cStation    
   --  ,@c_DevicePos      = @cPosition    
   --  ,@c_DeviceIP       = @cIPAddress      
   --  ,@c_LModMode       = '99'    
    
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