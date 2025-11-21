SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdt_LottableProcess_BCCheckValueInASN                       */
/* Copyright      : Maersk                                                      */
/* Customer       : Barry                                                       */
/* Purpose: Check lot values                                                    */
/*                                                                              */
/* Date        Author    Ver.    Purposes                                       */
/* 11-02-2024  PYU015    1.0     UWP-26490 Created                              */
/* 11-18-2024  PYU015    1.1.0   UWP-27049 lottable01 can not be empty          */
/********************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_BCCheckValueInASN]
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

   DECLARE @cLot01 NVARCHAR(18)
   DECLARE @cLot01_f NVARCHAR(18)
   DECLARE @cLot01_b NVARCHAR(18)
   DECLARE @cLottable01Value_f NVARCHAR(18)
   DECLARE @cLottable01Value_b NVARCHAR(18)

   -- Check lottable

   SELECT TOP 1 @cLot01 = rptl.Lottable01
     FROM RECEIPTDETAIL rptl WITH (NOLOCK) 
    INNER JOIN rdt.rdtConReceiveLog crl WITH (NOLOCK) on rptl.ReceiptKey = crl.ReceiptKey
    WHERE crl.Mobile = @nMobile 
      AND rptl.Sku = @cSKU 
      AND rptl.QtyExpected > rptl.BeforeReceivedQty

   IF CHARINDEX('#',@cLot01) > 0 
   BEGIN
      SELECT @cLot01_f = SUBSTRING(@cLot01,1,CHARINDEX('#',@cLot01)-1)
      SELECT @cLot01_b = SUBSTRING(@cLot01,CHARINDEX('#',@cLot01)+1,LEN(@cLot01))

      SELECT @cLottable01Value_f = SUBSTRING(@cLottable01Value,1,CHARINDEX('#',@cLottable01Value)-1)
      SELECT @cLottable01Value_b = SUBSTRING(@cLottable01Value,CHARINDEX('#',@cLottable01Value)+1,LEN(@cLottable01Value))

      IF CHARINDEX(@cLot01_f,@cLottable01Value_f) = 0 OR CAST(@cLot01_b AS int) <> CAST(@cLottable01Value_b AS int)
      BEGIN
         SET @nErrNo = 219931
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValueNotInList
         GOTO Quit
      END
   END
   ELSE 
   BEGIN
      IF CHARINDEX(@cLot01,@cLottable01Value) = 0 OR ISNULL(@cLottable01Value,'') = ''
      BEGIN
         SET @nErrNo = 219932
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValueNotInList
         GOTO Quit
      END
   END


Quit:

END
SET QUOTED_IDENTIFIER OFF

GO