SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_ManningsValidateL04                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-07-30   James     1.0   WMS-17561. Created                            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_ManningsValidateL04]
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

   DECLARE @cUDF01   NVARCHAR( 60)
   DECLARE @cUDF03   NVARCHAR( 60)
   DECLARE @cUDF04   NVARCHAR( 60)
   DECLARE @cUDF05   NVARCHAR( 60)
   DECLARE @cItemClass  NVARCHAR( 10)
   DECLARE @nShelfLife  INT
   DECLARE @cChannel NVARCHAR( 20)
   
   IF @nLottableNo = 4 
   BEGIN
      IF ISNULL( @dLottable04Value, 0) = 0
      BEGIN
         SET @nErrNo = 172501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lottable04 req
         GOTO Quit
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                      WHERE ReceiptKey = SUBSTRING ( @cSourceKey, 1, 10)
                      GROUP BY ReceiptKey
                      HAVING ISNULL( SUM( BeforeReceivedQty), 0) > 1)
         GOTO Quit

      SELECT TOP 1 @cChannel = Channel
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = SUBSTRING ( @cSourceKey, 1, 10)
      ORDER BY 1
      
      IF @cChannel NOT IN ('B2B', 'B2C')
         GOTO Quit

      SELECT 
         @cItemClass = itemclass, 
         @nShelfLife = ShelfLife
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Sku = @cSKU
      
      SELECT 
         @cUDF03 = UDF03, 
         @cUDF04 = UDF04, 
         @cUDF05 = UDF05
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'MANCATA'
      AND   Storerkey = @cStorerKey
      AND   Code = @cItemClass
      
      IF @cChannel = 'B2B'
      BEGIN
         IF rdt.rdtIsValidQTY( @cUDF03, 0) = 0 
         BEGIN
            SET @nErrNo = 172502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Udf03
            GOTO Quit
         END

         IF rdt.rdtIsValidQTY( @cUDF04, 1) = 0
         BEGIN
            SET @nErrNo = 172503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Udf04
            GOTO Quit
         END

         IF rdt.rdtIsValidQTY( @cUDF05, 0) = 0
         BEGIN
            SET @nErrNo = 172504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Udf05
            GOTO Quit
         END

         IF DATEDIFF( DAY, GETDATE(), @dLottable04) < ((@nShelfLife * CAST( @cUDF03 AS INT)) / CAST( @cUDF04 AS INT))
         BEGIN
            SET @nErrNo = 172505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --<MinShelfLife
            GOTO Quit
         END

         IF DATEDIFF( DAY, GETDATE(), @dLottable04) < CAST( @cUDF05 AS INT)
         BEGIN
            SET @nErrNo = 172506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --<MinShelfLife
            GOTO Quit
         END
      END
      ELSE  -- B2C
      BEGIN
         SELECT 
            @cUDF01 = UDF01
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'MANCATA'
         AND   Storerkey = @cStorerKey
         AND   code2 = 'B2C'
      
         IF rdt.rdtIsValidQTY( @cUDF01, 0) = 0 
         BEGIN
            SET @nErrNo = 172507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Udf01
            GOTO Quit
         END

         IF DATEDIFF( DAY, GETDATE(), @dLottable04) < (CAST( @cUDF01 AS INT))
         BEGIN
            SET @nErrNo = 172508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --<MinShelfLife
            GOTO Quit
         END
      END
   END

   Quit:
END

GO