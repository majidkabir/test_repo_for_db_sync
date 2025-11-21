SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrWCSRoutingUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WCSRouting Update Transaction                              */
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
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author       Rev   Purposes                               */
/* 28Sep2015  TLTING       1.1   Update(Editdate)                       */
/*                                                                      */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrWCSRoutingUpdate]
ON  [dbo].[WCSRouting] FOR UPDATE
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

   DECLARE @b_Success    INT
         , @n_err        INT
         , @n_err2       INT
         , @c_errmsg     NVARCHAR(250)
         , @n_continue   INT
         , @n_starttcnt  INT
         , @c_preprocess NVARCHAR(250)
         , @c_pstprocess NVARCHAR(250)
         , @n_cnt        INT
         , @c_authority  NVARCHAR(1)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   -- tlting01
   IF ( @n_continue = 1 OR @n_continue = 2 ) OR UPDATE (EditDate)
   BEGIN
      UPDATE WCSRouting
      SET EditDate = GETDATE(),
          EditWho  = SUSER_SNAME(),
          TrafficCop = NULL
      FROM WCSRouting W WITH (NOLOCK)
      JOIN INSERTED I ON W.WCSKey = I.WCSKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 69843
         SET @c_errmsg = 'NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table WCSRouting. (ntrWCSRoutingUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 3
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
      EXECUTE nsp_LogError @n_err, @c_errmsg, 'ntrWCSRoutingUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
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