SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GenSSCCLabelNo               		               */
/* Creation Date: 08-Feb-2007                                    			*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                   					*/
/*                                                                      */
/* Purpose:  Pacific Brands - Generate SSCC Label (SOS68117)		      */
/*           Note: Related to isp_Print_SSCC_CartonLabel                */
/*                                                                      */
/* Input Parameters:  @cPickSlipNo - Pickslipno, @nCartonNo - CartonNo	*/
/*                                                                      */
/* Output Parameters: @cSSCC_Barcode - SSCC barcode number              */
/*                                                                      */
/* Usage: Call from PB object nep_w_packing_maintenance (New Carton)    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GenSSCCLabelNo] ( 
   @cPickSlipNo   NVARCHAR(10), 
   @nCartonNo     int,
   @cSSCC_Barcode NVARCHAR(20) output )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_starttcnt   int,
      @n_continue    int, 
      @b_success		int,
      @n_err			int,
      @c_errmsg	 NVARCHAR( 255),
      @b_debug       int

   DECLARE 
      @cPrefix_SSCC_Label     NVARCHAR( 12),
      @cPrefix_SSCC_Barcode   NVARCHAR( 10),
      @cPartial_SSCC          NVARCHAR( 17),
      @cSSCC_Label            NVARCHAR( 22)

   DECLARE 
      @cRunningNum  NVARCHAR( 9),
      @nSumOdd      int,
      @nSumEven     int,
      @nSumAll      int,
      @nPos         int,
      @nNum         int,
      @nTry         int,
      @cChkDigit    NVARCHAR( 1)

   SET @n_starttcnt = @@TRANCOUNT
   SET @n_continue = 1
   SET @b_success	= 0
   SET @n_err = 0
   SET @c_errmsg	= ''
   SET @b_debug = 0

   SET @cPrefix_SSCC_Label = ''
   SET @cPrefix_SSCC_Barcode = ''
   SET @cPartial_SSCC = ''
   SET @cSSCC_Label = ''
   SET @cSSCC_Barcode = ''

   /*******************************************************************************************************/
   /* Calucuation of Check Digit                                                                          */
   /* ==========================                                                                          */
   /* Eg. SSCCLabelNo = 00093139381000000041                                                              */
	/* The last digit is a check digit and is calculated using the following formula:                      */
	/* The check digit is only based on pos 3 - 19. eg. 09313938100000004                                  */
	/* Step 1 : (Sum all odd pos.) x 3 eg. 14 x 3 = 42                                                     */
	/* Step 2 : Sum all even pos. eg. 27                                                                   */
	/* Step 3 : Step 1 + Step 2 eg. 42 + 27 = 69                                                           */
	/* Step 4 : Find the smallest number that added to the result of Step 3 will make it a multiple of 10. */
   /*******************************************************************************************************/

   -- Form SSCC Label
   -- Get running number
   EXECUTE dbo.nspg_GetKey
      'SSCCLabelNo',
      9,
      @cRunningNum	OUTPUT,
      @b_success		OUTPUT,
      @n_err			OUTPUT,
      @c_errmsg		OUTPUT

   SET @cPrefix_SSCC_Label = '(00)09313938'
   SET @cPrefix_SSCC_Barcode = '0009313938' -- exclude brackets
   SET @cPartial_SSCC = SUBSTRING(@cPrefix_SSCC_Barcode + @cRunningNum, 3, 17)
   
   IF @b_debug = 1
      SELECT @cPartial_SSCC '@cPartial_SSCC'

   -- Step 1 & 2
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
   
   SET @cSSCC_Label   = @cPrefix_SSCC_Label + @cRunningNum + @cChkDigit
   SET @cSSCC_Barcode = @cPrefix_SSCC_Barcode + @cRunningNum + @cChkDigit
   
   IF @b_debug = 1   
      SELECT @cSSCC_Label '@cSSCC_Label', @cSSCC_Barcode '@cSSCC_Barcode'

   BEGIN TRAN
   UPDATE PACKDETAIL WITH (ROWLOCK)
   SET LabelNo = @cSSCC_Barcode
   WHERE PickSlipNo = @cPickSlipNo
   AND   CartonNo = @nCartonNo
   AND   LabelNo = '' OR LabelNo IS NULL
   
   IF @@error <> 0
      SET @n_continue=3

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GenSSCCLabelNo"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO