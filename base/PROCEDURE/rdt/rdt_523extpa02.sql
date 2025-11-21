SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA02                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 14-04-2017  1.0  Ung      WMS-1627 Created                           */
/* 16-01-2018  1.1  Ung      WMS-3793 Add SKU.PutawayZone               */
/* 10-01-2019  1.2  Chermaine WMS-10792 Remove restrict of lot04	(cc01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA02] (
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
   DECLARE @dLottable04    DATETIME
   DECLARE @cSuggToLOC     NVARCHAR( 10)
   DECLARE @cPutawayZone   NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
   
   -- Get L04 
   --SELECT @dLottable04 = Lottable04 FROM LOTAttribute (NOLOCK) WHERE LOT = @cLOT (cc01)
   
   -- Get SKU info
   SELECT @cPutawayZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
   -- Find a friend (same SKU, L04)
   SELECT TOP 1
      @cSuggToLOC = LOC.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      --AND LA.Lottable04 = @dLottable04 --(cc01)
      AND LOC.Facility = @cFacility
      AND LOC.LocationType = 'OTHER'
      AND LOC.LocationCategory = 'MEZZANINE'
      AND LOC.PutawayZone = @cPutawayZone
      AND ((LLI.QTY - LLI.QTYPicked) > 0 OR LLI.PendingMoveIn > 0)
   GROUP BY LOC.LogicalLocation, LOC.LOC
   ORDER BY 
      SUM( LLI.QTY - LLI.QTYPicked), 
      LOC.LogicalLocation,
      LOC.LOC
      
   -- Find empty location
   IF @cSuggToLOC = ''
      SELECT TOP 1
         @cSuggToLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationType = 'OTHER'
         AND LOC.LocationCategory = 'MEZZANINE'
         AND LOC.PutawayZone = @cPutawayZone
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY 
         LOC.LogicalLocation,
         LOC.LOC

   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA02 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_523ExtPA02 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO