SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispRECD01                                          */
/* Creation Date: 03-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1789-TW-CarryOver default lottable06 value for Return   */   
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispRECD01]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue          INT,
           @n_StartTCnt         INT,
           @c_Receiptkey        NVARCHAR(10),
           @c_ReceiptLineNUmber NVARCHAR(5)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('INSERT','UPDATE') 
	 BEGIN
      DECLARE Cur_Receipt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Receiptkey, I.ReceiptLineNumber
         FROM #INSERTED I
         JOIN RECEIPT R (NOLOCK) ON I.Receiptkey = R.Receiptkey
         JOIN SKU (NOLOCK) ON I.Storerkey = SKU.Storerkey AND I.Sku = SKU.Sku
         WHERE I.Storerkey = @c_Storerkey         
         AND SKU.Busr5 = '1'
         AND R.DocType = 'R'
         AND I.Lottable06 <> 'CARRYOVER'

      OPEN Cur_Receipt
	  
	    FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_ReceiptLineNumber

	    WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
	    BEGIN	    
	    	
	    	 UPDATE RECEIPTDETAIL WITH (ROWLOCK)
	    	 SET Lottable06 = 'CARRYOVER'
	    	 WHERE Receiptkey = @c_Receiptkey
	    	 AND ReceiptLineNumber = @c_ReceiptLineNumber 
	    	 
	    	 SET @n_Err = @@ERROR
	    	 
	    	 IF @n_Err <> 0 
	    	 BEGIN
   	        SELECT @n_continue = 3 
   	        SELECT @n_err = 60190
   	        SELECT @c_errmsg = 'Update RECEIPTDETAIL Table Failed. (ispRECD01)' 
	    	 END
	    	 	    		    		    	
         FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey,  @c_ReceiptLineNumber
	    END
      CLOSE Cur_Receipt
      DEALLOCATE Cur_Receipt
   END
      
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	ROLLBACK TRAN
	    END
	    ELSE
	    BEGIN
	    	WHILE @@TRANCOUNT > @n_StartTCnt
	    	BEGIN
	    		COMMIT TRAN
	    	END
	    END
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD01'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO