SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/************************************************************************/      
/* Store procedure: rdt_523ExtPA45                                      */      
/*                                                                      */      
/* Purpose: Use RDT config to get suggested loc else return blank loc   */      
/*                                                                      */      
/* Called from: rdt_PutawayBySKU_GetSuggestLOC                          */      
/*                                                                      */      
/* Date         Rev  Author      Purposes                               */      
/* 2022-03-04  1.0  yeekung      WMS-19067. Created                     */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_523ExtPA45] (      
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
   @cSuggestedLOC    NVARCHAR( 10) = ''   OUTPUT,      
   @nPABookingKey    INT                  OUTPUT,      
   @nErrNo           INT                  OUTPUT,      
   @cErrMsg          NVARCHAR( 20)        OUTPUT      
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
         
   DECLARE @cHostWHCode    NVARCHAR(10)      
   DECLARE @cPutawayZone   NVARCHAR(10)     
   DECLARE @cLottable02    NVARCHAR(20)  
  
    SELECT @cLottable02=v_lottable02   
    FROM RDT.RDTMOBREC (NOLOCK)   
    WHERE MOBILE=@nMobile  
     
   SELECT @cHostWHCode = HostWHCode FROM Loc WITH (NOLOCK) WHERE facility = @cFacility AND loc = @cLOC      
   SELECT @cPutawayZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSKU      
    
   SELECT TOP 1         
      @cSuggestedLOC = LOC.LOC        
   FROM LOTxLOCxID LLI WITH (NOLOCK)        
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)        
   JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)        
   WHERE LOC.Facility = @cFacility              
   AND   LLI.StorerKey = @cStorerKey        
   AND   LLI.SKU = @cSKU      
   AND  LA.LOTTABLE02= @cLottable02  
   AND ( Qty - QtyPicked > 0)      
   AND LOC.Loc <> @cLOC      
   ORDER BY LOC.logicallocation,loc.loc,LA.Lottable02        
    
   IF @cSuggestedLOC = ''      
   BEGIN      
      SET @cSuggestedLOC = ''  
   END  
           
         
   /*-------------------------------------------------------------------------------      
                                 Book suggested location      
   -------------------------------------------------------------------------------*/      
   IF ISNULL( @cSuggestedLOC, '') <> '' AND ISNULL( @cSuggestedLOC, '') <> @cPutawayZone    
   --IF ISNULL( @cSuggestedLOC, '') <> ''      
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
         GOTO Quit      
   END      
         
   Quit:      
      
END  

GO