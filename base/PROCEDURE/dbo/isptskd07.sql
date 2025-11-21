SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD07                                          */
/* Creation Date: 11-Jun-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-13705 PH delete PA task remove related records          */   
/*                                                                      */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger            */
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

CREATE PROC [dbo].[ispTSKD07]   
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
           @c_ToLoc           NVARCHAR(10),
           @c_FromID          NVARCHAR(18)            
   
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action = 'DELETE'
   BEGIN      
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT D.FromID, D.ToLoc 
         FROM #DELETED D
         WHERE D.Storerkey = @c_Storerkey
         AND D.Tasktype = 'PA1'
         AND D.FromID <> ''
                
      OPEN Cur_Task
	    
	    FETCH NEXT FROM Cur_Task INTO @c_FromID, @c_ToLoc
            
	    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	    BEGIN	    	 
	    	 IF EXISTS(SELECT 1 FROM RFPUTAWAY(NOLOCK)
	    	           WHERE Storerkey = @c_Storerkey
	    	           AND FromID = @c_FromID 
	    	           AND SuggestedLoc = @c_ToLoc)
	    	 BEGIN
	    	 	  DELETE FROM RFPUTAWAY
            WHERE Storerkey = @c_Storerkey
	    	    AND FromID = @c_FromID 
	    	    AND SuggestedLoc = @c_ToLoc

        	  IF @@ERROR <> 0
     	      BEGIN
     	         SELECT @n_Continue = 3 
               SELECT @n_Err = 38010
               SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete RFPUTAWAY Failed. (ispTSKD07)'
            END
            ELSE
            BEGIN            	    	             
               UPDATE LOTXLOCXID WITH (ROWLOCK)
               SET PendingMoveIn = 0,
                   Trafficcop = NULL
               WHERE Storerkey = @c_Storerkey
               AND Loc = @c_ToLoc
               AND ID = @c_FromID

        	     IF @@ERROR <> 0
     	         BEGIN
     	            SELECT @n_Continue = 3 
                  SELECT @n_Err = 38020
                  SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD07)'
               END
            END	    	    	    	    
	    	 END
	    	 
   	     FETCH NEXT FROM Cur_Task INTO @c_FromID, @c_ToLoc
      END
 	    CLOSE Cur_Task
	    DEALLOCATE Cur_Task
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD07'    
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