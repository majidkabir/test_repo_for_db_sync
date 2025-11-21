SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPCKD01                                          */
/* Creation Date: 01-SEP-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15009 CN Natural Beauty delete pack update serial# info */   
/*                                                                      */
/* Called By: isp_PackdetailTrigger_Wrapper from Packdetail Trigger     */
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

CREATE PROC [dbo].[ispPCKD01]   
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
           @n_StartTCnt       INT
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('DELETE') 
	 BEGIN
      --delete pack by ucc	 	
	 	  UPDATE SERIALNO WITH (ROWLOCK)
	 	  SET SERIALNO.Pickslipno = ''
         ,SERIALNO.CartonNo = 0
         ,SERIALNO.LabelLine = ''
         ,SERIALNO.OrderLineNumber = ''
         ,SERIALNO.Orderkey = ''
         ,SERIALNO.Status = '1'
      FROM SERIALNO 
      JOIN PACKHEADER PH (NOLOCK) ON SERIALNO.Orderkey = PH.Orderkey
      JOIN #DELETED D ON D.Pickslipno = PH.Pickslipno AND SERIALNO.Storerkey = D.Storerkey AND SERIALNO.Sku = D.Sku AND SERIALNO.CartonNo = D.CartonNo AND SERIALNO.Userdefine01 = D.DropID 
      WHERE D.Storerkey = @c_Storerkey
      AND ISNULL(D.DropId,'') <> ''
	 	
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table PACKDETAIL. (ispPCKD01)'   
      
         GOTO QUIT_SP 
      END    	   	 	  	 	        

      --delete pack by sku 	
	 	  UPDATE SERIALNO WITH (ROWLOCK)
	 	  SET SERIALNO.Pickslipno = ''
         ,SERIALNO.CartonNo = 0
         ,SERIALNO.LabelLine = ''
         ,SERIALNO.OrderLineNumber = ''
         ,SERIALNO.Orderkey = ''
         ,SERIALNO.Status = '1'
      FROM SERIALNO 
      JOIN PACKHEADER PH (NOLOCK) ON SERIALNO.Orderkey = PH.Orderkey
      JOIN #DELETED D ON D.Pickslipno = PH.Pickslipno AND SERIALNO.Storerkey = D.Storerkey AND SERIALNO.Sku = D.Sku AND CAST(SERIALNO.OrderLineNumber AS INT) = D.CartonNo  
      WHERE D.Storerkey = @c_Storerkey
      AND ISNULL(D.DropId,'') = ''
	 	
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Delete Failed On Table PACKDETAIL. (ispPCKD01)'   
      
         GOTO QUIT_SP 
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPCKD01'		
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