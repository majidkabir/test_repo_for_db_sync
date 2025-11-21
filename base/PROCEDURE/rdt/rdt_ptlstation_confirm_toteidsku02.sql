SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_ToteIDSKU02                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Close working batch                                               */
/*                                                                            */
/* Date       Rev Author      Purposes                                        */
/* 15-12-2017 1.0 ChewKP      WMS-3487 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Confirm_ToteIDSKU02] (
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
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActCartonID   NVARCHAR( 20)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT
   DECLARE @cPackDetailDropID NVARCHAR(20)
   DECLARE @cTrackNo       NVARCHAR( 20)
   DECLARE @cNotes         NVARCHAR( 30)
   DECLARE @cUserDefine03  NVARCHAR( 20)
          ,@cPairStation   NVARCHAR( 10) 

   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   DECLARE @cUpdateTrackNo    NVARCHAR(1)
   DECLARE @cUpdatePackDetailDropID NVARCHAR(1)
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction

   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   --SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   --SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   --SET @cUpdateTrackNo = rdt.rdtGetConfig( @nFunc, 'UpdateTrackNo', @cStorerKey)
   --SET @cUpdatePackDetailDropID = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetailDropID', @cStorerKey)

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
            AND DropID = @cScanID
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
         --SET @nTranCount = @@TRANCOUNT
         --BEGIN TRAN  -- Begin our own transaction
         --SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction
         
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
            SET @nErrNo = 118201
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
               AND PD.DropID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.Status <> '4'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 118202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.DropID = @cScanID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  Status = '5', 
                  CaseID = 'SORTED', 
                  DropID = @cActCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
         
--         -- PackDetail
--         IF @cUpdatePackDetail = '1'
--         BEGIN
--            -- Get PickSlipNo
--            SET @cPickSlipNo = ''
--            SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--            
--            -- PackHeader
--            IF @cPickSlipNo = ''
--            BEGIN
--               SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--               IF @cPickSlipNo = ''
--               BEGIN
--                  -- Generate PickSlipNo
--                  EXECUTE dbo.nspg_GetKey
--                     'PICKSLIP',
--                     9,
--                     @cPickslipNo   OUTPUT,
--                     @bSuccess      OUTPUT,
--                     @nErrNo        OUTPUT,
--                     @cErrMsg       OUTPUT  
--                  IF @nErrNo <> 0
--                     GOTO RollBackTran
--         
--                  SET @cPickslipNo = 'P' + @cPickslipNo
--               END
--               
--               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
--               VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118204
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
--                  GOTO RollBackTran
--               END
--            END
--            
--            -- Get carton no
--            SET @nCartonNo = 0
--            SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cActCartonID
--            
--            -- New carton
--            IF @nCartonNo = 0
--            BEGIN
--               -- Grap a track no
--               IF @cUpdateTrackNo = '1'
--               BEGIN
--                  -- Get order info
--                  SELECT @cUserDefine03 = UserDefine03 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--                  
--                  -- Get code lookup info
--                  SELECT TOP 1 
--                     @cNotes = LEFT( ISNULL( Notes, ''), 30)
--                  FROM CodeLKUP WITH (NOLOCK) 
--                  WHERE ListName = 'LOTTELBL' 
--                     AND Short = @cUserDefine03 
--                     AND StorerKey = @cStorerKey
--                  
--                  -- Get track no
--                  SELECT TOP 1 
--                     @nRowRef = RowRef, 
--                     @cTrackNo = TrackingNo
--                  FROM CartonTrack WITH (NOLOCK)
--                  WHERE KeyName = @cNotes
--                     AND CarrierRef2 <> 'GET'
--                  ORDER BY RowRef
--                  
--                  -- Stamp track no used
--                  UPDATE CartonTrack SET 
--                     CarrierRef2 = 'GET', 
--                     LabelNo = @cActCartonID
--                  WHERE RowRef = @nRowRef
--                  IF @@ERROR <> 0
--                  BEGIN
--                     SET @nErrNo = 118205
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail
--                     GOTO RollBackTran
--                  END 
--               END
--            END
--            
--            -- PackDetail
--            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cActCartonID AND SKU = @cSKU)
--            BEGIN
--               -- Get next LabelLine
--               IF @nCartonNo = 0
--                  SET @cLabelLine = ''
--               ELSE
--                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
--                  FROM dbo.PackDetail (NOLOCK)
--                  WHERE Pickslipno = @cPickSlipNo
--                     AND CartonNo = @nCartonNo
--                     AND LabelNo = @cActCartonID    
--
--               IF @cUpdatePackDetailDropID = '1' 
--                  SET @cPackDetailDropID = @cActCartonID 
--               ELSE 
--                  SET @cPackDetailDropID = ''
--               
--               -- Insert PackDetail
--               INSERT INTO dbo.PackDetail
--                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
--               VALUES
--                  (@cPickSlipNo, @nCartonNo, @cActCartonID, @cLabelLine, @cStorerKey, @cSKU, @nExpectedQTY, @cPackDetailDropID, 
--                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118206
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
--                  GOTO RollBackTran
--               END     
--            END
--            ELSE
--            BEGIN
--               -- Update Packdetail
--               UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
--                  QTY = QTY + @nExpectedQTY, 
--                  EditWho = 'rdt.' + SUSER_SNAME(), 
--                  EditDate = GETDATE(), 
--                  ArchiveCop = NULL
--               WHERE PickSlipNo = @cPickSlipNo
--                  AND CartonNo = @nCartonNo
--                  AND LabelNo = @cActCartonID
--                  AND SKU = @cSKU
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118207
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
--                  GOTO RollBackTran
--               END
--            END
--
--            IF @cAutoPackConfirm = '1'
--            BEGIN
--               -- No outstanding PickDetail
--               IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')
--               BEGIN
--                  SET @nPackQTY = 0
--                  SET @nPickQTY = 0
--                  SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
--                  SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--      
--                  IF @nPackQTY = @nPickQTY
--                  BEGIN
--                     -- Pack confirm
--                     UPDATE PackHeader SET 
--                        Status = '9' 
--                     WHERE PickSlipNo = @cPickSlipNo
--                        AND Status <> '9'
--                     IF @@ERROR <> 0
--                     BEGIN
--                        SET @nErrNo = 118208
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
--                        GOTO RollBackTran
--                     END
--                  END
--               END
--            END
--         END
         
         -- Commit order level
         --COMMIT TRAN rdt_PTLStation_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_PTLStation_Confirm
         
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
      --SET @nTranCount = @@TRANCOUNT
      --BEGIN TRAN  -- Begin our own transaction
      --SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction
      
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
               AND DropID = @cScanID
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
                  SET @nErrNo = 118209
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
                  SET @nErrNo = 118210
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
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
                     SET @nErrNo = 118211
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
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
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'rdt_PTLStation_Confirm_ToteIDSKU02', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 118212
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PTL Fail
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
                     SET @nErrNo = 118213
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
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
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE O.OrderKey = @cOrderKey
               AND PD.DropID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.Status <> '4'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 118214
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- For calculation
            SET @nQTY_Bal = @nCartonQTY
         
            -- Get PickDetail candidate
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT PickDetailKey, QTY
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.DropID = @cScanID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.CaseID = ''
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
                     CaseID = 'SORTED', 
                     DropID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 118215
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
                     CaseID = 'SORTED', 
                     DropID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 118216
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
                        CaseID = 'SORTED', 
                        DropID = @cCartonID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME()
                        --TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 118217
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
                        SET @nErrNo = 118218
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
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
            				SET @nErrNo = 118219
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
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
                     SET @cPickSlipNo = ''
                     SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
                     IF @cPickSlipNo = ''
                        SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
                     
                     -- Insert into 
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 118220
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                        GOTO RollBackTran
                     END
                     
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        QTY = @nQTY_Bal, 
                        CaseID = 'SORTED', 
                        DropID = @cCartonID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(), 
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey 
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 118221
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
                        SET @nErrNo = 118222
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
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
--         IF @cUpdatePackDetail = '1'
--         BEGIN
--            -- Get PickSlipNo
--            SET @cPickSlipNo = ''
--            SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--            
--            -- PackHeader
--            IF @cPickSlipNo = ''
--            BEGIN
--               SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--               IF @cPickSlipNo = ''
--               BEGIN
--                  -- Generate PickSlipNo
--                  EXECUTE dbo.nspg_GetKey
--                     'PICKSLIP',
--                     9,
--                     @cPickslipNo   OUTPUT,
--                     @bSuccess      OUTPUT,
--                     @nErrNo        OUTPUT,
--                     @cErrMsg       OUTPUT  
--                  IF @nErrNo <> 0
--                     GOTO RollBackTran
--         
--                  SET @cPickslipNo = 'P' + @cPickslipNo
--               END
--               
--               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
--               VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118223
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
--                  GOTO RollBackTran
--               END
--            END
--            
--            -- Get carton no
--            SET @nCartonNo = 0
--            SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID
--
--            -- New carton
--            IF @nCartonNo = 0
--            BEGIN
--               -- Grap a track no
--               IF @cUpdateTrackNo = '1'
--               BEGIN
--                  -- Get order info
--                  SELECT @cUserDefine03 = UserDefine03 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--                  
--                  -- Get code lookup info
--                  SELECT TOP 1 
--                     @cNotes = LEFT( ISNULL( Notes, ''), 30)
--                  FROM CodeLKUP WITH (NOLOCK) 
--                  WHERE ListName = 'LOTTELBL' 
--                     AND Short = @cUserDefine03
--                     AND StorerKey = @cStorerKey
--                  
--                  -- Get track no
--                  SELECT TOP 1 
--                     @nRowRef = RowRef, 
--                     @cTrackNo = TrackingNo
--                  FROM CartonTrack WITH (NOLOCK)
--                  WHERE KeyName = @cNotes
--                     AND CarrierRef2 <> 'GET'
--                  ORDER BY RowRef
--                  
--                  -- Stamp track no used
--                  UPDATE CartonTrack SET 
--                     CarrierRef2 = 'GET', 
--                     LabelNo = @cCartonID
--                  WHERE RowRef = @nRowRef
--                  IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
--                  BEGIN
--                     SET @nErrNo = 118224
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail
--                     GOTO RollBackTran
--                  END 
--               END
--            END
--            
--            -- PackDetail
--            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID AND SKU = @cSKU)
--            BEGIN
--               -- Get next LabelLine
--               IF @nCartonNo = 0
--                  SET @cLabelLine = ''
--               ELSE
--                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
--                  FROM dbo.PackDetail (NOLOCK)
--                  WHERE Pickslipno = @cPickSlipNo
--                     AND CartonNo = @nCartonNo
--                     AND LabelNo = @cCartonID               
--
--               IF @cUpdatePackDetailDropID = '1' 
--                  SET @cPackDetailDropID = @cCartonID 
--               ELSE 
--                  SET @cPackDetailDropID = ''
--               
--               -- Insert PackDetail
--               INSERT INTO dbo.PackDetail
--                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
--               VALUES
--                  (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nCartonQTY, @cPackDetailDropID, 
--                   'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118225
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
--                  GOTO RollBackTran
--               END     
--            END
--            ELSE
--            BEGIN
--               -- Update Packdetail
--               UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
--                  QTY = QTY + @nCartonQTY, 
--                  EditWho = 'rdt.' + SUSER_SNAME(), 
--                  EditDate = GETDATE(), 
--                  ArchiveCop = NULL
--               WHERE PickSlipNo = @cPickSlipNo
--                  AND CartonNo = @nCartonNo
--                  AND LabelNo = @cCartonID
--                  AND SKU = @cSKU
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118226
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
--                  GOTO RollBackTran
--               END
--            END
--
--            IF @cAutoPackConfirm = '1'
--            BEGIN
--               -- No outstanding PickDetail
--               IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')
--               BEGIN
--                  SET @nPackQTY = 0
--                  SET @nPickQTY = 0
--                  SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
--                  SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--      
--                  IF @nPackQTY = @nPickQTY
--                  BEGIN
--                     -- Pack confirm
--                     UPDATE PackHeader SET 
--                        Status = '9' 
--                     WHERE PickSlipNo = @cPickSlipNo
--                        AND Status <> '9'
--                     IF @@ERROR <> 0
--                     BEGIN
--                        SET @nErrNo = 118227
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
--                        GOTO RollBackTran
--                     END
--                  END
--               END
--            END
--         END
      END

      -- Update new carton
      IF @cType = 'CLOSECARTON' AND @cNewCartonID <> ''
      BEGIN
         -- Loop current carton
         SELECT @cPairStation = Short 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'NIKEPTL'
         AND StorerKey = @cStorerKey 
         
         IF @cPairStation = ''
         BEGIN
            SET @curLOG = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cCartonID
            ORDER BY RowRef   
         END
         ELSE
         BEGIN
            SET @curLOG = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cPairStation)
               AND CartonID = @cCartonID
            ORDER BY RowRef
         END
         
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
               SET @nErrNo = 118228
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
                  AND DropID = @cScanID
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
                  SET @nErrNo = 118229
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
                     AND PD.DropID = @cScanID
                     AND PD.SKU = @cSKU
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'
                     AND PD.CaseID = ''
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 118230
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM Orders O WITH (NOLOCK) 
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.OrderKey = @cOrderKey
                        AND PD.DropID = @cScanID
                        AND PD.SKU = @cSKU
                        AND PD.Status <= '5'
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
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
                        --CaseID = @cActCartonID, 
                        DropID = @cActCartonID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 118231
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
            END
         END
      END

      --COMMIT TRAN rdt_PTLStation_Confirm
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_PTLStation_Confirm
END


GO