SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispTSKD09                                          */
/* Creation Date: 22-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16608 - HK LULULEMON - Delete ASTRPT task remove related*/  
/*          records                                                     */ 
/*                                                                      */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/
CREATE PROC [dbo].[ispTSKD09]   
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
           @n_RowRef          INT,
           @c_Lot             NVARCHAR(10),
           @c_Loc             NVARCHAR(10),
           @c_Id              NVARCHAR(18),
           @n_Qty             INT           
   
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action = 'UPDATE'
   BEGIN      
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT R.Rowref, R.LOT, R.SuggestedLOC, R.ID, R.Qty
         FROM #INSERTED I
         JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey)
         JOIN RFPutaway R (NOLOCK) ON (D.CaseId = R.CaseId)
         WHERE D.Storerkey = @c_Storerkey
         AND I.[Status] <> D.[Status]
         AND I.[Status] = 'X'
         AND ISNULL(D.CaseID,'') <> ''
         AND D.TaskType = 'ASTRPT'
       
      OPEN Cur_Task
       
      FETCH NEXT FROM Cur_Task INTO @n_RowRef, @c_Lot, @c_Loc, @c_ID, @n_Qty
            
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN           
         UPDATE LLI WITH (ROWLOCK)
         SET LLI.PendingMoveIN = LLI.PendingMoveIN - CASE WHEN (LLI.PendingMoveIN - @n_Qty) < 0 THEN LLI.PendingMoveIN ELSE @n_Qty END,
             LLI.TrafficCop = NULL
         FROM LOTXLOCXID LLI
         WHERE LLI.Lot = @c_Lot
         AND LLI.Loc = @c_Loc
         AND LLI.Id = @c_Id
      	
      	IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38005
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update LOTXLOCXID Failed. (ispTSKD09)'
         END
      	
         DELETE RFPutaway WITH (ROWLOCK)
         WHERE  RowRef = @n_RowRef
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38010
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete RFPUTAWAY Failed. (ispTSKD09)'
         END
         
         FETCH NEXT FROM Cur_Task INTO @n_RowRef, @c_Lot, @c_Loc, @c_ID, @n_Qty
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD09'    
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