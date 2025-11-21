SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrWCS_SortationUpdate                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Update UCC.                                                */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author   Ver  Purposes                                  */
/* 27-Jun-2012  Ung      1.0  Created                                   */
/* 28-Oct-2013  TLTING   1.1  Review Editdate column update             */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrWCS_SortationUpdate]
ON  [dbo].[WCS_Sortation]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_err int              -- Error number returned by stored procedure or this trigger
         , @c_errmsg Nvarchar(250)     -- Error message returned by stored procedure or this trigger
         , @n_continue int
         , @n_starttcnt int        -- Holds the current transaction count

         , @n_cnt int
         , @n_IsRDT INT            -- KHLim01
         , @c_PreUN Nvarchar(5)     -- KHLim01

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      -- KHLim01 start
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
      IF @n_IsRDT = 1
      BEGIN
         SET @c_PreUN = 'rdt.'
      END
      ELSE
      BEGIN
         SET @c_PreUN = ''
      END
      -- KHLim01 end

      UPDATE WCS_Sortation with (RowLock)
         SET EditDate = GETDATE(),
             EditWho = @c_PreUN + SUSER_SNAME() -- KHLim01
        FROM WCS_Sortation, INSERTED
       WHERE WCS_Sortation.RowRef = INSERTED.RowRef

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(Nvarchar(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(Nvarchar(5),ISNULL(@n_err,0))
                         +': Update Failed On Table WCS_Sortation. (ntrWCS_SortationUpdate)' + ' ( '
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
      END
   END
   /* END Added */



   /* #INCLUDE <TRPU_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWCS_SortationUpdate'
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