SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA40                                      */
/*                                                                      */
/* Purpose: Use RDT config to get suggested loc else prompt error msg   */
/*                                                                      */
/* Called from: rdt_PutawayBySKU_GetSuggestLOC                          */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-06-18   1.0  James    WMS-17375. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA40] (
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
   @cSuggestedLOC    NVARCHAR( 10) = ''   OUTPUT,
   @nPABookingKey    INT                  OUTPUT,
   @nErrNo           INT                  OUTPUT,
   @cErrMsg          NVARCHAR( 20)        OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cHostWHCode       NVARCHAR( 10)
   
   SET @cSuggestedLOC = ''

   -- Get pallet info
   SELECT TOP 1
      @cHostWHCode = LOC.HOSTWHCODE 
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LLI.LOC = @cLOC 
   AND   LLI.Id = @cID
   AND   LLI.Sku = @cSKU
   AND   LLI.QTY > 0
   ORDER BY 1

   SELECT @cPutawayZone = PutawayZone
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   Sku = @cSKU

   IF @cHostWHCode = 'aBL'
   BEGIN
      -- Find Friend
      SELECT TOP 1 
         @cSuggestedLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LocationFlag <> 'HOLD' 
      AND   LOC.HOSTWHCODE = @cHostWHCode
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))
      AND   LLI.LOC <> @cLOC  
      ORDER BY LA.Lottable05 DESC
      
      -- Find empty loc
      IF @cSuggestedLOC = ''
         SELECT TOP 1 @cSuggestedLOC = LOC.Loc
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
      -- Find Friend
      SELECT TOP 1 
         @cSuggestedLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LocationFlag <> 'HOLD' 
      AND   LOC.HOSTWHCODE = 'UU'
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))
      AND   LOC.LOC <> @cLOC
      ORDER BY LA.Lottable05 ASC

      -- Find empty loc
      IF @cSuggestedLOC = ''
      BEGIN
         SELECT TOP 1 @cSuggestedLOC = LOC.Loc
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
      SELECT TOP 1 @cSuggestedLOC = LOC.Loc
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
      SET @nErrNo = 169901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv HostWHCode
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF ISNULL( @cSuggestedLOC, '') <> ''
   BEGIN
      SET @nErrNo = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   Quit:

END

GO