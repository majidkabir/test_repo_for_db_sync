SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_NARS                                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-11-2015  Ung       1.0   SOS356691 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_NARS]
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
   SET @cDayCode = SUBSTRING( @cLottableValue, 2, 1)
   SET @cMonthCode = SUBSTRING( @cLottableValue, 3, 1)

   /*
      Month char:    Year char:     Day char:
      A = 01 Jan     8 = 2008       A = 01   K = 11   U = 21
      B = 02 :       9 = 2009       B = 02   L = 12   V = 22
      C = 03 :       0 = 2010       C = 03   M = 13   W = 23
      D = 04 :       1 = 2011       D = 04   N = 14   X = 24
      E = 05         2 = 2012       E = 05   O = 15   Y = 25
      F = 06         3 = 2013       F = 06   P = 16   Z = 26
      G = 07         4 = 2014       G = 07   Q = 17   2 = 27
      H = 08         5 = 2015       H = 08   R = 18   3 = 28
      I = 09         6 = 2016       I = 09   S = 19   4 = 29
      J = 10                        J = 10   T = 20   5 = 30
      K = 11                                          6 = 31
      L = 12 Dec       
   */

   -- Get day
   SELECT @cDay = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'NARS-DAY'
      AND Code2 = @cDayCode
      AND StorerKey = @cStorerKey

   -- Get month
   SELECT @cMonth = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'NARS-MONTH'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'NARS-YEAR'
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