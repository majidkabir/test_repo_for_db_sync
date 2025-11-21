SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP31                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 14-AUG-2020  1.0  Chermaine   WMS-14664. Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP31] (
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
   DECLARE @cPALogicalLoc     NVARCHAR(15)   
   DECLARE @cSKU              NVARCHAR(20)  
   DECLARE @cPickLoc          NVARCHAR(10)  
   DECLARE @cLocBay           NVARCHAR(10)  
   DECLARE @cLocAisle         NVARCHAR(10)  
   DECLARE @cPutawayZone      NVARCHAR(10)  
   DECLARE @nQty              INT
   DECLARE @nQtyLocationLimit INT
   
   --1. Get TOP 1 SKU   
   SELECT TOP 1  @cSKU = LLI.SKU
   FROM LOTxLOCxID LLI WITH (NOLOCK)   
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
   WHERE LOC.Facility = @cFacility  
      AND LLI.ID = @cID 
      AND LLI.QTY -   
         (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', LLI.StorerKey) = '0' THEN LLI.QTYAllocated ELSE 0 END) -   
         (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', LLI.StorerKey) = '0' THEN LLI.QTYPicked ELSE 0 END) > 0
   ORDER BY LLI.SKU
   
   IF @cSKU <> ''
   BEGIN
   	--2. Get suggest pickFace loc by sku.putawayloc
      SELECT TOP 1  @cSuggLOC = LOC.LOC                                
      FROM LOC LOC WITH (NOLOCK)     
         JOIN SKU SKU WITH (NOLOCK) ON (SKU.PutawayLoc = LOC.loc)   
         LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Storerkey = @cStorerKey AND LotxLocxID.Loc = Loc.Loc)      
      WHERE LOC.LocationCategory = 'PICK'  
         AND   LOC.Facility = @cFacility    
         AND sku.sku = @cSKU
      GROUP BY LOC.LogicalLocation, LOC.LOC     
      HAVING SUM( ISNULL(LotxLocxID.Qty,0)) = 0   
         AND SUM( ISNULL(LotxLocxID.PendingMoveIn,0)) = 0  
      ORDER BY LOC.LogicalLocation, LOC.LOC 
   END
   
   --3. find friend with same putawayZone and nearest PALogicalLoc
   IF ISNULL( @cSuggLOC, '') = ''
   BEGIN
   	SELECT TOP 1 @cPALogicalLoc = LOC.PALogicalLoc, @cPutawayZone = SKU.PutawayZone                    
      FROM LOC LOC WITH (NOLOCK)          
      JOIN SKU SKU WITH (NOLOCK) ON (SKU.PutawayLoc = LOC.loc)   
      WHERE LOC.LocationCategory = 'PICK'  
      AND   LOC.Facility = @cFacility    
      AND sku.sku = @cSKU
      
      SELECT TOP 1  @cSuggLOC = LOC.LOC                                
      FROM LOC LOC WITH (NOLOCK)     
         LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Storerkey = @cStorerKey AND LotxLocxID.Loc = Loc.Loc)      
      WHERE LOC.LocationCategory = 'OTHER'  
         AND Loc.PutawayZone = @cPutawayZone
         AND   LOC.Facility = @cFacility 
      GROUP BY LOC.LogicalLocation, LOC.LOC ,LOC.PALogicalLoc    
      HAVING SUM( ISNULL(LotxLocxID.Qty,0)) = 0   
         AND SUM( ISNULL(LotxLocxID.PendingMoveIn,0)) = 0  
      ORDER BY ABS( CAST(LOC.PALogicalLoc AS INT) - CAST(@cPALogicalLoc AS INT))  
      
   END 
   
   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      --SET @nErrNo = 156901 -- NoSuggestLoc
      --GOTO Quit
      SET @cSuggLOC = 'OVERFLOW' 
   END
   
   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP31 -- For rollback or commit only our own transaction
         
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
   
      COMMIT TRAN rdt_1819ExtPASP31 -- Only commit change made here
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP31 -- Only rollback change made here
   Fail:
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END


GO