SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenExpiryDateLot4                                       */
/* Creation Date: 21-Apr-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable04 By Lottable01            */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 03-Jun-2013  Leong     1.1   SOS# 279443 - Check Date Length.        */
/* 05-AUG-2013  YTWAN     1.2   SOS#284945: Calculate Lot04 from        */
/*                              Userdefine01.(Wan01)                    */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/* 27-AUG-2015  YTWAN     1.4   SOS#351301-TH-CTX auto calucate Lot04   */
/*                              (Wan02)                                 */  
/* 06-MAR-2020  SPChin    1.5   INC1064615 - Add Filter By StorerKey    */ 
/* 04-AUG-2020  Chermaine 1.6   WMS-14523 remark set lottble ='' (cc01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenExpiryDateLot4]
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
   , @c_UserDefineValue    NVARCHAR(30)   = ''     -- (Wan01)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @c_Lottable01Label   NVARCHAR( 20),
      @n_SKUShelfLife      INT
   ,  @c_ColName           NVARCHAR(20)   --(Wan01)  

   ,  @c_SQL               NVARCHAR(4000) --(Wan02)
   ,  @c_SQLArguements     NVARCHAR(4000) --(Wan02)
   ,  @c_Lottable          NVARCHAR(10)   --(Wan02)

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT --@c_Lottable01  = '',    --(cc01)
   --       @c_Lottable02  = '',
   --       @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL,
          --@c_Lottable06 = '',
          --@c_Lottable07 = '',
          --@c_Lottable08 = '',
          --@c_Lottable09 = '',
          --@c_Lottable10 = '',
          --@c_Lottable11 = '',
          --@c_Lottable12 = '',
          @dt_Lottable13 = NULL,
          @dt_Lottable14 = NULL,
          @dt_Lottable15 = NULL

   -- SOS# 279443 (Start)
   DECLARE @c_Year   NVARCHAR(4)
         , @c_Month  NVARCHAR(2)
         , @c_Day    NVARCHAR(2)

   --(Wan01) - START
   SET @c_ColName = ''

   IF ISNULL(RTRIM(@c_UserDefineValue),'')  <> ''  
   BEGIN

      IF ISDATE(@c_UserDefineValue) = 0 OR LEN(@c_UserDefineValue) <> 8
      BEGIN
         SET @n_Err = 30002
         SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + ' Userdefine01 is not a valid DateFormat. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
         GOTO QUIT
      END

      SELECT @n_SKUShelfLife = ISNULL(ShelfLife,0)
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey 
      AND   SKU = @c_Sku

      SET @c_Lottable01Value = @c_UserDefineValue
      GOTO CALC_LOT04
   END
   --(Wan01) - END

   --(Wan02) - START
   SELECT TOP 1 @c_Lottable = ListName                --INC1064615
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName Like 'Lottable%'
   AND   Code    = @c_LottableLabel
   AND   Long    = 'ispGenExpiryDateLot4'
   AND  (Storerkey = @c_Storerkey OR Storerkey = '')  --INC1064615
   Order by Storerkey DESC                            --INC1064615

   IF @c_Lottable = 'Lottable04'
   BEGIN
      GOTO QUIT
   END

   IF @c_Lottable <> 'Lottable01'
   BEGIN 
      SET @c_SQL = N'SET @c_Lottable01Value =  CASE @c_Lottable'
                 + ' WHEN ''Lottable02'' THEN @c_Lottable02Value'
                 + ' WHEN ''Lottable03'' THEN @c_Lottable03Value'
                 + ' WHEN ''Lottable05'' THEN REPLACE(CONVERT(CHAR(10),@dt_Lottable05Value,103),''/'','''')'
                 + ' WHEN ''Lottable06'' THEN @c_Lottable06Value'
                 + ' WHEN ''Lottable07'' THEN @c_Lottable07Value'
                 + ' WHEN ''Lottable08'' THEN @c_Lottable08Value'
                 + ' WHEN ''Lottable09'' THEN @c_Lottable09Value'
                 + ' WHEN ''Lottable10'' THEN @c_Lottable10Value'
                 + ' WHEN ''Lottable11'' THEN @c_Lottable11Value'
                 + ' WHEN ''Lottable12'' THEN @c_Lottable12Value'
                 + ' WHEN ''Lottable13'' THEN REPLACE(CONVERT(CHAR(10),@dt_Lottable13Value,103),''/'','''')'
                 + ' WHEN ''Lottable14'' THEN REPLACE(CONVERT(CHAR(10),@dt_Lottable14Value,103),''/'','''')'
                 + ' WHEN ''Lottable15'' THEN REPLACE(CONVERT(CHAR(10),@dt_Lottable15Value,103),''/'','''')'
                 + ' END'

      SET @c_SQLArguements = N'@c_Lottable01Value  NVARCHAR(18) OUTPUT'
                           + ',@c_Lottable         NVARCHAR(10)' 
                           + ',@c_Lottable02Value  NVARCHAR(18)'   
                           + ',@c_Lottable03Value  NVARCHAR(18)'   
                           + ',@dt_Lottable05Value DATETIME' 
                           + ',@c_Lottable06Value  NVARCHAR(30)'   
                           + ',@c_Lottable07Value  NVARCHAR(30)'
                           + ',@c_Lottable08Value  NVARCHAR(30)'   
                           + ',@c_Lottable09Value  NVARCHAR(30)'  
                           + ',@c_Lottable10Value  NVARCHAR(30)'  
                           + ',@c_Lottable11Value  NVARCHAR(30)'
                           + ',@c_Lottable12Value  NVARCHAR(30)'
                           + ',@dt_Lottable13Value DATETIME' 
                           + ',@dt_Lottable14Value DATETIME' 
                           + ',@dt_Lottable15Value DATETIME'  
 
      EXEC sp_ExecuteSql @c_SQL
                       , @c_SQLArguements
                       , @c_Lottable01Value  OUTPUT
                       , @c_Lottable
                       , @c_Lottable02Value    
                       , @c_Lottable03Value     
                       , @dt_Lottable05Value 
                       , @c_Lottable06Value   
                       , @c_Lottable07Value  
                       , @c_Lottable08Value  
                       , @c_Lottable09Value     
                       , @c_Lottable10Value   
                       , @c_Lottable11Value  
                       , @c_Lottable12Value   
                       , @dt_Lottable13Value  
                       , @dt_Lottable14Value  
                       , @dt_Lottable15Value

      --Lottables Date Input format = DDMMYYYY
      SET @c_Lottable01Value = SUBSTRING(@c_Lottable01Value,5,4) + SUBSTRING(@c_Lottable01Value,3,2) + SUBSTRING(@c_Lottable01Value,1,2)

      IF ISDATE(@c_Lottable01Value) = 0 OR LEN(@c_Lottable01Value) <> 8
      BEGIN
         SET @n_Err = 30007
         SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + '.' + @c_Lottable + ' is not a valid DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
         GOTO QUIT
      END

      SELECT @n_SKUShelfLife = ISNULL(ShelfLife,0)
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey 
      AND   SKU = @c_Sku 
      
      GOTO CALC_LOT04
   END
   --(Wan02) - END

   SET @c_Year  = SUBSTRING(@c_Lottable01Value, 5, 4)
   SET @c_Month = SUBSTRING(@c_Lottable01Value, 3, 2)
   SET @c_Day   = SUBSTRING(@c_Lottable01Value, 1, 2)

   IF LEN(ISNULL(RTRIM(@c_Lottable01Value),'')) <> 8
   BEGIN
      SET @n_Err = 30003
      SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + ' Lottable01 Not DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
      GOTO QUIT
   END

   IF LEN(RTRIM(@c_Year)) <> 4
   BEGIN
      SET @n_Err = 30004
      SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + ' Lottable01 Not DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
      GOTO QUIT
   END

   IF LEN(RTRIM(@c_Month)) <> 2
   BEGIN
      SET @n_Err = 30005
      SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + ' Lottable01 Not DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
      GOTO QUIT
   END

   IF LEN(RTRIM(@c_Day)) <> 2
   BEGIN
      SET @n_Err = 30006
      SET @c_Errmsg = CONVERT (NVARCHAR(5), @n_Err) + ' Lottable01 Not DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'
      GOTO QUIT
   END
   -- SOS# 279443 (End)

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Lottable01Label = RTrim(Lottable01Label),
             @n_SKUShelfLife    = ISNULL(ShelfLife,0)
      FROM SKU (NOLOCK)
      WHERE Storerkey = RTrim(@c_Storerkey)
      AND   SKU = RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable01Label', @c_Lottable01Label
         SELECT '@n_SKUShelfLife', CONVERT(CHAR(5), @n_SKUShelfLife)
      END

      IF @c_Lottable01Label = 'MFG_DATE' 
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE
      BEGIN
         --SET @n_continue = 3
         --SET @b_Success = 1
         SET @n_Err = 30001
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' SKU.Lottable01Label is not MFG_DATE. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'

         IF @b_debug = 1
         BEGIN
            SELECT '@c_Errmsg', @c_Errmsg
         END

         GOTO QUIT
      END
   END

   --User key in Lottable01 = DDMMYYYY
   SELECT @c_Lottable01Value = SUBSTRING(@c_Lottable01Value, 5, 4) + SUBSTRING(@c_Lottable01Value, 3, 2) + SUBSTRING(@c_Lottable01Value, 1, 2)

   IF ISDATE(@c_Lottable01Value) <> 1
   BEGIN
      SET @n_Err = 30002
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Lottable01 Not DateFormat DDMMYYYY. SKU='+ RTrim(@c_Sku) +' (ispGenExpiryDateLot4)'

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable01Value', @c_Lottable01Value
         SELECT '@c_Errmsg', @c_Errmsg
      END

      GOTO QUIT
   END

   CALC_LOT04:                                              --(Wan01)
   -- Get Lottable04
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      SELECT @dt_Lottable04 = DATEADD(Day, @n_SKUShelfLife, @c_Lottable01Value)

      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable04', @dt_Lottable04
      END
   END

QUIT:

END -- End Procedure

GO