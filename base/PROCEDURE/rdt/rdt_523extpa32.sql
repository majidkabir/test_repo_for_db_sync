SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA32                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2020-03-25  1.0  James    WMS-12541. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA32] (
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

   
   -- Find a friend in pick loc that can fit (LIT confirm no need check max)
   SELECT TOP 1 @cSuggToLOC = LOC.LOC                        
   FROM dbo.SKUxLOC SL WITH (NOLOCK)                        
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
   WHERE SL.StorerKey = @cStorerKey                        
   AND   SL.Sku = @cSKU                        
   AND   SL.LocationType = 'PICK'  
   AND   LOC.Facility = @cFacility 
   --GROUP BY Loc.LogicalLocation, LOC.LOC
   --HAVING ISNULL( SUM(SL.Qty - SL.QtyPicked), 0) > 0
   --AND    ( ISNULL( SUM(SL.Qty - SL.QtyPicked), 0) + @nQty) <= @nQtyLocationLimit
   ORDER BY LOC.LogicalLocation, LOC.LOC  

   -- Find a friend which not assign pick loc (LIT confirm user will do manual assign pick loc)
   IF ISNULL( @cSuggToLOC, '') = ''
      SELECT TOP 1 @cSuggToLOC = LOC.LOC                        
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey                        
      AND   LLI.SKU = @cSKU
      AND   LOC.LocationType = 'PICK'  
      AND   LOC.Facility = @cFacility 
      AND   LOC.[Status] = 'OK'
      GROUP BY LOC.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
      ORDER BY LOC.LogicalLocation, LOC.LOC  

   -- Find an empty loc which exclude pick loc assigned to other sku
   IF ISNULL( @cSuggToLOC, '') = ''
      SELECT TOP 1 @cSuggToLOC = LOC.LOC                        
      FROM dbo.LOC LOC WITH (NOLOCK)  
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.LOC = LLI.LOC)
      LEFT OUTER JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( LOC.LOC = SL.LOC)
      WHERE LOC.LocationType = 'PICK'  
      AND   LOC.Facility = @cFacility 
      AND   LOC.[Status] = 'OK'
      GROUP BY Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn + 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC

   IF ISNULL( @cSuggToLOC, '') = ''
   BEGIN
      SET @nErrNo = -1  
      GOTO Fail
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA32 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA32 -- Only commit change made here
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_523ExtPA32 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
   Fail:
END

GO