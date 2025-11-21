SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot2ByLot4ByDate                                     */
/* Creation Date: 04-Jan-2010  by GTGOH                                 */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable02                          */
/*           By Date in Lottable04                                      */
/*           - Duplicate from ispGenLot4ByLot3ByJulianDate              */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot2ByLot4ByDate]
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
      @n_Year              INT,
      @n_Month             INT,
      @n_Day               INT,
      @c_Year              NVARCHAR( 4),
      @c_Month             NVARCHAR( 2),
      @c_Day               NVARCHAR( 2),
      @n_Shelflife         INT,
      @dt_Lottable02       DATETIME,
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
          @dt_Lottable05 = NULL
   SET    @n_Shelflife = 0

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable02Label = dbo.fnc_RTrim(Lottable02Label),
             @c_Lottable04Label = dbo.fnc_RTrim(Lottable04Label),
             @n_Shelflife = Shelflife 
      FROM SKU (NOLOCK)
      WHERE Storerkey = dbo.fnc_RTrim(@c_Storerkey)
      AND   SKU = dbo.fnc_RTrim(@c_Sku)

   IF @b_debug = 1
      BEGIN
         SELECT '@c_Lottable02Label', @c_Lottable02Label
         SELECT '@c_Lottable04Label', @c_Lottable04Label
         SELECT '@n_Shelflife', @n_Shelflife
      END

      IF @c_Lottable02Label = 'BBT_BATCH' AND @c_Lottable04Label = 'BBT_EXPDATE'
      BEGIN
         SELECT @n_continue = 1
      END
  ELSE 
      BEGIN
         SET @n_continue = 3
--         SET @b_Success = 0
         
         IF @c_Lottable02Label <> 'BBT_BATCH'
         BEGIN
            SET @n_Err = 61326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable02Label Setup.  (ispGenLot2ByLot4ByDate)'
         END           
         ELSE IF @c_Lottable04Label <> 'BBT_EXPDATE'
         BEGIN
            SET @n_Err = 61327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Lottable04Label Setup.  (ispGenLot2ByLot4ByDate)'
         END       
         GOTO QUIT
      END         
   END
      
   -- Get Lottable02 
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      -- Eg. yyyy-mm
      SELECT @c_Year = Year(@dt_Lottable04Value) -- yyyy
      SELECT @c_Month = Month(@dt_Lottable04Value) -- mm
      SELECT @c_Day = Day(@dt_Lottable04Value) -- dd

      IF ISNUMERIC(@c_Year) = 0
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Year Not Numeric. (ispGenLot2ByLot4ByDate)'    
         GOTO QUIT
      END

      IF ISNUMERIC(@c_Month) = 0
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Month Not Numeric. (ispGenLot2ByLot4ByDate)'    
         GOTO QUIT
      END

      IF ISNUMERIC(@c_Day) = 0
      BEGIN
--         SET @b_Success = 0
         SET @n_Err = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Day Not Numeric. (ispGenLot2ByLot4ByDate)'    
         GOTO QUIT
      END

      -- Convert to Integer
      SELECT @n_Year = CAST(@c_Year AS INT)
      SELECT @n_Month = CAST(@c_Month AS INT) 
      SELECT @n_Day = CAST(@c_Day AS INT) 

      IF @b_debug = 1
      BEGIN
         SELECT '@n_Year', @n_Year
         SELECT '@n_Month', @n_Month
         SELECT '@n_Day', @n_Day
      END

      IF @n_Year <= 0
      BEGIN
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Year Less Than or Equal to Zero.  (ispGenLot2ByLot4ByDate)'  
         GOTO QUIT
      END

      IF @n_Month <= 0
      BEGIN
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Month Less Than or Equal to Zero.  (ispGenLot2ByLot4ByDate)'  
         GOTO QUIT
      END
   
      IF @n_Day <= 0
      BEGIN
         SET @n_Err = 61330
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Day Less Than or Equal to Zero.  (ispGenLot2ByLot4ByDate)'  
         GOTO QUIT
      END
   
      -- Get Lottable04 
      SET @dt_Lottable04 = @dt_Lottable04Value
      SET @dt_Lottable02 = DATEADD(day, (@n_Shelflife * -1), @dt_Lottable04Value)
      SET @c_Lottable02 = RIGHT(ISNULL(RTRIM(CONVERT(CHAR, DATEPART(YEAR, @dt_Lottable02))),'0000'),4)           
                                 + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, @dt_Lottable02))),'00'), 2)     
                                 + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, @dt_Lottable02))),'00'), 2)       

      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable02', @dt_Lottable02
      END         
   END
      
QUIT:
END -- End Procedure



GO