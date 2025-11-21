SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_521ExtPA14                                      */    
/*                                                                      */    
/* Purpose: Get suggested loc                                           */    
/*                                                                      */    
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */    
/* 2023-07-03   1.0  yeekung  WMS-22916. Created                        */ 
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_521ExtPA14] (    
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
           
   DECLARE @cPutawayZone   NVARCHAR(10)     
   DECLARE @cItemClass     NVARCHAR(20)
  DECLARE @cBusr7         NVARCHAR(20)  
   DECLARE @nTranCount     INT        

   SELECT  @cItemClass   = SKU.itemclass,
            @cSKU         = SKU.SKU,
            @cBusr7       = SKU.BUSR7
   FROM  SKU SKU (NOLOCK) 
   WHERE  SKU.SKU = @cSKU
      AND SKU.Storerkey = @cStorerKey

   IF @cBusr7 = '20'
   BEGIN

      SELECT TOP 1 @cSuggestedLOC = LLI.LOC
      FROM LOTXLOCXID LLI (NOLOCK)
         JOIN LOC LOC (NOLOCK) ON LOC.LOC =LLI.LOC
         JOIN LOtattribute LOT (NOLOCK) ON LOT.lot =LLI.lot AND LLI.sku = LOT.SKU AND LLI.StorerKey = LOT.StorerKey
      WHERE LOC.Facility = @cFacility 
         AND Loc.LOC <> @cLOC
         AND LLI.SKU = @cSKU
         AND LLI.Storerkey = @cStorerkey
         AND LOC.LoseID = '0'
         AND LOC.locationtype <>'STAGING'
      GROUP BY LLI.LOC
      HAVING SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked) > 0
      ORDER BY MAX(LOT.lottable05) , SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked)

      IF ISNULL(@cSuggestedLOC,'') =''
      BEGIN
      
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM LOTXLOCXID LLI (NOLOCK)
            JOIN LOC LOC (NOLOCK) ON LOC.LOC =LLI.LOC
            JOIN LOtattribute LOT (NOLOCK) ON LOT.lot =LLI.lot AND LLI.sku = LOT.SKU AND LLI.StorerKey = LOT.StorerKey
            JOIN SKU SKU (NOLOCK) ON SKU.SKU =LLI.SKU AND LLI.StorerKey = LOT.StorerKey
         WHERE LOC.Facility = @cFacility 
            AND Loc.LOC <> @cLOC
            AND SKU.itemclass = @cItemClass
            AND LLI.Storerkey = @cStorerkey
            AND LOC.locationtype <>'STAGING'
            AND LOC.LoseID = '0'
         GROUP BY LLI.LOC
         HAVING SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked) > 0
         ORDER BY MAX(LOT.lottable05) , SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked)
      END
   END
   ELSE
   BEGIN

      SELECT TOP 1 @cSuggestedLOC = LLI.LOC
      FROM LOTXLOCXID LLI (NOLOCK)
         JOIN LOC LOC (NOLOCK) ON LOC.LOC =LLI.LOC
         JOIN LOtattribute LOT (NOLOCK) ON LOT.lot =LLI.lot AND LLI.sku = LOT.SKU AND LLI.StorerKey = LOT.StorerKey
      WHERE LOC.Facility = @cFacility 
         AND Loc.LOC <> @cLOC
         AND LLI.SKU = @cSKU
         AND LLI.Storerkey = @cStorerkey
         AND LOC.locationtype <>'STAGING'
         AND LOC.LoseID = '1'
      GROUP BY LLI.LOC
      HAVING SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked) > 0
      ORDER BY MAX(LOT.lottable05) , SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked)

      IF ISNULL(@cSuggestedLOC,'') =''
      BEGIN
      
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM LOTXLOCXID LLI (NOLOCK)
            JOIN LOC LOC (NOLOCK) ON LOC.LOC =LLI.LOC
            JOIN LOtattribute LOT (NOLOCK) ON LOT.lot =LLI.lot AND LLI.sku = LOT.SKU AND LLI.StorerKey = LOT.StorerKey
            JOIN SKU SKU (NOLOCK) ON SKU.SKU =LLI.SKU AND LLI.StorerKey = LOT.StorerKey
         WHERE LOC.Facility = @cFacility 
            AND Loc.LOC <> @cLOC
            AND SKU.itemclass = @cItemClass
            AND LLI.Storerkey = @cStorerkey
            AND LOC.locationtype <>'STAGING'
            AND LOC.LoseID = '1'
         GROUP BY LLI.LOC
         HAVING SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked) > 0
         ORDER BY MAX(LOT.lottable05) , SUM(LLI.qty -LLI.qtyallocated-LLI.qtypicked)
      END
   END

   IF ISNULL(@cSuggestedLOC,'') =''
   BEGIN
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM dbo.LOC LOC       
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC  AND LLI.STORERKEY = @cStorerKey)     
      WHERE  LOC.Facility = @cFacility 
         AND Loc.LOC <> @cLOC
         AND LOC.locationtype <>'STAGING'
         AND LOC.Putawayzone  IN (SELECT LONG
                                    FROM CODELKUP (NOLOCK)
                                    WHERE StorerKey = @cStorerkey
                                    AND SHORT =  LEFT(@cSKU,1)
                                    AND Code = @cBusr7)
      GROUP BY LOC.LOC,LOC.LogicalLocation
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0    
      ORDER BY LOC.LOC,LOC.LogicalLocation
   END


   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggestedLOC <> ''    
   BEGIN    
      -- Handling transaction    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_521ExtPA14 -- For rollback or commit only our own transaction      
          
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
         ,@cLOC    
         ,@cID    
         ,@cSuggestedLOC    
         ,@cStorerKey    
         ,@nErrNo  OUTPUT    
         ,@cErrMsg OUTPUT    
         ,@cSKU          = @cSKU    
         ,@nPutawayQTY   = @nQTY    
         ,@cFromLOT      = @cLOT    
         ,@cUCCNo        = @cUCC    
         ,@nPABookingKey = @nPABookingKey OUTPUT    
      IF @nErrNo <> 0    
         GOTO RollBackTran    
    
      COMMIT TRAN rdt_521ExtPA14 -- Only commit change made here    
   END    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_521ExtPA14 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  
END


GO