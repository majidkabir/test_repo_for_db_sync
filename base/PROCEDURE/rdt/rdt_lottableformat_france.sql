SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_France                                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/* 09-09-2017  Ung       1.1   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_France]
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

   SET @cYearCode = SUBSTRING( @cLottableValue, 1, 1)
   SET @cMonthCode = SUBSTRING( @cLottableValue, 2, 1)
   -- SET @cDayCode = SUBSTRING( @cLottableValue, 3, 1)
   SET @cDayCode = RIGHT( @cLottableValue, 1)

   /*
      Month char:    Year char:     Day char:
      A = 01 Jan     H = 2001       A = 01   L = 11   W = 21
      C = 02 :       J = 2002       B = 02   M = 12   X = 22
      E = 03 :       K = 2003       C = 03   N = 13   Y = 23
      G = 04 :       L = 2004       D = 04   P = 14   Z = 24
      J = 05         M = 2005       E = 05   Q = 15   2 = 25
      L = 06         N = 2006       F = 06   R = 16   3 = 26
      N = 07         P = 2007       G = 07   S = 17   4 = 27
      Q = 08         Q = 2008       H = 08   T = 18   5 = 28
      S = 09         R = 2009       J = 09   U = 19   6 = 29
      U = 10         S = 2010       K = 10   V = 20   7 = 30
      W = 11         T = 2011                         8 = 31
      Y = 12 Dec     U = 2012  
                     V = 2013  
                     W = 2014  
                     X = 2015  
                     Y = 2016  
                     Z = 2017
   */

   -- Get day
   SELECT @cDay = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'FRANCE-DAY'
      AND Code2 = @cDayCode
      AND StorerKey = @cStorerKey

   -- Get month
   SELECT @cMonth = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'FRANCE-MONTH'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'FRANCE-YEAR'
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