SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCANOR01                                         */
/* Creation Date: 06-Mar-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 331723-SG-Melion order cancellation                         */   
/*                                                                      */
/* Called By: isp_OrderCancel_Wrapper from Orders Update Trigger        */
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

CREATE PROC [dbo].[ispCANOR01]   
   @c_Orderkey NVARCHAR(10),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
	 UPDATE TASKDETAIL WITH (ROWLOCK)
	 SET Holdkey = Status,
	     Status = 'X'
	 WHERE Orderkey = @c_Orderkey
	 AND SourceType = 'nspLPRTSK3'
	 AND Tasktype = 'ASRSPK'
	 AND Status <> '9'
	 
	 SET @n_Err = @@ERROR
	                    
   IF @n_Err <> 0
   BEGIN
   	  SELECT @n_Continue = 3 
	    SELECT @n_Err = 38002
	    SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update Taskdetail Failed. (ispCANOR01)'
      GOTO QUIT_SP 
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispCANOR01'		
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