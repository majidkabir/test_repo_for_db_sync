SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA25                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-11-04  1.0  James    WMS-10987. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA25] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount     INT
   DECLARE @cSuggToLOC     NVARCHAR( 10) = ''
   DECLARE @cSuggLOT       NVARCHAR( 10) = ''
   DECLARE @cLottable03    NVARCHAR( 18)
   DECLARE @cBarcode       NVARCHAR( 60)
   DECLARE @cPutAwayZone   NVARCHAR( 10)
   DECLARE @nIsAltSKU      INT = 0
   DECLARE @nIsRetailSKU   INT = 0

   
   SET @nTranCount = @@TRANCOUNT

   SELECT @cBarcode = V_String11
   FROM RDT.RDTMOBREC AS r WITH (NOLOCK)
   WHERE r.Mobile = @nMobile

   SELECT @cPutAwayZone = PutawayZone
   FROM dbo.LOC WITH (NOLOCK)
   WHERE Loc = @cLOC
   AND   Facility = @cFacility
   
   -- Check the product category (KR/CN)
   SET @cSKU = ''
   SELECT TOP 1 @cSKU = SKU 
   FROM dbo.SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
   WHERE AltSku = @cBarcode 
   AND   StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SELECT TOP 1 @cSKU = SKU 
      FROM dbo.SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
      WHERE RetailSku = @cBarcode 
      AND   StorerKey = @cStorerKey
      
      IF @@ROWCOUNT = 1
         SET @nIsRetailSKU = 1
   END
   ELSE
       SET @nIsAltSKU = 1

   -- Get from lot# of the product category
   SELECT TOP 1 @cLOT = LLI.Lot 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
   JOIN dbo.LOC L WITH (NOLOCK) ON ( LLI.LOC = L.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.Loc = @cLOC
   AND   LLI.Id = @cID
   AND   LLI.Sku = @cSKU
   AND   ( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
   AND   L.Facility = @cFacility
   AND   (( @nIsAltSKU = 1 AND LA.Lottable03 = 'KR') OR ( @nIsRetailSKU = 1 AND LA.Lottable03 = 'CN'))
   ORDER BY 1
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = -1  
      GOTO Quit
   END

   -- Find a friend (same SKU, L03) with min QTY
   SELECT TOP 1 
      @cSuggToLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cLOC
   AND   LOC.LocLevel = '1'
   AND   LOC.PutawayZone = @cPutAwayZone
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   AND   (( @nIsAltSKU = 1 AND LA.Lottable03 = 'KR') OR ( @nIsRetailSKU = 1 AND LA.Lottable03 = 'CN'))
   GROUP BY LOC.LOC
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen), LOC.Loc

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = -1  
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA25 -- For rollback or commit only our own transaction

   IF @cSuggToLOC <> ''
   BEGIN
      SET @nErrNo = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA25 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA25 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO