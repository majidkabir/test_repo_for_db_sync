SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Houbigant                        */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-13 1.0  Ung        WMS-23316 Created                         */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_Houbigant](
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
   DECLARE @cJulianDate NVARCHAR(7)
   DECLARE @nLength     INT
   DECLARE @nYear       INT

   SET @nLength = LEN( @cLottable)

   IF @nLength <> 8
   BEGIN
      SET @nErrNo = 205851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   SELECT @cYearCode = Short
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDECode'
      AND Code = 'HBY'
      AND Code2 = LEFT( @cLottable, 2)

   SET @nYear = CAST (@cYearCode AS INT)

   IF ((@nYear % 4 = 0 AND @nYear % 100 <> 0) OR @nYear % 400 = 0)
   BEGIN
      IF (CAST(SUBSTRING(@cLottable, 5, 3) AS INT) > 366 or CAST(SUBSTRING(@cLottable, 5, 3) AS INT) = 0)
      BEGIN
         SET @nErrNo = 205852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      IF (CAST(SUBSTRING(@cLottable, 5, 3) AS INT) > 365 or CAST(SUBSTRING(@cLottable, 5, 3) AS INT) = 0)
      BEGIN
         SET @nErrNo = 205853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END

   SET @cJulianDate = @cYearCode + SUBSTRING( @cLottable, 5, 3)
   SET @cLottable = CONVERT(NVARCHAR,(DATEADD(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, DATEADD(yy, @cJulianDate/1000 - 1900, 0)) ),103)

Quit:

END

GO