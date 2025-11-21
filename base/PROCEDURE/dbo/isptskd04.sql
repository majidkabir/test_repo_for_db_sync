SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD04                                          */
/* Creation Date: 04-May-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-649 TW-Can/del replen task update lotxlocxid.qtyreplen  */   
/*                                                                      */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger            */
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

CREATE PROC [dbo].[ispTSKD04]   
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
           @c_Sku             NVARCHAR(15),
           @c_Lot             NVARCHAR(10),
           @c_FromLoc         NVARCHAR(10),
           @c_FromID          NVARCHAR(18),
           @n_Qty             INT,
           @n_QtyReplen       INT
                                         
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'DELETE'
   BEGIN
   	  --delete task
      IF EXISTS(SELECT 1 
                FROM #DELETED D 
                JOIN LOTXLOCXID LLI ON (D.Lot = LLI.Lot AND D.FromLoc = LLI.Loc AND D.FromID = LLI.ID) 
                WHERE D.Storerkey = @c_Storerkey
                AND D.Tasktype = 'RPF'
                AND D.Status <= '4'
                AND LLI.QtyReplen > 0)
      BEGIN
      	  UPDATE LOTXLOCXID WITH (ROWLOCK)
      	  SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen - CASE WHEN LOTXLOCXID.QtyReplen < D.Qty THEN LOTXLOCXID.QtyReplen ELSE D.Qty END 
      	  FROM #DELETED D
      	  JOIN LOTXLOCXID ON (D.Lot = LOTXLOCXID.Lot AND D.FromLoc = LOTXLOCXID.Loc AND D.FromID = LOTXLOCXID.ID)
          WHERE D.Storerkey = @c_Storerkey
          AND D.Tasktype = 'RPF'
          AND D.Status <= '4'
          AND LOTXLOCXID.QtyReplen > 0
      	        	  
      	  IF @@ERROR <> 0
      	  BEGIN
      	     SELECT @n_Continue = 3 
	           SELECT @n_Err = 38001
	           SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD04)'
             GOTO QUIT_SP 
          END
      END     
   END 	 	 	       
   
   IF @c_Action = 'UPDATE' --AND @n_IsRDT <> 1
   BEGIN
   	  --Cancel task
      IF EXISTS(SELECT 1 
                FROM #INSERTED I 
                JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
                JOIN LOTXLOCXID LLI ON (I.Lot = LLI.Lot AND I.FromLoc = LLI.Loc AND I.FromID = LLI.ID) 
                WHERE I.Storerkey = @c_Storerkey
                AND I.Tasktype = 'RPF'
                AND D.Status <> '9'
                AND I.Status <> D.Status
                AND I.Status = 'X'
                AND LLI.QtyReplen > 0)   	  
      BEGIN
     	   UPDATE LOTXLOCXID WITH (ROWLOCK)
     	   SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen - CASE WHEN LOTXLOCXID.QtyReplen < D.Qty THEN LOTXLOCXID.QtyReplen ELSE D.Qty END 
         FROM #INSERTED I 
         JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
         JOIN LOTXLOCXID ON (I.Lot = LOTXLOCXID.Lot AND I.FromLoc = LOTXLOCXID.Loc AND I.FromID = LOTXLOCXID.ID) 
         WHERE I.Storerkey = @c_Storerkey
         AND I.Tasktype = 'RPF'
         AND D.Status <> '9'
         AND I.Status <> D.Status
         AND I.Status = 'X'
         AND LOTXLOCXID.QtyReplen > 0

      	 IF @@ERROR <> 0
      	 BEGIN
      	    SELECT @n_Continue = 3 
	          SELECT @n_Err = 38002
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD04)'
            GOTO QUIT_SP 
         END         
      END          

      --reverse cancelled task
      IF EXISTS(SELECT 1 
                FROM #INSERTED I 
                JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
                JOIN LOTXLOCXID LLI ON (I.Lot = LLI.Lot AND I.FromLoc = LLI.Loc AND I.FromID = LLI.ID) 
                WHERE I.Storerkey = @c_Storerkey
                AND I.Tasktype = 'RPF'
                AND D.Status = 'X'
                AND I.Status <= '4'
                AND I.Status <> D.Status)   	  
      BEGIN
     	   UPDATE LOTXLOCXID WITH (ROWLOCK)
     	   SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen + I.Qty 
         FROM #INSERTED I 
         JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
         JOIN LOTXLOCXID ON (I.Lot = LOTXLOCXID.Lot AND I.FromLoc = LOTXLOCXID.Loc AND I.FromID = LOTXLOCXID.ID) 
         WHERE I.Storerkey = @c_Storerkey
         AND I.Tasktype = 'RPF'
         AND D.Status = 'X'
         AND I.Status <= '4'
         AND I.Status <> D.Status

      	 IF @@ERROR <> 0
      	 BEGIN
      	    SELECT @n_Continue = 3 
	          SELECT @n_Err = 38003
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD04)'
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD04'		
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