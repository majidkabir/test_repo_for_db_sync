SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispGenLot1ByRecType                                        */
/* Creation Date: 08-Dec-2014                                           */
/* Copyright: LF                                                        */
/*                                                                      */
/* Purpose:  SOS#327560 - Lottable01 default value by receipt type      */ 
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 26-Feb-2015  NJOW01    1.0   327560-Trigger from finalize as well    */
/* 09-Apr-2015  CSCHONG     Added Lottables 06-15 and type (CS01)          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot1ByRecType]
    @c_Storerkey        NVARCHAR(15),
    @c_Sku              NVARCHAR(20),
	 @c_Lottable01Value  NVARCHAR(18),
	 @c_Lottable02Value  NVARCHAR(18),
	 @c_Lottable03Value  NVARCHAR(18),
	 @dt_Lottable04Value datetime,
	 @dt_Lottable05Value datetime,
    @c_Lottable06Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable07Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable08Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable09Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable10Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable11Value    NVARCHAR(30)   = '',             --(CS01)  
    @c_Lottable12Value    NVARCHAR(30)   = '',             --(CS01)  
    @dt_Lottable13Value   DATETIME       = NULL,           --(CS01)    
    @dt_Lottable14Value   DATETIME       = NULL,           --(CS01)  
    @dt_Lottable15Value   DATETIME       = NULL,           --(CS01)   
	 @c_Lottable01       NVARCHAR(18) OUTPUT,
	 @c_Lottable02       NVARCHAR(18) OUTPUT,
	 @c_Lottable03       NVARCHAR(18) OUTPUT,
	 @dt_Lottable04      datetime OUTPUT,
    @dt_Lottable05      datetime OUTPUT,
    @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT,    --(CS01)  
    @dt_Lottable13        DATETIME       = NULL   OUTPUT,    --(CS01)  
    @dt_Lottable14        DATETIME       = NULL   OUTPUT,    --(CS01)  
    @dt_Lottable15        DATETIME       = NULL   OUTPUT,    --(CS01)  
    @b_Success          int = 1  OUTPUT,
    @n_ErrNo            int = 0  OUTPUT,
    @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
    @c_Sourcekey        NVARCHAR(10) = '',  
    @c_Sourcetype       NVARCHAR(20) = '',  
    @c_LottableLabel    NVARCHAR(20) = '',
    @c_type               NVARCHAR(10)   = ''     --(CS01)   
AS
BEGIN
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @c_receiptkey   NVARCHAR(10),
           @c_rectype      NVARCHAR(10),
           @c_udf01        NVARCHAR(30)

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0
   SELECT @c_Lottable01  = '',
			    @c_Lottable02  = '',
			    @c_Lottable03  = '',
			    @dt_Lottable04 = NULL,
			    @dt_Lottable05 = NULL,
             @c_Lottable06  = '',           --(CS01) 
			    @c_Lottable07  = '',           --(CS01)
			    @c_Lottable08  = '',           --(CS01)
             @c_Lottable09  = '',           --(CS01) 
			    @c_Lottable10  = '',           --(CS01)
			    @c_Lottable11  = '',           --(CS01)
             @c_Lottable12  = '',           --(CS01)
             @dt_Lottable13 = NULL,         --(CS01)
			    @dt_Lottable14 = NULL,         --(CS01)
			    @dt_Lottable15 = NULL          --(CS01)
   
   SELECT @c_Receiptkey = LEFT(@c_Sourcekey,10)

   IF @c_Sourcetype NOT IN ('RECEIPT','TRADERETURN','RECEIPTFINALIZE')
   BEGIN
      GOTO QUIT
   END
   
   --IF ISNULL(@c_Lottable01Value,'') <> ''
   --BEGIN
   --   GOTO QUIT   	
   --END

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      /*SELECT @c_RecType = RecType
      FROM RECEIPT (NOLOCK)
  		WHERE Receiptkey = @c_Receiptkey*/
  		
  		SET @c_RecType = @c_Sourcekey 
  		
  		SELECT TOP 1 @c_udf01 = ISNULL(UDF01,'')
  		FROM CODELKUP (NOLOCK)
  		WHERE Listname = 'RECTYPE'
  		AND Code = @c_RecType
  	  AND (Storerkey = @c_Storerkey OR ISNULL(Storerkey,'') = '')
	    ORDER BY Storerkey DESC
	    
      SET @c_Lottable01 = ISNULL(@c_udf01,'')

   END
            
QUIT:
END -- End Procedure

GO