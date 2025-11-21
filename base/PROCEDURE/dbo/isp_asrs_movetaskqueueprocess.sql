SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_ASRS_MoveTaskQueueProcess                       */
/* Creation Date: 23 Sep 2014                                           */
/* Copyright: IDS                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Generic stor proc that Query TCPSocket_Process table based  */
/*          on ProjectName and MessageName                              */
/*                                                                      */
/* Called By: Exceed / RDT                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ASRS_MoveTaskQueueProcess]
           @b_Success            INT            OUTPUT  
         , @n_err                INT            OUTPUT    
         , @c_ErrMsg             NVARCHAR(215)  OUTPUT  
         , @b_debug              INT = 0  

AS 
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_MessageName        NVARCHAR(15) 
         , @c_MessageType        NVARCHAR(10) 
         , @c_TaskDetailKey      NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)  
         , @c_FromLoc            NVARCHAR(10)  
         , @c_ToLoc              NVARCHAR(10)  
         , @c_Priority           NVARCHAR(10)  
         , @n_continue           INT

   -- Default Parameter
   SET @c_MessageName         = 'MOVE'
   SET @c_MessageType         = 'SEND'
   SET @c_TaskDetailKey       = '' 
   SET @c_FromID              = '' 
   SET @c_FromLoc             = '' 
   SET @c_ToLoc               = '' 
   SET @c_Priority            = '' 
   SET @n_continue            = 1

   /*********************************************/
   /* Query Start                               */
   /*********************************************/

   DECLARE C_FullPalletTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TD.TaskDetailKey, TD.Priority, TD.FromID, TD.FromLoc, TD.ToLoc
   FROM TaskDetail TD WITH (NOLOCK) 
   INNER JOIN LOTxLOCxID LLI WITH (NOLOCK)
   ON LLI.ID = TD.FromID AND LLI.Qty > 0 and LLI.ID <> ''
   INNER JOIN LOC LOC WITH (NOLOCK) 
   ON LOC.Loc = LLI.Loc AND LOC.LocationCategory = 'ASRS'
   WHERE TD.Status = 'Q' AND TD.TaskType IN ('ASRSMV','ASRSQC')

   OPEN C_FullPalletTask  

   FETCH NEXT FROM C_FullPalletTask INTO @c_TaskDetailKey, @c_Priority, @c_FromID, @c_FromLoc, @c_ToLoc 
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
           
      --Start Call WCS message.  
      EXEC isp_TCP_WCS_MsgProcess  
           @c_MessageName     = @c_MessageName
         , @c_MessageType     = @c_MessageType
         , @c_OrigMessageID   = ''
         , @c_PalletID        = @c_FromID
         , @c_FromLoc         = ''
         , @c_ToLoc           = @c_ToLoc        
         , @c_Priority        = @c_Priority         
         , @c_TaskDetailKey   = @c_TaskDetailKey  	
         , @b_debug           = @b_debug
         , @b_Success         = @b_Success OUTPUT
         , @n_Err             = @n_Err OUTPUT
         , @c_ErrMsg          = @c_ErrMsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3  
         SET @b_Success = 0
         SET @n_Err = 68001
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                        + ': Fail while executing isp_TCP_WCS_MsgProcess (isp_ASRS_MoveTaskQueueProcess) ( ' 
                        + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO NEXT_LOOP
      END 

      INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)
      VALUES (@c_FromID, @c_TaskDetailKey, @c_MessageType, @c_FromLoc, @c_ToLoc, GETDATE(), SYSTEM_USER, @n_Err, @c_ErrMsg)
          
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3  
         SET @b_Success = 0
         SET @n_Err = 68002
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                        + ': INSERT into GTMLog failed (isp_ASRS_MoveTaskQueueProcess) ( ' 
                        + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO NEXT_LOOP
      END 

      -- If call Success, Tag Status =1
      UPDATE TASKDETAIL WITH (ROWLOCK) SET STATUS = 1
      WHERE TaskDetailKey = @c_TaskDetailKey AND STATUS = 'Q'

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3  
         SET @b_Success = 0
         SET @n_Err = 68003
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                        + ': Update TaskDetail failed (isp_ASRS_MoveTaskQueueProcess) ( ' 
                        + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT_SP
      END 

      NEXT_LOOP:
     
   FETCH NEXT FROM C_FullPalletTask INTO @c_TaskDetailKey, @c_Priority, @c_FromID, @c_FromLoc, @c_ToLoc 

   END  
   CLOSE C_FullPalletTask 
   DEALLOCATE C_FullPalletTask  

  
   QUIT_SP:

END

GO