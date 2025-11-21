SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtInfo02                                    */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-08-19   Chermaine 1.0   WMS-17673 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_521ExtInfo02]
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
      IF @nStep IN (2, 5) -- confirm putaway
      BEGIN
         SET @cExtendedInfo1 = 'to  ' + @cToLOC
      END
   END
END

GO