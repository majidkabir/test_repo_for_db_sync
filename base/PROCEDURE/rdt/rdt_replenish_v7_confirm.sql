SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_Replenish_V7_Confirm                            */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 25-03-2018 1.0  James      WMS-8254 Created                          */
/* 2022-08-23 1.1  Ung        WMS-20562 Add UCC                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Replenish_V7_Confirm] (
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
   ,@cUCCNo          NVARCHAR( 20)
   ,@cToLOC          NVARCHAR( 10)
   ,@cToID           NVARCHAR( 18)
   ,@cLottableCode   NVARCHAR( 30) OUTPUT
   ,@cLottable01     NVARCHAR( 18) OUTPUT
   ,@cLottable02     NVARCHAR( 18) OUTPUT
   ,@cLottable03     NVARCHAR( 18) OUTPUT
   ,@dLottable04     DATETIME      OUTPUT
   ,@dLottable05     DATETIME      OUTPUT
   ,@cLottable06     NVARCHAR( 30) OUTPUT
   ,@cLottable07     NVARCHAR( 30) OUTPUT
   ,@cLottable08     NVARCHAR( 30) OUTPUT
   ,@cLottable09     NVARCHAR( 30) OUTPUT
   ,@cLottable10     NVARCHAR( 30) OUTPUT
   ,@cLottable11     NVARCHAR( 30) OUTPUT
   ,@cLottable12     NVARCHAR( 30) OUTPUT
   ,@dLottable13     DATETIME      OUTPUT
   ,@dLottable14     DATETIME      OUTPUT
   ,@dLottable15     DATETIME      OUTPUT
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
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Replenish_V7_Confirm -- For rollback or commit only our own transaction

   IF @cReplenBySKUQTY = '1'
   BEGIN
      DECLARE @nQTY     INT
      DECLARE @nBal_QTY INT
      DECLARE @nRPL_QTY INT
      DECLARE @nAVL_QTY INT
      DECLARE @cLOT     NVARCHAR( 10)

      SET @nBal_QTY = @nActQTY

      DECLARE @curPD CURSOR
      SET @curPD = CURSOR FOR
         SELECT ReplenishmentKey, LOT, QTY
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND FromLOC = @cFromLOC
            AND ID = @cFromID
            AND SKU = @cSKU
            AND Confirmed = 'N'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cReplenKey, @cLOT, @nRPL_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get QTY avail
         SELECT @nAVL_QTY = ISNULL( SUM( QTY
            - CASE WHEN @cMoveQTYAlloc = '1' THEN 0 ELSE QTYAllocated END
            - QTYPicked), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID

         -- Make sure replen QTY not more then avail QTY
         IF @nRPL_QTY > @nAVL_QTY
            SET @nRPL_QTY = @nAVL_QTY

         -- Calc QTY to replen
         IF @nRPL_QTY > @nBal_QTY
            SET @nQTY = @nBal_QTY
         ELSE
            SET @nQTY = @nRPL_QTY

         UPDATE dbo.Replenishment WITH (ROWLOCK) SET
            QTY = @nQTY,
            ToLOC = @cToLOC,
            ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END,
            Confirmed = 'Y'
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 141551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END

         -- Reduce balance
         SET @nBal_QTY = @nBal_QTY - @nQTY
         IF @nBal_QTY <= 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cReplenKey, @cLOT, @nRPL_QTY
      END

      -- Check offset error
      IF @nBal_QTY <> 0
      BEGIN
         SET @nErrNo = 141552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Error
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      UPDATE dbo.Replenishment WITH (ROWLOCK) SET
         QTY = @nActQTY,
         ToLOC = @cToLOC,
         ToID = CASE WHEN @cToID <> '' THEN @cToID ELSE ToID END,
         Confirmed = 'Y'
      WHERE ReplenishmentKey = @cReplenKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 141553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
         GOTO RollBackTran
      END
      
      IF @cUCCNo <> ''
      BEGIN
         DECLARE @cLoseID NVARCHAR(1)
         SELECT @cLoseID = LoseID FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC
         
         UPDATE dbo.UCC WITH (ROWLOCK) SET
            Status = '6',
            LOC = @cToLOC, 
            ID = CASE WHEN @cLoseID = '1' THEN '' ELSE @cToID END, 
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCCNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 141554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCC Fail
            GOTO RollBackTran
         END
      END
   END

   COMMIT TRAN rdt_Replenish_V7_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Replenish_V7_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO