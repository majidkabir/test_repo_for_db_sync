SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
       
/************************************************************************/        
/* Store procedure: rdt_521ExtPA11                                      */        
/*                                                                      */        
/* Purpose: Get suggested loc                                           */        
/*                                                                      */        
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */        
/*                                                                      */        
/* Date         Rev  Author   Purposes                                  */        
/* 2021-10-28   1.0  Chermain WMS-18163. Created                        */     
/* 2022-03-04   1.1  yeekung  WMS-19073  New PA stragey (yeekung01)     */    
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_521ExtPA11] (        
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
        
   DECLARE @cHostWHCode    NVARCHAR(10)        
   DECLARE @cPutawayZone   NVARCHAR(10)        
           
   SET @cSuggestedLOC = ''        
           
   SELECT @cHostWHCode = HostWHCode FROM Loc WITH (NOLOCK) WHERE facility = @cFacility AND loc = @cLOC        
   SELECT @cPutawayZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSKU        
           
   IF EXISTS (SELECT 1         
            FROM codelkup WITH (NOLOCK)         
            WHERE storerKey = @cStorerKey        
            AND listname = 'ADSTKSTS'        
            AND Code = @cHostWHCode        
            AND Long = 'U' )        
   BEGIN        
    --HomeLOC        
      SELECT TOP 1              
            @cSuggestedLOC = SL.LOC            
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = SL.LOC AND LOC.Facility = @cFacility)    
      JOIN dbo.LOTXLOCXID LLI (NOLOCK) ON (LLI.LOC=LOC.LOC AND SL.SKU =LLI.SKU AND LLI.storerkey=SL.storerkey)    
      WHERE SL.StorerKey = @cStorerKey      
      AND SL.SKU = @cSKU            
      AND LOC.LocationType IN('PICK','DYNPPICK')    
      AND LLI.QTY>0    
      order by LLI.qty DESC  
    
      IF @cSuggestedLOC = ''      
      BEGIN    
         --HomeLOC        
         SELECT TOP 1              
            @cSuggestedLOC = PD.Loc            
         FROM dbo.pickdetail PD WITH (NOLOCK)      
         JOIN dbo.orderdetail OD WITH (NOLOCK) ON (PD.orderkey=OD.orderkey and pd.OrderLineNumber=OD.OrderLineNumber and pd.Storerkey=OD.StorerKey)    
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC AND LOC.Facility = @cFacility)    
         WHERE PD.StorerKey = @cStorerKey      
         AND PD.SKU = @cSKU            
         AND LOC.LocationType IN('PICK','DYNPPICK')    
         AND PD.Status ='9'    
         order by pd.EditDate desc;    
        
         IF @cSuggestedLOC = ''        
         BEGIN        
            --No HomeLoc Setup, Suggest location as the Sku PutawayZone        
            SET @cSuggestedLOC = @cPutawayZone          
         END      
      END    
   END        
   ELSE        
  BEGIN        
      SET @nErrNo = 178001        
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- HostWHCodeErr        
      GOTO Quit        
   END        
           
        
   IF ISNULL( @cSuggestedLOC, '') <> '' AND ISNULL( @cSuggestedLOC, '') <> @cPutawayZone      
   --IF ISNULL( @cSuggestedLOC, '') <> ''      
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