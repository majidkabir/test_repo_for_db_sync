SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_523ExtPA50                                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-05-17  1.0  yeekung WMS-20109. Created                          */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_523ExtPA50] (    
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
       
   DECLARE @cHostWHCode    NVARCHAR(10)    
   DECLARE @cPutawayZone   NVARCHAR(10)   
   DECLARE @cLocationCategory NVARCHAR(20)
   DECLARE @cLocAisle      NVARCHAR(20)
   DECLARE @nTranCount     INT
   DECLARE @cStyle         NVARCHAR(20)


   SELECT @cPutawayZone=putawayzone
   From LOC (NOLOCK)
   WHERE loc=@cLOC
      AND facility=@cfacility

   SELECT TOP 1 @cSuggestedLOC=LLI.loc
   FROM lotxlocxid LLI(NOLOCK) JOIN
   loc loc (nolock) ON LLI.loc=loc.loc JOIN
   SKU sku (NOLOCK) ON LLI.SKU=SKU.SKU and LLI.storerkey=SKU.storerkey
   WHERE loc.putawayzone=@cPutawayZone
      AND sku.storerkey=@cStorerkey
      AND LOC.facility=@cFacility
      AND loc.loc<>@cLOC
      AND sku.sku=@csku
      AND LLI.qty<>0
   ORDER BY lli.qty

   IF @cSuggestedLOC=''
   BEGIN
      SELECT TOP 1 @cSuggestedLOC=LLI.loc
      FROM lotxlocxid LLI(NOLOCK) LEFT JOIN
      loc loc (nolock) ON LLI.loc=loc.loc
      WHERE loc.putawayzone=@cPutawayZone
         AND loc.loc<>@cLOC
         AND facility=@cFacility
      GROUP BY LLI.LOC 
      HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) = 0  
      ORDER BY  LLI.LOC 
   END

   IF @cSuggestedLOC=''
   BEGIN
      SELECT TOP 1 @cSuggestedLOC=loc.loc
      FROM loc loc (nolock) 
      WHERE loc.putawayzone=@cPutawayZone
         AND loc.loc<>@cLOC
         AND loc.loc NOT IN ( SELECT LLI.loc
                              FROM lotxlocxid LLI(NOLOCK) LEFT JOIN
                              loc loc (nolock) ON LLI.loc=loc.loc
                              WHERE loc.putawayzone=@cPutawayZone
                                 AND loc.loc<>@cLOC
                                 AND LOC.facility=@cFacility
                              GROUP BY LLI.LOC)
         AND LOC.facility=@cFacility
      ORDER BY  loc.LOC 
   END


   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggestedLOC <> ''    
   BEGIN    
      -- Handling transaction    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_523ExtPA50 -- For rollback or commit only our own transaction      
          
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
    
      COMMIT TRAN rdt_523ExtPA50 -- Only commit change made here    
   END    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_523ExtPA50 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO