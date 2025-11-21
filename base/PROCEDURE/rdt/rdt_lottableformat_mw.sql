SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_MW                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_MW](
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
   
   DECLARE @cYearCode   NVARCHAR( 4)
   DECLARE @cMonthCode  NVARCHAR( 2)
   DECLARE @cYear       NVARCHAR( 4)
   DECLARE @cMonth      NVARCHAR( 2)
   DECLARE @cDay        INT
   DECLARE @cWeek       INT  
   DECLARE @cJulianDate NVARCHAR( 7)
   DECLARE @cDayMonthCode NVARCHAR( 5)

   IF (LEN(@cLottable)NOT BETWEEN 4 AND 7)
   BEGIN
      SET @nErrNo = 182651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   IF (LEN(@cLottable) in (4,6,7))
   BEGIN
      IF ISNUMERIC(SUBSTRING(@cLottable,1,1))<>1
      BEGIN
         SET @nErrNo = 182652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
         GOTO Quit
      END

      SET @cYearCode =(SUBSTRING(@cLottable,4,1))

      SET @cWeek = (SUBSTRING(@cLottable,2,2))

      SET @cDayMonthCode = (@cWeek-1)*7+(SUBSTRING(@cLottable,1,1))

      SET @cDay=SUBSTRING(@cLottable,1,1)

   END
   ELSE IF (LEN(@cLottable) in (5))
   BEGIN
      IF ISNUMERIC(SUBSTRING(@cLottable,1,1))<>1
      BEGIN
         SET @cYearCode =(SUBSTRING(@cLottable,5,1))

         SET @cWeek = (SUBSTRING(@cLottable,3,2))

         SET @cDayMonthCode = ((@cWeek-1)*7) + (SUBSTRING(@cLottable,2,1))-1

         SET @cDay=SUBSTRING(@cLottable,2,1)
      END

      ELSE
      BEGIN
         SET @cYearCode =(SUBSTRING(@cLottable,4,1))

         SET @cWeek = (SUBSTRING(@cLottable,2,2))

         SET @cDayMonthCode = (@cWeek-1)*7+(SUBSTRING(@cLottable,1,1))

         SET @cDay=SUBSTRING(@cLottable,1,1)
      END
   END

   SELECT  @cYear = LEFT( Short, 4)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'MW'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   IF LEN(@cDayMonthCode) = 2
      SET @cDayMonthCode='0'+@cDayMonthCode

   SET @cJulianDate = @cYear + @cDayMonthCode

   IF ((@cYear % 4 = 0 AND @cYear % 100 <> 0) OR @cYear % 400 = 0)
   BEGIN
      IF (CAST(@cDayMonthCode AS INT) > 366 or CAST(@cDayMonthCode AS INT) = 0)
      BEGIN
         SET @nErrNo = 182653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      IF (CAST(@cDayMonthCode AS INT) > 365 or CAST(@cDayMonthCode AS INT) = 0)
      BEGIN
         SET @nErrNo = 182654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Day
         GOTO Quit
      END
   END

   SET @cLottable = rdt.rdtformatdate( dateadd (week, @cWeek, dateadd (year, @cYear-1900, 0))            
                                    -4-datepart(dw, dateadd (week, @cWeek, dateadd (year, @cYear-1900, 0)) - 4) + 1            
                                    +@cDay) 

Quit:

END

GO