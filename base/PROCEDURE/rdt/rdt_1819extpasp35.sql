SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP35                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2021-06-18  1.0  James    WMS-17248. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP35] (
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

   DECLARE @nTranCount        INT
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cHostWHCode       NVARCHAR( 10)
   
   SET @cSuggLOC = ''

   -- Get pallet info
   SELECT TOP 1 
      @cSKU = LLI.Sku,
      @cHostWHCode = LOC.HOSTWHCODE 
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LLI.LOC = @cFromLOC 
   AND   LLI.ID = @cID 
   AND   LLI.QTY > 0
   ORDER BY 1

   SELECT @cPutawayZone = PutawayZone
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   Sku = @cSKU
   
   IF @cHostWHCode = 'aBL'
   BEGIN
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LocationFlag <> 'HOLD' 
      AND   LOC.HOSTWHCODE = @cHostWHCode
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))
      AND   LLI.ID <> @cID  
      ORDER BY LA.Lottable05 DESC
      
      -- Find empty loc
      IF @cSuggLOC = ''
         SELECT TOP 1 @cSuggLOC = LOC.Loc
         FROM dbo.LOC LOC WITH (NOLOCK)
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationFlag <> 'HOLD' 
         AND   LOC.HOSTWHCODE = @cHostWHCode
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
         ORDER BY LOC.LogicalLocation, LOC.LOC
   END
   ELSE IF @cHostWHCode = 'aQI'
   BEGIN
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LocationFlag <> 'HOLD' 
      AND   LOC.HOSTWHCODE = 'UU'
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))
      ORDER BY LA.Lottable05 ASC

      -- Find empty loc
      IF @cSuggLOC = ''
      BEGIN
         SELECT TOP 1 @cSuggLOC = LOC.Loc
         FROM dbo.LOC LOC WITH (NOLOCK)
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationFlag <> 'HOLD' 
         AND   LOC.HOSTWHCODE = 'UU'
         AND   LOC.PutawayZone = @cPutawayZone
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
         ORDER BY LOC.LogicalLocation, LOC.LOC
      END
   END
   -- Find empty loc
   ELSE IF @cHostWHCode = 'UU'
   BEGIN
      SELECT TOP 1 @cSuggLOC = LOC.Loc
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
      WHERE LOC.Facility = @cFacility
      AND   LOC.LocationFlag <> 'HOLD' 
      AND   LOC.HOSTWHCODE = 'UU'
      AND   LOC.PutawayZone = @cPutawayZone
      GROUP BY Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC
   END
   ELSE
   BEGIN
      SET @nErrNo = 169301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv HostWHCode
      GOTO Fail
   END

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP35 -- For rollback or commit only our own transaction
      
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_1819ExtPASP35 -- Only commit change made here
      
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_1819ExtPASP35 -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
   
   Fail:

END

GO