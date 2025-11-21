SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: isp_808Confirm01                                    */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 24-06-2015 1.0  Ung      SOS316714 Created                           */  
/* 30-10-2015 1.1  Alan     Changes for new middleware                  */  
/************************************************************************/  
  
CREATE PROC [PTL].[isp_808Confirm01] (  
   @cDeviceIPAddress    NVARCHAR(30),     
   @cDevicePosition     NVARCHAR(20),       
   @cFuncKEY            NVARCHAR(2),  
   @nLghInSerialNo      BIGINT,  
   @cInputValue         NVARCHAR(20),     
   @nErrNo              INT           OUTPUT,  
   @cErrMsg             NVARCHAR(125) OUTPUT  
      
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cLangCode      NVARCHAR( 3)  
   DECLARE @nTranCount     INT  
   DECLARE @bSuccess       INT  
   DECLARE @nFunc          INT  
   DECLARE @nPOS           INT  
   DECLARE @nQTY           INT  
   DECLARE @nCase          INT  
   DECLARE @nPiece         INT  
   DECLARE @nCaseCnt       INT  
   DECLARE @nPTLKey        INT  
   DECLARE @nQTY_PTL       INT  
   DECLARE @nQTY_PD        INT  
   DECLARE @nQTY_Bal       INT  
   DECLARE @nExpectedQTY   INT  
   DECLARE @cCartID        NVARCHAR( 10)  
   DECLARE @cToteID        NVARCHAR( 20)  
   DECLARE @cSKU           NVARCHAR( 20)  
   DECLARE @cLOC           NVARCHAR( 10)  
   DECLARE @cType          NVARCHAR( 10)  
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @cLightMode     NVARCHAR( 4)  
            ,@c_ForceColor NVARCHAR(20)  
     
   DECLARE @cStorerKey     NVARCHAR(15)  --extract out  
   DECLARE @cDPLKey        NVARCHAR(10)  
  
   DECLARE @curPTL CURSOR  
   DECLARE @curPD  CURSOR  
  
   SET @nFunc = 808 -- RDT smart cart (rdt.rdtfnc_PTLCcart)  
   SET @nCaseCnt = 0  
   SET @nCase = 0  
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))  
  
   -- Get storer config  
   DECLARE @cUpdatePickDetail NVARCHAR(1)  
     
   SELECT TOP 1 @cStorerKey = StorerKey  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE IPAddress = @cDeviceIPAddress  
   AND   DevicePosition = @cDevicePosition  
   AND   Status = '1'  
     
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)  
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)  
     
  
   -- Decode QTY in CS-PCS format  
   SET @nPOS = CHARINDEX( '-', @cInputValue)  
   IF @nPOS > 0  
   BEGIN  
      SET @nCase = LEFT( @cInputValue, @nPOS-1)  
      SET @nPiece = SUBSTRING( @cInputValue, @nPOS+1, LEN( @cInputValue))  
   END  
   ELSE  
      SET @nPiece = @cInputValue  
  
   -- Get device profile info  
   DECLARE @cDeviceID NVARCHAR(20)  
   SELECT @cDeviceID = DeviceID  
   FROM dbo.DeviceProfile WITH (NOLOCK)    
   WHERE IPAddress = @cDeviceIPAddress  
      AND DevicePosition = @cDevicePosition  
      AND DeviceType = 'CART'  
     
   -- Get device profile  
   SELECT @cDPLKey = DeviceProfileLogKey  
   FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
   WHERE CartID = @cDeviceID  
  
   
  
   -- Get PTLTran info  
   SELECT TOP 1  
      @cLOC = LOC,  
      @cSKU = SKU,  
      @cOrderKey = OrderKey,  
      @cCartID = DeviceID  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE DeviceProfileLogKey = @cDPLKey  
      AND DevicePosition = @cDevicePosition  
      AND Status = '1' -- Lighted up  
  
   -- Get cart info  
   SELECT @cToteID = ToteID  
   FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
   WHERE CartID = @cCartID  
      AND Position = @cDevicePosition  
  
   -- Get SKU info  
   IF @nCase > 0  
   SELECT @nCaseCnt = CAST( CaseCnt AS INT)  
      FROM SKU WITH (NOLOCK)  
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cSKU  
  
   -- Calc QTY  
   SET @nQTY = @nCaseCnt * @nCase + @nPiece  
  
   -- Determine action  
   IF @nQTY = 0  
      SET @cType = 'SHORTTOTE'  
   ELSE  
      SET @cType = 'CLOSETOTE'  
  
   -- For calc balance  
   SET @nQTY_Bal = @nQTY  
     
   INSERT INTO TRACEINFO ( tracename , timein , col1 , col2 ,col3, col4,  col5 , step1, step2)   
   VALUES ( '808' , getdate() , @cStorerKey , @cDPLKey , @cDeviceID, @nPiece, @cType , @nQTY_Bal , '1')  
  
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN isp_808Confirm01 -- For rollback or commit only our own transaction  
  
/*  
insert into a (fld, val) values ('@cDPLKey', @cDPLKey)  
insert into a (fld, val) values ('@cDevicePosition', @cDevicePosition)  
insert into a (fld, val) values ('@cLOC', @cLOC)  
insert into a (fld, val) values ('@cSKU', @cSKU)  
insert into a (fld, val) values ('@nQTY', @nQTY)  
insert into a (fld, val) values ('@cCartID', @cCartID)  
*/  
  
   -- PTLTran  
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PTLKey, ExpectedQTY  
      FROM PTL.PTLTran WITH (NOLOCK)  
      WHERE DeviceProfileLogKey = @cDPLKey  
         AND DevicePosition = @cDevicePosition  
         AND LOC = @cLOC  
         AND SKU = @cSKU  
         AND Status <> '9'  
   OPEN @curPTL  
   FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @nExpectedQTY IS NULL  
         SET @nExpectedQTY = @nQTY_PTL  
  
