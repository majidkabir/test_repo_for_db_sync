SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD01                                          */
/* Creation Date: 05-May-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 338845-CN-ANF Cancel Task at Front End to cancel loc booking*/   
/*                                                                      */
/* Called By: isp_TaskDetailTrigger_Wrapper from Taskdetail Trigger     */
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

CREATE PROC [dbo].[ispTSKD01]   
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
     
   DECLARE @n_Continue      INT,
           @n_StartTCnt     INT,
           @n_rowref        INT,
           @c_Lot           NVARCHAR(10),
           @c_Loc           NVARCHAR(10),
           @c_Id            NVARCHAR(18),
           @n_Qty           INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_Action = 'UPDATE'
   BEGIN   
      DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
   	     SELECT R.Rowref, R.LOT, R.SuggestedLOC, R.ID, R.Qty
         FROM #INSERTED I
         JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey)
         JOIN RFPutaway R (NOLOCK) ON (I.CaseId = R.CaseId)
         WHERE I.Storerkey = @c_Storerkey
         AND I.Status <> D.Status
         AND I.Status = 'X'
         AND ISNULL(I.CaseID,'') <> ''
         AND (I.TaskType = 'PA' OR (I.TaskType = 'RPF' AND I.SourceType='ispTransferAllocation'))

      OPEN CUR_TASK            
      
      FETCH NEXT FROM CUR_TASK INTO @n_RowRef, @c_Lot, @c_Loc, @c_ID, @n_Qty
            
      WHILE @@FETCH_STATUS <> -1     
      BEGIN         
	       UPDATE LLI WITH (ROWLOCK)
	       SET LLI.PendingMoveIN = LLI.PendingMoveIN - CASE WHEN (LLI.PendingMoveIN - @n_Qty) < 0 THEN LLI.PendingMoveIN ELSE @n_Qty END,
	           LLI.TrafficCop = NULL
	       FROM LOTXLOCXID LLI
	       WHERE LLI.Lot = @c_Lot
	       AND LLI.Loc = @c_Loc
	       AND LLI.Id = @c_Id
	       	       	 	 
	       SET @n_Err = @@ERROR
	                          
         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3 
	          SELECT @n_Err = 38001
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD01)'
            GOTO QUIT_SP 
         END      
         
         DELETE RFPutaway WITH (ROWLOCK)
         WHERE  RowRef = @n_RowRef         

	       SET @n_Err = @@ERROR
	                          
         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3 
	          SELECT @n_Err = 38002
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete RFPUTAWAY Failed. (ispTSKD01)'
            GOTO QUIT_SP 
         END      
      	
         FETCH NEXT FROM CUR_TASK INTO @n_RowRef, @c_Lot, @c_Loc, @c_ID, @n_Qty
      END
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK       	  
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD01'		
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