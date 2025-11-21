SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispVASTaskProcessing                               */
/* Creation Date: 14-Dec-2012                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: VAS Task Processing                                         */
/*                                                                      */
/* Called By: ntrTaskDetailAdd, ntrTaskDetailUpdate, ntrTaskdetailDelete*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 26-JAN-2016  YTWan   1.1  SOS#315603 - Project Merlion - VAP SKU     */
/*                           Reservation Strategy - MixSku in 1 Pallet  */
/*                           enhancement                                */	
/************************************************************************/ 
CREATE PROC  [dbo].[ispVASTaskProcessing]    
         @c_Action         NVARCHAR(5)
      ,  @c_TaskdetailKey  NVARCHAR(10)
      ,  @c_Tasktype       NVARCHAR(10)
      ,  @c_Sourcekey      NVARCHAR(15)
      ,  @c_SourceType     NVARCHAR(30)
      ,  @c_PickDetailKey  NVARCHAR(10)
      ,  @c_RefTaskkey     NVARCHAR(10)
      ,  @c_Storerkey      NVARCHAR(15)
      ,  @c_Sku            NVARCHAR(20)
      ,  @c_Fromloc        NVARCHAR(10)
      ,  @c_Fromid         NVARCHAR(18)
      ,  @c_Toloc          NVARCHAR(10)
      ,  @c_Toid           NVARCHAR(18)
      ,  @c_lot            NVARCHAR(10)
      ,  @n_Qty            INT
      ,  @n_UOMqty         INT
      ,  @c_UOM            NVARCHAR(10)
      ,  @c_Caseid         NVARCHAR(20) 
      ,  @c_Status         NVARCHAR(10)
      ,  @c_Reasonkey      NVARCHAR(10)
      ,  @b_Success        INT            OUTPUT
      ,  @n_err            INT            OUTPUT
      ,  @c_errmsg         NVARCHAR(255)  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE @n_Continue           INT
         , @n_StartTCnt          INT

         , @c_GroupKey           NVARCHAR(10)
         , @c_GrpTaskDetailKey   NVARCHAR(10)

         , @c_JobKey             NVARCHAR(10)
         , @c_JobLineNo          NVARCHAR(5)
         , @c_Movekey            NVARCHAR(10)
         , @c_JobStorerkey       NVARCHAR(15)
         , @c_JobSku             NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10) 
         , @c_PackUOM3           NVARCHAR(10)
         , @c_PackUOM4           NVARCHAR(10)
         , @c_VirtualLoc         NVARCHAR(10)
         , @c_PullUOM            NVARCHAR(10)
         , @n_QtyReserved        INT

         , @n_QtyReleased        INT
         , @n_QtyToProcess       INT
         , @n_QtyInProcess       INT
         , @n_PendingTasks       INT
         , @n_InProcessTasks     INT

   SET @b_Success       = 1
   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT

   SET @c_Packkey       = ''
   SET @c_Movekey       = ''
   SET @c_PackUOM3      = ''
   SET @c_VirtualLoc    = ''
   SET @n_QtyReserved   = 0
  
   SET @c_JobKey        = ''
   SET @c_JobLineNo     = ''
   SELECT @c_JobKey     = JobKey
         ,@c_JobLineNo  = JobLine
   FROM JOBTASKLOOKUP    WITH (NOLOCK)
   WHERE TaskDetailkey = @c_TaskDetailKey

   IF @c_JobKey = ''
   BEGIN 
      GOTO QUIT_SP
   END

   IF @c_Action = 'ADD' GOTO TASK_ADD
   IF @c_Action = 'UPD' GOTO TASK_UPD
   IF @c_Action = 'DEL' GOTO TASK_DEL
   
   TASK_ADD:
      GOTO UPD_QTY
   TASK_UPD:
--      IF EXISTS ( SELECT 1
--                  FROM TASKDETAIL WITH (NOLOCK)
--                  WHERE Taskdetailkey = @c_Taskdetailkey
--                  AND Status BETWEEN '1' AND '8'
--                )
--      BEGIN
--         SET @n_continue= 3
--         SET @n_err     = 61100  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Task is in progress. Changes is not allowed (ispVASTaskProcessing)' 
--         GOTO QUIT_SP
--      END


      IF @c_TaskType = 'FG' AND @c_Status = 'X'
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM TASKDETAIL     TD    WITH (NOLOCK)
                     JOIN JOBTASKLOOKUP  TLKUP WITH (NOLOCK) ON (TLKUP.TaskDetailkey = TD.TaskDetailKey)
                     WHERE TLKUP.JobKey  = @c_JobKey
                     AND   TD.SourceType = @c_SourceType
                     AND   Status NOT IN ('9','X')
                   )
         BEGIN        
            SET @n_continue= 3
            SET @n_err     = 61105  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Job is in progress. Cancel FG is not allowed (ispVASTaskProcessing)' 
            GOTO QUIT_SP
         END
      END

      IF @c_Status = 'X'
      BEGIN
         SET @c_JobLineNo = ''  -- to calculate qty(s) for all workorderjoboperation records
         SET @c_GroupKey = ''
         SELECT @c_GroupKey = GroupKey
         FROM TASKDETAIL WITH (NOLOCK)
         WHERE Taskdetailkey = @c_Taskdetailkey
   
         DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT 
                TD.Taskdetailkey
         FROM TASKDETAIL TD WITH (NOLOCK)
         WHERE TD.GroupKey = @c_GroupKey
         AND TD.Status IN ('S','0')

         OPEN CUR_TASK
         FETCH NEXT FROM CUR_TASK INTO @c_GrpTaskDetailKey

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            UPDATE TASKDETAIL WITH (ROWLOCK)
            SET Status = @c_Status
               ,EditWho   = SUSER_NAME()
               ,EditDate  = GETDATE()
               ,Trafficcop= NULL
            WHERE TaskDetailKey = @c_GrpTaskDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 61110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': UPDATE Failed On Table TASKDETAIL. (ispVASTaskProcessing)' 
               GOTO QUIT_SP
            END 

            DELETE JOBTASKLOOKUP WITH (ROWLOCK)
            WHERE  TaskDetailKey = @c_GrpTaskDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63715   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': DELET Failed From Table JOBTASKLOOKUP. (ispVASTaskProcessing)' 
               GOTO QUIT_SP
            END 

            FETCH NEXT FROM CUR_TASK INTO @c_GrpTaskDetailKey         
         END
         CLOSE CUR_TASK
         DEALLOCATE CUR_TASK

         DELETE JOBTASKLOOKUP WITH (ROWLOCK)
         WHERE  TaskDetailKey = @c_TaskDetailKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63715   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': DELET Failed From Table JOBTASKLOOKUP. (ispVASTaskProcessing)' 
            GOTO QUIT_SP
         END 
      END
      GOTO UPD_QTY
   TASK_DEL:
      IF EXISTS ( SELECT 1
                  FROM JOBTASKLOOKUP  TLKUP WITH (NOLOCK) 
                  WHERE TLKUP.TaskDetailkey = @c_TaskDetailkey
                )
      BEGIN 
      
         SET @n_continue= 3
         SET @n_err     = 61120  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Task Not Cancelled. Delete Task is not allowed (ispVASTaskProcessing)' 
         GOTO QUIT_SP
      END

      GOTO QUIT_SP
--      IF @c_TaskType = 'FG' 
--      BEGIN
--         IF EXISTS ( SELECT 1
--                     FROM TASKDETAIL WITH (NOLOCK)
--                     WHERE Sourcetype = @c_Sourcetype
--                     AND   SUBSTRING(Sourcekey,1,10) = @c_JobKey
--                     AND   Status NOT IN ('9','X')
--                     AND   Sourcekey <> @c_Sourcekey
--                   )
--         BEGIN        
--            SET @n_continue= 3
--            SET @n_err     = 61115  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Job is in progress. Delete FG Task is not allowed (ispVASTaskProcessing)' 
--            GOTO QUIT_SP
--         END
--      END
--      GOTO UPD_QTY

   UPD_QTY:

      DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WOJO.JobLine
      FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK) 
      WHERE WOJO.Jobkey = @c_JobKey
      AND  (WOJO.JobLine= @c_JobLineNo OR @c_JobLineNo = '')

      OPEN CUR_WOJO
      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SET @n_QtyToProcess = 0
         SET @n_QtyInProcess = 0
         SET @n_PendingTasks = 0
         SET @n_InProcessTasks = 0

         SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN TD.Qty ELSE 0 END),0)
               ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN TD.Qty ELSE 0 END),0)
               ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN 1 ELSE 0 END),0)
               ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
         FROM TASKDETAIL TD WITH (NOLOCK)
         WHERE TD.SourceType = @c_SourceType
         AND   EXISTS( SELECT 1 FROM JOBTASKLOOKUP   TLKUP WITH (NOLOCK)
                       WHERE TLKUP.TaskDetailkey = TD.TaskDetailKey
                       AND   TLKUP.JobKey = @c_JobKey
                       AND   TLKUP.JobLine= @c_JobLineNo
                     )

         -- Update QtyReserved
         UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET QtyToProcess = @n_QtyToProcess
            ,QtyInProcess = @n_QtyInProcess
            ,PendingTasks = @n_PendingTasks
            ,InProcessTasks=@n_InProcessTasks 
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
         WHERE Jobkey = @c_JobKey
         AND   JobLine= @c_JobLineNo

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 61125  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Updating WORKORDERJOBOPERATION. (ispVASTaskProcessing)' 
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
      END   
      CLOSE CUR_WOJO
      DEALLOCATE CUR_WOJO
      
   QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJO') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJO
      DEALLOCATE CUR_WOJO
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispVASTaskProcessing'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN

      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END  

GO