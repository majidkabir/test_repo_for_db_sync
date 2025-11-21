SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrLotxIDDetailUpdate
 ON  LotxIDDetail
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
 ,         @n_LotxIDDetailSysId int       
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 DECLARE @b_cursoropen int
 DECLARE @c_AlertMessage NVARCHAR(255)
 SELECT @b_cursoropen = 0
      /* #INCLUDE <TRLIDU1.SQL> */     
 IF UPDATE(TrafficCop)
 BEGIN
 SELECT @n_continue = 4 
 END
 IF UPDATE(ArchiveCop)
 BEGIN
 SELECT @n_continue = 4 
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS (SELECT 1 FROM DELETED, INSERTED
 WHERE DELETED.LotxIdDetailKey = INSERTED.LotxIdDetailKey
 AND (DELETED.IOFlag <> INSERTED.IOFlag
 OR DELETED.Lot <> INSERTED.Lot) )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87200
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to IOFlag and to Lot is not allowed. Use Delete and Insert. (ntrLotxIDDetailUpdate)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF UPDATE(LotxIdDetailKey)
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87200
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to row key is not allowed. Use Delete and Insert. (ntrLotxIDDetailUpdate)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED WHERE IOFlag = "O" and dbo.fnc_LTrim(dbo.fnc_RTrim(PickDetailkey)) IS NULL )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87201
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One or more of the weights relates to a PICK but no PICKDETAILKEY was provided. (ntrLotxIDDetailUpdate)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED, PICKDETAIL
 WHERE INSERTED.PickDetailKey = PICKDETAIL.PickDetailKey
 and INSERTED.IOFlag = "O"
 and PICKDETAIL.Status = '9' )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87202
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update weight to shipped PICKDETAIL not allowed. (ntrLotxIDDetailUpdate)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS(SELECT * FROM INSERTED WHERE dbo.fnc_LTrim(dbo.fnc_RTrim(LOT)) IS NULL )
 BEGIN
 SELECT @n_continue = 3 , @n_err = 87203
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": LOT is not provided. (ntrLotxIDDetailUpdate)"
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
 SELECT @n_continue = 3 , @n_err = 87204
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": One or more of the weights provided is outside the tolerances specified for the SKU. (ntrLotxIDDetailUpdate)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.IOFlag = "I")
 BEGIN
 UPDATE LOT
 SET NetWgt = (CASE WHEN (Lot.NetWgt + INSERTED.Wgt - DELETED.Wgt) > 0
 THEN (LOT.Netwgt + INSERTED.Wgt - DELETED.Wgt) ELSE 0 END ),
 GrossWgt = (CASE WHEN (Lot.GrossWgt + INSERTED.Wgt - DELETED.Wgt) > 0
 THEN (LOT.Grosswgt + INSERTED.Wgt - DELETED.Wgt) ELSE 0 END ),
      EditDate = GETDATE(),        --tlting
      EditWho = SUSER_SNAME()
 FROM DELETED, INSERTED
 WHERE INSERTED.LotxIdDetailKey = DELETED.LotxIdDetailKey
 AND INSERTED.LOT = LOT.Lot
 AND INSERTED.IOFlag = "I"
 AND INSERTED.Wgt <> DELETED.Wgt
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87205   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Inbound Weight in LOT table failed. (ntrLotxIDDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.IOFlag = "O")
 BEGIN
 UPDATE LOT
 SET NetWgtAllocated   = (CASE WHEN PICKDETAIL.Status IN ("0","1","2","3","4")
 and (NetWgtAllocated + Inserted.Wgt - DELETED.Wgt) > 0
 THEN NetWgtAllocated + Inserted.Wgt - DELETED.Wgt
 WHEN PICKDETAIL.Status IN ("0","1","2","3","4")
 and (NetWgtAllocated + Inserted.Wgt - DELETED.Wgt) <= 0
 THEN 0
 ELSE NetWgtAllocated END ),
 GrossWgtAllocated = (CASE WHEN PICKDETAIL.Status IN ("0","1","2","3","4")
 and (GrossWgtAllocated + Inserted.Wgt - DELETED.Wgt) > 0
 THEN GrossWgtAllocated + Inserted.Wgt - DELETED.Wgt
 WHEN PICKDETAIL.Status IN ("0","1","2","3","4")
 and (GrossWgtAllocated + Inserted.Wgt - DELETED.Wgt) <= 0
 THEN 0
 ELSE GrossWgtAllocated END ),
 NetWgtPicked   = (CASE WHEN PICKDETAIL.Status IN ("5","6","7","8")
 and (NetWgtPicked + Inserted.Wgt - DELETED.Wgt) > 0
 THEN NetWgtPicked + Inserted.Wgt - DELETED.Wgt
 WHEN PICKDETAIL.Status IN ("5","6","7","8")
 and (NetWgtPicked + Inserted.Wgt - DELETED.Wgt) <= 0
 THEN 0
 ELSE NetWgtPicked END ),
 GrossWgtPicked = (CASE WHEN PICKDETAIL.Status IN ("5","6","7","8")
 and (GrossWgtPicked  + Inserted.Wgt - DELETED.Wgt) > 0
 THEN GrossWgtPicked  + Inserted.Wgt - DELETED.Wgt
 WHEN PICKDETAIL.Status IN ("5","6","7","8")
 and (GrossWgtPicked  + Inserted.Wgt - DELETED.Wgt) <= 0
 THEN 0
 ELSE GrossWgtPicked END ),
      EditDate = GETDATE(),   --tlting
      EditWho = SUSER_SNAME()
 FROM INSERTED, DELETED, PICKDETAIL
 WHERE INSERTED.LotxIdDetailKey = DELETED.LotxIdDetailKey
 AND INSERTED.Lot = LOT.Lot
 AND INSERTED.PICKDETAILKEY = PICKDETAIL.PICKDETAILKEY
 AND INSERTED.IOFLAG = "O"
 AND INSERTED.Wgt <> DELETED.Wgt
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87206   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Outbound weight in LOT table failed. (ntrLotxIDDetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 END
      /* #INCLUDE <TRLIDU2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrLotxIDDetailUpdate"
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