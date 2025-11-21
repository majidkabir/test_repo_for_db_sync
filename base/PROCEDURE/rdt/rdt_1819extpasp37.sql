SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_1819ExtPASP37                                   */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date        Rev  Author   Purposes                                   */      
/* 28-10-2021  1.0  Chermain WMS-18162. Created                         */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1819ExtPASP37] (      
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
         
   DECLARE @nTranCount       INT      
   DECLARE @cHostWHCode    NVARCHAR(10)      
   DECLARE @cPutawayZone   NVARCHAR(10)      
   DECLARE @cSKU           NVARCHAR( 20)      
         
   SET @cSuggLOC = ''      
         
   SELECT @cHostWHCode = HostWHCode FROM Loc WITH (NOLOCK) WHERE facility = @cFacility AND loc = @cFromLOC      
    
   SELECT TOP 1       
      @cSKU = LLI.Sku      
   FROM LOTxLOCxID LLI WITH (NOLOCK)       
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)      
   WHERE LOC.Facility = @cFacility      
   AND   LLI.LOC = @cFromLOC       
   AND   LLI.ID = @cID       
   AND   LLI.QTY > 0      
   ORDER BY 1     
         
   IF EXISTS (SELECT 1       
              FROM codelkup WITH (NOLOCK)       
              WHERE storerKey = @cStorerKey      
              AND listname = 'ADSTKSTS'      
              AND Code = @cHostWHCode      
              AND Long = 'B' )      
   BEGIN      
    --Look for latest Lottable05 with 1st SKU in LLI      
      SELECT TOP 1       
         @cSuggLOC = LOC.LOC      
      FROM LOTxLOCxID LLI WITH (NOLOCK)      
      JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)      
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
      WHERE LOC.Facility = @cFacility      
      AND   LOC.HOSTWHCODE = @cHostWHCode      
      AND   LLI.StorerKey = @cStorerKey      
      AND   LLI.SKU = @cSKU      
      AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))      
      AND LOC.Loc <> @cFromLOC    
      ORDER BY LA.Lottable05 DESC      
         
      IF @cSuggLOC = ''      
      BEGIN      
       ----empty Loc with the same Loc.HostWHCode      
         SELECT TOP 1 
            @cSuggLOC = LOC.Loc      
         FROM dbo.LOC LOC WITH (NOLOCK)      
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC )       
         WHERE LOC.Facility = @cFacility      
         AND   LOC.HOSTWHCODE = @cHostWHCode    
         AND LOC.Loc <> @cFromLOC    
         GROUP BY Loc.LogicalLocation, LOC.LOC      
         HAVING ISNULL( SUM( LLI.QTY + LLI.QTYPicked + LLI.QTYAllocated + LLI.PendingMoveIn +       
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0      
         ORDER BY LOC.LogicalLocation, LOC.LOC        
      END      
   END      
   ELSE IF EXISTS (SELECT 1       
            FROM codelkup WITH (NOLOCK)       
            WHERE storerKey = @cStorerKey      
            AND listname = 'ADSTKSTS'      
            AND Code = @cHostWHCode      
            AND Long = 'I' )      
   BEGIN      
    --HomeLOC      
      SELECT TOP 1          
            @cSuggLOC = SL.LOC        
      FROM dbo.SKUxLOC SL WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = SL.LOC AND LOC.Facility = @cFacility)       
      WHERE SL.StorerKey = @cStorerKey  
      AND SL.SKU = @cSKU        
      AND SL.LocationType = 'PICK'        
    
      IF @cSuggLOC = ''      
      BEGIN      
       SET @nErrNo = 177951      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLoc      
         GOTO Quit      
      END      
   END      
   ELSE IF EXISTS (SELECT 1       
            FROM codelkup WITH (NOLOCK)       
            WHERE storerKey = @cStorerKey      
            AND listname = 'ADSTKSTS'      
            AND Code = @cHostWHCode      
            AND Long = 'U' )      
   BEGIN      
    --HomeLOC      
      SELECT TOP 1          
            @cSuggLOC = LOC.LOC        
      FROM dbo.LOC LOC WITH (NOLOCK)       
      JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.StorerKey = @cStorerKey AND SL.LOC = LOC.LOC AND SL.SKU = @cSKU)        
      WHERE LOC.Facility = @cFacility        
      AND SL.LocationType = 'PICK'        
      
      IF @cSuggLOC = ''      
      BEGIN      
       --No HomeLoc Setup, Suggest location as the Sku PutawayZone      
       SELECT TOP 1          
            @cSuggLOC = Sku.PutawayZone        
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)            
         JOIN dbo.Sku SKU ON SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.Sku    
         WHERE LLI.StorerKey = @cStorerKey      
         AND LLI.ID = @cID         
      END      
   END      
   ELSE      
   BEGIN      
    SET @nErrNo = 177952      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- HostWHCodeErr      
      GOTO Quit      
   END      
      
   IF @cSuggLOC <> ''      
      AND @cSuggLOC <> (SELECT TOP 1 Sku.PutawayZone            
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)                
                        JOIN dbo.Sku SKU ON SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.Sku        
                        WHERE LLI.StorerKey = @cStorerKey          
                        AND LLI.ID = @cID)  
   BEGIN      
    -- Handling transaction      
      SET @nTranCount = @@TRANCOUNT      
      BEGIN TRAN  -- Begin our own transaction      
      SAVE TRAN rdt_1819ExtPASP37 -- For rollback or commit only our own transaction      
                     
      SET @nPABookingKey = 0      
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
      
      COMMIT TRAN rdt_1819ExtPASP37 -- Only commit change made here      
   END      
         
   GOTO Quit      
      
RollBackTran:      
   ROLLBACK TRAN rdt_1819ExtPASP37 -- Only rollback change made here      
Fail:      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN      
END

GO