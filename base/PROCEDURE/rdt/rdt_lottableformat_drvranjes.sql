SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_DrVranjes                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_DrVranjes](
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
BEGIN TRY
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(4)
   DECLARE @cMonthCode  NVARCHAR(2)
   DECLARE @cJulianDate NVARCHAR(7) = ''
   DECLARE @nLength     INT

   SET @nLength = LEN( @cLottable)

   IF @nLength NOT IN (4, 6, 7, 8, 10)
   BEGIN
      SET @nErrNo = 182401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   IF @nLength = 4
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'DRVAY'
         AND Code2 = LEFT( @cLottable, 1)

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
   END

   ELSE IF @nLength = 6
   BEGIN
      IF LEFT( @cLottable, 1) LIKE '[A-Za-z]' --Alpha
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'DRVAY'
            AND Code2 = SUBSTRING( @cLottable, 3, 1)

         SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 4, 3)
         SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
      END

      ELSE IF LEFT( @cLottable, 1) LIKE '[0-9]' --Numeric
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'DRVBY'
            AND Code2 = SUBSTRING( @cLottable, 5, 2)

         SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 1, 3)
         SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
      END
   END

   ELSE IF @nLength = 7
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'DRVCY'
         AND Code2 = SUBSTRING( @cLottable, 3, 1)

      SET @cLottable =
         SUBSTRING( @cLottable, 1, 1) + SUBSTRING( @cLottable, 5, 1) + '/' +
         SUBSTRING( @cLottable, 2, 1) + SUBSTRING( @cLottable, 4, 1) + '/' +
         @cYearCode
   END

   ELSE IF @nLength = 8
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'DRVAY'
         AND Code2 = LEFT( @cLottable, 1)

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
   END

   ELSE IF @nLength = 10
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'DRVAY'
         AND Code2 = SUBSTRING( @cLottable, 3, 1)

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 4, 3)
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
            SET @nErrNo = 182402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            SET @cLottable = ''
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF (CAST(SUBSTRING(@cJulianDate,5,3) AS INT) > 365 or CAST(SUBSTRING(@cJulianDate,5,3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 182403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            SET @cLottable = ''
            GOTO Quit
         END
      END
   END

END TRY
BEGIN CATCH
   SET @cLottable = ''
END CATCH

Quit:


GO