SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_SEPWaveCriteria              */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-06-24 1.0  James       WMS-13639. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Confirm_SEPWaveCriteria] (
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
   DECLARE @cIPAddress     NVARCHAR( 40)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cConsigneeKey  NVARCHAR( 15)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)  
   DECLARE @cDropID        NVARCHAR( 20) = ''  
   DECLARE @cRefNo         NVARCHAR( 20) = ''  
   DECLARE @cRefNo2        NVARCHAR( 30) = ''  
   DECLARE @cUPC           NVARCHAR( 30) = ''  
   DECLARE @cDispatchPiecePickMethod   NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
  

   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR
   
   DECLARE @tOrders TABLE
   (
      OrderKey NVARCHAR(10) NOT NULL
   )

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)

   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)  
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE  
      SET @cPackDetailCartonID = ''  

   SELECT TOP 1 @cOrderKey = OrderKey
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND DropID = @cScanID
      AND SKU = @cSKU
      AND Status <> '9'
   ORDER BY 1

   SELECT @cWaveKey = UserDefine09
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
         
   SELECT @cDispatchPiecePickMethod = DispatchPiecePickMethod
   FROM dbo.Wave WITH (NOLOCK)
   WHERE WaveKey = @cWaveKey

   /***********************************************************************************************

                                                CONFIRM ID 

   ***********************************************************************************************/
   IF @cType = 'ID' 
   BEGIN
      -- Confirm entire ID
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, IPAddress, DevicePosition, OrderKey, ExpectedQTY
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DropID = @cScanID
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @cOrderKey, @nExpectedQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get carton
         SELECT @cActCartonID = CartonID
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
            SET @nErrNo = 157201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END

         -- PackDetail
         IF @cUpdatePackDetail = '1' AND @cDispatchPiecePickMethod = 'SEPB2BPTS'
         BEGIN
            -- Get LoadKey
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
            
            -- Get PickSlipNo
            SET @cPickSlipNo = ''
            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
            
            -- PackHeader
            IF @cPickSlipNo = ''
            BEGIN
               SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
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
               VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, '', '')
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
                  GOTO RollBackTran
               END
            END

            IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = @cActCartonID ELSE
            IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = @cActCartonID ELSE  
            IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = @cActCartonID  

            SET @nCartonNo = 0
            SET @cLabelNo = ''

            -- Get carton no
            SELECT 
               @nCartonNo = CartonNo, 
               @cLabelNo = LabelNo
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
               AND RefNo = @cActCartonID
            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo AND SKU = @cSKU)
            BEGIN
               -- Get next LabelLine
               IF @nCartonNo = 0
               BEGIN
                  SET @cLabelLine = ''
                  EXEC isp_GLBL08   
                     @c_PickSlipNo = @cPickSlipNo, 
                     @n_CartonNo   = @nCartonNo, 
                     @c_LabelNo    = @cLabelNo OUTPUT
                  IF @@ERROR <> 0
                     GOTO RollBackTran
               END
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo    
               
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
                  DropID, RefNo, RefNo2, UPC, AddWho, AddDate, EditWho, EditDate) 
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nExpectedQTY, 
                  @cDropID, @cActCartonID, @cRefNo2, @cUPC, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157203
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
                  AND LabelNo = @cLabelNo
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157204
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
               END
            END
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
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'
            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 157205
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
            BEGIN
               -- Loop PickDetail
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PickDetailKey
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND PD.DropID = @cScanID
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
                     Status = '5', 
                     CaseID = @cLabelNo, 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 157206
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
               
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END
            END
            ELSE
            BEGIN
               -- Loop PickDetail
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PickDetailKey
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND PD.DropID = @cScanID
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
                     Status = '5', 
                     CaseID = @cActCartonID, 
                     DropID = @cActCartonID,
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 157207
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
               
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END
            END
         END
         
         -- Commit order level
         COMMIT TRAN rdt_PTLStation_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @cOrderKey, @nExpectedQTY
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
            @cPosition = Position
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cCartonID

         SET @nExpectedQTY = NULL
         SET @nQTY_Bal = @nCartonQTY         

         -- PTLTran
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, OrderKey, ExpectedQTY            
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE IPAddress = @cIPAddress 
               AND DevicePosition = @cPosition
               AND DropID = @cScanID
               AND SKU = @cSKU
               AND Status <> '9'    
         OPEN @curPTL
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cOrderKey, @nQTY_PTL
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
                  SET @nErrNo = 157208
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
                  SET @nErrNo = 157209
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
                     SET @nErrNo = 157210
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
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'rdt_PTLStation_Confirm_SEPWaveCriteria', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 157211
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
                     SET @nErrNo = 157212
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END
            
            -- Get orders
            IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)
               INSERT INTO @tOrders (OrderKey) VALUES (@cOrderKey)
            
            -- Exit condition
            IF @cType = 'CLOSECARTON' AND @nQTY_Bal = 0
               BREAK
            
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cOrderKey, @nQTY_PTL
         END

         -- Get random one order (all orders should be have same load)
         SELECT TOP 1 @cOrderKey = OrderKey FROM @tOrders
                           
         -- PackDetail
         IF @cUpdatePackDetail = '1' AND @cDispatchPiecePickMethod = 'SEPB2BPTS'
         BEGIN
            -- Get random one order (all orders should be have same load)
            SELECT TOP 1 @cOrderKey = OrderKey FROM @tOrders
            
            -- Get LoadKey
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

            -- Get PickSlipNo
            SET @cPickSlipNo = ''
            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
            
            -- PackHeader
            IF @cPickSlipNo = ''
            BEGIN
               SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
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
               VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, '', '')
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157213
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
               AND RefNo = @cCartonID
            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo AND SKU = @cSKU)
            BEGIN
               -- Get next LabelLine
               IF @nCartonNo = 0
               BEGIN
                  SET @cLabelLine = ''
                  EXEC isp_GLBL08   
                     @c_PickSlipNo = @cPickSlipNo, 
                     @n_CartonNo   = @nCartonNo, 
                     @c_LabelNo    = @cLabelNo OUTPUT 
                  IF @@ERROR <> 0
                     GOTO RollBackTran 
               END
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo               
               
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, RefNo)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nCartonQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cCartonID)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157214
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
                  AND LabelNo = @cLabelNo
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 157215
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
               JOIN @tOrders t ON (t.OrderKey = O.OrderKey)
            WHERE PD.DropID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 157216
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- For calculation
            SET @nQTY_Bal = @nCartonQTY
            
            IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
            BEGIN
               -- Get PickDetail candidate
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT PickDetailKey, QTY
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     JOIN @tOrders t ON (t.OrderKey = O.OrderKey)
                  WHERE PD.DropID = @cScanID
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
                        CaseID = @cLabelNo, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 157217
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
                        CaseID = @cLabelNo, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 157218
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
                           -- CaseID = @cCartonID, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157219
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
                           SET @nErrNo = 157220
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
            				   SET @nErrNo = 157221
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                           GOTO RollBackTran
                        END
            
                        -- Get PickDetail info
                        DECLARE @cOrderLineNumber NVARCHAR( 5)
                        SELECT   
                           @cOrderLineNumber = OD.OrderLineNumber,   
                           @cLoadkey = O.Loadkey  
                        FROM dbo.PickDetail PD WITH (NOLOCK)   
                           INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
                           INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
                        WHERE PD.PickDetailkey = @cPickDetailKey 
                     
                        -- Get PickSlipNo
                        SET @cPickSlipNo = ''
                        SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
                        IF @cPickSlipNo = ''
                           SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
                     
                        -- Insert into 
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                        VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157222
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                           GOTO RollBackTran
                        END
                     
                        -- Change orginal PickDetail with exact QTY (with TrafficCop)
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           QTY = @nQTY_Bal, 
                           CaseID = @cLabelNo, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(), 
                           Trafficcop = NULL
                        WHERE PickDetailKey = @cPickDetailKey 
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157223
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
                           SET @nErrNo = 157224
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
            ELSE
            BEGIN            
               -- Get PickDetail candidate
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT PickDetailKey, QTY
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     JOIN @tOrders t ON (t.OrderKey = O.OrderKey)
                  WHERE PD.DropID = @cScanID
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
                        CaseID = @cActCartonID, 
                        DropID = @cActCartonID,
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 157225
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
                        DropID = @cActCartonID,
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 157226
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
                           -- CaseID = @cCartonID, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157227
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
                           SET @nErrNo = 157228
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
            				   SET @nErrNo = 157229
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                           GOTO RollBackTran
                        END
            
                        -- Get PickDetail info
                        SELECT   
                           @cOrderLineNumber = OD.OrderLineNumber,   
                           @cLoadkey = O.Loadkey  
                        FROM dbo.PickDetail PD WITH (NOLOCK)   
                           INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
                           INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
                        WHERE PD.PickDetailkey = @cPickDetailKey 
                     
                        -- Get PickSlipNo
                        SET @cPickSlipNo = ''
                        SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
                        IF @cPickSlipNo = ''
                           SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
                     
                        -- Insert into 
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                        VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157230
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                           GOTO RollBackTran
                        END
                     
                        -- Change orginal PickDetail with exact QTY (with TrafficCop)
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           QTY = @nQTY_Bal, 
                           CaseID = @cActCartonID, 
                           DropID = @cActCartonID,
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(), 
                           Trafficcop = NULL
                        WHERE PickDetailKey = @cPickDetailKey 
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 157231
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
                           SET @nErrNo = 157232
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
               SET @nErrNo = 157233
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
               SELECT PTLKey, IPAddress, DevicePosition, OrderKey, ExpectedQTY
               FROM PTL.PTLTran WITH (NOLOCK)
               WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND DropID = @cScanID
                  AND SKU = @cSKU
                  AND Status <> '9'
      
            OPEN @curPTL
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @cOrderKey, @nExpectedQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get carton
               SELECT 
                  @cActCartonID = CartonID
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
                  SET @nErrNo = 157234
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
                     AND PD.CaseID = ''
                     AND PD.QTY > 0
                     AND PD.Status <> '4'
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 157235
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
                        AND SKU = @cSKU
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
                        -- CaseID = @cActCartonID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 157236
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @cOrderKey, @nExpectedQTY
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