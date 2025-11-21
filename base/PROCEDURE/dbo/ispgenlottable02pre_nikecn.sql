SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP:  ispGenLottable02Pre_NikeCN                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable02 Default Value            */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 02-Jul-2007  Vicky    SOS 96822 Default lottable02 for NIKE          */
/* 30-Nov-2007  Vicky    Add Sourcekey and Sourcetype as Parameter      */
/*                       (Vicky01)                                      */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/* 14-Jan-2015  CSCHONG  Add new input parameter (CS01)                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLottable02Pre_NikeCN]
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
   , @c_Sourcekey          NVARCHAR(15)   = ''     -- (Vicky01)
   , @c_Sourcetype         NVARCHAR(20)   = ''     -- (Vicky01)
   , @c_LottableLabel      NVARCHAR(20)   = ''     -- (Vicky01)
   , @c_type               NVARCHAR(10) = ''     --(CS01)

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   IF @c_Sourcetype = 'RECEIPTFINALIZE'
      RETURN

   SET @c_Lottable01 = 'LOOKUP'
   SET @c_Lottable02 = '01000' ---- For lottable02 = ISEG and POID
   SET @c_Lottable03 = 'LOOKUP'
   
END -- End Procedure



GO