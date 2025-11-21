SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA55                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2023-01-18  1.0  James     WMS-21491. Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA55] (
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
   DECLARE @cStyle         NVARCHAR( 20) = ''
   DECLARE @cTempSuggSKU   NVARCHAR( 20) = ''
   DECLARE @cTempSuggSKUA  NVARCHAR( 20) = ''
   DECLARE @cTempSuggSKUB  NVARCHAR( 20) = ''
   	
   SET @nTranCount = @@TRANCOUNT
   
   -- Find assigned pick loc
   SELECT @cSuggToLOC = SL.LOC
   FROM dbo.LOC LOC WITH (NOLOCK) 
   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( LOC.LOC = SL.Loc)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cLOC
   AND   SL.StorerKey = @cStorerKey
   AND   SL.SKU = @cSKU
   AND   SL.LocationType = 'PICK'
   AND   SL.StorerKey = @cStorerKey
   GROUP BY SL.LOC
   
   -- No assigned pick loc
   IF ISNULL( @cSuggToLOC, '') = ''
   BEGIN
      SELECT TOP 1 @cSuggToLOC = LOC.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
      AND   LOC.LOC <> @cLOC
      AND   LOC.LocationType = 'PICK'
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      GROUP BY LOC.LOC
      HAVING SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
      ORDER BY SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) DESC, LOC.Loc
   
      -- No inventory with pick loc, find another sku, same style
      IF ISNULL( @cSuggToLOC, '') = ''
      BEGIN
         SELECT @cStyle = Style 
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKU

         SET @cTempSuggSKU = @cSKU

         -- Able to find another sku, same style, suggest assigned pick loc
         -- Only look for sku which contain digits only to minimize the search time
         -- Look for sku which nearer to the found same style sku
         -- Found sku: 10110111060022, closet sku: 10110111060020 and 10110111060025
         -- (10110111060022 - 10110111060020) = 2 | (10110111060025 - 10110111060020) = 5
         -- Take 10110111060022 as it is nearer (different by 2)
         IF ISNULL( @cTempSuggSKU, '') <> '' AND ISNUMERIC( @cTempSuggSKU) = 1
         BEGIN
            SELECT TOP 1 
               @cTempSuggSKUA = LLI.Sku
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.Sku)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cLOC
            AND   LLI.StorerKey = @cStorerKey
            AND   LLI.SKU < @cTempSuggSKU
            AND   SKU.Style = @cStyle
            GROUP BY LLI.Sku
            HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
            ORDER BY 1 DESC

            SELECT TOP 1 
               @cTempSuggSKUB = LLI.Sku
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.Sku)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cLOC
            AND   LLI.StorerKey = @cStorerKey
            AND   LLI.SKU > @cTempSuggSKU
            AND   SKU.Style = @cStyle
            GROUP BY LLI.Sku
            HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
            ORDER BY 1

            IF ISNULL( @cTempSuggSKUA, '') <> '' AND ISNULL( @cTempSuggSKUB, '') <> ''
            BEGIN -- Use BIGINT here as SKU all in digits and > 10 chars
            	IF ( CAST( @cTempSku AS BIGINT) - CAST( @cTempSuggSKUA AS BIGINT)) < ( CAST( @cTempSuggSKUB AS BIGINT) - CAST( @cTempSku AS BIGINT))
            	   SET @cTempSku = @cTempSuggSKUA
            	ELSE IF ( CAST( @cTempSku AS BIGINT) - CAST( @cTempSuggSKUA AS BIGINT)) > ( CAST( @cTempSuggSKUB AS BIGINT) - CAST( @cTempSku AS BIGINT))
            	   SET @cTempSku = @cTempSuggSKUB
            	ELSE
            		SET @cTempSku = @cTempSuggSKUA
            END
            ELSE IF ISNULL( @cTempSuggSKUA, '') <> '' AND ISNULL( @cTempSuggSKUB, '') = ''
               SET @cTempSku = @cTempSuggSKUA
            ELSE
            	SET @cTempSku = @cTempSuggSKUB
            
            -- Look for assigned pick loc for alternate sku with same style
            SET @cTempSuggToLOC = ''
            SELECT TOP 1 @cTempSuggToLOC = SL.LOC
            FROM dbo.LOC LOC WITH (NOLOCK) 
            JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( LOC.LOC = SL.Loc)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LOC <> @cLOC
            AND   SL.StorerKey = @cStorerKey
            AND   SL.SKU = @cTempSku
            AND   SL.LocationType = 'PICK'
            AND   SL.StorerKey = @cStorerKey
            GROUP BY SL.LOC
         
            -- Not able to find another sku assigned pick loc, same style, suggest loc with locationtype = 'pick'
            IF ISNULL( @cTempSuggToLOC, '') = ''
            BEGIN
               SELECT TOP 1 @cTempSuggToLOC = LOC.LOC
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
               AND   LOC.LOC <> @cLOC
               AND   LOC.LocationType = 'PICK'
               AND   LLI.StorerKey = @cStorerKey
               AND   LLI.SKU = @cTempSku
               GROUP BY LOC.LOC
               HAVING SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
               ORDER BY 1
            END

            -- Able to find loc for another sku, same style, suggest first empty loc
            IF ISNULL( @cTempSuggToLOC, '') <> ''
            BEGIN
               SELECT @cTempLogicLoc = LogicalLocation
               FROM dbo.LOC WITH (NOLOCK)
               WHERE Facility = @cFacility
               AND   Loc = @cTempSuggToLOC
            
               SELECT TOP 1 @cSuggToLOC = LOC.Loc
               FROM dbo.LOC LOC WITH (NOLOCK)
               LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.Loc = LLI.LOC )
               WHERE LOC.Facility = @cFacility
               AND   LOC.Locationflag <> 'HOLD'
               AND   LOC.Locationflag <> 'DAMAGE'
               AND   LOC.Status <> 'HOLD'
               AND   LOC.LocationType = 'PICK'
               AND   LOC.LogicalLocation < @cTempLogicLoc
               AND   NOT EXISTS ( SELECT 1
                                  FROM dbo.SKUxLOC SL WITH (NOLOCK)
                                  WHERE LOC.Loc = SL.LOC 
                                  AND   SL.LocationType = 'PICK')
               GROUP BY Loc.LogicalLocation, LOC.LOC
               HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
                     (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
               ORDER BY LOC.LogicalLocation DESC, LOC.LOC
            END

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
   SAVE TRAN rdt_523ExtPA55 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA55 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA55 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO