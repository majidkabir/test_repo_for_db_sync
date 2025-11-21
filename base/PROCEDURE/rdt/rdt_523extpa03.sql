SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_523ExtPA03                                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 17-03-2017  1.0  Ung      WMS-1365 Created                           */    
/* 11-07-2019  1.1  Pakyuen  INC0774369 - Add in Facility filter (PY01) */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_523ExtPA03] (    
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
       
   DECLARE @nTranCount  INT    
   DECLARE @cSuggToLOC  NVARCHAR( 10)    
       
   SET @nTranCount = @@TRANCOUNT    
   SET @cSuggToLOC = ''    
       
   -- Get pick face    
   SELECT TOP 1    
      @cSuggToLOC = LOC.LOC    
   FROM SKUxLOC SL WITH (NOLOCK)    
      JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)    
   WHERE SL.StorerKey = @cStorerKey    
      AND SL.SKU = @cSKU    
      AND SL.LocationType = 'PICK'  
   AND LOC.Facility = @cFacility		--PY01
   GROUP BY LOC.LOC, LOC.LogicalLocation    
   ORDER BY     
      SUM( SL.QTY - SL.QTYPicked),     
      LOC.LogicalLocation,    
      LOC.LOC    
          
   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggToLOC <> ''    
   BEGIN    
      -- Handling transaction    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN rdt_523ExtPA03 -- For rollback or commit only our own transaction    
          
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
         ,@cLOC    
         ,@cID    
         ,@cSuggToLOC    
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
    
      SET @cSuggestedLOC = @cSuggToLOC    
    
      COMMIT TRAN rdt_523ExtPA03 -- Only commit change made here    
   END    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_523ExtPA03 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO