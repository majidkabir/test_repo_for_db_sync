SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL4ByL2_01                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 30-Mar-2015  Ung       1.0   SOS335126 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenL4ByL2_01]
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

   IF @cLottable02Value <> '' AND (@dLottable04Value IS NULL OR @dLottable04Value = 0)
   BEGIN
      DECLARE @cYear       NVARCHAR(4) 
      DECLARE @cMonth      NVARCHAR(2)
      DECLARE @cDay        NVARCHAR(3)
      DECLARE @nShelfLife  INT
      DECLARE @cItemClass  NVARCHAR(10)
      DECLARE @dExpiryDate DATETIME

      -- Get SKU info
      SELECT 
         @nShelfLife = ShelfLife, 
         @cItemClass = ItemClass
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      IF LEN( @cLottable02Value) = 6 
      BEGIN
         -- Get Shelf life info
         SELECT 
            @cYear = Short, 
            @cMonth = RIGHT( '0' + RTRIM( Long), 2)
         FROM Codelkup WITH (NOLOCK)
         WHERE ListName = 'LORCVBH1' 
            AND Code = SUBSTRING( @cLottable02Value, 3, 2)

         IF @cYear BETWEEN '1900' AND '9999' AND
            @cMonth BETWEEN '01' AND '12'
         BEGIN
            SET @nShelfLife = CEILING( @nShelfLife / CAST( 360 AS FLOAT)) -- Shelf life is setup as days, but min unit is year. 1 year = 360 days
            SET @dExpiryDate = CONVERT( DATETIME, @cYear + @cMonth + '01', 112) --ISO format YYYYMMDD
            SET @dExpiryDate = DATEADD( year, @nShelfLife, @dExpiryDate)
            SET @dLottable04 = @dExpiryDate
         END
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM Codelkup WITH (NOLOCK) WHERE ListName = 'ITEMCLASS' AND Code = @cItemClass AND Long = 'LPD') 
         BEGIN
            -- Get Shelf life info
            SELECT @cYear = Short
            FROM Codelkup WITH (NOLOCK)
            WHERE ListName = 'LORCVBH2' 
               AND Code = SUBSTRING( @cLottable02Value, 2, 1)

            SET @cDay = SUBSTRING( @cLottable02Value, 3, 3)

            IF @cYear BETWEEN '1900' AND '9999' AND
               @cDay BETWEEN '001' AND '366'
            BEGIN
               SET @cMonth = DATEPART( mm, DATEADD( day, CAST( @cDay AS INT) - 1, CONVERT( DATETIME, @cYear + '0101', 112)))
               SET @cMonth = RIGHT( '0' + RTRIM( @cMonth), 2)
               SET @nShelfLife = CEILING( @nShelfLife / CAST( 360 AS FLOAT)) -- Shelf life is setup as days, but min unit is year. 1 year = 360 days
               SET @dExpiryDate = CONVERT( DATETIME, @cYear + @cMonth + '01', 112) --ISO format YYYYMMDD
               SET @dExpiryDate = DATEADD( year, @nShelfLife, @dExpiryDate)
               SET @dLottable04 = @dExpiryDate
            END
         END
      END
      SET @nErrNo = -1
   END
END

GO