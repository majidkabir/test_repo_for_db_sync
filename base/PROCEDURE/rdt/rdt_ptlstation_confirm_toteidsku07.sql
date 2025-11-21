SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_ToteIDSKU07                        */
/* Copyright      : Maersk                                                    */
/* rdt_PTLStation_Confirm_ToteIDSKU ->rdt_PTLStation_Confirm_ToteIDSKU07      */
/*                                                                            */
/* Purpose: Close working batch                                               */
/*                                                                            */
/* Date       Rev Author      Purposes                                        */
/* 26-09-2024 1.0  yeekung    FCR-609 Created                                 */ 
/* 30-09-2024 1.1  yeekung    FCR-772 Created                                 */ 
/* 28-01-2025 1.2  yeekung    FCR-1442 Add format carton                      */
/******************************************************************************/

CREATE   PROC rdt.rdt_PTLStation_Confirm_ToteIDSKU07 (
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
   
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActCartonID   NVARCHAR( 20)
   DECLARE @cLabelNo       NVARCHAR( 20)
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

   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR

   DECLARE  @cLightMode     NVARCHAR( 4),   
            @cLight         NVARCHAR( 1),
            @cStation       NVARCHAR( 10),
            @cPTLKey		NVARCHAR( 10)	

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   DECLARE @cUpdateTrackNo    NVARCHAR(1)
   DECLARE @cGenLabelNo_SP    NVARCHAR(20)

   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   SET @cUpdateTrackNo = rdt.rdtGetConfig( @nFunc, 'UpdateTrackNo', @cStorerKey)
   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''

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
            SET @nErrNo = 224751
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
               SET @nErrNo = 224752
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
                  CaseID = @cActCartonID, 
                  DropID = @cActCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 224753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
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
                  SET @nErrNo = 224754
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
               AND DropID = @cActCartonID
            
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
                     SET @nErrNo = 224786
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                     GOTO RollBackTran
                  END
               END

               IF @cLabelNo = ''
               BEGIN
                  SET @nErrNo = 224787
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
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 224755
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail
                     GOTO RollBackTran
                  END 
               END
            END
            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cActCartonID AND SKU = @cSKU)
            BEGIN
               -- Get next LabelLine
               IF @nCartonNo = 0
                  SET @cLabelLine = ''
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND DropID = @cActCartonID    

               
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nExpectedQTY, @cActCartonID, 
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 224756
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
                  AND DropID = @cActCartonID
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 224757
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
                     ,@c_Key2             = @cActCartonID  
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
                        SET @nErrNo = 224758
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
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
                  SET @nErrNo = 224759
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
                  SET @nErrNo = 224760
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
                     SET @nErrNo = 224761
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
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'rdt_PTLStation_Confirm_ToteIDSKU07', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 224762
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
                     SET @nErrNo = 224763
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
               SET @nErrNo = 224764
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
                     CaseID = @cCartonID, 
                     DropID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 224765
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
                     CaseID = @cCartonID, 
                     DropID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 224766
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
                        CaseID = @cCartonID, 
                        DropID = @cCartonID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME()
                        --TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 224767
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
                        SET @nErrNo = 224768
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
            				SET @nErrNo = 224769
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
                        SET @nErrNo = 224770
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                        GOTO RollBackTran
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
                        SET @nErrNo = 224771
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
                        SET @nErrNo = 224772
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
                  SET @nErrNo = 224773
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
                     SET @nErrNo = 224788
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                     GOTO RollBackTran
                  END
               END

               -- Check label no
               IF @cLabelNo = ''
               BEGIN
                  SET @nErrNo = 224789
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
                     SET @nErrNo = 224774
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail
                     GOTO RollBackTran
                  END 
               END
            END
            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cCartonID AND SKU = @cSKU)
            BEGIN
               -- Get next LabelLine
               IF @nCartonNo = 0
                  SET @cLabelLine = ''
               ELSE
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND DropID = @cCartonID               
               
               -- Insert PackDetail
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nCartonQTY, @cCartonID, 
                   'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 224775
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
                  AND DropID = @cCartonID
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 224776
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
                        SET @nErrNo = 224777
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
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

         IF @cNewCartonID <> ''
         BEGIN   
            -- Check barcode format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cNewCartonID) = 0
            BEGIN
               SET @nErrNo = 224786
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format     
               GOTO Quit
            END

            IF EXISTS ( SELECT 1 FROM rdt.rdtPTLStationLog  (NOLOCK)
                        WHERE StorerKey = @cStorerKey  
                           AND CartonID = @cNewCartonID )  
            BEGIN
               SET @nErrNo = 224784 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAdyUsed
               GOTO Quit
            END         
            -- Check carton ID on hold
            IF EXISTS(  SELECT 1 FROM PICKDETAIL PD (NOLOCK)
                        WHERE caseid=@cNewCartonID
                           AND Storerkey=@cStorerKey
                           AND status < '9' )
            BEGIN
               SET @nErrNo = 224785
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAdyUsed
               GOTO Quit
            END

         END
           
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
               SET @nErrNo = 224778
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curLOG INTO @nRowRef
         END

         IF EXISTS ( SELECT 1
                     From dbo.StorerConfig (Nolock) 
               WHERE Configkey = 'Innobec'
                  AND Storerkey = @cStorerkey
                  And Svalue = '1'
            )
         BEGIN

            SELECT @cOrderkey = Orderkey 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE RowRef = @nRowRef

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

         SELECT @cLight  = V_String27
         FROM RDT.RDTMobrec (NOLOCK)
         WHERE Mobile = @nMobile

         IF @cLight = '1' 
         BEGIN

            SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey) 

            SELECT @cPosition   = Position
            FROM rdt.rdtPTLStationLog (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cNewCartonID
            
            SELECT   @cIPAddress = IPAddress,
                     @cPosition   = DevicePosition,
                     @nQTY        = ExpectedQty,
                     @cStation    = DeviceID,
					 @cPTLKey     = PTLKey
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DevicePosition = @cPosition
               AND LightUP = 0 
               AND Status = 0
			   AND Facility = @cFacility

            -- Off all lights  
            EXEC  PTL.isp_PTL_TerminateModuleSingle  
               @cStorerKey  
               ,@nFunc  
               ,@cStation 
               ,@cPosition  
               ,@bSuccess    OUTPUT  
               ,@nErrNo       OUTPUT  
               ,@cErrMsg      OUTPUT  
            IF @nErrNo <> 0  
               GOTO RollBackTran  

            EXEC PTL.isp_PTL_LightUpLoc
               @n_Func            = @nFunc
               ,@n_PTLKey         = @cPTLKey
               ,@c_DisplayValue   = @nQTY 
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
                  SET @nErrNo = 224779
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
                     SET @nErrNo = 224780
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
                        SET @nErrNo = 224781
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
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
                        ,@c_Key2             = @cActCartonID  
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