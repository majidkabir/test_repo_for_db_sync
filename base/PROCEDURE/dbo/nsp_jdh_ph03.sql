SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_JDH_PH03                                       */
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

CREATE PROC    [dbo].[nsp_JDH_PH03]
@c_SheetNo          NVARCHAR(10)
,              @c_storerkey        NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(30)
,              @c_id               NVARCHAR(18)
,              @c_loc              NVARCHAR(18)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_team             NVARCHAR(1)
,              @c_inventorytag     NVARCHAR(18)
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   DECLARE @b_hold NVARCHAR(10)
   DECLARE @c_Dummy NVARCHAR(20)
   SELECT @b_debug = 0
   SELECT @b_hold = "0"
   IF @b_debug = 1
   BEGIN
      SELECT @c_storerkey, @c_lot, @c_sku, @c_id, @c_loc, @n_qty, @c_uom, @c_packkey,  @c_team, @c_inventorytag
   END
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @n_cnt int                -- Holds row count of most recent SQL statement
   DECLARE @c_retrec NVARCHAR(2)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   /* #INCLUDE <SPRFPH03_1.SQL> */
   SELECT @c_packkey = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey))
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_team)) IS NULL
   BEGIN
      SELECT @c_team = "A"
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lot)) IS NOT NULL
   BEGIN
      SELECT @c_Dummy = Lot FROM LOTATTRIBUTE
      WHERE Lot = @c_lot
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70405
         SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Invalid Lot. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         execute nsp_logerror @n_err, @c_errmsg, "nsp_JDH_PH03"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL
      OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL
      SELECT @c_StorerKey = StorerKey,
      @c_Sku = Sku
      FROM LOTATTRIBUTE
      WHERE Lot = @c_Lot
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70406
         SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Select Failed On LOTATTRIBUTE. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspg_GETSKU
      @c_StorerKey  = @c_StorerKey,
      @c_sku        = @c_sku     OUTPUT,
      @b_success    = @b_success OUTPUT,
      @n_err        = @n_err     OUTPUT,
      @c_errmsg     = @c_errmsg  OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE IF @b_debug = 1
      BEGIN
         SELECT @c_sku "@c_sku"
      END
   END
   SELECT @b_success = 0
   EXECUTE nspGetPack
   @c_storerkey        = @c_storerkey,
   @c_sku              = @c_sku,
   @c_lot              = @c_lot,
   @c_loc              = @c_loc,
   @c_id               = @c_id,
   @c_packkey          = @c_packkey      OUTPUT,
   @b_success          = @b_success      OUTPUT,
   @n_err              = @n_err          OUTPUT,
   @c_errmsg           = @c_errmsg       OUTPUT
   IF NOT @b_success = 1
   BEGIN
      SELECT @n_continue = 3
   END
ELSE IF @b_debug = 1
   BEGIN
      SELECT @c_id "@c_id"
      SELECT @c_lot "@c_lot"
      SELECT @c_loc "@c_loc"
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_uom)) IS NULL
   SELECT @c_uom = PackUOM3 FROM PACK
   WHERE packkey = @c_packkey
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407
      SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Select Failed On PACK. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @n_UOMQty int
      SELECT @n_UOMQty = 0
      SELECT @n_UOMQty = @n_Qty
      SELECT @b_success = 1
      EXECUTE nspUOMConv
      @n_fromqty = @n_qty,
      @c_fromuom = @c_uom,
      @c_touom   = NULL,
      @c_packkey = @c_packkey,
      @n_toqty   = @n_qty      OUTPUT,
      @b_success = @b_success  OUTPUT,
      @n_err     = @n_err      OUTPUT,
      @c_errmsg  = @c_errmsg   OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @b_debug = 1
   BEGIN
      SELECT @n_qty
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_InventoryTag)) IS NULL
   AND @n_continue <> 3
   BEGIN
      UPDATE PHYSICAL
      SET   Qty = @n_Qty,
      UOM = @c_uom,
      PackKey = @c_packkey,
      SheetNoKey = @c_SheetNo
      WHERE StorerKey = @c_StorerKey
      AND Sku = @c_Sku
      AND Loc = @c_Loc
      AND Id = @c_Id
      AND (Lot = @c_Lot
      OR Lot = " ")
      AND Team = @c_team
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update1 Failed On PHYSICAL. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0 AND @n_continue <> 3
      BEGIN
         INSERT PHYSICAL (
         Team,
         InventoryTag,
         StorerKey,
         Sku,
         Loc,
         Lot,
         Id,
         Qty,
         PackKey,
         UOM,
         SheetNoKey
         )
         VALUES (
         @c_Team,
         @c_InventoryTag,
         @c_StorerKey,
         @c_Sku,
         @c_Loc,
         @c_Lot,
         @c_Id,
         @n_Qty,
         @c_PackKey,
         @c_UOM,
         @c_SheetNo
         )
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Insert Failed On PHYSICAL. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
ELSE
   BEGIN
      IF @n_continue <> 3
      UPDATE PHYSICAL
      SET    Qty = @n_Qty,
      UOM = @c_uom,
      PackKey = @c_packkey,
      ID = @c_id,
      sku = @c_sku,
      storerkey = @c_storerkey,
      loc = @c_loc,
      lot = @c_lot,
      SheetNoKey = @c_SheetNo
      WHERE  InventoryTag = @c_InventoryTag
      AND Team = @c_team
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PHYSICAL. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0 AND @n_continue <> 3
      BEGIN
         INSERT PHYSICAL (
         Team,
         InventoryTag,
         StorerKey,
         Sku,
         Loc,
         Lot,
         Id,
         Qty,
         PackKey,
         UOM,
         SheetNoKey
         )
         VALUES (
         @c_Team,
         @c_InventoryTag,
         @c_StorerKey,
         @c_Sku,
         @c_Loc,
         @c_Lot,
         @c_Id,
         @n_Qty,
         @c_PackKey,
         @c_UOM,
         @c_SheetNo
         )
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70404   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Insert Failed On PHYSICAL. (nsp_JDH_PH03)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
   /* #INCLUDE <SPRFPH03_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nsp_JDH_PH03"
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