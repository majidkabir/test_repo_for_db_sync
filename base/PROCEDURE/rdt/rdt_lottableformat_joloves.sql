SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_JoLoves                          */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-13 1.0  Ung        WMS-22607 Created                         */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_JoLoves](
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
   DECLARE @nYear       INT

   SET @nLength = LEN( @cLottable)

   IF @nLength NOT IN (10, 3, 4, 5, 6)
   BEGIN
      SET @nErrNo = 202601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   IF @nLength = 10 -- (Group A logic)
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'JLAY'
         AND Code2 = SUBSTRING( @cLottable, 4, 1) + SUBSTRING( @cLottable, 8, 1)

      SET @nYear = CAST (@cYearCode AS INT)

      IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 5, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 5, 3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 202602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF (CAST(SUBSTRING(@cLottable, 5, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 5, 3) AS INT) = 0)
         BEGIN
            SET @nErrNo = 202603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
            GOTO Quit
         END
      END

      SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 5, 3)
      SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
   END

   IF @nLength = 3 -- (Group C logic)
   BEGIN
      SELECT @cMonthCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'JLCM'
         AND Code2 = LEFT( @cLottable, 1)
      
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'JLCY'
         AND Code2 = SUBSTRING( @cLottable, 3, 1)

      SET @cLottable = '01' +'/' + @cMonthCode +'/' + @cYearCode
   END

   IF @nLength = 4
   BEGIN
      -- 1st char is numeric (Group B logic)
      IF TRY_CAST( LEFT( @cLottable, 1) AS INT) IS NOT NULL
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLBY'
            AND Code2 = RIGHT( @cLottable, 1)

         SET @nYear = CAST (@cYearCode AS INT)

         IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 1, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 1, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 202604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 1, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 1, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 202605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END

         SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 1, 3)
         SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
      END
      
      -- 1st char is alphabet (Group C logic)
      ELSE
      BEGIN
         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLCM'
            AND Code2 = LEFT( @cLottable, 1)
         
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLCY'
            AND Code2 = SUBSTRING( @cLottable, 3, 1)

         SET @cLottable = '01' +'/' + @cMonthCode +'/' + @cYearCode
      END
   END

   IF @nLength = 5
   BEGIN
      -- 1st char is numeric (Group D logic)
      IF TRY_CAST( LEFT( @cLottable, 1) AS INT) IS NOT NULL
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLDY'
            AND Code2 = LEFT( @cLottable, 2)

         SET @nYear = CAST (@cYearCode AS INT)

         IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 3, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 3, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 202606
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF (CAST(SUBSTRING(@cLottable, 3, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 3, 3) AS INT) = 0)
            BEGIN
               SET @nErrNo = 202607
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
               GOTO Quit
            END
         END

         SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 3, 3)
         SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)
      END
      
      -- 1st char is alphabet (Group C logic)
      ELSE
      BEGIN
         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLCM'
            AND Code2 = LEFT( @cLottable, 1)
         
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLCY'
            AND Code2 = SUBSTRING( @cLottable, 4, 1)

         SET @cLottable = '01' +'/' + @cMonthCode +'/' + @cYearCode
      END
   END

   ELSE IF @nLength = 6
   BEGIN
      -- 1st char is numeric (Group E logic)
      IF TRY_CAST( LEFT( @cLottable, 1) AS INT) IS NOT NULL
      BEGIN
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLEY'
            AND Code2 = LEFT( @cLottable, 3)

         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLEM'
            AND Code2 = SUBSTRING( @cLottable, 5, 2)

         SET @cLottable = '01' +'/' + @cMonthCode +'/' + @cYearCode
      END
      
      -- 1st char is alphabet (Group F logic)
      ELSE
      BEGIN
         SELECT @cMonthCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLFM'
            AND Code2 = SUBSTRING( @cLottable, 4, 1)
         
         SELECT @cYearCode = Short
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDECode'
            AND Code = 'JLFY'
            AND Code2 = SUBSTRING( @cLottable, 5, 1)

         SET @cLottable = SUBSTRING( @cLottable, 2, 2) +'/' + @cMonthCode +'/' + @cYearCode
      END
   END

Quit:

END

GO