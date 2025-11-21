SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobUpdate                                          */
/* Creation Date: 04-Nov-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Update other transactions while WorkOrderJob line is updated  */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 28-JUL-2015  YTWan    1.1  SOS#318089 - Project Merlion - VAP Add or    */
/*                            Delete Work Order Component (Wan01)          */
/* 26-JAN-2016  YTWan    1.2  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderJobUpdate] ON [dbo].[WorkOrderJob] 
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
         , @c_JobLineNo          NVARCHAR(5)
         , @c_WorkOrderkey       NVARCHAR(10)
         , @c_Sequence           NVARCHAR(10)
         , @c_WorkStation        NVARCHAR(50)
         , @c_StepNo             NVARCHAR(10)
--         , @c_JobStatus          NVARCHAR(10) 

   DECLARE @n_UOMQtyJob          INT
         , @n_SumUOMQtyJob       INT
         , @n_SumQtyJob          INT
         , @n_QtyReleased        INT
         , @n_NoOfWorkStation    INT
         , @n_NoOfAssignedWorker INT
         , @n_TotalWorkers       INT
         , @c_PWorkStation       NVARCHAR(50)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   
   
   SET @c_JobKey        = ''
   SET @c_JobLineNo     = ''
   SET @c_WorkOrderkey  = ''
   SET @c_Sequence      = ''
   SET @c_WorkStation   = ''
   SET @c_StepNo        = ''

   SET @n_SumQtyJob     = 0
   SET @n_SumUOMQtyJob  = 0
   SET @n_UOMQtyJob     = 0
    
   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE WORKORDERJOB WITH (ROWLOCK)
      SET EditDate = GETDATE() 
         ,EditWho  = SUSER_SNAME() 
         ,TrafficCop = NULL
      FROM WORKORDERJOB
      JOIN DELETED  ON (DELETED.JobKey = WORKORDERJOB.JobKey AND DELETED.WorkOrderkey = WORKORDERJOB.WorkOrderkey)
      JOIN INSERTED ON (DELETED.JobKey = INSERTED.JobKey AND DELETED.WorkOrderkey = INSERTED.WorkOrderkey)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63700  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobUpdate)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO QUIT
      END
   END
  
   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   DECLARE CUR_JOBWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT JobKey      = INSERTED.JobKey
         ,WorkOrderKey= INSERTED.Workorderkey
         ,Sequence    = INSERTED.Sequence
         ,WorkStation = INSERTED.WorkStation
         ,UOMQtyJob   = INSERTED.UOMQtyJob
         ,QtyReleased = INSERTED.QtyReleased
   FROM INSERTED 

   OPEN CUR_JOBWO

   FETCH NEXT FROM CUR_JOBWO INTO @c_JobKey
                                 ,@c_WorkOrderKey
                                 ,@c_Sequence
                                 ,@c_WorkStation
                                 ,@n_UOMQtyJob
                                 ,@n_QtyReleased
 
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SELECT TOP 1 @c_JobLineNo = WOJO.JobLine
                  ,@c_StepNo    = MinStep
      FROM  WORKORDERJOBOPERATION WOJO WITH (NOLOCK) 
      WHERE WOJO.JobKey = @c_jobKey
      AND   WOJO.WOOperation = 'Begin FG'

      IF EXISTS ( SELECT 1
                  FROM DELETED 
                  WHERE DELETED.JobKey = @c_JobKey
                  AND   DELETED.WorkOrderKey = @c_WorkOrderKey
                  AND   DELETED.Sequence <> @c_Sequence
                )
      BEGIN
         -- MixSku (Wan02) - START
         --IF EXISTS (SELECT 1 
         --           FROM TASKDETAIL WITH (NOLOCK)
         --           WHERE SourceKey = @c_JobKey + @c_JobLineNo
         --           AND SourceType = 'VAS'
         --           AND TaskType = 'FG'
         --           AND Orderkey = @c_WorkOrderkey)
         IF EXISTS ( SELECT 1
                     FROM JOBTASKLOOKUP WITH (NOLOCK)
                     WHERE JobKey = @c_jobKey
                     AND  JobLine = @c_JobLineNo
                     AND  WorkOrderkey = @c_WorkOrderkey
                   ) 
         BEGIN
            UPDATE TASKDETAIL WITH (ROWLOCK)
            SET SourcePriority = @c_Sequence
               ,EditWho      = SUSER_NAME()
               ,EditDate     = GETDATE()
               ,Trafficcop   = NULL
            FROM TASKDETAIL 
            JOIN  JOBTASKLOOKUP WITH (NOLOCK) ON (TASKDETAIL.TaskDetailkey = JOBTASKLOOKUP.TaskDetailkey)
            WHERE JOBTASKLOOKUP.JobKey = @c_jobKey
            AND JOBTASKLOOKUP.JobLine = @c_JobLineNo
            AND JOBTASKLOOKUP.WorkOrderkey = @c_WorkOrderkey
            AND TASKDETAIL.SourceType = 'VAS'
         -- MixSku (Wan02) - END
            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table TASKDETAIL. (ntrWorkOrderJobUpdate)' 
               GOTO QUIT
            END 
         END
      END 
 
      UPDATE WORKORDERREQUEST WITH (ROWLOCK)
      SET    QtyJob          = WOR.QtyJob + ( (@n_UOMQtyJob + (DELETED.UOMQtyJob * -1)) * WOR.PackQty )
            ,UOMQtyRemaining = WOR.UOMQtyRemaining - ( @n_UOMQtyJob + (DELETED.UOMQtyJob * -1) )  
            ,QtyReleased     = WOR.QtyReleased + ( @n_QtyReleased + (DELETED.QtyReleased * -1) ) 
            ,WorkStation  = @c_WorkStation
            ,EditWho      = SUSER_NAME()
            ,EditDate     = GETDATE()
      FROM DELETED      
      JOIN WORKORDERREQUEST WOR ON (DELETED.WorkOrderkey = WOR.WorkOrderkey)
      WHERE DELETED.Jobkey = @c_Jobkey 
      AND   DELETED.WorkOrderkey = @c_WorkOrderkey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err      = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderJobUpdate)' 
         GOTO QUIT
      END

      UPDATE WORKORDERJOB WITH (ROWLOCK)
      SET QtyJob = WOJ.QtyJob + ( (@n_UOMQtyJob + (DELETED.UOMQtyJob * -1)) * WOR.PackQty )
         ,EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,Trafficcop= NULL
      FROM DELETED      
      JOIN WORKORDERJOB WOJ   ON (DELETED.JobKey = WOJ.JobKey)
                              AND(DELETED.WorkOrderKey = WOJ.WorkOrderKey)
      JOIN  WORKORDERREQUEST WOR WITH (NOLOCK) ON (DELETED.WorkOrderkey = WOR.WorkOrderkey)
      WHERE DELETED.Jobkey = @c_Jobkey 
      AND   DELETED.WorkOrderkey = @c_WorkOrderkey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63704  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobUpdate)' 
         GOTO QUIT
      END

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET QtyJob      = WOJD.QtyJob +  ( (@n_UOMQtyJob + (DELETED.UOMQtyJob * -1)) * WOR.PackQty )
         ,UOMQtyJob   = WOJD.UOMQtyJob + (@n_UOMQtyJob + (DELETED.UOMQtyJob * -1))
         ,QtyReleased = WOJD.QtyReleased + ( @n_QtyReleased + (DELETED.QtyReleased * -1) ) 
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
      FROM DELETED 
      JOIN WORKORDERJOBDETAIL WOJD               ON (DELETED.JobKey = WOJD.JobKey)
      JOIN WORKORDERJOB       WOJ  WITH (NOLOCK) ON (DELETED.JobKey = WOJ.JobKey)
                                                 AND(DELETED.WorkOrderKey = WOJ.WorkOrderKey)
      JOIN WORKORDERREQUEST   WOR  WITH (NOLOCK) ON (DELETED.WorkOrderkey = WOR.WorkOrderkey)
      WHERE DELETED.JobKey = @c_JobKey
      AND   DELETED.WorkOrderkey = @c_WorkOrderkey

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobUpdate)' 
         GOTO QUIT
      END 
 
      FETCH NEXT FROM CUR_JOBWO INTO @c_JobKey
                                    ,@c_WorkOrderKey
                                    ,@c_Sequence
                                    ,@c_WorkStation
                                    ,@n_UOMQtyJob
                                    ,@n_QtyReleased
   END
   CLOSE CUR_JOBWO
   DEALLOCATE CUR_JOBWO
/*
      IF EXISTS (SELECT 1
                 FROM INSERTED 
                 JOIN DELETED      ON (INSERTED.JobKey = DELETED.JobKey)
                 WHERE INSERTED.UOMQtyJob <> DELETED.UOMQtyJob
                )
      BEGIN 
         UPDATE WORKORDERJOB WITH (ROWLOCK)
         SET QtyJob = (INSERTED.UOMQtyJob * WORKORDERREQUEST.PackQty)
            ,EditWho   = SUSER_NAME()
            ,EditDate  = GETDATE()
            ,Trafficcop= NULL
         FROM INSERTED 
         JOIN DELETED      ON (INSERTED.JobKey = DELETED.JobKey)
         JOIN WORKORDERJOB ON (WORKORDERJOB.JobKey = INSERTED.JobKey)
                           AND(WORKORDERJOB.WorkOrderKey = INSERTED.WorkOrderKey)
         JOIN WORKORDERREQUEST WITH (NOLOCK) ON (INSERTED.WorkOrderKey = WORKORDERREQUEST.WorkOrderKey)
         WHERE INSERTED.JobKey = @c_Jobkey

         
         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63704  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobUpdate)' 
            GOTO QUIT
         END

         --(Wan01) - START
         SET @n_SumQtyJob = 0 
         SELECT @n_SumQtyJob = ISNULL(SUM(QtyJob),0)
               ,@n_SumUOMQtyJob = ISNULL(SUM(UOMQtyJob),0)
         FROM WORKORDERJOB WITH (NOLOCK)
         WHERE JobKey = @c_JobKey

         UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
         SET QtyJob = @n_SumQtyJob
            ,UOMQtyJob   = @n_SumUOMQtyJob
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
         WHERE JobKey = @c_JobKey

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobUpdate)' 
            GOTO QUIT
         END 
         --(Wan01) - END

         IF @n_SumQtyJob > 0 --@c_JobStatus <> '8'
         BEGIN
            SET @n_NoOfWorkStation = 0
            SET @n_TotalWorkers = 0
            SET @c_PWorkStation = ''

            DECLARE WOJ_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT WorkStation = ISNULL(RTRIM(WorkStation),'')
                  ,NoOfAssignedWorker = ISNULL(NoOfAssignedWorker,0)
            FROM WORKORDERJOB WITH (NOLOCK)
            WHERE JobKey = @c_JobKey
            UNION
            SELECT WorkStation = ISNULL(RTRIM(WorkStation),'')
                  ,NoOfAssignedWorker = ISNULL(NoOfAssignedWorker,0)
            FROM INSERTED WITH (NOLOCK)
            WHERE INSERTED.JobKey = @c_JobKey
            ORDER BY WorkStation

            OPEN WOJ_CUR
            FETCH NEXT FROM WOJ_CUR INTO @c_WorkStation
                                       , @n_NoOfAssignedWorker

            WHILE (@@FETCH_STATUS <> -1)
            BEGIN

               IF @c_WorkStation <> @c_PWorkStation AND @c_WorkStation <> ''
               BEGIN
                  SET @n_NoOfWorkStation = @n_NoOfWorkStation + 1
                  SET @n_TotalWorkers    = @n_TotalWorkers + @n_NoOfAssignedWorker
               END

               SET @c_PWorkStation = @c_WorkStation
               FETCH NEXT FROM WOJ_CUR INTO @c_WorkStation
                                          , @n_NoOfAssignedWorker
            END
            CLOSE WOJ_CUR
            DEALLOCATE  WOJ_CUR

            UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
            SET NoOfWorkStation    = @n_NoOfWorkStation
               ,NoOfAssignedWorker = @n_TotalWorkers
               ,EstUnitPerHour     = CASE WHEN EstJobDuration IS NULL OR EstJobDuration = 0 
                                          THEN 0 ELSE @n_SumQtyJob/EstJobDuration END 
               ,ActualUnitPerHour  = CASE WHEN ActualJobDuration IS NULL OR ActualJobDuration = 0 
                                          THEN 0 ELSE QtyCompleted/ActualJobDuration END
               ,AvgUnitPerWorker   = CASE WHEN ActualJobDuration IS NULL OR ActualJobDuration = 0 OR @n_TotalWorkers = 0
                                          THEN 0 ELSE (QtyCompleted/ActualJobDuration)/@n_TotalWorkers END
               ,EditWho      = SUSER_NAME()
               ,EditDate     = GETDATE()
               ,Trafficcop   = NULL
            WHERE JobKey = @c_Jobkey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobUpdate)' 
               GOTO QUIT
            END 
         END
      END
      FETCH NEXT FROM CUR_JOB INTO @c_JobKey
   END
   CLOSE CUR_JOB
   DEALLOCATE CUR_JOB
*/
QUIT:
--   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
--   BEGIN
--      CLOSE CUR_JOB
--      DEALLOCATE CUR_JOB
--   END

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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobUpdate'    
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