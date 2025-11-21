SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_510ExtUpd01                                     */  
/* Purpose: Update pickdetail.loc = replenishment toloc and             */  
/*          update pickdetail status = '3' (indicate replen done)       */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-11-28 1.0  James      WMS-11213. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_510ExtUpd01] (  
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT, 
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cReplenBySKUQTY NVARCHAR( 1),
   @cMoveQTYAlloc   NVARCHAR( 1),
   @cReplenKey      NVARCHAR( 10),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cToLOC          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,     
   @tExtUpdateVar   VariableTable READONLY,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @nTranCount        INT,
           @bSuccess          INT,   
           @nQTY_Bal          INT,
           @nQTY_PD           INT,
           @nQTY_Move         INT,
           @cWaveKey          NVARCHAR( 10),
           @cLot              NVARCHAR( 10),
           @cLoc              NVARCHAR( 10),
           @cID               NVARCHAR( 18),
           @cPickDetailKey    NVARCHAR( 10),
           @cMoveRefKey       NVARCHAR( 10),
           @cPackKey          NVARCHAR( 10),
           @cPackUOM3         NVARCHAR( 10),
           @cRPL_Key          NVARCHAR( 10)
  
   IF @nStep IN ( 4, 5)  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         -- For calculation
         --SET @nQTY_Bal = @nQTY

         --SELECT @cWaveKey = R.WaveKey,
         --         @cLot = R.Lot,
         --         @nQTY_Bal = Qty
         --FROM dbo.REPLENISHMENT R WITH (NOLOCK)
         --WHERE R.ReplenishmentKey = @cReplenKey

         --SELECT @cFromLOC '@cFromLOC', @cToLOC '@cToLOC', @cFromID '@cFromID', @cToID '@cToID', @cSKU '@cSKU'
         
         DECLARE @curRPL CURSOR
            
         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN  -- Begin our own transaction    
         SAVE TRAN rdt_510ExtUpd01 -- For rollback or commit only our own transaction   

         IF ISNULL( @cReplenKey, '') <> ''
            SET @curRPL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT WaveKey, Lot, Qty
            FROM dbo.REPLENISHMENT R WITH (NOLOCK)
            WHERE R.ReplenishmentKey = @cReplenKey
         ELSE
            SET @curRPL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT WaveKey, Lot, Qty
            FROM dbo.REPLENISHMENT WITH (NOLOCK)
            WHERE FromLOC = @cFromLOC
            AND   (( ISNULL( @cFromID, '') = '') OR ( ID = @cFromID))
            AND   SKU = @cSKU
            AND   Confirmed = 'N' 
         OPEN @curRPL
         FETCH NEXT FROM @curRPL INTO @cWaveKey, @cLot, @nQTY_Bal
         WHILE @@FETCH_STATUS = 0
         BEGIN
         --SELECT @cWaveKey '@cWaveKey', @cStorerKey '@cStorerKey', @cLot '@cLot'
         --SELECT @nQTY_Bal '@nQTY_Bal', @cFromLOC '@cFromLOC', @cToLOC '@cToLOC'
         --SELECT @cFromID '@cFromID', @cToID '@cToID', @cSKU '@cSKU'
         --SELECT TOP 5 'rdt_510ExtUpd01', * FROM pickdetail (NOLOCK) WHERE Storerkey = '11372' AND sku = @csku ORDER BY editdate desc
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, PD.QTY, PD.Loc, PD.ID
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey) 
            WHERE WD.WaveKey = @cWaveKey
            AND   PD.Storerkey = @cStorerKey
            AND   PD.Lot = @cLot
            AND   PD.Loc = @cFromLOC
            AND   (( ISNULL( @cFromID, '') = '') OR ( PD.ID = @cFromID))
            --AND   ((@nQTY_Bal = 0 AND PD.Loc = @cFromLOC) OR ( @nQTY_Bal > 0 AND PD.Loc = @cToLOC))
            --AND   ((@nQTY_Bal = 0 AND ( ISNULL( @cFromID, '') = '') OR ( PD.ID = @cFromID)) OR ( @nQTY_Bal > 0 AND ( ISNULL( @cToID, '') = '') OR ( PD.ID = @cToID)))
            AND   PD.Sku = @cSKU
            AND   PD.[Status] = '0'
            AND   PD.QTY > 0
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cLoc, @cID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     MoveRefKey = @cMoveRefKey, 
                     [Status] = '4',
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 146551
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
                     [Status] = '4',
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 146552
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
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        [Status] = '4',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 146553
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     SET @nQTY_Move = 0
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
                        SET @nErrNo = 146554
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
   				         SET @nErrNo = 146555
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
                           SET @nErrNo = 146556
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
                        SET @nErrNo = 146557
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
   
                     -- Confirm orginal PickDetail with exact QTY
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        [Status] = '4',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 146558
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
   
                     SET @nQTY_Move = @nQTY_Bal
                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cLoc, @cID
            END

            FETCH NEXT FROM @curRPL INTO @cWaveKey, @cLot, @nQTY_Bal
         END
         
         IF ISNULL( @cReplenKey, '') = ''
         BEGIN
            -- Short replen the rest (same from loc, from id)
            -- Exlclude by replenkey
            SET @curRPL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT ReplenishmentKey
            FROM dbo.REPLENISHMENT WITH (NOLOCK)
            WHERE FromLOC = @cFromLOC
            AND   (( ISNULL( @cFromID, '') = '') OR ( ID = @cFromID))
            AND   SKU = @cSKU
            AND   Confirmed = 'N' 
            OPEN @curRPL
            FETCH NEXT FROM @curRPL INTO @cRPL_Key
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.Replenishment WITH (ROWLOCK) SET
                  QTY = 0,
                  Confirmed = 'Y'  
               WHERE ReplenishmentKey = @cRPL_Key
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 146559
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curRPL INTO @cRPL_Key
            END
         END
         
         GOTO CommitTrans  
        
         RollBackTran:    
               ROLLBACK TRAN rdt_510ExtUpd01    
  
         CommitTrans:    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
      END  
   END  
     
   Quit:
    

GO