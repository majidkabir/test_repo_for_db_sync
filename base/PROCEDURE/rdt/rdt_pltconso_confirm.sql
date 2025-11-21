SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PltConso_Confirm                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Split PickDetail                                            */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 23-02-2015  1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PltConso_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR (3),
   @cFacility        NVARCHAR (5),
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 20),
   @cToID            NVARCHAR( 20),
   @cSKU             NVARCHAR( 20), 
   @nQTY_Move        INT,
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @b_success           INT,
      @n_err               INT,
      @c_errmsg            NVARCHAR( 255),
      @cNewPickDetailKey   NVARCHAR( 10),
      @cPickDetailKey      NVARCHAR( 10),
      @nQTY_Avail          INT,
      @nTranCount          INT

   -- Move by sku
   IF @nQTY_Move > 0 
   BEGIN

      DECLARE @curPD CURSOR
      SET @b_success = 0

      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT 
         PickDetailKey,
         QTY
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND DropID = @cFromID
         AND Status < '9'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_Avail

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_MoveByDropID

      WHILE @@FETCH_STATUS = 0 AND @nQTY_Move > 0
      BEGIN
         IF @nQTY_Move = @nQTY_Avail 
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cToID,
            CartonGroup = 'M',
            TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromID
               AND PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PDtl Fail
               GOTO RollBackTran
            END      

            SET @nQTY_Move = 0
         END --@nQTY_Move = @nQTY_Avail
         ELSE
         IF @nQTY_Move > @nQTY_Avail
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cToID,
            CartonGroup = 'M',
            TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromID
               AND PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PDtl Fail
               GOTO RollBackTran
            END      

            SET @nQTY_Move = @nQTY_Move - @nQTY_Avail
         END --@nQTY_Move > @nQTY_Avail
         ELSE
         IF @nQTY_Move < @nQTY_Avail
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Qty = Qty - @nQTY_Move,
            CartonGroup = 'M',
            TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromID
               AND PickDetailKey = @cPickDetailKey
               
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PDtl Fail
               GOTO RollBackTran
            END      

            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY', 
               10 ,
               @cNewPickDetailKey  OUTPUT,
               @b_success        OUTPUT,
               @n_err            OUTPUT,
               @c_errmsg         OUTPUT
               
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 51854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKey fail
               GOTO RollBackTran            
            END

            INSERT INTO dbo.PICKDETAIL
            (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, 
            UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource, 
            CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
            WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)
            SELECT @cNewPickDetailKey AS PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, 
            UOM, UOMQty, @nQTY_Move AS QTY, QtyMoved, Status, @cToID AS DropID, Loc, ID, PackKey, UpdateSource, 
            CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
            WaveKey, EffectiveDate, NULL AS TrafficCop, ArchiveCop, '1' AS OptimizeCop, ShipFlag, PickSlipNo 
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromID
               AND PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51855
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PDtl Fail
               GOTO RollBackTran
            END      
               
            IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey=@cPickDetailKey)
            BEGIN
               INSERT INTO RefKeyLookup
               	( PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey )
               SELECT @cNewPickDetailKey, Pickslipno, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK)
               WHERE PickDetailkey = @cPickDetailKey
            END
               
            SET @nQTY_Move = 0
         END --@nQTY_Move < @nQTY_Avail
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_Avail
      END
      CLOSE @curPD
      DEALLOCATE @curPD

      COMMIT TRAN rdt_MoveByDropID -- Only commit change made in rdt_MoveByDropID
      GOTO Quit
   END      
   ELSE -- Move by pallet
   BEGIN
      BEGIN TRAN

      --update pickdetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
      DropID = @cToID,
      CartonGroup = 'M',
      Trafficcop = NULL
      WHERE StorerKey = @cStorerKey
         AND DropID = @cFromID   

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 51856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PDtl Fail'
         GOTO Fail
      END

      COMMIT TRAN
      GOTO Fail   -- exit
   END

   RollBackTran:
      ROLLBACK TRAN rdt_MoveByDropID -- Only rollback change made in rdt_MoveByDropID
   Quit:
      -- Commit until the level we started
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN   
   Fail: 
END

GO