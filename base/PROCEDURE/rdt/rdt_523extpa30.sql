SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_523ExtPA30                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 28-02-2020  1.0  Chermaine WMS-12278 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA30] (
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
  
   
   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @cColor         NVARCHAR(10)
   DECLARE @cPutawayZone   NVARCHAR(10)
   DECLARE @cLottable06    NVARCHAR(20) 
   DECLARE @curTask        CURSOR
   DECLARE @curTask2       CURSOR
      
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggestedLOC = ''

   
   SELECT TOP 1 @cLottable06 = ISNULL(LA.Lottable06,'')
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.LOT AND LA.SKU = LLI.SKU AND LA.StorerKey = LLI.StorerKey
   WHERE LLI.StorerKey = @cStorerKey
      AND LLI.ID = @cID
      AND LLI.LOC = @cLOC
      AND LLI.SKU = @cSKU 
   
   SELECT @cStyle = Style 
         ,@cColor = Color 
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND SKU = @cSKU 
   
   SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT udf01 
      FROM codelkup (nolock) 
      WHERE listname = 'PUMAPZ' 
      AND StorerKey = @cStorerKey 
      ORDER BY code
  
   OPEN @curTask
   FETCH NEXT FROM @curTask INTO @cPutawayZone
   WHILE @@FETCH_STATUS = 0
   BEGIN

   SELECT TOP 1 @cSuggestedLOC = LLI.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cPutawayZone
      AND LOC.LocationCategory <> 'STAGE'
      AND ISNULL(LOC.HostWHCode,'')  = ''
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
      AND LA.Lottable06 = @cLottable06
      AND LOC.PutawayZone <> 'PMASTAGE'
   ORDER BY LLI.Qty, LOC.LogicalLocation, LOC.Loc

   IF ISNULL(@cSuggestedLOC,'')  <> '' 
      GOTO LocBooking
      
   FETCH NEXT FROM @curTask INTO @cPutawayZone
   END


   --look for Same Material 
   SET @curTask2 = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT udf01 
      FROM codelkup (nolock) 
      WHERE listname = 'PUMAPZ' 
      AND StorerKey = @cStorerKey 
      ORDER BY code
  
   OPEN @curTask2
   FETCH NEXT FROM @curTask2 INTO @cPutawayZone
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	
   SELECT TOP 1 @cSuggestedLOC = LLI.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
      JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey 
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cPutawayZone
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

   IF ISNULL(@cSuggestedLOC,'')  <> '' 
      GOTO LocBooking
      
   FETCH NEXT FROM @curTask2 INTO @cPutawayZone
   END

   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/

   LocBooking:
   
   IF @cSuggestedLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA18 -- For rollback or commit only our own transaction
      
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
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

      SET @cSuggestedLOC = @cSuggestedLOC
   
      
      COMMIT TRAN rdt_523ExtPA18 -- Only commit change made here
   END
   
   
   
   
  
   
GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA18 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO