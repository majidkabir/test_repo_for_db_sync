SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_521ExtPA13                                      */    
/*                                                                      */    
/* Purpose: Get suggested loc                                           */    
/*                                                                      */    
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */    
/* 2022-10-20  1.0  yeekung  WMS-21050. Created                         */     
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_521ExtPA13] (    
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
       
   DECLARE @cHostWHCode    NVARCHAR(10)    
   DECLARE @cPutawayZone   NVARCHAR(10)   
   DECLARE @cLocationCategory NVARCHAR(20)
   DECLARE @cLocAisle      NVARCHAR(20)
   DECLARE @nTranCount     INT
   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @cSKUGroup      NVARCHAR(20)


   DECLARE @tloc TABLE (
      loc        NVARCHAR( 20)
   )


   SELECT @cSKUGroup = skugroup
   FROM SKU (NOLOCK)
   where sku=@csku
   AND storerkey=@cstorerkey

   --New Empty LOC
   IF @cSuggestedLOC=''
   BEGIN
       --New Empty LOC (Match Product Category) 
      INSERT INTO @tloc
      SELECT LOC.loc
      FROM loc loc (nolock) 
      WHERE  loc.loc<>@cLOC
         AND LOC.facility=@cFacility
         AND LocationCategory in (SELECT udf01
                                  FROM codelkup (NOLOCK)
                                  where LEFT(long,10)= @cSKUGroup
                                  AND storerkey=@cStorerKey
                                  AND listname= 'BSJPCate')
         AND locationtype='NORMAL'
         AND loc NOT IN (  select distinct lli.loc
                           from lotxlocxid lli (nolock) join loc loc (nolock) on lli.loc=loc.loc
                           WHERE storerkey= @cStorerKey
                           GROUP BY LLI.LOC
                           HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) > 0 )

      SELECT TOP 1 @cSuggestedLOC=loc
      from @tloc 
      WHERE loc not in (select suggestedloc
                              FROM RFPutaway (NOLOCK)
                              where storerkey=@cStorerKey
                              AND fromloc=@cLOC)
                             
   END

      --New Empty LOC
   IF @cSuggestedLOC=''
   BEGIN
      --Lowest Qty of SKU in LOC
      SELECT TOP 1 @cSuggestedLOC=LLI.loc
      FROM lotxlocxid LLI(NOLOCK) JOIN
         loc loc (nolock) ON LLI.loc=loc.loc
      WHERE LLI.storerkey=@cStorerkey
         AND LOC.facility=@cFacility
         AND LLI.loc<>@cLOC
         AND locationtype='NORMAL'
         AND LLI.sku=@csku
         AND LLI.qty<>0
      GROUP BY LLI.LOC
      HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) > 0 
      ORDER BY SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked)

   END

   --Max SKU of LOC
   IF @cSuggestedLOC=''
   BEGIN
      --Max SKU of LOC (Match Product Category) 
      SELECT TOP 1 @cSuggestedLOC=LLI.loc
      FROM lotxlocxid LLI(NOLOCK) JOIN
      loc loc (nolock) ON LLI.loc=loc.loc
      WHERE  loc.loc<>@cLOC
         AND locationtype='NORMAL'
         AND storerkey= @cStorerKey
         AND LOC.facility=@cFacility
         AND LocationCategory in (SELECT udf01
                                  FROM codelkup (NOLOCK)
                                  where LEFT(long,10)= @cSKUGroup
                                  AND storerkey=@cStorerKey
                                  AND listname= 'BSJPCate')
      GROUP BY LLI.LOC,loc.MaxSKU 
      HAVING COUNT(DISTINCT SKU) <= loc.MaxSKU
      ORDER BY  LLI.LOC 

      --Max SKU of LOC (Not Match Product Category)
      IF @cSuggestedLOC=''
      BEGIN
         SELECT TOP 1 @cSuggestedLOC=LLI.loc
         FROM lotxlocxid LLI(NOLOCK) JOIN
         loc loc (nolock) ON LLI.loc=loc.loc
         WHERE  loc.loc<>@cLOC
            AND LOC.facility=@cFacility
            AND storerkey= @cStorerKey
            AND LocationCategory in (SELECT udf01
                                     FROM codelist (NOLOCK)
                                     where listname= 'BSJPCate')
         GROUP BY LLI.LOC,loc.MaxSKU 
         HAVING COUNT(DISTINCT SKU) <= loc.MaxSKU
         ORDER BY  LLI.LOC 
      END
   END

   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggestedLOC <> ''    
   BEGIN    
      -- Handling transaction    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_521ExtPA13 -- For rollback or commit only our own transaction      
          
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
    
      COMMIT TRAN rdt_521ExtPA13 -- Only commit change made here    
   END    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_521ExtPA13 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  
END


GO