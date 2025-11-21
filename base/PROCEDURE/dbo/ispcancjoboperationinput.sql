SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure:ispCancJobOperationInput                            */  
/* Creation Date: 23-JUN-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#318089 - Project Merlion - VAP Add or Delete Work Order */
/*          Component                                                   */ 
/*                                                                      */  
/* Called By: ntrWorkOrdertRequestInputsDelete &  isp_JobCancWO         */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 11-JAN-2016 Wan01    1.1   SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	
/************************************************************************/  
CREATE PROC [dbo].[ispCancJobOperationInput] 
     @c_JobKey             NVARCHAR(10)  
   , @c_Workorderkey       NVARCHAR(10)
   , @c_WkOrdReqInputsKey  NVARCHAR(10) = ''
   , @b_Success            INT           OUTPUT    
   , @n_Err                INT           OUTPUT    
   , @c_ErrMsg             NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue             INT     
         ,  @n_StartTCnt            INT  -- Holds the current transaction count  

         ,  @c_JobLineNo            NVARCHAR(5)
         ,  @c_TaskDetailkey        NVARCHAR(10)
         ,  @c_GroupKey             NVARCHAR(10)
         ,  @c_TaskType             NVARCHAR(10)
         ,  @c_TaskType_Prev        NVARCHAR(10)
         ,  @c_SourceType           NVARCHAR(10)
         ,  @c_Lot                  NVARCHAR(10)
         ,  @c_FromLoc              NVARCHAR(10)   
         ,  @c_ID                   NVARCHAR(18)
         ,  @c_PickMethod           NVARCHAR(10)
         ,  @n_WOMoveKey            INT

         ,  @c_StepNumber           NVARCHAR(10)
         ,  @n_StepQty              INT 
         ,  @n_QtyReserved          INT
         ,  @n_QtyToProcess         INT
         ,  @n_QtyToReverse         INT
         ,  @n_QtyRemainToRev       INT
         ,  @n_Qty                  INT
         ,  @n_PendingTasks         INT      
         ,  @n_QtyOnHold            INT

         ,  @n_QtyItemsOrd          INT
         ,  @n_QtyItemsRes          INT
         ,  @n_QtyItemsNeed         INT
         ,  @n_QtyNonInvOrd         INT
         ,  @b_Reversed             INT

         ,  @b_ItemFound            INT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 
   SET @c_SourceType = 'VAS'

   IF EXISTS ( SELECT 1 
               FROM WORKORDERJOBDETAIL WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND JobStatus IN ('8', '9')
             )
   BEGIN
      GOTO QUIT_SP
   END
   
   BEGIN TRAN
   DECLARE CUR_JOBLN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobKey
         ,JobLine
         ,Stepnumber
         ,StepQty
         ,WkOrdReqInputsKey
   FROM VASREFKEYLOOKUP WITH (NOLOCK)
   WHERE JobKey = @c_JobKey 
   AND   WorkOrderkey = @c_Workorderkey
   AND   WkOrdReqInputsKey <> ''
   AND   ((WkOrdReqInputsKey = @c_WkOrdReqInputsKey ) OR @c_WkOrdReqInputsKey = '')

   OPEN CUR_JOBLN
   
   FETCH NEXT FROM CUR_JOBLN INTO @c_JobKey
                                 ,@c_JobLineNo
                                 ,@c_Stepnumber
                                 ,@n_StepQty
                                 ,@c_WkOrdReqInputsKey
            
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      --(Wan01) - START
      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL TD WITH (NOLOCK)
                  JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                  WHERE TLKUP.Jobkey = @c_JobKey
                  AND   TLKUP.JobLine= @c_JobLineNo
                  AND   TD.SourceType = @c_SourceType
                  AND   TD.Status NOT IN ('S','0','X','9')
                  )
                  --AND   TaskType <> 'FG'
                  --AND   ((Status > '0' AND Status <= '9')
                  --OR      Status = 'H'
                  --      )
                  --AND EXISTS (SELECT 1
                  --            FROM TASKDETAIL RF WITH (NOLOCK)
                  --            WHERE RF.Sourcetype = @c_SourceType
                  --            AND RF.Sourcekey = @c_JobKey + @c_JobLineNo
                  --            AND RF.RefTaskKey = TASKDETAIL.RefTaskKey
      --(Wan01) - END
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63505  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'VAS Pick/Move Task are in Progress/Completed. Delete Abort. (ispCancJobOperationInput)' 
         GOTO QUIT_SP
      END

      DECLARE CUR_JOBMV CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WOJM.WOMoveKey
            ,Lot = CASE WHEN WOJM.PickMethod = '1' THEN '' ELSE WOJM.Lot END
            ,Loc = CASE WHEN WOJM.PickMethod = '1' THEN '' ELSE WOJM.FromLoc END
            ,WOJM.ID
            ,WOJM.Qty
            ,WOJM.PickMethod
            ,TLKUP.TaskDetailKey
      FROM WORKORDERJOBMOVE WOJM  WITH (NOLOCK)
      JOIN JOBTASKLOOKUP    TLKUP WITH (NOLOCK) ON (WOJM.JobKey = TLKUP.JobKey)
                                                AND(WOJM.JobLine= TLKUP.JobLine)
                                                AND(WOJM.WOMovekey= TLKUP.WOMovekey)
      JOIN TASKDETAIL       TD   WITH (NOLOCK) ON (TLKUP.TaskDetailKey = TD.Taskdetailkey) --(Wan01)
      WHERE WOJM.JobKey = @c_JobKey
      AND   WOJM.JobLine= @c_JobLineNo
      AND   WOJM.Qty > 0

      ORDER BY CASE WHEN TD.Status = 'S' THEN 1 
                    WHEN TD.Status = '0' THEN 2
                    ELSE 9 END                                    --(Wan01)
              ,WOJM.Qty                                           --(Wan01)

      OPEN CUR_JOBMV
   
      FETCH NEXT FROM CUR_JOBMV INTO @n_WOMoveKey
                                    ,@c_Lot
                                    ,@c_FromLoc
                                    ,@c_ID
                                    ,@n_QtyReserved
                                    ,@c_PickMethod
                                    ,@c_GroupKey
      WHILE @@FETCH_STATUS <> -1   
      BEGIN
         IF @n_StepQty <= 0 
         BEGIN
            BREAK
         END

         SET @n_QtyToReverse = CASE WHEN @n_StepQty < @n_QtyReserved THEN @n_StepQty ELSE @n_QtyReserved END 

         /*(Wan01) - START
         SELECT TOP 1 @c_GroupKey = RefTaskKey
         FROM TASKDETAIL WITH (NOLOCK)
         WHERE Sourcetype = @c_SourceType
         AND Sourcekey = @c_JobKey + @c_JobLineNo
         AND Lot       = @c_Lot
         AND FromLoc   = @c_FromLoc
         AND FromID    = @c_ID
         AND PickDetailKey = CASE WHEN @c_PickMethod = 1 THEN PickDetailKey ELSE CONVERT(NVARCHAR(10),@n_WOMovekey) END
         AND Status IN ('S','0','9')
         ORDER BY CASE Status WHEN 'S' THEN 1
                              WHEN '0' THEN 5
                              WHEN '9' THEN 9
                              END
                  ,Qty
                  ,Taskdetailkey 
         (Wan01) - END */
       
         --SET @n_QtyRemainToRev = @n_QtyToReverse                         --(Wan01)
         DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT TD.TaskDetailkey
               ,TD.TaskType
               ,TD.Qty
         FROM TASKDETAIL TD WITH (NOLOCK)
         WHERE TD.SourceType = @c_SourceType
         AND   TD.GroupKey = @c_GroupKey
         --AND TD.PickDetailKey = CONVERT(NVARCHAR(10), @n_WOMoveKey)      --(Wan01)
         AND TD.Status IN ( 'S', '0' )
         ORDER BY TD.TaskType
               ,  TD.TaskDetailkey

         OPEN CUR_TASK

         FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                    ,  @c_TaskType
                                    ,  @n_Qty
       
         WHILE @@FETCH_STATUS <> -1  --AND @n_QtyRemainToRev > 0
         BEGIN
--            IF @c_TaskType NOT IN ( 'MV', 'ML' )
--            BEGIN
--               SET @n_Qty = @n_Qty - (CASE WHEN @n_Qty > @n_QtyToReverse THEN @n_QtyToReverse ELSE @n_Qty END)
--            END
--            ELSE
--            BEGIN
--               IF @c_TaskType_Prev <> @c_TaskType
--               BEGIN
--                  SET @n_QtyRemainToRev = @n_QtyToReverse  
--               END
--
--               IF @n_Qty > @n_QtyRemainToRev 
--               BEGIN 
--                  SET @n_Qty = @n_Qty - @n_QtyRemainToRev
--                  SET @n_QtyRemainToRev = 0
--               END
--               ELSE
--               BEGIN
--                  SET @n_QtyRemainToRev = @n_QtyRemainToRev - @n_Qty
--                  SET @n_Qty = 0
--               END
--            END

            SET @n_Qty = @n_Qty - @n_QtyToReverse                       -- (Wan01)
            SET @n_Qty = CASE WHEN @n_Qty <= 0 THEN 0 ELSE @n_Qty END   -- (Wan01)

            UPDATE TASKDETAIL WITH (ROWLOCK)
            SET Status = CASE WHEN @n_Qty = 0 THEN 'X' ELSE Status END
               ,Qty    = @n_Qty
               ,EditWho= SUSER_NAME()
               ,EditDate = GETDATE()
               --,Trafficcop = NULL
            WHERE TaskDetailkey = @c_TaskDetailkey
            AND   Sourcetype = @c_SourceType
            AND   Status IN ( 'S', '0' )  

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63515  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (ispCancJobOperationInput)' 
               GOTO QUIT_SP
            END  
            
            --SET @c_TaskType_Prev = @c_TaskType
            FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                       ,  @c_TaskType
                                       ,  @n_Qty
                     
         END
         CLOSE CUR_TASK
         DEALLOCATE CUR_TASK
         /* (Wan01) - START
         SET @b_Reversed = 1

         SELECT @b_Reversed = 0
         FROM  TASKDETAIL TD WITH (NOLOCK) 
         WHERE TD.Sourcekey = @c_JobKey + @c_JobLineNo 
         AND TD.Sourcetype= @c_SourceType
         AND Lot       = @c_Lot
         AND FromLoc   = @c_FromLoc
         AND FromID    = @c_ID
         AND TD.Status = '9'

         IF @b_Reversed = 0 OR @c_PickMethod = 1 --Do not reverse ALL inv 1) if pick by Pallet 2) Stock move out from VAS Hold loc
         BEGIN
            UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
            SET Qty = Qty - @n_QtyToReverse  
               ,EditWho= SUSER_NAME()
               ,EditDate = GETDATE()
               ,Trafficcop = NULL
            WHERE WOMovekey = @n_WOMovekey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63555  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBMOVE. (ispCancJobOperationInput)' 
               GOTO QUIT_SP
            END    

            UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
            SET QtyReserved = QtyReserved - @n_QtyToReverse  
               ,EditWho= SUSER_NAME()
               ,EditDate = GETDATE()
               ,Trafficcop = NULL
            WHERE Jobkey = @c_Jobkey
            AND   JobLine= @c_JobLineNo

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63555  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ispCancJobOperationInput)' 
               GOTO QUIT_SP
            END  
         END

         IF @c_PickMethod = 1 AND @b_Reversed = 1 -- check if whole pallet id needs to reverse
         BEGIN
            SELECT @b_Reversed = 0
            FROM WORKORDERJOBMOVE WITH (NOLOCK)
            WHERE JobKey  = @c_JobKey
            AND   JobLine = @c_JoblineNo
            AND   ID  = @c_ID
            AND   Status = '9'
            AND   Qty > 0

            SET @n_WOMoveKey = 0
            SET @n_QtyToReverse = 0
         END
         
         IF NOT EXISTS (   SELECT  1
                           FROM  TASKDETAIL TD WITH (NOLOCK)
                           WHERE TD.Sourcetype= @c_SourceType 
                           AND   TD.TaskdetailKey = @c_GroupKey
                           AND   TD.Status NOT IN ('S', '0', 'X')
                       )
         BEGIN
            EXEC isp_WOJobInvReverse 
                    @c_JobKey      = @c_JobKey
                  , @c_JobLineNo   = @c_JobLineNo
                  , @n_WOMoveKey   = @n_WOMoveKey
                  , @n_QtyToReverse= @n_QtyToReverse         
                  , @b_Success     = @b_Success OUTPUT            
                  , @n_err         = @n_err     OUTPUT          
                  , @c_errmsg      = @c_errmsg  OUTPUT

            IF @@ERROR <> 0 OR @b_Success <> 1  
            BEGIN  
               SET @n_Continue= 3    
               SET @n_Err     = 63520
               SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC isp_WOJobInvReverse' +   
                                CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispCancJobOperationInput)'
               GOTO QUIT_SP                          
            END   
         END
         (Wan01) - END */

         IF @n_QtyToReverse = @n_QtyReserved
         BEGIN 
            DELETE WORKORDERJOBMOVE WITH (ROWLOCK)
            WHERE WOMovekey = @n_WOMovekey

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue= 3    
               SET @n_Err     = 63520
               SET @c_ErrMsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': DELETE Fail from Table WORKORDERJOBMOVE. (ispCancJobOperationInput)' 
               GOTO QUIT_SP                          
            END   
         END
         ELSE
         BEGIN
            UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
            SET Qty = Qty - @n_QtyToReverse
            WHERE WOMovekey = @n_WOMovekey

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue= 3    
               SET @n_Err     = 63521
               SET @c_ErrMsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': UPDATE Fail Onto Table WORKORDERJOBMOVE. (ispCancJobOperationInput)' 
               GOTO QUIT_SP                          
            END   
         END

         SET @n_StepQty = @n_StepQty - @n_QtyToReverse
    
         FETCH NEXT FROM CUR_JOBMV INTO @n_WOMovekey
                                       ,@c_Lot
                                       ,@c_FromLoc
                                       ,@c_ID
                                       ,@n_QtyReserved
                                       ,@c_PickMethod
                                       ,@c_GroupKey
      END
      CLOSE CUR_JOBMV
      DEALLOCATE CUR_JOBMV

      IF EXISTS (   SELECT 1
                    FROM WORKORDERJOBOPERATION WOJO  WITH (NOLOCK)
                    WHERE WOJO.JobKey = @c_JobKey
                    AND   WOJO.JobLine= @c_JobLineNo
                    AND   WOJO.QtyReserved = 0
                    AND NOT EXISTS  ( SELECT 1
                                      FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK) 
                                      WHERE TLKUP.JobKey = WOJO.JobKey 
                                      AND   TLKUP.JobLine = WOJO.JobLine 
                                     )
                )
      BEGIN
         DELETE WORKORDERJOBOPERATION WITH (ROWLOCK)
         WHERE JobKey = @c_JobKey
         AND   JobLine = @c_JobLineNo

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63540 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete WORKORDERJOBOPERATION Fail. (ispCancJobOperationInput)' 
            GOTO QUIT_SP
         END

         DELETE FROM VASREFKEYLOOKUP WITH (ROWLOCK)
         WHERE JobKey = @c_JobKey
         AND   JobLine = @c_JobLineNo
         --AND   WorkOrderkey = @c_WorkOrderkey 
         --AND   StepNumber   = @c_StepNumber
         --AND   WkOrdReqInputsKey = @c_WkOrdReqInputsKey 

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63545  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table VASREFKEYLOOKUP. (ispCancJobOperationInput)' 
            GOTO QUIT_SP
         END  
      END
      ELSE
      BEGIN 
         SET @n_StepQty = 0

         SELECT @n_StepQty = SUM(StepQty)
         FROM VASREFKEYLOOKUP WITH (NOLOCK) 
         WHERE JobKey = @c_JobKey
         AND   JobLine = @c_JobLineNo
         GROUP BY JobKey,JobLine
         HAVING COUNT(1) > 0

