SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_523ExtPA48                                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-05-17  1.0  yeekung WMS-19664. Created                          */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_523ExtPA48] (    
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
   DECLARE @cPAStrategyKey NVARCHAR(20)

   SET @nTranCount= @@TRANCOUNT
       
   SET @cSuggestedLOC = ''    
       
   SELECT @cLocationCategory = LocationCategory FROM Loc WITH (NOLOCK) WHERE facility = @cFacility AND loc = @cLOC    

   SELECT @cStyle=style 
   FROM SKU (NOLOCK)
   where SKU=@cSKU
   AND storerkey=@cStorerKey

   IF @cLocationCategory='MEZZP'
   BEGIN
      SELECT Top 1
		   @cPutawayZone = LOC.Putawayzone ,
		   @cLocAisle = LOC.LocAisle
      FROM LotxLocxID LLI (NOLOCK) 
      JOIN LOC LOC (NOLOCK) ON LOC.LOC = LLI.LOC 
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey
      WHERE LLI.StorerKey = @cStorerKey
         AND SKU.Style= @cStyle
         AND LOC.LocationType = 'DPBULK'
         AND LOC.LOC <> @cLOC
      ORDER By LLI.Qty DESC

      -- Search Empty Location on same zone , same aisle
      SELECT TOP 1
           @cSuggestedLOC =  LOC.LOC  
      FROM dbo.LOC LOC WITH (NOLOCK)  
          LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
      WHERE LOC.Facility = @cFacility  
           AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')  
           AND LOC.LOC <> @cLOC  
		     AND LOC.LocationType = 'DPBULK'
		     AND LOC.LocAisle = @cLocAisle
		     AND LOC.Putawayzone = @cPutawayZone
      GROUP BY LOC.PALogicalLOC, LOC.LOC  
      HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) = 0  
      ORDER BY LOC.PALogicalLOC, LOC.LOC 
      
      IF ISNULL(@cSuggestedLOC,'')  = ''
      BEGIN
      
         -- Search Empty Location on same zone , next aisle
         SELECT TOP 1
      	   @cSuggestedLOC =  LOC.LOC 
         FROM dbo.LOC LOC WITH (NOLOCK)  
      	   LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
         WHERE LOC.Facility = @cFacility  
      	   AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')  
      	   AND LOC.LOC <> @cLOC  
      	   AND LOC.LocationType = 'DPBULK'
      	   AND LOC.LocAisle > @cLocAisle
      	   AND LOC.Putawayzone = @cPutawayZone
         GROUP BY LOC.LocAisle,LOC.PALogicalLOC, LOC.LOC  
         HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) = 0  
         ORDER BY LOC.LocAisle,LOC.PALogicalLOC, LOC.LOC 
      END
   END
   ELSE  
   BEGIN  
      SET @cPAStrategyKey = ''    
      SELECT @cPAStrategyKey = Short     
      FROM CodeLKUP WITH (NOLOCK)    
      WHERE ListName = 'ADRDTExtPA'   
      AND storerkey=@cStorerKey

      -- Suggest LOC  
      EXEC @nErrNo = [dbo].[nspRDTPASTD]      
           @c_userid        = 'RDT'          -- NVARCHAR(10)      
         , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)      
         , @c_lot           = ''             -- NVARCHAR(10)      
         , @c_sku           = @cSKU -- NVARCHAR(20)      
         , @c_id            = @cID           -- NVARCHAR(18)      
         , @c_fromloc       = @cLOC          -- NVARCHAR(10)      
         , @n_qty           = @nQty          -- int      
         , @c_uom           = ''             -- NVARCHAR(10)      
         , @c_packkey       = ''             -- NVARCHAR(10) -- optional      
         , @n_putawaycapacity = 0      
         , @c_final_toloc     = @cSuggestedLOC     OUTPUT         
  
      -- Check suggest loc  
      IF @cSuggestedLOC = ''  
      BEGIN  
         SET @nErrNo = -1  
         GOTO Quit  
      END  
   END  
          
   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggestedLOC <> ''    
   BEGIN    
      -- Handling transaction    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_523ExtPA48 -- For rollback or commit only our own transaction    
          
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
    
      COMMIT TRAN rdt_523ExtPA48 -- Only commit change made here    
   END    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_523ExtPA48 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO