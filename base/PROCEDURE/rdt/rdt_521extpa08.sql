SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA08                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-08-19   1.0  James    WMS-17702. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA08] (
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
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,  
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    
   DECLARE @cLottable02     NVARCHAR( 18) 
   DECLARE @cLottable03     NVARCHAR( 18) 
   DECLARE @dLottable04     DATETIME

   SELECT 
      @cLottable02 = Lottable02,
      @cLottable03 = Lottable03,
      @dLottable04 = Lottable04
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @cLOT
   
   -- Find a friend with max QTY of same Lottable01, Lottable02
   SELECT TOP 1 
      @cSuggestedLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cLOC
   AND   LOC.LocationCategory = 'BULK'
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   AND   LA.Lottable02 = @cLottable02
   AND   LA.Lottable03 = @cLottable03
   AND   LA.Lottable04 = @dLottable04
   GROUP BY LOC.LOC
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) DESC, LOC.Loc
   
   IF ISNULL( @cSuggestedLOC, '') = ''
   BEGIN
      -- Find empty LOC 
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @cFacility
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LogicalLocation, LOC.LOC 
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
      AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC 
   END

   IF ISNULL( @cSuggestedLOC, '') <> ''
      -- Lock SuggestedLOC  
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
         ,@cLOC  
         ,@cID   
         ,@cSuggestedLOC  
         ,@cStorerKey  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
         ,@cSKU        = @cSKU  
         ,@nPutawayQTY = @nQTY     
         ,@cUCCNo      = @cUCC  
         ,@cFromLOT    = @cLOT  
         ,@nPABookingKey = @nPABookingKey OUTPUT
         
   Quit:
END

GO