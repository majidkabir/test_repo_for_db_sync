SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA06                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-01-25   1.0  James    WMS-16184. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA06] (
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

    
   DECLARE @cLottable01     NVARCHAR( 18) 
   DECLARE @cLottable02     NVARCHAR( 18) 
   DECLARE @cPAStrategyKey NVARCHAR( 10)
   DECLARE @cLocationType  NVARCHAR( 10)
   
   SELECT @cPAStrategyKey = ISNULL( Short, '')
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND StorerKey = @cStorerKey

   SELECT @cLocationType = LocationTypeRestriction01
   FROM dbo.PutawayStrategyDetail WITH (NOLOCK)
   WHERE PutawayStrategyKey = @cPAStrategyKey
   
   IF @@ROWCOUNT <> 0
   BEGIN
      SELECT @cLottable01 = Lottable01,
             @cLottable02 = Lottable02
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
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND   LA.Lottable01 = @cLottable01
      AND   LA.Lottable02 = @cLottable02
      AND   LOC.LocationType = @cLocationType
      GROUP BY LOC.LOC
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
      ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) DESC, LOC.Loc
   END
   
   IF ISNULL( @cSuggestedLOC, '') = ''
   BEGIN
      SET @cSuggestedLOC = ''
      SET @nErrNo = -1
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