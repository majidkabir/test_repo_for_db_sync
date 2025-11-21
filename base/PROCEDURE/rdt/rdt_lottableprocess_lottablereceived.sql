SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_LottableReceived                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check lottable received                                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   WMS-1241 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_LottableReceived]
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

   DECLARE @nReceived INT
   
   -- Get lottable
   IF @nLottableNo =  1 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable01 = @cLottable01Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  2 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable02 = @cLottable02Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  3 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable03 = @cLottable03Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  4 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable04 = @dLottable04Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  5 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable05 = @dLottable05Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  6 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable06 = @cLottable06Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  7 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable07 = @cLottable07Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  8 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable08 = @cLottable08Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo =  9 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable09 = @cLottable09Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 10 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable10 = @cLottable10Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 11 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable11 = @cLottable11Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 12 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable12 = @cLottable12Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 13 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable13 = @dLottable13Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 14 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable14 = @dLottable14Value AND BeforeReceivedQTY > 0 ELSE 
   IF @nLottableNo = 15 SELECT @nReceived = 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cSourceKey AND Lottable15 = @dLottable15Value AND BeforeReceivedQTY > 0

   -- Check received
   IF @nReceived = 1
   BEGIN
      SET @nErrNo = 106551
      SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --Received L99
      GOTO Quit
   END
   
Quit:
   
END

GO