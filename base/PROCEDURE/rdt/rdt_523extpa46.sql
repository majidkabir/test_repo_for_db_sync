SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA46                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2022-02-03   1.0  Ung      WMS-18864 Created base on rdt_523ExtPA34  */
/*                            Add product zone, default LOC             */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA46] (
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
   
   DECLARE @cUCC_Lot    NVARCHAR( 10)
   DECLARE @cUCC_SKU    NVARCHAR( 20)
   DECLARE @cUCC_Lot02  NVARCHAR( 18)
   DECLARE @cUCC_Lot03  NVARCHAR( 18)
   DECLARE @dUCC_Lot04  DATETIME
   DECLARE @nTranCount  INT
   DECLARE @cBUSR4      NVARCHAR( 200)
   DECLARE @cPAZone     NVARCHAR( 10) = ''
   DECLARE @cDefaultLOC NVARCHAR( 10) = ''

   SELECT TOP 1 @cUCC_Lot = Lot
   FROM dbo.UCC WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   UCCNo = @cUCC
   AND   [Status] = '1'
   ORDER BY 1
   
   SELECT @cUCC_SKU = Sku, 
          @cUCC_Lot02 = Lottable02, 
          @cUCC_Lot03 = Lottable03, 
          @dUCC_Lot04 = Lottable04
   FROM DBO.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @cUCC_Lot
   
   -- Get SKU info
   SELECT @cBUSR4 = ISNULL( BUSR4, '')
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cUCC_SKU
   
   -- Get product zone and LOC
   SELECT 
      @cPAZone = ISNULL( Short, ''), 
      @cDefaultLOC = ISNULL( Long, '')
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'SEPPAZONE'
      AND Code = @cBUSR4
      AND StorerKey = @cStorerKey
      AND Code2 = CAST( @nFunc AS NVARCHAR(4))
   
   SET @cSuggestedLOC = ''

   -- Find a friend (same SKU, L2, L3, L4)
   SELECT TOP 1 @cSuggestedLOC = LLI.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
   WHERE LLI.StorerKey = @cStorerKey 
   AND   LLI.SKU = @cUCC_SKU
   AND   LLI.QTY-LLI.QTYPicked > 0
   AND   LOC.LocationCategory = 'SHELVING' 
   AND   LOC.LocationType = 'DYNPPICK'
   AND   LOC.Facility = @cFacility
   AND   LOC.PutawayZone = @cPAZone
   AND   ( LA.SKU + LA.Lottable02 + LA.Lottable03 + CAST( LA.Lottable04 AS NVARCHAR( 10))) = 
         ( @cUCC_SKU + @cUCC_Lot02 + @cUCC_Lot03 + CAST( @dUCC_Lot04 AS NVARCHAR( 10)))
   ORDER BY 1
   
   -- Find empty LOC
   IF @cSuggestedLOC = ''
   BEGIN
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @cFacility
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      AND   LOC.LocationCategory = 'SHELVING' 
      AND   LOC.LocationType = 'DYNPPICK'
      AND   LOC.PutawayZone = @cPAZone
      GROUP BY Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
      AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
      ORDER BY Loc.LogicalLocation, LOC.LOC        
   END

   -- Default LOC
   IF @cSuggestedLOC = ''
      SET @cSuggestedLOC = @cDefaultLOC

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA46 -- For rollback or commit only our own transaction

   IF @cSuggestedLOC <> ''
   BEGIN
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
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      COMMIT TRAN rdt_523ExtPA46 -- Only commit change made here
   END
   GOTO Quit   

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA46 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO