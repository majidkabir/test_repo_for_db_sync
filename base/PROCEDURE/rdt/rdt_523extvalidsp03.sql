SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP03                                 */  
/* Purpose: Validate UCC.                                               */
/*          1. If mix sku, prompt error                                 */  
/*          2. If sku no pick loc assigned, prompt error                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-02-16 1.0  James     WMS1079. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP03] (  
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
            SET @nErrNo = 106201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc sku
            GOTO Quit
         END

         SELECT TOP 1 @cSKU = SKU
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC 
         AND   [Status] = '1'

         -- Check if sku has assigned pick loc
         IF NOT EXISTS ( 
            SELECT 1 
            FROM dbo.SKUxLOC SL WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
            WHERE SL.StorerKey = @cStorerKey
            AND   SL.LocationType = 'PICK'
            AND   SL.SKU = @cSKU
            AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 106202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No home loc
            GOTO Quit
         END
      END    

      IF @nStep = 2
      BEGIN
         -- user not key in sku, no need validation
         IF ISNULL( @cSKU, '') = ''
            GOTO Quit

         -- Check if sku has assigned pick loc
         IF NOT EXISTS ( 
            SELECT 1 
            FROM dbo.SKUxLOC SL WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
            WHERE SL.StorerKey = @cStorerKey
            AND   SL.LocationType = 'PICK'
            AND   SL.SKU = @cSKU
            AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 106203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No home loc
            GOTO Quit
         END
      END    
   END
    
   QUIT:
 

GO