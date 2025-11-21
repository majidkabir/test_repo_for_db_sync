SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP09                                 */  
/*                                                                      */
/* Purpose: Validate UCC. If mix sku, prompt error                      */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-02-16 1.0  James     WMS1079. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP09] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,  
   @cSuggestedLOC   NVARCHAR( 10), 
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1),  
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cUCC           NVARCHAR( 20)

   SELECT @cUCC = I_Field02
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 1
      BEGIN
         -- user not key in ucc, no need validation
         IF ISNULL( @cUCC, '') = ''
            GOTO Quit

         -- Check if ucc has mix sku
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   UCCNo = @cUCC 
                     AND   [Status] = '1'
                     GROUP BY UCCNo 
                     HAVING COUNT( DISTINCT SKU) > 1)
         BEGIN
            SET @nErrNo = 152451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc sku
            GOTO Quit
         END

         -- Check if ucc has mix lottable
         IF EXISTS ( SELECT 1 FROM dbo.UCC UCC WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( UCC.Lot = LA.Lot)
                     WHERE UCC.StorerKey = @cStorerKey
                     AND   UCC.UCCNo = @cUCC 
                     AND   UCC.Status = '1'
                     GROUP BY UCC.UCCNo 
                     HAVING COUNT( DISTINCT LA.Lottable02 + LA.Lottable03 + CAST( LA.Lottable04 AS NVARCHAR( 10))) > 1)
         BEGIN
            SET @nErrNo = 152452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc Lots
            GOTO Quit
         END
      END    
   END
    
   QUIT:
 

GO