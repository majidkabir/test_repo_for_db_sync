SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_L10ToLOC                              */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: track return location                                             */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 28-08-2018  Ung       1.0   WMS-5956 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_L10ToLOC]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSignatory NVARCHAR( 18)
   DECLARE @cBrand NVARCHAR( 250)
   DECLARE @cReceiptKey NVARCHAR( 10)
   
   SET @cReceiptKey = @cSourceKey -- ReceiptKey

   IF @cLottable01 = ''
   BEGIN
      -- Get receipt info
      SELECT @cSignatory = ISNULL( Signatory, '')
      FROM Receipt WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey

      -- Get SKU info
      SET @cBrand = ''
      SELECT @cBrand = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'ITEMCLASS' 
         AND StorerKey = @cStorerKey 
         AND Code = @cSignatory

      IF @cBrand = 'CPD'
         IF @cLottable09Value = ''
         BEGIN
            SET @nErrNo = 128451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need CPD ToLOC
         END
   END
END

GO