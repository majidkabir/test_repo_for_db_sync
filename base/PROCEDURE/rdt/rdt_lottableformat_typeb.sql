SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_TypeB                                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_TypeB]
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
      SET @cYearCode = SUBSTRING( @cLottableValue, 4, 1)
      SET @cDayCode = SUBSTRING( @cLottableValue, 3, 1)
   END
   ELSE IF LEN( @cLottableValue) = 4
   BEGIN
      SET @cMonthCode = SUBSTRING( @cLottableValue, 1, 1)
      SET @cYearCode = SUBSTRING( @cLottableValue, 3, 1)
      SET @cDayCode = SUBSTRING( @cLottableValue, 2, 1)
   END
   
   /*
      Month char:    Year char:     Day char:
      A = 01 Jan     H = 2001       A = 01   K = 11   U = 21
      C = 02 :       J = 2002       B = 02   L = 12   V = 22
      E = 03 :       L = 2003       C = 03   M = 13   W = 23
      G = 04 :       N = 2004       D = 04   N = 14   X = 24
      I = 05         P = 2005       E = 05   O = 15   Y = 25
      K = 06         R = 2006       F = 06   P = 16   Z = 26
      M = 07         T = 2007       G = 07   Q = 17   2 = 27
      O = 08         X = 2008       H = 08   R = 18   3 = 28
      S = 09         Z = 2009       I = 09   S = 19   4 = 29
      W = 10         A = 2010       J = 10   T = 20   5 = 30
      Y = 11         C = 2011                         6 = 31
      Z = 12 Dec     E = 2012  
                     G = 2013  
                     I = 2014  
                     K = 2015  
                     M = 2016  
                     O = 2017
   */

   -- Get day
   SELECT @cDay = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEB-DAY'
      AND Code2 = @cDayCode
      AND StorerKey = @cStorerKey

   -- Get month
   SELECT @cMonth = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEB-MONTH'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'TYPEB-YEAR'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   -- Generate date
   SET @cLottable = @cDay + '/' + @cMonth +  '/' + @cYear
   
   -- Check date valid
   IF rdt.rdtIsValidDate( @cLottable) = 0
      SET @cLottable = ''

Quit:

END

GO