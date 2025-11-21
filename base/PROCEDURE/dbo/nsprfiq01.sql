SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspRFIQ01                                          */
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

CREATE PROC    [dbo].[nspRFIQ01]
 @c_sendDelimiter    NVARCHAR(1)
 ,              @c_ptcid            NVARCHAR(5)
 ,              @c_userid           NVARCHAR(10)
 ,              @c_taskId           NVARCHAR(10)
 ,              @c_databasename     NVARCHAR(5)
 ,              @c_appflag          NVARCHAR(2)
 ,              @c_recordType       NVARCHAR(2)
 ,              @c_server           NVARCHAR(30)
 ,              @c_storerkey        NVARCHAR(15)
 ,              @c_lot              NVARCHAR(10)
 ,              @c_sku              NVARCHAR(20)
 ,              @c_id               NVARCHAR(18)
 ,              @c_loc              NVARCHAR(10)
 ,              @c_caseid           NVARCHAR(10)
 ,              @n_qty              int
 ,              @c_uom              NVARCHAR(10)
 ,              @c_packkey          NVARCHAR(10)
 ,              @c_status           NVARCHAR(10)
 ,              @c_outstring        NVARCHAR(255) OUTPUT
 ,              @b_Success          int       OUTPUT
 ,              @n_err              int       OUTPUT
 ,              @c_errmsg           NVARCHAR(250) OUTPUT
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE @b_debug int
 SELECT @b_debug = 0
 DECLARE        @n_continue int        ,  
 @n_starttcnt int        , -- Holds the current transaction count
 @c_preprocess NVARCHAR(250) , -- preprocess
 @c_pstprocess NVARCHAR(250) , -- post process
 @n_err2 int              -- For Additional Error Detection
 DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
 DECLARE @c_dbnamestring NVARCHAR(255)
 DECLARE @n_cqty int, @n_returnrecs int
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
 SELECT @c_retrec = "01"
 SELECT @n_returnrecs=1
 DECLARE @c_itrnkey NVARCHAR(10)
      /* #INCLUDE <SPRFIQ01_1.SQL> */     
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NULL and NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NULL
 BEGIN
 SELECT @b_success = 0
 EXECUTE nspg_GETSKU
 @c_StorerKey   = @c_StorerKey,
 @c_sku         = @c_sku     OUTPUT,
 @b_success     = @b_success OUTPUT,
 @n_err         = @n_err     OUTPUT,
 @c_errmsg      = @c_errmsg  OUTPUT
 IF NOT @b_success = 1
 BEGIN
 SELECT @n_continue = 3
 END
 ELSE IF @b_debug = 1
 BEGIN
 SELECT @c_sku "@c_sku"
 END
 END
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_caseid)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    PICKDETAIL.StorerKey,
 PICKDETAIL.Lot,
 PICKDETAIL.Sku,
 PICKDETAIL.Id,
 dbo.fnc_RTrim(PICKDETAIL.Loc) + '/' + PICKDETAIL.ToLoc Loc,
 PICKDETAIL.CaseId,
 PICKDETAIL.Qty,
 PICKDETAIL.UOM,
 PICKDETAIL.PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM PICKDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK)
 WHERE PICKDETAIL.Lot = LOTATTRIBUTE.Lot
 AND PICKDETAIL.Id = ID.Id
 AND PICKDETAIL.CaseId = @c_caseid
 ORDER BY PICKDETAIL.Sku
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    PICKDETAIL.StorerKey,
 PICKDETAIL.Lot,
 PICKDETAIL.Sku,
 PICKDETAIL.Id,
 dbo.fnc_RTrim(PICKDETAIL.Loc) + '/' + PICKDETAIL.ToLoc Loc,
 PICKDETAIL.CaseId,
 PICKDETAIL.Qty,
 PICKDETAIL.UOM,
 PICKDETAIL.PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM PICKDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK)
 WHERE PICKDETAIL.Lot = LOTATTRIBUTE.Lot
 AND PICKDETAIL.Id = ID.Id
 AND PICKDETAIL.CaseId = N'" + @c_caseid + "'
 ORDER BY PICKDETAIL.Sku
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loc)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Id = @c_id
 AND LOTxLOCxID.Loc = @c_loc
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Id = N'" + @c_id + "'
 AND LOTxLOCxID.Loc = N'" + @c_loc + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Id = @c_id
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Id = N'" + @c_id + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lot)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Loc)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Lot = @c_lot
 AND LOTxLOCxID.Loc = @c_loc
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Lot = N'" + @c_lot + "'
 AND LOTxLOCxID.Loc = N'" + @c_loc + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lot)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Lot = @c_lot
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 OTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Lot = N'" + @c_lot + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Loc)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID, SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.StorerKey = @c_storerkey
 AND LOTxLOCxID.Sku = @c_sku
 AND LOTxLOCxID.Loc = @c_loc
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.StorerKey = N'" + @c_storerkey + "'
 AND LOTxLOCxID.Sku = N'" + @c_sku + "'
 AND LOTxLOCxID.Loc = N'" + @c_loc + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.StorerKey = @c_storerkey
 AND LOTxLOCxID.Sku = @c_sku
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.StorerKey = N'" + @c_storerkey + "'
 AND LOTxLOCxID.Sku = N'" + @c_sku + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 /* Add by Ted Heung, 2001/11/23 to cater storerkey + loc */
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Loc)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Loc = @c_loc
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.StorerKey,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Lot
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Loc = N'" + @c_loc + "'
 AND LOTxLOCxID.StorerKey = N'" + @c_storerkey + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.StorerKey,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Lot
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 /* Add by Ted Heung, 2001/11/23 to cater storerkey + loc */
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Loc)) IS NULL
 BEGIN
 IF @b_debug = 1
 BEGIN
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Loc = @c_loc
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.StorerKey,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Lot
 END
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.Loc = N'" + @c_loc + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.StorerKey,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Lot
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL
 BEGIN
 EXEC ("DECLARE CURSOR_INQUIRY SCROLL CURSOR FOR
 SELECT    LOTxLOCxID.StorerKey,
 LOTxLOCxID.Lot,
 LOTxLOCxID.Sku,
 LOTxLOCxID.Id,
 LOTxLOCxID.Loc,
 '' CaseId,
 LOTxLOCxID.Qty,
 PACK.PACKUOM3 AS UOM,
 SKU.PACKKEY AS PackKey,
 LOTATTRIBUTE.Lottable01,
 LOTATTRIBUTE.Lottable02,
 LOTATTRIBUTE.Lottable03,
 LOTATTRIBUTE.Lottable04,
 LOTATTRIBUTE.Lottable05,
 ID.Status
 FROM LOTxLOCxID (NOLOCK), LOTATTRIBUTE (NOLOCK), ID (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
 WHERE LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
 AND LOTxLOCxID.Id = ID.Id
 AND LOTxLOCxID.StorerKey = N'" + @c_storerkey + "'
 AND LOTxLOCxID.Qty > 0
 AND LOTxLOCxID.StorerKey = SKU.StorerKey
 AND LOTxLOCxID.SKU = SKU.SKU
 AND SKU.PackKey = PACK.PackKey
 ORDER BY LOTxLOCxID.Loc
 FOR READ ONLY"
 )
 OPEN CURSOR_INQUIRY
 END
 ELSE
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65900
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFIQ01)"
 END
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 SELECT @n_returnrecs=@@CURSOR_ROWS
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 DECLARE @INQUIRY_storerkey     NVARCHAR(15),
 @INQUIRY_lot              NVARCHAR(10),
 @INQUIRY_sku              NVARCHAR(20),
 @INQUIRY_id               NVARCHAR(18),
 @INQUIRY_loc              NVARCHAR(21),
 @INQUIRY_caseid           NVARCHAR(10),
 @INQUIRY_qty              int,
 @INQUIRY_uom              NVARCHAR(10),
 @INQUIRY_packkey          NVARCHAR(10),
 @INQUIRY_Lottable01       NVARCHAR(18),
 @INQUIRY_Lottable02       NVARCHAR(18),
 @INQUIRY_Lottable03       NVARCHAR(18),
 @INQUIRY_Lottable04       datetime,
 @INQUIRY_Lottable05       datetime,
 @INQUIRY_status           NVARCHAR(10)
 SELECT @INQUIRY_storerkey      = space(15),
 @INQUIRY_lot              = space(10),
 @INQUIRY_sku              = space(20),
 @INQUIRY_id               = space(18),
 @INQUIRY_loc              = space(21),
 @INQUIRY_caseid           = space(10),
 @INQUIRY_qty              = 0,
 @INQUIRY_uom              = space(10),
 @INQUIRY_packkey          = space(10),
 @INQUIRY_Lottable01       = space(18),
 @INQUIRY_Lottable02       = space(18),
 @INQUIRY_Lottable03       = space(18),
 @INQUIRY_Lottable04       = NULL,
 @INQUIRY_Lottable05       = NULL,
 @INQUIRY_status           = space(10)
 FETCH NEXT FROM CURSOR_INQUIRY
 INTO @INQUIRY_StorerKey,
 @INQUIRY_Lot,
 @INQUIRY_Sku,
 @INQUIRY_Id,
 @INQUIRY_Loc,
 @INQUIRY_CaseId,
 @INQUIRY_Qty,
 @INQUIRY_UOM,
 @INQUIRY_PackKey,
 @INQUIRY_Lottable01,
 @INQUIRY_Lottable02,
 @INQUIRY_Lottable03,
 @INQUIRY_Lottable04,
 @INQUIRY_Lottable05,
 @INQUIRY_Status
 SELECT @n_err = @@ERROR
 IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFIQ01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE
 BEGIN
 SELECT @n_err = @@FETCH_STATUS
 IF @n_err = -1
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_retrec="02"
 SELECT @n_err = 65902
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Row(s) Found, EOF. (nspRFIQ01)"
 END
 ELSE IF @n_err = -2
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65903
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFIQ01)"
 END
 ELSE IF NOT @n_err = 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err = 65904
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFIQ01)"
 END
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
 END
 DECLARE @CONVERT_Lottable04 NVARCHAR(8)
 IF @INQUIRY_Lottable04 IS NULL
 SELECT @CONVERT_Lottable04 = ""
 ELSE
 SELECT @CONVERT_Lottable04 = CONVERT(char(8), @INQUIRY_Lottable04, 1)
 DECLARE @CONVERT_Lottable05 NVARCHAR(8)
 IF @INQUIRY_Lottable05 IS NULL
 SELECT @CONVERT_Lottable05 = ""
 ELSE
 SELECT @CONVERT_Lottable05 = CONVERT(char(8), @INQUIRY_Lottable05, 1)
 SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
 + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
 + @c_appflag   + @c_senddelimiter
 + @c_retrec    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_errmsg)  + @c_senddelimiter
 + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(10), @n_returnrecs))) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_StorerKey) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Lot) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Sku) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Id) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Loc) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_CaseId) + @c_senddelimiter
 + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(10), @INQUIRY_Qty))) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_UOM) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_PackKey) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Lottable01) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Lottable02) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Lottable03) + @c_senddelimiter
 + dbo.fnc_RTrim(@CONVERT_Lottable04) + @c_senddelimiter
 + dbo.fnc_RTrim(@CONVERT_Lottable05) + @c_senddelimiter
 + dbo.fnc_RTrim(@INQUIRY_Status)
 SELECT dbo.fnc_RTrim(@c_outstring)
      /* #INCLUDE <SPRFIQ01_2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "nspRFIQ01"
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