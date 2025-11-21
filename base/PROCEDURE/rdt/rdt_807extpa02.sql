SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_807ExtPA02                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 07-05-2018  1.0  Ung      WMS-4741 Created                                 */
/* 20-07-2018  1.1  Ung      WMS-5694 Add LOC.LocationCategory                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_807ExtPA02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cType            NVARCHAR( 10),
   @cCartID          NVARCHAR( 10),
   @cToteID          NVARCHAR( 20),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @cStyle      NVARCHAR(20)
   DECLARE @cPutawayZone      NVARCHAR(10)
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   DECLARE @curPA       CURSOR

   DECLARE @tFriendLOC TABLE
   (
      LOC NVARCHAR(10) NOT NULL PRIMARY KEY CLUSTERED
   )

   SET @nTranCount = @@TRANCOUNT
   
   IF @cType = 'LOCK'
   BEGIN
      -- Check ID booked
      IF EXISTS( SELECT 1 
         FROM RFPutaway R WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (R.FromLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND R.FromID = @cToteID)
         GOTO Quit

      SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.LOC, LLI.ID, LLI.LOT, LLI.SKU, LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      	WHERE LOC.Facility = @cFacility
      	   AND LLI.StorerKey = @cStorerKey
      	   AND LLI.ID = @cToteID
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
      OPEN @curPA
      FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cSuggToLOC = ''
   
         -- Get current zone
         SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

         -- Clear temp table
         DELETE @tFriendLOC
         
         -- Find friend (same SKU) 
         INSERT INTO @tFriendLOC (LOC)
         SELECT DISTINCT LOC.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone
            AND LOC.LocationCategory <> 'STAGE'
            AND LOC.HostWHCode = ''
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0

         -- Find a friend LOC with min QTY (regardless of SKU)
         IF @@ROWCOUNT > 0
         BEGIN
            SELECT TOP 1
               @cSuggToLOC = LLI.LOC
            FROM @tFriendLOC F
               JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (F.LOC = LLI.LOC)
            WHERE LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            GROUP BY LLI.LOC
            ORDER BY SUM( LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn)
         END

         -- Find friend (same style) 
         IF @cSuggToLOC = ''
         BEGIN
            -- Get SKU info
            SELECT @cStyle = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

            -- Clear temp table
            DELETE @tFriendLOC

            INSERT INTO @tFriendLOC (LOC)
            SELECT DISTINCT LOC.LOC
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone = @cPutawayZone
               AND LOC.LocationCategory <> 'STAGE'
               AND LOC.HostWHCode = ''
               AND SKU.StorerKey = @cStorerKey
               AND SKU.Style = @cStyle
               AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
         
            -- Find a friend LOC with min QTY (regardless of SKU)
            IF @@ROWCOUNT > 0
            BEGIN
               SELECT TOP 1
                  @cSuggToLOC = LLI.LOC
               FROM @tFriendLOC F
                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (F.LOC = LLI.LOC)
               WHERE LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
               GROUP BY LLI.LOC
               ORDER BY SUM( LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn)
            END
         END
         
         -- Find an empty LOC
         IF @cSuggToLOC = '' 
         BEGIN
            SELECT TOP 1 
               @cSuggToLOC = LOC.LOC
            FROM LOC WITH (NOLOCK)
               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone = @cPutawayZone
               AND LOC.LocationCategory <> 'STAGE'
               AND LOC.HostWHCode = ''
            GROUP BY LOC.PALogicalLOC, LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0)-ISNULL( LLI.QTYPicked, 0)) = 0
               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
            ORDER BY LOC.LOC DESC
         END

         /*-------------------------------------------------------------------------------
                                       Book suggested location
         -------------------------------------------------------------------------------*/
         IF @cSuggToLOC <> ''
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_807ExtPA02 -- For rollback or commit only our own transaction
            
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
   
            IF @nErrNo <> 0
               GOTO RollBackTran
      
            COMMIT TRAN rdt_807ExtPA02 -- Only commit change made here
         END
      
         FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY
      END
      GOTO Quit
   END
   
   IF @cType = 'UNLOCK'
   BEGIN
      -- Check cart have ID booked
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         GOTO Quit
      
      SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ToteID
         FROM rdt.rdtPACartLog WITH (NOLOCK)
      	WHERE CartID = @cCartID
      OPEN @curPA
      FETCH NEXT FROM @curPA INTO @cID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_807ExtPA02 -- For rollback or commit only our own transaction
         
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
            ,'' --@cLOC
            ,@cID
            ,'' --@cSuggToLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
   
         COMMIT TRAN rdt_807ExtPA02 -- Only commit change made here
      
         FETCH NEXT FROM @curPA INTO @cID
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_807ExtPA02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO