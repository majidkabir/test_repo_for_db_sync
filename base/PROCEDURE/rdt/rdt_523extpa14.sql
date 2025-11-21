SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA14                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 13-06-2018  1.0  Ung      WMS-5404 Created                           */
/* 15-02-2019  1.1  Ung      WMS-8025 Add lottable02                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA14] (
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
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   DECLARE @cLottable02 NVARCHAR( 18)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''

   SELECT @cLottable02 = V_Lottable02 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   /*-------------------------------------------------------------------------------------------
                        Find a friend (same SKU and Lottable02) with min QTY
   --------------------------------------------------------------------------------------------*/
   -- IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC'))
   --    DROP TABLE #tFriendLOC

   -- Find friends (same SKU) 
   SELECT TOP 1
      @cSuggToLOC = LOC.LOC
   -- INTO #tFriendLOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
      AND LOC.HostWHCode IN
         (SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'PUTHOSTWH' AND StorerKey = @cStorerKey)
      AND LOC.LocationFlag = 'NONE'
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LA.Lottable02 = @cLottable02
      AND LLI.QTY-LLI.QTYPicked > 0
   GROUP BY LOC.LOC
   ORDER BY SUM( LLI.QTY-LLI.QTYPicked)
      
   /*
   -- Find a friend with min QTY (QTY of all SKU in LOC)
   IF @@ROWCOUNT > 0
   BEGIN
      SELECT TOP 1
         @cSuggToLOC = SL.LOC
      FROM #tFriendLOC F
         JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
      GROUP BY SL.LOC
      ORDER BY SUM( SL.QTY-SL.QTYPicked)
   END
   */

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA14 -- For rollback or commit only our own transaction
      
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
   ROLLBACK TRAN rdt_523ExtPA14 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO