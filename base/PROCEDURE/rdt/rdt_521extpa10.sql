SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA10                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-08-19   1.0  James    WMS-17795. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA10] (
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

   DECLARE @cPutAwayZone   NVARCHAR( 10)
   DECLARE @cItemClass     NVARCHAR( 10)
   DECLARE @cBUSR7         NVARCHAR( 30)
   DECLARE @cUDF01         NVARCHAR( 60)
   DECLARE @cUDF02         NVARCHAR( 60)
   DECLARE @cUDF03         NVARCHAR( 60)
   DECLARE @cUDF04         NVARCHAR( 60)
   DECLARE @cUDF05         NVARCHAR( 60)
   
   SELECT @cItemClass = ItemClass,
          @cBUSR7 = BUSR7
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   Sku = @cSKU
   
   SELECT 
      @cUDF01 = UDF01,
      @cUDF02 = UDF02,
      @cUDF03 = UDF03,
      @cUDF04 = UDF04,
      @cUDF05 = UDF05
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'PAZoneDiv'
   AND   Code = @cBUSR7
   AND   Storerkey = @cStorerKey

   DECLARE @tPAZone TABLE ( PutawayZone NVARCHAR( 10))
   INSERT INTO @tPAZone (PutawayZone) VALUES (@cUDF01)
   INSERT INTO @tPAZone (PutawayZone) VALUES (@cUDF02)
   INSERT INTO @tPAZone (PutawayZone) VALUES (@cUDF03)
   INSERT INTO @tPAZone (PutawayZone) VALUES (@cUDF04)
   INSERT INTO @tPAZone (PutawayZone) VALUES (@cUDF05)

   -- Find friend
   SELECT TOP 1   
      @cSuggestedLOC = LOC.LOC  
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.Sku)  
   WHERE LOC.Facility = @cFacility  
   AND   LOC.LOC <> @cLOC  
   AND   LLI.StorerKey = @cStorerKey  
   AND   SKU.ItemClass = @cItemClass  
   AND   SKU.BUSR7 = @cBUSR7
   AND   EXISTS ( SELECT 1 FROM @tPAZone PAZone WHERE LOC.PutawayZone = PAZone.PutawayZone AND PAZone.PutawayZone <> '')
   GROUP BY LOC.LogicalLocation, LOC.Loc  
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
   ORDER BY LOC.LogicalLocation, LOC.Loc  
   
   -- Find empty loc
   IF ISNULL( @cSuggestedLOC, '') = ''
   BEGIN
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
      WHERE LOC.Facility = @cFacility
         AND LOC.LOC <> @cLoc
         AND   EXISTS ( SELECT 1 FROM @tPAZone PAZone WHERE LOC.PutawayZone = PAZone.PutawayZone AND PAZone.PutawayZone <> '')
         AND LOC.STATUS = 'OK'
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING ISNULL(SUM(LLI.QTY+LLI.PendingMoveIn),0)  = 0 
      ORDER BY LOC.LogicalLocation, LOC.Loc
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