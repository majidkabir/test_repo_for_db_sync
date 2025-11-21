SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA01                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 16-Feb-2017  1.0  James    WMS1079. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA01] (
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
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,  
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
      @cQuarantine     NVARCHAR( 1), 
      @cLottable01     NVARCHAR( 18), 
      @cLottable02     NVARCHAR( 18), 
      @cLottable03     NVARCHAR( 18), 
      @dLottable04     DATETIME, 
      @dLottable05     DATETIME

   DECLARE 
      @cIsHazmat       NVARCHAR( 1), 
      @cHazmatClass    NVARCHAR( 30) 

   SET @cSuggestedLOC = ''
   SET @cPAZone = ''
   SET @cIsHazmat = '0'
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
                      AND Loc = 'QUARANTINE'
                      AND Putawayzone = 'QUARANTINE')
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
      -- Check for hazardous flag
      SELECT @cIsHazmat = ISNULL( SKU.HazardousFlag, ''), 
             @cHazmatClass = SIF.ExtendedField01
      FROM dbo.SKU WITH (NOLOCK)
      JOIN SKUInfo SIF WITH (NOLOCK) ON ( SKU.SKU = SIF.SKU AND SKU.StorerKey = SIF.StorerKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      IF @cIsHazmat = ''
         SET @cIsHazmat = '0'

      -- Find an empty loc 
      -- If sku is hazmat then look for empty loc with same hazmat class
      -- Else look for empty loc in location category OTHER
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @cFacility
      AND   ( ( @cIsHazmat = '0' AND LOC.LocationCategory = 'OTHER') 
           OR ( @cIsHazmat = '1' AND LOC.LocationCategory = @cHazmatClass))
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LogicalLocation, LOC.LOC 
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
      AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC 

      IF ISNULL( @cSuggestedLOC, '') = ''
         SET @cSuggestedLOC = ''
   END

   IF ISNULL( @cSuggestedLOC, '') <> ''
      -- Lock SuggestedLOC  
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
         ,@cLOC  
         ,@cID   
         ,@cSuggestedLOC  
         ,@cStorerKey  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
   Quit:
END

GO