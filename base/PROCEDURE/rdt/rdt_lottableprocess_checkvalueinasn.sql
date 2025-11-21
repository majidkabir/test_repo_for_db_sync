SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_CheckValueInASN                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check price tag                                                   */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 05-01-2021  Chermaine 1.0   WMS-15955 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_CheckValueInASN]
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

   DECLARE @cLot03   NVARCHAR( 18)
   DECLARE @cLot07   NVARCHAR( 30)
   DECLARE @cLot08   NVARCHAR( 30)
   DECLARE @cLot09   NVARCHAR( 30)
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)
   
  
   --lot07,lot08,lot09 cannot be blank
   IF ISNULL(@cLottable07Value,'') = ''
   BEGIN
   	SET @nErrNo = 161801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot07
      GOTO Quit
   END
   
   SET @cReceiptLineNumber = ''
   SELECT TOP 1 
      @cReceiptLineNumber = ReceiptLineNumber,
      @cLot03 = Lottable03,
      @cLot08 = Lottable08, 
      @cLot09 = Lottable09 
   From receiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND ReceiptKey = @cSourceKey 
   AND (QtyExpected-BeforeReceivedQty) > 0
    AND Sku = @cSKU 
    AND Lottable07 = @cLottable07Value
    
   IF @cReceiptLineNumber = ''
   BEGIN
   	SET @nErrNo = 161804
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid lot07
      GOTO Quit
   END
   
   --check lot03 = codelkup
   IF EXISTS( SELECT 1 FROM CodeLKUP (NOLOCK) WHERE StorerKey = @cStorerKey AND ListName = 'CUSTPARAM' AND Code = 'RECVAL' 
               AND (UDF01 = @cLot03 OR UDF02 = @cLot03 OR UDF03 = @cLot03 OR UDF04 = @cLot03))
               
   --IF EXISTS( SELECT 1 FROM CodeLKUP (NOLOCK), ReceiptDetail (NOLOCK) WHERE CodeLKUP.Storerkey = @cStorerKey AND CodeLKUP.Storerkey = ReceiptDetail.StorerKey
   --            AND ListName = 'CUSTPARAM' AND Code = 'RECVAL' AND ReceiptDetail.ReceiptKey = @cSourceKey AND ReceiptDetail.ReceiptLineNumber = @cReceiptLineNumber
   --            AND (UDF01 = ReceiptDetail.Lottable03 OR UDF02 = ReceiptDetail.Lottable03 OR UDF03 = ReceiptDetail.Lottable03 OR UDF04 = ReceiptDetail.Lottable03))
   BEGIN
      IF ISNULL(@cLot08,'') = ''
      BEGIN
   	   SET @nErrNo = 161802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot08
         GOTO Quit
      END
   
      IF ISNULL(@cLot09,'') = ''
      BEGIN
   	   SET @nErrNo = 161803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot09
         GOTO Quit
      END
   END
   
Quit:
   
END

GO