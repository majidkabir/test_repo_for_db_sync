SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenLotUNILEVER                                          */
/* Creation Date: 03-Jun-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: WMS-9271 - PH Auto Compute Lottables                        */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*14/08/2019    WLChooi   1.0   Fix - LottableValues (WL01)             */
/*08/10/2019    WLChooi   1.1   Fix - Calculation of day (WL02)         */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispGenLotUNILEVER]
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
           @c_Lottable13Label   NVARCHAR(20),
           @c_Lottable04Label   NVARCHAR(20),
           @c_Lottable02Label   NVARCHAR(20),
           @c_Year              NVARCHAR(4),
           @c_Month             NVARCHAR(2),
           @c_Day               NVARCHAR(2),
           @dt_ExpiryDate       DATETIME,
           @n_starttcnt         INT,
           @n_Year              INT  = 0,
           @n_Week              INT  = 0,
           @n_Day               INT  = 0     

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0
   SELECT @n_starttcnt = @@TRANCOUNT
   
   --WL01 Start
   SELECT  @c_Lottable01  = @c_Lottable01Value
         , @c_Lottable02  = @c_Lottable02Value
         , @c_Lottable03  = @c_Lottable03Value
         , @dt_Lottable04 = @dt_Lottable04Value
         , @dt_Lottable05 = @dt_Lottable05Value
         , @c_Lottable06  = @c_Lottable06Value
         , @c_Lottable07  = @c_Lottable07Value
         , @c_Lottable08  = @c_Lottable08Value
         , @c_Lottable09  = @c_Lottable09Value
         , @c_Lottable10  = @c_Lottable10Value
         , @c_Lottable11  = @c_Lottable11Value
         , @c_Lottable12  = @c_Lottable12Value
         , @dt_Lottable13 = @dt_Lottable13Value
         , @dt_Lottable14 = @dt_Lottable14Value
         , @dt_Lottable15 = @dt_Lottable15Value
   --WL01 End

   SET @n_Shelflife = 0
   SET DATEFIRST 1 --WL02

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN 
      SELECT @c_Lottable13Label = ISNULL(Lottable13Label,''),
             @c_Lottable04Label = ISNULL(Lottable04Label,''),
             @c_Lottable02Label = ISNULL(Lottable02Label,''),
             @n_Shelflife = Shelflife 
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND SKU = @c_Sku

      IF ISNULL(@n_Shelflife,0) = 0
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_ErrNo)    
         SET @n_ErrNo = 82030    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_ErrNo)+': Shelflife not setup for this SKU: ' + @c_Sku + '. (ispGenLotUNILEVER)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT  
      END   

      IF @c_Lottable13Label <> 'PRODDATE' AND @c_Lottable04Label <> 'EXPDATE' AND @c_Lottable02Label <> 'BATCHNO'
      BEGIN
         SELECT @n_continue = 3
      END
   END
   
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LottableLabel = 'BATCHNO' AND ISNULL(@c_Lottable02Value,'') <> ''  --From lottable02 to lottable04 & lottable13 (Lottable02 = 190921)
   BEGIN    
      IF ( ISNUMERIC(@c_Lottable02Value) <> 1 )
      BEGIN
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_ErrNo)    
         SET @n_ErrNo = 82060    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_ErrNo)+': BatchNo contain chars other than integer: ' + @c_Lottable02Value + '. (ispGenLotUNILEVER)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT 
      END

      IF ( ( (CONVERT(INT,SUBSTRING(@c_Lottable02Value,3,2))) > 53 OR (CONVERT(INT,SUBSTRING(@c_Lottable02Value,3,2))) < 0 )
         OR ( (CONVERT(INT,SUBSTRING(@c_Lottable02Value,5,1))) > 7 OR (CONVERT(INT,SUBSTRING(@c_Lottable02Value,5,1))) < 0 ) )
      BEGIN
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_ErrNo)    
         SET @n_ErrNo = 82070    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_ErrNo)+': BatchNo not valid: ' + @c_Lottable02Value + '. (ispGenLotUNILEVER)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT 
      END

      SELECT @n_Year = LEFT(CAST(DATEPART(YEAR,GETDATE()) AS NVARCHAR(4)),2) + SUBSTRING(LTRIM(RTRIM(@c_Lottable02Value)),1,2) --2019
            ,@n_Week = SUBSTRING(LTRIM(RTRIM(@c_Lottable02Value)),3,2) --09
            ,@n_Day  = SUBSTRING(LTRIM(RTRIM(@c_Lottable02Value)),5,1) --2

      SELECT @dt_Lottable13 = ((DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4 -
                                DATEPART(dw, DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4) + 1 ) --Find first Day of the given week (Sunday)
                              + @n_Day )                                                                           --Then add the day
               
      SELECT @dt_Lottable04 = DATEADD(DAY,@n_Shelflife,@dt_Lottable13)     
   END
      
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LottableLabel = 'PRODDATE' AND ISNULL(@dt_Lottable13Value,'1900/01/01') <> '1900/01/01' --From lottable13 to lottable04 & lottable02
   BEGIN      
      IF(ISDATE(@dt_Lottable13Value) <> 1)
      BEGIN
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_ErrNo)    
         SET @n_ErrNo = 82040   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_ErrNo)+': Lottable13 is not in date format ' + CAST(@dt_Lottable13Value AS NVARCHAR(100))  
                      + '. (ispGenLotUNILEVER)'  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT
      END
      SELECT @n_Year = DATEPART(YEAR,@dt_Lottable13Value)
      SELECT @n_Week = DATEPART(WEEK,@dt_Lottable13Value)
      --SELECT @n_Day  = DATEPART(DAY,@dt_Lottable13Value) - DATEPART(DAY,((DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4 -
      --                 DATEPART(dw, DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4) + 1 ))) --WL02
      SELECT @n_Day = DATEPART(dw,@dt_Lottable13Value) --WL02
      SELECT @c_Lottable02 = RIGHT(CAST(@n_Year AS NVARCHAR(4)),2) + RIGHT('00'+ CAST(@n_Week AS NVARCHAR(2)),2) + CAST(@n_Day AS NVARCHAR(1)) + '1'

      SELECT @dt_Lottable04 = DATEADD(DAY,@n_Shelflife,@dt_Lottable13Value)
          
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LottableLabel = 'EXPDATE' AND ISNULL(@dt_Lottable04Value,'1900/01/01') <> '1900/01/01' --From lottable04 to lottable13 & lottable02
   BEGIN        
      IF(ISDATE(@dt_Lottable04Value) <> 1)
      BEGIN
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_ErrNo)    
         SET @n_ErrNo = 82050   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_ErrNo)+': Lottable04 is not in date format ' + CAST(@dt_Lottable04Value AS NVARCHAR(100))  
                      + '. (ispGenLotUNILEVER)'  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT
      END     
      SELECT @dt_Lottable13 = DATEDIFF(DAY,@n_Shelflife,@dt_Lottable04Value)   
      SELECT @n_Year = DATEPART(YEAR,@dt_Lottable13)
      SELECT @n_Week = DATEPART(WEEK,@dt_Lottable13)
      --SELECT @n_Day  = DATEPART(DAY,@dt_Lottable13) - DATEPART(DAY,((DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4 -
      --                 DATEPART(dw, DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4) + 1 )))  --WL02
      SELECT @n_Day = DATEPART(dw,@dt_Lottable13) --WL02
      SELECT @c_Lottable02 = RIGHT(CAST(@n_Year AS NVARCHAR(4)),2) + RIGHT('00'+ CAST(@n_Week AS NVARCHAR(2)),2) + CAST(@n_Day AS NVARCHAR(1)) + '1'              
   END
      
QUIT:
 
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
	    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
	    BEGIN
	       ROLLBACK TRAN
	    END
	 ELSE
	    BEGIN
	       WHILE @@TRANCOUNT > @n_starttcnt
 	      BEGIN
	          COMMIT TRAN
	       END
	    END
  	  execute nsp_logerror @n_ErrNo, @c_errmsg, 'ispGenLotUNILEVER'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	    BEGIN
	       SELECT @b_success = 1
	       WHILE @@TRANCOUNT > @n_starttcnt
	       BEGIN
	          COMMIT TRAN
	       END
	       RETURN
	    END	   
END -- End Procedure

GO