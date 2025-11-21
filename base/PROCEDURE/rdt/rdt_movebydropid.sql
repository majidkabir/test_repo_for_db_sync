SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveByDropID                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Split PickDetail                                            */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-Mar-2008 1.0  James       Created                                 */
/* 01-May-2012 1.1  Shong       Insert RefKeyLookUp                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveByDropID] (
   @cFromDropID       NVARCHAR( 20),
   @cToDropID         NVARCHAR( 20),
   @nQTY_Move         INT,
   @cStorerKey        NVARCHAR( 15),
   @cSKU              NVARCHAR( 20), 
   @cLottable02       NVARCHAR( 18),
   @cLottable03       NVARCHAR( 18),
   @dLottable04       DATETIME,
   @cLangCode         VARCHAR (3),
   @nErrNo            INT          OUTPUT, 
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   -- Move by sku
   IF @nQTY_Move > 0 
   BEGIN
      DECLARE 
         @b_success         INT,
         @n_err             INT,
         @c_errmsg          NVARCHAR( 255),
         @cNewPickDetailKey    NVARCHAR( 10),
         @cPickDetailKey    NVARCHAR( 10),
         @nQTY_Avail        INT,
         @nTranCount        INT

      DECLARE @curPD CURSOR
      SET @b_success = 0

      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT 
         PD.PickDetailKey,
         PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.StorerKey = LA.StorerKey AND PD.Lot = LA.Lot)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.DropID = @cFromDropID
         AND PD.Status = '5'
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         -- NULL column cannot be compared, even if SET ANSI_NULLS OFF
         AND ISNULL(LA.Lottable04, 0) = ISNULL(@dLottable04, 0)
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
            DropID = @cToDropID,
            CartonGroup = 'M',
            TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND DropID = @cFromDropID
               AND PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 63882
               SET @cErrMsg = rdt.rdtgetmessage( 63882, @cLangCode, 'DSP') -- Upd PDtl Fail
               GOTO RollBackTran
            END      

            SET @nQTY_Move = 0
         END --@nQTY_Move = @nQTY_Avail
            ELSE
            IF @nQTY_Move > @nQTY_Avail
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cToDropID,
               CartonGroup = 'M',
               TrafficCop = NULL
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cFromDropID
                  AND PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63883
                  SET @cErrMsg = rdt.rdtgetmessage( 63883, @cLangCode, 'DSP') -- Upd PDtl Fail
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
                  AND DropID = @cFromDropID
                  AND PickDetailKey = @cPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63884
                  SET @cErrMsg = rdt.rdtgetmessage( 63884, @cLangCode, 'DSP') -- Upd PDtl Fail
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
                  SET @nErrNo = 63885
                  SET @cErrMsg = rdt.rdtgetmessage( 63885, @cLangCode, 'DSP') -- GetDetKey fail
                  GOTO RollBackTran            
               END

               INSERT INTO dbo.PICKDETAIL
               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, 
               UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource, 
               CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
               WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)
               SELECT @cNewPickDetailKey AS PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku, 
               UOM, UOMQty, @nQTY_Move AS QTY, QtyMoved, Status, @cToDropID AS DropID, Loc, ID, PackKey, UpdateSource, 
               CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
               WaveKey, EffectiveDate, NULL AS TrafficCop, ArchiveCop, '1' AS OptimizeCop, ShipFlag, PickSlipNo 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cFromDropID
                  AND PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63886
                  SET @cErrMsg = rdt.rdtgetmessage( 63886, @cLangCode, 'DSP') -- Upd PDtl Fail
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
      DropID = @cToDropID,
      CartonGroup = 'M',
      Trafficcop = NULL
      WHERE StorerKey = @cStorerKey
         AND DropID = @cFromDropID   

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 63879
         SET @cErrMsg = rdt.rdtgetmessage( 63879, @cLangCode, 'DSP') --'Upd PDtl Fail'
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