SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_DefLottableBySKUSortByQtyRcv          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show default lottable value by sku, sort by qty received          */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-05-20   James     1.0   WMS-19557. Created                            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_DefLottableBySKUSortByQtyRcv]
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

   DECLARE @cRDLottable01        NVARCHAR( 18),
           @cRDLottable02        NVARCHAR( 18) ,
           @cRDLottable03        NVARCHAR( 18),
           @dRDLottable04        DATETIME,
           @dRDLottable05        DATETIME,
           @cRDLottable06        NVARCHAR( 30),
           @cRDLottable07        NVARCHAR( 30),
           @cRDLottable08        NVARCHAR( 30),
           @cRDLottable09        NVARCHAR( 30),
           @cRDLottable10        NVARCHAR( 30),
           @cRDLottable11        NVARCHAR( 30),
           @cRDLottable12        NVARCHAR( 30),
           @dRDLottable13        DATETIME,
           @dRDLottable14        DATETIME,
           @dRDLottable15        DATETIME

   DECLARE @cReceiptKey NVARCHAR(10)
   SELECT @cReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   SELECT TOP 1
      @cRDLottable01 = Lottable01,
      @cRDLottable02 = Lottable02,
      @cRDLottable03 = Lottable03,
      @dRDLottable04 = Lottable04,
      @dRDLottable05 = Lottable05,
      @cRDLottable06 = Lottable06,
      @cRDLottable07 = Lottable07,
      @cRDLottable08 = Lottable08,
      @cRDLottable09 = Lottable09,
      @cRDLottable10 = Lottable10,
      @cRDLottable11 = Lottable11,
      @cRDLottable12 = Lottable12,
      @dRDLottable13 = Lottable13,
      @dRDLottable14 = Lottable14,
      @dRDLottable15 = Lottable15
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   SKU = @cSKU
   AND   (QtyExpected - BeforeReceivedQty) > 0
   ORDER BY ReceiptLineNumber
   
   IF @nLottableNo = 1  SET @cLottable01 = @cRDLottable01
   IF @nLottableNo = 2  SET @cLottable02 = @cRDLottable02
   IF @nLottableNo = 3  SET @cLottable03 = @cRDLottable03
   IF @nLottableNo = 4  SET @dLottable04 = @dRDLottable04
   IF @nLottableNo = 5  SET @dLottable05 = @dRDLottable05
   IF @nLottableNo = 6  SET @cLottable06 = @cRDLottable06
   IF @nLottableNo = 7  SET @cLottable07 = @cRDLottable07
   IF @nLottableNo = 8  SET @cLottable08 = @cRDLottable08
   IF @nLottableNo = 9  SET @cLottable09 = @cRDLottable09
   IF @nLottableNo = 10  SET @cLottable10 = @cRDLottable10
   IF @nLottableNo = 11  SET @cLottable11 = @cRDLottable11
   IF @nLottableNo = 12  SET @cLottable12 = @cRDLottable12
   IF @nLottableNo = 13  SET @dLottable13 = @dRDLottable13
   IF @nLottableNo = 14  SET @dLottable14 = @dRDLottable14
   IF @nLottableNo = 15  SET @dLottable15 = @dRDLottable15
END

GO