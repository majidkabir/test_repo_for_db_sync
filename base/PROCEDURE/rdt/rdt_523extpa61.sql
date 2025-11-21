SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA61                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-07-04  1.0  James       WMS-22929 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA61] (
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
  
   DECLARE @nTranCount           INT,  
           @cSuggToLOC           NVARCHAR( 10) = '',
           @cLottable08          NVARCHAR( 30),  
           @cLogicalLocation     NVARCHAR( 10),  
           @cPAZone1             NVARCHAR( 20),  
           @cPAZone2             NVARCHAR( 20),  
           @cPAZone3             NVARCHAR( 20),  
           @cPAZone4             NVARCHAR( 20),  
           @cPAZone5             NVARCHAR( 20)  
     
   DECLARE @cPalletType       NVARCHAR( 15)    
  
   -- 1 pallet 1 sku, 1 lottable08  
   SELECT TOP 1 @cLottable08 = LA.Lottable08
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
   WHERE LLI.StorerKey = @cStorerKey  
   AND   LLI.Loc = @cLOC  
   AND   LLI.SKU = @cSKU  
   AND   LLI.Qty > 0  
   ORDER BY 1  
  
   -- Check lottable08 exists  
   IF ISNULL( @cLottable08, '') = ''  
   BEGIN  
      SET @nErrNo = 203451  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Lottable08  
      GOTO Quit  
   END  
  
   CREATE TABLE #PAZone (  
   RowRef  INT IDENTITY(1,1) NOT NULL,  
   PAZone  NVARCHAR(10)  NULL)  
  
   INSERT INTO #PAZone ( PAZone)  
   SELECT DISTINCT Code  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'UARTNZONE'   
   AND   Storerkey = @cStorerKey  
  
   -- Check blank putaway strategy  
   IF NOT EXISTS ( SELECT 1 FROM #PAZone)  
   BEGIN  
      SET @nErrNo = 203452  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PA Zone  
      GOTO Quit  
   END  
  
   -- Find a friend, look for same Lot08 in putawayzone defined in codelkup  
   SELECT TOP 1 @cSuggToLOC = LOC.LOC  
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)  
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot  
   WHERE LLI.StorerKey = @cStorerKey  
   AND   LLI.LOC <> @cLOC  
   AND   LLI.SKU = @cSKU  
   AND   LA.Lottable08 = @cLottable08  
   AND   LOC.Facility = @cFacility  
   GROUP BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC  
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn), 0) > 0  
   ORDER BY PAZONE.RowRef, Loc.LogicalLocation, LOC.LOC  
  
   -- Check suggest loc  
   IF @cSuggToLOC = ''  
   BEGIN  
      -- Find empty loc  
      SELECT TOP 1 @cSuggToLOC = ISNULL( SKU.PutawayLoc, 'UNKNOW')  
      FROM dbo.SKU SKU WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON SKU.PUTAWAYLOC = LOC.LOC  
      JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)  
      WHERE SKU.SKU = @cSKU  
      AND   SKU.STORERKEY = @cStorerKey  
      AND   LOC.FACILITY = @cFacility  
   
      IF @cSuggToLOC = ''  
      BEGIN  
         SET @nErrNo = 203453 -- No Suggest Loc  
         GOTO Quit  
      END  
  
   END  
  
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA61 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA61 -- Only commit change made here
   END
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_523ExtPA61 -- Only rollback change made here  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END  

GO