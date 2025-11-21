SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ReceiptDetail_Lottable02PreRule_Std             */  
/* Creation Date: 08-DEC-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-2410 - UAT  Philippines  PH SCE No Prompt For Entering  */
/*          Expired Stocks                                               */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-12-08  Wan      1.0   Created                                    */
/* 2021-01-15  Wan01    1.1   Adding Outer Begin Try/Catch               */
/*************************************************************************/   
CREATE PROC [WM].[lsp_ReceiptDetail_Lottable02PreRule_Std] (
        @c_Listname              NVARCHAR(10)
      , @c_Storerkey             NVARCHAR(15)
      , @c_Sku                   NVARCHAR(20)
      , @c_LottableLabel         NVARCHAR(20)   = ''      
      , @c_Lottable01Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable02Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable03Value       NVARCHAR(60)   = ''     OUTPUT
      , @dt_Lottable04Value      DATETIME       = ''     OUTPUT
      , @dt_Lottable05Value      DATETIME       = ''     OUTPUT
      , @c_Lottable06Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable07Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable08Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable09Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable10Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable11Value       NVARCHAR(60)   = ''     OUTPUT
      , @c_Lottable12Value       NVARCHAR(60)   = ''     OUTPUT
      , @dt_Lottable13Value      DATETIME       = NULL   OUTPUT
      , @dt_Lottable14Value      DATETIME       = NULL   OUTPUT
      , @dt_Lottable15Value      DATETIME       = NULL   OUTPUT
      , @c_Lottable01            NVARCHAR(18)   = ''     OUTPUT
      , @c_Lottable02            NVARCHAR(18)   = ''     OUTPUT
      , @c_Lottable03            NVARCHAR(18)   = ''     OUTPUT
      , @dt_Lottable04           DATETIME       = ''     OUTPUT
      , @dt_Lottable05           DATETIME       = ''     OUTPUT
      , @c_Lottable06            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable07            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable08            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable09            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable10            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable11            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable12            NVARCHAR(30)   = ''     OUTPUT
      , @dt_Lottable13           DATETIME       = NULL   OUTPUT
      , @dt_Lottable14           DATETIME       = NULL   OUTPUT
      , @dt_Lottable15           DATETIME       = NULL   OUTPUT
      , @b_Success               int            = 1      OUTPUT
      , @n_Err                   int            = 0      OUTPUT
      , @c_Errmsg                NVARCHAR(250)  = ''     OUTPUT
      , @c_Sourcekey             NVARCHAR(15)   = '' 
      , @c_Sourcetype            NVARCHAR(20)   = '' 
      , @c_type                  NVARCHAR(10)   = ''
      , @n_WarningNo             INT            = 0      OUTPUT
) AS 
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_WarningNo_Orig  INT = 0 
         , @n_Cnt             INT = 0
         , @n_MinShelfLife    INT = 0

         , @c_Facility        NVARCHAR(5) = ''
         , @c_Receiptkey      NVARCHAR(18)= ''
         , @c_BatchNo         NVARCHAR(18)= ''

         , @d_BatchNo         DATETIME
         , @dt_ReceiptDate    DATETIME    = GETDATE()     

         , @c_UTLITF          NVARCHAR(30)= ''

   SET @c_Receiptkey = LEFT(@c_Sourcekey,10)

   BEGIN TRY      --(Wan01) - START
      IF @c_LottableLabel = 'BATCHNO' AND @n_WarningNo = 0 
      BEGIN
         SELECT TOP 1 @c_Facility = Facility
         FROM RECEIPT WITH (NOLOCK) 
         WHERE Receiptkey = @c_Receiptkey

         SELECT @c_UTLITF = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'UTLITF')

         SET @n_MinShelfLife = 0

         IF @c_UTLITF = '1' 
         BEGIN
            SELECT @n_MinShelfLife = ISNULL(ShelfLife,0) 
		      FROM   SKU WITH (NOLOCK)
		      WHERE  STORERKEY = @c_StorerKey
		      AND    SKU = @c_SKU

            SET @c_BatchNo = LEFT(@c_Lottable02Value,8)

            IF ISDATE(@c_BatchNo) = 0
            BEGIN
               SET @n_Continue = 3
            END

            IF @n_Continue IN (1,2)
            BEGIN
               SET @d_BatchNo = @c_BatchNo

               IF DATEADD(DAY, @n_MinShelfLife, @d_BatchNo) <= @dt_ReceiptDate
               BEGIN
                  SET @n_Continue = 3
               END
               ELSE
               BEGIN
                  SET @dt_Lottable04Value = @d_BatchNo
                  SET @dt_Lottable04 = @d_BatchNo
               END 
            END
           
            IF @n_Continue = 3
            BEGIN
               SET @n_Err = 559151 
               SET @c_errmsg = 'Invalid Expiry Date. (lsp_ReceiptDetail_Lottable02PreRule_Std)'
               GOTO EXIT_SP
            END          
         END 
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_errmsg   = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH      --(Wan01) - END
   
   EXIT_SP:
   
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      SET @n_WarningNo = 0 
   END
   ELSE
   BEGIN
      SET @b_Success = 1   
   END
END -- Procedure

GO