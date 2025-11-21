SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtInfo01                                    */
/* Purpose: Move By LOC Extended Info                                   */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 07-Jan-2019 1.0  James      WMS7487 - Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_512ExtInfo01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @cOption          NVARCHAR( 1), 
   @cExtendedInfo    NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nStep IN ( 1, 2)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cExtendedInfo = ExtendedField02
         FROM dbo.SkuInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         IF ISNULL( @cExtendedInfo, '') =  ''
            SET @cExtendedInfo = '<none>'
      END
   END

QUIT:

GO