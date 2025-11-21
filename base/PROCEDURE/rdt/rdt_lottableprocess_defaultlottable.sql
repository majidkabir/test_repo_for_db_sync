SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefaultLottable                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 19-04-2016  Ung       1.0    SOS368648 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DefaultLottable]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptKey NVARCHAR(10)
   SELECT @cReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nLottableNo = 1  AND @cLottable01Value             = '' SELECT @cLottable01 = MAX( Lottable01) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable01) = 1 ELSE
   IF @nLottableNo = 2  AND @cLottable02Value             = '' SELECT @cLottable02 = MAX( Lottable02) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable02) = 1 ELSE
   IF @nLottableNo = 3  AND @cLottable03Value             = '' SELECT @cLottable03 = MAX( Lottable03) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable03) = 1 ELSE
   IF @nLottableNo = 4  AND ISNULL( @dLottable04Value, 0) = 0  SELECT @dLottable04 = MAX( Lottable04) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable04) = 1 ELSE
   IF @nLottableNo = 5  AND ISNULL( @dLottable05Value, 0) = 0  SELECT @dLottable05 = MAX( Lottable05) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable05) = 1 ELSE
   IF @nLottableNo = 6  AND @cLottable06Value             = '' SELECT @cLottable06 = MAX( Lottable06) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable06) = 1 ELSE
   IF @nLottableNo = 7  AND @cLottable07Value             = '' SELECT @cLottable07 = MAX( Lottable07) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable07) = 1 ELSE
   IF @nLottableNo = 8  AND @cLottable08Value             = '' SELECT @cLottable08 = MAX( Lottable08) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable08) = 1 ELSE
   IF @nLottableNo = 9  AND @cLottable09Value             = '' SELECT @cLottable09 = MAX( Lottable09) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable09) = 1 ELSE
   IF @nLottableNo = 10 AND @cLottable10Value             = '' SELECT @cLottable10 = MAX( Lottable10) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable10) = 1 ELSE
   IF @nLottableNo = 11 AND @cLottable11Value             = '' SELECT @cLottable11 = MAX( Lottable11) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable11) = 1 ELSE
   IF @nLottableNo = 12 AND @cLottable12Value             = '' SELECT @cLottable12 = MAX( Lottable12) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable12) = 1 ELSE
   IF @nLottableNo = 13 AND ISNULL( @dLottable13Value, 0) = 0  SELECT @dLottable13 = MAX( Lottable13) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable13) = 1 ELSE
   IF @nLottableNo = 14 AND ISNULL( @dLottable14Value, 0) = 0  SELECT @dLottable14 = MAX( Lottable14) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable14) = 1 ELSE
   IF @nLottableNo = 15 AND ISNULL( @dLottable15Value, 0) = 0  SELECT @dLottable15 = MAX( Lottable15) FROM ReceiptDetail (NOLOCK) WHERE ReceiptKey = @cReceiptKey HAVING COUNT( DISTINCT Lottable15) = 1

Fail:

END

GO