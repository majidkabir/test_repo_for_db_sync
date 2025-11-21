SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP04                                 */  
/* Purpose: Validate Final LOC.                                         */
/*          1. If locationtype = 'PICK', prompt error                   */  
/*          2. If locationtype <> 'PICK', pass                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-02-16 1.0  James     WMS2269. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP04] (  
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

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4
      BEGIN
         -- Make sure the sku do not have any locationtype = 'Pick'
         IF EXISTS ( SELECT 1 
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = LLI.LOC
                     WHERE LLI.SKU = @cSKU
                     AND   LLI.StorerKey = @cStorerKey
                     AND   ( LLI.Qty - LLI.QtyPicked) > 0
                     AND   LOC.LocationType = 'PICK' 
                     AND   LOC.Facility = @cFacility)
         BEGIN
            -- If suggest <> user key in loc and key in loc is location type = pick then error
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Facility = @cFacility
                        AND   LOC = @cFinalLOC
                        AND   LocationType = 'PICK') AND @cSuggestedLOC <> @cFinalLOC
            BEGIN
               SET @nErrNo = 111751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pick Location
               GOTO Quit
            END
         END
      END
   END
    
   QUIT:
 

GO