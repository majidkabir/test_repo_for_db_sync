SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFPH02                                          */
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

CREATE PROC    [dbo].[nspRFPH02]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(5)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_storerkey        NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(30)
,              @c_id               NVARCHAR(18)
,              @c_loc              NVARCHAR(18)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
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
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @c_storerkey, @c_sku, @c_lot, @c_id, @c_loc, @n_qty, @c_uom, @c_packkey
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
   /* #INCLUDE <SPRFPH02_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
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
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      execute    nspLOTLOCIDUniqueRow
      @c_storerkey    =@c_storerkey OUTPUT
      ,              @c_sku          =@c_sku       OUTPUT
      ,              @c_lot          =@c_lot       OUTPUT
      ,              @c_Loc          =@c_loc       OUTPUT
      ,              @c_ID           =@c_id        OUTPUT
      ,              @b_Success      =@b_success   OUTPUT
      ,              @n_err          =@n_err       OUTPUT
      ,              @c_errmsg       =@c_errmsg    OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue =3
      END
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
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @n_SystemQty int
      SELECT
      @n_SystemQty = SUM(Qty)
      FROM
      LOTxLOCxID
      WHERE
      Loc = @c_Loc
      AND  StorerKey = @c_StorerKey
      AND  Sku = @c_Sku
      AND  Id = @c_Id
      AND  Lot=@c_lot
      GROUP BY
      Loc,
      StorerKey,
      Sku,
      Id,
      Lot
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Select Failed On LOTxLOCxID. (nspRFPH02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_SystemQty = 0
      END
   END
   IF @b_debug = 1
   BEGIN
      SELECT @n_SystemQty
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_AlertMessage NVARCHAR(255)
      SELECT @c_AlertMessage =
      "CYCLE COUNT NOTIFICATION: StorerKey=" + dbo.fnc_RTrim(@c_StorerKey) +
      ", Sku=" + dbo.fnc_RTrim(@c_Sku) +
      ", Lot=" + dbo.fnc_RTrim(@c_Lot) +
      ", Id=" + dbo.fnc_RTrim(@c_Id) +
      ", Loc=" + dbo.fnc_RTrim(@c_Loc) +
      ", CycleCount=" + dbo.fnc_RTrim(CONVERT(char(10), @n_Qty)) +
      ", SystemCount=" + dbo.fnc_RTrim(CONVERT(char(10),@n_systemqty)) +
      ", Difference=" + dbo.fnc_RTrim(CONVERT(char(10),@n_Qty - @n_systemqty)) +
      ", UOM=" + dbo.fnc_RTrim(@c_UOM) +
      ", PackKey=" + dbo.fnc_RTrim(@c_PackKey)
      SELECT @b_success = 1
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspRFPH02",
      @c_AlertMessage = @c_AlertMessage,
      @n_Severity     = NULL,
      @b_success      = @b_success,
      @n_err          = @n_err,
      @c_errmsg       = @c_errmsg
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue=3
   BEGIN
      IF @c_retrec="01"
      BEGIN
         SELECT @c_retrec="09"
      END
   END
   SELECT @c_outstring =
   @c_ptcid               + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)       + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)       + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)      + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)       + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)       + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* #INCLUDE <SPRFPH02_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFPH02"
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