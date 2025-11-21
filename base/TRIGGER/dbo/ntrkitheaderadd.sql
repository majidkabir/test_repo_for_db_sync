SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrKitHeaderAdd                                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  KIT Header Add Transaction                                 */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When insert new records                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 30-May-2007  Shong     Add Checking on TrifficCop and ArchiveCop     */
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/*                                                                      */
/************************************************************************/
CREATE TRIGGER ntrKitHeaderAdd
ON  KIT
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF
	
   DECLARE   @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2               int       -- For Additional Error Detection
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue           int
   ,         @n_starttcnt          int       -- Holds the current transaction count
   ,         @c_preprocess         NVARCHAR(250) -- preprocess
   ,         @c_pstprocess         NVARCHAR(250) -- post process
   ,         @n_cnt                int
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRTHA1.SQL> */
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SELECT @n_continue = 4

   IF EXISTS( SELECT 1 FROM INSERTED WHERE TrafficCop = '9')
      SELECT @n_continue = 4

   -- 10.8.99 WALLY
   -- set reasoncode as mandatory field
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_reasoncode NVARCHAR(10)
      SELECT @c_reasoncode = reasoncode 
      FROM   INSERTED
      IF ISNULL(dbo.fnc_RTrim(@c_reasoncode), '') = ''
      BEGIN
         SELECT @n_continue = 3, @n_err = 50000
         SELECT @c_errmsg = 'VALIDATION ERROR: Reason Code Required.'
      END
   END
   
   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE KIT
      SET TrafficCop = NULL,
          AddDate  = GETDATE(),
          AddWho   = SUSER_SNAME(),
          EditDate = GETDATE(),
          EditWho  = SUSER_SNAME()
      FROM KIT
      JOIN INSERTED ON KIT.KitKey = INSERTED.KitKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table KIT. (nspKitHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   /* #INCLUDE <TRTHA2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrKitHeaderAdd'
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
END



GO