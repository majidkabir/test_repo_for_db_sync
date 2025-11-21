SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD03                                          */
/* Creation Date: 04-May-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 345748-UK JACKW-delete replen task update lotxlocxid.qtyreplen*/   
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

CREATE PROC [dbo].[ispTSKD03]   
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
                                         
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'DELETE'
   BEGIN
      IF EXISTS(SELECT 1 
                FROM #DELETED D 
                JOIN LOTXLOCXID LLI ON (D.Lot = LLI.Lot AND D.FromLoc = LLI.Loc AND D.FromID = LLI.ID) 
                WHERE D.Storerkey = @c_Storerkey
                AND D.Tasktype = 'DRP'
                AND D.Status NOT IN ('9','X')
                AND LLI.QtyReplen > 0)
      BEGIN
      	  UPDATE LOTXLOCXID WITH (ROWLOCK)
      	  SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen - D.Qty
      	  FROM #DELETED D
      	  JOIN LOTXLOCXID ON (D.Lot = LOTXLOCXID.Lot AND D.FromLoc = LOTXLOCXID.Loc AND D.FromID = LOTXLOCXID.ID)
          WHERE D.Storerkey = @c_Storerkey
          AND D.Tasktype = 'DRP'
          AND D.Status NOT IN ('9','X')
          AND LOTXLOCXID.QtyReplen > 0
      	        	  
      	  IF @@ERROR <> 0
      	  BEGIN
      	     SELECT @n_Continue = 3 
	           SELECT @n_Err = 38001
	           SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD03)'
             GOTO QUIT_SP 
          END
      END
      
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT D.Sku, D.FromLoc, D.FromID, SUM(D.Qty)
         FROM #DELETED D 
         WHERE D.Storerkey = @c_Storerkey
         AND D.Tasktype = 'DPK'
         AND D.Status NOT IN ('9','X')
         GROUP BY D.Sku, D.FromLoc, D.FromID

      OPEN Cur_Task
	    
	    FETCH NEXT FROM Cur_Task INTO @c_Sku, @C_FromLoc, @c_FromId, @n_Qty
            
	    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	    BEGIN	    	 
	    	 DECLARE Cur_LLI CURSOR FAST_FORWARD READ_ONLY FOR
	    	    SELECT LLI.Lot, LLI.QtyReplen
	    	    FROM LOTXLOCXID LLI (NOLOCK) 
	    	    WHERE LLI.Storerkey = @c_Storerkey
	    	    AND LLI.Sku = @c_Sku
	    	    AND LLI.Loc = @c_FromLoc
	    	    AND LLI.ID = @c_FromID
	    	    AND LLI.QtyReplen > 0
	    	    
         OPEN Cur_LLI
	       
	       FETCH NEXT FROM Cur_LLI INTO @c_Lot, @n_QtyReplen
	       
         WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2) AND @n_Qty > 0
         BEGIN
         	  IF @n_Qty >= @n_QtyReplen
         	  BEGIN
      	       UPDATE LOTXLOCXID WITH (ROWLOCK)
      	       SET LOTXLOCXID.QtyReplen = 0
               WHERE LOTXLOCXID.Lot = @c_Lot
               AND LOTXLOCXID.Loc = @c_FromLoc
               AND LOTXLOCXID.ID = @C_FromId
               AND LOTXLOCXID.QtyReplen > 0

      	       IF @@ERROR <> 0
      	       BEGIN
      	          SELECT @n_Continue = 3 
	                SELECT @n_Err = 38002
	                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD03)'
                  GOTO QUIT_SP 
               END
               
               SET @n_Qty = @n_Qty - @n_QtyReplen
         	  END
         	  ELSE
         	  BEGIN
      	       UPDATE LOTXLOCXID WITH (ROWLOCK)
      	       SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen - @n_Qty
               WHERE LOTXLOCXID.Lot = @c_Lot
               AND LOTXLOCXID.Loc = @c_FromLoc
               AND LOTXLOCXID.ID = @C_FromId
               AND LOTXLOCXID.QtyReplen > 0

      	       IF @@ERROR <> 0
      	       BEGIN
      	          SELECT @n_Continue = 3 
	                SELECT @n_Err = 38003
	                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD03)'
                  GOTO QUIT_SP 
               END
               
               SET @n_Qty = 0
         	  END
         	  
   	        FETCH NEXT FROM Cur_LLI INTO @c_Lot, @n_QtyReplen
         END
     	   CLOSE Cur_LLI
	       DEALLOCATE Cur_LLI	    	 
	    	 
   	     FETCH NEXT FROM Cur_Task INTO @c_Sku, @C_FromLoc, @c_FromId, @n_Qty
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD03'		
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