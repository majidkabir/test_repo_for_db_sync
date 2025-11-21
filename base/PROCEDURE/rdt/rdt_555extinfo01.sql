SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdt_555ExtInfo01                                          */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Purpose: Display SKU pack configuration                                    */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 2020-04-02   YeeKung   1.0   WMS-12740 Created                             */    
/******************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_555ExtInfo01]    
   @nMobile       INT,                 
   @nFunc         INT,                 
   @cLangCode     NVARCHAR( 3),        
   @nStep         INT,                              
   @nInputKey     INT,                 
   @cFacility     NVARCHAR( 5),         
   @cStorerKey    NVARCHAR( 15),       
   @cLOC          NVARCHAR( 10),       
   @cID           NVARCHAR( 18),       
   @cSKU          NVARCHAR( 20),       
   @cLottable01   NVARCHAR( 18),       
   @cLottable02   NVARCHAR( 18),       
   @cLottable03   NVARCHAR( 18),       
   @dLottable04   DATETIME,            
   @dLottable05   DATETIME,            
   @cLottable06   NVARCHAR( 30),       
   @cLottable07   NVARCHAR( 30),       
   @cLottable08   NVARCHAR( 30),       
   @cLottable09   NVARCHAR( 30),       
   @cLottable10   NVARCHAR( 30),       
   @cLottable11   NVARCHAR( 30),       
   @cLottable12   NVARCHAR( 30),       
   @dLottable13   DATETIME,            
   @dLottable14   DATETIME,            
   @dLottable15   DATETIME,            
   @nQTY          INT,   
   @cInquiry_LOC  NVARCHAR( 10),  
   @cInquiry_ID   NVARCHAR( 18),  
   @cInquiry_SKU  NVARCHAR( 20),            
   @cExtendedInfo NVARCHAR(20)  OUTPUT,     
   @nErrNo        INT           OUTPUT,     
   @cErrMsg       NVARCHAR( 20) OUTPUT     
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
    
   DECLARE @cSUSR3            NVARCHAR( 20),  
           @cPickQty          INT,  
           @cTtlPickQty       INT,  
           @cExtendedInfo2    NVARCHAR(20) ='',  
           @nTotalBlncQty     INT  
    
    
   IF @nStep = 3-- SKU    
   BEGIN    
      IF @nInputKey = 1 -- Enter    
      BEGIN    
         SELECT @cSUSR3 = SUSR3    
         FROM dbo.SKU WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND   SKU = @cSKU    
  
         IF (ISNULL(@cInquiry_LOC,'') <>'')  
         BEGIN  
              
            SELECT @cTtlPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC and LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND PD.LOC = @cInquiry_LOC    
               AND PD.SKU = @cSKU   
               AND LLI.qtyallocated<>0  
               AND LOC.Facility=@cFacility  
  
            SELECT @cPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC and LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND LLI.LOC = @cInquiry_LOC    
               AND PD.SKU = @cSKU   
               AND LLI.qtyallocated<>0   
               AND PD.status in ('3')  
               AND LOC.Facility=@cFacility  
  
            SELECT @nTotalBlncQty =(SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)))+(SUM(LLI.QTYAllocated)-ISNULL(@cPickQty,'0'))  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
            WHERE LOC.Facility = @cFacility      
               --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)      
               AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)   
               AND LLI.LOC=@cInquiry_LOC     
               AND LLI.SKU = @cSKU          
      
         END  
  
         ELSE IF (ISNULL(@cInquiry_SKU,'') <>'')  
         BEGIN  
            SELECT @cTtlPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC AND LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND PD.SKU = @cInquiry_SKU  
               AND LLI.qtyallocated<>0   
               AND PD.LOC =@cLOC  
               AND LOC.Facility=@cFacility    
  
            SELECT @cPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC AND LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND PD.SKU = @cInquiry_SKU   
               AND LLI.LOC =@cLOC    
               AND LLI.qtyallocated<>0    
               AND PD.status in ('3')  
               AND LOC.Facility=@cFacility  
                 
            SELECT @nTotalBlncQty =SUM(( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)))+(SUM(LLI.QTYAllocated)-ISNULL(@cPickQty,'0'))  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
            WHERE LOC.Facility = @cFacility      
               --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)      
               AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)   
               AND LLI.LOC=@cLOC     
               AND LLI.SKU = @cInquiry_SKU      
      
         END  
  
        ELSE IF (ISNULL(@cInquiry_ID,'') <>'')  
        BEGIN  
            SELECT @cTtlPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC and LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND PD.ID = @cInquiry_ID    
               AND LLI.qtyallocated<>0   
               AND LOC.Facility=@cFacility  
  
            SELECT @cPickQty = SUM(PD.QTY)    
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND LLI.LOC=PD.LOC and LLI.lot=pd.lot)      
            WHERE PD.storerkey = @cStorerKey  
               AND PD.SKU=@cSKU  
               AND LLI.LOC=@cLOC  
               AND LLI.qtyallocated<>0    
               AND PD.status in ('3')  
               AND LOC.Facility=@cFacility  
  
            SELECT @nTotalBlncQty =SUM(( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)))+(SUM(LLI.QTYAllocated)-ISNULL(@cPickQty,'0'))  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
            WHERE LOC.Facility = @cFacility      
               --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)      
               AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)   
               AND LLI.LOC=@cLOC     
               AND LLI.SKU = @cSKU      
       
         END  
  
         SET @cExtendedInfo2 =  CAST( (ISNULL(@cPickQty,'0')) AS NVARCHAR( 5)) +'/'+CAST(ISNULL( @nTotalBlncQty,'0') AS NVARCHAR( 5))  
  
            
    
         SET @cExtendedInfo = @cSUSR3+' '+@cExtendedInfo2  
      END    
   END    
    
END    
GOTO Quit    
    
Quit:         

GO