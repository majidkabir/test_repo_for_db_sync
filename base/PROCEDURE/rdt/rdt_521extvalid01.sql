SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_521ExtValid01                                   */  
/* Purpose: Validate  Location                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-10-05 1.0  James      SOS#353560                                */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_521ExtValid01] (  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,        
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 18), 
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

   DECLARE  @cHazmat       NVARCHAR( 1), 
            @cLocCategory  NVARCHAR( 10), 
            @cSKU          NVARCHAR( 20), 
            @cFacility     NVARCHAR( 5)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   SELECT @cFacility = Facility FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @cToLOC = 'DUMMYLOC'
         BEGIN
            SET @nErrNo = 57201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid TO LOC'
            GOTO Quit
         END

         SELECT TOP 1 
            @cSKU = SKU
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   Status = '1'
            
         IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   SKU = @cSKU
                     AND   HazardousFlag = '1')
            SET @cHazmat = '1'
         ELSE
            SET @cHazmat = '0'

         SELECT @cLocCategory = LocationCategory 
         FROM LOC WITH (NOLOCK)
         WHERE LOC = @cToLoc
         AND   Facility = @cFacility

         -- If UCC includes HAZMAT sku and final loc category <> SKU hazmat class
         IF @cHazmat = '1' AND 
            NOT EXISTS ( SELECT 1 FROM SKU SKU WITH (NOLOCK) 
                         JOIN SKUInfo SIF WITH (NOLOCK) ON 
                            ( SKU.StorerKey = SIF.StorerKey AND SKU.SKU = SIF.SKU)
                         WHERE SKU.StorerKey = @cStorerKey
                         AND   SKU.SKU = @cSKU
                         AND   SIF.ExtendedField01 = @cLocCategory)
         BEGIN
            SET @nErrNo = 57202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
            GOTO Quit
         END

         IF @cHazmat = '0'
         BEGIN
            -- If not hazmat item and final loc category <> 'OTHER'
            IF @cLocCategory <> 'OTHER'
            BEGIN
               SET @nErrNo = 57203
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
               GOTO Quit
            END
         END
      END
   END
  
QUIT:  

 

GO