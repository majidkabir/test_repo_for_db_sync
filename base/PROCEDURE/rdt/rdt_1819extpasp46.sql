SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
       
/************************************************************************/      
/* Store procedure: rdt_1819ExtPASP46                                   */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date         Rev  Author   Purposes                                  */      
/* 2023-04-11   1.0  yeekung   WMS-22251. Created                       */      
/************************************************************************/      
CREATE    PROC [RDT].[rdt_1819ExtPASP46] (    
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
   DECLARE @cLottable03    NVARCHAR( 18)      
   DECLARE @cLottable01    NVARCHAR( 18)      
   DECLARE @cLOT           NVARCHAR( 10)      
   DECLARE @cPAZone        NVARCHAR( 10)      
         
   DECLARE @nTranCount  INT      
      
   SELECT TOP 1       
      @cLottable03   = LA.Lottable03,      
      @cLottable01   = LA.Lottable01,      
      @cPAZone       = SKU.Putawayzone,      
      @cSKU          = SKU.SKU      
   FROM dbo.LotxLocxID LLI WITH (NOLOCK)      
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)      
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)      
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.SKU = SKU.SKU AND LLI.Storerkey  = SKU.Storerkey)      
   JOIN dbo.PUTAWAYZONE PZ WITH (NOLOCK) ON (PZ.PutawayZone = SKU.PutawayZone)   
   WHERE LLI.StorerKey = @cStorerKey      
   AND   LLI.ID = @cID      
   AND   LOC.Facility = @cFacility      
   AND LLI.Qty  > 0          
   ORDER BY PZ.ZoneCategory, SKU.SKU      
         
   IF @cLottable03 <> 'ONLINE'      
   BEGIN      
      IF ISNULL(@cSuggLOC,'') = ''      
      BEGIN      
         SELECT TOP 1 @cSuggLOC = LOC.LOC      
         FROM dbo.LOC LOC       
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC AND LLI.STORERKEY = @cStorerKey)     
         WHERE  LOC.Facility = @cFacility      
            AND LOC.Putawayzone = @cPAZone      
            AND LOC.LOC       <> @cFromLOC      
            AND LOC.locationCategory  = 'BULK'      
         GROUP  BY LOC.LOC ,LOC.logicallocation     
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0       
         ORDER BY LOC.logicallocation    
  
      END      
   END      
   ELSE      
   BEGIN      
    
      IF ISNULL(@cSuggLOC,'') = ''      
      BEGIN      
         SELECT TOP 1 @cSuggLOC = LOC.LOC      
         FROM dbo.LOC LOC       
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC  AND LLI.STORERKEY = @cStorerKey)     
         WHERE  LOC.Facility = @cFacility      
            AND LOC.Putawayzone = @cPAZone      
            AND LOC.LOC       <> @cFromLOC      
            AND LOC.locationCategory  = 'SHELVING'      
         GROUP  BY LOC.LOC ,LOC.logicallocation     
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0       
         ORDER BY LOC.logicallocation          
  
      END      
   END      
         
   IF ISNULL( @cSuggLOC, '') <> ''      
   BEGIN      
      -- Handling transaction      
      SET @nTranCount = @@TRANCOUNT      
      BEGIN TRAN  -- Begin our own transaction      
     SAVE TRAN rdt_1819ExtPASP46 -- For rollback or commit only our own transaction      
      
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
         
      COMMIT TRAN rdt_1819ExtPASP46      
      
      GOTO Quit      
      
   RollBackTran:      
      ROLLBACK TRAN rdt_1819ExtPASP46 -- Only rollback change made here      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
         COMMIT TRAN      
   END      
      
Fail:      
      
END         


GO