SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Replenish_MovePickDetail                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-02-05 1.0  James       WMS-11213 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_Replenish_MovePickDetail] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cReplenKey      NVARCHAR( 10)
   ,@cLot            NVARCHAR( 10)
   ,@cLoc            NVARCHAR( 10)
   ,@cId             NVARCHAR( 18)
   ,@nQty            INT
   ,@cToLoc          NVARCHAR( 10)
   ,@cToId           NVARCHAR( 18)
   ,@cWaveKey        NVARCHAR( 10)
   ,@cMoveRefKey     NVARCHAR( 10)  OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPackKey       NVARCHAR( 10)
   DECLARE @cPackUOM3      NVARCHAR( 10)   
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cUpdatePickDetail NVARCHAR( 1)
   DECLARE @bSuccess    INT
   DECLARE @nQTY_PD     INT
   DECLARE @nQTY_Bal    INT
   DECLARE @nQTY_Move   INT
   
   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   
   SET @nQTY_Bal = @nQty
   --SELECT @cWaveKey '@cWaveKey'
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Replenish_MovePickDetail -- For rollback or commit only our own transaction

   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT PD.PickDetailKey, PD.SKU, PD.Qty
   FROM dbo.PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.Storerkey = @cStorerKey
   AND   PD.Lot = @cLot
   AND   PD.Loc = @cLoc
   AND   PD.ID = @cId
   AND   PD.[Status] = '0'
   AND   PD.QTY > 0
   AND   (( ISNULL( @cWaveKey, '') = '') OR ( PD.WaveKey = @cWaveKey))
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get new MoveRefKey
      EXECUTE dbo.nspg_GetKey
         'MOVEREFKEY',
         10 ,
         @cMoveRefKey OUTPUT,
         @bSuccess    OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 148001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
         GOTO RollBackTran
      END

      -- Exact match
      IF @nQTY_PD = @nQTY_Bal
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            MoveRefKey = @cMoveRefKey, 
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 148002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         
         SET @nQTY_Move = @nQTY_PD
         SET @nQTY_Bal = 0 -- Reduce balance
      END

      -- PickDetail have less
		ELSE IF @nQTY_PD < @nQTY_Bal
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            MoveRefKey = @cMoveRefKey, 
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 148003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         
         SET @nQTY_Move = @nQTY_PD
         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more
		ELSE IF @nQTY_PD > @nQTY_Bal
      BEGIN
         -- Short pick
         IF @nQTY_Bal = 0 -- Don't need to split
            SET @nQTY_Move = 0
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
               SET @nErrNo = 148004
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKey Fail
               GOTO RollBackTran
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status, 
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status, 
               @nQTY_PD - @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 148005
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
                  SET @nErrNo = 148006
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END
   
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 148007
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               MoveRefKey = @cMoveRefKey, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 148008
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            SET @nQTY_Move = @nQTY_Bal
            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END
      
      IF @cUpdatePickDetail = '1'
      BEGIN
         -- Short pick
         IF @nQTY_Move = 0 
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               [Status] = '4',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 148009
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               [Status] = '3',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 148010
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
      END
      
      -- Move PickDetail
      IF @cToLOC <> '' AND @nQTY_Move > 0
      BEGIN
         -- Get SKU info
         SELECT 
            @cPackKey = SKU.PackKey, 
            @cPackUOM3 = Pack.PackUOM3
         FROM SKU WITH (NOLOCK)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
         
         -- Move LOTxLOCxID
         EXEC dbo.nspItrnAddMove
               @n_ItrnSysId     = NULL          -- int
            , @c_StorerKey     = @cStorerKey   -- NVARCHAR(15)
            , @c_Sku           = @cSKU         -- NVARCHAR(20)
            , @c_Lot           = @cLOT         -- NVARCHAR(10)
            , @c_FromLoc       = @cLoc         -- NVARCHAR(10)
            , @c_FromID        = @cID          -- NVARCHAR(18)
            , @c_ToLoc         = @cToLOC       -- NVARCHAR(10)
            , @c_ToID          = @cToID        -- NVARCHAR(18)
            , @c_Status        = ''            -- NVARCHAR(10)
            , @c_lottable01    = ''            -- NVARCHAR(18)
            , @c_lottable02    = ''            -- NVARCHAR(18)
            , @c_lottable03    = ''            -- NVARCHAR(18)
            , @d_lottable04    = ''            -- datetime
            , @d_lottable05    = ''            -- datetime
            , @n_casecnt       = 0             -- int
            , @n_innerpack     = 0             -- int
            , @n_qty           = @nQTY_Move    -- int
            , @n_pallet        = 0             -- int
            , @f_cube          = 0             -- float
            , @f_grosswgt      = 0             -- float
            , @f_netwgt        = 0             -- float
            , @f_otherunit1    = 0             -- float
            , @f_otherunit2    = 0             -- float
            , @c_SourceKey     = ''            -- NVARCHAR(20)
            , @c_SourceType    = 'rdt_Replenish_MovePickDetail'  -- NVARCHAR(30)
            , @c_PackKey       = @cPackKey     -- NVARCHAR(10)
            , @c_UOM           = @cPackUOM3    -- NVARCHAR(10)
            , @b_UOMCalc       = 1             -- int
            , @d_EffectiveDate = ''            -- datetime
            , @c_itrnkey       = ''            -- NVARCHAR(10)   OUTPUT
            , @b_Success       = @bSuccess     -- int        OUTPUT
            , @n_err           = @nErrNo       -- int        OUTPUT
            , @c_errmsg        = @cErrMsg      -- NVARCHAR(250)  OUTPUT
            , @c_MoveRefKey    = @cMoveRefKey
   
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   END

   COMMIT TRAN rdt_Replenish_MovePickDetail
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_Replenish_MovePickDetail -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END

GO