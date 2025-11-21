SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 24-Apr-2014  CSCHONG    Add Lottable06-15                            */

CREATE TRIGGER ntrCaseManifestAdd
ON CaseManifest
FOR  INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_Success     INT -- Populated by calls to stored procedures - was the proc successful?
          ,@n_err         INT -- Error number returned by stored procedure or this trigger
          ,@n_err2        INT -- For Additional Error Detection
          ,@c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger
          ,@n_continue    INT
          ,@n_starttcnt   INT -- Holds the current transaction count
          ,@c_preprocess  NVARCHAR(250) -- preprocess
          ,@c_pstprocess  NVARCHAR(250) -- post process
          ,@n_cnt         INT
   
   SELECT @n_continue = 1
         ,@n_starttcnt = @@TRANCOUNT
   /* #INCLUDE <TRMAN1.SQL> */ 
   --     IF @n_continue = 1 or @n_continue = 2
   --     BEGIN
   --          UPDATE RECEIPTDETAIL
   --               SET  QtyExpected = QtyExpected +
   --                (select sum(inserted.qty) from inserted
   --                  where RECEIPTDETAIL.ReceiptKey = INSERTED.ExpectedReceiptKey
   --                    AND RECEIPTDETAIL.StorerKey = INSERTED.StorerKey
   --                    AND RECEIPTDETAIL.Sku = INSERTED.Sku
   --                    AND RECEIPTDETAIL.POKey = INSERTED.ExpectedPOKey)
   --                   FROM RECEIPTDETAIL, INSERTED I2
   --               WHERE RECEIPTDETAIL.ReceiptKey = I2.ExpectedReceiptKey
   --                    AND RECEIPTDETAIL.StorerKey = I2.StorerKey
   --                    AND RECEIPTDETAIL.Sku = I2.Sku
   --                    AND RECEIPTDETAIL.POKey = I2.ExpectedPOKey
   --          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   --          IF @n_err <> 0
   --          BEGIN
   --               SELECT @n_continue = 3
   --
   --               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ON Table RECEIPTDETAIL Failed. (ntrCaseManifestAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   --
   --          END
   --     END
   
   BEGIN
      UPDATE RECEIPTDETAIL
      SET    QtyReceived = QtyReceived + (
                 SELECT SUM(INSERTED.qty)
                 FROM   INSERTED
                 WHERE  RECEIPTDETAIL.ReceiptKey = INSERTED.ReceivedReceiptKey
                 AND    receiptdetail.pokey = INSERTED.ReceivedPOKey
                 AND    receiptdetail.sku = INSERTED.sku
                 AND    receiptdetail.storerkey = INSERTED.storerkey
             )
      FROM   RECEIPTDETAIL
            ,INSERTED I1
      WHERE  RECEIPTDETAIL.ReceiptKey = I1.ReceivedReceiptKey
      AND    RECEIPTDETAIL.StorerKey = I1.StorerKey
      AND    RECEIPTDETAIL.Sku = I1.Sku
      AND    RECEIPTDETAIL.POKey = I1.ReceivedPOKey
      AND    I1.Status = "9"
      
      SELECT @n_err = @@ERROR
            ,@n_cnt = @@ROWCOUNT
      
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                ,@n_err = 68602 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg = "NSQL" + CONVERT(CHAR(5) ,@n_err) + ": Update ON Table RECEIPTDETAIL Failed. (ntrCaseManifestAdd)" +
                 " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      DECLARE @c_storerkey NVARCHAR(15)
             ,@c_sku NVARCHAR(20)
             ,@n_qty INT
             ,@c_loc NVARCHAR(10)
             ,@d_effectivedate DATETIME
             ,@c_itrnkey NVARCHAR(10)
      
      DECLARE @c_controlbreak NVARCHAR(20)
      SELECT @c_controlbreak = SPACE(20)
      WHILE (1 = 1)
      BEGIN
          SET ROWCOUNT 1
          SELECT @c_controlbreak = caseid
          FROM   INSERTED
          WHERE  caseid > @c_controlbreak
          AND    INSERTED.Status = "9"
          AND    dbo.fnc_LTrim(dbo.fnc_RTrim(ReceivedReceiptKey)) IS NULL
          ORDER BY
                 caseid
          
          IF @@ROWCOUNT = 1
          BEGIN
             SET ROWCOUNT 0
             SELECT @c_storerkey = storerkey
                   ,@c_sku = sku
                   ,@n_qty = Qty
                   ,@c_loc = Loc
                   ,@d_effectivedate = GETDATE()
             FROM   INSERTED
             WHERE  caseid = @c_controlbreak
             AND    INSERTED.Status = "9"
             AND    dbo.fnc_LTrim(dbo.fnc_RTrim(ReceivedReceiptKey)) IS NULL
             
             IF @@ROWCOUNT = 1
             BEGIN
                 SELECT @b_success = 0
                 EXECUTE nspItrnAddDeposit
                 @n_ItrnSysId = NULL,
                 @c_StorerKey = @c_storerkey,
                 @c_Sku = @c_sku,
                 @c_Lot = "",
                 @c_ToLoc = @c_loc,
                 @c_ToID = "",
                 @c_Status = "",
                 @c_lottable01 = "",
                 @c_lottable02 = "",
                 @c_lottable03 = "",
                 @d_lottable04 = NULL,
                 @d_lottable05 = NULL,
                 @c_lottable06 = "", --(CS01)
                 @c_lottable07 = "", --(CS01)
                 @c_lottable08 = "", --(CS01)
                 @c_lottable09 = "", --(CS01)
                 @c_lottable10 = "", --(CS01)
                 @c_lottable11 = "", --(CS01)
                 @c_lottable12 = "", --(CS01)
                 @d_lottable13 = NULL, --(CS01)
                 @d_lottable14 = NULL, --(CS01)
                 @d_lottable15 = NULL, --(CS01)
                 @n_casecnt = 1,
                 @n_innerpack = 0,
                 @n_qty = @n_qty,
                 @n_pallet = 0,
                 @f_cube = 0,
                 @f_grosswgt = 0,
                 @f_netwgt = 0,
                 @f_otherunit1 = 0,
                 @f_otherunit2 = 0,
                 @c_SourceKey = @c_controlbreak,
                 @c_SourceType = "ntrCaseManifestAdd",
                 @c_PackKey = "",
                 @c_UOM = "",
                 @b_UOMCalc = 0,
                 @d_EffectiveDate = @d_effectiveDate,
                 @c_itrnkey = @c_itrnkey OUTPUT,
                 @b_Success = @b_Success OUTPUT,
                 @n_err = @n_err OUTPUT,
                 @c_errmsg = @c_errmsg OUTPUT
                 IF NOT @b_success = 1
                 BEGIN
                     SELECT @n_continue = 3
                     BREAK
                 END
             END
          END
          ELSE
          BEGIN
              BREAK
          END
      END
      SET ROWCOUNT 0
   END
   
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
       UPDATE CASEMANIFEST
       SET    TrafficCop = NULL
             ,AddDate = GETDATE()
             ,AddWho = SUSER_SNAME()
             ,EditDate = GETDATE()
             ,EditWho = SUSER_SNAME()
       FROM   CASEMANIFEST
             ,INSERTED
       WHERE  CASEMANIFEST.CaseId = INSERTED.CaseId
       
       SELECT @n_err = @@ERROR
             ,@n_cnt = @@ROWCOUNT
       
       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 68600 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = "NSQL" + CONVERT(CHAR(5) ,@n_err) + ": Insert Failed On Table CASEMANIFEST. (nspCaseManifestAdd)" +
                  " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
   END
   /* #INCLUDE <TRMAN2.SQL> */
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
       IF @@TRANCOUNT = 1
       AND @@TRANCOUNT >= @n_starttcnt
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
       EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrCaseManifestAdd"
       RAISERROR (@c_errmsg ,16 ,1) WITH SETERROR -- SQL2012
       RETURN
   END
   ELSE
   BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
           COMMIT TRAN
       END
   END
END

GO