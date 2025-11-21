SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_ToteIDSKU06                              */
/* Copyright      : LF Logistics                                                    */
/*                                                                                  */
/* Purpose: Close working batch                                                     */
/*                                                                                  */
/* Date       Rev Author      Purposes                                              */
/* 03-08-2021 1.0 yeekung     WMS-17625 Created                                     */
/* 22-05-2023 1.1 Ung         WMS-22553 Migrate to isp_Carrier_Middleware_Interface */
/************************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_Confirm_ToteIDSKU06] (
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
   DECLARE @ctransmitlogkey NVARCHAR(20)

   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   DECLARE @cUpdateTrackNo    NVARCHAR(1)
   DECLARE @cGenLabelNo_SP    NVARCHAR(20)
   DECLARE @cExternline NVARCHAR(20)
   DECLARE @nWeight     DECIMAL
   DECLARE @nCube       DECIMAL

   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
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
            SET @nErrNo = 173001
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
               SET @nErrNo = 173002
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
                  SET @nErrNo = 173003
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
                  SET @nErrNo = 173004
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
                     SET @nErrNo = 100404
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                     GOTO RollBackTran
                  END
               END

               IF @cLabelNo = ''
               BEGIN
                  SET @nErrNo = 173005
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                  GOTO RollBackTran
               END
            END


            
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                      WHERE PickSlipNo = @cPickSlipNo 
                           AND DropID = @cActCartonID 
                           AND SKU = @cSKU
                           AND QTY+@nExpectedQTY=@nQTY_PD
                           )
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
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate,RefNo2)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nExpectedQTY, @cActCartonID, 
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(),@cExternline)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 173006
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END 

               SELECT 
                     @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
                  AND DropID = @cActCartonID
               
               IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND cartonno=@nCartonNo)    
               BEGIN    
                  SELECT @nWeight=(sum(s.stdgrosswgt*(@nExpectedQTY))),
                         @nCube=sum(s.cube *@nExpectedQTY)
                  FROM sku s(NOLOCK)
                  WHERE s.sku=@cSKU
                  AND s.StorerKey=@cStorerKey

                  INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate,qty,cube,Weight)    
                  SELECT DISTINCT PH.PickSlipNo, @nCartonNo, 'CTN', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),@nExpectedQTY,@nCube,@nWeight   
                  FROM   PACKHEADER PH WITH (NOLOCK)      
                  WHERE  PH.Orderkey = @cOrderkey    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 152771    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'    
                     GOTO RollBackTran    
                  END    
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
                  AND refno2=@cExternline
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 173007
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
               END

               SELECT @nWeight=(sum(s.stdgrosswgt*(@nExpectedQTY))),
                        @nCube=sum(s.cube *@nExpectedQTY)
               FROM sku s(NOLOCK)
               WHERE s.sku=@cSKU
               AND s.StorerKey=@cStorerKey

            END

            IF @cAutoPackConfirm = '1'
            BEGIN
               -- No outstanding PickDetail
               IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status IN ('0','3'))
               BEGIN
                  SET @nPackQTY = 0
                  SET @nPickQTY = 0
                  SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
                  SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND  status<>'4'
      
                  IF @nPackQTY = @nPickQTY
                  BEGIN
                     /*
                     EXEC dbo.ispGenTransmitLog2  
                     'WSCRSOREQILS'  -- TableName  
                     , @cOrderKey   -- Key1  
                     , @cCartonID   -- Key2  
                     , @cStorerKey  -- Key3  
                     , ''           -- Batch  
                     , @bSuccess  OUTPUT  
                     , @nErrNo    OUTPUT  
                     , @cErrMsg   OUTPUT

                     IF @nErrNo <>''
                     BEGIN
                        GOTO RollBackTran
                     END

                     SELECT @ctransmitlogkey=transmitlogkey 
                     FROM dbo.TRANSMITLOG2 (NOLOCK)
                     WHERE key1=@cOrderKey
                     AND key2=@cCartonID
                     AND key3=@cStorerKey
                     AND tablename='WSCRSOREQILS'

                     EXEC isp_QCmd_WSTransmitLogInsertAlert 
                      ''
                      ,@ctransmitlogkey
                      ,@ctransmitlogkey
                      ,0 
                      ,0 
                      , @nErrNo    OUTPUT  
                      , @cErrMsg   OUTPUT

                      IF @nErrNo<>''
                        GOTO RollBackTran
                     */
                     
                     EXEC isp_Carrier_Middleware_Interface
                         @cOrderKey
                        ,''
                        ,@nFunc
                        ,@nCartonNo
                        ,@nStep
                        ,@bSuccess  OUTPUT
                        ,@nErrNo    OUTPUT
                        ,@cErrMsg   OUTPUT
                     IF @bSuccess = 0
                     BEGIN
                        SET @nErrNo = 173032
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
                        GOTO RollBackTran
                     END
                     
                     -- Pack confirm
                     UPDATE PackHeader WITH (ROWLOCK)
                     SET 
                        Status = '9' 
                     WHERE PickSlipNo = @cPickSlipNo
                        AND Status <> '9'
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 173008
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
                  SET @nErrNo = 173009
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
                  SET @nErrNo = 173010
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
                     SET @nErrNo = 173011
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
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'rdt_PTLStation_Confirm_ToteIDSKU06', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 173012
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
                     SET @nErrNo = 173013
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
               SET @nErrNo = 173014
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
                     SET @nErrNo = 173015
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
                     SET @nErrNo = 173016
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
                        SET @nErrNo = 173017
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
                        SET @nErrNo = 173018
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
            				SET @nErrNo = 173019
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
                        SET @nErrNo = 173020
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
                        SET @nErrNo = 173021
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
                        SET @nErrNo = 173022
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
                  SET @nErrNo = 173023
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
                     SET @nErrNo = 100404
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                     GOTO RollBackTran
                  END
               END

               -- Check label no
               IF @cLabelNo = ''
               BEGIN
                  SET @nErrNo = 173024
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                  GOTO RollBackTran
               END
            END
            -- PackDetail
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cCartonID AND SKU = @cSKU AND refno2=@cExternline)
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
                  SET @nErrNo = 173025
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
                  GOTO RollBackTran
               END     

               SELECT 
                  @nCartonNo = CartonNo, 
                  @cLabelNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 

               IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND cartonno=@nCartonNo)    
               BEGIN    
                  SELECT @nWeight=(sum(s.stdgrosswgt*(@nCartonQTY))),
                         @nCube=sum((s.cube *@nCartonQTY))
                  FROM sku s(NOLOCK)
                  WHERE s.sku=@cSKU
                  AND s.StorerKey=@cStorerKey

                  INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate,qty,Weight,Cube)    
                  SELECT DISTINCT PH.PickSlipNo, @nCartonNo, 'CTN', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),@nCartonQTY,@nWeight,@nCube   
                  FROM   PACKHEADER PH WITH (NOLOCK)      
                  WHERE  PH.Orderkey = @cOrderkey    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 152771    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'    
                     GOTO RollBackTran    
                  END    
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
                  SET @nErrNo = 173026
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
                  GOTO RollBackTran
               END

               SELECT @nWeight=(sum(s.stdgrosswgt*(@nCartonQTY))),
                        @nCube=sum(s.cube *@nCartonQTY)
               FROM sku s(NOLOCK)
               WHERE s.sku=@cSKU
               AND s.StorerKey=@cStorerKey
            END

            IF @cAutoPackConfirm = '1'
            BEGIN
               -- No outstanding PickDetail
               IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status IN ('0','3'))
               BEGIN
                  SET @nPackQTY = 0
                  SET @nPickQTY = 0
                  SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
                  SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND status<>'4'
      
                  IF @nPackQTY = @nPickQTY
                  BEGIN
                     /*
                     EXEC dbo.ispGenTransmitLog2  
                     'WSCRSOREQILS'  -- TableName  
                     , @cOrderKey   -- Key1  
                     , @cCartonID   -- Key2  
                     , @cStorerKey  -- Key3  
                     , ''           -- Batch  
                     , @bSuccess  OUTPUT  
                     , @nErrNo    OUTPUT  
                     , @cErrMsg   OUTPUT

                     IF @nErrNo <>''
                     BEGIN
                        GOTO RollBackTran
                     END

                     SELECT @ctransmitlogkey=transmitlogkey 
                     FROM dbo.TRANSMITLOG2 (NOLOCK)
                     WHERE key1=@cOrderKey
                     AND key2=@cCartonID
                     AND key3=@cStorerKey
                     AND tablename='WSCRSOREQILS'

                     EXEC isp_QCmd_WSTransmitLogInsertAlert 
                      ''
                      ,@ctransmitlogkey
                      ,@ctransmitlogkey
                      ,0 
                      ,0 
                      , @nErrNo    OUTPUT  
                      , @cErrMsg   OUTPUT

                      IF @nErrNo<>''
                        GOTO RollBackTran
                     */

                     EXEC isp_Carrier_Middleware_Interface
                         @cOrderKey
                        ,''
                        ,@nFunc
                        ,@nCartonNo
                        ,@nStep
                        ,@bSuccess  OUTPUT
                        ,@nErrNo    OUTPUT
                        ,@cErrMsg   OUTPUT
                     IF @bSuccess = 0
                     BEGIN
                        SET @nErrNo = 173033
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
                        GOTO RollBackTran
                     END

                     -- Pack confirm
                     UPDATE PackHeader SET 
                        Status = '9' 
                     WHERE PickSlipNo = @cPickSlipNo
                        AND Status <> '9'
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 173027
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
               SET @nErrNo = 173028
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
                  SET @nErrNo = 173029
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
                     SET @nErrNo = 173030
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
                        SET @nErrNo = 173031
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