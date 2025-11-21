SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* Date         Author    Ver.  Purposes                                         */  
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()              */
/* 28-Oct-2013  TLTING    1.2   Review Editdate column update                    */
/* 24-Apr-2014  CSCHONG   1.3   Add Lottable06-15                                */

CREATE TRIGGER ntrCaseManifestUpdate  
 ON  CaseManifest  
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

 DECLARE @b_debug int  
 SELECT @b_debug = 0  
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
      /* #INCLUDE <TRMANU1.SQL> */       
 IF @n_continue=1 or @n_continue=2  
 BEGIN  
 IF @b_debug = 1  
 BEGIN  
 SELECT "Reject UPDATE when CASEMANIFEST.Status already 'Received'"  
 END  
 IF EXISTS(SELECT * FROM DELETED WHERE Status = "9")  
 AND (     UPDATE(Storerkey)  
 OR UPDATE(Sku)  
 OR UPDATE(ExpectedPOKey)  
 OR UPDATE(ExpectedReceiptKey)  
 OR UPDATE(ReceivedPOKey)  
 OR UPDATE(ReceivedReceiptKey)  
 OR UPDATE(Status)  
 OR UPDATE(Qty)  
 )  
 BEGIN  
 SELECT @n_continue=3  
 SELECT @n_err=68700  
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE rejected. CASEMANIFEST.Status = 'RECEIVED'. (ntrCaseManifestUpdate)"  
 END  
 END  
 IF @n_continue=1 or @n_continue=2  
 BEGIN  
 IF @b_debug = 1  
 BEGIN  
 SELECT "Reject UPDATE when CASEMANIFEST.Status already 'SHIPPED'"  
 END  
 IF EXISTS(SELECT * FROM DELETED WHERE ShipStatus = "9")  
 AND (     UPDATE(Storerkey)  
 OR UPDATE(Sku)  
 OR UPDATE(ExpectedPOKey)  
 OR UPDATE(ExpectedReceiptKey)  
 OR UPDATE(ReceivedPOKey)  
 OR UPDATE(ReceivedReceiptKey)  
 OR UPDATE(Status)  
 OR UPDATE(ShipStatus)  
 OR UPDATE(Qty)  
 OR UPDATE(ExpectedCLPOrderKey)  
 OR UPDATE(ShippedCLPOrderKey)  
 )  
 BEGIN  
 SELECT @n_continue=3  
 SELECT @n_err=68701  
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE rejected. CASEMANIFEST.ShipStatus = 'SHIPPED'. (ntrCaseManifestUpdate)"  
 END  
 END  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
 IF UPDATE(caseid)  
 BEGIN  
 IF EXISTS(Select Palletkey FROM palletdetail,deleted  
 where palletdetail.caseid = deleted.caseid)  
 BEGIN  
 UPDATE PALLETDETAIL  with (ROWLOCK)
 SET PALLETDETAIL.CaseId = INSERTED.CaseId,
      EditDate = GETDATE(),
      EditWho = SUSER_SNAME()  
 FROM PALLETDETAIL, INSERTED, DELETED  
 WHERE PALLETDETAIL.CaseId = DELETED.CaseId  
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 IF @n_err <> 0  
 BEGIN  
 SELECT @n_continue = 3  
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68706   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE rejected. The CaseId Exists but NOT Updated In The Pallet Tables. (ntrCaseManifestUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "  
 END  
 END  
 END  
 END  
 -- IF @n_continue = 1 or @n_continue = 2  
 --      BEGIN  
 --           UPDATE RECEIPTDETAIL  
 --                SET QtyExpected = QtyExpected -  
 --                 (select sum(DELETED.Qty) from deleted  
 --                   where RECEIPTDETAIL.ReceiptKey = DELETED.ExpectedReceiptKey  
 --                     AND RECEIPTDETAIL.StorerKey = DELETED.StorerKey  
 --                     AND RECEIPTDETAIL.Sku = DELETED.Sku  
 --                     AND RECEIPTDETAIL.POKey = DELETED.ExpectedPOKey)  
 --                FROM RECEIPTDETAIL, DELETED D1  
 --                WHERE RECEIPTDETAIL.ReceiptKey = D1.ExpectedReceiptKey  
 --                     AND RECEIPTDETAIL.StorerKey = D1.StorerKey  
 --                     AND RECEIPTDETAIL.Sku = D1.Sku  
 --                     AND RECEIPTDETAIL.POKey = D1.ExpectedPOKey  
 --           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 --           IF @n_err <> 0  
 --           BEGIN  
 --    SELECT @n_continue = 3  
 --                  
 --                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 --                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ON Table RECEIPTDETAIL Failed. (ntrCaseManifestUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "  
 --                  
 --           END  
 --      END  
 --      IF @n_continue = 1 or @n_continue = 2  
 --      BEGIN  
 --           UPDATE RECEIPTDETAIL  
 --                SET QtyExpected = QtyExpected +  
 --                 (select sum(INSERTED.Qty) from inserted  
 --                 WHERE RECEIPTDETAIL.ReceiptKey = INSERTED.ExpectedReceiptKey  
 --                     AND RECEIPTDETAIL.StorerKey = INSERTED.StorerKey  
 --                     AND RECEIPTDETAIL.Sku = INSERTED.Sku  
 --                     AND RECEIPTDETAIL.POKey = INSERTED.ExpectedPOKey)  
 --                FROM RECEIPTDETAIL, INSERTED I1  
 --                WHERE RECEIPTDETAIL.ReceiptKey = I1.ExpectedReceiptKey  
 --                     AND RECEIPTDETAIL.StorerKey = I1.StorerKey  
 --                     AND RECEIPTDETAIL.Sku = I1.Sku  
 --                     AND RECEIPTDETAIL.POKey = I1.ExpectedPOKey  
 --           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 --           IF @n_err <> 0  
 --           BEGIN  
 --                SELECT @n_continue = 3  
 --                  
 --                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 --                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ON Table RECEIPTDETAIL Failed. (ntrCaseManifestUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "  
 --                  
 --           END  
 --      END  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
 IF UPDATE(Status)  
 BEGIN  
 UPDATE RECEIPTDETAIL  
 SET QtyReceived = QtyReceived +  
 (select sum(INSERTED.Qty)
 from inserted  
 WHERE   RECEIPTDETAIL.ReceiptKey = INSERTED.ReceivedReceiptKey  
 AND RECEIPTDETAIL.StorerKey = INSERTED.StorerKey  
 AND RECEIPTDETAIL.Sku = INSERTED.Sku  
 AND RECEIPTDETAIL.POKey = INSERTED.ReceivedPOKey  
 AND INSERTED.Status = "9"),
     EditDate = GETDATE(),   --tlting
     EditWho = SUSER_SNAME()  
 FROM RECEIPTDETAIL, INSERTED I2  
 WHERE  
 RECEIPTDETAIL.ReceiptKey = I2.ReceivedReceiptKey  
 AND RECEIPTDETAIL.StorerKey = I2.StorerKey  
 AND RECEIPTDETAIL.Sku = I2.Sku  
 AND RECEIPTDETAIL.POKey = I2.ReceivedPOKey  
 AND I2.Status = "9"  
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 IF @n_err <> 0  
 BEGIN  
 SELECT @n_continue = 3  
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ON Table RECEIPTDETAIL Failed. (ntrCaseManifestUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "  
 END  
 END  
 END  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
 DECLARE @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20), @n_qty int ,  
 @c_loc NVARCHAR(10), @d_effectivedate datetime, @c_itrnkey NVARCHAR(10)  
 DECLARE @c_controlbreak NVARCHAR(20)  
 SELECT @c_controlbreak = SPACE(20)  
 WHILE (1=1)  
 BEGIN  
 SET ROWCOUNT 1  
 SELECT @c_controlbreak = inserted.caseid FROM INSERTED,DELETED  
 WHERE inserted.caseid > @c_controlbreak  
 AND INSERTED.Status = "9"  
 AND dbo.fnc_LTRIM(dbo.fnc_RTRIM(INSERTED.ReceivedReceiptKey)) IS NULL  
 AND DELETED.Status < "9"  
 ORDER BY INSERTED.caseid  
 IF @@ROWCOUNT = 1  
 BEGIN  
 SET ROWCOUNT 0  
 SELECT @c_storerkey = INSERTED.storerkey ,  
 @c_sku = INSERTED.sku ,  
 @n_qty = INSERTED.Qty ,  
 @c_loc = INSERTED.Loc ,  
 @d_effectivedate = getdate()  
 FROM INSERTED , DELETED  
 WHERE INSERTED.caseid = @c_controlbreak  
 AND INSERTED.Status = "9"  
 AND dbo.fnc_LTRIM(dbo.fnc_RTRIM(INSERTED.ReceivedReceiptKey)) IS NULL  
 AND DELETED.Status < "9"  
 IF @@ROWCOUNT = 1  
 BEGIN  
 SELECT @b_success = 0  
 EXECUTE nspItrnAddDeposit  
 @n_ItrnSysId  = NULL,  
 @c_StorerKey  = @c_storerkey,  
 @c_Sku        = @c_sku,  
 @c_Lot        = "",  
 @c_ToLoc      = @c_loc,  
 @c_ToID       = "",  
 @c_Status     = "",  
 @c_lottable01 = "",  
 @c_lottable02 = "",  
 @c_lottable03 = "",  
 @d_lottable04 = NULL,  
 @d_lottable05 = NULL, 
 @c_lottable06 = "",    --(CS01)
 @c_lottable07 = "",		--(CS01)
 @c_lottable08 = "",		--(CS01)
 @c_lottable09 = "",		--(CS01)
 @c_lottable10 = "",		--(CS01)
 @c_lottable11 = "",		--(CS01)
 @c_lottable12 = "",		--(CS01)
 @d_lottable13 = NULL,	--(CS01)
 @d_lottable14 = NULL,	--(CS01)
 @d_lottable15 = NULL,	--(CS01) 
 @n_casecnt    = 1,  
 @n_innerpack  = 0,  
 @n_qty        = @n_qty,  
 @n_pallet     = 0,  
 @f_cube       = 0,  
 @f_grosswgt   = 0,  
 @f_netwgt     = 0,  
 @f_otherunit1 = 0,  
 @f_otherunit2 = 0,  
 @c_SourceKey  = @c_controlbreak,  
 @c_SourceType = "ntrCaseManifestUpdate",  
 @c_PackKey    = "",  
 @c_UOM        = "",  
 @b_UOMCalc    = 0,  
 @d_EffectiveDate = @d_effectiveDate,  
 @c_itrnkey    = @c_itrnkey OUTPUT,  
 @b_Success    = @b_Success OUTPUT,  
 @n_err        = @n_err     OUTPUT,  
 @c_errmsg     = @c_errmsg  OUTPUT  
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
 IF (@n_continue = 1 or @n_continue=2  ) AND NOT UPDATE(EditDate)
 BEGIN  
 IF @b_debug = 1  
 BEGIN  
 SELECT "Update EditDate and EditWho"  
 END  
 UPDATE CASEMANIFEST with (ROWLOCK)
 SET  EditDate = GETDATE(),  
 EditWho = SUSER_SNAME()  
 FROM CASEMANIFEST, INSERTED  
 WHERE CASEMANIFEST.CaseId = INSERTED.CaseId  
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 IF @n_err <> 0  
 BEGIN  
 SELECT @n_continue = 3  
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table CASEMANIFEST. (ntrCaseManifestUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "  
 END  
 END  
      /* #INCLUDE <TRMANU2.SQL> */  
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrCaseManifestUpdate"  
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