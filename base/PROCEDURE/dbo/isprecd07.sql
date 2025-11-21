SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispRECD07                                          */
/* Creation Date: 14-Jun-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17252 CN IKEA Update receiptdetail lottable02 & ID      */   
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispRECD07]   
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
           @c_ReceiptLineNumber NVARCHAR(5),
           @c_ToId              NVARCHAR(18),
           @c_Lottable02        NVARCHAR(18),
           @c_Option1           NVARCHAR(50),
           @c_Option2           NVARCHAR(50),
           @c_Sku               NVARCHAR(20)
                                                       
	SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
  SELECT TOP 1 @c_Option1 = Option1,
               @c_Option2 = Option2
  FROM STORERCONFIG(NOLOCK)
  WHERE StorerKey = @c_Storerkey
  AND Configkey = 'ReceiptDetailTrigger_SP'
  AND Svalue = 'ispRECD07'
  
	IF @c_Action IN('INSERT') 
	BEGIN
     DECLARE Cur_Receipt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT I.Receiptkey, I.ReceiptLineNumber, I.Sku, I.ToId
        FROM #INSERTED I
        JOIN RECEIPT R (NOLOCK) ON I.Receiptkey = R.Receiptkey
        WHERE I.Storerkey = @c_Storerkey        
        AND R.Sellercompany = @c_Option1 
        AND ISNULL(I.Lottable02,'') = ''
        AND (R.Facility IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Option2)) 
            OR ISNULL(@c_Option2,'')='')
     
     OPEN Cur_Receipt
	  
	   FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_Sku, @c_ToId

	   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
	   BEGIN	   
	   	  SET @c_ToId = LEFT(@c_Sku,13) + RIGHT(RTRIM(@c_Receiptkey),3) + RIGHT(RTRIM(@c_ReceiptLineNumber),2)
	   	  SET @c_Lottable02 = @c_ToID

	      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
	      SET ToID = @c_ToId,
	          Lottable02 = @c_Lottable02,
	          Trafficcop = NULL
	      WHERE Receiptkey = @c_Receiptkey
	      AND ReceiptLineNumber = @c_ReceiptLineNumber 
	      
	      SET @n_Err = @@ERROR
	      
	      IF @n_Err <> 0 
	      BEGIN
   	        SELECT @n_continue = 3 
   	        SELECT @n_err = 60100
   	        SELECT @c_errmsg = 'Update RECEIPTDETAIL Table Failed. (ispRECD07)' 
	      END
    		   		    	
   	    FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_Sku, @c_ToId
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD07'		
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