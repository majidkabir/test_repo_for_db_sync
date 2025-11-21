SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_523ExtPA57                                            */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Date        Rev  Author   Purposes                                         */  
/* 2023-04-11   1.0  yeekung   WMS-22250. Created                             */  
/******************************************************************************/  
  
CREATE     PROC [RDT].[rdt_523ExtPA57] (  
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
  
     
   SET @nTranCount = @@TRANCOUNT  
  
   DECLARE @cLottable03    NVARCHAR( 18)  
   DECLARE @cLottable01    NVARCHAR( 18)  
   DECLARE @cPAZone        NVARCHAR( 10)  
     
  
   SELECT TOP 1   
      @cLottable03   = LA.Lottable03,  
      @cLottable01   = LA.Lottable01,  
      @cPAZone       = SKU.Putawayzone  
   FROM dbo.LotxLocxID LLI WITH (NOLOCK)  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.SKU = SKU.SKU AND LLI.Storerkey  = SKU.Storerkey)  
   WHERE LLI.StorerKey = @cStorerKey  
      AND   LLI.ID = @cID  
      AND   LLI.LOC = @cLOC  
      AND   LLI.SKU = @cSKU  
      AND   LOC.Facility = @cFacility  
   AND LLI.Qty  > 0  
   ORDER BY 1  
  
     
   IF @cLottable03 <> 'ONLINE'  
   BEGIN  

      SELECT TOP 1 @cSuggestedLOC = LOC.LOC  
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)  
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)  
      WHERE LLI.STORERKEY = @cStorerKey
         AND LOC.Facility = @cFacility  
         AND LOC.Putawayzone = @cPAZone  
         AND LA.Lottable03 = @cLottable03  
         AND LA.Lottable01 = @cLottable01  
         AND LLI.SKU = @cSKU  
         AND LLI.LOC       <> @cLOC  
         AND LOC.locationCategory  = 'BULK'  
      GROUP  BY LOC.LOC ,LOC.logicallocation   
      HAVING SUM(LLI.QTY- LLI.QtyAllocated-LLI.QTYPicked)  > 0    
      ORDER BY LOC.logicallocation  

      IF ISNULL(@cSuggestedLOC,'') = ''  
      BEGIN  
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC  
         FROM dbo.LOC LOC   
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC AND LLI.STORERKEY = @cStorerKey )   
         WHERE  LOC.Facility = @cFacility  
            AND LOC.Putawayzone = @cPAZone  
            AND LOC.LOC       <> @cLOC  
            AND LOC.locationCategory  = 'BULK'  
         GROUP  BY LOC.LOC ,LOC.logicallocation   
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0   
         ORDER BY LOC.logicallocation  
      END  
   END  
   ELSE  
   BEGIN  

      SELECT TOP 1 @cSuggestedLOC = LOC.LOC  
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)  
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)  
      WHERE LLI.STORERKEY = @cStorerKey
         AND LOC.Facility = @cFacility  
         AND LOC.Putawayzone = @cPAZone  
         AND LA.Lottable03 = @cLottable03  
         AND LA.Lottable01 = @cLottable01  
         AND LLI.SKU = @cSKU  
         AND LLI.LOC       <> @cLOC  
         AND LOC.locationCategory  = 'SHELVING'  
      GROUP  BY LOC.LOC ,LOC.logicallocation   
      HAVING SUM(LLI.QTY- LLI.QtyAllocated-LLI.QTYPicked)  > 0     
      ORDER BY LOC.logicallocation  

      IF ISNULL(@cSuggestedLOC,'') = ''  
      BEGIN  
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC  
         FROM dbo.LOC LOC   
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC AND LLI.STORERKEY = @cStorerKey )   
         WHERE LOC.Facility = @cFacility  
            AND LOC.Putawayzone = @cPAZone  
            AND LOC.LOC       <> @cLOC  
            AND LOC.locationCategory  = 'SHELVING'  
         GROUP  BY LOC.LOC ,LOC.logicallocation   
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0    
         ORDER BY LOC.logicallocation  
      END  
   END  
  
   /*-------------------------------------------------------------------------------  
                             Book suggested location  
   -------------------------------------------------------------------------------*/  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_523ExtPA57 -- For rollback or commit only our own transaction  
  
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
  
      COMMIT TRAN rdt_523ExtPA57 -- Only commit change made here  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_523ExtPA57 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  



GO