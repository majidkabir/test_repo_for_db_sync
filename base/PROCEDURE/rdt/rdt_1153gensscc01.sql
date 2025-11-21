SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_1153GenSSCC01                                                                  */
/* Copyright      : LF Logistics                                                                       */
/*                                                                                                     */
/* Purpose: Generate DGE SSCC code and store in Lottable03                                             */
/*                                                                                                     */
/* Called from rdt_Vap_Palletize_Confirm                                                               */
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

CREATE PROCEDURE [RDT].[rdt_1153GenSSCC01]
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),  
   @cStorerkey       NVARCHAR( 15), 
   @cToID            NVARCHAR( 18),
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @cLottable06      NVARCHAR( 30), 
   @cLottable07      NVARCHAR( 40), 
   @cLottable08      NVARCHAR( 50), 
   @cLottable09      NVARCHAR( 60), 
   @cLottable10      NVARCHAR( 30), 
   @cLottable11      NVARCHAR( 30), 
   @cLottable12      NVARCHAR( 30), 
   @dLottable13      DATETIME, 
   @dLottable14      DATETIME, 
   @dLottable15      DATETIME, 
   @cSSCC            NVARCHAR( 20) OUTPUT,
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
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

   SET @cSSCC = @cPartial_SSCC + @cChkDigit

Fail:

END

GO