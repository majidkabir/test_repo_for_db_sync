SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP02                                 */  
/* Purpose: Validate  Location                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-10-05 1.0  James      SOS#353560                                */  
/* 2016-12-07 1.0  Ung        WMS-751 Change parameter                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP02] (  
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

   DECLARE  @cHazmat             NVARCHAR( 1), 
            @cLocCategory        NVARCHAR( 10) 

   SET @nErrNo = 0
   SET @cErrMSG = ''    

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 4  -- Suggest LOC, final LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL( @cFinalLOC, '') = ''
            BEGIN
               SET @nErrNo = 57151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
               GOTO Quit
            END
   
            IF ISNULL( @cSKU, '') = ''
            BEGIN
               SET @nErrNo = 57152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO Quit
            END
                  
            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   SKU = @cSKU
                        AND   HazardousFlag = '1')
               SET @cHazmat = '1'
            ELSE
               SET @cHazmat = '0'
   
            SELECT @cLocCategory = LocationCategory 
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cFinalLOC
            AND   Facility = @cFacility
   
            IF @cHazmat = '1' AND 
               NOT EXISTS ( SELECT 1 FROM SKU SKU WITH (NOLOCK) 
                            JOIN SKUInfo SIF WITH (NOLOCK) ON 
                               ( SKU.StorerKey = SIF.StorerKey AND SKU.SKU = SIF.SKU)
                            WHERE SKU.StorerKey = @cStorerKey
                            AND   SKU.SKU = @cSKU
                            AND   SIF.ExtendedField01 = @cLocCategory)
            BEGIN
               SET @nErrNo = 57153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
               GOTO Quit
            END
   
            IF @cHazmat = '0' AND @cLocCategory <> 'OTHER'
            BEGIN
               SET @nErrNo = 57154
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
               GOTO Quit
            END
         END
      END
   END
   
Quit:  
 

GO