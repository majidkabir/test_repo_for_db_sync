SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPCKH01                                          */
/* Creation Date: 23-MAY-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1742 CN&SG Logitech Pack Status event catpure           */   
/*                                                                      */
/* Called By: isp_PackHeaderTrigger_Wrapper from PackHeader Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2019-10-27   TLTING01 1.1  missing NOLOCK                            */
/************************************************************************/

CREATE PROC [dbo].[ispPCKH01]   
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
           @c_TableName       NVARCHAR(30)         
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 SET @c_TableName = 'STSPACK'

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('INSERT') 
	 BEGIN	 	
	 	  INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	  SELECT @c_TableName, I.Orderkey, I.Storerkey, '0', I.Adddate, O.ExternOrderkey, I.Pickslipno, 'Y'
	 	  FROM #INSERTED I
	 	  JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey   --tlting01
	 	  WHERE I.Storerkey = @c_Storerkey
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispPCKH01)'   
      
         GOTO QUIT_SP 
      END    	   	 	  
   END
   
	 IF @c_Action IN('UPDATE') AND 
	    EXISTS (SELECT 1 FROM #INSERTED I 
	            JOIN #DELETED D ON I.Pickslipno = D.Pickslipno 
	            WHERE I.Status <> D.Status AND I.Status IN('0','9') AND I.Storerkey = @c_Storerkey)
	 BEGIN
	 	  DELETE FROM DOCSTATUSTRACK 
	 	  FROM #INSERTED I 
	 	  JOIN #DELETED D ON I.Pickslipno = D.Pickslipno 
	 	  JOIN DOCSTATUSTRACK (NOLOCK) ON  DOCSTATUSTRACK.TableName = @c_TableName AND D.Storerkey = DOCSTATUSTRACK.Storerkey 
	 	                               AND D.Orderkey = DOCSTATUSTRACK.DocumentNo AND I.Status = DOCSTATUSTRACK.DocStatus
	 	  AND I.Storerkey = @c_Storerkey
      AND I.Status <> D.Status AND I.Status IN('0','9') 	 	  
      
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispPCKH01)'   
      
         GOTO QUIT_SP 
      END    	   	 	  	 	  	 	  

      INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	  SELECT @c_TableName, I.Orderkey, I.Storerkey, I.Status, 
	 	         I.EditDate, 
	 	         O.ExternOrderkey, 	 	         
             I.Pickslipno,
	 	         'Y'
	 	  FROM #INSERTED I
	 	  JOIN #DELETED D ON I.Pickslipno = D.Pickslipno
	 	  JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey 
	 	  WHERE I.Storerkey = @c_Storerkey	 	  	 	  
	 	  AND D.Status <> I.Status 
	 	  AND I.Status IN('0','9') 
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispPCKH01)'   
      
         GOTO QUIT_SP 
      END    	   	 	  	 	  
   END	 	  

	 /*
	 IF @c_Action IN('DELETE') 
	 BEGIN
	 	  DELETE FROM DOCSTATUSTRACK 
	 	  FROM #DELETED D 
	 	  JOIN DOCSTATUSTRACK ON DOCSTATUSTRACK.TableName = @c_TableName AND D.Storerkey = DOCSTATUSTRACK.Storerkey AND D.Orderkey = DOCSTATUSTRACK.DocumentNo 
	 	  WHERE D.Storerkey = @c_Storerkey

      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61930-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispPCKH01)'   
      
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPCKH01'		
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