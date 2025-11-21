SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrNonInvDelete                                                */
/* Creation Date: 18-Oct-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Trigger when Delete Non Inventory item                        */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/***************************************************************************/

CREATE TRIGGER ntrNonInvDelete ON NONINV
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

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT     


   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED
               JOIN WORKORDERINPUTS  WITH (NOLOCK) ON (DELETED.Storerkey = WORKORDERINPUTS.Storerkey)
                                                   AND(DELETED.NonInvSku = WORKORDERINPUTS.NonInvSku)
               JOIN WORKORDERROUTING WITH (NOLOCK) ON (WORKORDERINPUTS.MasterWorkOrder = WORKORDERROUTING.MasterWorkOrder)
                                                   AND(WORKORDERINPUTS.WorkOrderName = WORKORDERROUTING.WorkOrderName)
                                                   AND(DELETED.Facility = WORKORDERROUTING.Facility)
             )  
   BEGIN
      SET @n_continue = 3
      SET @n_err=63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Not Allow to delete Non Inventory exists in WORKORDERINPUTS. (ntrNonInvDelete)'
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED
               JOIN WORKORDEROUTPUTS WITH (NOLOCK) ON (DELETED.Storerkey = WORKORDEROUTPUTS.Storerkey)
                                                   AND(DELETED.NonInvSku = WORKORDEROUTPUTS.NonInvSku)
               JOIN WORKORDERROUTING WITH (NOLOCK) ON (WORKORDEROUTPUTS.MasterWorkOrder = WORKORDERROUTING.MasterWorkOrder)
                                                   AND(WORKORDEROUTPUTS.WorkOrderName = WORKORDERROUTING.WorkOrderName)
                                                   AND(DELETED.Facility = WORKORDERROUTING.Facility)
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err=63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Not Allow to delete Non Inventory exists in WORKORDEROUTPUTS. (ntrNonInvDelete)'
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrNonInvDelete'    
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