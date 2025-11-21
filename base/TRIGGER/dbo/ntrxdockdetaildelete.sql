SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntrXDockDetailDelete
 ON  XDOCKDETAIL
 FOR DELETE
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF
  	
 DECLARE @b_debug int
 SELECT @b_debug = 0
 IF @b_debug = 2
 BEGIN
 DECLARE @profiler NVARCHAR(80)
 SELECT @profiler = "PROFILER,779,00,0,ntrXDockDetailDelete Trigger                       ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
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
 IF (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 select @n_continue = 4
 END
      /* #INCLUDE <TRXDKDD1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
 IF EXISTS(SELECT *
 FROM DELETED
 WHERE DELETED.ReceivedQty > 0
 )
 BEGIN
 SELECT @n_continue=3
 SELECT @n_err=77901
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Delete Rows That Have Been Received or Shipped. Deleted on table 'XdockDetail' rejected. (ntrXDockDetailDelete)"
 END
 END
 IF @n_continue = 1 or @n_continue=2
 BEGIN
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,779,03,0,XDOCK Update                                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 DECLARE @n_insertedcount int
 SELECT @n_insertedcount = (select count(*) FROM inserted)
 IF @n_insertedcount = 1
 BEGIN
 UPDATE XDOCK
 SET  XDOCK.ExpectedTotalQty = XDOCK.ExpectedTotalQty - DELETED.ExpectedQty ,
 XDOCK.ExpectedTotalGrossWgt = XDOCK.ExpectedTotalGrossWgt - DELETED.ExpectedGrossWeight,
 XDOCK.ExpectedTotalNetWgt = XDOCK.ExpectedTotalNetWgt - DELETED.ExpectedNetWeight,
 XDOCK.ExpectedTotalCube = XDOCK.ExpectedTotalCube - DELETED.ExpectedCube
 FROM XDOCK,
 DELETED
 WHERE XDOCK.XDOCKKey = DELETED.XDOCKKey
 END
 ELSE
 BEGIN
 UPDATE XDOCK SET XDOCK.ExpectedTotalQty
 = (Select Sum(ExpectedQty) From XDOCKDETAIL
 Where XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey) ,
 XDOCK.ExpectedTotalGrossWgt
 = (Select Sum(ExpectedGrossWeight) From XDOCKDETAIL
 Where XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey) ,
 XDOCK.ExpectedTotalNetWgt
 = (Select Sum(ExpectedNetWeight) From XDOCKDETAIL
 Where XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey) ,
 XDOCK.ExpectedTotalCube
 = (Select Sum(ExpectedCube) From XDOCKDETAIL
 Where XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey)
 FROM XDOCK,DELETED
 WHERE XDOCK.XDOCKkey IN (Select Distinct XDOCKkey From Deleted)
 AND XDOCK.XDOCKkey = Deleted.XDOCKkey
 END
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=77904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update failed on table XDOCKDETAIL. (ntrXDockDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE IF @n_cnt = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=77905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Zero rows affected updating table XDOCK. (ntrXDockDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,779,03,9,XDOCK Update                                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
END
      /* #INCLUDE <TRXDKDD2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrXDockDetailDelete"
 RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,779,00,9,ntrXDockDetailDelete Tigger                       ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 ELSE
 BEGIN
 WHILE @@TRANCOUNT > @n_starttcnt
 BEGIN
 COMMIT TRAN
 END
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,779,00,9,ntrXDockDetailDelete Trigger                       ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 END


GO