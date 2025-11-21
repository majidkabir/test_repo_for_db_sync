SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: isp_805PTL_Confirm04                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 27-06-2016 1.0  ChewKP   SOS#372370 Created                          */
/* 24-10-2016 1.2  ChewKP   Store PTL Loc in PackDetail.RefNo2(ChewKP02)*/
/* 04-11-2016 1.3  ChewKP   Light Up when Pick = Pack (ChewKP03)        */
/* 26-08-2019 1.4  YeeKung  Fix PD for the sku (yeekung01)					*/
/************************************************************************/

CREATE PROC [PTL].[isp_805PTL_Confirm04] (
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
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cDisplayValue  NVARCHAR( 5)
         , @cDropID        NVARCHAR(20)
         , @nSPErrNo       INT 
         , @cSPErrMSG      NVARCHAR(125) 
         , @cWaveKey       NVARCHAR(10)
         , @cPTLLoc        NVARCHAR(10) 
         , @nTTLPickedQty  INT   
         , @nTTLPackedQty  INT 

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   SET @nFunc = 805 -- PTL station (rdt.rdtfnc_PTLStation)
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))
   
   -- Get storer 
   DECLARE @cStorerKey NVARCHAR(15)
   SELECT TOP 1 
      @cStorerKey = StorerKey
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress 
      AND DevicePosition = @cPosition 
      AND LightUp = '1'
      
   -- Get display value
   SELECT @cDisplayValue = LEFT( DisplayValue, 5)
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition

   -- Get device profile info
   SELECT @cStation = DeviceID
   FROM dbo.DeviceProfile WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND DeviceType = 'STATION'
      AND DeviceID <> ''
      AND StorerKey = @cStorerKey 
   
   -- Check over put
   IF CAST( @cInputValue AS INT) > CAST( @cDisplayValue AS INT)
   BEGIN
      if @cDebug = '1'
         SELECT @cInputValue '@cInputValue', @cDisplayValue '@cDisplayValue'
      RAISERROR ('', 16, 1) WITH SETERROR -- Raise error to go to catch block
   END
   


   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   -- Get booking info
   SELECT 
      @nGroupKey = RowRef, 
      --@cOrderKey = OrderKey, 
      @cWaveKey = WaveKey, 
      @cCartonID = CartonID,
      @cPTLLoc   = Loc
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
   SAVE TRAN isp_805PTL_Confirm04 -- For rollback or commit only our own transaction

/*
insert into a (fld, val) values ('@cDPLKey', @cDPLKey)
insert into a (fld, val) values ('@cPosition', @cPosition)
insert into a (fld, val) values ('@cLOC', @cLOC)
insert into a (fld, val) values ('@cSKU', @cSKU)
insert into a (fld, val) values ('@nQTY', @nQTY)
insert into a (fld, val) values ('@cStation', @cStation)
*/

   -- PTLTran
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey, ExpectedQTY
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
         AND GroupKey = @nGroupKey
         AND SKU = @cSKU
         AND DropID = @cDropID 
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
            CaseID = @cCartonID,
            --MessageNum = @cMessageNum,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 101751
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
            SET @nErrNo = 101752
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
               SET @nErrNo = 101753
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
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_805PTL_Confirm04', ArchiveCop
            FROM PTL.PTLTran WITH (NOLOCK)
   			WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 101754
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
               SET @nErrNo = 101755
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
         JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey ) 
      WHERE PD.StorerKey = @cStorerKey 
         --AND O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status = '5'
         AND PD.QTY > 0
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.DropID = @cDropID
         AND PD.WaveKey = @cWaveKey 
         AND PD.CaseID = ''
         AND PTL.IPAddress = @cIPAddress
         AND PTL.Position = @cPosition
      
   
      
      IF @nQTY_PD <> @nExpectedQTY
      BEGIN
         SET @nErrNo = 101756
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
            JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON ( PTL.OrderKey = PD.OrderKey AND PTL.WaveKey = PD.WaveKey ) 
         WHERE PD.StorerKey = @cStorerKey 
            --AND O.OrderKey = @cOrderKey
            AND PD.SKU = @cSKU
            AND DropID = @cDropID
            AND PD.Status = '5'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.WaveKey = @cWaveKey 
            AND PD.CaseID = ''
            AND PTL.IPAddress = @cIPAddress
            AND PTL.Position = @cPosition
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN

        

         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            

            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               --Status = '5',
               CaseID = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101757
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
               --Status = '5',
               CaseID = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101758
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
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
                  --TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 101759
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
                  SET @nErrNo = 101760
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
      				SET @nErrNo = 101761
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
                     SET @nErrNo = 101762
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  CaseID = @cCartonID,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 101763
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END

               -- Confirm orginal PickDetail with exact QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  --Status = '5',
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 101764
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
      
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND CaseID = @cCartonID 
         
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
            
            SET @nErrNo = 101765
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END

      
      

      -- Get carton no
      SET @nCartonNo = 0
      SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID
      
      
      

      -- PackDetail
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID AND SKU = @cSKU)
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
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID, RefNo, RefNo2) -- (ChewKP02) 
         VALUES
            (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cCartonID, @cDropID, @cPTLLoc ) -- (ChewKP02) 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 101766
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
            AND LabelNo = @cCartonID
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 101767
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
         END
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
                  AND Status <> '9'
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 101768
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
                  GOTO RollBackTran
               END
            END
         END
      END
   END

   
   -- Release RDT.RDTPTLStationLog When Entire Wave is done Packing -- 
