SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA21                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 14-05-2019  1.0  Ung      WMS-8992 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA21] (
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
   DECLARE @cBUSR8         NVARCHAR( 30)
   DECLARE @cStyle         NVARCHAR( 20)
   DECLARE @cSuggToLOC     NVARCHAR( 10)
   DECLARE @cSameStyleLOC  NVARCHAR( 10)
   DECLARE @cSameStyleLogicalLOC NVARCHAR( 18)
   
   DECLARE @tPickZone TABLE
   (
      PickZone NVARCHAR(10) NOT NULL PRIMARY KEY CLUSTERED
   )
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
   SET @cSameStyleLOC = ''
   SET @cSameStyleLogicalLOC = ''
   
   -- Get SKU info
   SELECT 
      @cBUSR8 = BUSR8, 
      @cStyle = Style 
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU
   
   /*
      BUSR8
         10 = APPAREL
         20 = FOOTWEAR
         30 = EQUIPMENT

      PickZone
      APPAREL     FOOTWEAR    EQUIPMENT
         1P-AP    1P-FW       1P-AC
         2L-AP    2L-FW       2L-AC
         2P-AP    2P-FW       2P-AC
         3L-AP    3L-FW       3L-AC
   */

   -- Get pick face
   SELECT TOP 1
      @cSuggToLOC = LOC.LOC
   FROM SKUxLOC SL WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND SL.StorerKey = @cStorerKey
      AND SL.SKU = @cSKU
      AND SL.LocationType = 'PICK'
   GROUP BY LOC.LogicalLocation, LOC.LOC
   ORDER BY 
      LOC.LogicalLocation,
      LOC.LOC

   -- Find an empty LOC after friend (same Style) LOC
   IF @cSuggToLOC = ''
   BEGIN
      -- Populate pick zone
      IF @cBUSR8 = '10' INSERT INTO @tPickZone (PickZone) VALUES ('1P-AP'), ('2L-AP'), ('2P-AP'), ('3L-AP') ELSE 
      IF @cBUSR8 = '20' INSERT INTO @tPickZone (PickZone) VALUES ('1P-FW'), ('2L-FW'), ('2P-FW'), ('3L-FW') ELSE 
      IF @cBUSR8 = '30' INSERT INTO @tPickZone (PickZone) VALUES ('1P-AC'), ('2L-AC'), ('2P-AC'), ('3L-AC') 
            
      -- Find a friend (same Style)
      SELECT TOP 1
         @cSameStyleLOC = LOC.LOC, 
         @cSameStyleLogicalLOC = LogicalLocation
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND SKU.SKU = LLI.SKU)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.Style = @cStyle
         AND LOC.Facility = @cFacility
         AND ((LLI.QTY - LLI.QTYPicked) > 0 OR LLI.PendingMoveIn > 0)
      GROUP BY LOC.LogicalLocation, LOC.LOC
      ORDER BY 
         LOC.LogicalLocation,
         LOC.LOC
      
      -- Find empty location, after same style LOC
      IF @cSameStyleLOC <> ''
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND (LOC.LogicalLocation > @cSameStyleLogicalLOC 
             OR (LOC.LogicalLocation = @cSameStyleLogicalLOC AND LOC.LOC > @cSameStyleLOC))
         GROUP BY LOC.LogicalLocation, LOC.LOC
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY 
            LOC.LogicalLocation,
            LOC.LOC
   END

   -- Find empty location in default zone
   IF @cSuggToLOC = ''
      SELECT TOP 1
         @cSuggToLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      WHERE LOC.Facility = @cFacility
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY 
         LOC.LogicalLocation,
         LOC.LOC

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA21 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_523ExtPA21 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA21 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO