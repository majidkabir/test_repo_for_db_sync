SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFRP02                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/


CREATE PROC    [dbo].[nspRFRP02]
 @c_sendDelimiter    NVARCHAR(1)
 ,              @c_ptcid            NVARCHAR(5)
 ,              @c_userid           NVARCHAR(10)
 ,              @c_taskId           NVARCHAR(10)
 ,              @c_databasename     NVARCHAR(10)
 ,              @c_appflag          NVARCHAR(2)
 ,              @c_recordType       NVARCHAR(2)
 ,              @c_server           NVARCHAR(30)
 ,              @n_taskindicator    int
 ,              @c_outstring        NVARCHAR(255) OUTPUT
 ,              @b_Success          int       OUTPUT
 ,              @n_err              int       OUTPUT
 ,              @c_errmsg           NVARCHAR(250) OUTPUT
 AS
 BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE        @n_continue int        ,  
 @n_starttcnt int        , -- Holds the current transaction count
 @c_preprocess NVARCHAR(250) , -- preprocess
 @c_pstprocess NVARCHAR(250) , -- post process
 @n_err2 int               -- For Additional Error Detection
 DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
 SELECT @c_retrec = "01"
      /* #INCLUDE <SPRFRP02_1.SQL> */     
 DECLARE @b_debug int
 SELECT @b_debug = 0
 IF @b_debug = 1
 BEGIN
 SELECT @n_taskindicator "@n_taskindicator"
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DELETE FROM REPLENISHMENT_LOCK
 WHERE PTCID = @c_ptcid or
 datediff(second,adddate,getdate()) > 900  -- 15 minutes
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DECLARE   @Cursor_ReplenishmentGroup    NVARCHAR(10) ,
 @Cursor_ReplenishmentKey      NVARCHAR(10) ,
 @Cursor_Storerkey             NVARCHAR(15) ,
 @Cursor_Sku                   NVARCHAR(20) ,
 @Cursor_FromLoc               NVARCHAR(10) ,
 @Cursor_ToLoc                 NVARCHAR(10) ,
 @Cursor_Lot                   NVARCHAR(10) ,
 @Cursor_Id                    NVARCHAR(18) ,
 @Cursor_Qty                   int ,
 @Cursor_QtyMoved              int ,
 @Cursor_UOM                   NVARCHAR(10) ,
 @Cursor_PackKey               NVARCHAR(10) ,
 @Cursor_QtyInPickLoc          int ,
 @n_lotlocidqty                int ,
 @n_skulocqty                  int ,
 @n_skulocavailablecapacity    int ,
 @n_junkcount                  int
 END
 GETNEXTTASK:
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
 SELECT    @Cursor_ReplenishmentGroup    = SPACE(10) ,
 @Cursor_ReplenishmentKey      = SPACE(10) ,
 @Cursor_Storerkey             = SPACE(15) ,
 @Cursor_Sku                   = SPACE(20) ,
 @Cursor_FromLoc               = SPACE(10) ,
 @Cursor_ToLoc                 = SPACE(10) ,
 @Cursor_Lot                   = SPACE(10) ,
 @Cursor_Id                    = SPACE(18) ,
 @Cursor_Qty                   = 0 ,
 @Cursor_QtyMoved              = 0 ,
 @Cursor_UOM                   = SPACE(10) ,
 @Cursor_PackKey               = SPACE(10) ,
 @Cursor_QtyInPickLoc          = 0 ,
 @n_lotlocidqty                = 0 ,
 @n_skulocqty                  = 0 ,
 @n_skulocavailablecapacity    = 0 ,
 @n_junkcount                  = 0
 IF @n_taskindicator = 0 
 BEGIN
 FETCH RELATIVE 0 FROM CURSOR_REPLENISHMENT_TASKS
 INTO @Cursor_ReplenishmentGroup,
 @Cursor_ReplenishmentKey,
 @Cursor_Storerkey,
 @Cursor_Sku,
 @Cursor_FromLoc,
 @Cursor_ToLoc,
 @Cursor_Lot,
 @Cursor_Id,
 @Cursor_Qty,
 @Cursor_QtyMoved,
 @Cursor_UOM,
 @Cursor_PackKey,
 @Cursor_QtyInPickLoc
 SELECT @n_err = @@ERROR
 IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFRP02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE
 BEGIN
 SELECT @n_err = @@FETCH_STATUS
 IF @n_err = -1
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_retrec="02"
 SELECT @n_err = 65402
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFRP02)"
 END
 ELSE IF @n_err = -2
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65403
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFRP02)"
 END
 ELSE IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65404
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFRP02)"
 END
 END
 END
 ELSE IF @n_taskindicator = 1
 BEGIN
 FETCH NEXT FROM CURSOR_REPLENISHMENT_TASKS
 INTO @Cursor_ReplenishmentGroup,
 @Cursor_ReplenishmentKey,
 @Cursor_Storerkey,
 @Cursor_Sku,
 @Cursor_FromLoc,
 @Cursor_ToLoc,
 @Cursor_Lot,
 @Cursor_Id,
 @Cursor_Qty,
 @Cursor_QtyMoved,
 @Cursor_UOM,
 @Cursor_PackKey  ,
 @Cursor_QtyInPickLoc
 SELECT @n_err = @@ERROR
 IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFRP02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE
 BEGIN
 SELECT @n_err = @@FETCH_STATUS
 IF @n_err = -1
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_retrec="02"
 SELECT @n_err = 65402
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFRP02)"
 END
 ELSE IF @n_err = -2
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65403
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFRP02)"
 END
 ELSE IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65404
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFRP02)"
 END
 END
 END
 ELSE IF @n_taskindicator = -1
 BEGIN
 FETCH PRIOR FROM CURSOR_REPLENISHMENT_TASKS
 INTO @Cursor_ReplenishmentGroup,
 @Cursor_ReplenishmentKey,
 @Cursor_Storerkey,
 @Cursor_Sku,
 @Cursor_FromLoc,
 @Cursor_ToLoc,
 @Cursor_Lot,
 @Cursor_Id,
 @Cursor_Qty,
 @Cursor_QtyMoved,
 @Cursor_UOM,
 @Cursor_PackKey,
 @Cursor_QtyInPickLoc
 SELECT @n_err = @@ERROR
 IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFRP02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE
 BEGIN
 SELECT @n_err = @@FETCH_STATUS
 IF @n_err = -1
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_retrec="02"
 SELECT @n_err = 65404
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFRP02)"
 END
 ELSE IF @n_err = -2
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65405
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFRP02)"
 END
 ELSE IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65406
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFRP02)"
 END
 END
 END
 ELSE
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65400
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad TaskIndicator. (nspRFRP02)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 SELECT @n_junkcount = COUNT(*) FROM REPLENISHMENT_LOCK
 WHERE LOT = @cursor_lot AND
 FROMLOC = @cursor_fromloc AND
 TOLOC = @cursor_toloc AND
 ID = @cursor_id
 IF @n_junkcount > 0
 BEGIN
 GOTO GETNEXTTASK
 END
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 SELECT @n_skulocavailablecapacity = 0
 SELECT @n_skulocavailablecapacity = FLOOR( (SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked))/SKUXLOC.ReplenishmentCaseCnt)
 FROM SKUxLOC
 WHERE SKU = @cursor_sku AND
 LOC = @cursor_toloc
 IF @n_skulocavailablecapacity <= 0
 BEGIN
 SELECT @cursor_qty = 0, @Cursor_QtyMoved = 0
 GOTO GETNEXTTASK
 END
 END
 IF ( @n_continue = 1 or @n_continue = 2) and ((@cursor_qty - @cursor_qtyMoved) > 0)
 BEGIN
 SELECT @n_lotlocidqty = ( LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked )
 FROM LOTxLOCxID
 WHERE LOT = @cursor_lot AND
 LOC = @cursor_fromloc AND
 ID = @cursor_id
 IF @n_lotlocidqty < (@cursor_qty - @cursor_qtyMoved)
 BEGIN
 SELECT @cursor_qty = 0, @cursor_qtymoved = 0
 GOTO GETNEXTTASK
 END
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 INSERT REPLENISHMENT_LOCK (ptcid,storerkey,sku,fromloc,toloc,lot,id)
 values (@c_ptcid,@cursor_storerkey, @cursor_sku,@cursor_fromloc,@cursor_toloc,@cursor_lot,@cursor_id)
 SELECT @n_err = @@ERROR
 IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65410   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into REPLENISHMENT_LOCK failed. (nspRFRP02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END
 IF @n_continue=3
 BEGIN
 IF @c_retrec="01"
 BEGIN
 SELECT @c_retrec="09"
 END
 END
 ELSE
 BEGIN
 SELECT @c_retrec="01"
 SELECT @Cursor_PackKey = convert(char(10), Lottable04,103) From Lotattribute (NOLOCK)
  WHERE Storerkey = @Cursor_StorerKey 
    AND Sku = @Cursor_Sku 
    AND LOT = @Cursor_Lot
 IF @b_debug = 1 BEGIN SELECT @Cursor_ReplenishmentKey, @Cursor_ReplenishmentGroup, @Cursor_Storerkey, @Cursor_Sku, @Cursor_FromLoc, @Cursor_ToLoc, @Cursor_Lot, @Cursor_Id, @Cursor_Qty, @Cursor_QtyMoved, @Cursor_UOM, @Cursor_PackKey END
 END
 SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
 + dbo.fnc_RTrim(@c_userid)                 + @c_senddelimiter
 + dbo.fnc_RTrim(@c_taskid)                 + @c_senddelimiter
 + dbo.fnc_RTrim(@c_databasename)           + @c_senddelimiter
 + dbo.fnc_RTrim(@c_appflag)                       + @c_senddelimiter
 + dbo.fnc_RTrim(@c_retrec)                        + @c_senddelimiter
 + dbo.fnc_RTrim(@c_server)                        + @c_senddelimiter
 + dbo.fnc_RTrim(@c_errmsg)                 + @c_senddelimiter
 + dbo.fnc_RTrim(@cursor_ReplenishmentKey)         + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_StorerKey)                + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_Lot)                      + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_Sku)                      + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_Id)                       + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_FromLoc)                  + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_ToLoc)                    + @c_senddelimiter
 + dbo.fnc_RTrim(CONVERT(char(10), @Cursor_Qty - @Cursor_QtyMoved))   + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_UOM)                      + @c_senddelimiter
 + dbo.fnc_RTrim(@Cursor_PackKey)
 SELECT dbo.fnc_RTrim(@c_outstring)
      /* #INCLUDE <SPRFRP02_2.SQL> */
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
 execute nsp_logerror @n_err, @c_errmsg, "nspRFRP02"
 RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 RETURN
 END
 ELSE
 BEGIN
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_starttcnt
 BEGIN
 COMMIT TRAN
 END
 RETURN
 END
 END

GO