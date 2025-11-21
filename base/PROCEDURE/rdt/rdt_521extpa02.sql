SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA02                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 22-Nov-2017  1.0  Ung      WMS-3475 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA02] (
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

   DECLARE @nRowCount INT
   DECLARE @cSKUZone  NVARCHAR( 10)
   DECLARE @cFriendLogicalLOC NVARCHAR( 18)
   DECLARE @cLocationCategory NVARCHAR( 10)

   SET @cSuggestedLOC = ''
   SET @cSKUZone = ''

   -- Get SKU info
   SELECT @cSKUZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
   -- Get zone info (PutawayZone.ZoneCateogory not yet available on Exceed setup, workaround using LOC.LocationCategory)
   SELECT TOP 1 
      @cLocationCategory = LocationCategory
   FROM LOC WITH (NOLOCK) 
   WHERE Facility = @cFacility
      AND PutawayZone = @cSKUZone
   ORDER BY LOC
   
   -- Find a friend
   SELECT TOP 1 
      @cFriendLogicalLOC = LOC.LogicalLocation
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LOC.PutawayZone = @cSKUZone
      AND LLI.StorerKey = @cStorerKey 
      AND LLI.SKU = @cSKU
      AND LLI.QTY > 0
   ORDER BY LOT DESC

   SET @nRowCount = @@ROWCOUNT

   -- Pick face
   IF @cLocationCategory = 'SHELVING'
   BEGIN
      -- No friend, just find a empty loc
      IF @nRowCount = 0
         SELECT TOP 1 
            @cSuggestedLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cSKUZone
         GROUP BY LOC.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM( LLI.QTY), 0) = 0
            AND ISNULL( SUM( LLI.PendingMoveIn), 0) = 0
         ORDER BY LOC.LogicalLocation
   
      -- Find empty LOC closest to friend
      ELSE
         SELECT TOP 1 
            @cSuggestedLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cSKUZone
         GROUP BY LOC.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM( LLI.QTY), 0) = 0
            AND ISNULL( SUM( LLI.PendingMoveIn), 0) = 0
         ORDER BY 
             ABS( CAST( LOC.LogicalLocation AS INT) - CAST( @cFriendLogicalLOC AS INT))
            ,LOC.LogicalLocation DESC
   
      -- Lock SuggestedLOC  
      IF @cSuggestedLOC <> ''
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
            ,@cLOC  
            ,@cID   
            ,@cSuggestedLOC  
            ,@cStorerKey  
            ,@nErrNo  OUTPUT  
            ,@cErrMsg OUTPUT  
            ,@cSKU        = @cSKU  
            ,@nPutawayQTY = @nQTY     
            ,@cUCCNo      = @cUCC  
            ,@cFromLOT    = @cLOT  
            ,@nPABookingKey = @nPABookingKey OUTPUT
   END
   
   
   -- Carton location (1 location 2 cartons. 1 UCC = 1 carton)
   ELSE IF @cLocationCategory = 'CARTONFLOW'
   BEGIN
      -- No friend, just find a empty loc
      IF @nRowCount = 0
         SELECT TOP 1   
            @cSuggestedLOC = LOC.LOC
         FROM dbo.LOC with (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0))
            LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN ('1', '3'))
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cSKUZone
         GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet
         HAVING ISNULL( COUNT( DISTINCT 
                CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO 
                     WHEN LLI.ID    IS NOT NULL THEN LLI.ID   
                     ELSE NULL 
                END), 0) + 1 <= LOC.MaxPallet -- LOC ID Cnt + UCC (1)  
         ORDER BY LOC.LogicalLocation

      -- Find empty LOC closest to friend
      ELSE
         SELECT TOP 1   
            @cSuggestedLOC = LOC.LOC
         FROM dbo.LOC with (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0))
            LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN ('1', '3'))
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cSKUZone
         GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet
         HAVING ISNULL( COUNT( DISTINCT 
                CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO 
                     WHEN LLI.ID    IS NOT NULL THEN LLI.ID   
                     ELSE NULL 
                END), 0) + 1 <= LOC.MaxPallet -- LOC ID Cnt + UCC (1)  
         ORDER BY 
             ABS( CAST( LOC.LogicalLocation AS INT) - CAST( @cFriendLogicalLOC AS INT))
            ,LOC.LogicalLocation DESC

      -- Lock suggested LOC by UCC  
      IF @cSuggestedLOC <> ''
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'   
            ,@cLOC        
            ,@cID    
            ,@cSuggestedLOC   
            ,@cStorerKey  
            ,@nErrNo      OUTPUT  
            ,@cErrMsg     OUTPUT  
            ,@cSKU        = @cSKU  
            ,@nPutawayQTY = @nQTY     
            ,@cUCCNo      = @cUCC  
            ,@cFromLOT    = @cLOT  
            ,@nPABookingKey = @nPABookingKey OUTPUT
   END

Quit:

END

GO