SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1841ExtInfo02                                   */
/*                                                                      */
/* Purpose: Display sum(ucc.qty) when ucc.userdefine07 = 1              */
/*                                                                      */
/* Called from: rdt_fncPrePalletizeSort                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-02-02  1.0  James      WMS-21588. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1841ExtInfo02] (
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
   @cExtendedInfo  NVARCHAR( 20) OUTPUT

)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nUCCQty     INT = 0
   
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	IF EXISTS ( SELECT 1 
      	            FROM dbo.UCC WITH (NOLOCK)
                     WHERE Storerkey = @cStorerKey
                     AND   UCCNo = @cUCC
                     AND   Userdefined07 = '1')
            SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cUCC
            AND   Userdefined07 = '1'
         ELSE
            SELECT @nUCCQty = ISNULL( Qty, 0)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cUCC
         	
         IF @nUCCQty > 0
            SET @cExtendedInfo = 'UCC Qty: ' + CAST( @nUCCQty AS NVARCHAR( 5))
      END
   END

   Quit:


GO