SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_521ExtValid03                                   */  
/* Purpose: Validate no mix sku/lot ucc                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-08-19 1.0  James      WMS-17702. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_521ExtValid03] (  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,        
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 20), 
   @cSuggestedLOC   NVARCHAR( 10), 
   @cToLOC          NVARCHAR( 10), 
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE  @cFromLOC      NVARCHAR( 10), 
            @cFacility     NVARCHAR( 5)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   SELECT @cFacility = Facility 
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)  
                         WHERE StorerKey = @cStorerKey  
                         AND   UCCNo = @cUCCNo   
                         GROUP BY UCCNo
                         HAVING COUNT( DISTINCT SKU) > 1)  
         BEGIN
            SET @nErrNo = 173851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix SKU UCC'
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)  
                         WHERE StorerKey = @cStorerKey  
                         AND   UCCNo = @cUCCNo   
                         GROUP BY UCCNo
                         HAVING COUNT( DISTINCT Lot) > 1)  
         BEGIN
            SET @nErrNo = 173852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix SKU LOT'
            GOTO Quit
         END
      END
   END
  
QUIT:  

 

GO