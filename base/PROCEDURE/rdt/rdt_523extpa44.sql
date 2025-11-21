SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA44                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2021-11-18  1.0  James     WMS-18316. Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA44] (
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
   
   DECLARE @nTranCount     INT
   DECLARE @cSuggToLOC     NVARCHAR( 10) = ''
   DECLARE @cTempSuggToLOC NVARCHAR( 10) = ''
   DECLARE @cTempLogicLoc  NVARCHAR( 10) = ''
   DECLARE @cBUSR2         NVARCHAR( 30) = ''
   DECLARE @cTempSku       NVARCHAR( 20) = ''
   DECLARE @tTempLoc TABLE (LOC NVARCHAR( 10))
     
   SET @nTranCount = @@TRANCOUNT
   
   -- Find a friend
   INSERT INTO @tTempLoc (LOC)
   SELECT LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cLOC
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   GROUP BY LOC.LOC
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
   
   -- Able to find loc, find loc witn min qty
   IF EXISTS ( SELECT 1 FROM @tTempLoc)
   BEGIN
      SELECT TOP 1   
         @cSuggToLOC = LOC.LOC  
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN @tTempLoc t ON ( LOC.LOC = t.LOC)
      WHERE LOC.Facility = @cFacility
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      GROUP BY LOC.LOC
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
      ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) DESC, LOC.Loc
   END
   
   -- Find other sku with same style(busr2)
   IF @cSuggToLOC = ''
   BEGIN      
      SELECT @cBUSR2 = BUSR2 
      FROM dbo.sku WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Sku = @cSKU
      
      SELECT TOP 1 
         @cTempSku = LLI.Sku
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.Sku)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LOC <> @cLOC
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU > @cSKU
      AND   SKU.BUSR2 = @cBUSR2
      GROUP BY LLI.Sku
      HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
      ORDER BY 1
      
      -- Able to find another sku with same style(busr2)
      IF ISNULL( @cTempSku, '') <> ''
      BEGIN
         SELECT TOP 1 
            @cTempSuggToLOC = LOC.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cLOC
         AND   LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cTempSku
         GROUP BY LOC.LOC
         HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
         ORDER BY LOC.Loc
         
         -- Find the 1st empty loc before the current suggested loc
         IF ISNULL( @cTempSuggToLOC, '') <> ''
         BEGIN
            SELECT @cTempLogicLoc = LogicalLocation
            FROM dbo.LOC WITH (NOLOCK)
            WHERE Facility = @cFacility
            AND   Loc = @cTempSuggToLOC
            
            SELECT TOP 1 @cSuggToLOC = LOC.Loc
            FROM dbo.LOC LOC WITH (NOLOCK)
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
            WHERE LOC.Facility = @cFacility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LOC.LogicalLocation < @cTempLogicLoc
            GROUP BY Loc.LogicalLocation, LOC.LOC
            HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
                  (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
            ORDER BY LOC.LogicalLocation DESC, LOC.LOC
         END
      END
   END

   IF ISNULL( @cSuggToLOC, '') = ''
   BEGIN
      SET @nErrNo = -1
      GOTO Quit
   END   

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA44 -- For rollback or commit only our own transaction

   IF @cSuggToLOC <> ''
   BEGIN
      SET @nErrNo = 0
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

      COMMIT TRAN rdt_523ExtPA44 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA44 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO