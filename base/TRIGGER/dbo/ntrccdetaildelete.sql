SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Trigger: ntrCCDetailDelete                                           */  
/* Creation Date:14-Aug-2009                                            */  
/* Copyright: IDS                                                       */  
/* Written by:TLTing                                                    */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Ver   Purposes                               */  
/*  9-Jun-2011  KHLim01    1.1   Insert Delete log                      */
/* 14-Jul-2011  KHLim02    1.2   GetRight for Delete log                */
/* 23-May-2012  TLTING02         DM Data integrity - insert dellog B4   */
/*                               trafficCop                             */
/* 07-May-2014  TKLIM      1.3   Added Lottables 06-15                  */
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrCCDetailDelete]  
ON [dbo].[CCDetail]  
FOR DELETE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Success  int,       -- Populated by calls to stored procedures - was the proc successful?  
   @n_err              int,       -- Error number returned by stored procedure or this trigger  
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger  
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
   @n_starttcnt        int,       -- Holds the current transaction count  
   @n_cnt              int        -- Holds @@ROWCOUNT  
  ,@c_authority        NVARCHAR(1)  -- KHLim02
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   /* #INCLUDE <TRODD1.SQL> */  
   IF (SELECT COUNT(*) FROM DELETED) =  
      (SELECT COUNT(*) FROM DELETED WHERE DELETED.ARCHIVECOP = '9')  
   BEGIN  
      SELECT @n_continue = 4  
   END  
   
   --tlting02
   -- Start (KHLim01) 
   IF EXISTS ( SELECT 1 FROM DELETED WHERE [Status] <> '9' ) AND (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrCCDETAILDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.CCDETAIL_DELLOG ( CCDetailKey )
         SELECT CCDetailKey FROM DELETED
         WHERE [Status] <> '9'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62602   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table CCDETAIL Failed. (ntrCCDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

   IF @n_continue = 1 or @n_continue = 2
   BEGIN  
      IF EXISTS(SELECT 1 FROM DEL_CCDETAIL CC  
                JOIN DELETED ON CC.CCDetailKey = DELETED.CCDetailKey )  
      BEGIN  
         DELETE DEL_CCDETAIL  
         FROM DEL_CCDETAIL CC  
                JOIN DELETED ON CC.CCDetailKey = DELETED.CCDetailKey  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_CCDETAIL Failed. (ntrCCDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
         END  
      END  
  
      INSERT INTO DEL_CCDETAIL(CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot, Loc, Id, SystemQty,  
                  Qty, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, FinalizeFlag, 
                  Qty_Cnt2, Lottable01_Cnt2, Lottable02_Cnt2, Lottable03_Cnt2, Lottable04_Cnt2, Lottable05_Cnt2, FinalizeFlag_Cnt2,
                  Qty_Cnt3, Lottable01_Cnt3, Lottable02_Cnt3, Lottable03_Cnt3, Lottable04_Cnt3, Lottable05_Cnt3, FinalizeFlag_Cnt3, 
                  Status, StatusMsg, AddDate, AddWho, EditDate, EditWho,  
                  TrafficCop, ArchiveCop, RefNo, EditDate_Cnt1, EditWho_Cnt1, EditDate_Cnt2,  
                  EditWho_Cnt2, EditDate_Cnt3, EditWho_Cnt3, Counted_Cnt1, Counted_Cnt2, Counted_Cnt3,
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                  Lottable06_Cnt2, Lottable07_Cnt2, Lottable08_Cnt2, Lottable09_Cnt2, Lottable10_Cnt2, 
                  Lottable11_Cnt2, Lottable12_Cnt2, Lottable13_Cnt2, Lottable14_Cnt2, Lottable15_Cnt2,
                  Lottable06_Cnt3, Lottable07_Cnt3, Lottable08_Cnt3, Lottable09_Cnt3, Lottable10_Cnt3, 
                  Lottable11_Cnt3, Lottable12_Cnt3, Lottable13_Cnt3, Lottable14_Cnt3, Lottable15_Cnt3)  
      SELECT CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot, Loc, Id, SystemQty,   
                  Qty,Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, FinalizeFlag, 
                  Qty_Cnt2, Lottable01_Cnt2, Lottable02_Cnt2, Lottable03_Cnt2, Lottable04_Cnt2, Lottable05_Cnt2, FinalizeFlag_Cnt2,
                  Qty_Cnt3, Lottable01_Cnt3, Lottable02_Cnt3, Lottable03_Cnt3, Lottable04_Cnt3, Lottable05_Cnt3, FinalizeFlag_Cnt3, 
                  Status, StatusMsg, getdate(), suser_sname(), getdate(), suser_sname(),  
                  TrafficCop, ArchiveCop, RefNo, EditDate_Cnt1, EditWho_Cnt1, EditDate_Cnt2,  
                  EditWho_Cnt2, EditDate_Cnt3, EditWho_Cnt3, Counted_Cnt1, Counted_Cnt2, Counted_Cnt3,
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                  Lottable06_Cnt2, Lottable07_Cnt2, Lottable08_Cnt2, Lottable09_Cnt2, Lottable10_Cnt2, 
                  Lottable11_Cnt2, Lottable12_Cnt2, Lottable13_Cnt2, Lottable14_Cnt2, Lottable15_Cnt2,
                  Lottable06_Cnt3, Lottable07_Cnt3, Lottable08_Cnt3, Lottable09_Cnt3, Lottable10_Cnt3, 
                  Lottable11_Cnt3, Lottable12_Cnt3, Lottable13_Cnt3, Lottable14_Cnt3, Lottable15_Cnt3 
      FROM DELETED  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_CCDETAIL Failed. (ntrCCDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
   
   /* #INCLUDE <TRODD2.SQL> */  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrCCDetailDelete"  
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