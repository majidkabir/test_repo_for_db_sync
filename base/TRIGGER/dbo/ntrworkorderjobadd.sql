SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrWorkOrderJobAdd                                             */
/* Creation Date: 05-Oct-2015                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Update other transactions while WorkOrderJob is added          */
/*        : SOS#315823 - Project Merlion íV VAP RCM to record Wastage,     */
/*          Rejects and Reconciliation                                     */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Added                                           */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 26-JAN-2016  YTWan    1.1  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */
/* 26-FEB-2016  Wan02    1.2  Fixed Wrong WorkorderJob.Qtyjob Update       */    
/* 10-MAR-2016  Wan03    1.3  Fixed Error Msg                              */             
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderJobAdd] ON [dbo].[WorkOrderJob]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @b_Success         INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err             INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg          NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

   DECLARE @c_JobKey             NVARCHAR(10)   
         , @c_WorkOrderkey       NVARCHAR(10)
         , @c_WorkStation        NVARCHAR(50)

   DECLARE @n_UOMQtyJob          INT
         , @n_QtyJob             INT
         , @n_SumQtyJob          INT
         , @n_SumUOMQtyJob       INT
         , @n_NoOfWorkStation    INT
         , @n_NoOfAssignedWorker INT
         , @n_TotalWorkers       INT
         , @c_PWorkStation       NVARCHAR(50)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   
   
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   IF NOT EXISTS (SELECT 1
                  FROM INSERTED
                  JOIN WORKORDERREQUEST WOR  WITH (NOLOCK) ON (INSERTED.WorkorderKey = WOR.WorkorderKey)
                  JOIN WORKORDERROUTING WOT  WITH (NOLOCK) ON (WOR.MasterWorkOrder = WOT.MasterWorkOrder)
                                                           AND(WOR.WorkOrderName  = WOT.WorkOrderName)
                  )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63700  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      --(Wan03)
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Master Work Order & Name not Found in routing. (ntrWorkOrderJobAdd)' 
      GOTO QUIT
   END

   UPDATE WORKORDERREQUEST WITH (ROWLOCK)
   SET    QtyJob          = WOR.QtyJob + ( INSERTED.UOMQtyJob  * WOR.PackQty )
         ,QtyRemaining    = WOR.QtyRemaining - ( INSERTED.UOMQtyJob  * WOR.PackQty )
         ,UOMQtyRemaining = WOR.UOMQtyRemaining - ( INSERTED.UOMQtyJob )  
         ,WorkStation  = CASE WHEN ISNULL(INSERTED.WorkStation,'') <> '' THEN INSERTED.WorkStation ELSE WOR.WorkStation END
         ,EditWho      = SUSER_NAME()
         ,EditDate     = GETDATE()
   FROM INSERTED       
   JOIN WORKORDERREQUEST WOR  ON (INSERTED.WorkOrderKey = WOR.WorkOrderKey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderJobAdd)' 
      GOTO QUIT
   END

   UPDATE WORKORDERJOB WITH (ROWLOCK)
   SET QtyJob = (INSERTED.UOMQtyJob * WOR.PackQty)
      ,EditWho   = SUSER_NAME()
      ,EditDate  = GETDATE()
      ,Trafficcop= NULL
   FROM INSERTED 
   JOIN WORKORDERJOB     WOJ ON (INSERTED.JobKey = WOJ.Jobkey)             --(Wan02)      
                             AND(INSERTED.Workorderkey = WOJ.Workorderkey) --(Wan02)                             
   JOIN WORKORDERREQUEST WOR WITH (NOLOCK) ON (INSERTED.WorkOrderKey = WOR.WorkOrderKey)

   
   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobAdd)' 
      GOTO QUIT
   END

   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
   SET EditWho   = SUSER_NAME()
      ,EditDate  = GETDATE()
      ,QtyJob    = WOJD.QtyJob + WOJ.QtyJob 
      ,UOMQtyJob = (WOJD.QtyJob + WOJ.QtyJob) / WOR.PackQty
   FROM INSERTED
   JOIN WORKORDERJOB       WOJ  WITH (NOLOCK) ON (INSERTED.JobKey = WOJ.JobKey)
                                              AND(INSERTED.WorkOrderKey = WOJ.WorkOrderKey)
   JOIN WORKORDERJOBDETAIL WOJD ON (INSERTED.JobKey = WOJD.JobKey)
   JOIN WORKORDERREQUEST   WOR WITH (NOLOCK) ON (INSERTED.WorkOrderKey = WOR.WorkOrderKey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobAdd)' 
      GOTO QUIT
   END
