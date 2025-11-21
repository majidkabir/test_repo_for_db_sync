SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1841ExtInfo01                                   */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdt_fncPrePalletizeSort                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-04-06  1.0  James      WMS-16725. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1841ExtInfo01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cReceiptKey    NVARCHAR( 10),
   @cLane          NVARCHAR( 10),
   @cUCC           NVARCHAR( 20),
   @cToID          NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cOption        NVARCHAR( 1),               
   @cPosition      NVARCHAR( 20),
   @tExtInfoVar    VariableTable READONLY, 
   @cExtendedInfo        NVARCHAR( 20) OUTPUT

)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nAfterStep IN ( 2, 4)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cPosition = Position
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   [Status] = '1'
         AND   Loc = @cLane
         AND   UCCNo = @cUCC
         ORDER BY 1 DESC

         SET @cExtendedInfo = 'POSITION: ' + @cPosition
      END
   END

   Quit:


GO