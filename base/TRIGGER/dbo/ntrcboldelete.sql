SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrCBOLDelete                                               */
/* Creation Date: 12-Jul-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: UWP-21342 - New Delete trigger for CBOL                     */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records deleted                                      */
/*                                                                      */
/* Github Version: 1.0                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Jul-2024  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE   TRIGGER [dbo].[ntrCBOLDelete]
ON CBOL
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
   DECLARE @b_Success   INT -- Populated by calls to stored procedures - was the proc successful?
         , @n_err       INT -- Error number returned by stored procedure or this trigger
         , @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue  INT -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
         , @n_starttcnt INT -- Holds the current transaction count
         , @n_cnt       INT -- Holds the number of rows affected by the DELETE statement that fired this trigger.
         , @c_authority NVARCHAR(1)
   SELECT @n_continue = 1
        , @n_starttcnt = @@TRANCOUNT
   IF (  SELECT COUNT(*)
         FROM DELETED) = (  SELECT COUNT(*)
                            FROM DELETED
                            WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
   IF EXISTS (  SELECT 1
                FROM DELETED
                WHERE [Status] < '9')
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @b_Success = 0
         EXECUTE nspGetRight NULL -- facility  
                           , NULL -- Storerkey  
                           , NULL -- Sku  
                           , 'DataMartDELLOG' -- Configkey  
                           , @b_Success OUTPUT
                           , @c_authority OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
                 , @c_errmsg = N'ntrCBOLDelete' + dbo.fnc_RTRIM(@c_errmsg)
         END
         ELSE IF @c_authority = '1'
         BEGIN
            INSERT INTO dbo.CBOL_DELLOG (CbolKey)
            SELECT CbolKey
            FROM DELETED
            WHERE [Status] < '9'
            SELECT @n_err = @@ERROR
                 , @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                    , @n_err = 60540 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                  + N': Delete Trigger On Table ORDERS Failed. (ntrCBOLDelete)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
            END
         END
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM DELETED
                   WHERE [Status] = '9')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 60545
         SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                            + N': DELETE rejected. MBOL.Status = ''Shipped''. (ntrCBOLDelete)'
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE CBOL
      FROM CBOL, DELETED
      WHERE CBOL.CbolKey = DELETED.CbolKey
      SELECT @n_err = @@ERROR
           , @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
              , @n_err = 60550 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                            + N': Delete Trigger On Table CBOL Failed. (ntrCBOLDelete)' + N' ( '
                            + N' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + N' ) '
      END
   END
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrCBOLDelete'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
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