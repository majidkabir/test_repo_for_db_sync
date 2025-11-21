SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot3Lot4ByJulianDate                                 */
/* Creation Date: 22-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable03 & Lottable04             */
/*           By JulianDate in Lottable02                                */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 10-Oct-2006  Shong    Remove Time for @dt_ActualDate                 */
/* 19-Jan-2007  MaryVong Add RDT compatible messages                    */
/* 30-Nov-2007  Vicky    Add SourceKey and Sourcetype as Parameter      */
/*                       (Vicky01)                                      */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/* 02-Nov-2017  Ung      WMS-3366 RDT compatible                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot3Lot4ByJulianDate]
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
      @n_BatchYear         INT,
      @n_DaysInYear        INT,
      @c_BatchYear         NVARCHAR( 1),
      @c_DaysInYear        NVARCHAR( 3),
      @n_Shelflife         INT,
      @dt_Lottable03       DATETIME,
      @c_Lottable03Label   NVARCHAR( 20),
      @c_Lottable04Label   NVARCHAR( 20)

   DECLARE 
      @dt_Today            DATETIME,
      @n_CurrYear          INT,
      @n_CurrYear3Digits   INT,
      @dt_CurrYearDay1     DATETIME,
      @n_TempYear          INT,
      @dt_TempYearDay1     DATETIME,
      @dt_TempDate         DATETIME,
      @n_ManufYear         INT,
      @dt_ManufYearDay1    DATETIME,
      @dt_ManufDate        DATETIME,
      @c_IsLeapYear        NVARCHAR( 1)

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue      = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable01    = '',
          @c_Lottable02    = '',
          @c_Lottable03    = '',
          @dt_Lottable04   = NULL,
          @dt_Lottable05   = NULL,
          @c_Lottable06    = '',
          @c_Lottable07    = '',
          @c_Lottable08    = '',
          @c_Lottable09    = '',
          @c_Lottable10    = '',
          @c_Lottable11    = '',
          @c_Lottable12    = '',
          @dt_Lottable13   = NULL,
          @dt_Lottable14   = NULL,
          @dt_Lottable15   = NULL,
          @n_Shelflife     = 0

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable03Label = dbo.fnc_RTrim(Lottable03Label),
             @c_Lottable04Label = dbo.fnc_RTrim(Lottable04Label),
             @n_Shelflife = Shelflife 
      FROM SKU (NOLOCK)
      WHERE Storerkey = dbo.fnc_RTrim(@c_Storerkey)
      AND   SKU = dbo.fnc_RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable03Label', @c_Lottable03Label
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@n_Shelflife', @n_Shelflife
      END

      IF @c_Lottable03Label = 'MANF-DATE' AND @c_Lottable04Label = 'EXP-DATE'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
--         SET @b_Success = 0
         
         IF @c_Lottable03Label <> 'MANF-DATE'
         BEGIN
            SET @n_Err = 61326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable03Label Setup.  (ispGenLot3Lot4ByJulianDate)'
         END           
         ELSE IF @c_Lottable04Label <> 'EXP-DATE'
         BEGIN
            SET @n_Err = 61327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable04Label Setup.  (ispGenLot3Lot4ByJulianDate)'
         END       
         GOTO QUIT
      END         
   END
      
   -- Get Lottable03 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      -- Eg. 8060XXXXXX
      SELECT @c_BatchYear = LEFT(@c_Lottable02Value, 1) -- 8
      SELECT @c_DaysInYear = SUBSTRING(@c_Lottable02Value, 2, 3) -- 060

      IF NOT (@c_BatchYear >= '0' AND @c_BatchYear <= '9')
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Batch/Year Not Numeric. (ispGenLot3Lot4ByJulianDate)'    
         GOTO QUIT
      END

      -- Validate DaysInYear (eg. 7.1, .99, etc)
      DECLARE @i INT
      DECLARE @c NVARCHAR(1)
      SET @i = 1
      WHILE @i <= LEN( dbo.fnc_RTrim( @c_DaysInYear))
      BEGIN
         SET @c = SUBSTRING( @c_DaysInYear, @i, 1)
         IF NOT (@c >= '0' AND @c <= '9')
         BEGIN
--            SET @b_Success = 0
            SET @n_Err = 61329
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' DaysInYear Not Numeric. (ispGenLot3Lot4ByJulianDate)'            
            GOTO QUIT
         END
         SET @i = @i + 1
      END 

      -- Convert to Integer
      SELECT @n_BatchYear = CAST(@c_BatchYear AS INT)
      SELECT @n_DaysInYear = CAST(@c_DaysInYear AS INT) 

      IF @b_debug = 1
      BEGIN
         SELECT '@n_BatchYear', @n_BatchYear
         SELECT '@n_DaysInYear', @n_DaysInYear
      END

      IF @n_DaysInYear <= 0
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' DaysInYear Less Than or Equal to Zero.  (ispGenLot3Lot4ByJulianDate)'  
         GOTO QUIT
      END
   
      /*********************************************************************************/
      /* Julian Date must be smaller than today's date (It refers to production date)  */
      /* Eg. JulianDate      = 8060XXXXXX, where BatchYear = 8 and DaysInYear = 60     */
      /* Get values:                                                                   */
      /*    Today           = 2007-01-19                                               */
      /*    CurrYear        = 2007                                                     */
      /*    CurrYear3Digits = 200                                                      */
      /*    CurrYearDay1    = 2007-01-01                                               */
      /*    TempYear        = CurrYear3Digits + BatchYear = 2008                       */
      /*    TempYearDay1    = 2008-01-01                                               */
      /*    TempDate        = TempYearDay1 + 60 - 1 days = 2008-02-29                  */
      /* If TempDate > Today then CurrYear3Digits = 200 - 1 = 199                      */
      /*    ManufYear       = CurrYear3Digits + BatchYear = 1998                       */
      /* Check if ManufYear a leap year                                                */
      /*    ManufYearDay1   = 1998-01-01                          */
      /*    ManufDate       = ManufYearDay1 + 60 - 1 days = 1998-03-01                 */
      /*********************************************************************************/

      -- Eg. Today = 2007-01-19
      SELECT @dt_Today = CONVERT( DATETIME, CONVERT( NVARCHAR(8), GetDate(), 112)) 
      SELECT @n_CurrYear = DATEPART( Year, @dt_Today)  -- 2007
      SELECT @n_CurrYear3Digits = LEFT( @n_CurrYear,3) -- 200
      SELECT @dt_CurrYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @n_CurrYear) + '0101'), 112) -- 2007-01-01

      -- Assume TempYear as 200+8 = 2008
      SET @n_TempYear = CAST( CONVERT( NVARCHAR(3), @n_CurrYear3Digits) + CONVERT( NVARCHAR(1), @n_BatchYear) AS INT)
      SELECT @dt_TempYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @n_TempYear) + '0101'), 112)
      SELECT @dt_TempDate = DATEADD( Day, @n_DaysInYear - 1, @dt_TempYearDay1)

      -- Eg. Today = 2007-01-19, TempDate = 2008-03-01
      IF DATEDIFF( Day, @dt_TempDate, @dt_Today) < 0
      BEGIN
         SET @n_CurrYear3Digits = @n_CurrYear3Digits - 1  -- 200 - 1 = 199
      END

      -- Form manufacturing year
      SET @n_ManufYear = CAST( CONVERT( NVARCHAR(3), @n_CurrYear3Digits) + CONVERT( NVARCHAR(1), @n_BatchYear) AS INT)

      -- Check if ManufYear is leap year
      SET @c_IsLeapYear = 'N'
      IF (@n_ManufYear % 4 = 0) AND (@n_ManufYear % 100 = 0) AND (@n_ManufYear % 400 = 0) 
         SET @c_IsLeapYear = 'Y'
      ELSE IF (@n_ManufYear % 4 = 0) AND (@n_ManufYear % 100 <> 0) AND (@n_ManufYear % 400 <> 0)
         SET @c_IsLeapYear = 'Y'
      ELSE
         SET @c_IsLeapYear = 'N'  

      IF @c_IsLeapYear = 'Y' AND @n_DaysInYear > 366
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61331
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' DaysInYear Greater Than 366. (ispGenLot3Lot4ByJulianDate)'
         GOTO QUIT
      END
      ELSE IF @c_IsLeapYear = 'N' AND @n_DaysInYear > 365
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61332         
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' DaysInYear Greater Than 365. (ispGenLot3Lot4ByJulianDate)'
         GOTO QUIT
      END

      -- Form manufacturing date 
      SELECT @dt_ManufYearDay1 = CONVERT( DATETIME, CONVERT( NVARCHAR(8), CONVERT( NVARCHAR(4), @n_ManufYear) + '0101'), 112)
      SELECT @dt_ManufDate = DATEADD( Day, @n_DaysInYear - 1, @dt_ManufYearDay1)

      IF @b_debug = 1
         SELECT @dt_ManufDate
  
        SELECT @c_Lottable03 = CONVERT( NVARCHAR(8), @dt_ManufDate, 112)

      -- Get Lottable04 
      SELECT @dt_Lottable04 = @dt_ManufDate + @n_Shelflife

      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable03', @dt_Lottable03
         SELECT '@dt_Lottable04', @dt_Lottable04
      END         
   END

   IF @c_Sourcetype = '598'
      SET @c_Lottable02 = @c_Lottable02Value

QUIT:
END -- End Procedure

GO