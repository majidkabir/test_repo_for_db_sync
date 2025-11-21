SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_523ExtPA58                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2024-04-17  1.0  yeekung   WMS-22301. Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA58] (
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
   DECLARE @cStyle         NVARCHAR( 20)
   DECLARE @cPutawayZone   NVARCHAR(10) 
   DECLARE @cSkuGroup      NVARCHAR(20)
   DECLARE @cLogicalLoc    NVARCHAR(20)
   
   DECLARE @cSKUPutawayZone   NVARCHAR(10)   


   SET @nTranCount = @@TRANCOUNT



   SELECT  TOP 1  @cSKU = SKU.SKU, 
               @cStyle = SKU.Style,
               @cSKUGroup  = SKUGROUP,
               @cSKUPutawayZone = SKU.PutawayZone
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)        
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey   
   WHERE SKU.SKU = @cSKU
      AND SKU.Storerkey = @cStorerKey  
   GROUP BY SKU.STYLE,LLI.LOC,LLI.QTY,SKU.SKU,SKU.SKUGROUP,SKU.PutawayZone   
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0     
   ORDER BY LLI.QTY DESC

      -- Find a friend
   SELECT TOP 1
      @cSuggestedLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey
   WHERE LOC.Facility = @cFacility
      AND   LOC.LOC <> @cLOC
      AND   LLI.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU
      AND   LOC.LocationType    in    ('PICK','OTHER')  
      AND   LOC.locationcategory IN ('RACK','SHELVING')
   GROUP BY LA.lottable05, LOC.Loc
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
   ORDER BY MAX(LA.lottable05), SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen)

   -- Find existing SKU
   SELECT TOP 1  
      @cSuggestedLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey  
   WHERE LOC.Facility = @cFacility  
      AND   LOC.LOC <> @cLOC  
      AND   LLI.StorerKey = @cStorerKey  
      AND   SKU.SKU = @cSKU  
         AND   LOC.LocationType  IN ('PICK','OTHER' )   
      AND   LOC.locationcategory IN ('RACK','SHELVING')  
   GROUP BY LA.lottable05, LOC.Loc , LOC.PutawayZone 
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
   ORDER BY MAX(LA.lottable05), SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen)  

   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN

      -- Find same style for SKU
      SELECT TOP 1  
         @cSuggestedLOC = LOC.LOC 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey  
      WHERE LOC.Facility = @cFacility  
         AND   LOC.LOC <> @cLOC  
         AND   LLI.StorerKey = @cStorerKey  
         AND   (SKU.Style = @cStyle AND SKU.SkuGroup = @cSkuGroup)  
         AND   LOC.LocationType  IN ('PICK','OTHER' )   
         AND   LOC.locationcategory IN ('RACK','SHELVING')  
         --AND   LOC.MaxQTY > 0  
      GROUP BY LA.lottable05, LOC.Loc  ,LOC.PutawayZone
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
      ORDER BY MAX(LA.lottable05), SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen)  
   END

   
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN
      -- Find style for first two digit SKU style
      SELECT TOP 1 @cPutawayZone = LOC.PutawayZone   
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)     
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)     
         JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey 
      WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cLOC
            AND   (SKU.Style like SUBSTRING(@cStyle,1,5) +'%'  AND SKU.SkuGroup = @cSKUGroup)
            AND   LOC.LocationType  IN ('PICK','OTHER' )   
            AND   LOC.LocationCategory in ('RACK','SHELVING')  
      GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen ) > 0
      ORDER BY MAX(LA.lottable05),SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen),LOC.LogicalLocation, LOC.Loc,LOC.PutawayZone

      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM LOC LOC WITH (NOLOCK)
         LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cLOC
            AND   LOC.LocationType  IN ('PICK','OTHER' )   
            AND   LOC.LocationCategory in ('RACK','SHELVING')  
            AND   LOC.PutawayZone = @cPutawayZone
      GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
      HAVING SUM( ISNULL(lli.Qty,0) -  ISNULL(lli.QtyAllocated,0)  -  ISNULL(lli.QtyPicked,0)  -  ISNULL(lli.QtyReplen,0) ) = 0
      ORDER BY LOC.LogicalLocation, LOC.Loc

      IF ISNULL(@cSuggestedLOC,'') =''
      BEGIN
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC
         FROM LOC LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cLOC
               AND   LOC.LocationType  IN ('PICK','OTHER' )   
               AND   LOC.LocationCategory in ('RACK','SHELVING')  
               AND   LOC.PutawayZone = @cSKUPutawayZone
         GROUP BY LOC.LogicalLocation, LOC.LOC,LOC.PutawayZone
         HAVING SUM( ISNULL(lli.Qty,0) -  ISNULL(lli.QtyAllocated,0)  -  ISNULL(lli.QtyPicked,0)  -  ISNULL(lli.QtyReplen,0) ) = 0
         ORDER BY LOC.LogicalLocation, LOC.Loc

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
      END
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA58 -- For rollback or commit only our own transaction

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
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA58 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA58 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO