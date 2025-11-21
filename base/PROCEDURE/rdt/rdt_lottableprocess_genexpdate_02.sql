SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenExpDate_02                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 25-08-2018  Ung       1.0   WMS-5769 Created                               */
/* 18-09-2018  LinkLin   1.1   WMS-6356 Change expiry date logic              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenExpDate_02]
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

   DECLARE @nShelfLife  INT
   DECLARE @dExpiryDate DATETIME
   DECLARE @cDay        NVARCHAR(2)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cYear       NVARCHAR(4)

   -- Check empty
   IF @cLottable03Value <> ''
   BEGIN
      -- Check date valid
      IF rdt.rdtIsValidDate( @cLottable03Value) = 0
      BEGIN
         SET @nErrNo = 56251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
         GOTO Fail
      END

      -- Calc L04 if blank
      IF @dLottable04Value IS NULL OR @dLottable04Value = 0
      BEGIN
         -- Get Shelf life info
         SELECT @nShelfLife = ShelfLife
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU

         SET @dExpiryDate = CONVERT( DATETIME, @cLottable03Value, 112) --ISO format YYYYMMDD
         SET @cDay = RIGHT( '0' + RTRIM( DATEPART( dd, @dExpiryDate)), 2)
         SET @cMonth = RIGHT( '0' + RTRIM( DATEPART( mm, @dExpiryDate)), 2)

--         SET @dExpiryDate = DATEADD( day, @nShelfLife, @dExpiryDate)
         SET @dExpiryDate = DATEADD( year, @nShelfLife/365, @dExpiryDate)
         SET @cYear = DATEPART( yy, @dExpiryDate)

         SET @dLottable04 = CONVERT( DATETIME, @cYear + @cMonth + @cDay, 112)
         
         SET @nErrNo = -1
      END
   END

Fail:

END

GO