SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ReceiptDetail_Lottable04PreRule_Std             */  
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
CREATE PROC [WM].[lsp_ReceiptDetail_Lottable04PreRule_Std] (
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

         , @n_Cnt             INT = 0
         , @n_MinShelfLife    INT = 0
         , @n_DiffDay         INT = 0
         , @n_MatchLot02      INT = 0

         , @c_WarningMsg      NVARCHAR(255)= ''    
         , @c_Facility        NVARCHAR(5) = ''
         , @c_Receiptkey      NVARCHAR(18)= ''
         , @c_BatchNo         NVARCHAR(10)= ''
         
         , @d_BatchNo         DATE  
         , @d_ExpiryDate      DATE        
         , @dt_ReceiptDate    DATETIME    = GETDATE()     

         , @c_UTLITF          NVARCHAR(30)= ''
         , @c_ManLotExpDate   NVARCHAR(30)= ''

   SET @c_Receiptkey = LEFT(@c_Sourcekey,10)
   
   BEGIN TRY      --(Wan01) - START
      IF @c_LottableLabel = 'EXP_DATE'  
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
         END
         ELSE
         BEGIN
            SELECT @n_MinShelfLife = CASE WHEN ISNUMERIC(SUSR1)= 1 THEN SUSR1 ELSE 0 END 
		      FROM   SKU WITH (NOLOCK)
		      WHERE  STORERKEY = @c_StorerKey
		      AND    SKU = @c_SKU
         END

         SET @d_ExpiryDate = @dt_Lottable04Value

         IF @n_WarningNo = 0
         BEGIN
            IF @n_MinShelfLife = 0 
            BEGIN
               IF @d_ExpiryDate <= @dt_ReceiptDate OR @d_ExpiryDate IS NULL
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 559201 
                  SET @c_errmsg = 'Invalid Expiry Date. (lsp_ReceiptDetail_Lottable04PreRule_Std)'
                  GOTO EXIT_SP
               END
            END

            SET @n_DiffDay = DATEDIFF(DAY, @dt_ReceiptDate, @d_ExpiryDate)

            IF @n_DiffDay < @n_MinShelfLife
            BEGIN
               SET @n_WarningNo = 1
               SET @c_Errmsg = 'Expiry Date is less than a Minimum Shelf Life. Min Shelf days = ' + CONVERT(NVARCHAR(5), @n_MinShelfLife)
                             + ', Expiry Date - Current Date = ' + CONVERT(NVARCHAR(5), @n_DiffDay) + '. Continue?'
               GOTO EXIT_SP
            END
         END

         SELECT @c_ManLotExpDate = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ManLotExpDate')

         IF @c_ManLotExpDate = '1'
         BEGIN
            SET @n_Cnt = 0
      	   SELECT @n_Cnt = 1
		      FROM LOTATTRIBUTE WITH (NOLOCK)
		      WHERE Storerkey= @c_Storerkey
		      AND sku        = @c_Sku
            AND lottable02 = @c_Lottable02Value
		      AND lottable03 = @c_Lottable03Value
		      AND lottable04 = @dt_Lottable04Value

            IF @n_Cnt = 0 
            BEGIN
               SET @n_Cnt        = 0
               SET @n_MatchLot02 = 0

      	      SELECT @n_Cnt        = ISNULL(SUM(CASE WHEN LA.lottable02 Like @c_Lottable02Value + '.%' THEN 1 ELSE 0 END),0)
                  ,   @n_MatchLot02 = ISNULL(MAX(CASE WHEN LA.lottable02 = @c_Lottable02Value THEN 1 ELSE 0 END),0)
		         FROM LOTATTRIBUTE LA WITH (NOLOCK)
		         WHERE LA.Storerkey= @c_Storerkey
		         AND LA.Sku        = @c_Sku
               AND LA.lottable02 Like @c_Lottable02Value + '%'
		         AND LA.lottable03 = @c_Lottable03Value

               IF @n_MatchLot02 = 1 
               BEGIN
                  SET @c_WarningMsg = 'Manufacturer Lot: ' + @c_Lottable02Value + ' exists with different expiry date.'
                  IF @n_Cnt <> 0 
                  BEGIN
                     SET @n_Cnt = @n_Cnt + 1
                     SET @c_Lottable02Value = @c_Lottable02Value + REPLICATE ('.',@n_Cnt)
                     SET @c_Lottable02      = @c_Lottable02Value
                  END
               END
            END
         END

         IF @c_UTLITF = '1' 
         BEGIN
            SET @d_BatchNo = DATEADD(day, (-1 * @n_MinShelfLife), @d_ExpiryDate)
            SET @c_BatchNo = CONVERT(NVARCHAR(8), @d_BatchNo, 112) + 'A'
            SET @c_Lottable02Value = @c_BatchNo
            SET @c_Lottable02      = @c_Lottable02Value
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
      IF @c_WarningMsg <> ''
      BEGIN
         SET @b_Success = 2
         SET @c_Errmsg = @c_WarningMsg
      END
      ELSE
      BEGIN
         SET @b_Success = 1 
      END  
   END
END -- Procedure

GO