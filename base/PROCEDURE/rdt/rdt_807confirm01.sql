SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_807Confirm01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 07-08-2018 1.0  James       WMS5639 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_807Confirm01] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cCartID    NVARCHAR( 10) 
   ,@cToLOC     NVARCHAR( 10)
   ,@cSKU       NVARCHAR( 20)
   ,@nTotalQTY  INT 
   ,@nActQTY    INT
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cFromLOC    NVARCHAR( 10) 
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @nExpQTY     INT
   DECLARE @nTotalBal   INT
   DECLARE @nQTY        INT
   DECLARE @nBal        INT
   DECLARE @nLLI_QTY    INT
   DECLARE @nRowRef     INT
   DECLARE @curPA       CURSOR
   DECLARE @curPending  CURSOR 
   DECLARE @cOverflowLOC NVARCHAR( 10)
   DECLARE @cConfirmSP   NVARCHAR( 20)
   DECLARE @cSQL         NVARCHAR( MAX)
   DECLARE @cSQLParam    NVARCHAR( MAX)
   DECLARE @cPA_SKU      NVARCHAR( 20)
   DECLARE @nRF_Qty      INT

   SET @nTranCount = @@TRANCOUNT
   SET @nTotalBal = @nTotalQTY
   SET @cOverflowLOC = ''
   
   -- Not putaway all QTY
   IF @nActQTY < @nTotalQTY AND @cSKU = ''
   BEGIN
   /*
      -- Get overflow LOC
      SET @cOverflowLOC = rdt.RDTGetConfig( @nFunc, 'OverflowLOC', @cStorerKey)
      IF @cOverflowLOC = '0'
      BEGIN
         SET @nErrNo = 57454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupOvrFlwLOC
         GOTO Quit
      END
      */
      SELECT @cPA_SKU = O_Field01
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SET @nActQTY = 0
   END
   ELSE
      SET @cPA_SKU = @cSKU

   -- Transaction at order level
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_807Confirm01 -- For rollback or commit only our own transaction

   -- Confirm entire LOC
   SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.FromLOC, R.FromID, R.LOT, R.ID, QTY
      FROM rdt.rdtPACartLog L WITH (NOLOCK)
         JOIN RFPutaway R WITH (NOLOCK) ON (L.ToteID = R.FromID)
   	WHERE L.CartID = @cCartID
         AND R.StorerKey = @cStorerKey
   	   AND R.SKU = @cPA_SKU
   	   AND R.SuggestedLOC = @cToLOC
   OPEN @curPA
   FETCH NEXT FROM @curPA INTO @cFromLOC, @cFromID, @cLOT, @cToID, @nExpQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Calc QTY to move
      IF @nActQTY >= @nExpQTY
      BEGIN
         SET @nQTY = @nExpQTY
         SET @nBal = 0
      END
      ELSE
      BEGIN
         SET @nQTY = @nActQTY
         SET @nBal = @nExpQTY - @nActQTY
      END
      
      -- Move to suggested LOC
      IF @nQTY > 0
      BEGIN
         -- Get inventory
         SELECT @nLLI_QTY = ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0)
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.LOT = @cLOT
            AND LLI.LOC = @cFromLOC
            AND LLI.ID = @cFromID
         
         -- Check enough QTY
         IF @nQTY > @nLLI_QTY
         BEGIN
            SET @nErrNo = 57451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAvlNotEnuf
            GOTO RollBackTran
         END
         
         -- Move
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdt_807Confirm01',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        = @cPA_SKU,
            @nQTY        = @nQTY, 
            @cFromLOT    = @cLOT
         IF @nErrNo <> 0
            GOTO RollBackTran
         
         SET @nTotalBal = @nTotalBal - @nQTY
         SET @nActQTY = @nActQTY - @nQTY
      END
      /*
      IF @nQTY = 0
      BEGIN
         -- Move to overflow LOC
         IF @nBal > 0 
         BEGIN
            -- Get inventory
            SELECT @nLLI_QTY = ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0)
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.LOT = @cLOT
               AND LLI.LOC = @cFromLOC
               AND LLI.ID = @cFromID
         
            -- Check enough QTY
            IF @nBal > @nLLI_QTY
            BEGIN
               SET @nErrNo = 57452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAvlNotEnuf
               GOTO RollBackTran
            END
         
            -- Overflow ID
            SET @cToID = 'T' + @cCartID
         
            -- Move
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT,
               @cSourceType = 'rdt_807Confirm01',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cOverflowLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cPA_SKU,
               @nQTY        = @nBal, 
               @cFromLOT    = @cLOT
            IF @nErrNo <> 0
               GOTO RollBackTran
         
            SET @nTotalBal = @nTotalBal - @nBal
         END
      END
      */
      -- LOTxLOCxID.PendingMoveIn only is deducted by Exceed base when stock move-in
      -- Manually deduct in RFPutaway
      SET @curPending = CURSOR FOR
         SELECT RowRef, Qty
         FROM dbo.RFPutaway WITH (NOLOCK)
         WHERE FromLOC = @cFromLOC
            AND FromID = @cFromID
            AND LOT    = @cLOT
            AND StorerKey = @cStorerKey
            AND SKU = @cPA_SKU
      OPEN @curPending
      FETCH NEXT FROM @curPending INTO @nRowRef, @nRF_Qty
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- short putaway, delete all from rfputaway
         IF @nQty = 0
         BEGIN
            DELETE dbo.RFPutaway WITH (ROWLOCK)
            WHERE RowRef = @nRowRef
         END
         ELSE
         BEGIN
            -- after putaway, deduct qty from rfputaway
            IF @nRF_Qty - @nQty > 0
               UPDATE dbo.RFPutaway WITH (ROWLOCK) SET 
                  Qty = Qty - @nQty
               WHERE RowRef = @nRowRef
            ELSE
               -- if it is last qty to putaway, delete from rfputaway
               DELETE dbo.RFPutaway WITH (ROWLOCK)
               WHERE RowRef = @nRowRef
         END

         IF @@ERROR <> 0
            GOTO RollBackTran

         FETCH NEXT FROM @curPending INTO @nRowRef, @nRF_Qty
      END

      FETCH NEXT FROM @curPA INTO @cFromLOC, @cFromID, @cLOT, @cToID, @nExpQTY
   END

   -- Check balance
   --IF @nTotalBal <> 0 OR @nActQTY <> 0
   --BEGIN
   --   SET @nErrNo = 57453
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
   --   GOTO RollBackTran
   --END

   COMMIT TRAN rdt_807Confirm01
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_807Confirm01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO