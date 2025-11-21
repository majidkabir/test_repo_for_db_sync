SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_LottableProcess_VerifyValueInASN                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check price tag                                                   */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 11-08-2023  yeekung  1.0   WMS-23200 Created                              */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_VerifyValueInASN]
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

   DECLARE @nExist INT = 0

      -- Check lottable
   IF @nLottableNo =  1 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable01 = @cLottable01Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  2 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable02 = @cLottable02Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  3 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable03 = @cLottable03Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  4 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable04 = @dLottable04Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  5 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable05 = @dLottable05Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  6 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable06 = @cLottable06Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  7 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable07 = @cLottable07Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  8 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable08 = @cLottable08Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo =  9 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable09 = @cLottable09Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 10 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable10 = @cLottable10Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 11 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable11 = @cLottable11Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 12 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable12 = @cLottable12Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 13 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable13 = @dLottable13Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 14 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable14 = @dLottable14Value AND (QtyExpected-BeforeReceivedQty) > 0 END ELSE
   IF @nLottableNo = 15 BEGIN SELECT @nExist = 1 FROM receiptdetail WITH (NOLOCK) WHERE receiptkey = @cSourceKey AND StorerKey = @cStorerKey AND Lottable15 = @dLottable15Value AND (QtyExpected-BeforeReceivedQty) > 0 END 


   -- Check value exist in receiptdetail lookup
   IF @nExist = 0
   BEGIN
      SET @nErrNo = 205201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValueNotInList
      GOTO Quit
   END

Quit:

END

GO