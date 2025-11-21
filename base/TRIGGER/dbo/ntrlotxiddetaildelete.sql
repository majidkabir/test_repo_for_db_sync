SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrLotxIDDetailDelete
 ON  LotxIDDetail
 FOR DELETE
 AS
 BEGIN
 IF @@ROWCOUNT = 0
 BEGIN
 RETURN
 END
  
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
 DECLARE @b_cursoropen int
 DECLARE @c_AlertMessage NVARCHAR(255)
 SELECT @b_cursoropen = 0
      /* #INCLUDE <TRLIDD1.SQL> */     
 IF (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 select @n_continue = 4
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DECLARE @c_lot NVARCHAR(10), @f_wgttodelete float
 SELECT @c_lot = master.dbo.fnc_GetCharASCII(14)
 WHILE @n_continue = 1 or @n_continue = 2
 BEGIN
 SET ROWCOUNT 1
 SELECT @c_lot = Lot,
 @f_wgttodelete = SUM(Wgt)
 FROM DELETED
 WHERE IOFlag = 'I'
 AND Lot > @c_lot
 AND Wgt > 0
 GROUP BY Lot
 ORDER BY Lot
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 SET ROWCOUNT 0
 IF @n_cnt = 0 BREAK
 UPDATE LOT
 SET NetWgt   = (CASE WHEN (LOT.NetWgt - @f_wgttodelete) > 0
 THEN (LOT.Netwgt - @f_wgttodelete) ELSE 0 END ),
 GrossWgt = (CASE WHEN (LOT.GrossWgt - @f_wgttodelete) > 0
 THEN (LOT.Grosswgt - @f_wgttodelete) ELSE 0 END )
 WHERE Lot = @c_lot
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Reduce Inbound Weight from LOT table failed. (ntrLotxIDDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END -- while loop
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DECLARE @c_pickdetailkey char (10), @f_wgtallocated float, @f_wgtpicked float
 SELECT @c_lot = master.dbo.fnc_GetCharASCII(14)
 WHILE @n_continue = 1 or @n_continue = 2
 BEGIN
 SET ROWCOUNT 1
 SELECT @c_lot = DELETED.Lot,
 @f_wgtallocated = SUM(Case
 when PICKDETAIL.Status in ("0","1","2","3","4")
 then Wgt else 0 end),
 @f_wgtpicked = SUM(Case
 when PICKDETAIL.Status in ("5","6","7","8")
 then  Wgt else 0 end)
 FROM DELETED, PICKDETAIL
 WHERE IOFlag = "O"
 AND Wgt > 0
 AND DELETED.Lot > @c_lot
 AND DELETED.Pickdetailkey = PICKDETAIL.Pickdetailkey
 GROUP BY DELETED.Lot
 ORDER BY DELETED.Lot
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 SET ROWCOUNT 0
 IF @n_cnt = 0 BREAK
 UPDATE LOT
 SET NetWgtAllocated   = (CASE WHEN (NetWgtAllocated - @f_wgtallocated) > 0
 THEN NetWgtAllocated - @f_wgtallocated ELSE 0 END) ,
 GrossWgtAllocated = (CASE WHEN (GrossWgtAllocated - @f_wgtallocated) > 0
 THEN GrossWgtAllocated - @f_wgtallocated ELSE 0 END) ,
 NetWgtPicked      = (CASE WHEN (NetWgtPicked - @f_wgtpicked) > 0
 THEN NetWgtPicked - @f_wgtpicked ELSE 0 END ),
 GrossWgtPicked    = (CASE WHEN (GrossWgtPicked - @f_wgtpicked) > 0
 THEN GrossWgtPicked - @f_wgtpicked ELSE 0 END )
 WHERE Lot = @c_lot
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 87102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Reduce Outbound Weight from LOT table failed. (ntrLotxIDDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END -- while loop
 END
      /* #INCLUDE <TRLIDD2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrLotxIDDetailDelete"
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