SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLot4bylot3byyear                                     */
/* Creation Date: 05-Jul-2018                                           */
/* Copyright: LFL                                                       */
/*                                                                      */
/* Purpose: WMS-5586 - TW ENG Convert lottable03 to lottable04          */ 
/*          by sku shelflife.                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13/09/2019   NJO0W01   1.0   Change formula. get part date of year   */
/*                              after  add/ decrease ShelfLife by year  */
/*                              (ShelfLife/365)                         */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispGenLot4bylot3byyear]
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
   , @c_type               NVARCHAR(10)   = ''   
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @n_continue          INT,
           @b_debug             INT,
           @n_Shelflife         INT,
           @c_Lottable03Label   NVARCHAR(20),
           @c_Lottable04Label   NVARCHAR(20),
           @c_Year              NVARCHAR(4),
           @c_Month             NVARCHAR(2),
           @c_Day               NVARCHAR(2),
           @dt_ExpiryDate       DATETIME           

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0
   
   SELECT @c_Lottable01  = '', @c_Lottable02  = '', @c_Lottable03  = '', @dt_Lottable04 = NULL, @dt_Lottable05 = NULL
   SELECT @c_Lottable06  = '', @c_Lottable07  = '', @c_Lottable08  = '', @c_Lottable09 = '', @c_Lottable10 = ''
   SELECT @c_Lottable11  = '', @c_Lottable12  = '', @dt_Lottable13  = NULL, @dt_Lottable14 = NULL, @dt_Lottable15 = NULL

   SET  @n_Shelflife = 0

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SELECT @c_Lottable03Label = ISNULL(Lottable03Label,''),
             @c_Lottable04Label = ISNULL(Lottable04Label,''),
             @n_Shelflife = Shelflife 
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND SKU = @c_Sku

      IF @c_Lottable03Label <> 'EXPDATEYEAR' AND @c_Lottable04Label <> 'MANFDATEYEAR'
      BEGIN
         SELECT @n_continue = 3
      END
   END
      
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LottableLabel = 'EXPDATEYEAR' --From lottable03 to lottable04
   BEGIN       
      SELECT @c_Month = SUBSTRING(@c_Lottable03Value, 5, 2) 
      SELECT @c_Day = SUBSTRING(@c_Lottable03Value, 7, 2) 
      
      IF ISDATE(@c_Lottable03Value) <> 1
      BEGIN
         SET @n_ErrNo = 61328
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable03. The format must be YYYYMMDD. (ispGenLot4bylot3byyear)'    
         GOTO QUIT
      END
--	  SELECT @dt_ExpiryDate = DATEADD(Day, @n_ShelfLife, CAST(@c_Lottable03Value AS DATETIME))     
      SELECT @dt_ExpiryDate = DATEADD(YEAR, @n_ShelfLife/365, CAST(@c_Lottable03Value AS DATETIME))  --NJOW01
      
      SELECT @c_Year = CAST(YEAR(@dt_ExpiryDate) AS NVARCHAR)
      
      SELECT @dt_ExpiryDate = CAST(@c_year+@c_Month+@c_Day AS DATETIME)
      
      SELECT @dt_Lottable04 = @dt_ExpiryDate            
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LottableLabel = 'MANFDATEYEAR' --From lottable04 to lottable03
   BEGIN             
      SELECT @c_Month = SUBSTRING(CONVERT(NVARCHAR,@dt_Lottable04Value,112),5,2)
      SELECT @c_Day = SUBSTRING(CONVERT(NVARCHAR,@dt_Lottable04Value,112),7,2)

--      SELECT @dt_ExpiryDate = DATEADD(Day, @n_ShelfLife * -1, CAST(@dt_Lottable04Value AS DATETIME))
      SELECT @dt_ExpiryDate = DATEADD(YEAR, (@n_ShelfLife/365) * -1, CAST(@dt_Lottable04Value AS DATETIME))  --NJOW01
            
      SELECT @c_Year = CAST(YEAR(@dt_ExpiryDate) AS NVARCHAR)
           
      SELECT @c_Lottable03 = @c_Year+@c_Month+@c_Day            
   END
      
QUIT:
END -- End Procedure

GO