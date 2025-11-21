SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGenLot12_TW01                                            */
/* Creation Date: 19-AUG-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  TW-JTI Generate Receiptdetail Lottable01-02                */
/*           By Lottable03-04 refer to Lotattribute (SOS#286821)        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 09-Dec-2013  SPChin   1.1  SOS297467-Add in Sourcetype = 'RECEIPTRET'*/
/* 21-May-2014  TKLIM    1.1   Added Lottables 06-15                    */
/* 01/08/2014   SPChin   1.2  SOS330266-Add in Sourcetype ='TRADERETURN'*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot12_TW01]
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
   , @n_ErrNo              int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''
   , @c_Sourcetype         NVARCHAR(20)   = ''
   , @c_LottableLabel      NVARCHAR(20)   = ''

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lottable01Label    NVARCHAR(20),
           @c_Lottable02Label    NVARCHAR(20),
           @c_Lottable03Label    NVARCHAR(20),
           @c_Lottable04Label    NVARCHAR(20),
           @n_continue           INT,
           @b_debug              INT

   SELECT  @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   SELECT  @c_Lottable01  = '',
           @c_Lottable02  = '',
           @c_Lottable03  = '',
           @dt_Lottable04 = NULL,
           @dt_Lottable05 = NULL

   IF @c_SourceType NOT IN('RECEIPT','RECEIPTFINALIZE','CCOUNT','RDTRECEIPT','RDTCCOUNT','RECEIPTRET','TRADERETURN')   --SOS297467,SOS330266
      GOTO QUIT

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),''),
             @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),''),
             @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),''),
             @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),'')
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   SKU = @c_Sku

      IF @c_Lottable01Label = 'JTISAPCODE' AND @c_Lottable02Label = 'JTIBATCHNO'
         AND @c_Lottable03Label = 'JTICountry' AND @c_Lottable04Label = 'JTIEXPDATE'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE
      BEGIN
         SET @n_continue = 3
--         SET @b_Success = 0

         IF @c_Lottable01Label <> 'JTISAPCODE'
         BEGIN
            SET @n_ErrNo = 31326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable01Label Setup.  (ispGenLot12_TW01)'
         END
         ELSE IF @c_Lottable02Label <> 'JTIBATCHNO'
         BEGIN
            SET @n_ErrNo = 31327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02Label Setup.  (ispGenLot12_TW01)'
         END
         ELSE IF @c_Lottable03Label <> 'JTICountry'
         BEGIN
            SET @n_ErrNo = 31328
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable03Label Setup.  (ispGenLot12_TW01)'
         END
         ELSE IF @c_Lottable04Label <> 'JTIEXPDATE'
         BEGIN
            SET @n_ErrNo = 31329
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispGenLot12_TW01)'
         END
         GOTO QUIT
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
         IF ISNULL(@c_Lottable03Value,'') <> '' AND @c_LottableLabel IN ('JTICountry', 'JTIEXPDATE')
         BEGIN
            SELECT TOP 1 @c_Lottable01 = LOTATTRIBUTE.Lottable01,
                       @c_Lottable02 = LOTATTRIBUTE.Lottable02
          FROM LOTATTRIBUTE(NOLOCK)
          WHERE LOTATTRIBUTE.Storerkey = @c_Storerkey
          AND LOTATTRIBUTE.Sku = @c_Sku
          AND LOTATTRIBUTE.Lottable03 = @c_Lottable03Value
          AND DATEDIFF(Day, LOTATTRIBUTE.Lottable04, @dt_Lottable04Value) = 0
       END
   END

QUIT:
END -- End Procedure

GO