/*   
   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT INSERTED.Jobkey
   FROM INSERTED 
   ORDER BY INSERTED.Jobkey
 
   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_JobKey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN

      SET @n_SumQtyJob = 0
      SET @n_NoOfWorkStation = 0
      SET @n_TotalWorkers = 0
      SET @c_PWorkStation = ''

      DECLARE CUR_JOBWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT WorkOrderKey= WORKORDERJOB.Workorderkey
            ,WorkStation = WORKORDERJOB.WorkStation
            ,UOMQtyJob   = WORKORDERJOB.UOMQtyJob
            ,QtyJob      = WORKORDERJOB.UOMQtyJob * WORKORDERREQUEST.PackQty
            ,NoOfAssignedWorker = WORKORDERJOB.NoOfAssignedWorker
      FROM WORKORDERJOB WITH (NOLOCK)  
      JOIN WORKORDERREQUEST WITH (NOLOCK) ON (WORKORDERJOB.WorkOrderKey = WORKORDERREQUEST.WorkOrderKey)
      WHERE WORKORDERJOB.JobKey = @c_JobKey
      ORDER BY WORKORDERJOB.WorkStation

      OPEN CUR_JOBWO

      FETCH NEXT FROM CUR_JOBWO INTO @c_WorkOrderKey
                                    ,@c_WorkStation
                                    ,@n_UOMQtyJob
                                    ,@n_QtyJob
                                    ,@n_NoOfAssignedWorker
    
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SET @c_WorkStation = ISNULL(RTRIM(@c_WorkStation),'')
         SET @n_NoOfAssignedWorker = ISNULL(@n_NoOfAssignedWorker,0)

         IF EXISTS ( SELECT 1 
                     FROM INSERTED
                     WHERE INSERTED.JobKey = @c_JobKey
                     AND INSERTED.WorkOrderKey =  @c_WorkOrderKey
                   )
         BEGIN 
            UPDATE WORKORDERREQUEST WITH (ROWLOCK)
            SET    UOMQtyRemaining = UOMQtyRemaining - @n_UOMQtyJob
                  ,QtyJob       = QtyJob + @n_QtyJob
                  ,QtyRemaining = QtyRemaining - @n_QtyJob
                  ,QtyReleased  = 0--CASE WHEN QtyRemaining - @n_QtyRemaining <= 0 THEN 0 ELSE QtyReleased END
                  ,WorkStation  = CASE WHEN ISNULL(RTRIM(@c_WorkStation),'') <> '' THEN @c_WorkStation ELSE WorkStation END
                  ,EditWho     = SUSER_NAME()
                  ,EditDate    = GETDATE()
            WHERE WorkOrderkey = @c_WorkOrderkey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err      = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderJobAdd)' 
               GOTO QUIT
            END

         END

         IF @n_QtyJob > 0 AND @c_WorkStation <> ''
         BEGIN
            IF @c_WorkStation <> @c_PWorkStation 
            BEGIN
               SET @n_NoOfWorkStation = @n_NoOfWorkStation + 1
               SET @n_TotalWorkers    = @n_TotalWorkers + @n_NoOfAssignedWorker
            END
         END

         SET @c_PWorkStation = @c_WorkStation
         SET @n_SumQtyJob = @n_SumQtyJob + @n_QtyJob
         FETCH NEXT FROM CUR_JOBWO INTO @c_WorkOrderKey
                                       ,@c_WorkStation
                                       ,@n_UOMQtyJob
                                       ,@n_QtyJob
                                       ,@n_NoOfAssignedWorker
      END
      CLOSE CUR_JOBWO
      DEALLOCATE CUR_JOBWO

      UPDATE WORKORDERJOB WITH (ROWLOCK)
      SET QtyJob = (INSERTED.UOMQtyJob * WORKORDERREQUEST.PackQty)
         ,EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,Trafficcop= NULL
      FROM INSERTED 
      JOIN WORKORDERJOB ON (WORKORDERJOB.JobKey = INSERTED.JobKey)
                        AND(WORKORDERJOB.WorkOrderKey = INSERTED.WorkOrderKey)
      JOIN WORKORDERREQUEST WITH (NOLOCK) ON (INSERTED.WorkOrderKey = WORKORDERREQUEST.WorkOrderKey)
      WHERE INSERTED.JobKey = @c_Jobkey
      
      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobAdd)' 
         GOTO QUIT
      END

      SET @n_SumQtyJob = 0
      SET @n_SumUOMQtyJob = 0
      SELECT @n_SumQtyJob   = ISNULL(SUM(QtyJob),0)
            ,@n_SumUOMQtyJob= ISNULL(SUM(UOMQtyJob),0)
      FROM WORKORDERJOB WITH (NOLOCK)
      WHERE JobKey = @c_Jobkey

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,QtyJob    = @n_SumQtyJob
         ,UOMQtyJob = @n_SumUOMQtyJob
         ,UOMQtyJob = @n_SumUOMQtyJob
         ,NoOfWorkStation    = @n_NoOfWorkStation
         ,NoOfAssignedWorker = @n_TotalWorkers
         ,EstUnitPerHour     = CASE WHEN EstJobDuration IS NULL OR EstJobDuration = 0 
                                    THEN 0 ELSE @n_QtyJob/EstJobDuration END 
      WHERE JobKey = @c_JobKey 

      SET @n_err = @@ERROR

 IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobAdd)' 
         GOTO QUIT
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

--   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBOP') in (0 , 1)  
--   BEGIN
--      CLOSE CUR_JOBOP
--      DEALLOCATE CUR_JOBOP
--   END

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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobAdd'    
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