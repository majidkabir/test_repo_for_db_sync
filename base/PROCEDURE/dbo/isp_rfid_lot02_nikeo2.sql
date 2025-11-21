SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_RFID_Lot02_NIKEO2                               */  
/* Creation Date: 2020-12-02                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 02-DEC-2020 Wan      1.0   Created                                    */ 
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_RFID_Lot02_NIKEO2] 
   @c_Storerkey         NVARCHAR(15)  
,  @c_Sku               NVARCHAR(20)  
,  @c_Lottable01Value   NVARCHAR(18)  
,  @c_Lottable02Value   NVARCHAR(18)  
,  @c_Lottable03Value   NVARCHAR(18)  
,  @dt_Lottable04Value  DATETIME  
,  @dt_Lottable05Value  DATETIME 
,  @c_Lottable06Value   NVARCHAR(30)  
,  @c_Lottable07Value   NVARCHAR(30)  
,  @c_Lottable08Value   NVARCHAR(30) 
,  @c_Lottable09Value   NVARCHAR(30)  
,  @c_Lottable10Value   NVARCHAR(30)         
,  @c_Lottable11Value   NVARCHAR(30)  
,  @c_Lottable12Value   NVARCHAR(30)  
,  @dt_Lottable13Value  DATETIME    
,  @dt_Lottable14Value  DATETIME 
,  @dt_Lottable15Value  DATETIME 
,  @c_LottableLabel     NVARCHAR(20)   = ''     
,  @c_Lottable01        NVARCHAR(18)   = ''     OUTPUT
,  @c_Lottable02        NVARCHAR(18)   = ''     OUTPUT
,  @c_Lottable03        NVARCHAR(18)   = ''     OUTPUT
,  @dt_Lottable04       DATETIME       = NULL   OUTPUT
,  @dt_Lottable05       DATETIME       = NULL   OUTPUT
,  @c_Lottable06        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable07        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable08        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable09        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable10        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable11        NVARCHAR(30)   = ''     OUTPUT
,  @c_Lottable12        NVARCHAR(30)   = ''     OUTPUT
,  @dt_Lottable13       DATETIME       = NULL   OUTPUT
,  @dt_Lottable14       DATETIME       = NULL   OUTPUT
,  @dt_Lottable15       DATETIME       = NULL   OUTPUT
,  @b_Success           INT            = 1      OUTPUT   
,  @n_Err               INT            = 0      OUTPUT
,  @c_Errmsg            NVARCHAR(255)  = ''     OUTPUT
,  @c_Sourcekey         NVARCHAR(15)   = ''  
,  @c_Sourcetype        NVARCHAR(20)   = ''
,  @c_Type              NVARCHAR(20)   = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT
         
   IF @c_Sourcetype <> 'TRADERETURN'
   BEGIN
   	GOTO QUIT_SP
   END

   IF @c_Lottable01Value IN ('B', 'C') AND  ISNULL(@c_Lottable02Value,'') <> ''
   BEGIN
      IF NOT EXISTS( SELECT 1   
                     FROM CodeLKUP WITH (NOLOCK)   
                     WHERE ListName = 'O2reason'   
                     AND Code = @c_Lottable02Value  
                     AND StorerKey = @c_StorerKey
                     )  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err = 80610
         SET @c_Errmsg = 'Invalid Lottable02: ' + RTRIM(@c_Lottable02Value) + '. (isp_RFID_Lot02_NIKEO2)'
         GOTO QUIT_SP  
      END  
   END  
 
   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_Lot02_NIKEO2'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END     
END  

GO