SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenMfdExpDate                                           */
/* Creation Date: 23-DEC-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#232724 Pfizer - Auto Calculate Manufacturer Date        */
/*                              (Lottable01) & Expiry Date (lottable04) */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                      */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-Apr-2013  NJOW01    1.0   269605-Add lottable label MFD2L4EXP2 as */
/*                              date format YYYY-MM-DD                  */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenMfdExpDate]            
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
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug              INT

   DECLARE @c_Lottable01Label    NVARCHAR(20)   
         , @c_Lottable02Label    NVARCHAR(20)   
         , @c_Lottable03Label    NVARCHAR(20)   
         , @c_Lottable04Label    NVARCHAR(20)   
         , @n_ShelfLife          INT


   SET @b_success          = 1
   SET @n_Err              = 0
   SET @b_debug            = 0

   SET @c_Lottable01Label  = ''
   SET @c_Lottable02Label  = ''
   SET @c_Lottable03Label  = ''
   SET @c_Lottable04Label  = ''
   SET @n_ShelfLife        = 0

   IF @c_LottableLabel NOT IN('MFD2L4EXP','MFD2L4EXP2','EXP2L1MFD') --NJOW01
   BEGIN 
      GOTO QUIT
   END

   IF @c_LottableLabel IN('MFD2L4EXP','MFD2L4EXP2')  --NJOW01
   BEGIN 
      IF RTRIM(@c_Lottable01Value) = ''
      BEGIN
         SET @n_Err = 30001
         SET @c_Errmsg = CONVERT (Char(5), @n_Err) + '. Manufacturing Date is empty. (ispGenMfdExpDate)' 
         GOTO QUIT
      END

      IF ISDATE(@c_Lottable01Value) = 0 
      BEGIN
         SET @n_Err = 30002
         SET @c_Errmsg = CONVERT (Char(5), @n_Err) + '. Invalid Manufacturing Date: '+  RTRIM(@c_Lottable01Value) + '. (ispGenMfdExpDate)'    
         GOTO QUIT
      END
   END

   IF @c_LottableLabel = 'EXP2L1MFD' AND (@dt_Lottable04Value = '' OR @dt_Lottable04Value IS NULL OR @dt_Lottable04Value = '1900/01/01')
   BEGIN
      SET @n_Err = 30003
      SET @c_Errmsg = CONVERT (Char(5), @n_Err) + '. Expiry Date is empty. (ispGenMfdExpDate)' 
      GOTO QUIT
   END
  
   SELECT  @c_Lottable01Label = RTRIM(SKU.Lottable01Label)
         , @c_Lottable04Label = RTRIM(SKU.Lottable04Label) 
         , @n_ShelfLife       = ISNULL(SKU.ShelfLife,0)
   FROM SKU SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = RTRIM(@c_Storerkey)
   AND   SKU.SKU = RTRIM(@c_Sku)

   IF @b_debug = 1
   BEGIN
      SELECT 'Lottable01Label', @c_Lottable01Label
      SELECT 'Lottable04Label', @c_Lottable04Label
   END

   IF @c_Lottable01Label NOT IN('MFD2L4EXP','MFD2L4EXP2') --NJOW01
   BEGIN
      SET @n_Err = 30002
      SET @c_Errmsg = CONVERT (Char(5), @n_Err) + '. Invalid Lottable01 Label: '+  RTRIM(@c_Lottable01Label) + '. (ispGenMfdExpDate)'    
      GOTO QUIT
   END

   IF @c_Lottable04Label <> 'EXP2L1MFD' 
   BEGIN
      SET @n_Err = 30004
      SET @c_Errmsg = CONVERT (Char(5), @n_Err) + '. Invalid Lottable04 Label: '+  RTRIM(@c_Lottable01) + '. (ispGenMfdExpDate)'    
      GOTO QUIT
   END

   IF @c_LottableLabel IN('MFD2L4EXP','MFD2L4EXP2')
   BEGIN 
      SET @dt_Lottable04= DATEADD(day, @n_ShelfLife, CONVERT(DATETIME, @c_Lottable01Value))  
   END

   IF @c_LottableLabel = 'EXP2L1MFD' AND @c_Lottable01Label = 'MFD2L4EXP'
   BEGIN
      SET @c_Lottable01 = CONVERT(NVARCHAR(10), DATEADD(day, (-1 * @n_ShelfLife), @dt_Lottable04Value),112)       
   END   
   
   IF @c_LottableLabel = 'EXP2L1MFD' AND @c_Lottable01Label = 'MFD2L4EXP2'  --NJOW01
   BEGIN
      SET @c_Lottable01 = CONVERT(NVARCHAR(10), DATEADD(day, (-1 * @n_ShelfLife), @dt_Lottable04Value),121)     
   END   

   QUIT:
   
   IF @b_debug = 1
   BEGIN
      select CONVERT(NVARCHAR(10), getdate(),102)
      SELECT '@c_Errmsg', @c_Errmsg
   END

END -- End Procedure

GO