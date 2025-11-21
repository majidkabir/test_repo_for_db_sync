SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA12                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 12-04-2018  1.0  Ung      WMS-4562 Created                                 */
/* 27-05-2019  1.1  James    WMS-9073 PA strategy enhancement (james01)       */
/* 28-07-2022  1.2  James    WMS-20267 PA strategy enhancement (james02)      */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA12] (
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
   
   -- Get lottable02
   DECLARE @cLottable02 NVARCHAR(18)
   SELECT @cLottable02 = Lottable02,
          @cSKU = SKU
   FROM LOTAttribute WITH (NOLOCK) WHERE LOT = @cLOT
   
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE ListName = 'LULUEPA'  
               AND   Code = @cLottable02
               AND   StorerKey = @cStorerKey)
   BEGIN
      -- Find a friend (same SKU, L02) with min QTY
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
         AND LA.Lottable02 = @cLottable02
         AND LLI.QTY-LLI.QTYPicked > 0
      ORDER BY LLI.QTY-LLI.QTYPicked 
   END
   
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE ListName = 'LULUPA'  
               AND   Code = @cLottable02
               AND   StorerKey = @cStorerKey)
   BEGIN
      SELECT @cItemClass = ItemClass
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- Find a friend (same SKU, L02, class) with min QTY
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
         AND LA.Lottable02 = @cLottable02
         AND LLI.QTY-LLI.QTYPicked > 0
      ORDER BY LLI.QTY-LLI.QTYPicked 


      /*
      IF @cSuggToLOC = ''
         -- Find a friend (same SKU, L02) with min QTY
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
            AND LA.Lottable02 = @cLottable02
            AND LLI.QTY-LLI.QTYPicked > 0
         ORDER BY LLI.QTY-LLI.QTYPicked 
      */
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
   SAVE TRAN rdt_523ExtPA12 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA12 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA12 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO