SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPODetailUpdate                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 17-Mar-2009  TLTING   1.0  Change user_name() to SUSER_SNAME()       */
/* 22-May-2012  TLTING01 1.1  DM Integrity issue - Update editdate for  */
/*                            status < '9'                              */
/* 28-Oct-2013  TLTING   1.2  Review Editdate column update             */
/* 2014-08-26   YTWan    1.3  SOS#319232 - TH-PO not allow to add       */
/*                            Invactive-SKU. (Wan01)                    */
/* 2016-08-02   Ung      1.4  IN00110559 Enable trigger pass out error  */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrPODetailUpdate]
ON  [dbo].[PODETAIL]
FOR UPDATE
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
   
   DECLARE
   @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2 int              -- For Additional Error Detection
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue int
   ,         @n_starttcnt int                -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250)         -- preprocess
   ,         @c_pstprocess NVARCHAR(250)         -- post process
   ,         @n_cnt int
   ,  @c_PODisallowInactiveSku   NVARCHAR(10)      --(Wan01)
   ,  @c_Storerkey               NVARCHAR(15)      --(Wan01)
   ,  @c_InactiveSku             NVARCHAR(20)      --(Wan01)
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   --tlting01
   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE PODETAIL
      SET EditDate = GETDATE(), EditWho = Suser_Sname(), TrafficCop = NULL
      FROM PODETAIL, INSERTED
      WHERE PODETAIL.POKey = INSERTED.POKey AND PODETAIL.POLineNumber = INSERTED.POLineNumber
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
         SELECT @n_err = 200001
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PODETAIL. (ntrPODetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
        /* #INCLUDE <TRPODU1.SQL> */
   -- Added By SHONG
   -- Spec From Thailand
   -- Not Allow to Modify PO When Extern Status = 9 or CLOSED
   -- Date: 05th Dec 2000
   --IF @n_continue=1 or @n_continue=2
   --BEGIN
   --   IF EXISTS(SELECT DELETED.POKEY FROM DELETED, PO WHERE PO.POKey = DELETED.POKEY
   --            AND    PO.ExternStatus = "9")
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": PO Detail Cannot be Modified, Status = CLOSED. (ntrPODetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   --   END
   --END
   -- End of Modify
   --(Wan01) - START
   
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SET @c_Storerkey = ''
      SELECT TOP 1 @c_Storerkey = INSERTED.Storerkey
      FROM INSERTED
      JOIN DELETED ON (INSERTED.POKey = DELETED.POKey)
                   AND(INSERTED.POLineNumber = DELETED.POLineNumber)
   
      SET @c_PODisAllowInactiveSku = 0
      SET @b_success = 0
      Execute nspGetRight null   -- facility
              ,  @c_StorerKey    -- Storerkey
              ,  null            -- Sku
              ,  'PODisallowInactiveSku'    -- Configkey
              ,  @b_success               OUTPUT
              ,  @c_PODisAllowInactiveSku OUTPUT
              ,  @n_err                   OUTPUT
              ,  @c_errmsg                OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 200002
         SET @c_errmsg = 'ntrPODetailUpdate ' + RTRIM(@c_errmsg)
      END
      ELSE IF @c_PODisAllowInactiveSku = '1'
      BEGIN
         SET @c_InactiveSku = ''
         SELECT TOP 1 @c_InactiveSku = RTRIM(SKU.Sku)
         FROM INSERTED
         JOIN DELETED ON (INSERTED.POKey = DELETED.POKey)
                      AND(INSERTED.POLineNumber = DELETED.POLineNumber)
         JOIN SKU WITH (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey)
                                AND(INSERTED.Sku = SKU.Sku)
         WHERE SKU.SkuStatus = 'Inactive'
   
         IF @c_InactiveSku <> ''
         BEGIN
            SET @n_continue = 3
            SET @n_err = 200003
            SET @c_errmsg = 'ntrPODetailUpdate. Disallow Inactive Sku: ' + RTRIM(@c_InactiveSku) + 'add to PO.'
         END
      END
   END
   --(Wan01) - END
   
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         UPDATE    CASEMANIFEST
         SET   StorerKey = INSERTED.StorerKey,
               Sku       = INSERTED.Sku,
               ExpectedPOKey = INSERTED.POKey,
               EditDate = GETDATE(),   --tlting
               EditWho = SUSER_SNAME()
         FROM  CASEMANIFEST, INSERTED, DELETED
         WHERE CASEMANIFEST.StorerKey             = DELETED.StorerKey
         AND  CASEMANIFEST.Sku                   = DELETED.Sku
         AND  CASEMANIFEST.ExpectedPOKey         = DELETED.POKey
         AND ( NOT INSERTED.StorerKey   = DELETED.StorerKey
               OR   NOT INSERTED.Sku         = DELETED.Sku
               OR   NOT INSERTED.POKey       = DELETED.POKey )
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         UPDATE PODETAIL
         SET PODETAIL.QtyAdjusted = PODETAIL.QtyAdjusted - DELETED.QtyOrdered + INSERTED.QtyOrdered
         FROM PODETAIL, DELETED, INSERTED
         WHERE PODETAIL.POKey = DELETED.POKey AND PODETAIL.POLineNumber = DELETED.POLineNumber
         AND PODETAIL.POKey = INSERTED.POKey AND PODETAIL.POLineNumber = INSERTED.POLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
            SELECT @n_err = 200004
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PODETAIL. (ntrPODetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      DECLARE @n_deletedcount int
      SELECT @n_deletedcount = (select count(*) FROM deleted)
      IF @n_deletedcount = 1
      BEGIN
         UPDATE PO  with (ROWLOCK)
         SET  OpenQty = PO.OpenQty - (DELETED.QtyOrdered - DELETED.QtyReceived) + (INSERTED.QtyOrdered - INSERTED.QtyReceived),
               EditDate = GETDATE(),   --tlting
               EditWho = SUSER_SNAME()
         FROM PO, INSERTED, DELETED
         WHERE PO.POKey = INSERTED.POKey
           AND INSERTED.POKey = DELETED.POKey
      END
      ELSE
      BEGIN
         UPDATE PO SET PO.OpenQty = (PO.Openqty -
               (Select Sum(DELETED.QtyOrdered - DELETED.QtyReceived) From DELETED
                 Where DELETED.POKey = PO.POKey)
                +
               (Select Sum(INSERTED.QtyOrdered - INSERTED.QtyReceived) From INSERTED
                Where INSERTED.POKey = PO.POKey)
                ),
                EditDate = GETDATE(),   --tlting
                EditWho = SUSER_SNAME()
         FROM PO,DELETED,INSERTED
         WHERE PO.POKey IN (SELECT Distinct POKey From DELETED)
         AND PO.POKey = DELETED.POKey
         AND PO.POKey = INSERTED.POKey
         AND INSERTED.POKey = DELETED.POKey
         AND INSERTED.POLineNumber = DELETED.POLineNumber
      END
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
         SELECT @n_err = 200005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table PO. (ntrPODetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   /* #INCLUDE <TRPODU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
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
         execute nsp_logerror @n_err, @c_errmsg, "ntrPODetailUpdate"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
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