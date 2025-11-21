SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1581SuggestLoc01                                */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: To set Loc by ASN                                           */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 29-05-2023  1.0  yeekung     WMS-22634. Created                      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1581SuggestLoc01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@cSuggestedLoc NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRECTYPE NVARCHAR(20)

   --Default toloc form the top 1 receiptdetail.toloc where QtyExpected > 0 and isnull(toloc,ÆÆ) <> æÆ  if it is not found, do not default any value.

   IF @cReceiptKey <> ''
   BEGIN
      SELECT  @cRECTYPE =  RECTYPE
      FROM RECEIPT (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
         AND Storerkey = @cStorerKey

      SELECT @cSuggestedLoc = Udf03
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'RECTYPE'
         AND Storerkey = @cStorerKey
         AND CODE = @cRECTYPE
   END

   QUIT:
END

GO