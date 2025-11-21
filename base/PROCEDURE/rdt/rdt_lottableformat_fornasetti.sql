SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Fornasetti                       */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-13 1.0  Ung        WMS-22607 Created                         */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_Fornasetti](
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
   DECLARE @nLength     INT
   DECLARE @nWeekOfYear INT
   DECLARE @nDayOfYear  INT
   DECLARE @nYear       INT
   DECLARE @dDate       DATE

   SET @nLength = LEN( @cLottable)

   IF @nLength NOT IN (7, 4)
   BEGIN
      SET @nErrNo = 205901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   -- Group A logic
   IF @nLength = 7
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'FNAY'
         AND Code2 = SUBSTRING( @cLottable, 5, 1)

      SET @nYear = CAST (@cYearCode AS INT)
      SET @nWeekOfYear = CAST( SUBSTRING( @cLottable, 6, 2) AS INT)

      SET @dDate = CONVERT( DATETIME, '01/01/' + @cYearCode, 103)    -- Convert to first day of year. 103=DD/MM/YYYY
      SET @dDate = DATEADD( wk, @nWeekOfYear-1, @dDate)              -- Move date to that week

      SET @cLottable = CONVERT( NVARCHAR( 10), @dDate, 103)
   END

   -- Group B logic
   IF @nLength = 4 
   BEGIN
      SELECT @cYearCode = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTDECode'
         AND Code = 'FNBY'
         AND Code2 = SUBSTRING( @cLottable, 4, 1)

      SET @nDayOfYear = LEFT( @cLottable, 3)
      
      SET @dDate = CONVERT( DATETIME, '01/01/' + @cYearCode, 103)    -- Convert to first day of year. 103=DD/MM/YYYY
      SET @dDate = DATEADD( dd, @nDayOfYear-1, @dDate)               -- Move date to day of year

      SET @cLottable = CONVERT( NVARCHAR( 10), @dDate, 103)
   END

Quit:

END

GO