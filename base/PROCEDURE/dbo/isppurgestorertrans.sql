SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 19-Jan-2012  KHLim01   1.1  Update ArchiveCop before purging         */
/* 16-Feb-2012  KHLim02   1.2  prevent updating wrong InventoryHold     */

CREATE PROCEDURE ispPurgeStorerTrans
    @c_Storer NVARCHAR(15)
 AS
 BEGIN 
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE @n_continue int,
 @n_starttcnt   int      , -- Holds the current transaction count
 @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
 @c_preprocess NVARCHAR(250) , -- preprocess
 @c_pstprocess NVARCHAR(250) , -- post process
 @n_err2 int             , -- For Additional Error Detection
 @b_debug int            , -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
 @b_success int          ,
 @n_err   int            ,     
 @c_errmsg NVARCHAR(250),
 @errorcount int
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
 SELECT @b_debug = 0
 Print 'Purge Storer '+dbo.fnc_RTrim(@c_storer)+' starts at ' + convert(char(20), getdate(), 120)
 IF @n_Continue = 1
 BEGIN
    Print 'Updating Itrn ArchiveCop = 9'  -- KHLim01
    UPDATE ITRN
      SET ArchiveCop = '9'  
    WHERE  STORERKEY = @c_Storer

    Print 'Purging Itrn..'
    DELETE FROM ITRN 
 	 WHERE STORERKEY = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END

 IF @n_Continue = 1
 BEGIN
    Print 'Updating Inventory Hold ArchiveCop = 9'  
    UPDATE InventoryHold   
      SET ArchiveCop = '9'  
    FROM   InventoryHold    
    JOIN   LOT ON LOT.LOT = InventoryHold.LOT  
    WHERE  LOT.STORERKEY = @c_Storer  

    Print 'Purging Inventory Hold (Lot)'
    DELETE InventoryHold
    FROM   LOT
    WHERE  LOT.STORERKEY = @c_Storer
    AND    LOT.LOT = InventoryHold.LOT
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END

 IF @n_Continue = 1
 BEGIN
    Print 'Updating Inventory Hold ArchiveCop = 9'  
    UPDATE InventoryHold   
      SET ArchiveCop = '9'  
    FROM   InventoryHold    
    JOIN   LOTxLOCxID ON LOTxLOCxID.ID = InventoryHold.ID  
    WHERE  LOTxLOCxID.STORERKEY = @c_Storer  
    AND    InventoryHold.ID <> ''  -- KHLim02

    Print 'Purging Inventory Hold (ID)'
    DELETE InventoryHold
    FROM   LOTxLOCxID
    WHERE  LOTxLOCxID.STORERKEY = @c_Storer
    AND    LOTxLOCxID.ID = InventoryHold.ID
    AND    InventoryHold.ID <> ''  -- KHLim02
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating SKUxLOC ArchiveCop = 9'  -- KHLim01
    UPDATE SKUxLOC   
      SET ArchiveCop = '9'  
    WHERE STORERKEY = @c_Storer  

    Print 'Purging SKUxLOC'

    ALTER TABLE SKUxLOC disable trigger ntrSKUxLOCDelete 

    DELETE FROM SKUxLOC
 	 WHERE STORERKEY = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END

    ALTER TABLE SKUxLOC enable trigger ntrSKUxLOCDelete 

 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating taskdetail...'
    UPDATE TASKDETAIL
     SET ArchiveCop = '9'
    WHERE STORERKEY = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Taskdetail...'
       DELETE TASKDETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating PreAllocatePickdetail...'
    UPDATE PreAllocatePickDETAIL
     SET ArchiveCop = '9'
  WHERE STORERKEY = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging PreAllocatePickdetail...'
       DELETE PreAllocatePickDETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating Pickdetail...'
    UPDATE PICKDETAIL
     SET ArchiveCop = '9'
    WHERE STORERKEY = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Pickdetail...'
       DELETE PICKDETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating POD...'
    DELETE POD
    FROM   ORDERS
    WHERE  Orders.OrderKEY = POD.Orderkey
    AND    ORDERS.StorerKey = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 IF @n_Continue = 1
 BEGIN
    Print 'Updating MBOL Detail...'
    UPDATE MBOLDETAIL
    	SET ArchiveCop = '9'
    FROM   ORDERS
    WHERE  MBOLDETAIL.OrderKEY = ORDERS.OrderKey
    AND    ORDERS.StorerKey = @c_Storer
    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating MBOL Header...'
       UPDATE MBOL
       SET ArchiveCop = '9'
       FROM MBOLDETAIL
       WHERE MBOL.MBOLKey = MBOLDETAIL.MBOLKey
       AND   MBOLDETAIL.ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging MBOL Header...'
       DELETE MBOL
       WHERE ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging MBOL Detail...'
       DELETE MBOLDETAIL
       WHERE ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Loadplan Detail...'
       UPDATE LOADPLANDETAIL
 	        SET ArchiveCop = '9'
       FROM   ORDERS
       WHERE  LOADPLANDETAIL.OrderKEY = ORDERS.OrderKey
       AND    ORDERS.StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Loadplan Header...'
       UPDATE LoadPlan
 	SET ArchiveCop = '9'
       FROM LOADPLANDETAIL
       WHERE Loadplan.Loadkey = LoadPlanDetail.LoadKey
       AND   Loadplandetail.archivecop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Loadplan Driver...'
       DELETE IDS_LP_DRIVER
       FROM  LOADPLAN
       WHERE LOADPLAN.LoadKey = IDS_LP_DRIVER.LoadKey
       AND   ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Loadplan Vehicle...'
       DELETE IDS_LP_VEHICLE
       FROM  LOADPLAN
       WHERE LOADPLAN.LoadKey = IDS_LP_VEHICLE.LoadKey
       AND   ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Loadplan Detail...'
       DELETE LoadplanDetail
       WHERE ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Loadplan Header...'
       DELETE Loadplan
       WHERE ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Order Detail...'
       UPDATE ORDERDETAIL
 	SET ArchiveCop = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Order Detail...'
       DELETE ORDERDETAIL
       WHERE STORERKEY = @c_Storer
       AND   ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Order Header...'
       UPDATE ORDERS
 	SET ArchiveCop = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Order Header...'
       DELETE ORDERS
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating LOTxLOCxID...'  
       UPDATE LOTxLOCxID  
       SET ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END  
    IF @n_Continue = 1
    BEGIN
       Print 'Purging LOTxLOCxID...'

       ALTER TABLE LOTxLOCxID disable trigger ntrLOTxLOCxIDDelete

       DELETE FROM LOTxLOCxID
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END

       ALTER TABLE LOTxLOCxID enable trigger ntrLOTxLOCxIDDelete
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging PHYSICAL...'
       DELETE PHYSICAL
       WHERE STORERKEY = @c_storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating ID...'  
       UPDATE ID  
       SET ArchiveCop = '9'  
       WHERE ID.ID NOT IN (SELECT DISTINCT ID FROM LOTxLOCxID )  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END  
    IF @n_Continue = 1
    BEGIN
       Print 'Purging ID...'
       DELETE ID
       WHERE ID.ID NOT IN (SELECT DISTINCT ID FROM LOTxLOCxID )
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating LOT...'  
       UPDATE LOT  
       SET ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END  
    IF @n_Continue = 1
    BEGIN
       Print 'Purging LOT...'

       ALTER TABLE LOT disable trigger ntrLOTdelete 
       DELETE FROM LOT
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END

       ALTER TABLE LOT enable trigger ntrLOTdelete 
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Adjustment Detail...'
       UPDATE ADJUSTMENTDETAIL
        SET ARCHIVECOP = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Adjustment Header...'
       UPDATE ADJUSTMENT
        SET ARCHIVECOP = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Adjustment Detail...'
       DELETE FROM ADJUSTMENTDETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Adjustment Header...'
       DELETE FROM ADJUSTMENT
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Po Detail...'
       UPDATE PODETAIL
        SET ARCHIVECOP = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating PO ...'
       UPDATE PO
        SET ARCHIVECOP = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging PO Detail...'
       DELETE FROM PODETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging PO Header...'
       DELETE FROM PO
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Transfer Detail...'
       UPDATE TRANSFERDETAIL
        SET ARCHIVECOP = '9'
       WHERE FROMSTORERKEY = @c_Storer or TOSTORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Transfer Header...'
       UPDATE TRANSFER
        SET ARCHIVECOP = '9'
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Transfer Detail...'
       DELETE FROM TRANSFERDETAIL
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Transfer Header...'
       DELETE FROM TRANSFER
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 -- begin
    IF @n_Continue = 1
    BEGIN
       Print 'Updating KIT Detail...'
       UPDATE KitDetail
        SET ARCHIVECOP = '9'
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Kit Header...'
       UPDATE KIT
        SET ARCHIVECOP = '9'
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging KIT Detail...'
       DELETE FROM KitDetail
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging KIT Header...'
       DELETE FROM KIT
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating INVENTORYQC Detail...'
       UPDATE InventoryQCDetail
        SET ARCHIVECOP = '9'
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging INVENTORYQC Detail...'
       DELETE FROM INVENTORYQCDetail
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging INVENTORYQC Header...'
       DELETE FROM INVENTORYQC
       WHERE StorerKey = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
 -- end
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Receipt Detail...'
       UPDATE RECEIPTDETAIL
 	    SET ArchiveCop = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Deleting Receipt Detail...'
       DELETE RECEIPTDETAIL
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating Receipt Header...'
       UPDATE RECEIPT
 	SET ArchiveCop = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
   BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Receipt Header...'
       DELETE RECEIPT
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating LotAttribute...'  
       UPDATE LotAttribute  
       Set ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END 
    IF @n_Continue = 1
    BEGIN
       Print 'Purging LotAttribute...'
       DELETE FROM LOTATTRIBUTE
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
   
    IF @n_Continue = 1
    BEGIN
       Print 'Updating RFPUTAWAY...'
       UPDATE RFPUTAWAY
 	    SET ArchiveCop = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging RFPutaway...'
       DELETE RFPUTAWAY
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    -- Added By Vicky on 11-Sept-2007
    IF @n_Continue = 1
    BEGIN
       Print 'Updating WorkOrder...'
       UPDATE WorkOrder
        SET ARCHIVECOP = '9'
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Updating WorkOrder Detail...'
       UPDATE WorkOrderDetail
        SET ARCHIVECOP = '9'
       FROM WorkOrderDetail (NOLOCK)
       JOIN WorkOrder (NOLOCK) ON (WorkOrder.WorkOrderKey = WorkOrderDetail.WorkOrderKey)
       WHERE WorkOrder.STORERKEY = @c_Storer
       AND WorkOrder.ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging WorkOrder Detail...'
       DELETE FROM WorkOrderDetail
       WHERE ArchiveCop = '9'
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging WorkOrder Header...'
       DELETE FROM WorkOrder
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1  -- KHLim01
    BEGIN
       Print 'Updating Transmitlog3...'
       UPDATE Transmitlog3
 	    SET ArchiveCop = '9'
       WHERE Key1 = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Transmitlog3...'
       DELETE FROM Transmitlog3
       WHERE Key1 = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1  -- KHLim01
    BEGIN
       Print 'Updating Prepack PACK...'
       UPDATE PACK
 	    SET ArchiveCop = '9'
       WHERE PACKKEY IN (SELECT PACKKEY FROM UPC (NOLOCK) WHERE STORERKEY = @c_Storer)
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Prepack PACK...'
       DELETE FROM PACK WHERE PACKKEY IN (SELECT PACKKEY FROM UPC (NOLOCK) WHERE STORERKEY = @c_Storer)
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1  -- KHLim01
    BEGIN
       Print 'Updating PARENT SKU...'
       UPDATE SKU
 	    SET ArchiveCop = '9'
       WHERE SKU IN (SELECT SKU FROM UPC (NOLOCK) WHERE STORERKEY = @c_Storer)
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Prepack PARENT SKU...'
       DELETE FROM SKU WHERE SKU IN (SELECT SKU FROM UPC (NOLOCK) WHERE STORERKEY = @c_Storer)
       AND STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1
    BEGIN
       Print 'Purging UPC...'
       DELETE FROM UPC 
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating Bill of Material...'  
       UPDATE BillOfMaterial  
       Set ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END 
    IF @n_Continue = 1
    BEGIN
       Print 'Purging Bill of Material...'
       DELETE FROM BillOfMaterial
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END

    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating CCDETAIL...'  
       UPDATE CCDETAIL  
       Set ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END 
    IF @n_Continue = 1
    BEGIN
       Print 'Purging CCDETAIL...'
       DELETE FROM CCDETAIL 
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END


    IF @n_Continue = 1  -- KHLim01
    BEGIN  
       Print 'Updating StockTake Parameter...'  
       UPDATE StocktakeSheetParameters  
       Set ArchiveCop = '9'  
       WHERE STORERKEY = @c_Storer  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
       END  
    END 
    IF @n_Continue = 1
    BEGIN
       Print 'Purging StockTake Parameter...'
       DELETE FROM StocktakeSheetParameters 
       WHERE STORERKEY = @c_Storer
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    
    
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
    --RETURN
 END
 Print 'Purge Storer '+dbo.fnc_RTrim(@c_storer)+' ends at ' + convert(char(20), getdate(), 120)
 END -- procedure




GO