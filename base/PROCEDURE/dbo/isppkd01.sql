SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKD01                                           */
/* Creation Date: 29-Apr-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 315021-SG-Melion unallocation update and checking           */   
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
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

CREATE PROC [dbo].[ispPKD01]   
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
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
   IF @c_Action = 'UPDATE'    
   BEGIN    
      IF EXISTS (SELECT 1    
                FROM #INSERTED I    
                JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey    
                JOIN TASKDETAIL TD (NOLOCK) ON TD.TaskdetailKey = I.Taskdetailkey    
                WHERE TD.Status NOT IN('X','0','9')    
                AND TD.TaskType IN('ASRSPK','GTMJOB')    
                AND I.Storerkey = @c_Storerkey  
                AND I.Status NOT IN ('4', '9')        --(Wan01)  
                AND I.Qty <> D.Qty )                  --(Wan01)   
                --AND I.Qty <> D.Qty    
                --AND I.Qty = 0)    
     BEGIN    
        SELECT @n_Continue = 3     
        SELECT @n_Err = 38000    
        SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PickDetail Zero Qty Failed. Some Pallet Of The Order Have Been Called Out From ASRS (ispPKD01)'    
         GOTO QUIT_SP           
     END          
   END          
      	 
	 IF @c_Action = 'DELETE'
	 BEGIN
	 	  IF EXISTS (SELECT 1
	 	             FROM #DELETED D
	 	             JOIN TASKDETAIL TD (NOLOCK) ON D.TaskdetailKey = TD.Taskdetailkey
	 	             WHERE TD.Status NOT IN('X','0','9')
	 	             AND TD.TaskType IN('ASRSPK','GTMJOB')
	 	             AND D.Storerkey = @c_Storerkey)
	 	  BEGIN
      	 SELECT @n_Continue = 3 
	       SELECT @n_Err = 38010
	       SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete PickDetail Failed. Some Pallet Of The Order Have Been Called Out From ASRS (ispPKD01)'
          GOTO QUIT_SP 	 	  	
	 	  END
	 	  
	    SELECT Id, SUM(Qty) AS DelQty
	    INTO #DELETED_ID
	    FROM #DELETED
	    WHERE Storerkey = @c_Storerkey
	    AND ISNULL(Id,'') <> ''
	    GROUP BY Id
	    
	    SELECT DI.Id
	    INTO #ID
	    FROM #DELETED_ID DI
	    JOIN LOTXLOCXID LLI (NOLOCK) ON DI.Id = LLI.Id
	    AND LLI.Storerkey = @c_Storerkey
	    GROUP BY DI.Id, DI.DelQty 
	    HAVING SUM(LLI.QtyAllocated + LLI.QtyPicked) - DI.DelQty <= 0
	    	 
	    UPDATE ID WITH (ROWLOCK)
	    SET ID.PalletFlag = ''
	    FROM ID 
	    JOIN #ID ON ID.Id = #ID.Id  
	    
	    SET @n_Err = @@ERROR
	                       
      IF @n_Err <> 0
      BEGIN
      	 SELECT @n_Continue = 3 
	       SELECT @n_Err = 38020
	       SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ID Failed. (ispPKD01)'
         GOTO QUIT_SP 
      END   
   END
      
   QUIT_SP:
   
   IF OBJECT_ID('tempdb..#DELETED_ID') IS NOT NULL
   BEGIN
      DROP TABLE #DELETED_ID
   END

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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD01'		
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