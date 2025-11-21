SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFTRP01                                         */
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

CREATE PROC    [dbo].[nspRFTRP01]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(18)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(5)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ttm              NVARCHAR(5)
,              @c_taskdetailkey    NVARCHAR(10)
,              @c_storerkey        NVARCHAR(15)
,              @c_sku              NVARCHAR(30)
,              @c_fromloc          NVARCHAR(18)
,              @c_fromid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @c_lot              NVARCHAR(10)
,              @n_qty              int
,              @c_packkey          NVARCHAR(10)
,              @c_uom              NVARCHAR(10)
,              @c_reasoncode       NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 1
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   DECLARE @c_fromStorerKey NVARCHAR(15), @c_fromSku NVARCHAR(20), @n_fromQty int, @c_fromLot NVARCHAR(10)
   /* #INCLUDE <SPTRP01_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_fromStorerKey = StorerKey,
      @c_fromsku = SKU,
      @c_fromlot = Lot,
      @n_fromqty = QTY
      FROM REPLENISHMENT
      WHERE REPLENISHMENTKEY = @c_taskdetailkey
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81501, @c_errmsg = "NSQL81501:Invalid Replenishment/TaskDetail Key"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ( @c_StorerKey <> @c_fromStorerKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81502, @c_errmsg = "NSQL81502:" + "Invalid StorerKey!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ( @c_Sku <> @c_fromSku )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81503, @c_errmsg = "NSQL81503:" + "Invalid Sku!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ( @c_lot <> @c_fromlot )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81504, @c_errmsg = "NSQL81504:" + "Invalid Lot!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GETSKU
         @c_StorerKey   = @c_StorerKey,
         @c_sku     = @c_sku     OUTPUT,
         @b_success = @b_success OUTPUT,
         @n_err     = @n_err     OUTPUT,
         @c_errmsg  = @c_errmsg  OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) = NULL
   BEGIN
      SELECT @c_toid = @c_fromid
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      Declare @c_OnReceiptCopyPackKey NVARCHAR(10),
      @c_fromPackKey NVARCHAR(10),
      @c_fromUOM NVARCHAR(10)
      SELECT @c_fromPackKey = PACK.PackKey,
      @c_OnReceiptCopyPackKey = SKU.OnReceiptCopyPackKey,
      @c_fromUOM = PACK.PackUOM3
      FROM SKU (nolock), PACK (nolock), LOTATTRIBUTE (nolock)
      WHERE SKU.STORERKEY = @c_storerkey
      AND SKU.SKU = @c_sku
      AND LOTATTRIBUTE.Lot = @c_lot
      AND PACK.PackKey = CASE when SKU.OnReceiptCopyPackKey = '1'
      then IsNull(dbo.fnc_LTrim(dbo.fnc_RTrim(LOTATTRIBUTE.Lottable01)), SKU.PackKey)
   else SKU.PackKey end
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_frompackkey)) = NULL
      BEGIN
         SELECT @n_err = 81505, @c_errmsg = "NSQL81505: Ambiguous PackKey for Lot " + @c_lot
         execute nsp_logerror @n_err, @c_errmsg, "nspRFTRP01"
         SELECT @c_fromPackKey = PACK.PackKey, @c_fromUOM = PackUOM3
         FROM PACK (nolock), SKU (nolock)
         WHERE StorerKey = @c_storerkey
         AND Sku = @c_sku
         AND SKU.PackKey = PACK.PackKey
      END
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PackKey)) = NULL
      BEGIN
         SELECT @c_PackKey = @c_fromPackKey, @c_UOM = @c_fromUOM
      END
   ELSE IF @c_PackKey <> @c_fromPackKey
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81506, @c_errmsg = "NSQL81506: Invalid PackKey (expected " + @c_fromPackKey + ")"
      END
   ELSE IF ( dbo.fnc_LTrim(dbo.fnc_RTrim(@c_UOM)) = NULL  and (@n_qty = @n_fromqty) )
      BEGIN
         SELECT @c_UOM = @c_fromUOM
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_toqty int
      SELECT @b_success = 1
      EXECUTE nspUOMConv
      @n_fromqty = @n_qty,
      @c_fromuom = @c_uom,
      @c_touom   = NULL,
      @c_packkey = @c_packkey,
      @n_toqty   = @n_toqty OUTPUT,
      @b_success = @b_success OUTPUT,
      @n_err     = @n_err OUTPUT,
      @c_errmsg  = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) IS NOT NULL
      BEGIN
         IF NOT EXISTS (SELECT * FROM TaskManagerReason
         WHERE TaskManagerReasonKey = @c_reasoncode
         AND ValidInToLoc = "1"
         )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 81511, @c_errmsg = "NSQL81511:" + "Invalid ReasonCode!"
         END
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF (@n_toqty <> @n_fromqty) AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) IS NULL
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81512, @c_errmsg = "NSQL81512:" + "Quantity Does not Match - Reason Code Was Not Supplied!"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @n_toqty > 0
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspItrnAddMove
         @n_ItrnSysId    = NULL,
         @c_itrnkey      = NULL,
         @c_StorerKey    = @c_storerkey,
         @c_Sku          = @c_sku,
         @c_Lot          = @c_lot,
         @c_FromLoc      = @c_fromloc,
         @c_FromID       = @c_fromid,
         @c_ToLoc        = @c_toloc,
         @c_ToID         = @c_toid,
         @c_Status       = "",
         @c_lottable01   = "",
         @c_lottable02   = "",
         @c_lottable03   = "",
         @d_lottable04   = NULL,
         @d_lottable05   = NULL,
         @n_casecnt      = 0,
         @n_innerpack    = 0,
         @n_qty          = @n_qty,
         @n_pallet       = 0,
         @f_cube         = 0,
         @f_grosswgt     = 0,
         @f_netwgt       = 0,
         @f_otherunit1   = 0,
         @f_otherunit2   = 0,
         @c_SourceKey    = "",
         @c_SourceType   = "nspRFTRP01",
         @c_PackKey      = @c_packkey,
         @c_UOM          = @c_uom,
         @b_UOMCalc      = 1,
         @d_EffectiveDate = NULL,
         @b_Success      = @b_success  OUTPUT,
         @n_err          = @n_err      OUTPUT,
         @c_errmsg       = @c_errmsg   OUTPUT
         IF @b_success = 0
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END -- @n_continue = 1 or @n_continue = 2
   IF @n_continue=3
   BEGIN
      IF @c_retrec="01"
      BEGIN
         SELECT @c_retrec="09", @c_appflag = "TRP"
      END
   END
ELSE
   BEGIN
      SELECT @c_retrec="01"
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         DELETE FROM REPLENISHMENT_LOCK
         WHERE PTCID = @c_ptcid or
         datediff(second,adddate,getdate()) > 900  -- 15 minutes
      END
   END
   SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* #INCLUDE <SPTRP01_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFTRP01"
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