SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA59                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 30-05-2023  1.0  James    WMS-22627 Created                                */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA59] (
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
   DECLARE @cItemClass  NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
   
   SELECT @cSKU = SKU
   FROM LOTAttribute WITH (NOLOCK) 
   WHERE LOT = @cLOT
   
      -- Find a friend (same SKU, L02) with max QTY
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
         AND LOC.LOCLevel = 1
         AND LOC.LocationCategory = 'LULU'
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY-LLI.QTYPicked > 0
      ORDER BY LLI.QTY-LLI.QTYPicked DESC
   
   IF ISNULL( @cSuggToLOC, '') = ''
   BEGIN
      SELECT @cItemClass = ItemClass
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- Find a friend (same SKU, L02, class) with max QTY
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
         AND LOC.LOCLevel = 1
         AND LOC.LocationCategory = 'LULU'
         AND LOC.LocationGroup = @cItemClass
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY-LLI.QTYPicked > 0
      ORDER BY LLI.QTY-LLI.QTYPicked DESC

      IF @cSuggToLOC = ''
         -- Find empty loc
         SELECT TOP 1 @cSuggToLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LOC.LocationGroup = @cItemClass
         AND   LOC.LOCLevel = 1
         AND   LOC.LocationCategory = 'LULU'
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
         AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
         ORDER BY Loc.LogicalLocation, LOC.LOC  
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA59 -- For rollback or commit only our own transaction

   IF @cSuggToLOC <> ''
   BEGIN
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
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA59 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA59 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO