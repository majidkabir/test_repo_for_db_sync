SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP24                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 31-May-2019  1.0  James    WMS9137. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP24] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT,
           @cLogicalLocation     NVARCHAR( 10),
           @cPAZone1             NVARCHAR( 20),
           @cPAZone2             NVARCHAR( 20),
           @cPAZone3             NVARCHAR( 20),
           @cPAZone4             NVARCHAR( 20),
           @cPAZone5             NVARCHAR( 20)
   
   DECLARE @cPalletType       NVARCHAR(15)  
   DECLARE @cSKU              NVARCHAR(20)  
   DECLARE @cPickLoc          NVARCHAR(10)  
   DECLARE @cLocBay           NVARCHAR(10)  
   DECLARE @cLocAisle         NVARCHAR(10)  
   DECLARE @cPutawayZone      NVARCHAR(10)  
   DECLARE @nQty              INT
   DECLARE @nQtyLocationLimit INT

   SELECT TOP 1 @cSKU = LLI.SKU, 
                @nQty = ISNULL( SUM( LLI.Qty), 0)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.LOC = @cFromLOC
   AND   LLI.ID = @cID
   AND   LLI.Qty > 0
   AND   LOC.Facility = @cFacility
   GROUP BY LLI.SKU
   ORDER BY 1

   SELECT TOP 1 @cPickLoc = SL.LOC,
                @nQtyLocationLimit = SL.QtyLocationLimit,
                @cLocBay = LOC.LocBay,
                @cLocAisle = LOC.LocAisle
   FROM dbo.SKUxLOC SL WITH (NOLOCK)                        
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
   WHERE SL.StorerKey = @cStorerKey                        
   AND   SL.Sku = @cSKU                        
   AND   SL.LocationType IN ('PICK','CASE')   
   ORDER BY 1 

   SELECT @cPutawayZone = PutawayZone
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   -- SKU has pick loc
   IF ISNULL( @cPickLoc, '') <> ''
   BEGIN
      -- Find a friend in pick loc that can fit
      SELECT TOP 1 @cSuggLOC = LOC.LOC                        
      FROM dbo.SKUxLOC SL WITH (NOLOCK)                        
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @cStorerKey                        
      AND   SL.Sku = @cSKU                        
      AND   SL.LocationType IN ('PICK','CASE')  
      AND   LOC.Facility = @cFacility 
      GROUP BY Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM(SL.Qty - SL.QtyPicked), 0) > 0
      AND    ( ISNULL( SUM(SL.Qty - SL.QtyPicked), 0) + @nQty) <= @nQtyLocationLimit
      ORDER BY LOC.LogicalLocation, LOC.LOC   

      IF ISNULL( @cSuggLOC, '') = ''
         -- Find empty loc within same bay
         SELECT TOP 1 @cSuggLOC = LOC.LOC                        
         FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LOC.LocBay = @cLocBay
         AND   LOC.LocAisle = @cLocAisle
         AND   LOC.Facility = @cFacility
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
         AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
         ORDER BY Loc.LogicalLocation, LOC.LOC  
   END
   ELSE
   BEGIN
      -- Find a friend 
      SELECT TOP 1 @cSuggLOC = LOC.LOC                        
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)                        
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey                        
      AND   LLI.Sku = @cSKU     
      AND   LOC.Facility = @cFacility                   
      AND   SL.LocationType NOT IN ('PICK','CASE')   
      GROUP BY Loc.LogicalLocation, LOC.LOC
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) > 0
      ORDER BY LOC.LogicalLocation, LOC.LOC  

      IF ISNULL( @cSuggLOC, '') = ''
         -- Find empty loc
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LOC.PutawayZone = @cPutawayZone
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
         AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
         ORDER BY Loc.LogicalLocation, LOC.LOC  
   END


   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = 139501 -- No Suggest Loc
      GOTO Quit
   END
   
   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP24 -- For rollback or commit only our own transaction
         
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   
      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   
      COMMIT TRAN rdt_1819ExtPASP24 -- Only commit change made here
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP24 -- Only rollback change made here
   Fail:
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END


GO