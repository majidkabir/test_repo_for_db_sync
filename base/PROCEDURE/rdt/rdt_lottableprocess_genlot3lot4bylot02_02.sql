SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenLot3Lot4ByLot02_02                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 09-Aug-2022  Ung       1.0   WMS-20425 Created                             */
/* 07-Sep-2023  Ung       1.1   WMS-23431 Add group D logic                   */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_GenLot3Lot4ByLot02_02]
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

   BEGIN TRY
      DECLARE @nLen INT = LEN( @cLottable02Value)

      -- Remove space, dash
      SET @cLottable02Value = REPLACE( @cLottable02Value, ' ', '')
      SET @cLottable02Value = REPLACE( @cLottable02Value, '-', '')
      
      -- Check empty
      IF @cLottable02Value <> ''
      BEGIN
         DECLARE @cYear  NVARCHAR( 2)
         DECLARE @cMonth NVARCHAR( 2)
         DECLARE @cDay   NVARCHAR( 2) = '01'
         DECLARE @cCurrentYear NVARCHAR(1)
         DECLARE @dLottable03Value DATE
         DECLARE @cLottable04Value NVARCHAR(10)
         DECLARE @nShelfLife INT = 0

         -- Get SKU info
         SELECT @nShelfLife = ISNULL( ShelfLife, 0)
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU

         -- Logic group B
         IF @nLen = 4
         BEGIN
            SET @cMonth = SUBSTRING( @cLottable02Value, 3, 1)
            SET @cYear = SUBSTRING( @cLottable02Value, 4, 1)
            
            -- Convert month to 2 digits
            SELECT @cMonth = 
               CASE @cMonth 
                  WHEN 'A' THEN '01'
                  WHEN 'B' THEN '02'
                  WHEN 'C' THEN '03'
                  WHEN 'D' THEN '04'
                  WHEN 'E' THEN '05'
                  WHEN 'F' THEN '06'
                  WHEN 'G' THEN '07'
                  WHEN 'H' THEN '08'
                  WHEN 'I' THEN '09'
                  WHEN 'J' THEN '10'
                  WHEN 'K' THEN '11'
                  WHEN 'L' THEN '12'
                  ELSE ''
               END
               
            -- Get current year digit
            SET @cCurrentYear = RIGHT( FORMAT( GETDATE(), 'yy'), 1)

            -- If the year digit in the data scanned, is same as current year, then take current year
            -- If more than current year, then taken as year in previous decade
            IF @cYear <= @cCurrentYear
               SET @cYear = LEFT( FORMAT( GETDATE(), 'yy'), 1) + @cYear    -- Current decade
            
            ELSE IF @cYear > @cCurrentYear
               SET @cYear = LEFT( FORMAT( YEAR( GETDATE()) - 10, 'yy'), 1) + @cYear   -- Previous decade

            -- Calc L03
            SET @cLottable03Value = @cMonth + '/' + @cDay + '/' + @cYear
            SET @dLottable03Value = CONVERT( DATETIME, @cLottable03Value, 1) -- 1 = mm/dd/yy
            
            -- Calc L04
            SET @dLottable04Value = DATEADD( dd, @nShelfLife, @dLottable03Value)
            SET @dLottable04Value = CONVERT( DATETIME, CAST( MONTH( @dLottable04Value) AS NVARCHAR(2)) + '/01/' + CAST( YEAR( @dLottable04Value) AS NVARCHAR(4)), 101) -- 101 = mm/dd/yyyy, set 1st day of month

            -- Output
            SELECT @cLottable03 = @cLottable03Value
            SELECT @dLottable04 = @dLottable04Value
         END

         -- Logic group C
         ELSE IF @nLen = 6
         BEGIN
            DECLARE @cWeek NVARCHAR( 2)
            SET @cYear = SUBSTRING( @cLottable02Value, 1, 2)
            SET @cWeek = SUBSTRING( @cLottable02Value, 3, 2)
            
            DECLARE @dDate DATETIME
            SET @dDate = CONVERT( DATETIME, '01/01/' + @cYear, 1) -- 1 = mm/dd/yy
            SET @dDate = DATEADD( wk, CAST( @cWeek AS INT) - 1, @dDate)
            SET @cMonth = DATEPART( mm, @dDate)

            -- Calc L03
            SET @cLottable03Value = @cMonth + '/' + @cDay + '/' + @cYear
            SET @dLottable03Value = CONVERT( DATETIME, @cLottable03Value, 1) -- 1 = mm/dd/yy
            
            -- Calc L04
            SET @dLottable04Value = DATEADD( dd, @nShelfLife, @dLottable03Value)
            SET @dLottable04Value = CONVERT( DATETIME, CAST( MONTH( @dLottable04Value) AS NVARCHAR(2)) + '/01/' + CAST( YEAR( @dLottable04Value) AS NVARCHAR(4)), 101) -- 101 = mm/dd/yyyy, set 1st day of month

            -- Output
            SET @cLottable03 = @cLottable03Value
            SET @dLottable04 = @dLottable04Value
         END

         -- Logic group D
         ELSE IF @nLen = 7 AND LEFT( @cLottable02Value, 1) LIKE '[0-9]'
         BEGIN
            SET @cMonth = SUBSTRING( @cLottable02Value, 2, 1)
            SET @cYear = SUBSTRING( @cLottable02Value, 3, 1)
            
            -- Convert month to 2 digits
            SELECT @cMonth = 
               CASE @cMonth 
                  WHEN 'A' THEN '01'
                  WHEN 'B' THEN '02'
                  WHEN 'C' THEN '03'
                  WHEN 'D' THEN '04'
                  WHEN 'E' THEN '05'
                  WHEN 'F' THEN '06'
                  WHEN 'G' THEN '07'
                  WHEN 'H' THEN '08'
                  WHEN 'I' THEN '09'
                  WHEN 'J' THEN '10'
                  WHEN 'K' THEN '11'
                  WHEN 'L' THEN '12'
                  ELSE ''
               END
            
            -- Get current year digit
            SET @cCurrentYear = RIGHT( FORMAT( GETDATE(), 'yy'), 1)

            -- If the year digit in the data scanned, is same as current year or less then current year, it is automatically taken as year in next decade
            IF @cYear <= @cCurrentYear
               SET @cYear = LEFT( FORMAT( YEAR( GETDATE()) + 10, 'yy'), 1) + @cYear   -- Next decade
            ELSE
               SET @cYear = LEFT( FORMAT( GETDATE(), 'yy'), 1) + @cYear    -- Current decade

            -- Calc L04
            SET @cLottable04Value = @cMonth + '/' + @cDay + '/' + @cYear
            SET @dLottable04Value = CONVERT( DATETIME, @cLottable04Value, 1) -- 1 = mm/dd/yy    
            SET @dLottable04Value = EOMONTH( @dLottable04Value) -- last day of month

            -- Calc L03
            SET @dLottable03Value = DATEADD( dd, -@nShelfLife, @dLottable04Value)
            SET @dLottable03Value = CONVERT( DATETIME, CAST( MONTH( @dLottable03Value) AS NVARCHAR(2)) + '/01/' + CAST( YEAR( @dLottable03Value) AS NVARCHAR(4)), 101) -- 101 = mm/dd/yyyy, set 1st day of month

            -- Output
            SET @cLottable03 = CONVERT( NVARCHAR( 8), @dLottable03Value, 1)  -- 1 = mm/dd/yy
            SET @dLottable04 = @dLottable04Value
         END

         -- Logic group A
         ELSE
         BEGIN
            SET @cMonth = SUBSTRING( @cLottable02Value, 4, 2)
            SET @cYear = SUBSTRING( @cLottable02Value, 6, 2)
            
            SET @cYear = CAST( @cYear AS INT) - 10
         
            -- Calc L03
            SET @cLottable03Value = @cMonth + '/' + @cDay + '/' + @cYear
            SET @dLottable03Value = CONVERT( DATETIME, @cLottable03Value, 1) -- 1 = mm/dd/yy
            
            -- Calc L04
            SET @dLottable04Value = DATEADD( dd, @nShelfLife, @dLottable03Value)
            SET @dLottable04Value = CONVERT( DATETIME, CAST( MONTH( @dLottable04Value) AS NVARCHAR(2)) + '/01/' + CAST( YEAR( @dLottable04Value) AS NVARCHAR(4)), 101) -- 101 = mm/dd/yyyy, set 1st day of month

            -- Output
            SET @cLottable03 = @cLottable03Value
            SET @dLottable04 = @dLottable04Value
         END
      END
   END TRY
   BEGIN CATCH
      SET @nErrNo = 189551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Decode Error
   END CATCH
END

GO