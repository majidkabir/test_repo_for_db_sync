SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Byredo                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-06-20 1.0  YeeKung    WMS-16535 Created                         */
/* 2022-02-14 1.1  Ung        WMS-18866 Replace with new logic          */
/*                            Original logic moved to Nautica brand     */
/* 2022-06-21 1.2  Ung        WMS-19994 Add len = 4, 6 to group D logic */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_BYREDO](
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
   DECLARE @cMonthCode  NVARCHAR(2)
   DECLARE @cJulianDate NVARCHAR(7) = ''
   DECLARE @nLength     INT

   SET @nLength = LEN( @cLottable)

   IF @nLength NOT IN (3, 4, 5, 6, 9, 10)
   BEGIN
      SET @nErrNo = 182451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   IF @nLength = 3
   BEGIN
      IF SUBSTRING( @cLottable, 2, 1) LIKE '[A-Za-z]' --Alpha
      BEGIN
         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'BYREDOAM'
            AND Code2 = SUBSTRING( @cLottable, 2, 1)
            
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'BYREDOAY'
            AND Code2 = SUBSTRING( @cLottable, 3, 1)

         SET @cLottable = '01' + '/' + @cMonthCode + '/' + @cYearCode
      END
   
      ELSE IF SUBSTRING( @cLottable, 2, 1) LIKE '[0-9]' --Numeric
      BEGIN
         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'BYREDOBM'
            AND Code2 = SUBSTRING( @cLottable, 3, 1)

         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'BYREDOBY'
            AND Code2 = LEFT( @cLottable, 2)

         SET @cLottable = '01' + '/' + @cMonthCode + '/' + @cYearCode
      END
   END
   
   ELSE IF @nLength = 5
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'BYREDOCY'
         AND Code2 = SUBSTRING( @cLottable, 5, 1)

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)  
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)      
   END

   ELSE IF @nLength IN (4, 6, 9, 10)
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'BYREDO'
         AND Code2 = LEFT( @cLottable, 1)

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)  
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)      
   END

   IF @cJulianDate <> ''
   BEGIN
      DECLARE @nYear INT
      SET @nYear = CAST (@cYearCode AS INT)

      IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
      BEGIN
         IF (CAST(SUBSTRING(@cJulianDate,5,3) AS INT) > 366 or CAST(SUBSTRING(@cJulianDate,5,3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 182452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            SET @cLottable = ''
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF (CAST(SUBSTRING(@cJulianDate,5,3) AS INT) > 365 or CAST(SUBSTRING(@cJulianDate,5,3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 182453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            SET @cLottable = ''
            GOTO Quit
         END
      END
   END

Quit:

END

GO