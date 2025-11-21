SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA04                                      */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 30-Sep-2019  1.0  Ung      WMS-10642 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA04] (
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

   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cLottable02 NVARCHAR( 18)
   DECLARE @cStyle      NVARCHAR( 20)
   DECLARE @cPutawayZone  NVARCHAR( 10)

   SET @cSuggestedLOC = ''
   SET @cPutawayZone = ''

   -- Get UCC info
   SELECT 
      @cLottable01 = Lottable01, 
      @cLottable02 = Lottable02
   FROM LOTAttribute WITH (NOLOCK)
   WHERE LOT = @cLOT
   
   -- Find a friend (same SKU, L01, L02)
   SELECT TOP 1 
      @cSuggestedLOC = LOC.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   WHERE LOC.Facility = @cFacility
      AND LOC.LocationFlag = 'NONE'
      AND LLI.StorerKey = @cStorerKey 
      AND LLI.SKU = @cSKU
      AND LA.Lottable01 = @cLottable01
      AND LA.Lottable02 = @cLottable02
      AND ((LLI.QTY-LLI.QTYPicked > 0) 
       OR (LLI.PendingMoveIn > 0)) 
   ORDER BY LOC.LogicalLocation, LOC.LOC

   IF @cSuggestedLOC = ''
   BEGIN
      -- Get SKU info
      SELECT @cStyle = Style 
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Find a friend zone (same style, L01)
      SELECT TOP 1 
         @cPutawayZone = LOC.PutawayZone
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationFlag = 'NONE'
         AND LLI.StorerKey = @cStorerKey 
         AND SKU.Style = @cStyle
         AND LA.Lottable02 = @cLottable02
         AND ((LLI.QTY-LLI.QTYPicked > 0) 
          OR (LLI.PendingMoveIn > 0)) 
      ORDER BY LOC.LogicalLocation, LOC.LOC

      -- Find empty LOC in friend zone
      SELECT TOP 1 
         @cSuggestedLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.LocationFlag = 'NONE'
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC
   END
   
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
   ELSE
      SET @nErrNo = -1 -- No suggested LOC, and allow continue. 
END

GO