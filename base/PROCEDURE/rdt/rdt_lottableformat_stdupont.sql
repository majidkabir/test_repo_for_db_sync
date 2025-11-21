SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_STDupont                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_STDupont](
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
   
   DECLARE @cYearCode      NVARCHAR( 1)
   DECLARE @cDayMonthCode  NVARCHAR( 3)
   DECLARE @cYear          NVARCHAR( 4)
   DECLARE @cJulianDate    NVARCHAR( 7)

   IF (LEN(@cLottable)!=9)
   BEGIN
      SET @nErrNo = 58311
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   SET @cYearCode = SUBSTRING( @cLottable, 6, 1)
   SET @cDayMonthCode = SUBSTRING( @cLottable, 7, 3)

   IF @cYearCode NOT BETWEEN 'A' AND 'Z'
   BEGIN
      SET @nErrNo = 58312
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   SELECT  @cYear = LEFT( Short, 4)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'S.T DUPONT'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   SET @cJulianDate = @cYear + @cDayMonthCode

   IF ((@cYear % 4 = 0 AND @cYear % 100 <> 0) OR @cYear % 400 = 0)
   BEGIN
      IF (CAST(@cDayMonthCode AS INT) > 366 or CAST(@cDayMonthCode AS INT) = 0)
      BEGIN
         SET @nErrNo = 58313
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      IF (CAST(@cDayMonthCode AS INT) > 365 or CAST(@cDayMonthCode AS INT) = 0)
      BEGIN
         SET @nErrNo = 58314
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END

   SET @cLottable = convert(varchar,(dateadd(dd, (@cJulianDate - ((@cJulianDate/1000) * 1000)) - 1, dateadd(yy, @cJulianDate/1000 - 1900, 0)) ),103)

Quit:

END

GO