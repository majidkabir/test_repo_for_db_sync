SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispUADelTsk01                                      */
/* Creation Date: 15-Aug-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-10158 - NIKE - PH Wave Release Task Enhancement         */   
/*                                                                      */
/* Called By: ntrPickDetailDelete when SP Setup in Storerconfig =       */
/*          : 'UnAllocDelTaskSP'                                        */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispUADelTsk01]   
      @c_PickDetailkey NVARCHAR(10)   
   ,  @b_Success       INT      OUTPUT 
   ,  @n_Err           INT      OUTPUT 
   ,  @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT = 1 
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @c_TaskDetailkey      NVARCHAR(10)   = ''  
         , @c_Wavekey            NVARCHAR(10)   = '' 
         , @c_UCCNo              NVARCHAR(20)   = '' 
         , @c_UOM                NVARCHAR(10)   = ''
         , @c_LocationType       NVARCHAR(10)   = ''

         , @b_Delete             BIT = 1

         , @CUR_DEL              CURSOR
                                             
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1

   IF OBJECT_ID('tempdb..#P_DELETED') IS NULL
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 35120
      SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Deleted PickDetail temp table not found. (ispTSKD05)'
      GOTO QUIT_SP  
   END
        
   SET @CUR_DEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT 
         D.TaskDetailKey
      ,  D.Wavekey
      ,  D.DropID
      ,  D.UOM
      ,  L.LocationType
   FROM #P_DELETED D
   JOIN LOC L WITH (NOLOCK) ON D.Loc = L.Loc
   WHERE D.PickDetailKey = @c_PickDetailkey
   AND   D.TaskDetailKey <> ''

   OPEN @CUR_DEL   
      
   FETCH NEXT FROM @CUR_DEL INTO @c_TaskDetailKey, @c_Wavekey, @c_UCCNo, @c_UOM, @c_LocationType

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      -----------------------------------------------
      -- Check Same TaskDetailKey in Other pickdetail
      -----------------------------------------------
      IF NOT EXISTS( SELECT 1 FROM PICKDETAIL(NOLOCK)  
                     WHERE  TaskDetailKey = @c_TaskDetailKey
                     AND    PickDetailKey <> @c_PickDetailkey
                     )             
      BEGIN    
         SET @b_Delete = 1
         ---------------------------------------------------
         -- IF Taskdetail is a General Replenishment record  
         ---------------------------------------------------
         IF @c_UCCNo <> '' AND @c_UOM = '7' AND @c_LocationType NOT IN ('DYNPPICK', 'DYNPICKP')-- Allocated UCC From BULK That has REplen Task
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM TASKDETAIL TD WITH (NOLOCK) 
                        WHERE TaskDetailkey = @c_TaskDetailkey
                        AND TaskType = 'RPF' 
                        AND SourceType = 'ispRLWAV20-REPLEN'
                        AND CaseID = @c_UCCNo
                        AND [Status] <> '9'  
                      )
            BEGIN
               SET @b_Delete = 0 
            END
         END
          
         IF @b_Delete = 1
         BEGIN 
            DELETE TASKDETAIL 
            WHERE  TaskDetailKey = @c_TaskDetailKey  
            AND    [Status] <> '9'    
                   
            IF @@ERROR <> 0  
            BEGIN 
               SET @n_Continue = 3 
               SET @n_Err = 35110
               SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err) + ': Delete TASKDETAIL Failed. (ispUADelTsk01)'
               GOTO QUIT_SP
            END
         END
         ELSE
         BEGIN
            UPDATE TASKDETAIL 
               SET SystemQty = 0
                  ,EditWho = SUSER_SNAME()
                  ,EditDate= GETDATE() 
                  ,TrafficCop = NULL
            WHERE  TaskDetailKey = @c_TaskDetailKey  
            AND    [Status] <> '9'    

            SET @n_Err = @@ERROR
                             
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3 
               SET @n_Err = 35110
               SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err) + ': UPDATE TASKDETAIL Failed. (ispUADelTsk01)'
               GOTO QUIT_SP
            END 
         END
      END                       
      FETCH NEXT FROM @CUR_DEL INTO @c_TaskDetailKey, @c_Wavekey, @c_UCCNo,@c_UOM, @c_LocationType
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispUADelTsk01'     
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