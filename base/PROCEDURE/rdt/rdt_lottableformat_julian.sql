SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_Julian                                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_Julian]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cLottableCode    NVARCHAR( 30), 
   @nLottableNo      INT,
   @cFormatSP        NVARCHAR( 50), 
   @cLottableValue   NVARCHAR( 60), 
   @cLottable        NVARCHAR( 60) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode      NVARCHAR(1)
   DECLARE @cDayOfYearCode NVARCHAR(3)
   DECLARE @nDayOfYearCode INT
   DECLARE @dDate DATETIME
   DECLARE @cDate NVARCHAR(10)

   -- Get day of year
   SET @cYearCode = LEFT( @cLottableValue, 1)
   IF @cYearCode NOT BETWEEN '1' AND '9'
   BEGIN
      SET @cLottable = ''
      GOTO Quit
   END

   -- Get day of year
   SET @cDayOfYearCode = SUBSTRING( @cLottableValue, 2, 3)
   IF LEN( @cDayOfYearCode) <> 3
   BEGIN
      SET @cLottable = ''
      GOTO Quit
   END

   -- Check valid day of year
   IF rdt.rdtIsValidQTY( @cDayOfYearCode, 1) = 0
   BEGIN
      SET @cLottable = ''
      GOTO Quit
   END
      
   -- Get leap year
   DECLARE @nLeapYear INT
   IF DAY( EOMONTH( DATEFROMPARTS( '201' + @cYearCode, 2, 1))) = 29
      SET @nLeapYear = 1
   ELSE
      SET @nLeapYear = 0
      
   -- Check valid range
   SET @nDayOfYearCode = CAST( @cDayOfYearCode AS INT)
   IF @nDayOfYearCode NOT BETWEEN 1 AND (365 + @nLeapYear)
   BEGIN
      SET @cLottable = ''
      GOTO Quit
   END
   
   -- Default to 1st day of current year
   SET @cDate = '201' + @cYearCode + '/01/01' 
   SET @dDate = CONVERT( DATETIME, @cDate, 120) --YYYY/MM/DD
   
   -- Add day of year
   SET @nDayOfYearCode = @nDayOfYearCode - 1
   SET @dDate = DATEADD( dd, @nDayOfYearCode, @dDate)

   SET @cLottable = CONVERT( NVARCHAR( 10), @dDate, 103) --DD/MM/YYYY

Quit:

END

GO