--   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
--                   WHERE StorerKey = @cStorerKey
--                   AND WaveKey = @cWaveKey
--                   AND CaseID = '' ) 
--   BEGIN
--      
--      DELETE FROM rdt.rdtPTLStationLog WITH (ROWLOCK) 
--      WHERE WaveKey = @cWaveKey
--      AND StorerKey = @cStorerKey 
--      
--      IF @@ERROR <> 0
--      BEGIN
--         SET @nErrNo = 101772
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReleaseStsFail
--         GOTO RollBackTran
--      END
--      
--   END 

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
               AND DropID = @cDropID
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
               SET @nErrNo = 101769
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
                  AND DropID = @cDropID
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
               IF @nQTY_PD <> @nExpectedQTY
               BEGIN
                  SET @nErrNo = 101770
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
                     AND DropID = @cDropID
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
                     --CaseID = @cCartonID,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 101771
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
         AND DropID = @cDropID
         
--      SELECT @cDPLKey '@cDPLKey', @cPosition '@cPosition', @cSKU '@cSKU', @cLOC '@cLOC', @nExpectedQTY '@nExpectedQTY'
         
      IF @nExpectedQTY > 0
      BEGIN
         DECLARE @cQTY NVARCHAR(10)
         SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(10))
         IF LEN( @cQTY) > 5
            SET @cQTY = '*'
         ELSE
            SET @cQTY = LEFT( @cQTY, 5)
         /*
         EXEC [dbo].[isp_DPC_LightUpLoc]
            @c_StorerKey = @cStorerKey
           ,@n_PTLKey    = @nPTLKey
           ,@c_DeviceID  = @cStation
           ,@c_DevicePos = @cPosition
           ,@n_LModMode  = @cLightMode
           ,@n_Qty       = @cQTY
           ,@b_Success   = @bSuccess    OUTPUT
           ,@n_Err       = @nErrNo      OUTPUT
           ,@c_ErrMsg    = @cErrMsg     OUTPUT
         */
         
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = @nPTLKey
           ,@c_DisplayValue   = @cQTY 
           ,@b_Success        = @bSuccess    OUTPUT    
           ,@n_Err            = @nErrNo      OUTPUT  
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos = @cPosition
           ,@c_DeviceIP       = @cIPAddress  
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END
   
   -- (ChewKP01) 
   -- IF Pick and Pack matched light up with END and Light Flash.
   SELECT @nTTLPickedQty = SUM(QTY) 
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND OrderKey = @cOrderKey 
   
   SELECT TOP 1 @nTTLPackedQty = SUM(QTY) 
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND PickSlipNo = @cPickSlipNo 
   
   
   IF ISNULL(@nTTLPickedQty,0)   = ISNULL(@nTTLPackedQty,0) 
   BEGIN
      -- RelightUp 
      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
        ,@n_PTLKey         = 0
        ,@c_DisplayValue   = 'END'
        ,@b_Success        = @bSuccess    OUTPUT    
        ,@n_Err            = @nErrNo      OUTPUT  
        ,@c_ErrMsg         = @cErrMsg     OUTPUT
        ,@c_DeviceID       = @cStation
        ,@c_DevicePos      = @cPosition
        ,@c_DeviceIP       = @cIPAddress  
        ,@c_LModMode       = '19'
        
   END
   

   COMMIT TRAN isp_805PTL_Confirm04
   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN isp_805PTL_Confirm04 -- Only rollback change made here
   
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
     ,@n_Err            = @nErrNo      OUTPUT  
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