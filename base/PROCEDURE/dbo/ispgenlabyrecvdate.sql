SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP:  ispGenLAByRecvDate                                              */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Generate Lottable Attributes by Receipt Date               */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 09-Jun-2015  CSCHONG  Added Lottables 06-15 and type (CS01)          */  
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLAByRecvDate]
      @c_Storerkey        NVARCHAR(15) 
   ,  @c_Sku              NVARCHAR(20) 
   ,  @c_Lottable01Value  NVARCHAR(18) 
   ,  @c_Lottable02Value  NVARCHAR(18) 
   ,  @c_Lottable03Value  NVARCHAR(18) 
   ,  @dt_Lottable04Value DATETIME 
   ,  @dt_Lottable05Value DATETIME 
   ,  @c_Lottable06Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable07Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable08Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable09Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable10Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable11Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @c_Lottable12Value  NVARCHAR(30)   = ''             --(CS01)    
   ,  @dt_Lottable13Value DATETIME       = NULL           --(CS01)      
   ,  @dt_Lottable14Value DATETIME       = NULL           --(CS01)    
   ,  @dt_Lottable15Value DATETIME       = NULL           --(CS01)     
   ,  @c_Lottable01       NVARCHAR(18) OUTPUT    
   ,  @c_Lottable02       NVARCHAR(18) OUTPUT    
   ,  @c_Lottable03       NVARCHAR(18) OUTPUT    
   ,  @dt_Lottable04      DATETIME     OUTPUT  
   ,  @dt_Lottable05      DATETIME     OUTPUT  
   ,  @c_Lottable06       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable07       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable08       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable09       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable10       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable11       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @c_Lottable12       NVARCHAR(30)   = ''     OUTPUT    --(CS01)    
   ,  @dt_Lottable13      DATETIME       = NULL   OUTPUT    --(CS01)    
   ,  @dt_Lottable14      DATETIME       = NULL   OUTPUT    --(CS01)    
   ,  @dt_Lottable15      DATETIME       = NULL   OUTPUT    --(CS01)  
   ,  @b_Success          INT = 1      OUTPUT  
   ,  @n_ErrNo            INT = 0      OUTPUT  
   ,  @c_Errmsg           NVARCHAR(250) = '' OUTPUT 
   ,  @c_Sourcekey        NVARCHAR(15) = ''    
   ,  @c_Sourcetype       NVARCHAR(20) = ''    
   ,  @c_LottableLabel    NVARCHAR(20) = ''    

AS
BEGIN
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @n_continue        INT 
         , @b_debug           INT

         , @c_year            NVARCHAR(4)
         , @c_Week            NVARCHAR(10)

         , @c_LottableLabel01 NVARCHAR(20)
         , @c_LottableLabel02 NVARCHAR(20)
         , @c_LottableLabel03 NVARCHAR(20)
         , @c_LottableLabel05 NVARCHAR(20)

   SET @n_continue = 1
   SET @b_success  = 1
   SET @n_ErrNo    = 0
   SET @b_debug    = 0

   IF @c_Sourcetype <> 'RECEIPTFINALIZE'
   BEGIN
      GOTO QUIT
   END

   SET @c_LottableLabel01 = ''
   SET @c_LottableLabel02 = ''
   SET @c_LottableLabel03 = ''
   SET @c_LottableLabel05 = ''

   SELECT @c_LottableLabel01 = Lottable01Label
         ,@c_LottableLabel02 = Lottable02Label
         ,@c_LottableLabel03 = Lottable03Label
         ,@c_LottableLabel05 = Lottable05Label
   FROM SKU WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND   SKU = @c_Sku

   IF @c_LottableLabel05 <> 'RCP_DATE'
   BEGIN
      GOTO QUIT
   END

   SET @c_year = ''
   SET @c_Week = ''

   SET @dt_Lottable05Value = CASE WHEN @dt_Lottable05Value IS NULL THEN GETDATE() ELSE @dt_Lottable05Value END
   SET @c_year = DATEPART(yy, @dt_Lottable05Value)
   SET @c_Week = DATEPART(wk, @dt_Lottable05Value)

   SET @c_Lottable01 = CASE WHEN @c_LottableLabel01 = @c_LottableLabel THEN @c_year + @c_week ELSE '' END
   SET @c_Lottable02 = CASE WHEN @c_LottableLabel02 = @c_LottableLabel THEN @c_year + @c_week ELSE '' END
   SET @c_Lottable03 = CASE WHEN @c_LottableLabel03 = @c_LottableLabel THEN @c_year + @c_week ELSE '' END
  
   QUIT:

END -- End Procedure

GO