--         SET @n_QtyToProcess = 0
--         SET @n_PendingTasks  = 0
--         SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN Status IN ('S', '0') THEN TD.Qty ELSE 0 END),0)
--               ,@n_PendingTasks = ISNULL(SUM(CASE WHEN Status IN ('S', '0') THEN 1 ELSE 0 END),0)
--         FROM TASKDETAIL TD WITH (NOLOCK)
--         WHERE TD.SourceType = @c_SourceType
--         AND   TD.Status = 'S'
--         AND   EXISTS ( SELECT 1 
--                        FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK)
--                        WHERE TLKUP.JobKey = @c_JobKey 
--                        AND   TLKUP.JobLine= @c_JobLineNo
--                        AND   TLKUP.TaskDetailkey = TD.TaskDetailkey
--                      )

         UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET StepQty      = @n_StepQty 
--            ,QtyToProcess = @n_QtyToProcess
--            ,PendingTasks = @n_PendingTasks
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
         WHERE JobKey = @c_JobKey
         AND   JobLine= @c_JobLineNo

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63555  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ispCancJobOperationInput)' 
            GOTO QUIT_SP
         END
      END

      FETCH NEXT FROM CUR_JOBLN INTO @c_JobKey
                                    ,@c_JobLineNo
                                    ,@c_Stepnumber
                                    ,@n_StepQty
                                    ,@c_WkOrdReqInputsKey
   END
   CLOSE CUR_JOBLN 
   DEALLOCATE CUR_JOBLN 


QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBLN') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBLN
      DEALLOCATE CUR_JOBLN
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBMV') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBMV
      DEALLOCATE CUR_JOBMV
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK
   END

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispCancJobOperationInput'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN 
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   
      RETURN    
   END    
END -- Procedure  

GO