SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP07                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 02-05-2017  1.0  Ung      WMS-1797 Created                           */
/* 07-08-2017  1.1  Ung      WMS-1797 Change putaway logic for shuttle  */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP07] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cPalletType       NVARCHAR(10)
   DECLARE @cPAType           NVARCHAR(10)
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cExtField01       NVARCHAR(30)
   DECLARE @cReceiptKey       NVARCHAR(10)
   DECLARE @cSKUPutawayZone   NVARCHAR(10)
   DECLARE @nPalletCnt        INT
   DECLARE @nPalletQTY        INT
   DECLARE @nExpPallet        INT
   DECLARE @nQTYExpected      INT

   SET @nTranCount = @@TRANCOUNT
   SET @cSuggLOC = ''
   
   -- Get pallet SKU
   SELECT TOP 1 
      @cSKU = SKU, 
      @cLOT = LOT
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LLI.LOC = @cFromLOC 
      AND LLI.ID = @cID 
      AND LLI.QTY > 0

   -- Check multi SKU pallet
   IF EXISTS( SELECT TOP 1 1 
      FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.LOC = @cFromLOC 
         AND LLI.ID = @cID 
         AND LLI.QTY > 0
         AND (LLI.StorerKey <> @cStorerKey OR LLI.SKU <> @cSKU))
   BEGIN
      SET @nErrNo = 108501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUPallet
      SET @nErrNo = -1
      GOTO Quit
   END
   
   -- Get SKU info
   DECLARE @cSerialNoCapture NVARCHAR(1)
   SELECT @cSerialNoCapture = SerialNoCapture
   FROM SKU WITH (NOLOCK) 
   WHERE SKU.StorerKey = @cStorerKey 
      AND SKU.SKU = @cSKU
      
   -- S&A (spare parts and accessories)
   IF @cSerialNoCapture <> '1'
   BEGIN
      -- Suggest LOC
      EXEC @nErrNo = [dbo].[nspRDTPASTD]
           @c_userid          = 'RDT'
         , @c_storerkey       = @cStorerKey
         , @c_lot             = ''
         , @c_sku             = ''
         , @c_id              = @cID
         , @c_fromloc         = @cFromLOC
         , @n_qty             = 0
         , @c_uom             = '' -- not used
         , @c_packkey         = '' -- optional, if pass-in SKU
         , @n_putawaycapacity = 0
         , @c_final_toloc     = @cSuggLOC          OUTPUT
         , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
         , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
   END

   -- FG (finish goods)
   ELSE
   BEGIN
      -- Get SKU info
      SELECT 
         @cSKUPutawayZone = PutawayZone, 
         @nPalletCnt = CAST( Pallet AS INT)
      FROM SKU WITH (NOLOCK) 
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cSKU
   
      -- Get pallet QTY
      SELECT @nPalletQTY = ISNULL( SUM( LLI.QTY - LLI.QTYPicked), 0)
      FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.LOC = @cFromLOC 
         AND LLI.ID = @cID 
         AND LLI.QTY > 0
   
      -- Determine pallet type
      IF @nPalletQTY = @nPalletCnt
         SET @cPalletType = 'FULL'
      ELSE 
         SET @cPalletType = 'PARTIAL'
   
      -- Step 1. Putaway into shuttle (full pallet only)
      IF @cPalletType = 'FULL'
      BEGIN
         -- Get LOC info (entire shuttle is setup with same MinPalletToFill)
         DECLARE @nMinPalletToFill INT
         SELECT TOP 1
            @nMinPalletToFill = CAST( ChargingPallet AS INT)
         FROM LOC WITH (NOLOCK)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'SHUTTLE'
         
         -- Find a friend (SKU, LOT)
         SELECT TOP 1 
            @cSuggLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'SHUTTLE'
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.LOT = @cLOT
            AND ((LLI.QTY - LLI.QTYPicked > 0) OR (LLI.PendingMoveIn > 0))
         GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet
         HAVING COUNT( DISTINCT LLI.ID) < LOC.MaxPallet
         ORDER BY LOC.PALogicalLoc, LOC.LOC
         
         -- Find empty LOC
         IF @cSuggLOC = ''
         BEGIN
            -- Get ASN
            SELECT TOP 1 
               @cReceiptKey = R.ReceiptKey
            FROM Receipt R WITH (NOLOCK)
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
            WHERE R.StorerKey = @cStorerKey
               AND R.ASNStatus < '9'
               AND RD.ToID = @cID
      
            -- Get Expected in ASN
            SELECT @nQTYExpected = ISNULL( SUM( QTYExpected), 0)
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Calc expected total pallet
            SELECT @nExpPallet = @nQTYExpected / @nPalletCnt
            
            -- Get pallet already booked or putaway
            DECLARE @nPalletPutaway INT
            SELECT @nPalletPutaway = COUNT( DISTINCT RD.ToID)
            FROM ReceiptDetail RD WITH (NOLOCK) 
               JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (RD.StorerKey = LLI.StorerKey AND RD.SKU = LLI.SKU AND RD.ToID = LLI.ID)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND RD.ToID <> ''
               AND RD.StorerKey = @cStorerKey
               AND RD.SKU = @cSKU
               AND LOC.Facility = @cFacility
               AND LOC.LocationCategory = 'SHUTTLE'
            
            -- Minus out pallet booked or putaway
            SET @nExpPallet = @nExpPallet - @nPalletPutaway
            
            -- Remain pallet meet min pallet fill for shuttle
            IF @nExpPallet >= @nMinPalletToFill
               SELECT TOP 1 
                  @cSuggLOC = LOC.LOC
               FROM LOC WITH (NOLOCK)
                  LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LOC.LocationCategory = 'SHUTTLE'
               GROUP BY LOC.PALogicalLoc, LOC.LOC
               HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
                  AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
               ORDER BY LOC.PALogicalLoc, LOC.LOC
         END
      END

      -- Step 2. Find empty location
      IF @cSuggLOC = ''
         SELECT TOP 1 
            @cSuggLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cSKUPutawayZone
         GROUP BY LOC.PALogicalLoc, LOC.LOC
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0  
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LOC.PALogicalLoc, LOC.LOC
   END
   
   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = -1
      GOTO Quit
   END

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP07 -- For rollback or commit only our own transaction
      
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_1819ExtPASP07 -- Only commit change made here
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP07 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO