SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefaultLastValue                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Default lottable as last input value                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 15-08-2022  Ung       1.0   WMS-20493 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DefaultLastValue]
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

   IF @nFunc = 600 -- Normal receive V7
   BEGIN
      IF @cType = 'PRE'
      BEGIN
         -- Get session info
         DECLARE @cReceiptKey NVARCHAR( 10)
         SELECT @cReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile 
         
         -- IF @cLottable = ''
         BEGIN
            IF @cSKU = ''
            BEGIN
               -- Get last value by lottable
               IF @nLottableNo =  1 SELECT TOP 1 @cLottable01 = Lottable01 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  2 SELECT TOP 1 @cLottable02 = Lottable02 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  3 SELECT TOP 1 @cLottable03 = Lottable03 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  4 SELECT TOP 1 @dLottable04 = Lottable04 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  5 SELECT TOP 1 @dLottable05 = Lottable05 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  6 SELECT TOP 1 @cLottable06 = Lottable06 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  7 SELECT TOP 1 @cLottable07 = Lottable07 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  8 SELECT TOP 1 @cLottable08 = Lottable08 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  9 SELECT TOP 1 @cLottable09 = Lottable09 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 10 SELECT TOP 1 @cLottable10 = Lottable10 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 11 SELECT TOP 1 @cLottable11 = Lottable11 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 12 SELECT TOP 1 @cLottable12 = Lottable12 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 13 SELECT TOP 1 @dLottable13 = Lottable13 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 14 SELECT TOP 1 @dLottable14 = Lottable14 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 15 SELECT TOP 1 @dLottable15 = Lottable15 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() ORDER BY EditDate DESC
            END
            ELSE
            BEGIN
               -- Get last value by SKU, lottable
               IF @nLottableNo =  1 SELECT TOP 1 @cLottable01 = Lottable01 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  2 SELECT TOP 1 @cLottable02 = Lottable02 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  3 SELECT TOP 1 @cLottable03 = Lottable03 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  4 SELECT TOP 1 @dLottable04 = Lottable04 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  5 SELECT TOP 1 @dLottable05 = Lottable05 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  6 SELECT TOP 1 @cLottable06 = Lottable06 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  7 SELECT TOP 1 @cLottable07 = Lottable07 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  8 SELECT TOP 1 @cLottable08 = Lottable08 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo =  9 SELECT TOP 1 @cLottable09 = Lottable09 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 10 SELECT TOP 1 @cLottable10 = Lottable10 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 11 SELECT TOP 1 @cLottable11 = Lottable11 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 12 SELECT TOP 1 @cLottable12 = Lottable12 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 13 SELECT TOP 1 @dLottable13 = Lottable13 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 14 SELECT TOP 1 @dLottable14 = Lottable14 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC ELSE
               IF @nLottableNo = 15 SELECT TOP 1 @dLottable15 = Lottable15 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND EditWho = SUSER_SNAME() AND SKU = @cSKU ORDER BY EditDate DESC
            END
         END
      END
   END
   
Quit:

END

GO