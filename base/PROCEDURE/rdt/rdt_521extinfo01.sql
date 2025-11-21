SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtInfo01                                    */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-08-03   James     1.0   SOS373949 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_521ExtInfo01]
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,       
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 20), 
   @cSuggestedLOC   NVARCHAR( 10), 
   @cToLOC          NVARCHAR( 10), 
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU        NVARCHAR( 20),
           @cSKUGROUP   NVARCHAR( 10)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         SELECT TOP 1 @cSKU = SKU
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   Status = '1'

         SELECT TOP 1 @cSKUGROUP = SKUGROUP
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo1 = 'CATEGORY: ' + @cSKUGROUP
      END
   END
END

GO