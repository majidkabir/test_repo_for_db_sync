SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_523ExtPA04                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 31-Mar-2017  1.0  James    WMS1482. Created                          */
/* 17-Jul-2017  1.1  James    Add storerkey validation (james01)        */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA_C_1] (
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

   DECLARE 
      @cPAZone         NVARCHAR( 10), 
      @cLottable01     NVARCHAR( 18), 
      @cLottable02     NVARCHAR( 18),
	  @cLottable08     NVARCHAR( 18),
      @cRetrunSTG       NVARCHAR( 1), 
      @cQuarantine     NVARCHAR( 1),
      @cHazmatClass    NVARCHAR( 30)

   SET @cSuggestedLOC = ''
   SET @cPAZone = ''
   SET @cRetrunSTG = '0'
   SET @cQuarantine = '0'

   -- 1 loc only for all quarantine product, no mater is hazardous or not
   IF EXISTS ( SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK) 
               JOIN dbo.SKUInfo SIF WITH (NOLOCK) ON ( SKU.SKU = SIF.SKU AND SKU.StorerKey = SIF.Storerkey)
               WHERE SKU.StorerKey = @cStorerKey
               AND   SKU.SKU = @cSKU
               AND   SIF.ExtendedField20 = 'Q' )
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                      WHERE Facility = @cFacility
                      AND   Loc = 'QUARANTINE'
                      AND   Putawayzone = 'QUARANTINE')
      BEGIN
         SET @cSuggestedLOC = ''
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cSuggestedLOC = 'QUARANTINE'
         SET @cQuarantine = '1'
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      -- Check for return flag
      SELECT @cRetrunSTG = ISNULL( listname, ''),
	         @cPAZone   = ISNULL( long, '')
      FROM dbo.codelkup WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   short = @cLOC
	  AND   listname = 'UARESTAGE'

      IF @cRetrunSTG = ''
         SET @cRetrunSTG = '0'

      -- Get Lottables
      SELECT @cLottable01 = Lottable01, 
	         @cLottable08 = Lottable08, 
             @cLottable02 = Lottable02  
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE LOT = @cLOT

      IF @cRetrunSTG = '0'
      BEGIN
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationCategory = 'OTHER'
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
		 AND   LOC.Locationtype = 'DYNPPICK'
         AND   LOC.PutawayZone = @cPAZone
         AND   LLI.SKU = @cSKU
         AND   LA.Lottable01 = @cLottable01
         AND   LA.Lottable02 = @cLottable02
		 AND   LA.Lottable08 = @cLottable08
         GROUP BY LOC.LogicalLocation, LOC.LOC 
         -- Not Empty LOC
         HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
         ORDER BY LOC.LogicalLocation, LOC.LOC 

         IF ISNULL( @cSuggestedLOC, '') = ''
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationCategory = 'OTHER'
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
			AND   LOC.Locationtype = 'DYNPPICK'
            AND   LOC.PutawayZone = @cPAZone
			AND   LOC.loc not in (select toloc from dbo.replenishment(nolock) where storerkey = 'ua' and confirmed = 'N')
            --AND   LLI.SKU = @cSKU
            GROUP BY LOC.LogicalLocation, LOC.LOC 
            --Empty LOC
            --HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
			HAVING ISNULL(SUM(LLI.Qty), 0) = 0
            ORDER BY LOC.LogicalLocation, LOC.LOC 

         -- If cannot find loc in same sku putawayzone, then look for all putawayzone 
         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC 
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
			AND   LOC.Locationtype = 'DYNPPICK'
            AND   LOC.PutawayZone = @cStorerKey
            GROUP BY LOC.LogicalLocation, LOC.LOC 
            -- Empty LOC
            HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
            ORDER BY LOC.LogicalLocation, LOC.LOC 
         END
      END
      ELSE  -- return item putaway
      BEGIN
         -- same lot01,lot08
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.LOC <> @cLOC
		 AND   LOC.PUTAWAYZONE = @cPAZone
         AND   LLI.SKU = @cSKU
         AND   LA.Lottable08 = @cLottable08
         AND   LOC.Facility = @cFacility
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) > 0
         ORDER BY Loc.LogicalLocation, LOC.LOC
         
         -- Check suggest loc
         IF @cSuggestedLOC = ''
         BEGIN
            -- Find empty loc
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
            WHERE LOC.Facility = @cFacility
            AND   LOC.Locationflag <> 'HOLD'
			AND   LOC.PUTAWAYZONE = @cPAZone
           AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            GROUP BY Loc.LogicalLocation, LOC.LOC
            HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
            AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
            ORDER BY Loc.LogicalLocation, LOC.LOC
		END
      END
   END

   QUIT:

END

GO