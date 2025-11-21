SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispReturnGetReceiveDate_FEFO                                     */
/* Creation Date: 27-Aug-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: FKLIM                                                    */
/*                                                                      */
/* Purpose:  - Get oldest date in the system with the same lot01, lot02,*/
/*             lot03, lot04.                                            */
/*           - Is called by ispLottableRule_Wrapper                     */
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
/* 30-Nov-2007  Vicky    Add Sourcekey and Sourcetype as Parameter      */
/*                       (Vicky01)                                      */
/* 02-Jun-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispReturnGetReceiveDate_FEFO]
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
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE @n_continue     INT,
           @b_debug        INT

   DECLARE 
      @c_Lottable04Label   NVARCHAR( 20),
      @c_Lottable05Label   NVARCHAR( 20)

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   SELECT @c_Lottable04Label  = '',
          @c_Lottable05Label  = ''

  IF ISNULL(@dt_Lottable05Value, '') <> '' --retain original Lottable05 value
      GOTO Quit

   IF ISNULL(@dt_Lottable04Value, '') = ''
   BEGIN
     SET @n_continue = 3
--     SET @b_Success = 0
     SET @n_ErrNo = 61333
     SET @c_Errmsg = 'Lottable04 (ExpiryDate) Required.  (ispReturnGetReceiveDate_FEFO)'
   END

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable04Label = dbo.fnc_RTrim(Lottable04Label),
             @c_Lottable05Label = dbo.fnc_RTrim(Lottable05Label)
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = dbo.fnc_RTrim(@c_Storerkey)
      AND   SKU = dbo.fnc_RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@c_Lottable05Label', @c_Lottable05Label
      END

      IF (@c_Lottable04Label = 'EXP_DATE' OR @c_Lottable04Label = 'EXP-DATE') AND @c_Lottable05Label = 'RCP_DATE'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
--         SET @b_Success = 0
         
         IF @c_Lottable04Label <> 'EXP_DATE' AND @c_Lottable04Label <> 'EXP-DATE'
         BEGIN
            SET @n_ErrNo = 61326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispReturnGetReceiveDate_FEFO)'
            GOTO QUIT
         END           
         ELSE IF @c_Lottable05Label <> 'RCP_DATE'
         BEGIN
            SET @n_ErrNo = 61327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable05Label Setup.  (ispReturnGetReceiveDate_FEFO)'
            GOTO QUIT
         END       
         
      END         
   END

   -- Get Lottable03 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      --Get the oldest LOT with QTY
      SELECT @dt_Lottable05 = MIN(Lotattribute.Lottable05)
      FROM Lotattribute Lotattribute WITH (NOLOCK)
         JOIN LOTXLOCXID LLI WITH (NOLOCK) 
         ON Lotattribute.Lot = LLI.Lot AND Lotattribute.Storerkey = LLI.Storerkey AND Lotattribute.Sku = LLI.Sku
      WHERE Lotattribute.Sku = @c_Sku
         AND Lotattribute.Storerkey = @c_Storerkey
         AND Lotattribute.Lottable01 = @c_Lottable01Value
         AND Lotattribute.Lottable02 = @c_Lottable02Value
         AND Lotattribute.Lottable03 = @c_Lottable03Value
         AND CONVERT(CHAR(8), Lotattribute.Lottable04) = CONVERT(CHAR(8), @dt_Lottable04Value)
         AND Lotattribute.Lottable06 = @c_Lottable06Value
         AND Lotattribute.Lottable07 = @c_Lottable07Value
         AND Lotattribute.Lottable08 = @c_Lottable08Value
         AND Lotattribute.Lottable09 = @c_Lottable09Value
         AND Lotattribute.Lottable10 = @c_Lottable10Value
         AND Lotattribute.Lottable11 = @c_Lottable11Value
         AND Lotattribute.Lottable12 = @c_Lottable12Value
         AND CONVERT(CHAR(8), Lotattribute.Lottable13) = CONVERT(CHAR(8), @dt_Lottable13Value)
         AND CONVERT(CHAR(8), Lotattribute.Lottable14) = CONVERT(CHAR(8), @dt_Lottable14Value)
         AND CONVERT(CHAR(8), Lotattribute.Lottable15) = CONVERT(CHAR(8), @dt_Lottable15Value)
         AND LLI.Qty > 0

      --If such LOT not exist, get the most recent received LOT
      IF ISNULL(@dt_Lottable05,'') = ''
      BEGIN
         SELECT @dt_Lottable05 = MAX(Lotattribute.Lottable05)
         FROM Lotattribute Lotattribute WITH (NOLOCK)
         WHERE Lotattribute.Sku = @c_Sku
            AND Lotattribute.Storerkey = @c_Storerkey
            AND Lotattribute.Lottable01 = @c_Lottable01Value
            AND Lotattribute.Lottable02 = @c_Lottable02Value
            AND Lotattribute.Lottable03 = @c_Lottable03Value
            AND CONVERT(CHAR(8), Lotattribute.Lottable04) = CONVERT(CHAR(8), @dt_Lottable04Value)
            AND Lotattribute.Lottable06 = @c_Lottable06Value
            AND Lotattribute.Lottable07 = @c_Lottable07Value
            AND Lotattribute.Lottable08 = @c_Lottable08Value
            AND Lotattribute.Lottable09 = @c_Lottable09Value
            AND Lotattribute.Lottable10 = @c_Lottable10Value
            AND Lotattribute.Lottable11 = @c_Lottable11Value
            AND Lotattribute.Lottable12 = @c_Lottable12Value
            AND CONVERT(CHAR(8), Lotattribute.Lottable13) = CONVERT(CHAR(8), @dt_Lottable13Value)
            AND CONVERT(CHAR(8), Lotattribute.Lottable14) = CONVERT(CHAR(8), @dt_Lottable14Value)
            AND CONVERT(CHAR(8), Lotattribute.Lottable15) = CONVERT(CHAR(8), @dt_Lottable15Value)
      END
      ELSE
         GOTO Quit

      --If such LOT not exist, return today╞s date
      IF ISNULL(@dt_Lottable05,'') = ''
         SET @dt_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), getdate(), 106))

  END

QUIT:
END -- End Procedure


GO