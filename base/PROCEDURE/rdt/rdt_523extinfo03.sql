SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo03                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Display suggested id (from suggested loc)                   */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2015-06-27 1.0  James    WMS9392 Created                             */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo03]    
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
   
   DECLARE @cSuggID     NVARCHAR( 18)
   DECLARE @cUserName   NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         SET @cSuggID = ''
         SELECT @cSuggID = ID 
         FROM dbo.RFPutaway WITH (NOLOCK) 
         WHERE SuggestedLOC = @cSuggestedLOC 
         AND   SKU = @cSKU
         AND   FromLoc = @cLOC
         AND   FromID = @cID
         AND   AddWho = @cUserName

      
         SET @cExtendedInfo1 = 'ID: ' + @cSuggID
      END
   END
   
Quit:
    
END

GO