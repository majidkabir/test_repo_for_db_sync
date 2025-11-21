SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580SKULabelSP02                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2015-04-07 1.0  Ung      SOS318064 Created                              */
/* 2016-04-19 1.1  Ung      OS00023393 Fix suggest empty LOC not in zone   */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1580SKULabelSP02] (
   @nMobile            INT,
   @nFunc              INT,
   @nStep              INT,
   @cLangCode          NVARCHAR( 3),
   @cStorerKey         NVARCHAR( 15),
   @cDataWindow        NVARCHAR( 60),
   @cPrinter           NVARCHAR( 10),
   @cTargetDB          NVARCHAR( 20),
   @cReceiptKey        NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR(  5),
   @nQTY               INT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount   INT
   DECLARE @cUserName    NVARCHAR( 18)
   DECLARE @bSuccess     INT
   DECLARE @cFacility    NVARCHAR( 5)
   DECLARE @cSKU         NVARCHAR( 20)
   DECLARE @cSuggToAisle NVARCHAR( 10)
   DECLARE @cSuggToLOC   NVARCHAR( 10)
   DECLARE @cFromLOC     NVARCHAR( 10)
   DECLARE @cFromID      NVARCHAR( 18)
   DECLARE @cLOT         NVARCHAR( 10)
   DECLARE @cLottable01  NVARCHAR( 18)
   DECLARE @cLottable02  NVARCHAR( 18)
   DECLARE @cLottable03  NVARCHAR( 18)
   DECLARE @dLottable04  DATETIME
   DECLARE @dLottable05  DATETIME
   DECLARE @cLottable06  NVARCHAR( 30)
   DECLARE @cLottable07  NVARCHAR( 30)
   DECLARE @cLottable08  NVARCHAR( 30)
   DECLARE @cLottable09  NVARCHAR( 30)
   DECLARE @cLottable10  NVARCHAR( 30)
   DECLARE @cLottable11  NVARCHAR( 30)
   DECLARE @cLottable12  NVARCHAR( 30)
   DECLARE @dLottable13  DATETIME 
   DECLARE @dLottable14  DATETIME 
   DECLARE @dLottable15  DATETIME 

   DECLARE @cReceiptLoc  NVARCHAR( 10) -- (james01)
   
   DECLARE @tPutawayZone TABLE 
   (
      PutawayZone NVARCHAR(10)
   )
   
   SET @nTranCount = @@TRANCOUNT
   SET @cUserName = SUSER_SNAME()
   
   -- Get ReceiptDetail info
   SELECT 
      @cSKU = SKU, 
      @cFromLOC = ToLOC, 
      @cFromID = ToID,
      @cLottable01 = Lottable01,
      @cLottable02 = Lottable02,
      @cLottable03 = Lottable03,
      @dLottable04 = Lottable04,
      @dLottable05 = Lottable05,
      @cLottable06 = Lottable06,
      @cLottable07 = Lottable07,
      @cLottable08 = Lottable08,
      @cLottable09 = Lottable09,
      @cLottable10 = Lottable10,
      @cLottable11 = Lottable11,
      @cLottable12 = Lottable12,
      @dLottable13 = Lottable13,
      @dLottable14 = Lottable14,
      @dLottable15 = Lottable15
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cReceiptLineNumber

   IF @@ROWCOUNT = 0
      RETURN

   -- (james01)
   SELECT @cReceiptLoc = ISNULL( ReceiptLoc, '')
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   -- Get Receipt info
   SELECT @cFacility = Facility FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Get PutawayZone
   INSERT INTO @tPutawayZone (PutawayZone)
   SELECT Code
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'PTZONE'
      AND StorerKey = @cStorerKey
      AND Short = @cFacility
      AND Code <> ''

   SET @cSuggToLOC = ''

   -- Find a friend with actual stock
   IF @cSuggToLOC = ''
      SELECT TOP 1
         @cSuggToLOC = LOC.LOC
      FROM SKUxLOC SL WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone AND LOC.PutawayZone <> '')
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SL.QTY - SL.QTYPicked > 0
      ORDER BY SL.QTY - SL.QTYPicked

   -- Find a friend with pending move in
   IF @cSuggToLOC = ''
      SELECT TOP 1
         @cSuggToLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone AND LOC.PutawayZone <> '')
      WHERE LOC.Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LLI.PendingMoveIn > 0
      ORDER BY LLI.PendingMoveIn

   -- If SKU.ReceiptLoc is not null and the loc in @PTZone, then find the SKU.ReceiptLoc
   IF @cSuggToLOC = '' AND @cReceiptLoc <> ''
      SELECT @cSuggToLOC = LOC.LOC 
      FROM LOC LOC WITH (NOLOCK) 
      JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone AND LOC.PutawayZone <> '')
      WHERE LOC.Facility = @cFacility
      AND   LOC.LOC = @cReceiptLoc
      
   -- Find empty LOC
   IF @cSuggToLOC = ''
      SELECT TOP 1
         @cSuggToLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone AND LOC.PutawayZone <> '')
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
      GROUP BY LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         
   /*-------------------------------------------------------------------------------
   
                              Create LOT if not yet receive

   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1580SKULabelSP02 -- For rollback or commit only our own transaction
      
      -- Stamp receiving date (to get LOT in below)
      IF ISNULL( @dLottable05, 0) = 0
      BEGIN
         -- NULL and 1900-01-01 generate different LOT, use NULL
         SET @dLottable05 = NULL
         
         -- Get SKU info
         IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND Lottable05Label = 'RCP_DATE')
         BEGIN
            SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120)
            UPDATE ReceiptDetail SET
               Lottable05 = @dLottable05
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cReceiptLineNumber
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
         END
      END

      -- LOT lookup
      SET @cLOT = ''
      EXECUTE dbo.nsp_LotLookUp @cStorerKey, @cSKU
        , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
        , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
        , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
        , @cLOT      OUTPUT
        , @bSuccess  OUTPUT
        , @nErrNo    OUTPUT
        , @cErrMsg   OUTPUT

      -- Create LOT if not exist
      IF @cLOT IS NULL
      BEGIN
         EXECUTE dbo.nsp_LotGen @cStorerKey, @cSKU
            , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05
            , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10
            , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
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
            BEGIN
               SET @nErrNo = 91351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOT Fail
               GOTO RollbackTran
            END
         END
      END

      -- Create ToID if not exist
      IF @cFromID <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cFromID)
         BEGIN
            INSERT INTO ID (ID) VALUES (@cFromID)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 91352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ID Fail
               GOTO RollbackTran
            END
         END
      END

      -- Book location in RFPutaway
      IF EXISTS( SELECT TOP 1 1 
         FROM RFPutaway WITH (NOLOCK) 
         WHERE LOT = @cLOT
            AND FromLOC = @cFromLOC
            AND FromID = @cFromID
            AND SuggestedLOC = @cSuggToLOC)
      BEGIN
         UPDATE RFPutaway SET
            QTY = QTY + 1
         WHERE LOT = @cLOT
            AND FromLOC = @cFromLOC
            AND FromID = @cFromID
            AND SuggestedLOC = @cSuggToLOC
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         -- Update RFPutaway
         INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)
         VALUES (@cStorerKey, @cSKU, @cLOT, @cFromLOC, @cFromID, @cSuggToLOC, @cFromID, @cUserName, 1, '')
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollbackTran
         END
      END
      
      -- Book location in LOTxLOCxID
      IF EXISTS (SELECT 1 
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @cSuggToLOC
            AND ID = @cFromID)
      BEGIN
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET 
            PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + 1 ELSE 0 END
         WHERE LOT = @cLOT
            AND LOC = @cSuggToLOC
            AND ID  = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 91353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)
         VALUES (@cLOT, @cSuggToLOC, @cFromID, @cStorerKey, @cSKU, 1)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 91354
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LLI Fail
            GOTO RollbackTran
         END      
      END
      
      COMMIT TRAN rdt_1580SKULabelSP02
   END

   IF @cSuggToLOC = ''
   BEGIN
      SET @cSuggToLOC = 'NO LOC'
      SET @cSuggToAisle = ''
   END
   ELSE
      SELECT @cSuggToAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @cSuggToLOC


   IF rdt.RDTGetConfig( @nFunc, 'PrintPASKULabel', @cStorerKey) = '1'
   BEGIN
      -- Insert print job
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'SKULABEL',       -- ReportType
         'PRINT_SKULABEL', -- PrintJobName
         @cDataWindow,
         @cPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cReceiptKey,
         @cReceiptLineNumber,
         @nQTY, 
         @cSuggToLOC
   END
   ELSE
   BEGIN
      DECLARE @cErrMsg1 NVARCHAR(20)
      DECLARE @cErrMsg2 NVARCHAR(20)
      SET @cErrMsg1 = rdt.rdtgetmessage( 91355, @cLangCode, 'DSP')
      SET @cErrMsg2 = rdt.rdtgetmessage( 91356, @cLangCode, 'DSP')
      SET @cErrMsg1 = RTRIM( @cErrMsg1) + @cSuggToLOC
      SET @cErrMsg2 = RTRIM( @cErrMsg2) + @cSuggToAisle
      
      -- Display on screen
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
      SET @nErrNo = 0
      SET @cErrMsg = ''
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1580SKULabelSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO