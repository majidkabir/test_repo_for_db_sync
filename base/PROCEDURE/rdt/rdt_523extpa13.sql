SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA13                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 04-05-2018  1.0  James    WMS-4888 Created (base on rdt_523ExtPA04)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA13] (
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

   DECLARE @cLottable02 NVARCHAR( 18)

   SET @cSuggestedLOC = ''

   -- Get Lottable
   SELECT @cLottable02 = Lottable02  
   FROM dbo.LotAttribute WITH (NOLOCK) 
   WHERE LOT = @cLOT

   -- Find a friend (same SKU, L02)
   SELECT TOP 1 
      @cSuggestedLOC = LOC.LOC 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LA.Lottable02 = @cLottable02
      AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0)
   GROUP BY LOC.LogicalLocation, LOC.LOC 
   ORDER BY SUM( LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn)

   -- Find empty LOC
   IF @cSuggestedLOC = ''
      SELECT TOP 1 
         @cSuggestedLOC = LOC.LOC 
      FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationCategory = 'OTHER'
      GROUP BY LOC.LogicalLocation, LOC.LOC 
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0 
      ORDER BY LOC.LogicalLocation, LOC.LOC 

QUIT:

END

GO