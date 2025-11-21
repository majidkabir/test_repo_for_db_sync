SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD02                                          */
/* Creation Date: 12-May-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 315198-SG-Merlian-WCS Task Update Msg Trigger Point         */   
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
/* 29-Mar-2016  TKLIM    1.0  Pass in TaskDetailKey to MsgProcess (TK01)*/
/************************************************************************/

CREATE PROC [dbo].[ispTSKD02]   
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
           @c_TskUpdCode      NVARCHAR(10),
           @c_PalletID        NVARCHAR(18),
           @C_Priority        NVARCHAR(2),
           @c_TaskDetailKey   NVARCHAR(10)   --TK01
                              
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'UPDATE'
   BEGIN
      IF EXISTS(SELECT 1 
                FROM #INSERTED I 
                JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey) 
                WHERE D.Priority <> I.Priority
                AND I.Storerkey = @c_Storerkey
                AND (I.Tasktype NOT IN ('ASRSPK', 'ASRSQC', 'ASRSTRF', 'ASRSCC', 'ASRSMV')
                OR I.Status IN ('9','X')))
      BEGIN
      	  SELECT @n_Continue = 3 
	       SELECT @n_Err = 38001
	       SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Invalid status/tasktype to change priority. (ispTSKD02)'
         GOTO QUIT_SP 
      END
      
      IF EXISTS(SELECT 1 
                FROM #INSERTED I 
                JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey) 
                WHERE D.Status <> I.Status
                AND I.Storerkey = @c_Storerkey             
                AND I.Status = 'X'
                AND (I.Tasktype NOT IN ('ASRSPA', 'ASRSPK', 'ASRSQC', 'ASRSTRF', 'ASRSCC', 'ASRSMV')
                OR I.Status <> '0'))
      BEGIN
      	  SELECT @n_Continue = 3 
	       SELECT @n_Err = 38002
	       SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Invalid status/tasktype to cancel task. (ispTSKD02)'
         GOTO QUIT_SP 
      END
      
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT 'P' AS tskupdcode, I.FromID, I.Priority, I.Taskdetailkey      --TK01
         FROM #INSERTED I 
         JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey) 
         WHERE D.Priority <> I.Priority
         AND I.Storerkey = @c_Storerkey
         UNION ALL
         SELECT DISTINCT 'C' AS tskupdcode, I.FromID, '' AS Priority, I.Taskdetailkey  --TK01
         FROM #INSERTED I 
         JOIN #DELETED D ON (I.Taskdetailkey = D.Taskdetailkey) 
         WHERE D.Status <> I.Status
         AND I.Status = 'X'      
         AND I.Storerkey = @c_Storerkey   
         
      OPEN Cur_Task
	    
	    FETCH NEXT FROM Cur_Task INTO @c_TskUpdCode, @c_PalletID, @C_Priority, @c_TaskDetailKey  --TK01
      
      BEGIN TRAN
      
	    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	    BEGIN
	    	  SET @b_Success = 1
	    	  
	    	  EXEC isp_TCP_WCS_MsgProcess 
	    	      @c_MessageName = 'TASKUPDATE', 
	    	      @c_MessageType = 'SEND', 
	    	      @c_TaskDetailKey = @c_TaskDetailKey,   --TK01
	    	      @c_PalletID = @c_PalletID, 
	    	      @c_Priority = @c_Priority, 
	    	      @c_UD1 = @c_TskUpdCode,
	    	      @b_Success = @b_Success OUTPUT,
             @n_Err = @n_Err OUTPUT, 
             @c_ErrMsg = @c_ErrMsg OUTPUT
	    	      
         IF @b_Success <> 1
         BEGIN
         	 SELECT @n_Continue = 3 
	          SELECT @c_Errmsg = 'Send WCS TCP Message Failed. ' + RTRIM(LTRIM(ISNULL(@c_ErrMsg,''))) + ' (ispTSKD02)'
         END      
      
	       FETCH NEXT FROM Cur_Task INTO @c_TskUpdCode, @c_PalletID, @C_Priority, @c_TaskDetailKey  --TK01
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD02'		
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