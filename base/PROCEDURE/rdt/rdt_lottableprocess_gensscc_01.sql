SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_LottableProcess_GenSSCC_01                                                     */
/* Copyright      : LF Logistics                                                                       */
/*                                                                                                     */
/* Purpose: Generate DGE SSCC code and store in Lottable03                                             */
/*                                                                                                     */
/* Calucuation of Check Digit                                                                          */
/* ==========================                                                                          */
/* Eg. SSCCLabelNo = 00093139381000000041                                                              */
/* The last digit is a check digit and is calculated using the following formula:                      */
/* The check digit is only based on pos 3 - 19. eg. 09313938100000004                                  */
/* Step 1 : (Sum all odd pos.) x 3 eg. 14 x 3 = 42                                                     */
/* Step 2 : Sum all even pos. eg. 27                                                                   */
/* Step 3 : Step 1 + Step 2 eg. 42 + 27 = 69                                                           */
/* Step 4 : Find the smallest number that added to the result of Step 3 will make it a multiple of 10. */
/*                                                                                                     */
/*                                                                                                     */
/* Date         Author    Ver.  Purposes                                                               */
/* 03-Feb-2016  James     1.0   SOS362979 Created                                                      */
/*******************************************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenSSCC_01]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cPartial_SSCC          NVARCHAR( 17),
      @cExtension_digit       NVARCHAR( 1),
      @cCompanyCode           NVARCHAR( 7),
      @cFixscal_Year          NVARCHAR( 2),
      @cPrinterID             NVARCHAR( 1),
      @b_debug                int,
      @b_success              INT,
      @n_err                  INT,
      @c_errmsg               NVARCHAR( 20)

   DECLARE 
      @cRunningNum  NVARCHAR( 9),
      @nSumOdd      int,
      @nSumEven     int,
      @nSumAll      int,
      @nPos         int,
      @nNum         int,
      @nTry         int,
      @cChkDigit    NVARCHAR( 1)

   EXECUTE dbo.nspg_GetKey
      'DGESSCCLblNo',
      6,
      @cRunningNum	OUTPUT,
      @b_success		OUTPUT,
      @n_err			OUTPUT,
      @c_errmsg		OUTPUT

   SET @cExtension_digit = '0'
   SET @cCompanyCode = '5010408'
   SET @cFixscal_Year = ( YEAR( GETDATE() ) % 100 )
   SET @cPrinterID = '1'
   set @cPartial_SSCC = @cExtension_digit + @cCompanyCode + @cFixscal_Year + @cPrinterID + @cRunningNum

   SET @nSumOdd  = 0
   SET @nSumEven = 0
   SET @nSumAll  = 0
   SET @nPos = 1

   WHILE @nPos <= 17
   BEGIN
      SET @nNum = SUBSTRING(@cPartial_SSCC, @nPos, 1)

      IF @nPos % 2 = 0
         SET @nSumEven = @nSumEven + @nNum
      ELSE
         SET @nSumOdd = @nSumOdd + @nNum

      SET @nPos = @nPos + 1
   END

   -- Step 3
   SELECT @nSumAll = (@nSumOdd * 3) + @nSumEven

   IF @b_debug = 1
      SELECT @nSumEven '@nSumEven', @nSumOdd '@nSumOdd', @nSumAll '@nSumAll'

   -- Step 4
   SET @nTry = 0
   WHILE @nTry <= 9
   BEGIN
      IF (@nSumAll + @nTry) % 10 = 0 
      BEGIN
         SET @cChkDigit = CAST( @nTry as NVARCHAR(1))
         BREAK
      END
      SET @nTry = @nTry + 1
   END

   SET @cLottable03 = @cPartial_SSCC + @cChkDigit

Fail:

END

GO