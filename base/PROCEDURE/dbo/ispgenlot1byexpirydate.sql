SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot1ByExpiryDate                                     */
/* Creation Date: 30-Nov-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable01 By Lottable04            */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot1ByExpiryDate]
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
   , @c_Sourcekey          NVARCHAR(15)   = ''     -- (Vicky01)
   , @c_Sourcetype         NVARCHAR(20)   = ''     -- (Vicky01)
   , @c_LottableLabel      NVARCHAR(20)   = ''     -- (Vicky01)

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_Lottable01Label   NVARCHAR( 20),
      @c_Lottable04Label   NVARCHAR( 20)


   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL,
          @c_Lottable06 = '',
          @c_Lottable07 = '',
          @c_Lottable08 = '',
          @c_Lottable09 = '',
          @c_Lottable10 = '',
          @c_Lottable11 = '',
          @c_Lottable12 = '',
          @dt_Lottable13 = NULL,
          @dt_Lottable14 = NULL,
          @dt_Lottable15 = NULL

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable01Label = dbo.fnc_RTrim(Lottable01Label)
      FROM SKU (NOLOCK)
      WHERE Storerkey = dbo.fnc_RTrim(@c_Storerkey)
      AND   SKU = dbo.fnc_RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable01Label', @c_Lottable01Label
      END

      IF @c_Lottable01Label = 'GEN_WEEK'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
         SET @b_Success = 1
      END         
   END

   IF ISDATE(@dt_Lottable04Value) <> 1
   BEGIN
      --SET @b_Success = 0
      SET @n_Err = 61376
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Lottable04 Not DateFormat. (ispGenLot1ByExpiryDate)'    
      GOTO QUIT
   END
      
   -- Get Lottable01 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
     
      SELECT @c_Lottable01 = CONVERT(Char(4), (DATEPART(year, @dt_Lottable04Value))) + 
                             RIGHT('0' + dbo.fnc_RTrim(CONVERT(Char(2), (DATEPART(ww, @dt_Lottable04Value)))), 2)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable01', @c_Lottable01
      END
   END
      
QUIT:
END -- End Procedure


GO