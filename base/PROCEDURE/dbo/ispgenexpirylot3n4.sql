SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispGenExpiryLot3n4                                         */
/* Creation Date: 27-Dec-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  SOS#199987 Generate Receiptdetail Lottable03 & 04          */
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
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenExpiryLot3n4]
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
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_SKUShelfLife INT

   DECLARE @n_continue     INT

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0
   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @n_SKUShelfLife = ISNULL(ShelfLife,0)
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   SKU = @c_Sku
       
      IF @n_SKUShelfLife = 0
      BEGIN
         SET @n_Err = 30000
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Sku Shelf Life Not Define.  SKU='+ RTrim(@c_Sku) +' (ispGenExpiryLot3n4)'    
         GOTO QUIT
      END         

      IF @c_LottableLabel = 'MFGLOT3' OR @c_LottableLabel = 'EXPLOT4'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_Err = 30001
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' SKU.Lottable03Label is not MFGLOT3 or SKU.Lottable04Label is not EXPLOT4.  SKU='+ RTrim(@c_Sku) +' (ispGenExpiryLot3n4)'    
         GOTO QUIT
      END         
       
      IF @c_Lottablelabel = 'MFGLOT3'
      BEGIN
         IF ISNULL(@c_Lottable03Value,'') = '' --PRE
         BEGIN
            IF @dt_Lottable04Value IS NOT NULL 
            BEGIN
               SET @c_Lottable03 = CONVERT(char(8),(@dt_Lottable04Value - @n_SKUShelfLife),112) 
            END
         END
         ELSE
         BEGIN  --POST
            IF ISDATE(@c_Lottable03Value) <> 1  
            BEGIN
               SET @n_Err = 30002
               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Lottable03 Not DateFormat YYYYMMDD. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryLot3n4)'    
               GOTO QUIT
            END   
            
            SELECT @dt_Lottable04 = DATEADD(Day, @n_SKUShelfLife , @c_Lottable03Value)
         END
      END
      
      IF @c_Lottablelabel = 'EXPLOT4'
      BEGIN
         IF @dt_Lottable04Value IS NULL  --PRE
         BEGIN
            IF ISNULL(@c_Lottable03Value,'') <> '' AND ISDATE(@c_Lottable03Value) = 1
            BEGIN
               SET @dt_Lottable04 = DATEADD(Day, @n_SKUShelfLife, @c_Lottable03Value)
            END
         END
         ELSE
         BEGIN  --POST
            SET @c_Lottable03 = CONVERT(char(8),(@dt_Lottable04Value - @n_SKUShelfLife),112) 
         END
      END                 
   END

QUIT:

END -- End Procedure


GO