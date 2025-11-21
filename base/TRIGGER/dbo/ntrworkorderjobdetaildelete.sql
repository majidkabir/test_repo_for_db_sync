SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobDetailDelete                                    */
/* Creation Date: 03-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Trigger when Delete Work order Request                        */
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
CREATE TRIGGER [dbo].[ntrWorkOrderJobDetailDelete] ON [dbo].[WorkOrderJobDetail]
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

   DECLARE @n_Continue  INT                     
         , @n_StartTCnt INT            -- Holds the current transaction count    
         , @b_Success   INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err       INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg    NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

   DECLARE @c_JobKey    NVARCHAR(10)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT     

   SET @c_JobKey    = ''

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
	   SET @n_Continue = 4
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED 
               WHERE QtyCompleted > 0 )
   BEGIN
      SET @n_continue = 3
      SET @n_err=63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Completed Qty > 0. Cannot delete Job. (ntrWorkOrderJobDetailDelete)'
      GOTO QUIT
   END 

   IF EXISTS ( SELECT 1 
               FROM DELETED
               JOIN WORKORDERJOBOPERATION WOJO WITH (NOLOCK) ON (DELETED.JobKey = WOJO.JobKey)
               WHERE WOJO.QtyReserved > 0 )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Reserved Qty found. Cannot delete Job. (ntrWorkOrderJobDetailDelete)'
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED  
               JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (DELETED.JobKey  = TLKUP.JobKey)       
               JOIN TASKDETAIL    TD    WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
               WHERE TD.SourceType = 'VAS'
               AND TD.Status <> 'X' )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Task Detail Exists. Cannot delete Job Operation. (ntrWorkOrderJobOperationDelete)'
      GOTO QUIT
   END 

   DELETE WORKORDERJOB WITH (ROWLOCK) 
   FROM DELETED
   WHERE DELETED.JobKey = WORKORDERJOB.JobKey 

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete Failed On Table WORKORDERJOB. (ntrWorkOrderJobDetailDelete)' 
      GOTO QUIT
   END  

   DELETE WORKORDERJOBOPERATION WITH (ROWLOCK) 
   FROM DELETED
   WHERE DELETED.JobKey = WORKORDERJOBOPERATION.JobKey 

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete Failed On Table WORKORDERJOBOPERATION. (ntrWorkOrderJobDetailDelete)' 
      GOTO QUIT
   END 

   --(Wan01) - START
   DELETE VASREFKEYLOOKUP WITH (ROWLOCK)
   FROM DELETED
   WHERE DELETED.JobKey = VASREFKEYLOOKUP.JobKey

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63706   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete Failed On Table VASREFKEYLOOKUP. (ntrWorkOrderJobDetailDelete)' 
      GOTO QUIT
   END  
   --(Wan01) - END

   DELETE WORKORDERJOBMOVE WITH (ROWLOCK) 
   FROM DELETED
   WHERE DELETED.JobKey = WORKORDERJOBMOVE.JobKey 

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63707   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete Failed On Table WORKORDERJOBMOVE. (ntrWorkOrderJobDetailDelete)' 
      GOTO QUIT
   END  

QUIT:
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobDetailDelete'    
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