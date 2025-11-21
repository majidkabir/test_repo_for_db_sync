SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_DuplicateReceiptInfo                           */
/* Creation Date: 23-JUL-2021                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17567 - Duplicate receiptinfo                           */   
/*                                                                      */
/* Called By: ASN Screen RCM duplicate ASN                              */
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

CREATE PROC [dbo].[isp_DuplicateReceiptInfo]   
   @c_OriginReceiptkey  NVARCHAR(10),
   @c_NewReceiptkey     NVARCHAR(15),  
   @b_Success           INT      OUTPUT,
   @n_Err               INT      OUTPUT, 
   @c_ErrMsg            NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue      INT,
           @n_StartTCnt     INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF NOT EXISTS(SELECT 1 FROM RECEIPTINFO(NOLOCK) WHERE Receiptkey = @c_NewReceiptkey)
   BEGIN
   	  INSERT INTO RECEIPTINFO (ReceiptKey,
                               EcomReceiveId,
                               EcomOrderId,
                               ReceiptAmount,
                               Notes,
                               Notes2,
                               StoreName)
      SELECT @c_NewReceiptkey,      
             EcomReceiveId,   
             EcomOrderId,     
             ReceiptAmount,   
             Notes,           
             Notes2,          
             StoreName   
      FROM RECEIPTINFO (NOLOCK)
      WHERE Receiptkey = @c_OriginReceiptkey                                   
      
      SET @n_err = @@ERROR         
      
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61800-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table RECEIPTINFO. (isp_DuplicateReceiptInfo)'         
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_DuplicateReceiptInfo'		
	    RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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