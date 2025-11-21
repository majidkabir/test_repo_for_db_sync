SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA09                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-08-19   1.0  James    WMS-17695. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ExtPA09] (
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

   DECLARE @cPutAwayZone   NVARCHAR( 10)

   -- Find friend
   SELECT TOP 1   
      @cSuggestedLOC = LOC.LOC  
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
   WHERE LOC.Facility = @cFacility  
   AND   LOC.LOC <> @cLOC  
   AND   LOC.LocLevel = '1'
   AND   LOC.HOSTWHCODE= 'Normal'  
   AND   LLI.StorerKey = @cStorerKey  
   AND   LLI.SKU = @cSKU  
   GROUP BY LOC.LOC  
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0  
   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) ASC, LOC.Loc  
   
   IF ISNULL( @cSuggestedLOC, '') = ''
   BEGIN
      -- Find empty LOC 
      SELECT @cPutAwayZone = UDF01  
      FROM dbo.CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = 'PAZONE'  
      AND   Storerkey = @cStorerKey  
      AND   code2 = @cFacility  
       
      SELECT TOP 1     
         @cSuggestedLOC = LOC.LOC    
      FROM LOC LOC WITH (NOLOCK)         
      LEFT OUTER JOIN LotxLocxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LLI.Loc = Loc.Loc AND LLI.StorerKey = @cStorerKey )    
      WHERE LOC.Facility = @cFacility   
      AND   LOC.LOC <> @cLOC   
      AND   LOC.LocLevel = '1'
      AND   LOC.HOSTWHCODE= 'Normal'      
      AND   Loc.PutawayZone = @cPutAwayZone  
      GROUP BY LOC.LOC    
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0   
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0  
      ORDER BY LOC.Loc ASC   
   END

   IF ISNULL( @cSuggestedLOC, '') <> ''
      -- Lock SuggestedLOC  
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
         
   Quit:
END


GO