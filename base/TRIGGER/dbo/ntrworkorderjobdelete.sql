SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrWorkOrderJobDelete                                          */
/* Creation Date: 05-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Trigger when Delete WorkorderJob                              */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records deleted                                         */
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

CREATE TRIGGER [dbo].[ntrWorkOrderJobDelete] ON [dbo].[WorkOrderJob] 
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
        

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT     

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   UPDATE WORKORDERREQUEST WITH (ROWLOCK)
   SET    QtyJob       = WOR.QtyJob - DELETED.QtyJob
         ,QtyRemaining = WOR.QtyRemaining + DELETED.QtyJob
         ,UOMQtyRemaining = WOR.UOMQtyRemaining + DELETED.UOMQtyJob
         ,WOStatus     = CASE WHEN WOR.Qty = WOR.QtyRemaining + DELETED.QtyRemaining THEN '0' ELSE WOR.WOStatus END
--         ,EditWho      = SUSER_NAME()
--         ,EditDate     = GETDATE()
--         ,Trafficcop   = NULL
   FROM DELETED
   JOIN WORKORDERREQUEST WOR ON (DELETED.WorkOrderkey = WOR.WorkOrderkey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg   = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderJobDelete)' 
      GOTO QUIT
   END

   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
   SET EditWho   = SUSER_NAME()
      ,EditDate  = GETDATE()
      ,QtyJob    = WOJD.QtyJob - DELETED.QtyJob 
      ,UOMQtyJob = WOJD.UOMQtyJob - DELETED.UOMQtyJob 
   FROM DELETED
   JOIN WORKORDERJOBDETAIL WOJD ON (DELETED.JobKey = WOJD.JobKey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobDelete)' 
      GOTO QUIT
   END

--   UPDATE WORKORDERREQUESTINPUTS WITH (ROWLOCK)
--   SET QtyJob       = WORQI.QtyJob - (DELETED.QtyRemaining * WOI.Qty)
--      ,QtyRemaining = WORQI.QtyRemaining + (DELETED.QtyRemaining * WOI.Qty) 
--      ,EditWho      = SUSER_NAME()
--      ,EditDate     = GETDATE()
--      ,Trafficcop   = NULL
--   FROM DELETED
--   JOIN WORKORDERREQUESTINPUTS WORQI ON (DELETED.WorkOrderkey = WORQI.WorkOrderkey)
--   JOIN WORKORDERINPUTS        WOI   WITH (NOLOCK) ON (WORQI.WkOrdInputsKey = WOI.WkOrdInputsKey)
--
--   SET @n_err = @@ERROR
--
--   IF @n_err <> 0
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUESTINPUTS. (ntrWorkOrderJobDelete)' 
--      GOTO QUIT
--   END    

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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobDelete'    
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