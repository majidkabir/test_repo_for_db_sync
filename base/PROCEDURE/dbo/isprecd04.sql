SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispRECD04                                          */
/* Creation Date: 03-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-8285 CN & SG Logitech ASN Status tracking               */   
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

CREATE PROC [dbo].[ispRECD04]   
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
           @c_TableName       NVARCHAR(30),
           @c_Option1         NVARCHAR(50)                 
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
   SET @c_TableName = 'STSASN'	 
   
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
   SELECT @c_Option1 = ISNULL(Option1,'')
   FROM STORERCONFIG (NOLOCK)
   WHERE Configkey = 'ReceiptDetailTrigger_SP'
   AND Storerkey = @c_Storerkey
   AND Svalue = 'ispRECD04'
   
   IF ISNULL(@c_Option1,'') NOT IN('1','2')
     SET @c_Option1 = '1'   
               
	 IF @c_Action IN('UPDATE') 
	 BEGIN	
      --Capture create receipt status when received first qty
      IF @c_Option1 = '2' 
      BEGIN      
         INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	     SELECT @c_TableName, R.Receiptkey, R.Storerkey, '0', 
	 	            MIN(I.EditDate),
	 	            R.ExternReceiptkey,
	 	            R.POKey, 	 	         
	 	            'N'
	 	     FROM #INSERTED I
	 	     JOIN #DELETED D ON I.Receiptkey = D.Receiptkey AND I.ReceiptLineNumber = D.ReceiptLineNumber 
	 	     JOIN RECEIPT R (NOLOCK) ON I.Receiptkey = R.Receiptkey
	 	     WHERE R.Storerkey = @c_Storerkey
	 	     AND I.QtyReceived + I.BeforeReceivedQty > 0
	 	     AND NOT EXISTS(SELECT 1 FROM DOCSTATUSTRACK (NOLOCK)
      	                WHERE TableName = @c_TableName
      	                AND DocumentNo = R.Receiptkey
      	                AND Storerkey = R.Storerkey
      	                AND DocStatus = '0')	 	     	 	        	     
      	 GROUP BY R.Receiptkey, R.Storerkey, R.ExternReceiptkey, R.POKey 	 	                                     	                	
 	  	     	  
         SET @n_err = @@ERROR    
         
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispRECD04)'   
         
            GOTO QUIT_SP 
         END    	   	 	  	 	  
      END
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD04'		
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