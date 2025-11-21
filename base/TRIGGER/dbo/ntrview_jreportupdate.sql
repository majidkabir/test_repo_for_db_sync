SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Trigger:  ntrView_JReportUpdate                                               */
/* Creation Date: 2020-06-23                                                     */
/* Copyright: LFL                                                                */
/* Written by: WLChooi                                                           */
/*                                                                               */
/* Purpose:  Trigger point upon any Update on the View_JReport                   */
/*                                                                               */
/* Return Status:  None                                                          */
/*                                                                               */
/* Usage:                                                                        */
/*                                                                               */
/* Local Variables:                                                              */
/*                                                                               */
/* Called By: When records updated                                               */
/*                                                                               */
/* GitLab Version: 1.0                                                           */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date         Author    Ver.  Purposes                                         */
/*********************************************************************************/  

CREATE TRIGGER [dbo].[ntrView_JReportUpdate]
ON  [dbo].[View_JReport]
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

   IF (@n_continue = 1 or @n_continue = 2)  AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE View_JReport WITH (ROWLOCK)
      SET View_JReport.EditWho = SUSER_SNAME(),
          View_JReport.EditDate = GETDATE()
      FROM View_JReport JOIN INSERTED ON View_JReport.JReport_ID = INSERTED.JReport_ID

      SELECT @n_err = @@ERROR 

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table View_JReport. (ntrView_JReportUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrView_JReportUpdate'
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