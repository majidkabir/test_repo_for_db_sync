SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_WOJobReleaseTasks                                  */
/* Creation Date: 10-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Hold Work Order Job Tasks                                     */
/*                                                                         */
/* Called By: PB: Work ORder Job - RMC Generate Tasks                      */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver. Purposes                                     */
/* 26-JAN-2016  Wan01    1.1  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobReleaseTasks]
           @c_JobKey          NVARCHAR(10) 
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue           INT                     
         , @n_StartTCnt          INT            -- Holds the current transaction count  
         , @n_Cnt                INT  

   DECLARE @c_WORelease          NVARCHAR(50)

   DECLARE @c_TaskdetailKey      NVARCHAR(10) 
         , @c_TaskType           NVARCHAR(10)
         , @c_SourceKey          NVARCHAR(20)
         , @c_SourceType         NVARCHAR(30)
         , @c_Status             NVARCHAR(10)

   DECLARE @c_JobLineNo          NVARCHAR(5)
         , @c_MinStep            NVARCHAR(5)
         , @c_WOOperation        NVARCHAR(30)
         , @c_PullType           NVARCHAR(10)
         , @n_PullQty            INT

         , @n_QtyReleased        INT
         , @n_QtyToProcess       INT
         , @n_QtyInProcess       INT
         , @n_PendingTasks       INT         
         , @n_InProcessTasks     INT

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = ''  
   SET @n_Cnt              = 1

   SET @c_WORelease        = ''

   SET @c_TaskdetailKey    = ''
   SET @c_TaskType         = ''
   SET @c_SourceKey        = ''
   SET @c_SourceType       = 'VAS'
   SET @c_Status           = ''

   SET @c_JobLineNo        = ''
   SET @c_MinStep          = ''
   SET @c_WOOperation      = ''
   SET @c_PullType         = ''
   SET @n_PullQty          = 0

   SET @n_QtyReleased      = 0

   SELECT @n_QtyReleased = QtyReleased
   FROM WORKORDERJOBDETAIL WITH (NOLOCK)
   WHERE JobKey = @c_JobKey

   BEGIN TRAN
   DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobLineNo   = JobLine
         ,WOOperation = ISNULL(RTRIM(WOOperation),'')
         ,PullType    = ISNULL(RTRIM(PullType),'')
         ,PullQty     = ISNULL(PullQty,0)
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE Jobkey = @c_JobKey
   AND   Sku <> '' AND SKU IS NOT NULL
   AND   QtyReserved > 0
   ORDER BY JobLine

   OPEN CUR_WOJO
   FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                              ,  @c_WOOperation
                              ,  @c_PullType
                              ,  @n_PullQty

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      --SET @c_TaskType = CASE @c_WOOperation WHEN 'ASRS Pull' THEN 'VA'
      --                                      WHEN 'VAS Pick'  THEN 'VP'
      --                                      WHEN 'VAS Move'  THEN 'VM'
      --                                      WHEN 'VAS Move To Line' THEN 'VL' 
      --                                      WHEN 'Begin FG'  THEN 'FG'
      --                  END

      --IF @c_TaskType IN ( 'VA', 'VP' )
      --BEGIN
         SET @n_Cnt = 1
         DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT TD.TaskDetailkey
               ,TD.Status
         FROM TASKDETAIL    TD    WITH (NOLOCK)
         JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON ( TD.TaskDetailkey = TLKUP.TaskDetailKey )
         WHERE TLKUP.JobKey = @c_JobKey 
         AND   TLKUP.JobLine= @c_JobLineNo
         AND   TD.Sourcetype= @c_Sourcetype
         AND   TD.Status <> 'X'
         ORDER BY CASE WHEN TD.Status = 'S' THEN 9 ELSE 1 END

         OPEN CUR_TASK

         FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                     , @c_Status

         WHILE @@FETCH_STATUS <> -1 
         BEGIN

            IF @c_PullType = 'Replenish' AND @n_PullQty < @n_Cnt
            BEGIN
               BREAK
            END

            IF @c_Status <> 'S'
            BEGIN
               -- Do not Count if not released yet
               IF @n_QtyReleased = 0
               BEGIN
                  SET @n_Cnt = @n_Cnt - 1
               END
                GOTO NEXT_TASK
            END

            IF @c_WORelease= 'Full Release' -- Release Others Related TaskType
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM TASKDETAIL WITH (NOLOCK)
                           WHERE GroupKey = @c_TaskDetailkey
                           AND   SourceType = @c_Sourcetype
                           AND   Status = 'S'
                         )
               BEGIN
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Status = '0'
                     ,EditWho   = SUSER_NAME()
                     ,EditDate  = GETDATE()
                     --,Trafficcop= NULL
                  --WHERE RefTaskKey = @c_TaskDetailkey
                  WHERE GroupKey = @c_TaskDetailkey
                  AND   SourceType = @c_Sourcetype
               END
            END
            ELSE
            BEGIN
               UPDATE TASKDETAIL WITH (ROWLOCK)
               SET Status = '0'
                  ,EditWho   = SUSER_NAME()
                  ,EditDate  = GETDATE()
                  --,Trafficcop= NULL
               WHERE TaskDetailkey = @c_TaskDetailkey
            END

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (isp_WOJobReleaseTasks)' 
               GOTO QUIT_SP
            END

            NEXT_TASK:
            SET @n_Cnt = @n_Cnt + 1
           
            FETCH NEXT FROM CUR_TASK INTO @c_TaskDetailkey
                                        , @c_Status
         END
         CLOSE CUR_TASK
         DEALLOCATE CUR_TASK
      --END 
      /* --(Wan01) - START 
      SET @n_QtyToProcess = 0
      SET @n_QtyInProcess = 0
      SET @n_PendingTasks = 0
      SET @n_InProcessTasks=0
      SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN TASKDETAIL.Qty ELSE 0 END),0)
            ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TASKDETAIL.Status BETWEEN '0' AND '8' THEN TASKDETAIL.Qty ELSE 0 END),0)
            ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TASKDETAIL.Status = 'S' THEN 1 ELSE 0 END),0)
            ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TASKDETAIL.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
      FROM TASKDETAIL WITH (NOLOCK)
      WHERE SourceType = @c_SourceType
      AND   EXISTS( SELECT 1 FROM JOBTASKLOOKUP   TLKUP WITH (NOLOCK)
                    WHERE TLKUP.TaskDetailkey = TD.TaskDetailKey
                    AND   TLKUP.JobKey = @c_JobKey
                    AND   TLKUP.JobLine= @c_JobLineNo
                  )

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
         SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobReleaseTasks)' 
         GOTO QUIT_SP
      END
      --(Wan01) - END */
      NEXT_WOJO:
      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                 ,  @c_WOOperation
                                 ,  @c_PullType
                                 ,  @n_PullQty
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobReleaseTasks'
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