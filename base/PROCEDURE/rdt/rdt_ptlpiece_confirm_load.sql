SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Load                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm by load                                             */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 09-07-2018 1.0  Ung         WMS-5489 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Confirm_Load] (
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

   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNo      NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cSortedPDKey      NVARCHAR(10)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cLOC              NVARCHAR( 10)
   DECLARE @cID               NVARCHAR( 18)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cLoadkey          NVARCHAR( 10)
   DECLARE @cDisplay          NVARCHAR( 5)
   
   SET @cDisplay = '' 

   -- Find PickDetail to offset
   SET @cOrderKey = ''
   SELECT TOP 1 
      @cOrderKey = PD.OrderKey, 
      @cOrderLineNo = PD.OrderLineNumber, 
      @cPickDetailKey = PD.PickDetailKey, 
      @cLOT = PD.LOT, 
      @cLOC = PD.LOC, 
      @cID = PD.ID, 
      @nQTY_PD = PD.QTY
   FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
      JOIN PickDetail PD WITH (NOLOCK) ON (L.SourceKey = PD.DropID)
      JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
   WHERE L.Station = @cStation
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status <= '5'
      AND PD.CaseID = ''
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND O.Status <> 'CANC' 
      AND O.SOStatus <> 'CANC'

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 99751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
      GOTO Quit
   END

   -- Find sorted PickDetail to topup (avoid split line, 1 QTY 1 line), but must be same line, LOT, LOC, ID
   SET @cSortedPDKey = ''
   SELECT @cSortedPDKey = PickDetailKey
   FROM PickDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
      AND OrderLineNumber = @cOrderLineNo
      AND LOT = @cLOT
      AND LOC = @cLOC
      AND ID = @cID
      AND Status <= '5'
      AND CaseID = 'SORTED'
      AND QTY > 0
      AND Status <> '4'

   /***********************************************************************************************

                                              CONFIRM ORDER

   ***********************************************************************************************/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction

   IF @cSortedPDKey <> ''
   BEGIN
      -- Reduce open PickDetail
      UPDATE PickDetail SET
         QTY = QTY - 1, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
			SET @nErrNo = 99752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
         GOTO RollBackTran
      END
      
      -- Top up sorted PickDetail
      UPDATE PickDetail SET
         QTY = QTY + 1, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE PickDetailKey = @cSortedPDKey
      IF @@ERROR <> 0
      BEGIN
			SET @nErrNo = 99753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
         GOTO RollBackTran
      END
      
      -- Delete zero balance PickDetail
      IF @nQTY_PD = 1
      BEGIN
         DELETE PickDetail WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
   			SET @nErrNo = 99754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      -- Exact match
      IF @nQTY_PD = 1
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            CaseID = 'SORTED', 
            DropID = 'SORTED', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 99755
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
            SET @nErrNo = 99756
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
            @nQTY_PD - 1, -- QTY
            NULL, -- TrafficCop
            '1'   -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK) 
   		WHERE PickDetailKey = @cPickDetailKey			            
         IF @@ERROR <> 0
         BEGIN
   			SET @nErrNo = 99757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Split RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM RefKeyLookup WITH (NOLOCK) 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 99758
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END
         
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            QTY = 1, 
            CaseID = 'SORTED', 
            DropID = 'SORTED', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 99759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END

   -- Get order info
   DECLARE @cConsigneeKey NVARCHAR(15)
   SELECT 
      @cConsigneeKey = ConsigneeKey, 
      @cLoadKey = LoadKey
   FROM Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
   
   -- Get stor info
   DECLARE @cSUSR5 NVARCHAR( 20)
   SELECT @cSUSR5 = SUSR5 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey
   
   -- Get SKU info
   DECLARE @cSKUDesc NVARCHAR(60)
   SELECT @cSKUDesc = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   SET @cResult01 = 'STOR:'
   SET @cResult02 = @cSUSR5
   SET @cResult03 = ''
   SET @cResult04 = 'LOADKEY:'
   SET @cResult05 = @cLoadKey
   SET @cResult06 = ''
   SET @cResult07 = 'SKU:'
   SET @cResult08 = @cSKU
   SET @cResult09 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
   SET @cResult10 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO