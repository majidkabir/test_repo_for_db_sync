SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFRP03                                          */
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

CREATE PROC    [dbo].[nspRFRP03]
@c_senddelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(10)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_replenishmentkey NVARCHAR(10)
,              @c_storerkey        NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_fromsku          NVARCHAR(30)
,              @c_sku              NVARCHAR(30)
,              @c_fromloc          NVARCHAR(18)
,              @c_fromid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @n_fromqty          int
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
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
   @n_err2 int,              -- For Additional Error Detection
   @n_cnt int,               -- Holds @@ROWCOUNT
   @n_TranBusy int           -- Hold BEGIN TRANSATION Status
   DECLARE @c_retrec NVARCHAR(2)     -- Return Record "01" = Success, "09" = Failure
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   DECLARE @b_debug int
   SELECT @b_debug = 1
   DECLARE @n_originalQty int
   SELECT @n_originalQty  = @n_qty
   /* #INCLUDE <SPRFRP03_1.SQL> */
   IF @b_debug = 1
   BEGIN
      SELECT 'LOT', @c_lot
   END
   /* Handle the display of lottable04 in RF by Ricky Nov. 1st 2001 */
   SELECT @c_packkey = ''
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) = NULL
   BEGIN
      SELECT @c_toid = @c_fromid
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromsku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GETSKU
         @c_StorerKey   = @c_StorerKey,
         @c_sku         = @c_fromsku OUTPUT,
         @b_success     = @b_success OUTPUT,
         @n_err         = @n_err     OUTPUT,
         @c_errmsg      = @c_errmsg  OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
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
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_sku <> @c_fromsku
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65315, @c_errmsg = "NSQL65315:" + "Invalid Sku!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspGetPack
      @c_storerkey   = @c_storerkey,
      @c_sku         = @c_sku,
      @c_lot         = @c_lot,
      @c_loc         = @c_fromloc,
      @c_id          = @c_toid,
      @c_packkey     = @c_packkey      OUTPUT,
      @b_success     = @b_success      OUTPUT,
      @n_err         = @n_err          OUTPUT,
      @c_errmsg      = @c_errmsg       OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_uom)) = NULL
   BEGIN
      SELECT @c_uom = PackUOM3
      FROM PACK
      WHERE PackKey = @c_packkey
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspUOMConv
      @n_fromqty = @n_qty,
      @c_fromuom = @c_uom,
      @c_touom   = NULL,
      @c_packkey = @c_packkey,
      @n_toqty   = @n_qty OUTPUT,
      @b_success = @b_success OUTPUT,
      @n_err     = @n_err OUTPUT,
      @c_errmsg  = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   /* Modified to cater the FromLoc and ToLoc is different loc by Ricky Nov. 1, 2001 */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_fromloc =	@c_toloc
      Begin
         SELECT @n_continue = 3
         SELECT @n_err = 65316, @c_errmsg = "NSQL65316:" + "FromLoc=ToLoc!"
      End
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_fromloc =	@c_toloc
      Begin
         SELECT @n_continue = 3
         SELECT @n_err = 65316, @c_errmsg = "NSQL65316:" + "FromLoc=ToLoc!"
      End
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @n_qty > 0
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
         @c_SourceType   = "nspRFRP03",
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
         SELECT @c_retrec="09"
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
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* #INCLUDE <SPRFRP03_2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspRFRP03"
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