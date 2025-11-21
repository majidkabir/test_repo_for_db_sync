SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispVASRL01                                                  */
/* Creation Date: 19-AUG-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#315701 - Project Merlion - VAP Release Task generates   */
/*        : WCS Message                                                 */
/*                                                                      */
/* Called By:  isp_VASJobReleaseTasks_Wrapper                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-JAN-2016  Wan01    1.1  SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	
/************************************************************************/
CREATE PROC [dbo].[ispVASRL01] 
            @c_JobKey      NVARCHAR(10)
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15)
         , @c_JobLineNo       NVARCHAR(5)


         , @c_TaskdetailKey   NVARCHAR(10)
         , @c_TaskType        NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_FromLoc         NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)

         , @c_MessageName     NVARCHAR(15)
         , @c_MessageType     NVARCHAR(10)

         , @n_QtyReleased     INT
         , @n_QtyToProcess    INT
         , @n_QtyInProcess    INT
         , @n_PendingTasks    INT
         , @n_InProcessTasks  INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN -- Optional if PB Transaction is AUTOCOMMIT = FALSE. No harm to always start BEGIN TRAN in begining of SP
  
   DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT JobLine 
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE Jobkey = @c_jobKey
   AND (Sku <> '' OR WOOperation = 'Begin FG')
   ORDER BY JobLine

   OPEN CUR_WOJO
   FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                             
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT
             TD.TaskDetailkey
            ,TD.TaskType
            ,TD.FromID
            ,TD.FromLoc
            ,TD.ToLoc
      FROM TASKDETAIL    TD    WITH (NOLOCK)
      JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON ( TD.TaskDetailkey = TLKUP.TaskDetailKey )
      WHERE TLKUP.JobKey = @c_JobKey 
      AND TLKUP.JobLine  = @c_JobLineNo
      AND TD.Sourcetype = 'VAS'
      AND TD.Status = 'S'

      OPEN CUR_TASK

      FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                 ,  @c_TaskType
                                 ,  @c_ID
                                 ,  @c_FromLoc
                                 ,  @c_ToLoc
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET Status = '0'
            ,Priority  = '5'              -- 14-Jan-2016 by Wan ML need task priority = '5'
            ,EditWho   = SUSER_NAME()
            ,EditDate  = GETDATE()
         --   ,Trafficcop= NULL           -- Let Trigger call ispVasTaskProcessing to cal qty(s) back to WORKORDERJOBOPERATION
         WHERE Taskdetailkey = @c_Taskdetailkey

         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Failed. (ispVASRL01)' 
            GOTO QUIT_SP
         END 
         /*
         IF @c_TaskType = 'ASRSMV'
         BEGIN
            --Inventory Hold id to hold ID when Travelling in WCS01 - START
             -- Call InventoryHold SP to hold
            IF NOT EXISTS ( SELECT 1
                            FROM ID WITH (NOLOCK)
                            WHERE Id = @c_ID
                            AND Status = 'HOLD'
                            )
            BEGIN  
               EXEC nspInventoryHoldWrapper
                  '',               -- lot
                  '',               -- loc
                  @c_ID,            -- id
                  '',               -- storerkey
                  '',               -- sku
                  '',               -- lottable01
                  '',               -- lottable02
                  '',               -- lottable03
                  NULL,             -- lottable04
                  NULL,             -- lottable05
                  '',               -- lottable06
                  '',               -- lottable07    
                  '',               -- lottable08
                  '',               -- lottable09
                  '',               -- lottable10
                  '',               -- lottable11
                  '',               -- lottable12
                  NULL,             -- lottable13
                  NULL,             -- lottable14
                  NULL,             -- lottable15
                  'VASHOLD',        -- status  
                  '1',              -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  'Release VAS ASRS ID' -- remark

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61010
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (ispVASRL01)' 
                                      + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
                  GOTO QUIT_SP 
               END
            END
            --Inventory Hold id to hold ID when Travelling in WCS01 - END
            
            SET @c_MessageName  = 'MOVE'
            SET @c_MessageType  = 'SEND'
            SET @b_Success = 1

            SET @b_Success = 0
            EXEC isp_TCP_WCS_MsgProcess
                     @c_MessageName  = @c_MessageName
                  ,  @c_MessageType  = @c_MessageType
                  ,  @c_PalletID     = @c_ID
                  ,  @c_FromLoc      = @c_FromLoc
                  ,  @c_ToLoc	       = @c_ToLoc
                  ,  @c_Priority	    = '5'
                  ,  @c_TaskDetailKey= @c_Taskdetailkey
                  ,  @b_Success      = @b_Success  OUTPUT
                  ,  @n_Err          = @n_Err      OUTPUT
                  ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
            
            IF @b_Success <> 1   
            BEGIN  

               SET @n_continue = 3    
               SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (ispVASRL01)' 
                            + '( ' + @c_ErrMsg + ' )'
               GOTO QUIT_SP
            END 
         END
          */
         FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                    ,  @c_TaskType
                                    ,  @c_ID
                                    ,  @c_FromLoc
                                    ,  @c_ToLoc
      END
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK

      /* (Wan01) - START :Let Trigger call ispVasTaskProcessing to cal qty(s) back to WORKORDERJOBOPERATION
      SET @n_QtyToProcess = 0
      SET @n_QtyInProcess = 0
      SET @n_PendingTasks = 0
      SET @n_InProcessTasks=0
      --SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN TASKDETAIL.Qty ELSE 0 END),0)
      --      ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TASKDETAIL.Status BETWEEN '0' AND '8' THEN TASKDETAIL.Qty ELSE 0 END),0)
      --      ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN 1 ELSE 0 END),0)
      --      ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TASKDETAIL.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
      --FROM TASKDETAIL WITH (NOLOCK)
      --WHERE SourceType = 'VAS'
      --AND SourceKey = @c_JobKey + @C_JobLineNo
      SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN TD.Qty ELSE 0 END),0)
            ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN TD.Qty ELSE 0 END),0)
            ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN 1 ELSE 0 END),0)
            ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
      FROM TASKDETAIL TD WITH (NOLOCK)
      WHERE TD.SourceType = 'VAS'
      AND   EXISTS( SELECT 1 FROM JOBTASKLOOKUP   TLKUP WITH (NOLOCK)
                    WHERE TLKUP.TaskDetailkey = TD.TaskDetailKey
                    AND   TLKUP.JobKey = @c_JobKey
                    AND   TLKUP.JobLine= @c_JobLineNo
                  )

      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET QtyToProcess = @n_QtyToProcess
         ,QtyInProcess = @n_QtyInProcess
         ,PendingTasks = @n_PendingTasks
         ,InProcessTasks=@n_InProcessTasks
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
      WHERE JobKey = @c_JobKey  
      AND   JobLine= @c_JobLineNo

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ispVASRL01)' 
         GOTO QUIT_SP
      END
      (Wan01) - END */
      FETCH NEXT FROM CUR_WOJO INTO @C_JobLineNo
   END
   CLOSE CUR_WOJO
   DEALLOCATE CUR_WOJO

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJO') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJO
      DEALLOCATE CUR_WOJO
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispVASRL01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO