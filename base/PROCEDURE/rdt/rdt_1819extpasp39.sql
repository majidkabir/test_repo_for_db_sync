SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP39                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2022-05-17  1.0  yeekung WMS-19664. Created                          */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP39] (
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

   DECLARE @cSKU    NVARCHAR( 20)
   DECLARE @cLOT    NVARCHAR(10)
   DECLARE @cPutawayZone NVARCHAR(20)
   DECLARE @cLocAisle NVARCHAR(20)
   DECLARE @cLocationCategory NVARCHAR(20)
   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @cPAStrategyKey NVARCHAR(20)
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
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

   SELECT @cLocationCategory = LocationCategory FROM Loc WITH (NOLOCK) WHERE facility = @cFacility AND loc = @cFromLOC    

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
         AND SKU.style = @cStyle
         AND LOC.LocationType = 'DPBULK'
         AND LOC.LOC <> @cFromLOC
      ORDER By LLI.Qty DESC

      SELECT TOP 1
         @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
         AND LOC.LOC <> @cFromLOC
         AND LOC.LocationType = 'DPBULK'
         AND LOC.LocAisle = @cLocAisle
         AND LOC.Putawayzone = @cPutawayZone
      GROUP BY LOC.PALogicalLOC, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0
      ORDER BY LOC.PALogicalLOC, LOC.LOC



      

      IF ISNULL(@cSuggLOC,'')  = ''
      BEGIN
      
         -- Search Empty Location on same zone , next aisle
         SELECT TOP 1
      	   @cSuggLOC =  LOC.LOC 
         FROM dbo.LOC LOC WITH (NOLOCK)  
      	   LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
         WHERE LOC.Facility = @cFacility  
      	   AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')  
      	   AND LOC.LOC <> @cFromLOC  
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
            @c_userid          = 'RDT'  
         , @c_storerkey       = @cStorerKey  
         , @c_lot             = @cLOT  
         , @c_sku             = @cSKU  
         , @c_id              = @cID  
         , @c_fromloc         = @cFromLOC  
         , @n_qty             = 0  
         , @c_uom             = '' -- not used  
         , @c_packkey         = '' -- optional, if pass-in SKU  
         , @n_putawaycapacity = 0  
         , @c_final_toloc     = @cSuggLOC OUTPUT 

      -- Check suggest loc
      IF @cSuggLOC = ''
      BEGIN
         SET @nErrNo = -1
         GOTO Quit
      END
   END

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
   
Quit:
END

GO