SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtValidSP05                                */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-01-26 1.0  ChewKP     Created. WMS-3850                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1804ExtValidSP05] (  
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
   
    
--    DECLARE  @cUCCWithMultiSKU       NVARCHAR(1)
--           , @cShort                 NVARCHAR(10)
--           , @cChildID            NVARCHAR(20)

    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    
       
    IF @nStep = 6
    BEGIN

       IF EXISTS ( SELECT 1 FROM dbo.LotAttribute LA WITH (NOLOCK) 
                   INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON LLI.Lot = LA.Lot AND LLI.StorerKey = LA.StorerKey AND LLI.SKU = LA.SKU
                   WHERE LLI.StorerKey = @cStorerKey
                   AND LLI.Loc = @cFromLoc
                   AND LLI.ID = @cFromID
                   AND LLI.SKU = @cSKU
                   AND LLI.Qty > 0 
                   GROUP BY LA.Lottable01 
                   HAVING COUNT(DISTINCT LA.Lottable01) > 1  ) 
       BEGIN
         SET @nErrNo = 118951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiLot'
         GOTO QUIT
       END  
       
       IF EXISTS ( SELECT 1 FROM dbo.LotAttribute LA WITH (NOLOCK) 
                   INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON LLI.Lot = LA.Lot AND LLI.StorerKey = LA.StorerKey AND LLI.SKU = LA.SKU
                   WHERE LLI.StorerKey = @cStorerKey
                   AND LLI.Loc = @cFromLoc
                   AND LLI.ID = @cFromID
                   AND LLI.SKU = @cSKU
                   AND LLI.Qty > 0 
                   GROUP BY LA.Lottable01 
                   HAVING COUNT(DISTINCT LA.Lottable09) > 1  ) 
       BEGIN
         SET @nErrNo = 118952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiLot'
         GOTO QUIT
       END  
       
       
       
       
       
       
    END
    
    

   
END  
  
QUIT:  

 

GO