SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP15                                   */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 19-Apr-2018  1.0  Ung      WMS-4687 Created                          */
/* 10-Jul-2018  1.1  Ung      WMS-5665 Add LocationCategory             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP15] (
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
   DECLARE @cPutawayZone      NVARCHAR(10)

   -- Get current zone
   SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC 

   -- Find empty LOC
   SELECT TOP 1 
      @cSuggLOC = LOC.LOC
   FROM LOC WITH (NOLOCK)
      LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
   WHERE LOC.Facility = @cFacility
      AND LOC.HostWHCode = 'NEW'
      AND LOC.PutawayZone = @cPutawayZone
      AND LOC.LocationCategory <> 'STAGE'
   GROUP BY LOC.PALogicalLOC, LOC.LOC
   HAVING SUM( ISNULL( QTY, 0) - ISNULL( QTYPicked, 0)) = 0 AND
      SUM( ISNULL( PendingMoveIn, 0)) = 0
   ORDER BY LOC.PALogicalLOC, LOC.LOC

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP04 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_1819ExtPASP15 -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP15 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO