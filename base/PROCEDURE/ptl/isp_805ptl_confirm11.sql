SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: isp_805PTL_Confirm11                                */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: PTL station confirm qty                                     */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2021-04-19 1.0  James    WMS-15658. Created                          */  
/************************************************************************/  
  
CREATE PROC [PTL].[isp_805PTL_Confirm11] (  
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
   DECLARE @cLOC           NVARCHAR( 10)  
   DECLARE @cType          NVARCHAR( 10)  
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @cLightMode     NVARCHAR( 4)  
   DECLARE @cLabelLine     NVARCHAR( 5)  
   DECLARE @cDisplayValue  NVARCHAR( 5)  
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cPTLLOC        NVARCHAR( 10)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @nUCCQty        INT = 0
   DECLARE @nResidualQty   INT = 0
   DECLARE @nMobile        INT
   DECLARE @nPABookingKey  INT = 0
   DECLARE @nSuccess       INT
   DECLARE @nCountTask     INT
   DECLARE @cFromLoc       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18) = ''
   DECLARE @cLot           NVARCHAR( 10)
   DECLARE @cUCCSKU        NVARCHAR( 20)
	DECLARE @cOutField01    NVARCHAR( 20)
	DECLARE @cOutField02    NVARCHAR( 20)
   DECLARE @cOutField03    NVARCHAR( 20)
   DECLARE @cOutField04    NVARCHAR( 20)
   DECLARE @cOutField05    NVARCHAR( 20)
   DECLARE @cOutField06    NVARCHAR( 20)
   DECLARE @cOutField07    NVARCHAR( 20)
   DECLARE @cOutField08    NVARCHAR( 20)
   DECLARE @cOutField09    NVARCHAR( 20)
   DECLARE @cOutField10    NVARCHAR( 20)
	DECLARE @cOutField11    NVARCHAR( 20)
	DECLARE @cOutField12    NVARCHAR( 20)
   DECLARE @cOutField13    NVARCHAR( 20)
   DECLARE @cOutField14    NVARCHAR( 20)
   DECLARE @cOutField15    NVARCHAR( 20)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToLOCPAZone   NVARCHAR( 10)
   DECLARE @cToLOCAreaKey  NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cCurrentPTLLOC    NVARCHAR( 10)
   DECLARE @cQCStation     NVARCHAR(10) = ''
   DECLARE @curPTL CURSOR  
   DECLARE @curPD  CURSOR  
   DECLARE @nTtl_PackedQty INT = 0
   DECLARE @cConsigneeKey  NVARCHAR( 15)
   DECLARE @cRoute         NVARCHAR( 10)

   DECLARE @tPTL TABLE
   (
      Seq       INT IDENTITY(1,1) NOT NULL,
      PTLKey    BIGINT
   )
     
   SET @nFunc = 805 -- PTL station (rdt.rdtfnc_PTLStation)  
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))  
   
   -- Get display value  
   SELECT @cDisplayValue = LEFT( DisplayValue, 5)  
   FROM PTL.LightStatus WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress  
      AND DevicePosition = @cPosition  
  
   -- Get device profile info  
   SELECT @cStation = DeviceID, 
          @cCurrentPTLLOC = LogicalName  
   FROM dbo.DeviceProfile WITH (NOLOCK)    
   WHERE IPAddress = @cIPAddress  
      AND DevicePosition = @cPosition  
      AND DeviceType = 'STATION'  
      AND DeviceID <> ''  

   -- No need check for full tote, user will put everything in
   IF @cDisplayValue <> 'FTOTE'
   BEGIN
      -- Check over put  
      IF CAST( @cInputValue AS INT) > CAST( @cDisplayValue AS INT) 
      BEGIN  
         if @cDebug = '1'  
            SELECT @cInputValue '@cInputValue', @cDisplayValue '@cDisplayValue'  
         RAISERROR ('', 16, 1) WITH SETERROR -- Raise error to go to catch block  
      END  
   END
   ELSE
      SELECT @cInputValue = ISNULL( SUM( ExpectedQty), 0)
      FROM PTL.PTLTran WITH (NOLOCK)  
      WHERE IPAddress = @cIPAddress   
         AND DevicePosition = @cPosition   
         AND LightUp = '1' 
      
   -- Get storer   
   DECLARE @cStorerKey NVARCHAR(15)  
   SELECT TOP 1   
      @cStorerKey = StorerKey  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress   
      AND DevicePosition = @cPosition   
      AND LightUp = '1'  
  
   -- Get storer config  
   DECLARE @cUpdatePickDetail NVARCHAR(1)  
   DECLARE @cUpdatePackDetail NVARCHAR(1)  
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)  
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)  
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)  
  
   -- Get booking info  
   SELECT   
      @nGroupKey = RowRef,   
      @cWaveKey = WaveKey,
      @cOrderKey = OrderKey,   
      @cCartonID = CartonID,
      @cPTLLOC = LOC  
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
   WHERE Station = @cStation  
      AND IPAddress = @cIPAddress  
      AND Position = @cPosition  
  
   -- Get PTLTran info  
   SELECT TOP 1  
      @cSKU = SKU,   
      @cUserName = EditWho,
      @cDropID = DropID  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress  
      AND DevicePosition = @cPosition  
      AND GroupKey = @nGroupKey  
      AND Func = 805  
      AND Status = '1' -- Lighted up  

   SELECT @cFacility = Facility 
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
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
   @nGroupKey '@nGroupKey', @cStorerKey '@cStorerKey', @cOrderKey '@cOrderKey', @cCartonID '@cCartonID', @cSKU '@cSKU',   
   @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName'  
  
   -- For calc balance  
   SET @nQTY_Bal = @nQTY  
  
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN isp_805PTL_Confirm11 -- For rollback or commit only our own transaction  
  
