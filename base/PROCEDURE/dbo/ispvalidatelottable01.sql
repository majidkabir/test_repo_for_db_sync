SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispValidateLottable01                                      */
/* Creation Date: 06-Dec-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: Validate Lottable01 value against setup in Codelkup         */
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
/* 30-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispValidateLottable01]
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

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_sValue            NVARCHAR( 1)


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
      IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = RTRIM(@c_LottableLabel)
                 AND Code = RTRIM(@c_Lottable01Value))
      BEGIN
         SELECT @n_continue = 1
         SELECT @b_Success = 1
      END
      ELSE 
      BEGIN
         --SET @b_Success = 1
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), 61351) + ' Invalid Lot1 (ispValidateLottable01)'
      END         
  END

     
QUIT:
END -- End Procedure


GO