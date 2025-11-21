SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Replenish_Confirm                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 21-11-2017 1.0  Ung         WMS-3426 Created                         */
/* 07-12-2017 1.1  Ung         WMS-3426 Fix QTY NULL                    */
/* 12-06-2018 1.2  Ung         WMS-5195 Add MoveQTYAlloc                */
/* 05-02-2020 1.3  James       WMS-11213 Add MoveRefKey (james01)       */
/*                             Allow full short replen                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_Replenish_Confirm] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cReplenBySKUQTY NVARCHAR( 1)
   ,@cMoveQTYAlloc   NVARCHAR( 1)
   ,@cReplenKey      NVARCHAR( 20)
   ,@cFromLOC        NVARCHAR( 20)
   ,@cFromID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20) 
   ,@nActQTY         INT
   ,@cToLOC          NVARCHAR( 20)
   ,@cToID           NVARCHAR( 18)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cWaveKey    NVARCHAR( 10)


   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Replenish_Confirm -- For rollback or commit only our own transaction
   
   IF @cReplenBySKUQTY = '1'
   BEGIN
      DECLARE @nQTY     INT
      DECLARE @nBal_QTY INT
      DECLARE @nRPL_QTY INT
      DECLARE @nAVL_QTY INT
      DECLARE @cLOT     NVARCHAR( 10)
      DECLARE @cMoveRefKey NVARCHAR( 10) = ''
      DECLARE @nQtyAvl     INT
      DECLARE @nQtyOnHand  INT
      DECLARE @nALC_QTY INT
            
      SET @nBal_QTY = @nActQTY
      
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR FOR
         SELECT ReplenishmentKey, LOT, QTY, WaveKey
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLOC = @cFromLOC
            AND ID = @cFromID
            AND SKU = @cSKU
            AND Confirmed = 'N' 
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cReplenKey, @cLOT, @nRPL_QTY, @cWaveKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get QTY avail
         SELECT @nAVL_QTY = ISNULL( SUM( QTY 
            - CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE QTYAllocated END 
            - QTYPicked), 0),
            @nALC_QTY = ISNULL( SUM( QtyAllocated), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID

         IF @nALC_QTY > 0 AND @cMoveQTYAlloc <> '1'
         BEGIN
            SET @nErrNo = 117054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CannotMvQtyAlc
            GOTO RollBackTran
         END

         -- Make sure replen QTY not more then avail QTY
         IF @nRPL_QTY > @nAVL_QTY
            SET @nRPL_QTY = @nAVL_QTY

         -- Calc QTY to replen
         IF @nRPL_QTY > @nBal_QTY
            SET @nQTY = @nBal_QTY
         ELSE
            SET @nQTY = @nRPL_QTY

         -- (james01)
         -- Check if the replen inventory is already allocated
         -- If yes then need update moverefkey because system don't know 
         -- which pickdetail line to update (split pickdetail if needed).
         -- Confirm replen will update accordingly based on moverefkey
         SET @nErrNo = 0
         SET @cMoveRefKey = ''
         EXEC rdt.rdt_Replenish_MovePickDetail 
               @nMobile      = @nMobile
            ,@nFunc        = @nFunc
            ,@cLangCode    = @cLangCode
            ,@nStep        = @nStep
            ,@nInputKey    = @nInputKey
            ,@cFacility    = @cFacility
            ,@cStorerKey   = @cStorerKey
            ,@cReplenKey   = @cReplenKey
            ,@cLot         = @cLOT
            ,@cLoc         = @cFromLoc
            ,@cId          = @cFromID
            ,@nQty         = @nQTY
            ,@cToLoc       = @cToLOC
            ,@cToId        = @cToID
            ,@cWaveKey     = @cWaveKey
            ,@cMoveRefKey  = @cMoveRefKey OUTPUT
            ,@nErrNo       = @nErrNo      OUTPUT
            ,@cErrMsg      = @cErrMsg     OUTPUT            
            
         IF @nErrNo <> 0
            GOTO RollBackTran

         IF @cMoveRefKey = ''
         BEGIN
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET
               QTY = @nQTY,
               ToLOC = @cToLOC,
               ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END, 
               Confirmed = 'Y'  
            WHERE ReplenishmentKey = @cReplenKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- If MoveRefKey not blank, meaning pickdetail 
            -- already moved stock. No need move again when confirm replen
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET
               QTY = @nQTY,
               ToLOC = @cToLOC,
               ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END, 
               Confirmed = 'Y', 
               ArchiveCop = NULL 
            WHERE ReplenishmentKey = @cReplenKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117058
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
               GOTO RollBackTran
            END
         END

         -- Reduce balance
         SET @nBal_QTY = @nBal_QTY - @nQTY
         IF @nBal_QTY <= 0
            BREAK
         
         FETCH NEXT FROM @curPD INTO @cReplenKey, @cLOT, @nRPL_QTY, @cWaveKey
      END

      -- Check offset error
      IF @nBal_QTY <> 0
      BEGIN
         SET @nErrNo = 117052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      SELECT @cLOT = LOT, @cWaveKey = Wavekey
      FROM dbo.REPLENISHMENT WITH (NOLOCK)
      WHERE ReplenishmentKey = @cReplenKey

      -- (james01)
      -- Check if the replen inventory is already allocated
      -- If yes then need update moverefkey because system don't know 
      -- which pickdetail line to update (split pickdetail if needed).
      -- Confirm replen will update accordingly based on moverefkey
      SELECT @nALC_QTY = ISNULL( SUM( QtyAllocated), 0)  
      FROM LOTxLOCxID (NOLOCK)  
      WHERE LOT = @cLOT 
      AND   LOC = @cFromLoc 
      AND   ID = @cFromID  

      IF @nALC_QTY > 0 AND @cMoveQTYAlloc <> '1'
      BEGIN
         SET @nErrNo = 117055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CannotMvQtyAlc
         GOTO RollBackTran
      END
            
      SET @nErrNo = 0
      SET @cMoveRefKey = ''
      EXEC rdt.rdt_Replenish_MovePickDetail 
          @nMobile      = @nMobile
         ,@nFunc        = @nFunc
         ,@cLangCode    = @cLangCode
         ,@nStep        = @nStep
         ,@nInputKey    = @nInputKey
         ,@cFacility    = @cFacility
         ,@cStorerKey   = @cStorerKey
         ,@cReplenKey   = @cReplenKey
         ,@cLot         = @cLOT
         ,@cLoc         = @cFromLoc
         ,@cId          = @cFromID
         ,@nQty         = @nActQTY
         ,@cToLoc       = @cToLOC
         ,@cToId        = @cToID
         ,@cWaveKey     = @cWaveKey
         ,@cMoveRefKey  = @cMoveRefKey OUTPUT
         ,@nErrNo       = @nErrNo      OUTPUT
         ,@cErrMsg      = @cErrMsg     OUTPUT            
            
      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @cMoveRefKey = ''
      BEGIN
         UPDATE dbo.Replenishment WITH (ROWLOCK) SET
            QTY = @nActQTY,
            ToLOC = @cToLOC,
            ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END, 
            Confirmed = 'Y'  
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 117053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- If MoveRefKey not blank, meaning pickdetail 
         -- already moved stock. No need move again when confirm replen
         UPDATE dbo.Replenishment WITH (ROWLOCK) SET
            QTY = @nActQTY,
            ToLOC = @cToLOC,
            ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END, 
            Confirmed = 'Y',
            ArchiveCop = NULL  
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 117059
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
      END
   END

   COMMIT TRAN rdt_Replenish_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Replenish_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
      --INSERT INTO traceinfo (tracename, TimeIn, Col1, col2, col3, col4) VALUES
      --('510', GETDATE(), @cReplenKey, @nQtyAvl, @nQtyOnHand, @nQty)
END

GO