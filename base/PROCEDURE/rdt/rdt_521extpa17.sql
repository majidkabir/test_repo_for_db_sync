SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA17                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 01-Dec-2023  1.0  Ung      WMS-24306 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtPA17] (
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
   DECLARE @cSKUABC     NVARCHAR( 5)
   DECLARE @cSKUGroup   NVARCHAR( 10)

   SET @cSuggestedLOC = ''

   -- Get UCC info
   SELECT @cLottable01 = Lottable01
   FROM LOTAttribute WITH (NOLOCK)
   WHERE LOT = @cLOT

   -- Find a friend (same SKU, L01)
   SELECT TOP 1
      @cSuggestedLOC = LOC.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   WHERE LOC.Facility = @cFacility
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LA.Lottable01 = @cLottable01
      AND LOC.LocationType = 'PICK'
      AND ((LLI.QTY - LLI.QTYPicked > 0)
       OR (LLI.PendingMoveIn > 0))
   ORDER BY LOC.Floor, LOC.LogicalLocation, LOC.LOC

   IF @cSuggestedLOC = ''
   BEGIN
      -- Get SKU info
      SELECT 
         @cSKUABC = ISNULL( ABC, ''), 
         @cSKUGroup = SKUGroup
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Find an empty LOC in zones (of that SKUGroup, setup in CodeLKUP)
      SELECT TOP 1
         @cSuggestedLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         JOIN dbo.CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'PUMAPA' AND CL.StorerKey = @cStorerKey AND CL.Code = LOC.PutawayZone AND CL.UDF01 = @cSKUGroup)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.ABC = @cSKUABC
         AND LOC.LocationType = 'PICK'
      GROUP BY LOC.LOCLevel, CL.Short, LOC.LogicalLocation, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.LOCLevel, CL.Short, LOC.LogicalLocation, LOC.LOC
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