SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Receiving_Label_10                                 */
/* Purpose: SKU label                                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS288082 Created                              */
/***************************************************************************/

CREATE PROC [dbo].[isp_Receiving_Label_10] (
   @cReceiptKey         NVARCHAR(20),
   @cReceiptLineNumber  NVARCHAR(5),
   @nQTY                INT, 
   @cPrintType          NVARCHAR(10) = ''
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @nErrNo      INT
   DECLARE @cErrMsg     NVARCHAR( 20)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cAltSKU     NVARCHAR( 20)
   DECLARE @cPickLOC    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cLottable02 NVARCHAR( 18)
   DECLARE @cLottable03 NVARCHAR( 18)
   DECLARE @dLottable04 DATETIME
   DECLARE @dLottable05 DATETIME
   DECLARE @cPutawayZone NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cUserName = LEFT( SUSER_SNAME(), 18)
   SET @cPickLOC = ''

   -- Get Receipt info
   SELECT
      @cStorerKey = StorerKey,
      @cFacility = Facility
   FROM Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   IF @@ROWCOUNT = 0
      RETURN

   -- Get ReceiptDetail info
   SELECT
      @cSKU = SKU,
      @cFromLOC = ToLOC,
      @cFromID = ToID,
      @cLottable01 = Lottable01,
      @cLottable02 = Lottable02,
      @cLottable03 = Lottable03,
      @dLottable04 = Lottable04,
      @dLottable05 = Lottable05
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber

   IF @@ROWCOUNT = 0
      RETURN

   -- Get SKU info
   SELECT
      @cAltSKU = AltSKU, 
      @cPutawayZone = PutawayZone
   FROM SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Find a friend with actual stock
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM SKUxLOC SL WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LocationCategory = 'RESALE'
         AND SL.QTY - SL.QTYPicked > 0

   -- Find a friend with pending move in
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LocationCategory = 'RESALE'
         AND LLI.PendingMoveIn > 0

   -- Find empty LOC
   IF @cPickLOC = ''
      SELECT TOP 1
         @cPickLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationCategory = 'RESALE'
         AND LOC.PutawayZone = @cPutawayZone
      GROUP BY LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0

   /*-------------------------------------------------------------------------------
   
                           Create LOT if not yet receive

   -------------------------------------------------------------------------------*/
   IF @cPickLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN isp_Receiving_Label_10 -- For rollback or commit only our own transaction
      
      -- Stamp receiving date (to get LOT in below)
      IF @dLottable05 IS NULL
      BEGIN
         SET @dLottable05 = CAST( CONVERT( NVARCHAR( 10), GETDATE(), 120) AS DATETIME)
         UPDATE ReceiptDetail SET
            Lottable05 = @dLottable05
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         IF @@ERROR <> 0
            GOTO RollbackTran
      END
      
      -- LOT lookup
      SET @cLOT = ''
      EXECUTE dbo.nsp_LotLookUp
          @cStorerKey
        , @cSKU
        , @cLottable01
        , @cLottable02
        , @cLottable03
        , @dLottable04
        , @dLottable05
        , @cLOT      OUTPUT
        , @bSuccess  OUTPUT
        , @nErrNo    OUTPUT
        , @cErrMsg   OUTPUT

      -- Create LOT if not exist
      IF @cLOT IS NULL
      BEGIN
         EXECUTE dbo.nsp_LotGen
            @cStorerKey
          , @cSKU
          , @cLottable01
          , @cLottable02
          , @cLottable03
          , @dLottable04
          , @dLottable05
          , @cLOT     OUTPUT
          , @bSuccess OUTPUT
          , @nErrNo   OUTPUT
          , @cErrMsg  OUTPUT
         IF @bSuccess <> 1
            GOTO RollbackTran

         IF NOT EXISTS( SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @cLOT)
         BEGIN
            INSERT INTO LOT (LOT, StorerKey, SKU) VALUES (@cLOT, @cStorerKey, @cSKU)
            IF @@ERROR <> 0
               GOTO RollbackTran
         END
      END

      -- Create ToID if not exist
      IF @cFromID <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cFromID)
         BEGIN
            INSERT INTO ID (ID) VALUES (@cFromID)
            IF @@ERROR <> 0
               GOTO RollbackTran
         END
      END

      -- Book location if not booked
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM RFPutaway WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SuggestedLOC = @cPickLOC
            AND FromID = @cFromID)
            -- AND @cPrintType <> 'REPRINT' -- REPRINT don't need to rebook location
      BEGIN
         -- Update RFPutaway
         INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
         VALUES (@cStorerKey, @cSKU, @cLOT, @cFromLOC, @cFromID, @cPickLOC, @cFromID, @cUserName, @nQTY, '')
         IF @@ERROR <> 0
            GOTO RollbackTran
   
         -- Update PendingMoveIn
         IF EXISTS (SELECT 1 
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE LOT = @cLOT
               AND LOC = @cPickLOC
               AND ID = @cFromID)
         BEGIN
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET 
               PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @nQTY ELSE 0 END
            WHERE LOT = @cLOT
               AND LOC = @cPickLOC
               AND ID  = @cFromID
         END
         ELSE
         BEGIN
            INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
            VALUES (@cLOT, @cPickLOC, @cFromID, @cStorerKey, @cSKU, @nQTY)
         END            
         IF @@ERROR <> 0
            GOTO RollbackTran
      END

      COMMIT TRAN isp_Receiving_Label_10
   END

   IF @cPickLOC = ''
      SET @cPickLOC = 'NO LOC'

   SELECT @cSKU SKU, @cAltSKU AltSKU, @cPickLOC LOC, @cReceiptKey ReceiptKey, @cUserName UserName
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN isp_Receiving_Label_10 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO