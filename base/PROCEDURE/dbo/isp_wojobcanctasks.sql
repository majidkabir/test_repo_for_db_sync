SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_WOJobCancTasks                                     */
/* Creation Date: 05-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Cancel Work Order Job Tasks                                   */
/*                                                                         */
/* Called By: PB: Work ORder Job - RMC Cancel Tasks                        */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 01-JULY-2015 YTWan     1.1   SOS#318089 - VAP Add or Delete Order       */
/*                              Component (Wan01)                          */
/* 26-JAN-2016  YTWan     1.2   SOS#315603 - Project Merlion - VAP SKU     */
/*                              Reservation Strategy - MixSku in 1 Pallet  */
/*                               enhancement                               */	
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobCancTasks]
           @c_JobKey          NVARCHAR(10) 
         , @c_JobLineNo	      NVARCHAR(5) = ''
         , @c_WorkOrderkey    NVARCHAR(10)= ''
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @n_RowCount        INT
         , @n_NoTaskToCanc    INT

   DECLARE @n_QtyReleased     INT
         , @n_QtyToProcess    INT
         , @n_QtyInProcess    INT
         , @n_PendingTasks    INT
         , @n_InProcessTasks  INT
         , @n_QtyCancelled    INT
         , @c_WOOperation     NVARCHAR(30)
         
         , @c_SourceType      NVARCHAR(30)
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_TaskType        NVARCHAR(10)
         , @c_JobStatus       NVARCHAR(10)

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = '' 

   SET @n_QtyReleased      = 0
   SET @n_NoTaskToCanc     = 1
      
   SET @c_SourceType       = 'VAS'
   SET @c_TaskDetailKey    = ''

   BEGIN TRAN

   SET @c_JobLineNo =  ISNULL(@c_JobLineNo,'')
   SET @c_WorkOrderkey = ISNULL(@c_WorkOrderkey,'')

   DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TD.TaskDetailKey
   FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK) 
   JOIN TASKDETAIL    TD    WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
   WHERE TLKUP.Jobkey = @c_jobKey
   AND  (TLKUP.JobLine = @c_JobLineNo OR @c_JobLineNo = '')
   AND  (TLKUP.WorkOrderkey = @c_WorkOrderkey OR @c_WorkOrderkey = '')
   AND   TD.Status IN ('S','0')

   OPEN CUR_TASK
   FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

      IF EXISTS ( SELECT 1
                  FROM JOBTASKLOOKUP WITH (NOLOCK)
                  WHERE TaskDetailKey = @c_TaskDetailKey
                )
      BEGIN   
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET Status = 'X'
            ,EditWho   = SUSER_NAME()
            ,EditDate  = GETDATE()
           -- ,Trafficcop= NULL
         WHERE TaskDetailKey = @c_TaskDetailKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': UPDATE Failed On Table TASKDETAIL. (isp_WOJobCancTasks)' 
            GOTO QUIT_SP
         END 
      END
      FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailKey
   END 
   CLOSE CUR_TASK
   DEALLOCATE CUR_TASK
/*
   DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobLine 
         ,WOOperation  
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE  Jobkey = @c_jobKey
   AND   (JobLine = @c_JobLineNo OR @c_JobLineNo = '')
   ORDER BY CASE WOOperation  WHEN 'VAS Move To Line' THEN 8
                              WHEN 'VAS Move'  THEN 7
                              WHEN 'VAS Pick'  THEN 2
                              WHEN 'ASRS Pull' THEN 1
                              ELSE 9 
                              END
          , JobLine

   OPEN CUR_WOJO
   FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                              ,  @c_WOOperation

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF NOT EXISTS ( SELECT 1  
                      FROM TASKDETAIL WITH (NOLOCK)
                      WHERE SourceType = @c_SourceType
                      AND   SourceKey  = @c_JobKey + @c_JobLineNo
                      AND   Status IN ('S', '0')
                      AND   (OrderKey = @c_WorkOrderkey OR @c_WorkOrderkey = '')
                    )
      BEGIN 
         GOTO NEXT_WOJO
      END

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = 'X'
         ,EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,Trafficcop= NULL
      WHERE SourceType = @c_SourceType
      AND   SourceKey  = @c_JobKey + @c_JobLineNo
      AND   Status IN ('S', '0')
      AND   (OrderKey = @c_WorkOrderkey OR @c_WorkOrderkey = '')

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Failed. (isp_WOJobCancTasks)' 
         GOTO QUIT_SP
      END 

      DELETE JOBTASKLOOKUP WITH (ROWLOCK)
      WHERE  JobKey = @c_JobKey
      AND    JobLine= @c_JobLineNo 
      AND    WorkOrderkey = @c_WorkOrderkey
   
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': DELETE Failed from Table JOBTASKLOOKUP. (isp_WOJobCancTasks)' 
         GOTO QUIT_SP
      END 

      SET @n_NoTaskToCanc = 0

      SET @n_QtyToProcess = 0
      SET @n_QtyInProcess = 0
      SET @n_PendingTasks = 0
      SET @n_InProcessTasks = 0
      SELECT @n_QtyToProcess = SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN TASKDETAIL.Qty ELSE 0 END)
            ,@n_QtyInProcess = SUM(CASE WHEN TASKDETAIL.Status BETWEEN '0' AND '8' THEN TASKDETAIL.Qty ELSE 0 END)
            ,@n_PendingTasks = SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN 1 ELSE 0 END)
            ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TASKDETAIL.TaskType <> 'FG' AND TASKDETAIL.Status BETWEEN '0' AND '8' THEN 1 
                                               WHEN TASKDETAIL.TaskType = 'FG' AND TASKDETAIL.Status <> 'X' THEN 1 
                                               ELSE 0 END),0)
      FROM TASKDETAIL WITH (NOLOCK)
      WHERE SourceType = @c_SourceType
      AND EXISTS( SELECT 1 FROM JOBTASKLOOKUP   TLKUP WITH (NOLOCK)
                  WHERE TLKUP.TaskDetailkey = TD.TaskDetailKey
                  AND   TLKUP.JobKey = @c_JobKey 
                  AND   TLKUP.JobLine= @c_JobLineNo
                  )
 
      IF NOT EXISTS (SELECT 1 
                     FROM WORKORDERJOBOPERATION WITH (NOLOCK)
                     WHERE JobKey = @c_JobKey 
                     AND   Sku <> ''
                     AND   QtyInProcess > 0 
                     )
      BEGIN
         SET @n_InProcessTasks = 0
      END

      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET QtyToProcess = @n_QtyToProcess
         ,QtyInProcess = @n_QtyInProcess
         ,PendingTasks = @n_PendingTasks
         ,InProcessTasks = @n_InProcessTasks
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
      WHERE JobKey = @c_JobKey  
      AND   JobLine= @c_JobLineNo

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63720  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobCancTasks)' 
         GOTO QUIT_SP
      END

      NEXT_WOJO:
      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                  , @c_WOOperation
   END 
   CLOSE CUR_WOJO
   DEALLOCATE CUR_WOJO
*/
--   IF @n_NoTaskToCanc = 1
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63725   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': No Tasks to cancel. (isp_WOJobCancTasks)' 
--      GOTO QUIT_SP
--   END 

   QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobCancTasks'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END

GO