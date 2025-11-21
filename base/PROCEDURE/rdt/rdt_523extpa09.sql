SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA09                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 04-12-2017  1.0  Ung      WMS-3565 Created                                 */
/* 10-07-2018  1.1  Ung      WMS-5676 Add min QTY in LOC                      */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA09] (
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

   IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC'))
      DROP TABLE #tFriendLOC
   
   -- Find a friend with min QTY
   SELECT DISTINCT LOC.LOC
   INTO #tFriendLOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LOC.LOCAisle = @cID
      AND LOC.LocationFlag <> 'HOLD'
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.QTY-LLI.QTYPicked > 0
      AND LOC.LOC <> @cLOC
      
   -- Find a friend with min QTY
   IF @@ROWCOUNT > 0
   BEGIN
      SELECT TOP 1
         @cSuggToLOC = SL.LOC
      FROM #tFriendLOC F
         JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
      GROUP BY SL.LOC
      ORDER BY SUM( SL.QTY-SL.QTYPicked)
   END
   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA09 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_523ExtPA09 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA09 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO