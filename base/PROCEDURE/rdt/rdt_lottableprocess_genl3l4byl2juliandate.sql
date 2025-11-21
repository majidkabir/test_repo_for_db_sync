SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL3L4ByL2JulianDate                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose:  Generate Receiptdetail Lottable03 & Lottable04                   */
/*           By JulianDate in Lottable02                                      */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-07-16   James     1.0   WMS9161. Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenL3L4ByL2JulianDate]
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

   DECLARE 
      @nBatchYear         INT,
      @nDaysInYear        INT,
      @cBatchYear         NVARCHAR( 1),
      @cDaysInYear        NVARCHAR( 3),
      @nShelflife         INT,
      @bDebug             INT

   DECLARE 
      @dt_Today            DATETIME,
      @nCurrYear           INT,
      @nCurrYear3Digits    INT,
      @dt_CurrYearDay1     DATETIME,
      @nTempYear           INT,
      @dt_TempYearDay1     DATETIME,
      @dt_TempDate         DATETIME,
      @nManufYear          INT,
      @dt_ManufYearDay1    DATETIME,
      @dt_ManufDate        DATETIME,
      @cIsLeapYear         NVARCHAR( 1)

   IF @cType = 'PRE'
   BEGIN
      SET @cLottable02 = ''
      GOTO Quit
   END

   IF @cLottable02Value <> ''
   BEGIN 
      -- Eg. 8060XXXXXX
      SELECT @cBatchYear = LEFT(@cLottable02Value, 1) -- 8
      SELECT @cDaysInYear = SUBSTRING(@cLottable02Value, 2, 3) -- 060

      IF NOT (@cBatchYear >= '0' AND @cBatchYear <= '9')
      BEGIN
         SET @nErrNo = 142001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Inv Batch/Year'    
         GOTO QUIT
      END

      -- Validate DaysInYear (eg. 7.1, .99, etc)
      DECLARE @i INT
      DECLARE @c NVARCHAR(1)
      SET @i = 1
      WHILE @i <= LEN( dbo.fnc_RTrim( @cDaysInYear))
      BEGIN
         SET @c = SUBSTRING( @cDaysInYear, @i, 1)
         IF NOT (@c >= '0' AND @c <= '9')
         BEGIN
            SET @nErrNo = 142002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'Inv DaysInYear'            
            GOTO QUIT
         END
         SET @i = @i + 1
      END 

      -- Convert to Integer
      SELECT @nBatchYear = CAST(@cBatchYear AS INT)
      SELECT @nDaysInYear = CAST(@cDaysInYear AS INT) 

      IF @bDebug = 1
      BEGIN
         SELECT '@nBatchYear', @nBatchYear
         SELECT '@nDaysInYear', @nDaysInYear
      END

      IF @nDaysInYear <= 0
      BEGIN
         SET @nErrNo = 142003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'DaysInYear <= 0'  
         GOTO QUIT
      END
   
      /*********************************************************************************/
      /* Julian Date must be smaller than today's date (It refers to production date)  */
      /* Eg. JulianDate      = 8060XXXXXX, where BatchYear = 8 and DaysInYear = 60     */
      /* Get values:                                                                   */
      /*    Today           = 2007-01-19                                               */
      /*    CurrYear        = 2007                                                     */
      /*    CurrYear3Digits = 200                                                      */
      /*    CurrYearDay1    = 2007-01-01                                               */
      /*    TempYear        = CurrYear3Digits + BatchYear = 2008                       */
      /*    TempYearDay1    = 2008-01-01                                               */
      /*    TempDate        = TempYearDay1 + 60 - 1 days = 2008-02-29                  */
      /* If TempDate > Today then CurrYear3Digits = 200 - 1 = 199                      */
      /*    ManufYear       = CurrYear3Digits + BatchYear = 1998                       */
      /* Check if ManufYear a leap year                                                */
      /*    ManufYearDay1   = 1998-01-01                          */
      /*    ManufDate       = ManufYearDay1 + 60 - 1 days = 1998-03-01                 */
      /*********************************************************************************/

      -- Eg. Today = 2007-01-19
      SELECT @dt_Today = CONVERT( DATETIME, CONVERT( NVARCHAR(8), GetDate(), 112)) 
      SELECT @nCurrYear = DATEPART( Year, @dt_Today)  -- 2007
      SELECT @nCurrYear3Digits = LEFT( @nCurrYear,3) -- 200
      SELECT @dt_CurrYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @nCurrYear) + '0101'), 112) -- 2007-01-01

      -- Assume TempYear as 200+8 = 2008
      SET @nTempYear = CAST( CONVERT( NVARCHAR(3), @nCurrYear3Digits) + CONVERT( NVARCHAR(1), @nBatchYear) AS INT)
      SELECT @dt_TempYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @nTempYear) + '0101'), 112)
      SELECT @dt_TempDate = DATEADD( Day, @nDaysInYear - 1, @dt_TempYearDay1)

      -- Eg. Today = 2007-01-19, TempDate = 2008-03-01
      IF DATEDIFF( Day, @dt_TempDate, @dt_Today) < 0
      BEGIN
         SET @nCurrYear3Digits = @nCurrYear3Digits - 1  -- 200 - 1 = 199
      END

      -- Form manufacturing year
      SET @nManufYear = CAST( CONVERT( NVARCHAR(3), @nCurrYear3Digits) + CONVERT( NVARCHAR(1), @nBatchYear) AS INT)

      -- Check if ManufYear is leap year
      SET @cIsLeapYear = 'N'
      IF (@nManufYear % 4 = 0) AND (@nManufYear % 100 = 0) AND (@nManufYear % 400 = 0) 
         SET @cIsLeapYear = 'Y'
      ELSE IF (@nManufYear % 4 = 0) AND (@nManufYear % 100 <> 0) AND (@nManufYear % 400 <> 0)
         SET @cIsLeapYear = 'Y'
      ELSE
         SET @cIsLeapYear = 'N'  

      IF @cIsLeapYear = 'Y' AND @nDaysInYear > 366
      BEGIN
         SET @nErrNo = 142004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'DaysInYear >366'
         GOTO QUIT
      END
      ELSE IF @cIsLeapYear = 'N' AND @nDaysInYear > 365
      BEGIN
         SET @nErrNo = 142005         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --'DaysInYear >365'
         GOTO QUIT
      END

      SELECT @nShelflife = Shelflife   
      FROM SKU (NOLOCK)  
      WHERE Storerkey = @cStorerKey
      AND   SKU = @cSKU  

      -- Form manufacturing date 
      SELECT @dt_ManufYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @nManufYear) + '0101'), 112)
      SELECT @dt_ManufDate = DATEADD( Day, @nDaysInYear - 1, @dt_ManufYearDay1)

      SET @cLottable02 = @cLottable02Value

      IF @bDebug = 1
         SELECT @dt_ManufDate
  
      SELECT @cLottable03 = CONVERT( NVARCHAR(8), @dt_ManufDate, 112)

      -- Get Lottable04 
      SELECT @dLottable04 = @dt_ManufDate + @nShelflife

      IF @bDebug = 1
      BEGIN
         SELECT '@cLottable03', @cLottable03
         SELECT '@dLottable04', @dLottable04
      END         
   END

   Quit:

END

GO