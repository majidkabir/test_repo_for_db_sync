SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_DropIDOrder                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Confirm by Drop ID, SKU                                     */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 22-04-2023 1.0  Ung         WMS-22221 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_DropIDOrder] (
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

   DECLARE @cDropID           NVARCHAR( 20)
   DECLARE @cCartonID         NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cDisplay          NVARCHAR( 5)

   SET @cDisplay = '' 

   -- Get assign info
   SELECT @cDropID = V_DropID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Find PickDetail to offset
   SET @cOrderKey = ''
   SELECT TOP 1 
      @cOrderKey = O.OrderKey, 
      @cPickDetailKey = PD.PickDetailKey, 
      @nQTY_PD = QTY, 
      @cCartonID = L.CartonID, 
      @cIPAddress = L.IPAddress, 
      @cPosition = L.Position
   FROM Orders O WITH (NOLOCK) 
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
   WHERE PD.DropID = @cDropID
      AND PD.SKU = @cSKU
      AND CaseID = ''
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND PD.Status < '5'
      AND O.Status <> 'CANC' 
      AND O.SOStatus <> 'CANC'
   ORDER BY L.Position

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 200051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
      -- EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cStation, @cDropID, @cSKU
      GOTO Quit
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
         DropID = @cCartonID, 
         EditDate = GETDATE(), 
         EditWho  = SUSER_SNAME(), 
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 200052
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
         SET @nErrNo = 200053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
         GOTO RollBackTran
      END

      -- Create new a PickDetail to hold the balance
      INSERT INTO dbo.PickDetail (
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, Channel_ID, 
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         PickDetailKey, 
         QTY, 
         TrafficCop,
         OptimizeCop)
      SELECT 
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
         CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, Channel_ID, 
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         @cNewPickDetailKey, 
         @nQTY_PD - 1, -- QTY
         NULL, -- TrafficCop
         '1'   -- OptimizeCop
      FROM dbo.PickDetail WITH (NOLOCK) 
		WHERE PickDetailKey = @cPickDetailKey			            
      IF @@ERROR <> 0
      BEGIN
			SET @nErrNo = 200054
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
            SET @nErrNo = 200055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
            GOTO RollBackTran
         END
      END
      
      -- Change orginal PickDetail with exact QTY (with TrafficCop)
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         QTY = 1, 
         CaseID = 'SORTED', 
         DropID = @cCartonID, 
         EditDate = GETDATE(), 
         EditWho  = SUSER_SNAME(), 
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 200056
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
   END

   -- Check position fully sorted
   IF NOT EXISTS( SELECT 1 
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC')
   BEGIN
      SET @cDisplay = 'END' 
      
      IF @cLight <> '1'
      BEGIN
         SET @nErrNo = 200058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ORDER COMPLETED
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cErrMsg, '', @cPosition, @cCartonID    
         SET @nErrNo = 0
         SET @cErrMsg = ''
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
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   
   -- Position fully sorted
   IF @cDisplay = 'END'
   BEGIN
      DECLARE @cWCSSP NVARCHAR( 30)
      SET @cWCSSP = rdt.rdt_PTLPiece_GetConfig( @nFunc, 'WCSSP', @cStorerKey, @cMethod)
      IF @cWCSSP = '0'
         SET @cWCSSP = ''
      
      -- Send carton to WCS (if error don't rollback, coz need the error in TCPSocket_OutLog)
      IF @cWCSSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cWCSSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cWCSSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' + 
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cStation     NVARCHAR( 10), ' +
               '@cMethod      NVARCHAR( 1),  ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cIPAddress   NVARCHAR( 40), ' +
               '@cPosition    NVARCHAR( 10), ' +
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            -- IF @nErrNo <> 0
            --    GOTO Quit
         END
      END
      
      -- Auto unassign position if fully sorted (cannot unassign earlier, coz WCS SP need the assign details)
      DELETE rdt.rdtPTLPieceLog
      WHERE Station = @cStation
         AND OrderKey = @cOrderKey
      IF @@ERROR <> 0 AND @nErrNo = 0 -- Not overwrite WCS error, if any
      BEGIN
         SET @nErrNo = 200057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
         GOTO RollBackTran
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO