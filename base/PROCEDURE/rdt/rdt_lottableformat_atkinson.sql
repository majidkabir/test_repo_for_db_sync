SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Atkinson                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_Atkinson](
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
   DECLARE @cJulianDate NVARCHAR(7)
   DECLARE @nLength     INT

   SET @nLength = LEN( @cLottable)

   IF @nLength NOT IN (4, 8, 5, 6)
   BEGIN
      SET @nErrNo = 182301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   IF @nLength = 4
   BEGIN
      SELECT @cMonthCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'ATKINSONAM'
         AND Code2 = LEFT( @cLottable, 1)

      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'ATKINSONAY'
         AND Code2 = SUBSTRING( @cLottable, 2, 1)

      SET @cLottable= '01' + '/' + @cMonthCode + '/' + @cYearCode
   END

   ELSE IF @nLength = 8
   BEGIN
      SELECT @cMonthCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'ATKINSONAM'
         AND Code2 = SUBSTRING( @cLottable, 5, 1)

      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'ATKINSONAY'
         AND Code2 = SUBSTRING( @cLottable, 6, 1)

      SET @cLottable = SUBSTRING( @cLottable, 3, 2) +'/' + @cMonthCode +'/' + @cYearCode
   END

   ELSE IF @nLength IN (5, 6)
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'ATKINSONBY'
         AND Code2 = LEFT( @cLottable, 1)

      DECLARE @nYear INT
      SET @nYear = CAST (@cYearCode AS INT)

      IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 2,3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 2,3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 182302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 2,3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 2,3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 182303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 2, 3)
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
   END

Quit:

END

GO