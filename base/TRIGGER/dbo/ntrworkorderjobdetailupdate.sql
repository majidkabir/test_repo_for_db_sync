SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobDetailUpdate                                    */
/* Creation Date: 05-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Update other transactions while WorkOrderJobDetail line is    */
/*           updated                                                       */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records updated                                         */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 25-JUN-2015  YTWan    1.1  SOS#318089 - VAP Add or Delete Order         */
/*                            Component (Wan01)                            */
/* 26-JAN-2016  YTWan    1.2  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderJobDetailUpdate] ON [dbo].[WorkOrderJobDetail] 
FOR UPDATE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT                     
         , @n_StartTCnt          INT            -- Holds the current transaction count    
         , @b_Success            INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err                INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg             NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

   DECLARE @c_JobKey             NVARCHAR(10)
         , @c_JobStatus          NVARCHAR(10)
         , @c_JobStatusD         NVARCHAR(10)
         , @c_SourceType         NVARCHAR(10)
         , @c_Priority           NVARCHAR(10)

         , @c_WorkOrderkey       NVARCHAR(10)
         , @c_JobLineNo          NVARCHAR(5)
         , @n_QtyToProcess       INT
         , @n_QtyInProcess       INT
         , @n_PendingTasks       INT         
         , @n_InProcessTasks     INT

         , @n_QtyJob             INT
         , @n_QtyCompleted       INT
         , @n_QtyItemsOrd        INT
         , @n_QtyItemsRes        INT
         , @n_QtyNonInvOrd       INT
         , @n_QtyReleased        INT
         , @n_QtyReleased_Del    INT
         , @n_QtyOnHold          INT
         , @n_QtyRemaining       INT

         , @n_NoOfWorkStation    INT
         , @n_NoOfAssignedWorker INT
         , @n_TotalWorkers       INT
         , @c_WorkStation        NVARCHAR(50)
         , @c_PWorkStation       NVARCHAR(50)

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT     

   SET @c_JobKey           = ''
   SET @c_JobStatus        = '0'
   SET @c_SourceType       = 'VAS'
   SET @c_Priority         = ''

   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET EditDate = GETDATE() 
         ,EditWho  = SUSER_SNAME() 
         ,TrafficCop = NULL
      FROM WORKORDERJOBDETAIL
      JOIN DELETED  ON (DELETED.JobKey = WORKORDERJOBDETAIL.JobKey)
      JOIN INSERTED ON (DELETED.JobKey = INSERTED.JobKey)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63700  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobDetailUpdate)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO QUIT
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobKey      = INSERTED.Jobkey
         ,JobStatus   = INSERTED.JobStatus
         ,JobStatusD  = DELETED.JobStatus
         ,Priority    = INSERTED.Priority
         ,QtyJob      = INSERTED.QtyJob
         ,QtyItemsOrd = INSERTED.QtyItemsOrd
         ,QtyItemsRes = INSERTED.QtyItemsRes
   FROM INSERTED 
   JOIN DELETED ON (INSERTED.JobKey = DELETED.JobKey)
   ORDER BY INSERTED.Jobkey
 
   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_JobKey
                              ,  @c_JobStatus
                              ,  @c_JobStatusD
                              ,  @c_Priority 
                              ,  @n_QtyJob
                              ,  @n_QtyItemsOrd
                              ,  @n_QtyItemsRes
   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      IF UPDATE(Priority)
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM TASKDETAIL    TD    WITH (NOLOCK)
                     JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                     WHERE TLKUP.JobKey = @c_JobKey
                     AND TD.SourceType  = @c_SourceType
                     AND TD.Priority   <> @c_Priority
                     AND TD.Status     NOT IN ('9', 'X')
                   )
         BEGIN
            UPDATE TASKDETAIL WITH (ROWLOCK)
               SET Priority     = @c_Priority
                  ,EditWho      = SUSER_NAME()
                  ,EditDate     = GETDATE()
                  ,Trafficcop   = NULL
             FROM TASKDETAIL    TD    
             JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
             WHERE TLKUP.JobKey = @c_JobKey
             AND TD.SourceType  = @c_SourceType
             AND TD.Priority   <> @c_Priority
             AND TD.Status     NOT IN ('9', 'X')
      
            SET @n_err = @@ERROR
      
            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END 
         END     
      END  

      -- Handling JobStatus when its value change
      IF @c_JobStatus <> @c_JobStatusD 
      BEGIN
         --Job Hold
         IF @c_JobStatus = '6'
         BEGIN 
            IF @c_JobStatusD = '3'
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63725  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Hold Job fail. Job has not been released yet. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END

            IF @c_JobStatusD = '8'
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Hold Job fail. Job had been cancelled  (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END 

            IF EXISTS ( SELECT 1 
                        FROM TASKDETAIL    TD    WITH (NOLOCK) 
                        JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                        WHERE TLKUP.JobKey = @c_JobKey
                        AND   TD.SourceType= @c_SourceType
                        AND   TD.Status BETWEEN '1' AND '8') 
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Hold Job fail. There are tasks in progress  (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END

            DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT JobLineNo = ISNULL(RTRIM(WOJO.JobLine),'')
            FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)
            WHERE WOJO.Jobkey = @c_jobKey
            ORDER BY CASE WOJO.WOOperation   WHEN 'Begin FG'  THEN 9  
                                             WHEN 'VAS Pick'  THEN 2
                                             WHEN 'ASRS Pull' THEN 1
                                             ELSE 8
                                             END
                   , ISNULL(RTRIM(WOJO.JobLine),'')
            OPEN CUR_WOJO
            FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo

            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM TASKDETAIL    TD    WITH (NOLOCK) 
                           JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                           WHERE TLKUP.JobKey  = @c_JobKey
                           AND   TLKUP.JobLine = @c_JobLineNo
                           AND   TD.SourceType = @c_SourceType
                           AND   TD.Status     = '0'
                         )
               BEGIN
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Status       = 'H'
                     ,EditWho      = SUSER_NAME()
                     ,EditDate     = GETDATE()
                     ,Trafficcop   = NULL   
                  FROM TASKDETAIL    TD      
                  JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                  WHERE TLKUP.JobKey  = @c_JobKey
                  AND   TLKUP.JobLine = @c_JobLineNo
                  AND   TD.SourceType = @c_SourceType
                  AND   TD.Status     = '0'
                  
                  SET @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue= 3
                     SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (ntrWorkOrderJobDetailUpdate)' 
                     GOTO QUIT
                  END
               END
 
               SET @n_QtyToProcess = 0
               SET @n_QtyInProcess = 0
               SET @n_PendingTasks = 0
               SET @n_InProcessTasks=0
               SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN TD.Qty ELSE 0 END),0)
                     ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN TD.Qty ELSE 0 END),0)
                     ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN 1 ELSE 0 END),0)
                     ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
               FROM TASKDETAIL TD WITH (NOLOCK)
               WHERE TD.SourceType = @c_SourceType
               AND EXISTS (   SELECT 1
                              FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK)
                              WHERE TLKUP.JobKey  = @c_JobKey
                              AND   TLKUP.JobLine = @c_JobLineNo
                              AND   TLKUP.Taskdetailkey = TD.Taskdetailkey
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
                  SET @n_err     = 63707   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobDetailUpdate)' 
                  GOTO QUIT
               END 
               FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
            END
            CLOSE CUR_WOJO
            DEALLOCATE CUR_WOJO
            --END
         END

         --Job UnHold / Release
         IF @c_JobStatus = '4'
         BEGIN 
            --Job UnHold
            IF @c_JobStatusD = '6'
            BEGIN
               DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT JobLineNo = ISNULL(RTRIM(WOJO.JobLine),'')
               FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)
               JOIN TASKDETAIL            TD   WITH (NOLOCK) ON (TD.SourceType = @c_SourceType)
                                                             AND(TD.SourceKey  = WOJO.JobKey + WOJO.JobLine) 
               WHERE WOJO.Jobkey = @c_jobKey
               AND   TD.Status   = 'H'
               ORDER BY CASE WOJO.WOOperation   WHEN 'Begin FG'  THEN 9  
                                                WHEN 'VAS Pick'  THEN 2
                                                WHEN 'ASRS Pull' THEN 1
                                                ELSE 8
                                                END
                      , ISNULL(RTRIM(WOJO.JobLine),'')
               OPEN CUR_WOJO
               FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  IF EXISTS ( SELECT 1
                              FROM TASKDETAIL    TD    WITH (NOLOCK) 
                              JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                              WHERE TLKUP.JobKey  = @c_JobKey
                              AND   TLKUP.JobLine = @c_JobLineNo
                              AND   TD.SourceType = @c_SourceType
                              AND   TD.Status     = 'H'
                            )
                   BEGIN
                     UPDATE TASKDETAIL WITH (ROWLOCK)
                     SET Status       = '0'
                        ,EditWho      = SUSER_NAME()
                        ,EditDate     = GETDATE()
                        ,Trafficcop   = NULL   
                     FROM TASKDETAIL    TD     
                     JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                     WHERE TLKUP.JobKey  = @c_JobKey
                     AND   TLKUP.JobLine = @c_JobLineNo
                     AND   TD.SourceType = @c_SourceType
                     AND   TD.Status     = 'H'
                     
                     SET @n_err = @@ERROR

                     IF @n_err <> 0
                     BEGIN
                        SET @n_continue= 3
                        SET @n_err     = 63706   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (ntrWorkOrderJobDetailUpdate)' 
                        GOTO QUIT
                     END
                  END

                  SET @n_QtyToProcess = 0
                  SET @n_QtyInProcess = 0
                  SET @n_PendingTasks = 0
                  SET @n_InProcessTasks=0
                  SELECT @n_QtyToProcess = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN TD.Qty ELSE 0 END),0)
                        ,@n_QtyInProcess = ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN TD.Qty ELSE 0 END),0)
                        ,@n_PendingTasks = ISNULL(SUM(CASE WHEN TD.Status = 'S' THEN 1 ELSE 0 END),0)
                        ,@n_InProcessTasks=ISNULL(SUM(CASE WHEN TD.Status BETWEEN '0' AND '8' THEN 1 ELSE 0 END),0)
                  FROM TASKDETAIL TD WITH (NOLOCK)
                  WHERE TD.SourceType = @c_SourceType
                  AND EXISTS (   SELECT 1
                                 FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK)
                                 WHERE TLKUP.JobKey  = @c_JobKey
                                 AND   TLKUP.JobLine = @c_JobLineNo
                                 AND   TLKUP.Taskdetailkey = TD.Taskdetailkey
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
                     SET @n_err     = 63707   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobDetailUpdate)' 
                     GOTO QUIT
                  END
                  FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
               END
               CLOSE CUR_WOJO
               DEALLOCATE CUR_WOJO
            END
         END

         --Job Cancel
         IF @c_JobStatus = '8'
         BEGIN 
            IF @c_JobStatusD > '3'
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63711
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Pending Tasks. Cannot Cancel Job. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END

            IF @c_JobStatusD > '0'
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63712
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Inventory Reserved. Cannot Cancel Job. '
                              + 'Please remove the reservation and try again (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END

            UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
            SET JobStatus   = @c_JobStatus
               ,QtyReserved = 0                       --(Wan01)
               ,QtyToProcess= 0                       --(Wan01)
               ,EditWho     = SUSER_NAME()
               ,EditDate    = GETDATE()
               ,Trafficcop  = NULL
            WHERE JobKey = @c_JobKey 

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63714  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END

            UPDATE WORKORDERJOB WITH (ROWLOCK)
            SET UOMQtyJob = 0
               ,JobStatus = @c_JobStatus
               ,EditWho   = SUSER_NAME()
               ,EditDate  = GETDATE()
            WHERE JobKey  = @c_JobKey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END
--            SET @n_QtyJob = 0
         END
      END

      SET @n_NoOfWorkStation = 0
      SET @n_TotalWorkers = ''
      SET @c_PWorkStation = ''
      DECLARE CUR_JOBWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WorkOrderKey = WOJ.WorkOrderKey
            ,WorkStation = ISNULL(RTRIM(WorkStation),'')
            ,NoOfAssignedWorker = ISNULL(NoOfAssignedWorker,0)
      FROM WORKORDERJOB  WOJ   WITH (NOLOCK)
      WHERE WOJ.JobKey = @c_JobKey 
      ORDER BY WOJ.WorkStation

      OPEN CUR_JOBWO

      FETCH NEXT FROM CUR_JOBWO INTO  @c_WorkOrderkey
                                     ,@c_WorkStation
                                    , @n_NoOfAssignedWorker
      
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         IF @c_WorkStation <> @c_PWorkStation AND @c_WorkStation <> ''
         BEGIN
            SET @n_NoOfWorkStation = @n_NoOfWorkStation + 1
            SET @n_TotalWorkers    = @n_TotalWorkers + @n_NoOfAssignedWorker
         END
         SET @c_PWorkStation = @c_WorkStation

         /*
         IF EXISTS ( SELECT 1
                     FROM INSERTED 
                     JOIN DELETED ON (INSERTED.JobKey = DELETED.JobKey)
                     WHERE INSERTED.JobKey = @c_JobKey
                     AND INSERTED.QtyReleased <> DELETED.QtyReleased
                   )
         BEGIN
            SET @n_QtyReleased = 0
            SELECT @n_QtyReleased = CASE WHEN Status BETWEEN '0' AND '8' THEN TD.Qty ELSE 0 END
            FROM TASKDETAIL TD WITH (NOLOCK)
            WHERE TD.SourceType = @c_SourceType
            AND EXISTS( SELECT 1
                        FROM JOBTASKLOOKUP TLKUP WITH (NOLOCK)  
                        WHERE TLKUP.JobKey = @c_JobKey
                        AND   TLKUP.WorkOrderKey = @c_WorkOrderkey
                        AND   TLKUP.Taskdetailkey = TD.Taskdetailkey
                      )

            UPDATE WORKORDERJOB  WITH (ROWLOCK)
            SET QtyReleased = @n_QtyReleased
               ,JobStatus   = CASE WHEN @n_QtyReleased > 0 THEN '4' 
                                   WHEN @c_JobStatus = '6' THEN '6'
                                   ELSE JobStatus END
               ,EditWho     = SUSER_NAME()
               ,EditDate    = GETDATE()
            WHERE JobKey       = @c_JobKey 
            AND   WorkOrderkey = @c_WorkOrderkey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63720  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobDetailUpdate)' 
               GOTO QUIT
            END
         END
         */
         FETCH NEXT FROM CUR_JOBWO INTO  @c_WorkOrderkey
                                       , @c_WorkStation
                                       , @n_NoOfAssignedWorker
      END   
      CLOSE CUR_JOBWO
      DEALLOCATE CUR_JOBWO     

      SET @n_QtyToProcess= 0
      SET @n_QtyOnHold   = 0

      SELECT  @n_QtyToProcess= ISNULL(SUM(QtyToProcess),0)
            , @n_QtyOnHold   = ISNULL(SUM(CASE WHEN JobStatus = '6' THEN StepQty ELSE 0 END),0) 
      FROM WORKORDERJOBOPERATION WITH (NOLOCK)
      WHERE JobKey = @c_JobKey

      SELECT @n_QtyReleased = QtyReleased
            ,@n_QtyJob      = QtyJob
            ,@n_QtyCompleted= QtyCompleted
      FROM  WORKORDERJOBDETAIL WITH (NOLOCK)
      WHERE JobKey = @c_JobKey

      SET @c_JobStatus = CASE WHEN @n_QtyJob    > 0 AND @n_QtyJob - @n_QtyCompleted = 0 THEN '9'
                              WHEN @n_QtyJob    = 0    THEN '8'
                              WHEN @n_QtyOnHold > 0    THEN '6'
                              WHEN @n_QtyReleased > 0  THEN '4'
                              WHEN @n_QtyToProcess> 0  THEN '3'
                              WHEN @n_QtyItemsOrd > 0 AND @n_QtyItemsOrd - @n_QtyItemsRes = 0 THEN '2'
                              WHEN @n_QtyItemsRes > 0  THEN '1'
                              ELSE 0 END

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET JobStatus          = @c_JobStatus
         ,NoOfWorkStation    = @n_NoOfWorkStation
         ,NoOfAssignedWorker = @n_TotalWorkers
         ,EstUnitPerHour     = CASE WHEN EstJobDuration IS NULL OR EstJobDuration = 0 
                                    THEN 0 ELSE QtyJob/EstJobDuration END 
         ,ActualUnitPerHour  = CASE WHEN ActualJobDuration IS NULL OR ActualJobDuration = 0 
                                    THEN 0 ELSE QtyCompleted/ActualJobDuration END
         ,AvgUnitPerWorker   = CASE WHEN ActualJobDuration IS NULL OR ActualJobDuration = 0 OR @n_TotalWorkers = 0
                                    THEN 0 ELSE (QtyCompleted/ActualJobDuration)/@n_TotalWorkers END
         ,EditWho      = SUSER_NAME()
         ,EditDate     = GETDATE()
         ,Trafficcop   = NULL
      WHERE JobKey = @c_JobKey
      AND JobStatus < '9'

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63725  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobDetailUpdate)' 
         GOTO QUIT
      END

      FETCH NEXT FROM CUR_JOB INTO  @c_JobKey
                                 ,  @c_JobStatus
                                 ,  @c_JobStatusD
                                 ,  @c_Priority 
                                 ,  @n_QtyJob
                                 ,  @n_QtyItemsOrd
                                 ,  @n_QtyItemsRes
   END
   CLOSE CUR_JOB
   DEALLOCATE CUR_JOB
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBWO') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBWO
      DEALLOCATE CUR_JOBWO
   END

   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt    
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobDetailUpdate'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  

      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    

      RETURN    
   END      
END

GO