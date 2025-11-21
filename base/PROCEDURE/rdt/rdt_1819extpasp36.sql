SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP36                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 25-Jun-2021  1.0  yeekung     WMS-17243. Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP36] (
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
  
   DECLARE @cUCC  NVARCHAR( 20),   
           @cLOT  NVARCHAR( 10),   
           @cLOC  NVARCHAR( 10),   
           @cSKU  NVARCHAR( 20),  
           @cPAType  NVARCHAR( 10),  
           @cPAStrategyKey NVARCHAR( 10),
           @cSKUPutawayZone NVARCHAR(10),
           @cSKUstyle NVARCHAR(20),
           @cPutawayzone NVARCHAR(20)  
  
   -- Check if pallet has mix sku  
   IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
                   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
                   WHERE LLI.StorerKey = @cStorerKey  
                   AND   LLI.LOC = @cFromLoc   
                   AND   LLI.ID = @cID  
                   GROUP BY LLI.ID   
                   HAVING COUNT( DISTINCT LLI.SKU + LA.Lottable01 + LA.Lottable03) > 1)  
      SET @cPAType = 'PALLET' -- no mix sku, use pallet putaway strategy  
   ELSE  
      SET @cPAType = 'CASE'   -- mix sku in the pallet, use case putaway strategy  

-- Get sku from pallet
   SELECT  
      @cSKU = LLI.SKU
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cFromLOC
   AND   LLI.ID = @cID
   AND   ( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
         ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   GROUP BY LLI.Lot, LLI.Sku
   
   SELECT TOP 1  @cSKUPutawayZone = SKU.PutawayZone,
          @cSKUstyle = sku.Style
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.SKU = @cSKU

   IF @cPAType = 'PALLET'
   BEGIN
      SELECT TOP 1 @cSuggLOC=lli.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  JOIN
      LOC LOC WITH (NOLOCK) ON LLI.loc=LOC.loc
      WHERE lli.sku=@csku
      AND LLI.StorerKey = @cStorerKey
      AND   LLI.LOC <> @cFromLOC
      AND loc.LocationType='OTHER'
      AND LOC.PutawayZone=@cSKUPutawayZone
      AND   LOC.Facility = @cFacility
      GROUP BY Loc.PALogicalLoc, LLI.Loc
      ORDER BY Loc.PALogicalLoc, LLI.Loc

      IF @@ROWCOUNT=0
      BEGIN
         SELECT TOP 1 @cSuggLOC=lli.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  JOIN
         LOC LOC WITH (NOLOCK) ON LLI.loc=LOC.loc JOIN
         sku sku WITH (NOLOCK) ON LLI.sku=sku.sku
         WHERE sku.Style=@cSKUstyle
         AND LLI.StorerKey = @cStorerKey
         AND   LLI.LOC <> @cFromLOC
         AND LOC.PutawayZone=@cSKUPutawayZone
         AND loc.LocationType='OTHER'
         AND   LOC.Facility = @cFacility
         GROUP BY Loc.PALogicalLoc, LLI.Loc,sku.Style
         ORDER BY Loc.PALogicalLoc, LLI.Loc,sku.Style

         IF @@ROWCOUNT =0
         BEGIN
            SELECT TOP 1 @cSuggLOC=lli.LOC
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  JOIN
            LOC LOC WITH (NOLOCK) ON LLI.loc=LOC.loc JOIN
            sku sku WITH (NOLOCK) ON LLI.sku=sku.sku
            WHERE sku.PutawayZone=@cSKUPutawayZone
            AND loc.PutawayZone=@cSKUPutawayZone
            AND LLI.StorerKey = @cStorerKey
            AND   LLI.LOC <> @cFromLOC
            AND loc.LocationType='OTHER'
            AND   LOC.Facility = @cFacility
            GROUP BY Loc.PALogicalLoc, LLI.Loc,sku.PutawayZone
            ORDER BY Loc.PALogicalLoc, LLI.Loc,sku.PutawayZone
         END
      END

   END
   ELSE IF @cPAType = 'CASE'
   BEGIN
      
      IF @@ROWCOUNT=0
      BEGIN
         SELECT TOP 1 @cSuggLOC=lli.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  JOIN
         LOC LOC WITH (NOLOCK) ON LLI.loc=LOC.loc JOIN
         sku sku WITH (NOLOCK) ON LLI.sku=sku.sku
         WHERE sku.Style=@cSKUstyle
         AND LLI.StorerKey = @cStorerKey
         AND   LLI.LOC <> @cFromLOC
         AND LOC.PutawayZone=@cSKUPutawayZone
         AND loc.LocationType='OTHER'
         AND   LOC.Facility = @cFacility
         GROUP BY Loc.PALogicalLoc, LLI.Loc,sku.Style
         ORDER BY Loc.PALogicalLoc, LLI.Loc,sku.Style

         IF @@ROWCOUNT =0
         BEGIN
            SELECT TOP 1 @cSuggLOC=lli.LOC
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  JOIN
            LOC LOC WITH (NOLOCK) ON LLI.loc=LOC.loc JOIN
            sku sku WITH (NOLOCK) ON LLI.sku=sku.sku
            WHERE sku.PutawayZone=@cSKUPutawayZone
            AND LLI.StorerKey = @cStorerKey
            AND   LLI.LOC <> @cFromLOC
            AND LOC.PutawayZone=@cSKUPutawayZone
            AND loc.LocationType='OTHER'
            AND   LOC.Facility = @cFacility
            GROUP BY Loc.PALogicalLoc, LLI.Loc,sku.PutawayZone
            ORDER BY Loc.PALogicalLoc, LLI.Loc,sku.PutawayZone
         END
      END
   END
  
      
   DECLARE @nTranCount  INT  
  
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1819ExtPASP36 -- For rollback or commit only our own transaction  
  
   IF ISNULL( @cSuggLOC, '') =''  
   BEGIN  
      SET @nErrNo = 171601  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggested LOC  
      GOTO RollBackTran  
   END  

   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1819ExtPASP36 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
  
END


GO