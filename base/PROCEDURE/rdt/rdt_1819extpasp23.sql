SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP23                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 14-May-2019  1.0  James    WMS9081. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP23] (
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

   DECLARE @nTranCount           INT,
           @cLottable08          NVARCHAR( 30),
           @cLogicalLocation     NVARCHAR( 10),
           @cPAZone1             NVARCHAR( 20),
           @cPAZone2             NVARCHAR( 20),
           @cPAZone3             NVARCHAR( 20),
           @cPAZone4             NVARCHAR( 20),
           @cPAZone5             NVARCHAR( 20)
   
   DECLARE @cPalletType       NVARCHAR( 15)  
   DECLARE @cSKU              NVARCHAR( 20)  

   -- 1 pallet 1 sku, 1 lottable08
   SELECT TOP 1 @cLottable08 = LA.Lottable08, 
                @cSKU =LA.SKU
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.Loc = @cFromLOC
   AND   LLI.ID = @cID
   AND   LLI.Qty > 0
   ORDER BY 1

   -- Check lottable08 exists
   IF ISNULL( @cLottable08, '') = ''
   BEGIN
      SET @nErrNo = 138451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Lottable08
      GOTO Quit
   END

   CREATE TABLE #PAZone (
   RowRef  INT IDENTITY(1,1) NOT NULL,
   PAZone  NVARCHAR(10)  NULL)

   INSERT INTO #PAZone ( PAZone)
   SELECT DISTINCT Code
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'UARTNZONE' 
   AND   Storerkey = @cStorerKey

   -- Check blank putaway strategy
   IF NOT EXISTS ( SELECT 1 FROM #PAZone)
   BEGIN
      SET @nErrNo = 138452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PA Zone
      GOTO Quit
   END

   SET @cSuggLOC = ''

   -- Find a friend, look for same Lot08 in putawayzone defined in codelkup
   SELECT TOP 1 @cSuggLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC <> @cFromLOC
   AND   LLI.SKU = @cSKU
   AND   LA.Lottable08 = @cLottable08
   AND   LOC.Facility = @cFacility
   GROUP BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) > 0
   ORDER BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      -- Find empty loc
      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
      WHERE LOC.Facility = @cFacility
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
      AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
      ORDER BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC

      IF @cSuggLOC = ''
      BEGIN
         SET @nErrNo = 138453 -- No Suggest Loc
         GOTO Quit
      END
   END

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtPASP23 -- For rollback or commit only our own transaction

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
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
   
      COMMIT TRAN rdt_1819ExtPASP23 -- Only commit change made here
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP23 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END


GO