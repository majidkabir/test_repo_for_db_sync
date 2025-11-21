SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_523ExtPA39                                            */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Date        Rev  Author    Purposes                                        */  
/* 2021-06-09  1.0  Chermaine WMS-17121 Created                               */  
/* 2021-09-10  1.1  Chermaine Tune SET QUOTED_IDENTIFIER                      */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtPA39] (  
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
   DECLARE @cPutawayLoc    NVARCHAR( 20)  
   DECLARE @cPutawayZone   NVARCHAR( 20)  
   DECLARE @dLottable01    NVARCHAR( 20)  
   DECLARE @cPAStrategyKey NVARCHAR( 10)    
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
     
    -- Get putaway strategy from SKU  
   SET @cPAStrategyKey = ''    
   SET @cSuggestedLOC = ''  
   
   SELECT    
      @cPAStrategyKey = PS.PutawayStrategyKey  
   FROM SKU S WITH (NOLOCK)   
   JOIN PutawayStrategy PS WITH (NOLOCK) ON s.StrategyKey = PS.PutawayStrategyKey  
   WHERE S.SKU = @cSKU  
   AND S.StorerKey = @cStorerKey  
   
   IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND Loc = @cLOC AND LocationCategory = 'PUMASH')
   BEGIN
   	IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND ISNULL(BUSR8,'') = 'Y')
      BEGIN
      	--find empty loc
   	   SELECT TOP 1    
            @cSuggToLOC = LOC.LOC  
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
         WHERE LOC.Facility = @cFacility  
         AND LOC.PickZone = '9876' 
         AND LOC.LocationType = 'DYNPPICK'  
         AND LLI.StorerKey = @cStorerKey  
         GROUP BY LOC.Loc  
         HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) = 0  
         ORDER BY LOC.Loc
      END
      ELSE
      BEGIN
         -- Suggest LOC  
         EXEC @nErrNo = [dbo].[nspRDTPASTD]  
            @c_userid          = 'RDT'    
            , @c_storerkey       = @cStorerKey    
            , @c_lot             = @cLOT    
            , @c_sku             = @cSKU    
            , @c_id              = @cID    
            , @c_fromloc         = @cLOC    
            , @n_qty             = @nQTY    
            , @c_uom             = '' -- not used    
            , @c_packkey         = '' -- optional, if pass-in SKU    
            , @n_putawaycapacity = 0    
            , @c_final_toloc     = @cSuggestedLOC  OUTPUT    
            , @c_PAStrategyKey   = @cPAStrategyKey   
      END
   END
   ELSE
   BEGIN
   	 -- Suggest LOC  
      EXEC @nErrNo = [dbo].[nspRDTPASTD]  
         @c_userid          = 'RDT'    
         , @c_storerkey       = @cStorerKey    
         , @c_lot             = @cLOT    
         , @c_sku             = @cSKU    
         , @c_id              = @cID    
         , @c_fromloc         = @cLOC    
         , @n_qty             = @nQTY    
         , @c_uom             = '' -- not used    
         , @c_packkey         = '' -- optional, if pass-in SKU    
         , @n_putawaycapacity = 0    
         , @c_final_toloc     = @cSuggestedLOC  OUTPUT    
         , @c_PAStrategyKey   = @cPAStrategyKey  
   END     
  
   /*-------------------------------------------------------------------------------  
                                 Book suggested location  
   -------------------------------------------------------------------------------*/  
   IF @cSuggToLOC <> ''  
   BEGIN 
      -- Handling transaction  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_523ExtPA39 -- For rollback or commit only our own transaction  
  
    
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
  
      COMMIT TRAN rdt_523ExtPA39 -- Only commit change made here  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_523ExtPA39 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END

GO