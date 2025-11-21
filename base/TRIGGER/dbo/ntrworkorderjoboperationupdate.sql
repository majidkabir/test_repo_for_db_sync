SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobOperationUpdate                                 */
/* Creation Date: 12-Nov-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Update other transactions while WorkOrderJobOperation line    */
/*           is updated                                                    */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Updated                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 26-JAN-2016  YTWan    1.1  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderJobOperationUpdate] ON [dbo].[WorkOrderJobOperation] 
FOR UPDATE
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

   DECLARE @n_QtyItemsOrd     INT
         , @n_QtyItemsRes     INT
         , @n_QtyNonInvOrd    INT
         , @n_QtyReleased     INT

         , @c_JobKey          NVARCHAR(10)   
         , @c_JobLineNo       NVARCHAR(5)
         , @n_StepQty         INT
         , @n_QtyReserved     INT
         , @n_QtyToProcess    INT
         , @n_QtyInProcess    INT
         , @n_QtyOnHold       INT
         , @c_JobStatus       NVARCHAR(10)
         , @c_SourceType      NVARCHAR(10)

         , @c_WorkOrderkey    NVARCHAR(10)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   
   
   SET @c_JobKey        = ''
   SET @c_JobLineNo     = ''
   SET @c_SourceType    = 'VAS'
   SET @n_StepQty      = 0
   SET @n_QtyReserved  = 0
   SET @n_QtyToProcess = 0
   SET @n_QtyInProcess = 0
   SET @c_JobStatus    = ''

   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END


   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET EditDate = GETDATE() 
         ,EditWho  = SUSER_SNAME() 
         ,TrafficCop = NULL
      FROM WORKORDERJOBOPERATION
      JOIN DELETED  ON (DELETED.JobKey  = WORKORDERJOBOPERATION.JobKey)
                    AND(DELETED.JobLine = WORKORDERJOBOPERATION.JobLine)
      JOIN INSERTED ON (DELETED.JobKey  = INSERTED.JobKey)
                    AND(DELETED.JobLine = INSERTED.JobLine)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63700  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobOperationUpdate)'
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
   SELECT DISTINCT INSERTED.Jobkey
   FROM INSERTED 
   WHERE INSERTED.JobStatus < '9'
   ORDER BY INSERTED.Jobkey

   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      DECLARE CUR_JOBOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT JobLineNo     = INSERTED.JobLine
            ,StepQty       = INSERTED.StepQty
            ,QtyReserved   = INSERTED.QtyReserved
            ,QtyToProcess  = INSERTED.QtyToProcess
            ,QtyInProcess  = INSERTED.QtyInProcess
            ,JobStatus     = INSERTED.JobStatus
      FROM INSERTED
      WHERE  INSERTED.Jobkey = @c_JobKey

      OPEN CUR_JOBOP

      FETCH NEXT FROM CUR_JOBOP INTO   @c_JobLineNo
                                    ,  @n_StepQty
                                    ,  @n_QtyReserved
                                    ,  @n_QtyToProcess
                                    ,  @n_QtyInProcess
                                    ,  @c_JobStatus
    
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SET @n_QtyOnHold   = 0
         SELECT @n_QtyOnHold  = ISNULL(SUM(CASE WHEN Status = 'H' THEN TD.Qty ELSE 0 END),0)
         FROM TASKDETAIL TD WITH (NOLOCK)
         WHERE TD.SourceType = @c_SourceType
         AND   EXISTS ( SELECT 1 
                        FROM  JOBTASKLOOKUP TLKUP   WITH (NOLOCK)
                        WHERE TLKUP.JobKey = @c_JobKey
                        AND   TLKUP.JobLine = @c_JobLineNo
                        AND   TLKUP.Taskdetailkey = TD.Taskdetailkey
                      )

         SET @c_JobStatus = CASE WHEN @c_JobStatus ='8'   THEN '8'      
                                 WHEN @n_QtyOnHold > 0    THEN '6'
                                 WHEN @n_QtyInProcess > 0 THEN '4'
                                 WHEN @n_QtyToProcess > 0 THEN '3'
                                 WHEN @n_StepQty - @n_QtyReserved = @n_StepQty THEN '0'
                                 WHEN @n_StepQty - @n_QtyReserved = 0 THEN '2'
                                 WHEN @n_StepQty - @n_QtyReserved > 0 THEN '1'
                                 END

         UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET JobStatus    = @c_JobStatus
            ,EditWho      = SUSER_NAME()
            ,EditDate     = GETDATE()
            ,Trafficcop   = NULL
         WHERE JobKey = @c_JobKey
         AND   JobLine= @c_JobLineNo
         AND   JobStatus < '8'

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobOperationUpdate)' 
            GOTO QUIT
         END 
         
         FETCH NEXT FROM CUR_JOBOP INTO   @c_JobLineNo
                                       ,  @n_StepQty
                                       ,  @n_QtyReserved
                                       ,  @n_QtyToProcess
                                       ,  @n_QtyInProcess
                                       ,  @c_JobStatus
      END
      CLOSE CUR_JOBOP
      DEALLOCATE CUR_JOBOP


      SET @n_QtyItemsOrd = 0
      SET @n_QtyItemsRes = 0
      SET @n_QtyNonInvOrd= 0
 
      SELECT  @n_QtyItemsOrd = ISNULL(SUM(CASE WHEN RTRIM(SKU) <> '' THEN StepQty ELSE 0 END),0)
            , @n_QtyItemsRes = ISNULL(SUM(QtyReserved),0)
            , @n_QtyNonInvOrd= ISNULL(SUM(CASE WHEN RTRIM(NonInvSku) <> '' THEN StepQty ELSE 0 END),0)
            , @n_QtyToProcess= ISNULL(SUM(QtyToProcess),0)
            , @n_QtyInProcess= ISNULL(SUM(QtyInProcess),0)
            , @n_QtyOnHold   = ISNULL(SUM(CASE WHEN JobStatus = '6' THEN StepQty ELSE 0 END),0) 
      FROM WORKORDERJOBOPERATION WITH (NOLOCK)
      WHERE JobKey = @c_JobKey

      SET @n_QtyReleased = 0
      IF @n_QtyInProcess > 0 
      BEGIN
         --(MIXSKU) - START

         DECLARE CUR_JOBWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT WorkOrderKey = WOJ.WorkOrderKey
         FROM WORKORDERJOB  WOJ   WITH (NOLOCK)
         WHERE WOJ.JobKey = @c_JobKey 
         ORDER BY WOJ.WorkStation

         OPEN CUR_JOBWO

         FETCH NEXT FROM CUR_JOBWO INTO  @c_WorkOrderkey
         
         WHILE @@FETCH_STATUS <> -1  
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
               SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (ntrWorkOrderJobOperationUpdate)' 
               GOTO QUIT
            END
            FETCH NEXT FROM CUR_JOBWO INTO  @c_WorkOrderkey
         END
         CLOSE CUR_JOBWO
         DEALLOCATE CUR_JOBWO
      END

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,QtyItemsOrd  = @n_QtyItemsOrd
         ,QtyItemsRes  = @n_QtyItemsRes
         ,QtyItemsNeed = QtyItemsOrd - QtyItemsRes
         ,QtyNonInvOrd = @n_QtyNonInvOrd
         ,QtyNonInvNeed= @n_QtyNonInvOrd - QtyNonInvRes
         --,QtyReleased  = @n_QtyReleased
      WHERE JobKey = @c_JobKey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobOperationUpdate)' 
         GOTO QUIT
      END
      FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey
   END
   CLOSE CUR_JOB 
   DEALLOCATE CUR_JOB
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBOP') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBOP
      DEALLOCATE CUR_JOBOP
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobOperationUpdate'    
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