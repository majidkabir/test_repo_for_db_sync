SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP40                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2022-05-17  1.0  yeekung WMS-19664. Created                          */  
/* 2023-09-19  1.1  yeekung WMS-23674 Add codelkup to replace longspan  */
/*                         (yeekung01)                                  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP40] (
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
   DECLARE @cFromLocationCategory NVARCHAR(20)
   DECLARE @cToLocationCategory NVARCHAR(20)
   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @cUDF05         NVARCHAR(20)

   DECLARE @cPAStrategyKey NVARCHAR(20)
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
   -- Get pallet SKU  
   SELECT TOP 1   
      @cSKU = SKU,   
      @cLOT = LOT,
      @cFromLocationCategory = LOC.Locationcategory
   FROM LOTxLOCxID LLI WITH (NOLOCK)   
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
   WHERE LOC.Facility = @cFacility  
      AND LLI.LOC = @cFromLOC   
      AND LLI.ID = @cID   
      AND LLI.QTY > 0 

   SELECT @cToLocationCategory = UDF02,
          @cUDF05  = UDF05
   FROM Codelkup (NOLOCK)
   WHERE listname ='RDTExtPA'
      AND Storerkey = @cStorerKey
      AND UDF01 = @cFromLocationCategory

   IF ISNULL(@cToLocationCategory,'') =''
      SET @cToLocationCategory ='' 



  -- SET @cLocationCategory='LongSpan' (yeekung01)

   SELECT @cStyle=style 
   FROM SKU (NOLOCK)
   where SKU=@cSKU
   AND storerkey=@cStorerKey


   SELECT Top 1
		@cPutawayZone = LOC.Putawayzone ,
		@cLocAisle = LOC.LocAisle
   FROM LotxLocxID LLI (NOLOCK) 
   JOIN LOC LOC (NOLOCK) ON LOC.LOC = LLI.LOC 
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey
   WHERE LLI.StorerKey = @cStorerKey
      AND SKU.Style= @cStyle
      AND LOC.Facility=@cFacility
      AND LOC.LOC <> @cFromLOC
   GROUP BY LOC.Putawayzone ,LOC.LocAisle
   ORDER BY CASE WHEN @cUDF05 = 1 THEN SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) END,
            CASE WHEN @cUDF05 = 0 THEN SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) END desc

   SELECT TOP 1
      @cSuggLOC = LOC.LOC
   FROM dbo.LOC LOC WITH (NOLOCK)
   LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey
   WHERE LOC.Facility = @cFacility
      AND LOC.LocationFlag  NOT IN ('HOLD', 'DAMAGE')
      AND LOC.LOC <> @cFromLOC
      AND LOC.LocationCategory = @cToLocationCategory
      AND SKU.Style= @cStyle
      AND Loc.PutawayZone = @cPutawayZone
   GROUP BY LOC.LOC
   HAVING  SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked)>0
   ORDER BY CASE WHEN @cUDF05 = 1 THEN SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) END,
            CASE WHEN @cUDF05 = 0 THEN SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) END desc, 
            LOC.LOC

   IF ISNULL(@cSuggLOC,'')  = ''
   BEGIN
      
      -- Search Empty Location on same zone , next aisle
      SELECT TOP 1
      	@cSuggLOC =  LOC.LOC 
      FROM dbo.LOC LOC WITH (NOLOCK)  
      	JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.SKU = LLI.SKU)  
      WHERE LOC.Facility = @cFacility  
      	AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')  
      	AND LOC.LOC <> @cFromLOC  
         AND LOC.LocationCategory = @cToLocationCategory
         AND SKU.Style = @cStyle
      	AND LOC.LocAisle <> @cLocAisle
      	AND LOC.Putawayzone = @cPutawayZone
      GROUP BY LOC.LocAisle,LOC.PALogicalLOC, LOC.LOC  
      HAVING SUM(LLI.QTY -LLI.QtyAllocated- LLI.QTYPicked) = 0  
      ORDER BY LOC.LocAisle,LOC.PALogicalLOC, LOC.LOC 

   END

   IF ISNULL(@cSuggLOC,'')  = ''
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
         ,@c_PAStrategyKey   = @cPAStrategyKey   

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