/*  
insert into a (fld, val) values ('@cDPLKey', @cDPLKey)  
insert into a (fld, val) values ('@cPosition', @cPosition)  
insert into a (fld, val) values ('@cLOC', @cLOC)  
insert into a (fld, val) values ('@cSKU', @cSKU)  
insert into a (fld, val) values ('@nQTY', @nQTY)  
insert into a (fld, val) values ('@cStation', @cStation)  
*/  
  --SELECT @cIPAddress '@cIPAddress', @cPosition '@cPosition', @nGroupKey '@nGroupKey', @cSKU '@cSKU'
   -- PTLTran  

   INSERT INTO @tPTL ( PTLKey) 
   SELECT PTLKey  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress  
      AND DevicePosition = @cPosition  
      AND GroupKey = @nGroupKey  
      --AND SKU = @cSKU  
      AND DropID = @cDropID
      AND Status <> '9'  
         
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PTLKey, ExpectedQTY  
      FROM PTL.PTLTran WITH (NOLOCK)  
      WHERE IPAddress = @cIPAddress  
         AND DevicePosition = @cPosition  
         AND GroupKey = @nGroupKey  
         --AND SKU = @cSKU  
         AND DropID = @cDropID
         AND Status <> '9'  
   OPEN @curPTL  
   FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @nExpectedQTY IS NULL  
         SET @nExpectedQTY = @nQTY_PTL  
      ELSE
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
            --MessageNum = @cMessageNum,  
            EditWho = SUSER_SNAME(),  
            EditDate = GETDATE(),  
            TrafficCop = NULL  
         WHERE PTLKey = @nPTLKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 166601  
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
            --MessageNum = @cMessageNum,  
            EditDate = GETDATE(),  
            EditWho  = SUSER_SNAME(),  
            TrafficCop = NULL  
         WHERE PTLKey = @nPTLKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 166602  
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
               --MessageNum = @cMessageNum,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME(),  
               TrafficCop = NULL  
            WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166603  
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
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_805PTL_Confirm11', ArchiveCop  
            FROM PTL.PTLTran WITH (NOLOCK)  
            WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166604  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail  
               GOTO RollBackTran  
            END  
  
            -- Confirm orginal PTLTran with exact QTY  
            UPDATE PTL.PTLTran WITH (ROWLOCK) SET  
               Status = '9',  
               LightUp = '0',   
               ExpectedQty = @nQTY_Bal,  
               QTY = @nQTY_Bal,  
               --MessageNum = @cMessageNum,  
               CaseID = @cCartonID,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME(),  
               Trafficcop = NULL  
            WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166605  
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
      WHERE O.OrderKey = @cOrderKey  
         --AND PD.SKU = @cSKU
         AND pd.DropID = @cDropID  
         AND PD.Status <> '4'  
         AND PD.Status < '9'
         AND PD.QTY > 0  
         AND O.Status <> 'CANC'  
         AND O.SOStatus <> 'CANC'  
  
      IF @nQTY_PD <> @nExpectedQTY  
      BEGIN  
         --SELECT @nExpectedQTY '@nExpectedQTY', @nQTY_PD '@nQTY_PD'
         SET @nErrNo = 166606  
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
         WHERE O.OrderKey = @cOrderKey  
            --AND SKU = @cSKU  
            AND PD.DropID = @cDropID
            AND PD.Status <> '4'  
            AND PD.Status < '9'
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
               Status = '5',  
               CaseID = @cCartonID,  
               DropID = @cCartonID,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166607  
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
               CaseID = @cCartonID,  
               DropID = @cCartonID,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166608  
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
                  --CaseID = @cCartonID,  
                  --DropID = @cCartonID,  
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME(),  
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166609  
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
                  SET @nErrNo = 166610  
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
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
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
                  SET @nErrNo = 166611  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                  GOTO RollBackTran  
               END  
  
               -- Split RefKeyLookup  
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
               BEGIN  
                  -- Get PickDetail info  
                  DECLARE @cOrderLineNumber NVARCHAR( 5)  
                  DECLARE @cLoadkey NVARCHAR( 10)  
                  SELECT  
                     @cOrderLineNumber = OD.OrderLineNumber,  
                     @cLoadkey = OD.Loadkey  
                  FROM dbo.PickDetail PD WITH (NOLOCK)  
                     INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
                  WHERE PD.PickDetailkey = @cPickDetailKey  
     
                  -- Get PickSlipNo  
                  DECLARE @cPickSlipNo NVARCHAR(10)  
                  SET @cPickSlipNo = ''  
                  SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
                  IF @cPickSlipNo = ''  
                     SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey  
     
                  -- Insert into  
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                  VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 166612  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                     GOTO RollBackTran  
                  END  
               END  
  
               -- Change orginal PickDetail with exact QTY (with TrafficCop)  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  QTY = @nQTY_Bal,  
                  CaseID = @cCartonID,  
                  DropID = @cCartonID,  
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME(),  
                  Trafficcop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166613  
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
                  SET @nErrNo = 166614  
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
   IF @cUpdatePackDetail = '1'  
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
         
         SELECT 
            @cLoadkey = LoadKey, 
            @cConsigneeKey = ConsigneeKey, 
            @cRoute = [Route]
         FROM dbo.ORDERS WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey, ConsigneeKey, [Route])  
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadkey, @cConsigneeKey, @cRoute)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 166615  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail  
            GOTO RollBackTran  
         END  
      END  
      
      DECLARE @ccurPackDtl CURSOR
      DECLARE @cPack_SKU   NVARCHAR( 20)
      DECLARE @nPack_Qty   INT
      SET @ccurPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PTL1.SKU, SUM( PTL1.Qty)
      FROM PTL.PTLTRAN PTL1 WITH (NOLOCK)
      JOIN @tPTL PTL2 ON PTL1.PTLKey = PTL2.PTLKey
      GROUP BY PTL1.SKU
      OPEN @ccurPackDtl
      FETCH NEXT FROM @ccurPackDtl INTO @cPack_SKU, @nPack_Qty
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get carton no  
         SET @nCartonNo = 0  
         SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID  
        
         -- PackDetail  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID AND SKU = @cPack_SKU)  
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
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cPack_SKU, @nPack_Qty, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cDropID)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166616  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
               GOTO RollBackTran  
            END       
         END  
         ELSE  
         BEGIN  
            -- Update Packdetail  
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
               QTY = QTY + @nPack_Qty,   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               EditDate = GETDATE(),   
               ArchiveCop = NULL  
            WHERE PickSlipNo = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cCartonID  
               AND SKU = @cPack_SKU  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166617  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail  
               GOTO RollBackTran  
            END  
         END
         
         SET @nTtl_PackedQty = @nTtl_PackedQty + @nPack_Qty

         FETCH NEXT FROM @ccurPackDtl INTO @cPack_SKU, @nPack_Qty  
      END
      -- Auto pack confirm  
      DECLARE @cAutoPackConfirm NVARCHAR(1)  
      SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)  
      IF @cAutoPackConfirm = '1'  
      BEGIN  
         -- No outstanding PickDetail  
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')  
         BEGIN  
            DECLARE @nPackQTY INT  
            DECLARE @nPickQTY INT  
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
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166618  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail  
                  GOTO RollBackTran  
               END  
               /*
               -- Update packdetail.labelno = pickdetail.caseid
               -- Get storer config
               DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
               EXECUTE nspGetRight
                  @cFacility,
                  @cStorerKey,
                  '', --@c_sku
                  'AssignPackLabelToOrdCfg',
                  @bSuccess                 OUTPUT,
                  @cAssignPackLabelToOrdCfg OUTPUT,
                  @nErrNo                   OUTPUT,
                  @cErrMsg                  OUTPUT
               IF @nErrNo <> 0
                  GOTO RollBackTran

               -- Assign
               IF @cAssignPackLabelToOrdCfg = '1'
               BEGIN
                  -- Update PickDetail, base on PackDetail.DropID
                  EXEC isp_AssignPackLabelToOrderByLoad
                      @cPickSlipNo
                     ,@bSuccess OUTPUT
                     ,@nErrNo   OUTPUT
                     ,@cErrMsg  OUTPUT
                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END

               DECLARE @curUpdPack   CURSOR
               DECLARE @curUpdPick   CURSOR
               DECLARE @cTempLabelNo   NVARCHAR( 20)
               DECLARE @cTempDropID    NVARCHAR( 20)
               DECLARE @cTempPickDetailKey    NVARCHAR( 20)
               SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               ORDER BY 1
               OPEN @curUpdPack
               FETCH NEXT FROM @curUpdPack INTO @cTempLabelNo
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Update packdetail.dropid = pickdetail.dropid
                  SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT DISTINCT DropID FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   CaseID = @cTempLabelNo
                  AND   [Status] = '5'
                  OPEN @curUpdPick
                  FETCH NEXT FROM @curUpdPick INTO @cTempDropID
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     UPDATE dbo.PACKDETAIL SET 
                        DropID = CASE WHEN ISNULL( @cTempDropID, '') = '' THEN @cTempLabelNo ELSE @cTempDropID END,
                        EditWho = USER_NAME(), 
                        EditDate = GETDATE()
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   LabelNo = @cTempLabelNo

                     IF @@ERROR <> 0
                        GOTO RollBackTran
                     
                     FETCH NEXT FROM @curUpdPick INTO @cTempDropID
                  END
                  CLOSE @curUpdPick
                  DEALLOCATE @curUpdPick

                  -- Update pickdetail.dropid = packdetail.labelno
                  SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PickDetailKey FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   CaseID = @cTempLabelNo
                  AND   [Status] = '5'
                  OPEN @curUpdPick
                  FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     UPDATE dbo.PICKDETAIL SET 
                        DropID = @cTempLabelNo,
                        EditWho = USER_NAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cTempPickDetailKey
                  
                     IF @@ERROR <> 0
                        GOTO RollBackTran

                     FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey
                  END
                  CLOSE @curUpdPick
                  DEALLOCATE @curUpdPick

                  FETCH NEXT FROM @curUpdPack INTO @cTempLabelNo
               END
               CLOSE @curUpdPack
               DEALLOCATE @curUpdPack
               */
            END
         END  
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
           
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY  
            FROM PTL.PTLTran WITH (NOLOCK)  
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
               AND SKU = @cSKU  
               AND Status <> '9'  
     
         OPEN @curPTL  
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            -- Get carton  
            SELECT   
               @cCartonID = CartonID,   
               @cOrderKey= OrderKey  
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
               SET @nErrNo = 166619  
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
               WHERE O.OrderKey = @cOrderKey  
                  AND LOC = @cLOC  
                  AND SKU = @cSKU  
                  AND PD.Status < '4'  
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'  
                  AND O.SOStatus <> 'CANC'  
               IF @nQTY_PD <> @nExpectedQTY  
               BEGIN  
                  SET @nErrNo = 166620  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed  
                  GOTO RollBackTran  
               END  
  
               -- Loop PickDetail  
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT PickDetailKey  
                  FROM Orders O WITH (NOLOCK)  
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
                  WHERE O.OrderKey = @cOrderKey  
                     AND LOC = @cLOC  
                     AND SKU = @cSKU  
                     AND PD.Status < '4'  
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
                     CaseID = @cCartonID,  
                     EditWho = SUSER_SNAME(),  
                     EditDate = GETDATE()  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 166621  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey  
               END  
            END  
  
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nExpectedQTY, @cOrderKey  
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
                  GOTO Quit  
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
         AND SKU = @cSKU  
         AND Status <> '9'  
           
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
            GOTO RollBackTran  
      END  
   END  
   
   -- Insert routing
   SET @cOrderKey = ''
   SELECT TOP 1 @cOrderKey = OrderKey
   FROM dbo.PICKDETAIL WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   DropID = @cDropID
   AND   Status <> '4'  
   AND   Status < '9'
   AND   QTY > 0  
   ORDER BY 1

   IF @cType = 'SHORTTOTE'
      SET @cOrderKey = ''

   IF @cOrderKey = ''
   BEGIN
      -- Short pack
      --IF CAST( @cInputValue AS INT) < CAST( @cDisplayValue AS INT) AND 
      --   @cDisplayValue <> 'FTOTE'
      IF @cType <> 'SHORTTOTE'
      BEGIN
         -- the original ucc no more in pickdetail
         -- meaning no more residual, prompt empty box
         SET @nUCCQty = 0
         SELECT @nUCCQty = Qty
         FROM dbo.UCC WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   UCCNo = @cDropID

         SET @nPackQTY = 0
         SELECT @nPackQTY = ISNULL( SUM( Qty), 0)
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DropID = @cDropID   
         AND   Storerkey = @cStorerKey
         AND   Func = 805  

         -- Check if ucc has residual
         SET @nResidualQty = @nUCCQty - @nPackQTY

         -- With residual, generate astrpt task
         IF @nResidualQty > 0
         BEGIN
            SELECT @cFromLoc = Loc,
                   @cFromID = Id, 
                   @cUCCSKU = SKU,
                   @cLot = Lot
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cDropID
         
            SET @nErrNo = 0
            EXEC [RDT].[rdt_513SuggestLOC13] 
               @nMobile       = @nMobile,
               @nFunc         = @nFunc,
               @cLangCode     = @cLangCode,
               @cStorerkey    = @cStorerkey,
               @cFacility     = @cFacility,
               @cFromLoc      = @cFromLoc,
               @cFromID       = @cFromID,
               @cSKU          = @cUCCSKU,
               @nQTY          = 0,
               @cToID         = '',
               @cToLOC        = '',
               @cType         = 'LOCK',
               @nPABookingKey = @nPABookingKey  OUTPUT,
	            @cOutField01   = @cOutField01    OUTPUT,
	            @cOutField02   = @cOutField02    OUTPUT,
               @cOutField03   = @cOutField03    OUTPUT,
               @cOutField04   = @cOutField04    OUTPUT,
               @cOutField05   = @cOutField05    OUTPUT,
               @cOutField06   = @cOutField06    OUTPUT,
               @cOutField07   = @cOutField07    OUTPUT,
               @cOutField08   = @cOutField08    OUTPUT,
               @cOutField09   = @cOutField09    OUTPUT,
               @cOutField10   = @cOutField10    OUTPUT,
	            @cOutField11   = @cOutField11    OUTPUT,
	            @cOutField12   = @cOutField12    OUTPUT,
               @cOutField13   = @cOutField13    OUTPUT,
               @cOutField14   = @cOutField14    OUTPUT,
               @cOutField15   = @cOutField15    OUTPUT,
               @nErrNo        = @nErrNo         OUTPUT,
               @cErrMsg       = @cErrMsg        OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 166622
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err
               GOTO RollBackTran
            END

            IF ISNULL( @cOutField01, '') = ''
            BEGIN
               SET @nErrNo = 166623
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err
               GOTO RollBackTran
            END
            ELSE
               SET @cToLOC = @cOutField01
         
            -- Lock SuggestedLOC  
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
               ,@cFromLoc  
               ,@cFromID   
               ,@cToLOC  
               ,@cStorerKey  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU        = @cUCCSKU  
               ,@nPutawayQTY = @nResidualQty     
               ,@cUCCNo      = @cDropID  
               ,@cFromLOT    = @cLot  
               ,@nPABookingKey = @nPABookingKey OUTPUT
               
            SET @nSuccess = 1
            EXECUTE dbo.nspg_getkey
               'TASKDETAILKEY'
               , 10
               , @cNewTaskDetailKey OUTPUT
               , @nSuccess          OUTPUT
               , @nErrNo            OUTPUT
               , @cErrMsg           OUTPUT
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 166624
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
               GOTO RollBackTran
            END

            -- Get LOC info
            SET @cToLOCPAZone = ''
            SET @cToLOCAreaKey = ''
            SELECT @cToLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
            SELECT @cToLOCAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cToLOCPAZone 

            -- Insert final task
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, PickMethod, TransitCount, AreaKey, SourceType, FromLOC, FromID, ToLOC, ToID, 
               StorerKey, SKU, LOT, CaseID, UOMQty, QTY, ListKey, SourceKey, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
            VALUES(
               @cNewTaskDetailKey, 'ASTRPT', '0', '', 'PP', 1, @cToLOCAreaKey, 'isp_805PTL_Confirm11', @cFromLOC, '', @cToLOC, '', 
               @cStorerKey, @cUCCSKU, @cLot, @cDropID, @nResidualQty, @nResidualQty, '', '', @cWaveKey, '', '9', '9', NULL)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 166625
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CreateASTRPTFail
               GOTO RollBackTran
            END
         END
      END
   END

   COMMIT TRAN isp_805PTL_Confirm11  
   GOTO Quit  
  
   RollBackTran:  
   ROLLBACK TRAN isp_805PTL_Confirm11 -- Only rollback change made here  
     
   -- Raise error to go to catch block  
   RAISERROR ('', 16, 1) WITH SETERROR  
  
   END TRY  
   BEGIN CATCH  
     IF @cDebug = 0
      -- RelightUp   
      EXEC PTL.isp_PTL_LightUpLoc  
         @n_Func           = @nFunc  
        ,@n_PTLKey         = 0  
        ,@c_DisplayValue   = @cDisplayValue  
        ,@b_Success        = @bSuccess    OUTPUT      
        ,@n_Err            = @nErrNo      OUTPUT    
        ,@c_ErrMsg         = @cErrMsg     OUTPUT  
        ,@c_DeviceID       = @cStation  
        ,@c_DevicePos      = @cPosition  
        ,@c_DeviceIP       = @cIPAddress    
        ,@c_LModMode       = '99'  
  
   END CATCH  

   Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

      WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  

