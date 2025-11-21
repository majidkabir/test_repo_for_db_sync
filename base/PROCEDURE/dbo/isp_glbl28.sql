SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL28                                          */
/* Creation Date: 15-Dec-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15874 - FJ02 Generate SSCC LabelNo                      */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters: @c_SSCC_Barcode - SSCC barcode number             */
/*                                                                      */
/* Usage: Call from isp_GenSSCCLabel_Wrapper                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL28] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_SSCC_LabelNo NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_debug              INT       
         , @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)

   DECLARE @c_Label_PreFix       NVARCHAR(2)  
         , @c_Label_Company      NVARCHAR(10)
         , @c_Label_SeqNo        NVARCHAR(9)  
         , @c_Label_CheckDigit   NVARCHAR(1) 
         , @c_Userdefine05       NVARCHAR(10)

   DECLARE @n_SumOdd             INT
         , @n_SumEven            INT
         , @n_SumAll             INT
         , @n_Pos                INT
         , @n_Num                INT
         , @n_Try                INT

   SET @b_debug            = 0
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''

   SET @c_Label_PreFix     = '1'                
   SET @c_Label_Company    = '84741778' 
   SET @c_Label_SeqNo      = ''
   SET @c_Label_CheckDigit = ''
   SET @c_SSCC_LabelNo     = ''

   SET @n_SumOdd  = 0
   SET @n_SumEven = 0
   SET @n_SumAll  = 0
   SET @n_Pos     = 1
   SET @n_Num     = 0
   SET @n_Try     = 0

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
      'SSCCLabelNo_FJ02',
      8,
      @c_Label_SeqNo OUTPUT,
      @b_Success     OUTPUT,
      @n_err         OUTPUT,
      @c_errmsg      OUTPUT

   --SET @c_Label_SeqNo = '12345678'
   SET @c_Label_SeqNo = RIGHT(REPLICATE('0',8) + @c_Label_SeqNo, 8)
   
   IF @b_debug = 1
   BEGIN
      SELECT @c_Label_SeqNo '@c_Label_SeqNo'
   END 

   -- Step 1
   SET @c_SSCC_LabelNo  = @c_Label_Prefix + @c_Label_Company + @c_Label_SeqNo + @c_Label_CheckDigit

   -- Step 2
   WHILE @n_Pos <= LEN(@c_SSCC_LabelNo)
   BEGIN
      SET @n_Num = SUBSTRING(@c_SSCC_LabelNo, @n_Pos, 1)

      IF @n_Pos % 2 = 0
      BEGIN
         SET @n_SumEven = @n_SumEven + @n_Num
      END
      ELSE
      BEGIN
         SET @n_SumOdd = @n_SumOdd + @n_Num
      END
      SET @n_Pos = @n_Pos + 1
   END

   -- Step 3
   SET @n_SumAll = (@n_SumOdd * 3) + @n_SumEven

   IF @b_debug = 1
   BEGIN
      SELECT @n_SumEven '@n_SumEven', @n_SumOdd '@n_SumOdd', @n_SumAll '@n_SumAll'
   END

   -- Step 4
   SET @c_Label_CheckDigit = CONVERT(NVARCHAR(1),(1000 - @n_SumAll) % 10)

   SET @c_SSCC_LabelNo  = RTRIM(@c_SSCC_LabelNo) + @c_Label_CheckDigit
   
   IF @b_debug = 1   
   BEGIN
      SELECT @c_Label_CheckDigit '@c_Label_CheckDigit', @c_SSCC_LabelNo '@c_SSCC_Label' 
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL28"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO