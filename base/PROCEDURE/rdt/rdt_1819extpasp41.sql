SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP41                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2022-08-08  1.0  yeekung WMS-20438. Created                          */   
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP41] (
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
       
   DECLARE @cHostWHCode    NVARCHAR(10)    
   DECLARE @cPutawayZone   NVARCHAR(10)   
   DECLARE @cFromLOCationCategory NVARCHAR(20)
   DECLARE @cFromLOCAisle      NVARCHAR(20)
   DECLARE @nTranCount     INT
   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @cSKUGroup      NVARCHAR(20)
   DECLARE @cSKU          NVARCHAR(20)
   DECLARE @cLOT    NVARCHAR(10)

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

   SELECT @cSKUGroup = skugroup
   FROM SKU (NOLOCK)
   where sku=@cSKU
   AND storerkey=@cstorerkey


   --Lowest Qty of SKU in LOC
   SELECT TOP 1 @cSuggLOC=LLI.loc
   FROM lotxlocxid LLI(NOLOCK) JOIN
      loc loc (nolock) ON LLI.loc=loc.loc
   WHERE LLI.storerkey=@cStorerkey
      AND LLI.loc<>@cFromLOC
      AND locationtype='NORMAL'
      AND LLI.sku=@csku
      AND LLI.qty<>0
   ORDER BY lli.qty

   --Max SKU of LOC
   IF @cSuggLOC=''
   BEGIN
      --Max SKU of LOC (Match Product Category) 
      SELECT TOP 1 @cSuggLOC=LLI.loc
      FROM lotxlocxid LLI(NOLOCK) JOIN
      loc loc (nolock) ON LLI.loc=loc.loc
      WHERE  loc.loc<>@cFromLOC
         AND locationtype='NORMAL'
         AND storerkey= @cStorerKey
         AND LocationCategory in (SELECT udf01
                                  FROM codelkup (NOLOCK)
                                  where LEFT(long,10)= @cSKUGroup
                                  AND storerkey=@cStorerKey
                                  AND listname= 'DCJPCate')
      GROUP BY LLI.LOC,loc.MaxSKU 
      HAVING COUNT(DISTINCT SKU) <= loc.MaxSKU
      ORDER BY  LLI.LOC 

      --Max SKU of LOC (Not Match Product Category)
      IF @cSuggLOC=''
      BEGIN
         SELECT TOP 1 @cSuggLOC=LLI.loc
         FROM lotxlocxid LLI(NOLOCK) JOIN
         loc loc (nolock) ON LLI.loc=loc.loc
         WHERE  loc.loc<>@cFromLOC
            AND storerkey= @cStorerKey
            AND LocationCategory in (SELECT udf01
                                     FROM codelist (NOLOCK)
                                     where listname= 'DCJPCate')
         GROUP BY LLI.LOC,loc.MaxSKU 
         HAVING COUNT(DISTINCT SKU) <= loc.MaxSKU
         ORDER BY  LLI.LOC 
      END
   END

   --New Empty LOC
   IF @cSuggLOC=''
   BEGIN
       --New Empty LOC (Match Product Category) 
      SELECT TOP 1 @cSuggLOC=LOC.loc
      FROM loc loc (nolock) 
      WHERE  loc.loc<>@cFromLOC
         AND LocationCategory in (SELECT  udf01
                                  FROM codelkup (NOLOCK)
                                  where LEFT(long,10)= @cSKUGroup
                                  AND storerkey=@cStorerKey
                                  AND listname= 'DCJPCate')
         AND locationtype='NORMAL'
         AND loc NOT IN (select distinct lli.loc
                         from lotxlocxid lli (nolock) join loc loc (nolock) on lli.loc=loc.loc
                           WHERE  loc.loc<>@cFromLOC   AND
                           loc.LocationCategory in (SELECT udf01
                                                    FROM codelkup (NOLOCK)
                                                    where LEFT(long,10)= @cSKUGroup
                                                    AND storerkey=@cStorerKey
                                                    AND listname= 'DCJPCate')  
                              AND storerkey= @cStorerKey
                              GROUP BY LLI.LOC
                              HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) > 0 )
	  
     --New Empty LOC (Not Match Product Category)
      IF @cSuggLOC=''
      BEGIN
         SELECT TOP 1 @cSuggLOC=LOC.loc
         FROM loc loc (nolock) 
         WHERE  loc.loc<>@cFromLOC
            AND LocationCategory in (SELECT udf01
                                     FROM codelist (NOLOCK)
                                     where listname= 'DCJPCate')
            AND loc NOT IN (select distinct lli.loc
                         from lotxlocxid lli (nolock) join loc loc (nolock) on lli.loc=loc.loc
                           WHERE loc.loc<>@cFromLOC   AND
                           loc.LocationCategory in (SELECT udf01  
                                                       FROM codelist (NOLOCK)  
                                                       where listname= 'DCJPCate')  
                              AND storerkey= @cStorerKey
                              GROUP BY LLI.LOC
                              HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) > 0 )
      END
   END

   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggLOC <> ''    
   BEGIN    

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
         ,@cFromLOC    
         ,@cID    
         ,@cSuggLOC    
         ,@cStorerKey    
         ,@nErrNo  OUTPUT    
         ,@cErrMsg OUTPUT    
         ,@cSKU          = @cSKU      
         ,@cFromLOT      = @cLOT   
         ,@nPABookingKey = @nPABookingKey OUTPUT   
      IF @nErrNo <> 0    
         GOTO QUIT    

   END    
   GOTO Quit    
    
Quit:    

END

GO