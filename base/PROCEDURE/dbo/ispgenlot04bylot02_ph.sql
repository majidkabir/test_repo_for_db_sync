SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispGenLot04ByLot02_PH                                       */
/* Creation Date: 22-AUG-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-01-16  Wan01    1.1   WMS-3671 - GreenCross Lottable04 AutoCompute*/
/************************************************************************/
CREATE PROC [dbo].[ispGenLot04ByLot02_PH] 
     @c_Storerkey          NVARCHAR(15)  
   , @c_Sku                NVARCHAR(20)  
   , @c_Lottable01Value    NVARCHAR(18)  
   , @c_Lottable02Value    NVARCHAR(18)  
   , @c_Lottable03Value    NVARCHAR(18)  
   , @dt_Lottable04Value   DATETIME  
   , @dt_Lottable05Value   DATETIME  
   , @c_Lottable06Value    NVARCHAR(30)   = ''  
   , @c_Lottable07Value    NVARCHAR(30)   = ''  
   , @c_Lottable08Value    NVARCHAR(30)   = ''  
   , @c_Lottable09Value    NVARCHAR(30)   = ''  
   , @c_Lottable10Value    NVARCHAR(30)   = ''  
   , @c_Lottable11Value    NVARCHAR(30)   = ''  
   , @c_Lottable12Value    NVARCHAR(30)   = ''  
   , @dt_Lottable13Value   DATETIME       = NULL  
   , @dt_Lottable14Value   DATETIME       = NULL  
   , @dt_Lottable15Value   DATETIME       = NULL  
   , @c_Lottable01         NVARCHAR(18)            OUTPUT  
   , @c_Lottable02         NVARCHAR(18)            OUTPUT  
   , @c_Lottable03         NVARCHAR(18)            OUTPUT  
   , @dt_Lottable04        DATETIME                OUTPUT  
   , @dt_Lottable05        DATETIME                OUTPUT  
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT  
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT  
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT  
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT  
   , @b_Success            int            = 1      OUTPUT  
   , @n_Err                int            = 0      OUTPUT  
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT  
   , @c_Sourcekey          NVARCHAR(15)   = ''    
   , @c_Sourcetype         NVARCHAR(20)   = ''     
   , @c_LottableLabel      NVARCHAR(20)   = ''   
   , @c_type               NVARCHAR(10)   = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_ProdDate        NVARCHAR(10)

         , @c_ExpDate         NVARCHAR(10)      --(Wan02)
         , @c_lot04Label      NVARCHAR(20)      --(Wan01)
         

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_lot04Label = ''
   SELECT @c_lot04Label = ISNULL(RTRIM(Lottable04Label),'')
               FROM SKU WITH (NOLOCK)
               WHERE Storerkey = @c_Storerkey
               AND   Sku = @c_Sku

   IF @c_lot04Label = 'PRODN_DATE'
   BEGIN
      SET @c_ProdDate = LEFT(@c_Lottable02Value,6) 

      SET @c_ProdDate = STUFF(@c_ProdDate,3,0,'/') 

      SET @c_ProdDate = STUFF(@c_ProdDate,6,0,'/') 
  
      IF IsDate(@c_ProdDate)= 1 
      BEGIN
         SET @dt_Lottable04 = CONVERT(datetime, @c_ProdDate)

         IF @dt_Lottable04 > GETDATE()
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 61020
            SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) 
                          + '. Cannot convert Lottable02 to date value or date is'
                          + ' more than the current date. (ispGenLot04ByLot02_PH)'
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61000
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + '. Cannot Convert Lottable02 to date value. (ispGenLot04ByLot02_PH)'
         GOTO QUIT_SP
      END
   END

   IF @c_lot04Label = 'EXP_DATE'
   BEGIN
      SET @c_ExpDate = LEFT(@c_Lottable02Value,6) 

      SET @c_ExpDate = STUFF(@c_ExpDate,3,0,'/') 

      SET @c_ExpDate = STUFF(@c_ExpDate,6,0,'/') 
  
      IF IsDate(@c_ExpDate)= 1 
      BEGIN
         SET @dt_Lottable04 = CONVERT(datetime, @c_ExpDate)

         IF @dt_Lottable04 < GETDATE()
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 61030
            SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) 
                          + '. Cannot convert Lottable02 to date value or date is'
                          + ' less than the current date. (ispGenLot04ByLot02_PH)'
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61040
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + '. Cannot Convert Lottable02 to date value. (ispGenLot04ByLot02_PH)'
         GOTO QUIT_SP
      END
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispGenLot04ByLot02_PH'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
   END
END -- procedure

GO