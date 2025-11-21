SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Trigger:  ntrTrackingIDUpdate                                                 */
/* Creation Date: 2020-04-20                                                     */
/* Copyright: LFL                                                                */
/* Written by: WLChooi                                                           */
/*                                                                               */
/* Purpose:  Trigger point upon any Update on the TrackingID                     */
/*                                                                               */
/* Return Status:  None                                                          */
/*                                                                               */
/* Usage:                                                                        */
/*                                                                               */
/* Local Variables:                                                              */
/*                                                                               */
/* Called By: When records updated                                               */
/*                                                                               */
/* PVCS Version: 1.1                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date         Author    Ver.  Purposes                                         */
/* 06-Jul-2022  WLChooi   1.1   JSM-77218 Skip Trigger if updating ArchiveCop to */
/*                              9 (WL01)                                         */
/* 06-Jul-2022  WLChooi   1.1   DevOps Combine Script                            */
/*********************************************************************************/  

CREATE   TRIGGER [dbo].[ntrTrackingIDUpdate]
ON  [dbo].[TrackingID]
FOR UPDATE
AS
BEGIN -- main
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END     
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                int       -- Error number returned by stored procedure or this trigger
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue           int                 
         , @n_starttcnt          int       -- Holds the current transaction count
         , @c_TrafficCop         NCHAR(1)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT      

   SELECT @c_TrafficCop = TrafficCop
   FROM INSERTED
   
   IF UPDATE(TrafficCop)  
   BEGIN
      SELECT @n_continue = 4 
   END

   --WL01 S
   IF UPDATE(ArchiveCop)  
   BEGIN
      SELECT @n_continue = 4 
   END
   --WL01 E

   IF (@n_continue = 1 or @n_continue = 2)  AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE TrackingID WITH (ROWLOCK)
      SET TrackingID.EditWho = SUSER_SNAME(),
          TrackingID.EditDate = GETDATE(),
          TrackingID.TrafficCop = NULL
      FROM TrackingID JOIN INSERTED ON TrackingID.TrackingIDKey = INSERTED.TrackingIDKey

      SELECT @n_err = @@ERROR 

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TrackingID. (ntrTrackingIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
    END

   IF @n_continue = 3  -- Error Occured - Process And Return
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTrackingIDUpdate'
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- main

GO