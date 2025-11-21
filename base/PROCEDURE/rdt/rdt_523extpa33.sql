SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA33                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2020-03-25  1.0  James    WMS-12835. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA33] (
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

   -- Check if SKU has inventory
   IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.SKU = @cSKU
               AND   ( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                     (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
               AND   LOC.Facility = @cFacility)
   BEGIN
      -- Get the Pick Loc for the SKU with inventory 1st
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = LLI.LOC
      WHERE LLI.SKU = @cSKU
      AND   LLI.StorerKey = @cStorerKey
      AND   ( LLI.Qty - LLI.QtyPicked) > 0
      AND   LOC.LocationType = 'PICK' 
      AND   LOC.Facility = @cFacility
      ORDER BY LOC.LOC
         
      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         -- Get Any Pick Loc for the SKU 
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC
         FROM dbo.SKUxLOC SL WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = SL.LOC
         WHERE SL.SKU = @cSKU
         AND   SL.StorerKey = @cStorerKey
         AND   LOC.LocationType = 'PICK' 
         AND   LOC.Facility = @cFacility
         ORDER BY LOC.LOC
      END
   END


   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA33 -- For rollback or commit only our own transaction

   IF @cSuggestedLOC <> ''
   BEGIN
      SET @nErrNo = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      COMMIT TRAN rdt_523ExtPA33 -- Only commit change made here
   END
   ELSE
      SET @nErrNo = -1  -- Main script will return No Suggested Loc error

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_523ExtPA33 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
   Fail:
END

GO