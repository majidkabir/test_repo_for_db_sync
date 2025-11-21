SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrLotxIDDetailAdd
 ON  LotxIDDetail
 FOR INSERT
 AS
 BEGIN
   SET NOCOUNT ON
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
 ,         @n_LotxIDDetailSysId int       
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRLIDA1.SQL> */     
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 SELECT @n_cnt = COUNT(*) FROM INSERTED
 IF @n_cnt > 1
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87000
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": You cannot enter more than one record at a time. (ntrLotxIDDetailAdd)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED WHERE WGT < 0)
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87001
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One or more of the weights provided is negative. (ntrLotxIDDetailAdd)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED WHERE IOFlag = "O" and dbo.fnc_LTrim(dbo.fnc_RTrim(PickDetailkey)) IS NULL )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87002
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One or more of the weights relates to a PICK but no PICKDETAILKEY was provided. (ntrLotxIDDetailAdd)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED, PICKDETAIL
 WHERE INSERTED.PickDetailKey = PICKDETAIL.PickDetailKey
 and INSERTED.IOFlag = "O" and PICKDETAIL.Status = '9' )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87003
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Provided PICKDETAILKEY has been shipped already. (ntrLotxIDDetailAdd)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DECLARE @c_lotxiddetailkey NVARCHAR(10), @c_id NVARCHAR(18), @c_lot NVARCHAR(10), @b_isok int,
 @n_reccount int, @c_pickdetailkey NVARCHAR(10), @c_receiptkey NVARCHAR(10),
 @c_receiptlinenumber NVARCHAR(5), @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20),
 @c_lottable01 NVARCHAR(18), @c_lottable02 NVARCHAR(18), @c_lottable03 NVARCHAR(18),
 @d_lottable04 datetime, @d_lottable05 datetime
 /*Add by CSCHONG(CS01) on 22May2014 Added Lottables 06-15 */
  DECLARE @c_lottable06 NVARCHAR(30), @c_lottable07 NVARCHAR(30), @c_lottable08 NVARCHAR(30),
          @c_lottable09 NVARCHAR(30), @c_lottable10 NVARCHAR(30), @c_lottable11 NVARCHAR(30),
          @c_lottable12 NVARCHAR(30),@d_lottable13 datetime,@d_lottable14 datetime, @d_lottable15 datetime
 /*CS01 End*/
 SELECT @c_lotxiddetailkey = master.dbo.fnc_GetCharASCII(14)
 WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)
 BEGIN
 SET ROWCOUNT 1
 SELECT @c_lotxiddetailkey = LotxIDDETailKey,
 @c_lot = LOT,
 @c_id = ID,
 @c_pickdetailkey = PickDetailKey,
 @c_receiptkey = ReceiptKey,
 @c_receiptlinenumber = ReceiptLineNumber
 FROM INSERTED
 WHERE LotxIDDetailkey > @c_lotxiddetailkey
 AND dbo.fnc_LTrim(dbo.fnc_RTrim(LOT)) IS NULL
 ORDER BY LotxIDDetailKey
 IF @@ROWCOUNT = 0
 BEGIN
 SET ROWCOUNT 0
 BREAK
 END
 SET ROWCOUNT 0
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_pickdetailkey)) IS NOT NULL
 AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NULL
 BEGIN
 SELECT @c_lot = LOT ,
 @c_id = ID
 FROM PICKDETAIL
 WHERE PICKDETAILKEY = @c_pickdetailkey
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NULL
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87004
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to determine the LOT# for the PICK. (ntrLotxIDDetailAdd)"
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_receiptkey)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_receiptlinenumber)) IS NOT NULL
 AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NULL
 BEGIN
 SELECT @c_storerkey = StorerKey ,
 @c_sku = Sku,
 @c_lottable01 = Lottable01,
 @c_lottable02 = Lottable02,
 @c_lottable03 = Lottable03,
 @d_lottable04 = Lottable04,
 @d_lottable05 = Lottable05,
 @c_lottable06 = Lottable06,		--(CS01)
 @c_lottable07 = Lottable07,		--(CS01)
 @c_lottable08 = Lottable08,		--(CS01)
 @c_lottable09 = Lottable09,		--(CS01)
 @c_lottable10 = Lottable10,		--(CS01)
 @c_lottable11 = Lottable11,		--(CS01)
 @c_lottable12 = Lottable12,		--(CS01)
 @d_lottable13 = Lottable13,		--(CS01)
 @d_lottable14 = Lottable14,		--(CS01)
 @d_lottable15 = Lottable15		--(CS01)
 FROM RECEIPTDETAIL
 WHERE ReceiptKey = @c_receiptkey
 and ReceiptLineNumber = @c_receiptlinenumber
 EXECUTE nsp_lotlookup
 @c_storerkey
 , @c_sku
 , @c_lottable01
 , @c_lottable02
 , @c_lottable03
 , @d_lottable04
 , @d_lottable05
 , @c_lottable06		--(CS01)
 , @c_lottable07		--(CS01)
 , @c_lottable08		--(CS01)
 , @c_lottable09		--(CS01)
 , @c_lottable10		--(CS01)
 , @c_lottable11		--(CS01)
 , @c_lottable12		--(CS01)
 , @d_lottable13		--(CS01)
 , @d_lottable14		--(CS01)
 , @d_lottable15		--(CS01)
 , @c_lot       OUTPUT
 , @b_isok      OUTPUT
 , @n_err       OUTPUT
 , @c_errmsg    OUTPUT
 IF @b_isok <> 1 OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NULL
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87005
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to determine the LOT# for the Receipt. (ntrLotxIDDetailAdd)"
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ID)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NULL
 BEGIN
 SELECT @n_reccount = COUNT(DISTINCT Lot ),
 @c_lot = LOT
 FROM LOTxLOCxID
 WHERE ID = @c_id
 GROUP BY LOT
 IF @n_reccount > 1 or @n_reccount <= 0 or @n_reccount IS NULL
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87006
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": A lot number must be provided . (ntrLotxIDDetailAdd)"
 END
 END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NOT NULL
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 UPDATE LOTxIDDetail
 SET LOT = @c_LOT, ID = @C_id, TrafficCop = NULL
 WHERE LOTxIDDetailKey = @c_LotxIDDetailKey
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to LOTxIDDetail table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 END  -- end while
 SET ROWCOUNT 0
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS (SELECT 1 FROM INSERTED WHERE IOFlag NOT IN ("I", "O"))
 BEGIN
 DELETE LOTxIDDETAIL
 FROM INSERTED, LOT, SKU (nolock)
 WHERE LOTxIDDETAIL.LotxIDDetailkey = INSERTED.LotxIDDetailkey
 and INSERTED.LOT = LOT.LOT
 and LOT.STORERKEY = SKU.STORERKEY
 and LOT.SKU = SKU.SKU
 and (INSERTED.IOFlag NOT IN ("I", "O") OR SKU.IOFlag IN ("N") OR SKU.IOFlag is NULL )
 SELECT @n_err = @@ERROR
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87010
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete unknown record failed. (ntrLotxIDDetailAdd)"
 END
 IF NOT EXISTS (SELECT 1 FROM LOTxIDDETAIL, INSERTED
 WHERE LOTxIDDETAIL.LotxIDDetailkey = INSERTED.LotxIDDetailkey)
 BEGIN
 SELECT @n_continue = 4
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS (SELECT 1
 FROM INSERTED, LOTxIDDetail, LOT, SKU (nolock)
 WHERE INSERTED.LOTxIDDETAILKEY = LOTxIDDetail.LOTxIDDetailKey
 AND LOTxIDDetail.LOT = LOT.LOT
 and LOT.STORERKEY = SKU.STORERKEY
 AND LOT.SKU = SKU.SKU
 AND SKU.IOFlag IN ("I","O","B")
 AND SKU.TolerancePCT > 0
 AND SKU.AvgCaseWeight > 0
 AND ABS(INSERTED.Wgt - SKU.AvgCaseWeight) > SKU.AvgCaseWeight * SKU.TolerancePCT
 )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87011
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One or more of the weights provided is outside the tolerances specified for the SKU. (ntrLotxIDDetailAdd)"
 END
 END
 IF (@n_continue = 1 or @n_continue = 2)
 AND EXISTS (SELECT 1 FROM INSERTED WHERE IOFlag = 'I')
 BEGIN
 UPDATE LOT SET
 NetWgt = Lot.NetWgt + Inserted.Wgt,
 GrossWgt = Lot.GrossWgt +  Inserted.Wgt
 FROM INSERTED, LOTxIDDETAIL
 WHERE INSERTED.LotxIdDetailKey = LOTxIDDETAIL.LotxIdDetailKey
 AND LOTxIDDETAIL.Lot = LOT.Lot
 AND inserted.IOFlag = "I"
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to LOT table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 IF (@n_continue = 1 or @n_continue = 2)
 AND EXISTS (SELECT 1 FROM INSERTED WHERE IOFlag = 'I')
 BEGIN
 SELECT @c_lotxiddetailkey = master.dbo.fnc_GetCharASCII(14)
 WHILE @n_continue = 1 or @n_continue = 2
 BEGIN
 SET ROWCOUNT 1
 SELECT @c_lotxiddetailkey   = INSERTED.LotxIdDetailKey,
 @c_receiptkey        = INSERTED.ReceiptKey,
 @c_receiptlinenumber = INSERTED.ReceiptLineNumber,
 @c_lot               = LOTxIDDETAIL.Lot
 FROM INSERTED, LOTxIDDETAIL
 WHERE INSERTED.LotxIdDetailKey > @c_lotxiddetailkey
 AND INSERTED.IOFlag = 'I'
 AND IsNull(dbo.fnc_RTrim(INSERTED.ReceiptLineNumber), '') <> ''
 AND INSERTED.LotxIdDetailKey = LOTxIDDETAIL.LotxIdDetailKey
 ORDER BY INSERTED.LotxIdDetailKey
 SELECT @n_cnt = @@ROWCOUNT
 SET ROWCOUNT 0
 IF @n_cnt = 0 BREAK
 IF (SELECT COUNT(1) FROM LOTxIDDETAIL (nolock)
 WHERE LOTxIDDETAIL.ReceiptKey = @c_receiptkey
 AND LOTxIDDETAIL.ReceiptLineNumber = @c_receiptlinenumber ) > 1
 BEGIN
 CONTINUE
 END
 UPDATE LOT
 SET GrossWgt = Lot.GrossWgt +  RECEIPTDETAIL.QtyReceived * SKU.TareWeight
 FROM RECEIPTDETAIL, SKU (nolock), LOT
 WHERE RECEIPTDETAIL.ReceiptKey = @c_receiptkey
 AND RECEIPTDETAIL.ReceiptLineNumber = @c_receiptlinenumber
 AND RECEIPTDETAIL.StorerKey = SKU.StorerKey
 AND RECEIPTDETAIL.Sku = SKU.Sku
 AND SKU.IOFlag IN ("I","B")
 AND LOT.Lot = @c_lot
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to LOT table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END -- end while
 END
 IF (@n_continue = 1 or @n_continue = 2)
 AND EXISTS (SELECT 1 FROM INSERTED WHERE IOFlag = 'O')
 BEGIN
 UPDATE LOT
 SET NetWgtAllocated   = NetWgtAllocated +
 (CASE
 WHEN PICKDETAIL.Status IN ("0","1","2","3","4") THEN Inserted.Wgt
 ELSE 0 END ),
 GrossWgtAllocated = GrossWgtAllocated +
 (CASE
 WHEN PICKDETAIL.Status IN ("0","1","2","3","4") THEN Inserted.Wgt
 ELSE 0 END ),
 NetWgtPicked   = NetWgtPicked +
 (CASE
 WHEN PICKDETAIL.Status IN ("5","6","7","8") THEN Inserted.Wgt
 ELSE 0 END ),
 GrossWgtPicked = GrossWgtPicked +
 (CASE
 WHEN PICKDETAIL.Status IN ("5","6","7","8") THEN Inserted.Wgt
 ELSE 0 END )
 FROM INSERTED, PICKDETAIL
 WHERE INSERTED.PICKDETAILKEY = PICKDETAIL.PICKDETAILKEY
 AND INSERTED.Lot = LOT.Lot
 AND INSERTED.IOFLAG = "O"
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to LOT table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
      /* #INCLUDE <TRLIDA2.SQL> */

-- Added By Vicky 12 Dec 2002
-- Nike China UCC Receiving - Update UCC table status to 9 when receiving is done
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
  UPDATE UCC
    set status = '9'
  FROM  INSERTED , UCC (nolock)
  WHERE INSERTED.Receiptkey = LEFT(UCC.Sourcekey,10)
    AND INSERTED.Receiptlinenumber = Substring(UCC.Sourcekey,11,5)
    AND INSERTED.Other1 = UCC.Uccno
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
  BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to UCC table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
  END
 END -- End Add Vicky
    
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrLotxIDDetailAdd"
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