INSERT INTO TRACEINFO ( tracename , timein , col1 , col2 ,col3, col4,  col5 , step1, step2)   
   VALUES ( '808' , getdate() , @cStorerKey , @cDPLKey , @cDeviceID, @nPiece, @nQTY_PTL , @nQTY_Bal , '2')  
     
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
            SET @nErrNo = 55151  
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
            SET @nErrNo = 55152  
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
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME(),  
               TrafficCop = NULL  
            WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 55153  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN -- Have balance, need to split  
            -- Create new a PTLTran to hold the balance  
              
                    INSERT INTO TRACEINFO ( tracename , timein , col1 , col2 ,col3, col4,  col5 , step1, step2)   
   VALUES ( '808' , getdate() , @cStorerKey , @cDPLKey , @cDeviceID, @nPiece, @nQTY_PTL , @nQTY_Bal , '3')  
     
            INSERT INTO PTL.PTLTran (  
               ExpectedQty, QTY, DropID, Status, LightUp, TrafficCop, --cut down message no.  
               IPAddress, DeviceID, DevicePosition, PTLType, OrderKey, Storerkey, SKU, LOC, LOT, Remarks,  
               DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightMode, LightSequence, UOM, RefPTLKey)  
            SELECT  
               @nQTY_PTL - @nQTY_Bal, 0, '', '0', '0', NULL,   
               IPAddress, DeviceID, DevicePosition, PTLType, OrderKey, Storerkey, SKU, LOC, LOT, Remarks,  
               DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightMode, LightSequence, UOM, RefPTLKey  
            FROM PTL.PTLTran WITH (NOLOCK)  
      WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
       SET @nErrNo = 55154  
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
               SET @nErrNo = 55155  
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
  
--select * from ptltran where deviceprofilelogkey = '0000000483'  
  
   -- PickDetail  
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
         SET @nErrNo = 55156  
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
            AND LOC = @cLOC  
            AND SKU = @cSKU  
            AND PD.Status < '4'  
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
               DropID = @cToteID,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 55157  
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
               DropID = @cToteID,  
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME()  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 55158  
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
                  SET @nErrNo = 55159  
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
                  SET @nErrNo = 55160  
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
          SET @nErrNo = 55161  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                  GOTO RollBackTran  
     END  
  
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
                  SET @nErrNo = 55162  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                  GOTO RollBackTran  
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
                  SET @nErrNo = 55163  
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
                  SET @nErrNo = 55164  
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
      IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'  
      BEGIN  
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PTLKey, ExpectedQTY, OrderKey  
            FROM PTL.PTLTran WITH (NOLOCK)  
            WHERE DeviceProfileLogKey = @cDPLKey  
               AND LOC = @cLOC  
               AND SKU = @cSKU  
               AND Status <> '9'  
  
         OPEN @curPTL  
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nExpectedQTY, @cOrderKey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            -- Confirm PTLTran  
            UPDATE PTL.PTLTran SET  
               Status = '9',  
               QTY = 0,  
               DropID = @cToteID,  
               EditWho = SUSER_SNAME(),  
               EditDate = GETDATE(),  
               TrafficCop = NULL  
            WHERE PTLKey = @nPTLKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 55165  
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
                  SET @nErrNo = 55166  
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
                     DropID = @cToteID,  
                     EditWho = SUSER_SNAME(),  
                     EditDate = GETDATE()  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 55167  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey  
               END  
            END  
  
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nExpectedQTY, @cOrderKey  
         END  
  
         -- Turn all Light off in cart  
         EXEC dbo.isp_DPC_TerminateAllLight  
             @cStorerKey  
            ,@cCartID  
            ,@bSuccess    OUTPUT  
            ,@nErrNo      OUTPUT  
            ,@cErrMsg     OUTPUT  
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
      WHERE DeviceProfileLogKey = @cDPLKey  
         AND DevicePosition = @cDevicePosition  
         AND SKU = @cSKU  
         AND LOC = @cLOC  
         AND Status = '0'  
           
--      SELECT @cDPLKey '@cDPLKey', @cDevicePosition '@cDevicePosition', @cSKU '@cSKU', @cLOC '@cLOC', @nExpectedQTY '@nExpectedQTY'  
           
      IF @nExpectedQTY > 0  
      BEGIN  
         DECLARE @cQTY NVARCHAR(20)  
         SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(20))  
--         EXEC [dbo].[isp_DPC_LightUpLoc]  
--            @c_StorerKey = @cStorerKey  
--           ,@n_PTLKey    = @nPTLKey  
--           ,@c_DeviceID  = @cCartID  
--           ,@c_DevicePos = @cDevicePosition  
--           ,@n_LModMode  = @cLightMode  
--           ,@n_Qty       = @cQTY  
--           ,@b_Success   = @bSuccess    OUTPUT  
--          ,@n_Err       = @nErrNo      OUTPUT  
--           ,@c_ErrMsg    = @cErrMsg     OUTPUT  
             
             
           EXEC [PTL].[isp_PTL_LightUpLoc]    
               @n_Func      = @nFunc   
              ,@n_PTLKey    = @nPTLKey    
              ,@c_DisplayValue = @cQTY    
              ,@b_Success   = @bSuccess    OUTPUT    
              ,@n_Err       = @nErrNo      OUTPUT    
              ,@c_ErrMsg    = @cErrMsg     OUTPUT    
              ,@c_ForceColor = @c_ForceColor  
  
             
             
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
   END  
  
   COMMIT TRAN isp_808Confirm01  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN isp_808Confirm01 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO