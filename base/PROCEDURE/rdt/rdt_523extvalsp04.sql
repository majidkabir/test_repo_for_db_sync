SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValSP04                                   */  
/* Purpose: Validate  Location                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-03-17 1.0  Ung        WMS-1365 Created                          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValSP04] (  
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),  
   @cLOC             NVARCHAR( 10), 
   @cID              NVARCHAR( 18), 
   @cSKU             NVARCHAR( 20), 
   @nQTY             INT,  
   @cSuggestedLOC    NVARCHAR( 10),
   @cFinalLOC        NVARCHAR( 10),
   @cOption          NVARCHAR( 1),
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT
)  
AS  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   SET @nErrNo = 0
   SET @cErrMsg = ''    

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 4  -- Suggest LOC, final LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cSuggestedLOC = ''
            BEGIN
               -- Check non-empty LOC
               IF EXISTS ( SELECT 1 
                  FROM dbo.SKUxLOC WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LOC = @cFinalLOC
                     AND QTY-QTYPicked > 0)
               BEGIN
                  SET @nErrNo = 107001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not empty
                  GOTO Quit
               END
               
               /*
               -- Check other pick face LOC
               IF EXISTS ( SELECT 1 
                  FROM dbo.SKUxLOC WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND SKU <> @cSKU
                     AND LOC = @cFinalLOC
                     AND LocationType = 'PICK')
               BEGIN
                  SET @nErrNo = 107002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Other SKU LOC
                  GOTO Quit
               END
               */
            END
         END
      END
   END
   
Quit:  
 

GO