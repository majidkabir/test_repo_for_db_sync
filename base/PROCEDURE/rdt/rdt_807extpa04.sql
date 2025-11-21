SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_807ExtPA04                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 16-11-2018  1.0  ChewKP   WMS-6904 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_807ExtPA04] (
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
   DECLARE @cColor      NVARCHAR(10)
   DECLARE @cPutawayZone      NVARCHAR(10)
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   DECLARE @curPA       CURSOR
          ,@cLottable06 NVARCHAR(20) 


--   DECLARE @tFriendLOC TABLE
--   (
--      LOC NVARCHAR(10) NOT NULL PRIMARY KEY CLUSTERED
--   )

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
         SELECT LLI.LOC, LLI.ID, LLI.LOT, LLI.SKU, LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked, LA.Lottable06
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.LOT AND LA.SKU = LLI.SKU AND LA.StorerKey = LLI.StorerKey
      	WHERE LOC.Facility = @cFacility
      	   AND LLI.StorerKey = @cStorerKey
      	   AND LLI.ID = @cToteID
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
            AND LOC.PutawayZone = 'PMASTAGE'
            --AND LLI.SKU = '35263405011'
         ORDER BY LOC.LogicalLocation, LOC.LOC, LLI.SKU, LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked
      OPEN @curPA
      FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY, @cLottable06
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cSuggToLOC = ''
   
         -- Get current zone
         --SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC
         SELECT @cStyle = Style 
               ,@cColor = Color 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         -- Clear temp table
         --DELETE @tFriendLOC
         
         --Search PMAGOOD
         SELECT TOP 1 @cSuggToLOC = LLI.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = 'PMAGOOD'
            AND LOC.LocationCategory <> 'STAGE'
            AND ISNULL(LOC.HostWHCode,'')  = ''
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            AND LA.Lottable06 = @cLottable06
            AND LOC.PutawayZone <> 'PMASTAGE'
         ORDER BY LLI.Qty, LOC.LogicalLocation, LOC.Loc

         IF ISNULL(@cSuggToLoc,'')  <> '' 
            GOTO LocBooking

         --Search PMA1101
         SELECT TOP 1 @cSuggToLOC = LLI.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = 'PMA1101'
            AND LOC.LocationCategory <> 'STAGE'
            AND ISNULL(LOC.HostWHCode,'') = ''
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            AND LA.Lottable06 = @cLottable06
            AND LOC.PutawayZone <> 'PMASTAGE'
         ORDER BY LLI.Qty, LOC.LogicalLocation, LOC.Loc    

        IF ISNULL(@cSuggToLoc,'')  <> '' 
            GOTO LocBooking

         --Search PMAGOOD with Same Material 
         SELECT TOP 1 @cSuggToLOC = LLI.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
            JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = 'PMAGOOD'
            AND LOC.LocationCategory <> 'STAGE'
            AND ISNULL(LOC.HostWHCode,'') = ''
            AND LLI.StorerKey = @cStorerKey
            --AND LLI.SKU = @cSKU
            AND SKU.Style = @cStyle 
            AND SKU.Color = @cColor 
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            AND LA.Lottable06 = @cLottable06
            AND LOC.PutawayZone <> 'PMASTAGE'
         ORDER BY LLI.Qty, LOC.LogicalLocation, LOC.Loc 

         IF ISNULL(@cSuggToLoc,'')  <> '' 
            GOTO LocBooking

         --Search PMA1101 with Same Material 
         SELECT TOP 1 @cSuggToLOC = LLI.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
            JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = 'PMA1101'
            AND LOC.LocationCategory <> 'STAGE'
            AND ISNULL(LOC.HostWHCode,'') = ''
            AND LLI.StorerKey = @cStorerKey
            --AND LLI.SKU = @cSKU
            AND SKU.Style = @cStyle 
            AND SKU.Color = @cColor 
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            AND LA.Lottable06 = @cLottable06
            AND LOC.PutawayZone <> 'PMASTAGE'
         ORDER BY LLI.Qty, LOC.LogicalLocation, LOC.Loc    

         

--         
--                
--         
--         -- Find friend (same SKU) 
--         INSERT INTO @tFriendLOC (LOC)
--         SELECT DISTINCT LOC.LOC
--         FROM LOTxLOCxID LLI WITH (NOLOCK)
--            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
--         WHERE LOC.Facility = @cFacility
--            AND LOC.PutawayZone = @cPutawayZone
--            AND LOC.LocationCategory <> 'STAGE'
--            AND LOC.HostWHCode = ''
--            AND LLI.StorerKey = @cStorerKey
--            AND LLI.SKU = @cSKU
--            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
--
--         -- Find a friend LOC with min QTY (regardless of SKU)
--         IF @@ROWCOUNT > 0
--         BEGIN
--            SELECT TOP 1
--               @cSuggToLOC = LLI.LOC
--            FROM @tFriendLOC F
--               JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (F.LOC = LLI.LOC)
--            WHERE LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
--            GROUP BY LLI.LOC
--            ORDER BY SUM( LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn)
--         END
--
--         -- Find friend (same style) 
--         IF @cSuggToLOC = ''
--         BEGIN
--            -- Get SKU info
--            SELECT 
--               @cStyle = Style, 
--               @cColor = Color
--            FROM SKU WITH (NOLOCK)
--            WHERE StorerKey = @cStorerKey
--               AND SKU = @cSKU
--
--            -- Clear temp table
--            DELETE @tFriendLOC
--
--            INSERT INTO @tFriendLOC (LOC)
--            SELECT DISTINCT LOC.LOC
--            FROM LOTxLOCxID LLI WITH (NOLOCK)
--               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
--               JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
--            WHERE LOC.Facility = @cFacility
--               AND LOC.PutawayZone = @cPutawayZone
--               AND LOC.LocationCategory <> 'STAGE'
--               AND LOC.HostWHCode = ''
--               AND SKU.StorerKey = @cStorerKey
--               AND SKU.Style = @cStyle
--               AND SKU.Color = @cColor
--               AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
--         
--            -- Find a friend LOC with min QTY (regardless of SKU)
--            IF @@ROWCOUNT > 0
--            BEGIN
--               SELECT TOP 1
--                  @cSuggToLOC = LLI.LOC
--               FROM @tFriendLOC F
--                  JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (F.LOC = LLI.LOC)
--               WHERE LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
--               GROUP BY LLI.LOC
--               ORDER BY SUM( LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn)
--            END
--         END
--         
--         -- Find an empty LOC
--         IF @cSuggToLOC = '' 
--         BEGIN
--            SELECT TOP 1 
--               @cSuggToLOC = LOC.LOC
--            FROM LOC WITH (NOLOCK)
--               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
--            WHERE LOC.Facility = @cFacility
--               AND LOC.PutawayZone = @cPutawayZone
--               AND LOC.LocationCategory <> 'STAGE'
--               AND LOC.HostWHCode = ''
--            GROUP BY LOC.PALogicalLOC, LOC.LOC
--            HAVING SUM( ISNULL( LLI.QTY, 0)-ISNULL( LLI.QTYPicked, 0)) = 0
--               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
--            ORDER BY LOC.LOC DESC
--         END

         /*-------------------------------------------------------------------------------
                                       Book suggested location
         -------------------------------------------------------------------------------*/

         LocBooking:
         --PRINT @cSuggToLOC
         IF @cSuggToLOC <> ''
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_807ExtPA04 -- For rollback or commit only our own transaction
            
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
      
            COMMIT TRAN rdt_807ExtPA04 -- Only commit change made here
         END
      
         FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY, @cLottable06
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
         SAVE TRAN rdt_807ExtPA04 -- For rollback or commit only our own transaction
         
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
            ,'' --@cLOC
            ,@cID
            ,'' --@cSuggToLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
   
         COMMIT TRAN rdt_807ExtPA04 -- Only commit change made here
      
         FETCH NEXT FROM @curPA INTO @cID
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_807ExtPA04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO