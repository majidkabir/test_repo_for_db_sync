SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO




/*****************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Order10                             */
/* Copyright      : LF Logistics                                             */
/*                                                                           */
/* Purpose: Confirm by order                                                 */
/*                                                                           */
/* Date       Rev  Author     Purposes                                       */
/* 07-10-2021 1.0  yeekung    WMS-17823 Created                              */
/* 20-01-2022 1.1  Calvin     JSM-46277 ChongHwang Bug Fix (CLVN01)          */
/* 11-05-2022 1.2  Calvin     Add ChannelID to PickDetail Insertion (CLVN02) */
/*****************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Confirm_Order10] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess          INT
   DECLARE @nTranCount        INT
   DECLARE @nQTY_PD           INT
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)

   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cCartonID         NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cLoadkey          NVARCHAR( 10)
   DECLARE @cLightMode        NVARCHAR( 4)
   DECLARE @cDisplay          NVARCHAR( 5)
   DECLARE @cDynamicSlot      NVARCHAR( 1)
   DECLARE @cUpdateCaseID     NVARCHAR( 1)
   DECLARE @cUpdateStatus     NVARCHAR( 1)
   DECLARE @cAutoScanOut      NVARCHAR( 1)
   DECLARE @cInsertDropIDSP   NVARCHAR( 20)

   SET @cDisplay = '' 

   -- Get assign info
   SET @cWaveKey = ''
   SELECT @cWaveKey = WaveKey FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation 
   IF @cWaveKey = ''
      SELECT @cWaveKey = V_WaveKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Storer configure
   SET @cAutoScanOut = rdt.RDTGetConfig( @nFunc, 'AutoScanOut', @cStorerKey)
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)
   SET @cUpdateCaseID = rdt.RDTGetConfig( @nFunc, 'UpdateCaseID', @cStorerKey)

   SET @cInsertDropIDSP = rdt.RDTGetConfig( @nFunc, 'InsertDropIDSP', @cStorerKey)
   IF @cInsertDropIDSP = '0'
      SET @cInsertDropIDSP = ''
   SET @cUpdateStatus = rdt.RDTGetConfig( @nFunc, 'UpdateStatus', @cStorerKey)
   IF @cUpdateStatus NOT IN ('0', '3', '5')
      SET @cUpdateStatus = '0'

   -- Find PickDetail to offset
   SET @cOrderKey = ''
   SELECT TOP 1 
      @cOrderKey = O.OrderKey, 
      @cPickDetailKey = PD.PickDetailKey, 
      @nQTY_PD = QTY
   FROM WaveDetail WD WITH (NOLOCK)
      JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
    LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.WaveKey = @cWaveKey AND L.Station = @cStation)
   WHERE WD.WaveKey = @cWaveKey
      AND PD.SKU = @cSKU
      AND PD.Status <='5'
      AND PD.CaseID = ''
      AND PD.QTY > 0
      AND PD.Status NOT IN ('4','0')
      AND O.Status <> 'CANC' 
      AND O.SOStatus <> 'CANC'
   ORDER BY L.RowRef DESC-- Match order with position first					--(CLVN01)

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 176951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
      GOTO Quit
   END

   -- Get assign info
   SET @cCartonID = ''
   SET @cIPAddress = ''
   SET @cPosition = ''
   SELECT 
      @cCartonID = CartonID, 
      @cIPAddress = IPAddress, 
      @cPosition = Position
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation 
      AND OrderKey = @cOrderKey


   -- Dynamic assign slot
   IF @cDynamicSlot = '1'
   BEGIN
      -- Assign order
      IF @cPosition = ''
      BEGIN
         -- Get position not yet assign
         SELECT TOP 1
            @cIPAddress = DP.IPAddress, 
            @cPosition = DP.DevicePosition
         FROM dbo.DeviceProfile DP WITH (NOLOCK)
         WHERE DP.DeviceType = 'STATION'
            AND DP.DeviceID = @cStation
            AND NOT EXISTS( SELECT 1
               FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
               WHERE Log.Station = @cStation
                  AND Log.Position = DP.DevicePosition)
         ORDER BY DP.LogicalPos, DP.DevicePosition
         
         -- Check position available
         IF @cPosition = ''
         BEGIN
            SET @nErrNo = 176952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPos4NewOrder
            GOTO Quit
         END
         
         -- Save assign
         INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, WaveKey, OrderKey, CartonID)
         VALUES (@cStation, @cIPAddress, @cPosition, @cWaveKey, @cOrderKey, '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 176953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log fail
            GOTO Quit
         END
      END
      
      -- Assign carton ID 
      IF @cCartonID = ''
      BEGIN
         IF @cLight = '1'
         BEGIN
            -- Get light setting
            SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
      
            -- Off all lights
            EXEC PTL.isp_PTL_TerminateModule
                @cStorerKey
               ,@nFunc
               ,@cStation
               ,'STATION'
               ,@bSuccess    OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
   
            EXEC PTL.isp_PTL_LightUpLoc
               @n_Func           = @nFunc
              ,@n_PTLKey         = 0
              ,@c_DisplayValue   = 'TOTE' 
              ,@b_Success        = @bSuccess    OUTPUT    
              ,@n_Err            = @nErrNo      OUTPUT  
              ,@c_ErrMsg         = @cErrMsg     OUTPUT
              ,@c_DeviceID       = @cStation
              ,@c_DevicePos      = @cPosition
              ,@c_DeviceIP       = @cIPAddress  
              ,@c_LModMode       = @cLightMode
            IF @nErrNo <> 0
               GOTO Quit
         END
         
         SET @nErrNo = 176954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Assign Carton
         SET @nErrNo = 0
         GOTO Quit
      END
   END

   /***********************************************************************************************

                                              CONFIRM ORDER

   ***********************************************************************************************/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction
        
   -- Exact match
   IF @nQTY_PD = 1
   BEGIN
      -- Confirm PickDetail
      IF @cUpdateStatus = '0'
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            CaseID = CASE WHEN @cUpdateCaseID =  '1' THEN 'SORTED' ELSE CaseID END, 
            DropID = @cCartonID, 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey

      ELSE IF @cUpdateStatus = '5'
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = '5', 
            CaseID = CASE WHEN @cUpdateCaseID =  '1' THEN 'SORTED' ELSE CaseID END, 
            DropID = @cCartonID, 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
      
      ELSE
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = @cUpdateStatus, 
            CaseID = CASE WHEN @cUpdateCaseID =  '1' THEN 'SORTED' ELSE CaseID END, 
            DropID = @cCartonID, 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
   END
      
   -- PickDetail have more
	ELSE IF @nQTY_PD > 1
   BEGIN
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
         SET @nErrNo = 176956
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
         OptimizeCop,
		 Channel_ID)				--(CLVN02)
      SELECT 
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
         CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         @cNewPickDetailKey, 
         @nQTY_PD - 1, -- QTY
         NULL, -- TrafficCop
         '1',   -- OptimizeCop
		 Channel_ID					--(CLVN02)
      FROM dbo.PickDetail WITH (NOLOCK) 
		WHERE PickDetailKey = @cPickDetailKey			            
      IF @@ERROR <> 0
      BEGIN
			SET @nErrNo = 176957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
         GOTO RollBackTran
      END

      -- Check RefKeyLookup
      IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
      BEGIN
         -- Insert RefKeyLookup
         INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)
         SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
         FROM RefKeyLookup WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 176958
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
            GOTO RollBackTran
         END
      END
      
      -- Change orginal PickDetail with exact QTY (with TrafficCop)
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         QTY = 1, 
         CaseID = CASE WHEN @cUpdateCaseID = '1' THEN 'SORTED' ELSE CaseID END, 
         DropID = @cCartonID, 
         EditDate = GETDATE(), 
         EditWho  = SUSER_SNAME(), 
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END

      -- Confirm orginal PickDetail with exact QTY
      IF @cUpdateStatus <> '0'
      BEGIN
         IF @cUpdateStatus = '5'
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '5', 
               EditDate = GETDATE(), 
               EditWho  = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey
         ELSE
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = @cUpdateStatus, 
               EditDate = GETDATE(), 
               EditWho  = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 176960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END

   -- Auto unassign position if fully sorted
   IF NOT EXISTS( SELECT 1 
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND (@cUpdateStatus = '0' OR (@cUpdateStatus <> '0' AND PD.Status < @cUpdateStatus))
         AND (@cUpdateCaseID = '0' OR (@cUpdateCaseID <> '0' AND PD.CaseID = ''))
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC')
   BEGIN
      DELETE rdt.rdtPTLPieceLog
      WHERE Station = @cStation
         AND OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
         GOTO RollBackTran
      END

      DECLARE @cWaveEnd NVARCHAR(20),
              @nlastitem INT

      SELECT @nlastitem=COUNT(1)
      FROM WaveDetail WD WITH (NOLOCK)
         JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.WaveKey = @cWaveKey AND L.Station = @cStation)
      WHERE WD.WaveKey = @cWaveKey
         -- AND PD.SKU = @cSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'

      IF @nlastitem = 0
      BEGIN
         SET @cWaveEnd='WAVE ENDED'
      END
      
      IF @cLight = '1'
      BEGIN
         SET @cDisplay = 'END' 
      END
      ELSE
      BEGIN
         SET @nErrNo = 176962
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ORDER COMPLETED
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, '', @cPosition, @cCartonID,'','','',@cWaveEnd    
         SET @nErrNo = 0
         SET @cErrMsg = ''
      END
   END
   
   -- Auto scan out
   IF @cAutoScanOut = '1'
   BEGIN
      -- Finish pick
      IF EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '5')
      BEGIN
         -- Get pick info
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
         
         -- Scan out
         IF @cPickSlipNo <> ''
         BEGIN
            IF NOT EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) 
            BEGIN
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, ScanOutDate, PickerID)
               VALUES (@cPickSlipNo, GETDATE(), GETDATE(), SUSER_SNAME())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176963
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-Out Fail
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PickingInfo SET
                  ScanOutDate = GETDATE(), 
                  -- PickerID = SUSER_SNAME(), 
                  EditWho = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176964
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-Out Fail
                  GOTO Quit
               END
            END
         END
      END
   END
   
   -- Insert DropID
   IF @cInsertDropIDSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cInsertDropIDSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cInsertDropIDSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, ' +
            ' @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition, @cCartonID, @cOrderKey, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile      INT,           ' + 
            ' @nFunc        INT,           ' + 
            ' @cLangCode    NVARCHAR( 3),  ' + 
            ' @nStep        INT,           ' + 
            ' @nInputKey    INT,           ' + 
            ' @cFacility    NVARCHAR( 5) , ' + 
            ' @cStorerKey   NVARCHAR( 15), ' + 
            ' @cLight       NVARCHAR( 1),  ' + 
            ' @cStation     NVARCHAR( 10), ' + 
            ' @cMethod      NVARCHAR( 1) , ' + 
            ' @cSKU         NVARCHAR( 20), ' + 
            ' @cIPAddress   NVARCHAR( 40), ' + 
            ' @cPosition    NVARCHAR( 10), ' + 
            ' @cCartonID    NVARCHAR( 20), ' + 
            ' @cOrderKey    NVARCHAR( 10), ' + 
            ' @nErrNo       INT           OUTPUT, ' + 
            ' @cErrMsg      NVARCHAR(250) OUTPUT  ' 
      
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, 
            @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition, @cCartonID, @cOrderKey, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
   END
   
   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight
      ,@cStation
      ,@cMethod
      ,@cSKU
      ,@cIPAddress 
      ,@cPosition
      ,@cDisplay
      ,@nErrNo     OUTPUT
      ,@cErrMsg    OUTPUT
      ,@cResult01  OUTPUT
      ,@cResult02  OUTPUT
      ,@cResult03  OUTPUT
      ,@cResult04  OUTPUT
      ,@cResult05  OUTPUT
      ,@cResult06  OUTPUT
      ,@cResult07  OUTPUT
      ,@cResult08  OUTPUT
      ,@cResult09  OUTPUT
      ,@cResult10  OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran
   
   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO