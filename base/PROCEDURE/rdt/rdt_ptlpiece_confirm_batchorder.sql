SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_BatchOrder                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Confirm by batch order                                            */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 29-11-2022 1.0  Ung         WMS-21170 base on rdt_PTLPiece_Confirm_Order   */
/*                             Add DynamicSlot                                */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_BatchOrder] (
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

   DECLARE @cBatchKey         NVARCHAR( 20)
   DECLARE @cCartonID         NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10) = ''
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cDisplay          NVARCHAR( 5)
   DECLARE @cLightMode        NVARCHAR( 4)
   DECLARE @cLOC              NVARCHAR( 10)

   DECLARE @cDynamicSlot      NVARCHAR( 1)
   DECLARE @cUpdateDropID     NVARCHAR( 1)

   SET @cDisplay = ''

   -- Storer configure
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)
   SET @cUpdateDropID = rdt.RDTGetConfig( @nFunc, 'UpdateDropID', @cStorerKey)

   IF @nStep = 3 -- SKU
   BEGIN
      -- Find PickDetail to offset (for order assigned)
      SELECT TOP 1
         @cOrderKey = O.OrderKey,
         @cPickDetailKey = PD.PickDetailKey,
         @nQTY_PD = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)
         JOIN Orders O WITH (NOLOCK) ON (L.OrderKey = O.OrderKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) 
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
      ORDER BY L.Position
      
      -- Find PickDetail to offset (for new order not yet assigned)
      IF @cOrderKey = '' AND @cDynamicSlot = '1' 
      BEGIN
         -- Get batch (if some order assigned)
         SET @cBatchKey = ''
         SELECT @cBatchKey = BatchKey
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND BatchKey <> ''
            
         -- Get batch (no order had assigned)
         IF @cBatchKey = ''
            SELECT @cBatchKey = V_PickSlipNo FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
         
         SELECT TOP 1
            @cOrderKey = O.OrderKey,
            @cPickDetailKey = PD.PickDetailKey,
            @nQTY_PD = QTY
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) 
         WHERE PD.PickSlipNo = @cBatchKey
            AND PD.SKU = @cSKU
            AND PD.Status <= '5'
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
      END
   END
   
   ELSE IF @nStep = 5 -- Close carton
   BEGIN
      -- Find PickDetail to offset (for order in that position)
      SELECT TOP 1
         @cOrderKey = O.OrderKey,
         @cPickDetailKey = PD.PickDetailKey,
         @nQTY_PD = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)
         JOIN Orders O WITH (NOLOCK) ON (L.OrderKey = O.OrderKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) 
      WHERE L.Station = @cStation
         AND L.Position = @cPosition
         AND PD.SKU = @cSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
   END
   
   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 194401
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
            @cPosition = DP.DevicePosition, 
            @cLOC = LOC
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
            SET @nErrNo = 194402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPos4NewOrder
            GOTO Quit
         END
         
         -- Save assign
         INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, LOC, BatchKey, OrderKey, CartonID)
         VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cBatchKey, @cOrderKey, '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 194403
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
         
         -- Go to carton ID screen
         SET @nErrNo = 194404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Assign Carton
         SET @nErrNo = -2
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
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         CaseID = 'SORTED',
         DropID = CASE WHEN @cUpdateDropID =  '1' THEN @cCartonID ELSE DropID END,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME(),
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 194405
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
         SET @nErrNo = 194406
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
         OptimizeCop, Channel_ID)   -- INC1356666
      SELECT
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
         CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
         @cNewPickDetailKey,
         @nQTY_PD - 1, -- QTY
         NULL,        -- TrafficCop
         '1',         -- OptimizeCop
         Channel_ID   -- INC1356666
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 194407
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
            SET @nErrNo = 194408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
            GOTO RollBackTran
         END
      END

      -- Change orginal PickDetail with exact QTY (with TrafficCop)
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         QTY = 1,
         CaseID = 'SORTED',
         DropID = CASE WHEN @cUpdateDropID =  '1' THEN @cCartonID ELSE DropID END,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME(),
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 194409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
   END

   -- Get position info
   SELECT
      @cIPAddress = IPAddress,
      @cPosition = Position
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND OrderKey = @cOrderKey

   -- Get method info
   SELECT TOP 1
      @cBatchKey = BatchKey
   FROM rdt.rdtPTLPieceLog (NOLOCK)
   WHERE Station = @cStation
      AND OrderKey = @cOrderKey

   -- Get PackTask info
   DECLARE @nRowRef        BIGINT
   DECLARE @cPreAssignPos  NVARCHAR(10)
   SELECT
      @nRowRef = RowRef,
      @cPreAssignPos = DevicePosition
   FROM PackTask WITH (NOLOCK)
   WHERE TaskBatchNo = @cBatchKey
      AND OrderKey = @cOrderKey

   -- Exceed not yet assign position
   IF @cPreAssignPos = ''
   BEGIN
      -- Get position info
      DECLARE @cLogicalName NVARCHAR(10)
      SELECT @cLogicalName = LogicalName
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'STATION'
         AND DeviceID = @cStation
         AND DevicePosition = @cPosition

      -- Update PackTask
      UPDATE PackTask SET
         DevicePosition = @cPosition,
         LogicalName = @cLogicalName,
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 194410
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTask Fail
         GOTO RollBackTran
      END
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '3',
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @cDeviceID   = @cStation,
     @cDropID     = @cPosition,
     @cPickSlipNo = @cBatchKey,
     @cOrderKey   = @cOrderKey,
     @cSKU        = @cSKU,
     @nQTY        = 1, 
     @cCartonID   = @cCartonID

   -- Check order completed
   IF @cDynamicSlot = '1' 
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) 
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status <= '5'
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
      BEGIN
         -- Unassign position
         DELETE rdt.rdtPTLPieceLog
         WHERE Station = @cStation
            AND OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 194411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
            GOTO RollBackTran
         END
         
         IF @cLight = '1'
         BEGIN
            -- Get light setting
            SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)
      
            -- Display
            SET @cDisplay = 'END'
         END
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