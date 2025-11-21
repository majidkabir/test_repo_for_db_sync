SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot2Lot4ByJulianDate                                 */
/* Creation Date: 22-Sep-2006                                           */
/* Copyright: IDS                                                       */
/*                                                                      */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable04                          */
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
/* 26-Mar-2007  James    Created                                        */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot2Lot4ByJulianDate]
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

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE 
      @n_Year              INT,
      @n_Month             INT,
      @c_Year              NVARCHAR( 4),
      @c_Month             NVARCHAR( 2),
      @n_Shelflife         INT,
      @dt_Lottable03       DATETIME,
      @c_Lottable02Label   NVARCHAR( 20),
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

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL,
          @n_Shelflife = 0

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable02Label = RTRIM(Lottable02Label),
             @c_Lottable04Label = RTRIM(Lottable04Label),
             @n_Shelflife = Shelflife 
      FROM SKU (NOLOCK)
      WHERE Storerkey = RTRIM(@c_Storerkey)
      AND   SKU = RTRIM(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable02Label', @c_Lottable02Label
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@n_Shelflife', @n_Shelflife
      END

      IF @c_Lottable02Label = 'EXPDATEYYYY-MM' AND @c_Lottable04Label = 'EXP_DATE'
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
   BEGIN
         SET @n_continue = 3
         SET @b_Success = 0
         
         IF @c_Lottable02Label <> 'EXPDATEYYYY-MM'
         BEGIN
            SET @n_Err = 61326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable02Label Setup.  (ispGenLot2Lot4ByJulianDate)'
         END           
         ELSE IF @c_Lottable04Label <> 'EXP_DATE'
         BEGIN
            SET @n_Err = 61327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable04Label Setup.  (ispGenLot2Lot4ByJulianDate)'
         END       
         GOTO QUIT
      END         
   END
      
   -- Get Lottable02 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      -- Eg. yyyy-mm
      SELECT @c_Year = LEFT(@c_Lottable02Value, 4) -- yyyy
      SELECT @c_Month = SUBSTRING(@c_Lottable02Value, 6, 2) -- mm

      IF ISNUMERIC(@c_Year) = 0
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Year Not Numeric. (ispGenLot2Lot4ByJulianDate)'    
         GOTO QUIT
      END

      IF ISNUMERIC(@c_Month) = 0
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Month Not Numeric. (ispGenLot2Lot4ByJulianDate)'    
         GOTO QUIT
      END

      -- Convert to Integer
      SELECT @n_Year = CAST(@c_Year AS INT)
      SELECT @n_Month = CAST(@c_Month AS INT) 

      IF @b_debug = 1
      BEGIN
         SELECT '@n_Year', @n_Year
         SELECT '@n_Month', @n_Month
      END

      IF @n_Year <= 0
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Year Less Than or Equal to Zero.  (ispGenLot2Lot4ByJulianDate)'  
         GOTO QUIT
      END

      IF @n_Month <= 0
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Month Less Than or Equal to Zero.  (ispGenLot2Lot4ByJulianDate)'  
         GOTO QUIT
      END
   
      -- Get Lottable04 
         SET @dt_Lottable04 = RIGHT(RTRIM('0' + CONVERT(CHAR, @n_Year)), 4) + RIGHT(RTRIM('0' + CONVERT(CHAR, @n_Month)), 2) + '01'
      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable04', @dt_Lottable04
      END         
   END
      
QUIT:
END -- End Procedure

GO