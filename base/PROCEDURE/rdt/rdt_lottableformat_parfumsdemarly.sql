SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_ParfumsDeMarly                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_ParfumsDeMarly] (
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
   DECLARE @nWeekOfYear INT
   DECLARE @dDate       DATETIME

   IF LEN( @cLottable) < 6
   BEGIN
      SET @nErrNo = 182351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   SELECT @cYearCode = Short
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDECode'
      AND Code = 'PDM'
      AND Code2 = LEFT( @cLottable, 1)

   SET @nWeekOfYear = CAST( SUBSTRING( @cLottable, 2, 2) AS INT)

   SET @dDate = CONVERT( DATETIME, '01/01/' + @cYearCode, 103)    -- Convert to first day of year. 103=DD/MM/YYYY
   SET @dDate = DATEADD( wk, @nWeekOfYear-1, @dDate)              -- Move date to that week
   IF @nWeekOfYear > 1
      SET @dDate = DATEADD( d, 2-DATEPART( dw, @dDate), @dDate)   -- Move to Monday of that week (need @@DATEFIRST = 7)
   
   SET @cLottable = CONVERT( NVARCHAR( 10), @dDate, 103)

Quit:

END

GO