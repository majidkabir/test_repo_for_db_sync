SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenMfgDate_02                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 22-08-2015  Ung       1.0   SOS347636 Created                              */
/* 25-08-2018  Ung       1.1   WMS-5769 Created                               */
/* 18-09-2018  LinkLin   1.2   WMS-6356 Change MFG date logic                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenMfgDate_02]
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
   DECLARE @dMfgDate    DATETIME
   DECLARE @cDay        NVARCHAR(2)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cYear       NVARCHAR(4)
   
   -- Check empty
   IF NOT (@dLottable04Value IS NULL OR @dLottable04Value = 0)
   BEGIN
      -- Calc L03 if blank
      IF @cLottable03Value = ''
      BEGIN
         -- Get Shelf life info
         SELECT @nShelfLife = ShelfLife
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU

         SET @cDay = RIGHT( '0' + RTRIM( DATEPART( dd, @dLottable04Value)), 2)
         SET @cMonth = RIGHT( '0' + RTRIM( DATEPART( mm, @dLottable04Value)), 2)

--         SET @dMfgDate = DATEADD( day, @nShelfLife * -1, @dLottable04Value)
         SET @dMfgDate = DATEADD( year, @nShelfLife/365 * -1, @dLottable04Value)
         SET @cYear = DATEPART( yy, @dMfgDate)

         SET @cLottable03 = @cYear + @cMonth + @cDay --ISO format YYYYMMDD
         
         SET @nErrNo = -1
      END
   END

Fail:

END

GO