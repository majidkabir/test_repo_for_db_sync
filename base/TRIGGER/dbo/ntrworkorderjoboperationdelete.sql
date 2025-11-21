SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobOperationDelete                                 */
/* Creation Date: 23-May-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Trigger when Delete Work order Job Operation                  */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 26-JAN-2016  YTWan    1.1  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderJobOperationDelete] ON [dbo].[WorkOrderJobOperation]
FOR DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0  
   BEGIN
	   RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT                     
         , @n_StartTCnt    INT            -- Holds the current transaction count    
         , @b_Success      INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err          INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg       NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

   DECLARE @c_JobKey       NVARCHAR(10)
         , @c_JobLineNo    NVARCHAR(5)
         
         , @n_QtyItemsOrd  INT
         , @n_QtyItemsRes  INT
         , @n_QtyNonInvOrd INT
         , @n_QtyReleased  INT
         , @n_QtyReserved  INT

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT     

   SET @c_JobKey     = ''
   SET @c_JobLineNo  = ''
   SET @n_QtyReserved= 0

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
	   SET @n_Continue = 4
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1
               FROM DELETED 
               WHERE QtyReserved > 0 
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Reserved Qty found. Cannot delete Job Operation. (ntrWorkOrderJobOperationDelete)'
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED  
               JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (DELETED.JobKey  = TLKUP.JobKey)       
                                                      AND(DELETED.JobLine = TLKUP.JobLine)     
               JOIN TASKDETAIL    TD    WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
               WHERE TD.SourceType = 'VAS'
               AND TD.Status <> 'X' )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Task Detail Exists. Cannot delete Job Operation. (ntrWorkOrderJobOperationDelete)'
      GOTO QUIT
   END 

   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT DELETED.Jobkey
   FROM DELETED 
   ORDER BY DELETED.Jobkey

   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      /*
      DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT JobLine
            ,ISNULL(QtyReserved,0) 
      FROM DELETED
      WHERE JobKey = @c_JobKey                 
      OPEN CUR_WOJO
      
      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                 ,  @n_QtyReserved
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_QtyReserved > 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err      = 63701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Reserved Qty exists. Cannot delete Job. (ntrWorkOrderJobOperationDelete)'
            GOTO QUIT
         END

         IF EXISTS ( SELECT 1 
                     FROM TASKDETAIL    TD    WITH (NOLOCK)
                     JOIN TASKKEYLOOKUP TLKUP WITH (NOLOCK) ON (TD.Taskdetailkey = TLKUP.Taskdetailkey)
                     WHERE TLKUP.JobKey = @c_JobKey
                     AND TKUP.JobLine = @c_JobLineNo
                     AND  TD.SourceType = 'VAS'
                     AND  TD.Status <> 'X' )
         BEGIN
            SET @n_continue = 3
            SET @n_err      = 63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Task Detail Exists. Cannot delete Job. (ntrWorkOrderJobOperationDelete)'
            GOTO QUIT
         END 

         FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                    ,  @n_QtyReserved
      END
      CLOSE CUR_WOJO 
      DEALLOCATE CUR_WOJO
      */
      SET @n_QtyItemsOrd = 0
      SET @n_QtyNonInvOrd= 0
      SELECT  @n_QtyItemsOrd = ISNULL(SUM(CASE WHEN RTRIM(SKU) <> '' THEN StepQty ELSE 0 END),0)
            , @n_QtyNonInvOrd= ISNULL(SUM(CASE WHEN RTRIM(NonInvSku) <> '' THEN StepQty ELSE 0 END),0)
      FROM WORKORDERJOBOPERATION WITH (NOLOCK)
      WHERE JobKey = @c_JobKey

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,QtyItemsOrd  = @n_QtyItemsOrd
         ,QtyItemsNeed = @n_QtyItemsOrd - QtyItemsRes
         ,QtyNonInvOrd = @n_QtyNonInvOrd
         ,QtyNonInvNeed= @n_QtyNonInvOrd - QtyNonInvRes
      WHERE JobKey = @c_JobKey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobOperationDelete)' 
         GOTO QUIT
      END
      FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey
   END
   CLOSE CUR_JOB 
   DEALLOCATE CUR_JOB
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJO' ) = 0
   BEGIN
      CLOSE CUR_WOJO 
      DEALLOCATE CUR_WOJO
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobOperationDelete'    
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