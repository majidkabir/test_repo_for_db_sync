SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING     Review Editdate column update                */

CREATE TRIGGER [dbo].[ntrPalletDetailUpdate]
 ON  [dbo].[PALLETDETAIL]
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
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 IF UPDATE(TrafficCop)
 BEGIN
 SELECT @n_continue = 4 
 END
 IF UPDATE(ArchiveCop)
 BEGIN
 SELECT @n_continue = 4 
 END
      /* #INCLUDE <TRPALDU1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
 IF EXISTS ( SELECT *
 FROM INSERTED
 WHERE NOT EXISTS ( SELECT *
 FROM SKU
 WHERE SKU.StorerKey = INSERTED.StorerKey
 AND SKU.Sku = INSERTED.Sku )
 AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(Sku)) IS NULL )
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=67703
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad PALLETDETAIL.StorerKey or PALLETDETAIL.Sku. (ntrPalletDetailUpdate)"
 END
 END
 IF @n_continue =1 or @n_continue =2
 BEGIN
 UPDATE PALLETDETAIL
 SET  StorerKey = CASEMANIFEST.StorerKey,
 Sku = CASEMANIFEST.Sku ,
 Qty = CASEMANIFEST.Qty
 FROM PALLETDETAIL, INSERTED, CASEMANIFEST
 WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
 AND PALLETDETAIL.CaseId = INSERTED.CaseId
 AND CASEMANIFEST.CaseId = INSERTED.CaseId
 AND dbo.fnc_LTrim(dbo.fnc_RTrim(INSERTED.Caseid)) IS NOT NULL
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
 UPDATE CASEMANIFEST
 SET ShipStatus = "9",
      EditDate = GETDATE(),   --tlting
      EditWho = SUSER_SNAME()
 FROM CASEMANIFEST, INSERTED
 WHERE CASEMANIFEST.CaseId = INSERTED.CaseId
 AND INSERTED.Status = "9"
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table CASEMANIFEST. (ntrPalletDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
 BEGIN
 UPDATE PALLETDETAIL with (ROWLOCK)
 SET  EditDate = GETDATE(),
 EditWho = SUSER_SNAME()
 FROM PALLETDETAIL, INSERTED
 WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
 AND PALLETDETAIL.PalletLineNumber = INSERTED.PalletLineNumber
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PALLETDETAIL. (ntrPalletDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
      /* #INCLUDE <TRPALDU2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrPalletDetailUpdate"
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