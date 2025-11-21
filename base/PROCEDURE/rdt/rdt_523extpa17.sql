SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA17                                            */
/* Copyright      : LF Logistics                                              */  
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 19-11-2018  1.0  ChewKP   WMS-6885 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA17] (
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
   
   DECLARE @nTranCount INT
   DECLARE @cSuggToLOC NVARCHAR(10)
         , @cFriendLoc NVARCHAR(10) 
         , @cPutawayZone NVARCHAR(10) 
         , @nPackQty    INT
         , @cItemClass  NVARCHAR(10)
         , @cSUSR3      NVARCHAR(18)

   
                   
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = '' 
   
      
   SELECT TOP 1 @cPutawayZone = LA.Lottable06
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey 
   AND LLI.SKU = @cSKU 
   AND LLI.Loc = @cLoc
   AND LLI.ID  = @cID 
   AND LLI.QTY > 0 
   
   SELECT @nPackQty   = P.PackUOM8
         ,@cItemClass = SKU.ItemClass
         ,@cSUSR3     = SKU.SUSR3
   FROM dbo.SKU SKU WITH (NOLOCK) 
   INNER JOIN dbo.Pack P ON P.PackKey = SKU.PackKey
   WHERE SKU.StorerKey = @cStorerKey
   AND SKU.SKU = @cSKU

   
   -- Search Location < PackUOM8
   SELECT TOP 1 @cSuggToLoc = LLI.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cPutawayZone
      AND LOC.LOC <> @cLoc
      AND LOC.CommingleSKU  = '0'
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.Qty > 0   
   GROUP BY LOC.LogicalLocation, LLI.LOC
   HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) < @nPackQty 
   ORDER BY LOC.LogicalLocation, LLI.Loc
   

   IF ISNULL(@cSuggToLoc,'')  <> '' 
      GOTO LocationBooking
   
   -- Search Empty Location 
   SELECT TOP 1 @cSuggToLoc = LOC.LOC
   FROM LOC WITH (NOLOCK)
      --JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cPutawayZone
      AND LOC.LOC <> @cLoc
      AND LOC.CommingleSKU  = '0'
      --AND LLI.StorerKey = @cStorerKey
      --AND LLI.SKU = @cSKU
   GROUP BY LOC.LogicalLocation, LOC.LOC
   HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0)  = 0 
   ORDER BY LOC.LogicalLocation, LOC.Loc

   
   
   IF ISNULL(@cSuggToLoc,'')  <> '' 
      GOTO LocationBooking
   
   -- Search Empty Location near ItemClass
   SET @cFriendLoc = '' 
   SELECT TOP 1 @cFriendLoc = LLI.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN SKU SKU WITH (NOLOCK)  ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cPutawayZone
      AND LOC.LOC <> @cLoc
      AND LOC.CommingleSKU  = '0'
      AND LLI.StorerKey = @cStorerKey
      AND SKU.ItemClass = @cItemClass
   GROUP BY LOC.LogicalLocation, LLI.LOC
   HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) > 0 
   ORDER BY LOC.LogicalLocation, LLI.Loc

   
   IF ISNULL ( @cFriendLoc , '' ) = '' 
   BEGIN
      -- Search Empty Location near SUSR3
      SET @cFriendLoc = '' 
      SELECT TOP 1 @cFriendLoc = LLI.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN SKU SKU WITH (NOLOCK)  ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
      WHERE LOC.Facility = @cFacility
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LOC <> @cLoc
         AND LOC.CommingleSKU  = '0'
         AND LLI.StorerKey = @cStorerKey
         AND SKU.SUSR3 = @cSUSR3
      GROUP BY LOC.LogicalLocation, LLI.LOC
      HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) > 0 
      ORDER BY LOC.LogicalLocation, LLI.Loc

      
      IF ISNULL ( @cFriendLoc , '' ) <> '' 
      BEGIN
         SELECT TOP 1 @cSuggToLoc = LLI.LOC
         FROM LOC LOC WITH (NOLOCK)
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone
            AND LOC.LOC <> @cLoc
            AND LOC.CommingleSKU  = '0'
            --AND LLI.StorerKey = @cStorerKey
            AND LOC.LOC > @cFriendLoc
         GROUP BY LOC.LogicalLocation, LLI.LOC
         HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) = 0
         ORDER BY LOC.LogicalLocation, LLI.Loc


      END
      
      IF ISNULL( @cSuggToLoc , '' ) = '' 
      BEGIN
         SELECT TOP 1 @cSuggToLoc = LOC.LOC
         FROM LOC LOC WITH (NOLOCK)
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone
            AND LOC.LOC <> @cLoc
            AND LOC.CommingleSKU  = '0'
            --AND LLI.StorerKey = @cStorerKey
            --AND LOC.LOC > @cFriendLoc
            GROUP BY LOC.LogicalLocation, LOC.LOC
            HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) = 0 
            ORDER BY LOC.LogicalLocation, LOC.Loc

      END
        
      
   END
   ELSE
      SELECT TOP 1 @cSuggToLoc = LOC.LOC
      FROM LOC WITH (NOLOCK)
         --JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
      WHERE LOC.Facility = @cFacility
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LOC <> @cLoc
         AND LOC.CommingleSKU  = '0'
         --AND LLI.StorerKey = @cStorerKey
         AND LOC.LOC > @cFriendLoc
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING ISNULL(SUM(LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn),0) = 0 
      ORDER BY LOC.LogicalLocation, LOC.Loc
      

   
   IF ISNULL(@cSuggToLoc,'')  <> '' 
      GOTO LocationBooking
   
   
   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   LocationBooking:
   --SELECT @cSuggToLOC '@cSuggToLOC' 
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA17 -- For rollback or commit only our own transaction
      
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
         ,@cUCCNo        = @cUCC
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA17 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA17 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO