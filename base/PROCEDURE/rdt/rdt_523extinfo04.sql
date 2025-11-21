SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo04                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2019-12-31 1.0  James    WMS-11501. Created                          */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo04]    
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
   
   DECLARE @cSUSR3      NVARCHAR( 18) = ''

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         SELECT @cSUSR3 = SUSR3
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         
         SET @cExtendedInfo1 = @cSUSR3
      END
   END
   
Quit:
    
END

GO