SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_MichaelKors                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-09-02 1.0  Ung        WMS-23316 Created                         */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_MichaelKors](
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cFormatSP        NVARCHAR( 20)
   ,@cLottableValue   NVARCHAR( 20)
   ,@cLottable        NVARCHAR( 30) OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(4)
   DECLARE @cMonthCode  NVARCHAR(3)
   DECLARE @cDayCode    NVARCHAR(2)
   DECLARE @cJulianDate NVARCHAR(7)
   DECLARE @nLength     INT
   DECLARE @nYear       INT
   DECLARE @nWeekOfYear INT
   DECLARE @nDayOfWeek  INT
   DECLARE @dDate       DATETIME
   DECLARE @cSKUGroup   NVARCHAR(10)

   SET @nLength = LEN( @cLottable)

   -- Get SKU info
   SELECT @cSKUGroup = @cSKUGroup FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   -- Non sample
   IF @cSKUGroup <> 'SAMP'
   BEGIN
      -- Group A logic
      IF @nLength BETWEEN 5 AND 9 AND
         LEFT( @cLottable, 1) LIKE '[0-9]' AND  -- Numeric
         RIGHT( @cLottable, 1) LIKE '[A-Za-z]'  -- Alphabet
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'MKAY'
            AND Code2 = LEFT( @cLottable, 1)
         
         SET @nYear = CAST (@cYearCode AS INT)

         IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 2, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 2, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 205751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 2, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 2, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 205752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END

         SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)
         SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
      END
      
      -- Group B logic
      ELSE IF @nLength IN (4, 6) AND
         LEFT( @cLottable, 2) LIKE '[A-Za-z][A-Za-z]' -- Alphabet
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'MKBY'
            AND Code2 = SUBSTRING( @cLottable, 3, 2)
                  
         SELECT 
            @cDayCode = UDF01, 
            @cMonthCode = UDF02 
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'MKDM'
            AND Code2 = SUBSTRING( @cLottable, 1, 2)
            
         -- Format month Jan, Feb... to 1, 2...
         SET @cMonthCode = ISNULL( FORMAT( TRY_CONVERT( DATE, @cMonthCode + ' 01, 1900'), 'MM'), '')
      
         SET @cLottable = @cDayCode +'/' + @cMonthCode +'/' + @cYearCode
      END
      
      -- Group C logic
      ELSE IF @nLength = 8
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'MKCY'
            AND Code2 = SUBSTRING( @cLottable, 4, 2)

         SET @nWeekOfYear = CAST( SUBSTRING( @cLottable, 6, 2) AS INT)
         SET @nDayOfWeek = CAST( SUBSTRING( @cLottable, 1, 8) AS INT)   -- 1=Mon, 2=Tue, 3=Wed... Sun=7 
         
         -- Convert to 2=Mon, 3=Tue, 4=Wed... Sun=1, under @@DATEFIRST = 7
         SET @nDayOfWeek += 1                                           
         IF @nDayOfWeek = 8 
            SET @nDayOfWeek = 1

         SET @dDate = CONVERT( DATETIME, '01/01/' + @cYearCode, 103)    -- Convert to first day of year. 103=DD/MM/YYYY
         SET @dDate = DATEADD( wk, @nWeekOfYear-1, @dDate)              -- Move date to that week
         
         -- Move to day of that week
         WHILE DATEPART( dw, @dDate) <> @nDayOfWeek
            SET @dDate = DATEADD( d, 1, @dDate)
         
         SET @cLottable = CONVERT( NVARCHAR( 10), @dDate, 103)
      END
      
      ELSE
      BEGIN
         SET @nErrNo = 205753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
         GOTO Quit
      END
      
   END

   -- Sample
   ELSE IF @cSKUGroup = 'SAMP'
   BEGIN
      -- Group X logic
      IF @nLength NOT BETWEEN 6 AND 9
      BEGIN
         SET @nErrNo = 205754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
         GOTO Quit
      END
      
      -- Group X logic
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'MKXY'
         AND Code2 = LEFT( @cLottable, 2)

      SET @nYear = CAST (@cYearCode AS INT)

      IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 3, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 3, 3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 205755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 3, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 3, 3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 205756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 3, 3)
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
   END

Quit:

END

GO