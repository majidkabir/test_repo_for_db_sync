SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************/      
/* Store procedure: isp_805PTL_Confirm14                                */      
/* Copyright      : LF Logistics                                        */      
/*                                                                      */      
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 02-09-2024 1.0  YeeKung  FCR-609 Created                             */ 
/* 02-12-2024 1.1  YeeKung  UWP-27793 Solved DB Blocking (yeekung01)    */
/* 30-09-2024 1.2  yeekung  FCR-772 Add Transmitlog2                    */
/* 20-12-2024 1.3  yeekung  FCR-1484 light up all order in multi station*/      
/************************************************************************/      
      
CREATE     PROC [PTL].[isp_805PTL_Confirm14] (      
   @cIPAddress    NVARCHAR(30),      
   @cPosition     NVARCHAR(20),      
   @cFuncKey      NVARCHAR(2),      
   @nSerialNo     INT,      
   @cInputValue   NVARCHAR(20),      
   @nErrNo        INT           OUTPUT,      
   @cErrMsg       NVARCHAR(125) OUTPUT,      
   @cDebug        NVARCHAR( 1) = '',
   @cFacility     NVARCHAR( 20)
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
   DECLARE @nExpectedQTY   INT  = 0    
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
   DECLARE @cLabelNo       NVARCHAR( 30)      
   DECLARE @nTotalExpectedQTY INT      
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)      
   DECLARE @cSQL           NVARCHAR( MAX)      
   DECLARE @cSQLParam      NVARCHAR( MAX)      
   DECLARE @cNewLine       NVARCHAR(1)   
   DECLARE @cQTY           NVARCHAR(10)
   DECLARE @cPackDetailDropID NVARCHAR(20)
   DECLARE @cPackDetailUPC    NVARCHAR(30)
   DECLARE @cPackDetailRefNo  NVARCHAR(20)
   DECLARE @cTrackNo       NVARCHAR( 20)
   DECLARE @cNotes         NVARCHAR( 30)
   DECLARE @cUserDefine03  NVARCHAR( 20)
   DECLARE @nRowRef        INT
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT
      
   DECLARE @cLabelPrinter     NVARCHAR( 10)      
         , @cPaperPrinter     NVARCHAR( 10)      
         , @nMobile           INT      
         , @cLightModeEnd     NVARCHAR(10)      
         , @cbatchkey NVARCHAR(20)      
         , @nCUBE FLOAT      
      
   DECLARE @curPTL CURSOR      
   DECLARE @curPD  CURSOR      
      
      -- Get device profile info      
      
   SET @nFunc = 805 -- PTL station (rdt.rdtfnc_PTLStation)      
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))      
      
   
   SET @nExpectedQTY = @cInputValue  
      
      
   -- Get storer      
   DECLARE @cStorerKey NVARCHAR(15)      
   SELECT TOP 1      
      @cStorerKey = StorerKey  ,  
      @cOrderKey = Orderkey  ,
      @cStation = DeviceID,
      @cSKU = SKU,  
      @nGroupKey = GroupKey,
      @cOrderKey = Orderkey,
      @cDropID   = DropID
   FROM PTL.PTLTran WITH (NOLOCK)      
   WHERE IPAddress = @cIPAddress      
      AND DevicePosition = @cPosition
      AND LightUP ='1'      
      AND Facility = @cFacility
      
   -- Get storer config      
   DECLARE @cUpdatePickDetail NVARCHAR(1)      
   DECLARE @cUpdatePackDetail NVARCHAR(1)  
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   DECLARE @cUpdateTrackNo    NVARCHAR(1) 

   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   SET @cUpdateTrackNo = rdt.rdtGetConfig( @nFunc, 'UpdateTrackNo', @cStorerKey)
   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)  
   IF @cGenLabelNo_SP = '0'  
      SET @cGenLabelNo_SP = ''  
   
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)    
      
   SELECT TOP 1 @cPaperPrinter   = Printer_Paper      
               ,@cLabelPrinter   = Printer      
               ,@nMobile         = Mobile      
   FROM rdt.rdtMobrec WITH (NOLOCK)      
   WHERE username=@cUserName      
   AND Func=805      

   -- Get booking info      
   SELECT      
      @cWaveKey = wavekey,
      @cCartonID = CartonID
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)      
   WHERE RowRef = @nGroupKey      
      
   SELECT TOP 1 @cLoadKey = PH.ExternOrderKey      
   FROM PickDetail PD (NOLOCK) 
      JOIN PickHeader PH (NOLOCK) ON PD.PickSlipNo = PH.PickHeaderKey      
   WHERE PD.Orderkey = @cOrderKey   
   
   -- Calc QTY      
   IF @cInputValue = ''      
      SET @nQTY = 0      
   ELSE IF @cInputValue = 'End' -- IN00028515      
   BEGIN      
      GOTO QUIT      
   END      
   ELSE      
      SET @nQTY = CAST( @cInputValue AS INT)      
      
   -- Determine action      
   IF @nQTY = 0      
      SET @cType = 'SHORTTOTE'      
   ELSE      
      SET @cType = 'CLOSETOTE'      
      
   if @cDebug = '1'      
      select @cStorerKey '@cStorerKey', @cStation '@cStation', @nGroupKey '@nGroupKey', @cOrderKey '@cOrderKey', @cCartonID '@cCartonID', @cSKU '@cSKU',      
      @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName'      
      
   -- For calc balance      
   SET @nQTY_Bal = @nQTY      
      
   -- Handling transaction      
   SET @nTranCount = @@TRANCOUNT      
   BEGIN TRAN  -- Begin our own transaction      
   SAVE TRAN isp_805PTL_Confirm14 -- For rollback or commit only our own transaction      
      
   SET @nExpectedQTY = 0      
      
   -- PTLTran      
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PTLKey, ExpectedQTY      
      FROM PTL.PTLTran WITH (NOLOCK)      
      WHERE IPAddress = @cIPAddress      
         AND DevicePosition = @cPosition          
         AND LightUP ='1'      
         AND Facility = @cFacility  
   OPEN @curPTL      
   FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL      
   WHILE @@FETCH_STATUS = 0      
   BEGIN     
	IF @nExpectedQTY = 0
      SET @nExpectedQTY =  @nQTY_PTL      
      
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
            SET @nErrNo = 222751      
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
            SET @nErrNo = 222752      
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
               SET @nErrNo = 222753      
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
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, SourceType, ArchiveCop,Facility)      
            SELECT      
               @nQTY_PTL - @nQTY_Bal, 0, NULL,      
               IPAddress, DeviceID, DevicePosition, Status, LightUp, LightMode, LightSequence, PTLType, SourceKey, DropID, CaseID, RefPTLKey,      
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_805PTL_Confirm14', ArchiveCop,Facility      
            FROM PTL.PTLTran WITH (NOLOCK)      
            WHERE PTLKey = @nPTLKey      
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 222754      
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
               SET @nErrNo = 222755      
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

   IF @cUpdatePickDetail = '1'      
   BEGIN      

      -- Get PickDetail tally PTLTran      
      SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)      
      FROM   Orders O WITH (NOLOCK)      
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
      WHERE o.UserDefine09 = @cWaveKey      
         AND PD.SKU = @cSKU        
         AND PD.Status <= '5'      
         AND PD.CaseID = ''   
         AND PD.DropID = @cDropID  
         AND PD.Orderkey = @cOrderKey  
         AND PD.QTY > 0      
         AND PD.StorerKey = @cStorerKey  
         AND PD.Status <> '4'      
         AND O.Status <> 'CANC'      
         AND O.SOStatus <> 'CANC'      
         AND UOM <> '2'      
      
      select @cWaveKey,@cOrderKey,'@cOrderKey',@cSKU,'@cSKU'  ,@nExpectedQTY    ,@nQTY_PD
      
      IF @nQTY_PD <> @nExpectedQTY      
      BEGIN      
         SET @nErrNo = 222756      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed      
         GOTO RollBackTran      
      END      
      
      -- For calculation      
      SET @nQTY_Bal = @nQTY 

      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT pickdetailkey, SUM( PD.QTY)      
      FROM   Orders O WITH (NOLOCK)      
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
      WHERE o.UserDefine09=@cWaveKey      
         AND PD.SKU = @cSKU       
         AND PD.Orderkey = @cOrderkey 
         AND PD.Status <= '5'      
         AND PD.CaseID = ''      
         AND PD.QTY > 0	
         AND PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cDropID		
		   AND PD.Orderkey = @cOrderkey
         AND PD.Status <> '4'      
         AND O.Status <> 'CANC'      
         AND O.SOStatus <> 'CANC'      
         AND UOM <>'2'      
      GROUP BY pickdetailkey      
      
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
               CASEID = @cCartonID,      
               EditDate = GETDATE(),      
               EditWho  = SUSER_SNAME()      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 222757      
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
               CASEID = @cCartonID,      
               EditDate = GETDATE(),      
               EditWho  = SUSER_SNAME()      
            WHERE PickDetailKey = @cPickDetailKey      
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 222758      
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
                 SET @nErrNo = 222759      
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
                  SET @nErrNo = 222760      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey      
                  GOTO RollBackTran      
               END      
      
               -- Create new a PickDetail to hold the balance      
               INSERT INTO dbo.PickDetail (      
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,      
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,      
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,      
                  PickDetailKey,Channel_ID,      
                  QTY,      
                  TrafficCop,      
                  OptimizeCop)      
               SELECT      
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,      
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,      
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,      
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,      
                  @cNewPickDetailKey, Channel_ID,      
                  @nQTY_PD - @nQTY_Bal, -- QTY      
                  NULL, -- TrafficCop      
                  '1'   -- OptimizeCop      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE PickDetailKey = @cPickDetailKey      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 222761      
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
                     SET @nErrNo = 222762      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSRefKeyFail      
                     GOTO RollBackTran      
                  END      
               END      
      
               -- Change orginal PickDetail with exact QTY (with TrafficCop)      
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
                  QTY = @nQTY_Bal,      
                  dropid = @cCartonID,      
                  CASEID = @cCartonID,      
                  EditDate = GETDATE(),      
                  EditWho  = SUSER_SNAME(),      
                  Trafficcop = NULL      
               WHERE PickDetailKey = @cPickDetailKey      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 222763      
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
                  SET @nErrNo = 222764      
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
   -- PackDetail      
   IF @cUpdatePackDetail = '1'  AND @nQTY <> 0    
   BEGIN      
      -- Get PickSlipNo
      SET @cPickSlipNo = ''
      SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      -- PackHeader
      IF @cPickSlipNo = ''
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

         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 222765
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END    
      
      -- Get carton no  
      SET @nCartonNo = 0  
      SET @cLabelNo = ''  
      SELECT   
         @nCartonNo = CartonNo,   
         @cLabelNo = LabelNo  
      FROM dbo.PackDetail WITH (NOLOCK)   
      WHERE PickSlipNo = @cPickSlipNo   
         AND DropID = @cCartonID  

      -- New carton  
      IF @nCartonNo = 0  
      BEGIN  
         -- Get new label no  
         IF @cGenLabelNo_SP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')    
            BEGIN  
               SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +  
                  ' @cPickslipNo, ' +    
                  ' @nCartonNo,   ' +    
                  ' @cLabelNo     OUTPUT '    
               SET @cSQLParam =  
                  ' @cPickslipNo  NVARCHAR(10),       ' +    
                  ' @nCartonNo    INT,                ' +    
                  ' @cLabelNo     NVARCHAR(20) OUTPUT '    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @cPickslipNo,   
                  @nCartonNo,   
                  @cLabelNo OUTPUT  
            END  
         END  
         ELSE  
         BEGIN     
            EXEC isp_GenUCCLabelNo  
               @cStorerKey,  
               @cLabelNo      OUTPUT,   
               @bSuccess      OUTPUT,  
               @nErrNo        OUTPUT,  
               @cErrMsg       OUTPUT  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 222766  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
               GOTO RollBackTran  
            END  
         END  

         -- Check label no  
         IF @cLabelNo = ''  
         BEGIN  
            SET @nErrNo = 222767  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
            GOTO RollBackTran  
         END  
                 
         -- Grap a track no  
         IF @cUpdateTrackNo = '1'  
         BEGIN  
            -- Get order info  
            SELECT @cUserDefine03 = UserDefine03 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
               
            -- Get code lookup info  
            SELECT TOP 1   
               @cNotes = LEFT( ISNULL( Notes, ''), 30)  
            FROM CodeLKUP WITH (NOLOCK)   
            WHERE ListName = 'LOTTELBL'   
               AND Short = @cUserDefine03  
               AND StorerKey = @cStorerKey  
               
            -- Get track no  
            SELECT TOP 1   
               @nRowRef = RowRef,   
               @cTrackNo = TrackingNo  
            FROM CartonTrack WITH (NOLOCK)  
            WHERE KeyName = @cNotes  
               AND CarrierRef2 <> 'GET'  
            ORDER BY RowRef  
               
            -- Stamp track no used  
            UPDATE CartonTrack SET   
               CarrierRef2 = 'GET',   
               LabelNo = @cLabelNo  
            WHERE RowRef = @nRowRef  
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  
            BEGIN  
               SET @nErrNo = 222768  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail  
               GOTO RollBackTran  
            END   
         END  
      END  
	  
      -- PackDetail
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cCartonID AND CartonNo = @nCartonNo AND SKU = @cSKU)
      BEGIN
         -- Get next LabelLine
         IF @nCartonNo = 0
            SET @cLabelLine = ''
         ELSE
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               
         -- Insert PackDetail  
         INSERT INTO dbo.PackDetail  
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)  
         VALUES  
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cCartonID,   
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 222769
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
            AND CartonNo = @nCartonNo
            AND DropID = @cCartonID
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 222770
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
         END
      END

      IF NOT EXISTS (SELECT TOP 1 1  
               FROM  PickDetail PD WITH (NOLOCK) 
               WHERE PD.Orderkey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey  
                  AND PD.Status  <= '5'
                  AND PD.Status  <> '4'
                  AND PD.CaseID = ''  
                  AND PD.QTY > 0)  
      BEGIN
         IF EXISTS ( SELECT 1
                     From dbo.StorerConfig (Nolock) 
            WHERE Configkey = 'Innobec'
               AND Storerkey = @cStorerkey
               And Svalue = '1'
         )
         BEGIN
            -- Insert transmitlog2 here  
            EXEC ispGenTransmitLog2   
                  @c_TableName        = 'WSBOXCFMlb'  
               ,@c_Key1             = @cOrderkey  
               ,@c_Key2             = @cCartonID  
               ,@c_Key3             = @cStorerkey  
               ,@c_TransmitBatch    = ''  
               ,@b_Success          = @bSuccess    OUTPUT  
               ,@n_err              = @nErrNo      OUTPUT  
               ,@c_errmsg           = @cErrMsg     OUTPUT        

            -- Insert TL2 here only, the web service will do the printing  
            -- quit after excute        
            IF @bSuccess <> 1      
               GOTO Quit  
         END
      END

      IF @cAutoPackConfirm = '1'
      BEGIN
         -- No outstanding PickDetail
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')
         BEGIN
            SET @nPackQTY = 0
            SET @nPickQTY = 0
            SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
            SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            IF @nPackQTY = @nPickQTY
            BEGIN
               -- Pack confirm
               UPDATE PackHeader SET
                  Status = '9'
               WHERE PickSlipNo = @cPickSlipNo
                  AND Status <> '9'
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 222771
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
                  GOTO RollBackTran
               END
            END
         END
      END     
        
   END     
   
   IF NOT EXISTS (SELECT 1      
               FROM   Orders O WITH (NOLOCK)      
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
               WHERE o.UserDefine09=@cWaveKey          
                  AND pd.Orderkey = @cOrderKey
                  AND PD.Status <= '5'      
                  AND PD.CaseID = ''      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND O.Status <> 'CANC'      
                  AND O.SOStatus <> 'CANC'      
                  AND UOM <>'2'      
   )      
   BEGIN      
      SET @nErrNo = 0
      SET @cLightModeEnd = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)      



      DECLARE @curMultiStation CURSOR
      SET @curMultiStation = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Station,Position,IPAddress
      FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)  
      WHERE Wavekey =  @cWaveKey
         AND Orderkey = @cOrderkey
  
      OPEN @curMultiStation      
      FETCH NEXT FROM @curMultiStation INTO @cStation, @cPosition ,@cIPAddress      
      WHILE @@FETCH_STATUS = 0      
      BEGIN   
      
         EXEC PTL.isp_PTL_LightUpLoc      
            @n_Func           = @nFunc      
            ,@n_PTLKey         = 0      
            ,@c_DisplayValue   = 'End'      
            ,@b_Success        = @bSuccess    OUTPUT      
            ,@n_Err            = @nErrNo      OUTPUT      
            ,@c_ErrMsg         = @cErrMsg     OUTPUT      
            ,@c_DeviceID       = @cStation      
            ,@c_DevicePos      = @cPosition      
            ,@c_DeviceIP       = @cIPAddress      
            ,@c_LModMode       = @cLightModeEnd      
         
         IF @nErrNo <> 0      
         BEGIN      
            SET @nErrNo = 222772      
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'      
            GOTO RollBackTran      
         END  
         FETCH NEXT FROM @curMultiStation INTO @cStation, @cPosition ,@cIPAddress  
      END    
      CLOSE @curMultiStation
      DEALLOCATE @curMultiStation
   END     
   
   SET @nExpectedQTY = 0

   SELECT TOP 1 @cPosition     = PTL.DevicePosition,  
                @nExpectedQTY  = PTL.ExpectedQty,
                @nPTLKey       = PTL.PTLKey
    FROM PTL.PTLTran PTL WITH (NOLOCK)    
      JOIN DeviceProfile DP (nolock) ON PTL.DevicePosition = DP.DevicePosition AND PTL.DeviceID = DP.DeviceID AND PTL.IPaddress =DP.IPAddress
    WHERE PTL.IPAddress = @cIPAddress   
        AND PTL.Status <> '9'    
        AND PTL.DeviceID = @cStation
        AND PTL.DropID = @cDropID	
        AND DP.Facility = @cFacility
    ORDER BY CAST(DP.logicalpos AS INT)
      
    IF @cDebug = '1'      
        SELECT @cType '@cType', @cIPAddress '@cIPAddress', @cPosition '@cPosition', @nGroupKey '@nGroupKey', @cDropID '@cDropID', @cSKU '@cSKU', @nExpectedQTY '@nExpectedQTY'      
      
	IF @nExpectedQTY > 0      
	BEGIN      
           
		SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(10))      
		IF LEN( @cQTY) > 5      
			SET @cQTY = '*'      
		ELSE      
			SET @cQTY = LEFT( @cQTY, 5)      
      
		SET @nErrNo = 0

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
      
   COMMIT TRAN isp_805PTL_Confirm14      
   GOTO Quit      
      
 RollBackTran:      
   ROLLBACK TRAN isp_805PTL_Confirm14 -- Only rollback change made here      
      
   -- Raise error to go to catch block      
   RAISERROR ('', 16, 1) WITH SETERROR      
      
   END TRY      
   BEGIN CATCH      
     IF @cDebug = 0      
       -- RelightUp      
      EXEC PTL.isp_PTL_LightUpLoc      
         @n_Func           = @nFunc      
        ,@n_PTLKey         = 0      
        ,@c_DisplayValue   = 'ERR'      
        ,@b_Success        = @bSuccess    OUTPUT      
        ,@n_Err            = @nErrNo      OUTPUT      
        ,@c_ErrMsg         = @cErrMsg     OUTPUT      
        ,@c_DeviceID       = @cStation      
        ,@c_DevicePos      = @cPosition      
        ,@c_DeviceIP       = @cIPAddress      
        ,@c_LModMode       = '99'      
      
   END CATCH      
      
Quit:      
IF XACT_STATE() <> -1      
BEGIN                      -- XACT_STATE() = 1 (committable), -1 (uncommittable), 0 (no transaction)  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
   COMMIT TRAN  

END 

GO