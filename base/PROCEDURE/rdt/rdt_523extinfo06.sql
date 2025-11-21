SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo06                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2021-11-19 1.0  James    WMS-18387. Created                          */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo06]    
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nAfterStep      INT, 
   @nInputKey       INT,                
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cLOC            NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQTY            INT,  
   @cSuggestedLOC   NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1), 
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cExtendedField01  NVARCHAR( 30) = ''

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         SELECT @cExtendedField01 = ExtendedField01
         FROM dbo.SkuInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo1 = @cExtendedField01
      END
   END
   
Quit:
    
END

GO