SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderRequestUpdate                                      */
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
/* Called By: When records Update                                          */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 16-JULY-2015  YTWan   1.1  SOS#318089 - VAP Add or Delete Order         */
/*                            Component (Wan01)                            */
/* 26-JAN-2016  YTWan    1.2  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE TRIGGER [dbo].[ntrWorkOrderRequestUpdate] ON [dbo].[WorkOrderRequest] 
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

         , @c_WorkOrderkey    NVARCHAR(10)
         , @c_WorkOrderType   NVARCHAR(10)
         , @n_PackQty         FLOAT

--         , @n_Qty             INT
--         , @n_QtyRemainingDel INT
         , @n_QtyRemaining    INT
--         , @n_QtyReleased     INT
--         , @b_JobExists       INT
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT

   SET @c_WorkOrderType = 'O'   
   
   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE WORKORDERREQUEST WITH (ROWLOCK)
      SET EditDate = GETDATE() 
         ,EditWho  = SUSER_SNAME() 
         ,TrafficCop = NULL
      FROM WORKORDERREQUEST
      JOIN DELETED  ON (DELETED.WorkOrderKey = WORKORDERREQUEST.WorkOrderKey)
      JOIN INSERTED ON (DELETED.WorkOrderKey = INSERTED.WorkOrderKey)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63700  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderRequestUpdate)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO QUIT
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   --(Wan01) - START
--   UPDATE WORKORDERREQUESTINPUTS WITH (ROWLOCK)
--   SET QtyJob       = WORQI.QtyJob + ((INSERTED.QtyJob - DELETED.QtyJob)*(WORQI.Qty / INSERTED.UOMQty)) 
--      ,QtyRemaining = WORQI.QtyRemaining + ((INSERTED.QtyRemaining - DELETED.QtyRemaining )*(WORQI.Qty / INSERTED.UOMQty))
--      ,QtyReleased  = CASE WHEN WORQI.QtyJob > 0 THEN INSERTED.QtyReleased ELSE 0 END
   UPDATE WORKORDERREQUESTINPUTS WITH (ROWLOCK)
   SET QtyRemaining = CASE WHEN WORQI.QtyAddOn > 0 THEN WORQI.QtyRemaining
                           ELSE WORQI.QtyRemaining + (((INSERTED.QtyRemaining - DELETED.QtyRemaining)/INSERTED.PackQty) 
                             * (WORQI.Qty / INSERTED.UOMQty))
                           END
      ,QtyJob       = WORQI.QtyJob + (((INSERTED.QtyJob - DELETED.QtyJob)/INSERTED.PackQty)
                      * (WORQI.Qty / INSERTED.UOMQty)) 
      ,QtyReleased  = WORQI.QtyReleased + CASE WHEN WORQI.SKU <> '' 
                                               THEN (INSERTED.QtyReleased - DELETED.QtyReleased) 
                                               ELSE 0 END
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      ,Trafficcop   = NULL
   FROM INSERTED
   JOIN DELETED ON (INSERTED.WorkOrderKey = DELETED.Workorderkey)
   JOIN WORKORDERREQUESTINPUTS WORQI ON (DELETED.WorkOrderkey = WORQI.WorkOrderkey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUESTINPUTS. (ntrWorkOrderRequestUpdate)' 
      GOTO QUIT
   END 

   UPDATE WORKORDERREQUESTOUTPUTS WITH (ROWLOCK)
   SET QtyRemaining = WORQO.QtyRemaining + (((INSERTED.QtyRemaining - DELETED.QtyRemaining)/INSERTED.PackQty)* (WORQO.Qty / INSERTED.UOMQty))
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      ,Trafficcop   = NULL
   FROM INSERTED
   JOIN DELETED ON (INSERTED.WorkOrderKey = DELETED.Workorderkey)
   JOIN WORKORDERREQUESTOUTPUTS WORQO ON (DELETED.WorkOrderkey = WORQO.WorkOrderkey)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUESTINPUTS. (ntrWorkOrderRequestUpdate)' 
      GOTO QUIT
   END 

   UPDATE WORKORDERREQUEST WITH (ROWLOCK)
   SET WOStatus     = CASE WHEN INSERTED.WOStatus = '9' THEN '9'
                           WHEN INSERTED.QtyReleased > 0 AND INSERTED.QtyRemaining = 0 THEN '7'
                           WHEN INSERTED.QtyReleased > 0 AND INSERTED.QtyRemaining > 0 THEN '5'
                           WHEN INSERTED.QtyJob      > 0 THEN '3'
                           WHEN INSERTED.QtyJob      = 0 THEN '0'
                           ELSE INSERTED.WOStatus
                           END
      ,QtyRemaining = INSERTED.UOMQtyRemaining * WOR.PackQty
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      ,Trafficcop   = NULL
   FROM INSERTED
   JOIN DELETED              ON (INSERTED.WorkOrderKey = DELETED.Workorderkey)
   JOIN WORKORDERREQUEST WOR ON (INSERTED.WorkOrderKey = WOR.Workorderkey)

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUEST. (ntrWorkOrderRequestUpdate)' 
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderRequestUpdate'    
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