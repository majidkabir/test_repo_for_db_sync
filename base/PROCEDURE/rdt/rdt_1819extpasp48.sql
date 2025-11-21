SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP48                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2024-04-17  1.0  yeekung   WMS-22299. Created                        */ 
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP48] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10) = ''  OUTPUT,
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
   
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPutawayZone   NVARCHAR(10)   
   DECLARE @nTranCount     INT
   DECLARE @cStyle         NVARCHAR( 20)
   DECLARE @cFromLOCQTY    INT
   DECLARE @cLogicalLoc    NVARCHAR(20)
   DECLARE @cSKUGroup      NVARCHAR(20)
   DECLARE @cSKUPutawayZone   NVARCHAR(10)   


   SELECT TOP 1 @cSKU = SKU.SKU, 
               @cStyle = SKU.Style,
               @cFromLOC = LLI.LOC,
               @cSKUGroup  = SKUGROUP,
               @cSKUPutawayZone = SKU.PutawayZone,
               @cFromLOCQTY = LLI.qty
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey
   WHERE ID = @cID
      AND SKU.Storerkey = @cStorerKey
   ORDER BY LLI.QTY DESC

   -- Find existing SKU
   SELECT TOP 1  
      @cSuggLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey  
   WHERE LOC.Facility = @cFacility  
      AND   LOC.LOC <> @cFromLOC  
      AND   LLI.StorerKey = @cStorerKey  
      AND   SKU.SKU = @cSKU  
      AND   LOC.LocationType    = 'OTHER'    
      AND   LOC.locationcategory IN ('RACK','SHELVING','BULK')  
   GROUP BY LA.lottable05, LOC.Loc , LOC.PutawayZone 
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
   ORDER BY MAX(LA.lottable05), SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen)  

   IF ISNULL(@cSuggLOC,'') = ''
   BEGIN

      -- Find same style for SKU
      SELECT TOP 1  
         @cSuggLOC = LOC.LOC 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey  
      WHERE LOC.Facility = @cFacility  
         AND   LOC.LOC <> @cFromLOC  
         AND   LLI.StorerKey = @cStorerKey  
         AND   (SKU.Style = @cStyle AND SKU.SkuGroup = @cSkuGroup)  
         AND   LOC.LocationType    in    ('OTHER')    
         AND   LOC.locationcategory IN ('RACK','SHELVING','BULK')  
         --AND   LOC.MaxQTY > 0  
      GROUP BY LA.lottable05, LOC.Loc  ,LOC.PutawayZone
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
      ORDER BY MAX(LA.lottable05), SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen)  
   END

   
   IF ISNULL(@cSuggLOC,'') = ''
   BEGIN
      -- Find style for first two digit SKU style
      SELECT TOP 1 @cPutawayZone = LOC.PutawayZone   
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)     
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)     
         JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey 
      WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cFromLOC
            AND   (SKU.Style like SUBSTRING(@cStyle,1,5) +'%'  AND SKU.SkuGroup = @cSKUGroup)
            AND   LOC.LocationType ='OTHER'      
            AND   LOC.LocationCategory in ('RACK','SHELVING','BULK')
      GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen + @cFromLOCQTY) > 0
      ORDER BY MAX(LA.lottable05),SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen),LOC.LogicalLocation, LOC.Loc,LOC.PutawayZone

      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM LOC LOC WITH (NOLOCK)
         LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
            AND   LOC.LocationType ='OTHER'      
            AND   LOC.LocationCategory in ('RACK','SHELVING','BULK')
            AND   LOC.PutawayZone = @cPutawayZone
      GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
      HAVING SUM( ISNULL(lli.Qty,0) -  ISNULL(lli.QtyAllocated,0)  -  ISNULL(lli.QtyPicked,0)  -  ISNULL(lli.QtyReplen,0) ) = 0
      ORDER BY LOC.LogicalLocation, LOC.Loc

      IF ISNULL(@cSuggLOC,'') = ''
      BEGIN
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM LOC LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cFromLOC
               AND   LOC.LocationType ='OTHER'      
               AND   LOC.LocationCategory in ('RACK','SHELVING','BULK')
               AND   LOC.PutawayZone = @cSKUPutawayZone
         GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
         HAVING SUM( ISNULL(lli.Qty,0) -  ISNULL(lli.QtyAllocated,0)  -  ISNULL(lli.QtyPicked,0)  -  ISNULL(lli.QtyReplen,0) ) = 0
         ORDER BY LOC.LogicalLocation, LOC.Loc
      END
   END


   IF ISNULL( @cSuggLOC, '') <> ''
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP48 -- For rollback or commit only our own transaction

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTraN
   
      COMMIT TRAN rdt_1819ExtPASP48

      GOTO Quit

      RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP48 -- Only rollback change made here
      Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

Fail:

END


GO