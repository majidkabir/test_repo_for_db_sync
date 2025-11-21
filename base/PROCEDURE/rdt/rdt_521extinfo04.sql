SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtInfo04                                    */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-05-08   yeekung   1.0   WMS-22498 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_521ExtInfo04]
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

   DECLARE @cNotes1     NVARCHAR( 20)
   DECLARE @nUCCQTY  INT
   DECLARE @cFacility   NVARCHAR( 5)
   
   SELECT @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         SELECT @cNotes1 = SKU.NOTES1, @nUCCQTY =qty
         FROM UCC UCC (NOLOCK) JOIN
         SKU SKU (NOLOCK)  ON UCC.SKU =SKU.SKU AND SKU.Storerkey = UCC.Storerkey
         WHERE UCCNO = @cUCCNo
            AND SKU.Storerkey = @cStorerkey

         SET @cExtendedInfo1 = RIGHT(@cNotes1,15) + '|'+ CAST(@nUCCQTY AS NVARCHAR(5))
      END
   END
END

GO