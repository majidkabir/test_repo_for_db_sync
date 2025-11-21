SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_TypeA                                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_TypeA]
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

   DECLARE @cYearCode   NVARCHAR(1)
   DECLARE @cMonthCode  NVARCHAR(1)
   DECLARE @cDayCode    NVARCHAR(1)
   
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cDay        NVARCHAR(2)
   
   IF LEN( @cLottableValue) = 5
   BEGIN
      -- 1st char must be numeric
      IF rdt.rdtIsValidQTY( LEFT( @cLottableValue, 1), 0) = 0
      BEGIN
         SET @cLottable = ''
         GOTO Quit
      END

      SET @cMonthCode = SUBSTRING( @cLottableValue, 2, 1)
      SET @cYearCode = SUBSTRING( @cLottableValue, 3, 1)
      SET @cDayCode = SUBSTRING( @cLottableValue, 5, 1)
   END
   ELSE IF LEN( @cLottableValue) = 4
   BEGIN
      SET @cMonthCode = SUBSTRING( @cLottableValue, 1, 1)
      SET @cYearCode = SUBSTRING( @cLottableValue, 2, 1)
      SET @cDayCode = SUBSTRING( @cLottableValue, 4, 1)
   END
   ELSE IF LEN( @cLottableValue) = 3
   BEGIN
      SET @cMonthCode = SUBSTRING( @cLottableValue, 1, 1)
      SET @cYearCode = SUBSTRING( @cLottableValue, 2, 1)
      SET @cDayCode = 'A'
   END      
       
   /*
      Month char:    Year char:     Day char:
      T = 01 Jan     D = 2002       A = 01   K = 11   U = 21
      V = 02 :       F = 2003       B = 02   L = 12   V = 22
      X = 03 :       H = 2004       C = 03   M = 13   W = 23
      B = 04 :       J = 2005       D = 04   N = 14   X = 24
      D = 05         L = 2006       E = 05   O = 15   Y = 25
      F = 06         N = 2007       F = 06   P = 16   Z = 26
      H = 07         P = 2008       G = 07   Q = 17   2 = 27
      J = 08         R = 2009       H = 08   R = 18   3 = 28
      L = 09         T = 2010       I = 09   S = 19   4 = 29
      N = 10         X = 2011       J = 10   T = 20   5 = 30
      P = 11         Z = 2012                         6 = 31
      R = 12 Dec     A = 2013  
                     C = 2014  
                     E = 2015  
                     G = 2016  
                     I = 2017  
   */

   -- Get day
   SELECT @cDay = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEA-DAY'
      AND Code2 = @cDayCode
      AND StorerKey = @cStorerKey

   -- Get month
   SELECT @cMonth = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEA-MONTH'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEA-YEAR'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   -- Generate date
   SET @cLottable = @cDay + '/' + @cMonth +  '/' + @cYear

   -- Check date valid
   IF rdt.rdtIsValidDate( @cLottable) = 0
   BEGIN
      SET @cLottable = ''
      GOTO Quit
   END
   
   -- Add 365 days if JAN or FEB or MAR
   IF @cMonth IN ('01', '02', '03')
   BEGIN
      DECLARE @dDate DATETIME
      SET @dDate = CONVERT( DATETIME, @cLottable, 103) -- DD/MM/YYYY
      SET @dDate = DATEADD( dd, 365, @dDate)
      SET @cLottable = CONVERT( NVARCHAR( 60), @dDate, 103) -- DD/MM/YYYY
   END

Quit:

END

GO