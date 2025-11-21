SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_SKUQTY_Order                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 15-11-2022 1.0  Ung         WMS-21024 Created                        */
/* 05-01-2023 1.1  Ung         Fix error no                             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_Confirm_SKUQTY_Order] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) -- ID=confirm ID, CLOSECARTON/SHORTCARTON = confirm carton
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cScanID      NVARCHAR( 20) 
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cCartonID    NVARCHAR( 20) = '' 
   ,@nCartonQTY   INT           = 0
   ,@cNewCartonID NVARCHAR( 20) = ''   -- For close carton with balance
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActCartonID   NVARCHAR( 20)
   DECLARE @cIPAddress     NVARCHAR( 40)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT
   DECLARE @cNewPickDetailKey NVARCHAR( 10)

   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)

   -- Get pick filter
   IF @cUpdatePickDetail = '1'
      SELECT @cPickFilter = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'PickFilter'
         AND Code = @nFunc 
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

   /***********************************************************************************************

                                                CONFIRM ID 

   ***********************************************************************************************/
   IF @cType = 'ID' 
   BEGIN
      -- Confirm entire ID
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
            @cActCartonID = CartonID, 
            @cOrderKey = OrderKey
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND IPAddress = @cIPAddress
            AND Position = @cPosition
         
         -- Transaction at order level
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction
         
         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9', 
            QTY = ExpectedQTY, 
            CaseID = @cActCartonID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 194951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END
         
         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Get PickDetail tally PTLTran
            SET @cSQL = 
               ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.CaseID = '''' ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' ' + 
                  CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam =
               ' @cOrderKey NVARCHAR( 10), ' + 
               ' @cSKU      NVARCHAR( 20), ' + 
               ' @nQTY_PD   INT OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cOrderKey, 
               @cSKU, 
               @nQTY_PD OUTPUT
            
            -- Check PickDetail changed
            IF @nQTY_PD < @nExpectedQTY
            BEGIN
               SET @nErrNo = 194952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END

            -- For calculation
            SET @nQTY_Bal = @nExpectedQTY

            -- Loop PickDetail
            SET @cSQL = 
               ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
                  ' SELECT PickDetailKey, QTY ' + 
                  ' FROM Orders O WITH (NOLOCK) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                     ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                  ' WHERE O.OrderKey = @cOrderKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.CaseID = '''' ' + 
                     ' AND PD.Status < ''4'' ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND O.Status <> ''CANC'' ' + 
                     ' AND O.SOStatus <> ''CANC'' ' + 
                     CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
               ' OPEN @curPD '
            SET @cSQLParam =
               ' @cOrderKey NVARCHAR( 10), ' + 
               ' @cSKU      NVARCHAR( 20), ' + 
               ' @curPD     CURSOR OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cOrderKey, 
               @cSKU, 
               @curPD OUTPUT

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     Status = '5',
                     CaseID = @cActCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194953
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
                     CaseID = @cActCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194954
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END
               
               -- PickDetail have more
         		ELSE IF @nQTY_PD > @nQTY_Bal
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
                     SET @nErrNo = 194955
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                     GOTO RollBackTran
                  END
         
                  -- Create new a PickDetail to hold the balance
                  INSERT INTO dbo.PickDetail (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,
                     PickDetailKey, 
                     QTY, 
                     TrafficCop,
                     OptimizeCop)
                  SELECT 
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
                     CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,
                     @cNewPickDetailKey, 
                     @nQTY_PD - @nQTY_Bal, -- QTY
                     NULL, -- TrafficCop
                     '1'   -- OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK) 
         			WHERE PickDetailKey = @cPickDetailKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 194956
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  -- Split RefKeyLookup
                  IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
                  BEGIN
                     -- Insert RefKeyLookup
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                     FROM RefKeyLookup WITH (NOLOCK) 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 194957
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                        GOTO RollBackTran
                     END
                  END
                  
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     QTY = @nQTY_Bal, 
                     CaseID = @cActCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME(), 
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey 
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194958
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
                     SET @nErrNo = 194959
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END

               -- Exit condition
               IF @nQTY_Bal = 0
                  BREAK

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
            END
            
            IF CURSOR_STATUS( 'variable', '@curPD') IN ( 0, 1)
               CLOSE @curPD
            IF CURSOR_STATUS( 'variable', '@curPD') = -1
               DEALLOCATE @curPD
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
               
               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
               VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194960
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
                  GOTO RollBackTran
               END
            END
            
            -- Get carton no
            SET @nCartonNo = 0
            SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cActCartonID
            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cActCartonID AND SKU = @cSKU)
            BEGIN
               -- Get next LabelLine
               IF @nCartonNo = 0
                  SET @cLabelLine = ''
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cActCartonID    
               
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cActCartonID, @cLabelLine, @cStorerKey, @cSKU, @nExpectedQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194961
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END     
            END
            ELSE
            BEGIN
               -- Update Packdetail
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
                  QTY = QTY + @nExpectedQTY, 
                  EditWho = 'rdt.' + SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  ArchiveCop = NULL
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cActCartonID
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194962
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
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
                        SET @nErrNo = 194963
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
                        GOTO RollBackTran
                     END
                  END
               END
            END
         END
         
         -- Commit order level
         COMMIT TRAN rdt_PTLStation_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
      END
   END


   /***********************************************************************************************

                                              CONFIRM CARTON 

   ***********************************************************************************************/
   -- Confirm carton
   IF @cType <> 'ID'
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction
      
      -- Close with QTY or short 
      IF (@cType = 'CLOSECARTON' AND @nCartonQTY > 0) OR
         (@cType = 'SHORTCARTON')
      BEGIN
         -- Get carton info
         SELECT 
            @cIPAddress = IPAddress, 
            @cPosition = Position, 
            @cOrderKey = OrderKey
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cCartonID

         SET @nExpectedQTY = NULL
         SET @nQTY_Bal = @nCartonQTY         

         -- PTLTran
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, ExpectedQTY            
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE IPAddress = @cIPAddress 
               AND DevicePosition = @cPosition
               AND SKU = @cSKU
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
                  CaseID = @cCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194964
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
                  CaseID = @cCartonID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194965
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END
      
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance
            END
            
            -- PTLTran have more
      		ELSE IF @nQTY_PTL > @nQTY_Bal
            BEGIN
               -- Short pick
               IF @cType = 'SHORTCARTON' AND @nQTY_Bal = 0 -- Don't need to split
               BEGIN
                  -- Confirm PTLTran
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     QTY = 0, 
                     CaseID = @cCartonID, 
                     TrafficCop = NULL, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194966
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
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'rdt_PTLStation_Confirm_SKUQTY_Order', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 194967
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail
                     GOTO RollBackTran
                  END
         
                  -- Confirm orginal PTLTran with exact QTY
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     ExpectedQty = @nQTY_Bal, 
                     QTY = @nQTY_Bal, 
                     CaseID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME(), 
                     Trafficcop = NULL
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194968
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END
            
            -- Exit condition
            IF @cType = 'CLOSECARTON' AND @nQTY_Bal = 0
               BREAK
            
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         END
               
         -- PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN            
            -- Get PickDetail tally PTLTran
            SET @cSQL = 
               ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.CaseID = '''' ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' ' + 
                  CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
            SET @cSQLParam =
               ' @cOrderKey NVARCHAR( 10), ' + 
               ' @cSKU      NVARCHAR( 20), ' + 
               ' @nQTY_PD   INT OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cOrderKey, 
               @cSKU, 
               @nQTY_PD OUTPUT

            IF @nQTY_PD < @nExpectedQTY
            BEGIN
               SET @nErrNo = 194969
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- For calculation
            SET @nQTY_Bal = @nCartonQTY
            
            -- Get PickDetail candidate
            SET @cSQL = 
               ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
                  ' SELECT PickDetailKey, QTY ' + 
                  ' FROM Orders O WITH (NOLOCK) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                     ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                  ' WHERE O.OrderKey = @cOrderKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.CaseID = '''' ' + 
                     ' AND PD.Status <> ''4'' ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND O.Status <> ''CANC'' ' + 
                     ' AND O.SOStatus <> ''CANC'' ' + 
                     CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
               ' OPEN @curPD '
            SET @cSQLParam =
               ' @cOrderKey NVARCHAR( 10), ' + 
               ' @cSKU      NVARCHAR( 20), ' + 
               ' @curPD     CURSOR OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cOrderKey, 
               @cSKU, 
               @curPD OUTPUT
               
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
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194970
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
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194971
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END
               
               -- PickDetail have more
         		ELSE IF @nQTY_PD > @nQTY_Bal
               BEGIN
                  -- Short pick
                  IF @cType = 'SHORTCARTON' AND @nQTY_Bal = 0 -- Don't need to split
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '4',
                        CaseID = @cCartonID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 194972
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN -- Have balance, need to split
         
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
                        SET @nErrNo = 194973
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                        GOTO RollBackTran
                     END
            
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,
                        PickDetailKey, 
                        QTY, 
                        TrafficCop,
                        OptimizeCop)
                     SELECT 
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,
                        @cNewPickDetailKey, 
                        @nQTY_PD - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK) 
            			WHERE PickDetailKey = @cPickDetailKey			            
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 194974
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Split RefKeyLookup
                     IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
                     BEGIN
                        -- Insert RefKeyLookup
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                        FROM RefKeyLookup WITH (NOLOCK) 
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 194975
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
                        SET @nErrNo = 194976
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
                        SET @nErrNo = 194977
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END
         
               -- Exit condition
               IF @cType = 'CLOSECARTON' AND @nQTY_Bal = 0
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
               
               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
               VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194978
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
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nCartonQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194979
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END     
            END
            ELSE
            BEGIN
               -- Update Packdetail
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
                  QTY = QTY + @nCartonQTY, 
                  EditWho = 'rdt.' + SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  ArchiveCop = NULL
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cCartonID
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194980
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
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
                        SET @nErrNo = 194981
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
                        GOTO RollBackTran
                     END
                  END
               END
            END
         END
      END

      -- Update new carton
      IF @cType = 'CLOSECARTON' AND @cNewCartonID <> ''
      BEGIN
         -- Loop current carton
         SET @curLOG = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cCartonID
         OPEN @curLOG
         FETCH NEXT FROM @curLOG INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Change carton on rdtPTLStationLog
            UPDATE rdt.rdtPTLStationLog SET
               CartonID = @cNewCartonID
            WHERE RowRef = @nRowRef 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 194982
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curLOG INTO @nRowRef
         END
      END
      
      -- Auto short all subsequence carton
      IF @cType = 'SHORTCARTON'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainCarton', @cStorerKey) = '1'
         BEGIN
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
                  @cActCartonID = CartonID, 
                  @cOrderKey= OrderKey
               FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
               WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND IPAddress = @cIPAddress
                  AND Position = @cPosition
               
               -- Confirm PTLTran
               UPDATE PTL.PTLTran SET
                  Status = '9', 
                  QTY = 0, 
                  CaseID = @cActCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 194983
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               
               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  -- Get PickDetail tally PTLTran
                  SET @cSQL = 
                     ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                        ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                     ' WHERE O.OrderKey = @cOrderKey ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.CaseID = '''' ' + 
                        ' AND PD.Status <> ''4'' ' + 
                        ' AND PD.QTY > 0 ' + 
                        ' AND O.Status <> ''CANC'' ' + 
                        ' AND O.SOStatus <> ''CANC'' ' + 
                        CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
                  SET @cSQLParam =
                     ' @cOrderKey NVARCHAR( 10), ' + 
                     ' @cSKU      NVARCHAR( 20), ' + 
                     ' @nQTY_PD   INT OUTPUT '
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @cOrderKey, 
                     @cSKU, 
                     @nQTY_PD OUTPUT
                     
                  IF @nQTY_PD < @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 194984
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  SET @cSQL = 
                     ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
                        ' SELECT PickDetailKey, QTY ' + 
                        ' FROM Orders O WITH (NOLOCK) ' + 
                           ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                           ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                        ' WHERE O.OrderKey = @cOrderKey ' + 
                           ' AND PD.SKU = @cSKU ' + 
                           ' AND PD.CaseID = '''' ' + 
                           ' AND PD.Status <> ''4'' ' + 
                           ' AND PD.QTY > 0 ' + 
                           ' AND O.Status <> ''CANC'' ' + 
                           ' AND O.SOStatus <> ''CANC'' ' + 
                           CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
                     ' OPEN @curPD '
                  SET @cSQLParam =
                     ' @cOrderKey NVARCHAR( 10), ' + 
                     ' @cSKU      NVARCHAR( 20), ' + 
                     ' @curPD     CURSOR OUTPUT  '
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @cOrderKey, 
                     @cSKU, 
                     @curPD OUTPUT
               
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE PickDetail SET
                        Status = '4', 
                        CaseID = @cActCartonID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 194985
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
                  
                  IF CURSOR_STATUS( 'variable', '@curPD') IN ( 0, 1)
                     CLOSE @curPD
                  IF CURSOR_STATUS( 'variable', '@curPD') = -1
                     DEALLOCATE @curPD
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
            END
         END
      END

      COMMIT TRAN rdt_PTLStation_Confirm
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO