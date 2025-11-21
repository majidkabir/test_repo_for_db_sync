SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL4L14ExpiryByL1Batch03       */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Key-inYYMM, default DD                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 01-06-2023  1.0  YeeKung     WMS-22114 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_GenL4L14ExpiryByL1Batch03]
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

   DECLARE @cShelflife INT
   DECLARE @cReceiptkey NVARCHAR(20)

   SELECT @cReceiptkey = V_Receiptkey
   from rdt.rdtmobrec (nolock)
   where mobile =@nMobile

   SET @dLottable05 = GETDATE()

   IF EXISTS (SELECT 1
              FROM RECEIPT (NOLOCK)
              WHERE Receiptkey =@cReceiptkey
               AND storerkey = @cStorerKey
               AND Carrierkey NOT IN ('LFLSG', 'MaerskSG'))
   BEGIN

      SELECT @cShelflife=shelflife
      FROM dbo.SKU (NOLOCK)
      WHERE SKU = @csku
      and storerkey=@cStorerKey --(yeekung01)

      SELECT TOP 1 @dLottable04 = Lottable04,
                   @dLottable14 = Lottable14
      FROM Receiptdetail (nolock)
      WHERE Receiptkey = @cReceiptkey
         AND SKU = @csku
         and storerkey=@cStorerKey

      IF rdt.rdtIsValidDate( rdt.rdtformatdate(@dLottable04)) = 0
      BEGIN
         SET @dLottable04=DATEADD (DAY,@cShelflife,@dLottable05)
      END

      IF rdt.rdtIsValidDate( rdt.rdtformatdate(@dLottable14)) = 0
      BEGIN
         SET @dLottable14 = GETDATE()
      END
   END
   ELSE
   BEGIN
      
      SELECT TOP 1 @dLottable04 = Lottable04,
                   @dLottable14 = Lottable14
      FROM Receiptdetail (nolock)
      WHERE Receiptkey = @cReceiptkey
         AND SKU = @csku
         and storerkey=@cStorerKey
   END


END -- End Procedure


GO