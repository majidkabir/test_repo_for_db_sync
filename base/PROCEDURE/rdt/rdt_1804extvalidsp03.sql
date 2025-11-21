SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtValidSP03                                */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-05-02 1.0  ChewKP     WMS-1796 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1804ExtValidSP03] (  
     @nMobile         INT, 
     @nFunc           INT, 
     @cLangCode       NVARCHAR(3), 
     @nStep           INT, 
     @cStorerKey      NVARCHAR(15),
     @cFacility       NVARCHAR(5), 
     @cFromLOC        NVARCHAR(10),
     @cFromID         NVARCHAR(18),
     @cSKU            NVARCHAR(20),
     @nQTY            INT, 
     @cUCC            NVARCHAR(20),
     @cToID           NVARCHAR(18),
     @cToLOC          NVARCHAR(10),
     @nErrNo          INT OUTPUT, 
     @cErrMsg         NVARCHAR(20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 1804  
BEGIN  
   
	 DECLARE @cLot  					NVARCHAR(10) 
	        ,@dLottable04 		DATETIME
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''

       
    IF @nStep = '6'
    BEGIN
			 
			 IF @cSKU <> '' AND @nQty <> 0 
			 BEGIN
				 SELECT @cLot = V_LOT
				 FROM rdt.rdtMobRec WITH (NOLOCK) 
				 WHERE Mobile = @nMobile 
				 AND Func = @nFunc 
				 
				 SELECT @dLottable04 = Lottable04
				 FROM dbo.LotAttribute WITH (NOLOCK) 
				 WHERE StorerKey = @cStorerKey
				 AND SKU = @cSKU
				 AND LOT = @cLot
				 
				 IF EXISTS ( SELECT 1
				 						 FROM dbo.UCC UCC WITH (NOLOCK)
				 						 INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.StorerKey = UCC.StorerKey AND LA.SKU = UCC.SKU AND LA.Lot = UCC.Lot 
				 						 WHERE UCC.StorerKey = @cStorerKey
				 						 AND UCC.UCCNo = @cUCC
				 						 AND UCC.SKU = @cSKU
				 						 AND LA.Lottable04 <> @dLottable04  )
				 BEGIN
	            SET @nErrNo = 107501
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKULot04Diff'
	            GOTO QUIT
	       END  
     	 END
       
       
    END
    
    

   
END  
  
QUIT:  

 

GO