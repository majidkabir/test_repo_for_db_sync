SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP45                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2023-03-30   1.0  James    WMS-22049. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP45] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10) = ''  OUTPUT,
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
   
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cLottable02    NVARCHAR( 18)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cPAZone        NVARCHAR( 10)
   DECLARE @cFriendLoc     NVARCHAR( 10) = ''
   
   DECLARE @nTranCount  INT

   -- User scan ID and this ID only will contain 1 lottable01+lottable02
   SELECT TOP 1 
      @cLottable01 = LA.Lottable01,
      @cLottable02 = LA.Lottable02,
      @cSKU = LA.Sku
   FROM dbo.LotxLocxID LLI WITH (NOLOCK)
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.ID = @cID
   AND   LOC.Facility = @cFacility
   GROUP BY LA.Lottable01, LA.Lottable02, LA.Sku
   HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) > 0
   ORDER BY 1
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 198601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID No Record
      GOTO Fail
   END
   
   -- Get PutAwayZone
   IF @cLottable01 = 'BS' AND @cLottable02 = 'ZP'
      SET @cPAZone = 'BS'
   ELSE IF @cLottable01 = 'FB' AND @cLottable02 = 'ZP'
      SET @cPAZone = 'FB'
   ELSE IF @cLottable02 = 'CC'
      SET @cPAZone = 'CC'

   -- Find friend
   SELECT TOP 1 @cFriendLoc = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cFromLOC
   AND   LOC.PutawayZone = @cPAZone
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   GROUP BY LOC.LOC
   HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) > 0
   ORDER BY LOC.Loc

   -- Able find friend, find empty loc next to it
   IF ISNULL( @cFriendLoc, '') <> ''
   BEGIN
      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.Loc = LLI.LOC )
      WHERE LOC.Facility = @cFacility
      AND   LOC.PutawayZone = @cPAZone
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      AND   LOC.Loc > @cFriendLoc
      GROUP BY LOC.LOC
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0
      ORDER BY LOC.Loc
      
      IF ISNULL( @cSuggLOC, '') = ''
      BEGIN
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.Loc = LLI.LOC )
         WHERE LOC.Facility = @cFacility
         AND   LOC.PutawayZone = @cPAZone
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LOC.Loc < @cFriendLoc
         GROUP BY LOC.LOC
         HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0
         ORDER BY LOC.Loc DESC
      END
   END

   -- No suggest loc, find empty
   IF ISNULL( @cSuggLOC, '') = ''
   BEGIN
      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.Loc = LLI.LOC )
      WHERE LOC.Facility = @cFacility
      AND   LOC.PutawayZone = @cPAZone
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LOC
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0
      ORDER BY LOC.Loc
   END

   IF ISNULL( @cSuggLOC, '') = ''
   BEGIN
      SET @nErrNo = 198602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggest Loc
      GOTO Fail
   END
   
   IF ISNULL( @cSuggLOC, '') <> ''
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP45 -- For rollback or commit only our own transaction

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
      
      COMMIT TRAN rdt_1819ExtPASP45

      GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP45 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

Fail:

END


GO