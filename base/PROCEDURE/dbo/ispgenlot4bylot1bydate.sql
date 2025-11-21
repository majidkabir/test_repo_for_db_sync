SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Trigger:  ispGenLot4ByLot1ByDate                                     */    
/* Creation Date: 07-Sep-2011                                           */    
/* Copyright: IDS                                                       */    
/*                                                                      */    
/* Purpose:  Generate Receiptdetail Lottable04                          */    
/*           By JulianDate in Lottable01                                */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Who      Purpose                                        */    
/* 07-Sep-2011  James    Created                                        */      
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispGenLot4ByLot1ByDate]    
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
    
   DECLARE     
      @n_Year              INT,    
      @n_Month             INT,    
      @n_Day               INT,    
      @c_Year              NVARCHAR( 4),    
      @c_Month             NVARCHAR( 2),    
      @c_Day               NVARCHAR( 2),    
      @n_Shelflife         INT,    
      @c_Lottable01Label   NVARCHAR( 20),    
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
    
   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0    
   SELECT @c_Lottable01  = '',    
          @c_Lottable02  = '',    
          @c_Lottable03  = '',    
          @dt_Lottable04 = NULL,    
          @dt_Lottable05 = NULL    
   SET    @n_Shelflife = 0    
    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN     
      SELECT @c_Lottable01Label = RTRIM(Lottable01Label),    
             @c_Lottable04Label = RTRIM(Lottable04Label),    
             @n_Shelflife = Shelflife     
      FROM SKU (NOLOCK)    
      WHERE Storerkey = RTRIM(@c_Storerkey)    
      AND   SKU = RTRIM(@c_Sku)    
    
      IF @b_debug = 1    
      BEGIN    
         SELECT '@c_Lottable01Label', @c_Lottable01Label    
         SELECT '@c_Lottable04Label', @c_Lottable04Label    
         SELECT '@n_Shelflife', @n_Shelflife    
      END    
    
      IF @c_Lottable01Label = 'BATCHNO' AND @c_Lottable04Label = 'EXP_DATE'    
      BEGIN    
         SELECT @n_continue = 1    
      END    
      ELSE     
      BEGIN    
         SET @n_continue = 3    
  
         IF @c_Lottable01Label <> 'BATCHNO'    
         BEGIN    
            SET @n_ErrNo = 61326    
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable01Label Setup.  (ispGenLot4ByLot1ByDate)'    
         END               
         ELSE IF @c_Lottable04Label <> 'EXP_DATE'    
         BEGIN    
            SET @n_ErrNo = 61327    
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispGenLot4ByLot1ByDate)'    
         END           
         GOTO QUIT    
      END             
   END    
          
   -- Get Lottable01     
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN     
      -- Eg. yyyy-mm    
      SELECT @c_Year = LEFT(@c_Lottable01Value, 4) -- yyyy    
      SELECT @c_Month = SUBSTRING(@c_Lottable01Value, 5, 2) -- mm    
      SELECT @c_Day = SUBSTRING(@c_Lottable01Value, 7, 2) -- dd    
    
      IF ISNUMERIC(@c_Year) = 0    
      BEGIN    
         SET @n_ErrNo = 61328    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Year Not Numeric. (ispGenLot4ByLot1ByDate)'        
         GOTO QUIT    
      END    
    
      IF ISNUMERIC(@c_Month) = 0    
      BEGIN    
         SET @n_ErrNo = 61328    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Month Not Numeric. (ispGenLot4ByLot1ByDate)'        
         GOTO QUIT    
      END    
    
      IF ISNUMERIC(@c_Day) = 0    
      BEGIN    
         SET @n_ErrNo = 61328    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Day Not Numeric. (ispGenLot4ByLot1ByDate)'        
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
         SET @n_ErrNo = 61330    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Year Less Than or Equal to Zero.  (ispGenLot4ByLot1ByDate)'      
         GOTO QUIT    
      END    
    
      IF @n_Month <= 0    
      BEGIN    
         SET @n_ErrNo = 61330    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Month Less Than or Equal to Zero.  (ispGenLot4ByLot1ByDate)'      
         GOTO QUIT    
      END    
       
      IF @n_Day <= 0    
      BEGIN    
         SET @n_ErrNo = 61330    
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Day Less Than or Equal to Zero.  (ispGenLot4ByLot1ByDate)'      
         GOTO QUIT    
      END    
       
      -- Get Lottable04     
      SET @dt_Lottable04 = DATEADD(day, @n_Shelflife, CONVERT( DATETIME, LEFT( @c_Lottable01Value, 10)))    
      IF @b_debug = 1    
      BEGIN    
         SELECT '@dt_Lottable04', @dt_Lottable04    
      END             
   END    
          
QUIT:    
END -- End Procedure    

GO