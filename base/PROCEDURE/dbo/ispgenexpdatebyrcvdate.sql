SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispGenExpDateByRcvDate                                     */
/* Creation Date: 04-Jun-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable04 By Lottable05            */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13-Jul-2009  Vanessa   1.1   SOS#136260 Remove time stamp in the     */
/*                              expiry date    (Vanessa01)              */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenExpDateByRcvDate]
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
      @c_Lottable04Label   NVARCHAR(20),
      @c_Lottable05Label   NVARCHAR(20)

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL,
          @c_Lottable06  = '',
          @c_Lottable07  = '',
          @c_Lottable08  = '',
          @c_Lottable09  = '',
          @c_Lottable10  = '',
          @c_Lottable11  = '',
          @c_Lottable12  = '',
          @dt_Lottable13 = NULL,
          @dt_Lottable14 = NULL,
          @dt_Lottable15 = NULL

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable04Label = RTrim(Lottable04Label),
             @c_Lottable05Label = RTrim(Lottable05Label)
      FROM SKU (NOLOCK)
      WHERE Storerkey = RTrim(@c_Storerkey)
      AND   SKU = RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@c_Lottable05Label', @c_Lottable05Label
      END

      IF ISNULL(RTrim(@c_Lottable04Label),'') = 'GenExpDateByRcvDate' AND ISNULL(RTrim(@c_Lottable05Label),'') = 'RCP_DATE'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
         SET @b_Success = 0
         
         SET @n_Err = 30001
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' SKU=' + RTrim(@c_Sku) 
                     + ' SKU.Lottable04Label=' + RTrim(@c_Lottable04Label) + ' and' 
                     + ' SKU.Lottable05Label=' + RTrim(@c_Lottable05Label) 
                     + ' is not GenExpDateByRcvDate or RCP_DATE. Lottable04 is not auto calculated. Please key in manually for Lottable04 or Lottable05! (ispGenExpDateByRcvDate)' 

         IF @b_debug = 1
         BEGIN
            SELECT '@c_Errmsg', @c_Errmsg
         END

         GOTO QUIT
      END         
   END

   -- Get Lottable04 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @dt_Lottable05 = Convert(Varchar(8),GetDate(),112) -- (Vanessa01)
      SELECT @dt_Lottable04 = DATEADD(Year, 3, @dt_Lottable05)


      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable05', @dt_Lottable05
         SELECT '@dt_Lottable04', @dt_Lottable04
      END
   END
      
QUIT:

END -- End Procedure


GO