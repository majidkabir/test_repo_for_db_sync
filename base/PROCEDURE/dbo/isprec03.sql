SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispREC03                                           */
/* Creation Date: 24-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1952 CN&SG Logitech ASN Status event catpure            */   
/*                                                                      */
/* Called By: isp_ReceiptTrigger_Wrapper from Receipt Trigger           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 20-Mar-2018	NJOW01   1.0  WMS-4360 Generate status 0,9 at same time */
/* 14-Mar-2019  NJOW02   1.1  WMS-8285 new logic trigger based on config*/
/************************************************************************/

CREATE PROC [dbo].[ispREC03]   
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
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
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
   WHERE Configkey = 'ReceiptTrigger_SP'
   AND Storerkey = @c_Storerkey
   AND Svalue = 'ispREC03'
   
   IF ISNULL(@c_Option1,'') NOT IN('1','2')
     SET @c_Option1 = '1'

   --capture receipt create status when insert
	 IF @c_Action IN('INSERT') AND @c_Option1 = '1' 
	 BEGIN	 		 	 
	 	  INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	  SELECT @c_TableName, I.Receiptkey, I.Storerkey, '0', I.Adddate, I.ExternReceiptkey, I.POkey, 'N'
	 	  FROM #INSERTED I
	 	  WHERE I.Storerkey = @c_Storerkey
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispREC03)'   
      
         GOTO QUIT_SP 
      END    	   	 	  
   END
   
	 IF @c_Action IN('UPDATE')  
	 BEGIN
      --Capture create receipt status when received first qty
      /* --removed and move to receiptdetail trigger instead at ispRECD04
      IF @c_Option1 = '2' 
      BEGIN      
         INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	     SELECT @c_TableName, I.Receiptkey, I.Storerkey, '0', 
	 	            MIN(RD.EditDate),--I.EditDate 
	 	            I.ExternReceiptkey,
	 	            I.POKey, 	 	         
	 	            'N'
	 	     FROM #INSERTED I
	 	     JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
	 	     JOIN RECEIPTDETAIL RD (NOLOCK) ON I.Receiptkey = RD.Receiptkey
	 	     WHERE I.Storerkey = @c_Storerkey
	 	     AND I.OpenQty < D.OpenQty
	 	     AND RD.QtyReceived > 0
	 	     AND NOT EXISTS(SELECT 1 FROM DOCSTATUSTRACK (NOLOCK)
      	                WHERE TableName = @c_TableName
      	                AND DocumentNo = I.Receiptkey
      	                AND Storerkey = I.Storerkey
      	                AND DocStatus = '0')	 	     	 	        	     
      	 GROUP BY I.Receiptkey, I.Storerkey, I.ExternReceiptkey, I.POKey 	 	                                     	                	
 	  	     	  
         SET @n_err = @@ERROR    
         
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispREC03)'   
         
            GOTO QUIT_SP 
         END    	   	 	  	 	  
      END
      */
      
      --Capture received status when finalize
      IF EXISTS (SELECT 1 FROM #INSERTED I 
	       JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
	       WHERE I.ASNStatus <> D.ASNStatus AND I.ASNStatus = '9' AND I.Storerkey = @c_Storerkey)
	    BEGIN   
	 	     DELETE FROM DOCSTATUSTRACK 
	 	     FROM #INSERTED I 
	 	     JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 	 	   
	 	     JOIN DOCSTATUSTRACK (NOLOCK) ON  DOCSTATUSTRACK.TableName = @c_TableName AND D.Storerkey = DOCSTATUSTRACK.Storerkey 
	 	                             AND I.Receiptkey = DOCSTATUSTRACK.DocumentNo AND I.ASNStatus = DOCSTATUSTRACK.DocStatus 
	 	     AND I.Storerkey = @c_Storerkey
         AND D.ASNStatus <> I.ASNStatus 
         AND I.ASNStatus = '9'	 	  
	 	     
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispREC03)'   
         
            GOTO QUIT_SP 
         END    	   	 	  	 	  	 	  
	    	
         INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	     SELECT @c_TableName, I.Receiptkey, I.Storerkey, I.ASNStatus, 
	 	            I.EditDate, 
	 	            I.ExternReceiptkey,
	 	            I.POKey, 	 	         
	 	            'N'
	 	     FROM #INSERTED I
	 	     JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
	 	     WHERE I.Storerkey = @c_Storerkey	 	  	
	 	     AND D.ASNStatus <> I.ASNStatus 
         AND I.ASNStatus = '9'	 	   	  
	 	     
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61930-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispREC03)'   
         
            GOTO QUIT_SP 
         END    	   	 	  
      END	 	  
   END	 	  

	 /*
	 IF @c_Action IN('DELETE') 
	 BEGIN
	 	  DELETE FROM DOCSTATUSTRACK 
	 	  FROM #DELETED D 
	 	  JOIN DOCSTATUSTRACK ON DOCSTATUSTRACK.TableName = @c_TableName AND D.Storerkey = DOCSTATUSTRACK.Storerkey AND D.Receiptkey = DOCSTATUSTRACK.DocumentNo 
	 	  WHERE D.Storerkey = @c_Storerkey

      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61930-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispREC03)'   
      
         GOTO QUIT_SP 
      END    	   	 	  	 	  	 	  	 	  
	 END 
   */
      
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC03'		
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