SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD04                                           */
/* Creation Date: 25-APR-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1742 CN&SG Logitech Orders Status event catpure         */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 15-Sep-2017  NJOW01   1.0  Fix status not update issue               */
/* 19-Feb-2019  NJOW02   1.1  WMS-7965 capture cancel status            */
/************************************************************************/

CREATE PROC [dbo].[ispORD04]   
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
	 SET @c_TableName = 'STSORDERS'

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('INSERT') 
	 BEGIN	 	
	 	  INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	  SELECT @c_TableName, I.Orderkey, I.Storerkey, '0', I.Adddate, I.ExternOrderkey, I.Orderkey, 'Y'
	 	  FROM #INSERTED I
	 	  WHERE I.Storerkey = @c_Storerkey
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispORD04)'   
      
         GOTO QUIT_SP 
      END    	   	 	  
   END
   
	 IF @c_Action IN('UPDATE') AND 
	    EXISTS (SELECT 1 FROM #INSERTED I 
	            JOIN #DELETED D ON I.Orderkey = D.Orderkey 
	            JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
	            WHERE O.Status <> D.Status AND O.Status IN('2','3','5','9','CANC') AND I.Storerkey = @c_Storerkey)
	 BEGIN
	 	  DELETE FROM DOCSTATUSTRACK 
	 	  FROM #INSERTED I 
	 	  JOIN #DELETED D ON I.Orderkey = D.Orderkey 
	 	  JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey  AND D.Status <> O.Status AND O.Status IN('2','3','5','9','CANC') 
	 	  JOIN DOCSTATUSTRACK (NOLOCK) ON  DOCSTATUSTRACK.TableName = @c_TableName AND D.Storerkey = DOCSTATUSTRACK.Storerkey 
	 	                          AND D.Orderkey = DOCSTATUSTRACK.DocumentNo AND O.Status = DOCSTATUSTRACK.DocStatus
	 	  AND I.Storerkey = @c_Storerkey
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispORD04)'   
      
         GOTO QUIT_SP 
      END    	   	 	  	 	  	 	  

      INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Userdefine01, Userdefine02, Finalized)
	 	  SELECT @c_TableName, I.Orderkey, I.Storerkey, O.Status, 
	 	         I.EditDate, 
	 	         I.ExternOrderkey, 	 	         
	 	         CASE WHEN O.Status = '2' THEN
	 	                 I.Loadkey
	 	              WHEN O.Status = '3' THEN
	 	                 ISNULL(PH.Pickheaderkey,'')
	 	              WHEN O.Status = '5' THEN
	 	                 ISNULL(PH.Pickheaderkey,'')
	 	              WHEN O.Status = '9' THEN
	 	                 I.Mbolkey
	 	              WHEN O.Status = 'CANC' THEN --NJOW02
	 	                 I.Orderkey   
	 	         END, 
	 	         'Y'
	 	  FROM #INSERTED I
	 	  JOIN #DELETED D ON I.Orderkey = D.Orderkey 
	 	  JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey AND D.Status <> O.Status AND O.Status IN('2','3','5','9','CANC') 
	 	  LEFT JOIN PICKHEADER PH (NOLOCK) ON I.Orderkey = PH.Orderkey
	 	  WHERE I.Storerkey = @c_Storerkey	 	  	 	  
	 	  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Insert Failed On Table DOCSTATUSTRACK. (ispORD04)'   
      
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
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table DOCSTATUSTRACK. (ispORD04)'   
      
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD04'		
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