--SELECT * FROM PTL.PTLTRAN WITH (NOLOCK)
--                   WHERE IPAddress = @cIPAddress
--                   AND   DeviceID = @cStation
--                   AND   DropID = @cDropID
--                   AND   [Status] < '9'
                   
   -- Check if everything packed in this station then only insert routing
   IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)
                   WHERE IPAddress = @cIPAddress
                   AND   DeviceID = @cStation
                   AND   DropID = @cDropID
                   AND   [Status] < '9') OR @cType = 'SHORTTOTE'
   BEGIN
      -- Insert routing
      -- Get next orderkey to pack, order by station seq
      SET @cOrderKey = ''
      SELECT TOP 1 @cOrderKey = PD.OrderKey
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN rdt.rdtPTLStationLogQueue PTLLog WITH (NOLOCK) ON ( PD.OrderKey = PTLLog.OrderKey) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PTLLog.LOC = LOC.LOC)
      WHERE PD.Storerkey = @cStorerKey
      AND   PD.DropID = @cDropID
      AND   PD.[STATUS] <> '4'  
      AND   PD.[STATUS] < '9'
      AND   PD.QTY > 0  
      AND   PTLLog.WaveKey = @cWaveKey
      ORDER BY LOC.PutawayZone
      
      IF @cType = 'SHORTTOTE'
         SET @cOrderKey = ''

      IF @cOrderKey <> ''
      BEGIN
         SELECT TOP 1 @cPTLLOC = LOC
         FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   LOC <> @cCurrentPTLLOC  -- Find next available PTL station
         ORDER BY 1

         IF @@ROWCOUNT > 0
         BEGIN
             SET @nCountTask = 0   

             SELECT @cQCStation = ISNULL(RTRIM(Short),'')   
             FROM dbo.CodeLkup WITH (NOLOCK)  
             WHERE Listname = 'WCSStation'   
             AND Code = 'QC01' 
    
             SELECT @nCountTask = Count(WCSKey)  
             FROM dbo.WCSRouting WITH (NOLOCK)   
             WHERE ToteNo = @cDropID   
             AND Final_Zone <> @cQCStation  
             AND Status = '0'  
             --AND TaskType = 'PTS' 

             -- If there is route (not qc) that not finish then need 
             -- delete for new route to insert later
             IF ISNULL(@nCountTask,0 )  > 0   
             BEGIN  
                -- Update WCSRouting , WCSRoutingDetail  
                UPDATE dbo.WCSRoutingDetail  
                SET Status = '9'  
                WHERE ToteNo = @cDropID  
                AND Status = '0'  
                 
                IF @@ERROR <> 0  
                BEGIN  
                   SET @nErrNo = 166626    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetErr'     
                   GOTO Fail    
                END  
                  
                UPDATE dbo.WCSRouting  
                SET Status = '9'  
                WHERE ToteNo = @cDropID  
                AND Status = '0'  
                --AND TaskType = 'RPF'  
                 
                IF @@ERROR <> 0  
                BEGIN  
                   SET @nErrNo = 166627    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROErr'     
                   GOTO Fail    
                END  
            END
            
            -- If there is no route to qc (no short pick) then need insert new route
            IF NOT EXISTS ( SELECT 1 FROM WCSRouting WITH (NOLOCK)
                            WHERE ToteNo = @cDropID
                            AND   Final_Zone = @cQCStation
                            AND   [Status] = '0')
            BEGIN
               -- Delete existing route
               SET @nErrNo = 0
               EXEC [dbo].[ispWCSRO03]              
                 @c_StorerKey     =  @cStorerKey  
               , @c_Facility      =  @cFacility   
               , @c_ToteNo        =  @cDropID            
               , @c_TaskType      =  'PTS'            
               , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
               , @c_TaskDetailKey =  ''  
               , @c_Username      =  @cUserName  
               , @c_RefNo01       =  ''         
               , @c_RefNo02       =  ''  
               , @c_RefNo03       =  ''  
               , @c_RefNo04       =  ''  
               , @c_RefNo05       =  ''  
               , @b_debug         =  '0'  
               , @c_LangCode      =  'ENG'   
               , @n_Func          =  0  
               , @b_Success       = @bSuccess  OUTPUT              
               , @n_ErrNo         = @nErrNo    OUTPUT            
               , @c_ErrMsg        = @cErrMSG   OUTPUT    

               IF @nErrNo <> 0
                  GOTO Fail
         
               -- Insert route for next station
               SET @nErrNo = 0
               EXEC [dbo].[ispWCSRO03]              
                  @c_StorerKey     =  @cStorerKey  
                  , @c_Facility      =  @cFacility           
                  , @c_ToteNo        =  @cDropID            
                  , @c_TaskType      =  'PTS'            
                  , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
                  , @c_TaskDetailKey =  ''  
                  , @c_Username      =  @cUserName  
                  , @c_RefNo01       =  @cPTLLOC         
                  , @c_RefNo02       =  ''  
                  , @c_RefNo03       =  ''  
                  , @c_RefNo04       =  ''  
                  , @c_RefNo05       =  ''  
                  , @b_debug         =  '0'  
                  , @c_LangCode      =  'ENG'   
                  , @n_Func          =  0          
                  , @b_Success       = @bSuccess OUTPUT              
                  , @n_ErrNo         = @nErrNo    OUTPUT            
                  , @c_ErrMsg        = @cErrMSG   OUTPUT    
            END
         END
      END
      ELSE
      BEGIN
         -- Short pack
         --IF CAST( @cInputValue AS INT) < CAST( @cDisplayValue AS INT) AND 
         --   @cDisplayValue <> 'FTOTE'
         IF @cType = 'SHORTTOTE'
         BEGIN
             SET @nCountTask = 0   

             SELECT @cQCStation = ISNULL(RTRIM(Short),'')   
             FROM dbo.CodeLkup WITH (NOLOCK)  
             WHERE Listname = 'WCSStation'   
             AND Code = 'QC01' 
    
             SELECT @nCountTask = Count(WCSKey)  
             FROM dbo.WCSRouting WITH (NOLOCK)   
             WHERE ToteNo = @cDropID   
             AND Final_Zone <> @cQCStation  
             AND Status = '0'  
             --AND TaskType = 'PTS' 

             IF ISNULL(@nCountTask,0 )  > 0   
             BEGIN  
                -- Update WCSRouting , WCSRoutingDetail  
                UPDATE dbo.WCSRoutingDetail  
                SET Status = '9'  
                WHERE ToteNo = @cDropID  
                AND Status = '0'  
                 
                IF @@ERROR <> 0  
                BEGIN  
                   SET @nErrNo = 166626    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetErr'     
                   GOTO Fail    
                END  
                  
                UPDATE dbo.WCSRouting  
                SET Status = '9'  
                WHERE ToteNo = @cDropID  
                AND Status = '0'  
                --AND TaskType = 'RPF'  
                 
                IF @@ERROR <> 0  
                BEGIN  
                   SET @nErrNo = 166627    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROErr'     
                   GOTO Fail    
                END  
            END
            
            -- Delete existing route
            SET @nErrNo = 0
            EXEC [dbo].[ispWCSRO03]              
               @c_StorerKey     =  @cStorerKey  
            , @c_Facility      =  @cFacility   
            , @c_ToteNo        =  @cDropID            
            , @c_TaskType      =  'PTS'            
            , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
            , @c_TaskDetailKey =  ''  
            , @c_Username      =  @cUserName  
            , @c_RefNo01       =  ''         
            , @c_RefNo02       =  ''  
            , @c_RefNo03       =  ''  
            , @c_RefNo04       =  ''  
            , @c_RefNo05       =  ''  
            , @b_debug         =  '0'  
            , @c_LangCode      =  'ENG'   
            , @n_Func          =  0  
            , @b_Success       = @bSuccess  OUTPUT              
            , @n_ErrNo         = @nErrNo    OUTPUT            
            , @c_ErrMsg        = @cErrMSG   OUTPUT    

            IF @nErrNo <> 0
               GOTO Fail

            SELECT @cPTLLOC = Short
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'WCSSTATION' 
            AND   Code = 'QC01'

            -- Insert route for next station
            SET @nErrNo = 0
            EXEC [dbo].[ispWCSRO03]              
               @c_StorerKey     =  @cStorerKey  
               , @c_Facility      =  @cFacility           
               , @c_ToteNo        =  @cDropID            
               , @c_TaskType      =  'PTS'            
               , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
               , @c_TaskDetailKey =  ''  
               , @c_Username      =  @cUserName  
               , @c_RefNo01       =  @cPTLLOC         
               , @c_RefNo02       =  ''  
               , @c_RefNo03       =  ''  
               , @c_RefNo04       =  ''  
               , @c_RefNo05       =  ''  
               , @b_debug         =  '0'  
               , @c_LangCode      =  'ENG'   
               , @n_Func          =  0          
               , @b_Success       = @bSuccess OUTPUT              
               , @n_ErrNo         = @nErrNo    OUTPUT            
               , @c_ErrMsg        = @cErrMSG   OUTPUT    
         END
         ELSE
         BEGIN
            SET @nCountTask = 0   

               SELECT @cQCStation = ISNULL(RTRIM(Short),'')   
               FROM dbo.CodeLkup WITH (NOLOCK)  
               WHERE Listname = 'WCSSation'   
               AND Code = 'QC01' 
    
               SELECT @nCountTask = Count(WCSKey)  
               FROM dbo.WCSRouting WITH (NOLOCK)   
               WHERE ToteNo = @cDropID   
               AND Final_Zone <> @cQCStation  
               AND Status = '0'  
               --AND TaskType = 'PTS' 

               IF ISNULL(@nCountTask,0 )  > 0   
               BEGIN  
                  -- Update WCSRouting , WCSRoutingDetail  
                  UPDATE dbo.WCSRoutingDetail  
                  SET Status = '9'  
                  WHERE ToteNo = @cDropID  
                  AND Status = '0'  
                 
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 166626    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetErr'     
                     GOTO Fail    
                  END  
                  
                  UPDATE dbo.WCSRouting  
                  SET Status = '9'  
                  WHERE ToteNo = @cDropID  
                  AND Status = '0'  
                  --AND TaskType = 'RPF'  
                 
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 166627    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROErr'     
                     GOTO Fail    
                  END  
               END
                
            -- the original ucc no more in pickdetail
            -- meaning no more residual, prompt empty box
            SET @nUCCQty = 0
            SELECT @nUCCQty = Qty
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cDropID
      
            SET @nPackQTY = 0
            SELECT @nPackQTY = ISNULL( SUM( Qty), 0)
            FROM PTL.PTLTRAN WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   DropID = @cDropID
            AND   Func = 805
            
            -- Check if ucc has residual
            SET @nResidualQty = @nUCCQty - @nPackQTY
      
            -- With residual, generate astrpt task
            IF @nResidualQty > 0
            BEGIN
               -- Delete existing route
               SET @nErrNo = 0
               EXEC [dbo].[ispWCSRO03]              
                 @c_StorerKey     =  @cStorerKey  
               , @c_Facility      =  @cFacility   
               , @c_ToteNo        =  @cDropID            
               , @c_TaskType      =  'PTS'            
               , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
               , @c_TaskDetailKey =  ''  
               , @c_Username      =  @cUserName  
               , @c_RefNo01       =  ''         
               , @c_RefNo02       =  ''  
               , @c_RefNo03       =  ''  
               , @c_RefNo04       =  ''  
               , @c_RefNo05       =  ''  
               , @b_debug         =  '0'  
               , @c_LangCode      =  'ENG'   
               , @n_Func          =  0  
               , @b_Success       = @bSuccess  OUTPUT              
               , @n_ErrNo         = @nErrNo    OUTPUT            
               , @c_ErrMsg        = @cErrMSG   OUTPUT    

               IF @nErrNo <> 0
                  GOTO Fail

               SELECT @cToLOC = ToLoc
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   TaskType = 'ASTRPT'
               AND   Caseid = @cDropID
               AND   WaveKey = @cWaveKey
               AND   SourceType = 'isp_805PTL_Confirm11'
               AND   [Status] = '0'
               
               -- Insert route for next station
               SET @nErrNo = 0
               EXEC [dbo].[ispWCSRO03]              
                  @c_StorerKey     =  @cStorerKey  
                  , @c_Facility      =  @cFacility           
                  , @c_ToteNo        =  @cDropID            
                  , @c_TaskType      =  'PTS'            
                  , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
                  , @c_TaskDetailKey =  ''  
                  , @c_Username      =  @cUserName  
                  , @c_RefNo01       =  @cToLOC         
                  , @c_RefNo02       =  ''  
                  , @c_RefNo03       =  ''  
                  , @c_RefNo04       =  ''  
                  , @c_RefNo05       =  ''  
                  , @b_debug         =  '0'  
                  , @c_LangCode      =  'ENG'   
                  , @n_Func          =  0          
                  , @b_Success       = @bSuccess OUTPUT              
                  , @n_ErrNo         = @nErrNo    OUTPUT            
                  , @c_ErrMsg        = @cErrMSG   OUTPUT    

               IF @nErrNo <> 0
                  GOTO Fail
            END
         END
      END
      /*
      -- Insert next station routing
      SELECT TOP 1 @cPTLLOC = LOC
      FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK) 
      WHERE WaveKey = @cWaveKey
      AND   Station > @cStation  -- Find next available PTL station
      ORDER BY 1
      
      IF @@ROWCOUNT = 1
      BEGIN
         -- Delete existing route
         SET @nErrNo = 0
         EXEC [dbo].[ispWCSRO03]              
            @c_StorerKey     =  @cStorerKey  
         , @c_Facility      =  @cFacility   
         , @c_ToteNo        =  @cDropID            
         , @c_TaskType      =  'PTS'            
         , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
         , @c_TaskDetailKey =  ''  
         , @c_Username      =  @cUserName  
         , @c_RefNo01       =  ''         
         , @c_RefNo02       =  ''  
         , @c_RefNo03       =  ''  
         , @c_RefNo04       =  ''  
         , @c_RefNo05       =  ''  
         , @b_debug         =  '0'  
         , @c_LangCode      =  'ENG'   
         , @n_Func          =  0  
         , @b_Success       = @bSuccess  OUTPUT              
         , @n_ErrNo         = @nErrNo    OUTPUT            
         , @c_ErrMsg        = @cErrMSG   OUTPUT    

         IF @nErrNo <> 0
            GOTO Fail

         -- Insert route for next station
         SET @nErrNo = 0
         EXEC [dbo].[ispWCSRO03]              
            @c_StorerKey     =  @cStorerKey  
            , @c_Facility      =  @cFacility           
            , @c_ToteNo        =  @cDropID            
            , @c_TaskType      =  'PTS'            
            , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
            , @c_TaskDetailKey =  ''  
            , @c_Username      =  @cUserName  
            , @c_RefNo01       =  @cPTLLOC         
            , @c_RefNo02       =  ''  
            , @c_RefNo03       =  ''  
            , @c_RefNo04       =  ''  
            , @c_RefNo05       =  ''  
            , @b_debug         =  '0'  
            , @c_LangCode      =  'ENG'   
            , @n_Func          =  0          
            , @b_Success       = @bSuccess OUTPUT              
            , @n_ErrNo         = @nErrNo    OUTPUT            
            , @c_ErrMsg        = @cErrMSG   OUTPUT    

         IF @nErrNo <> 0
            GOTO Fail
      END*/
   END
   
   Fail:


GO