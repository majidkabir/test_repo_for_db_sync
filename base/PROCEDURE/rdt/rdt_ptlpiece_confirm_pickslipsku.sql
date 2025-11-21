SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_PickSlipSKU                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm by PickSlipNo, SKU                                  */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-11-2022 1.0  Ung         WMS-21056 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_PickSlipSKU] (
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

   DECLARE @bSuccess             INT
   DECLARE @nTranCount           INT
   DECLARE @nRowCount            INT

   DECLARE @cPickSlipNo          NVARCHAR(10)
   DECLARE @cDropID              NVARCHAR(20)
   DECLARE @cZone                NVARCHAR(18)
   DECLARE @cOrderKey            NVARCHAR(10)
   DECLARE @cLoadKey             NVARCHAR(10)
   DECLARE @cFromPickDetailKey   NVARCHAR(10) = ''
   DECLARE @nFromQTY             INT
   DECLARE @cToPickDetailKey     NVARCHAR(10) = ''
   DECLARE @nToQTY               INT
   DECLARE @cDisplay             NVARCHAR(5) = ''

   DECLARE @cFromOrderKey        NVARCHAR(10)
   DECLARE @cFromOrderLineNumber NVARCHAR(5)
   DECLARE @cFromLOT             NVARCHAR(10)
   DECLARE @cFromLOC             NVARCHAR(10)
   DECLARE @cFromID              NVARCHAR(18)

   -- Get assign info
   SELECT TOP 1 @cPickSlipNo = PickSlipNo 
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation

   -- Get session info
   SELECT @cDropID = V_DropID
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Get PickHeader info
   SELECT
      @cZone = Zone,
      @cOrderKey = ISNULL( OrderKey, ''),
      @cLoadKey = ExternOrderKey
   FROM PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SELECT TOP 1
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
      WHERE RKL.PickslipNo = @cPickSlipNo
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
      WHERE RKL.PickslipNo = @cPickSlipNo
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SELECT TOP 1
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SELECT TOP 1
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE LPD.Loadkey = @cLoadKey
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         
      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE LPD.Loadkey = @cLoadKey
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Custom PickSlip
   ELSE
   BEGIN
      SELECT TOP 1
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.DropID = @cDropID
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Check blank
   IF @cFromPickDetailKey = ''
   BEGIN
      SET @nErrNo = 193501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No task
      GOTO Quit
   END


   /***********************************************************************************************

                                              CONFIRM ORDER

   ***********************************************************************************************/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction

   /*
      For 1 position = 1 SKU, it is most likeky a B2B process. So won't split PickDetail to 1 QTY = 1 record
      Need to use find PickDetail to reduce and top up approach

      1. Reduce from pickdetail
         if from qty = 1
            if have to pickdetail, direct delete the from, don't need to reduce first
            if don't have to pickdetail, stamp it as sorted
         else 
            if have to pickdetail
               reduce from pickdetail
            if don't have to pickdetail
               split line, new line holding the balance
               stamp from line as sorted
            
      2. Top up to pickdetail
         if found
      
      test scenarios:
         1 QTY
         2 QTY
         3 QTY
      end result should only have 1 pickdetail line after fully sorted
   
   */

   -- 1. Reduce from pickdetail
   IF @nFromQTY = 1 
   BEGIN
      -- if have to pickdetail, delete the from, don't need to reduce first
      IF @cToPickDetailKey <> ''
      BEGIN
         UPDATE dbo.PickDetail SET
            ArchiveCop = '9'
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END

         DELETE dbo.PickDetail
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- if don't have to pickdetail, stamp it as sorted
      ELSE
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      -- if have to pickdetail
      IF @cToPickDetailKey <> ''
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = QTY - 1,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- if don't have to pickdetail
      ELSE
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
            SET @nErrNo = 193506
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
            @nFromQTY - 1, -- QTY
            NULL,        -- TrafficCop
            '1'          -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Check RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cFromPickDetailKey)
         BEGIN
            -- Insert RefKeyLookup
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM RefKeyLookup WITH (NOLOCK)
            WHERE PickDetailKey = @cFromPickDetailKey
            
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
            IF @nErrNo <> 0 OR @nRowCount <> 1
            BEGIN
               SET @nErrNo = 193508
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- stamp from line as sorted
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = 1,
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 193509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   
   -- 2. Top up to pickdetail
   IF @cToPickDetailKey <> ''
   BEGIN
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         QTY = QTY + 1,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE PickDetailKey = @cToPickDetailKey
         AND QTY = @nToQTY
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
      IF @nErrNo <> 0 OR @nRowCount <> 1
      BEGIN
         SET @nErrNo = 193510
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
      AND SKU = @cSKU

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

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType     = '3',
     @nMobileNo       = @nMobile,
     @nFunctionID     = @nFunc,
     @cFacility       = @cFacility,
     @cStorerKey      = @cStorerkey,
     @cPickSlipNo     = @cPickSlipNo,
     @cDropID         = @cDropID,
     @cSKU            = @cSKU,
     @cDeviceID       = @cStation,
     @cDevicePosition = @cPosition, 
     @nQty            = 1

   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO