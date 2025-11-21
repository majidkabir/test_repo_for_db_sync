SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFTMV01                                         */
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

CREATE PROC    [dbo].[nspRFTMV01]
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
   SELECT @b_debug = 0
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   DECLARE @c_requestedsku NVARCHAR(20), @n_requestedqty int, @c_requestedlot NVARCHAR(10),
   @c_requestedfromid NVARCHAR(18), @c_requestedfromloc NVARCHAR(10),
   @c_requestedtoid NVARCHAR(18), @c_requestedtoloc NVARCHAR(10),
   @c_requestedwavekey NVARCHAR(10), @c_currentstatus NVARCHAR(10)
   /* #INCLUDE <SPTMV01_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) = NULL
      BEGIN
         SELECT @c_toid = @c_fromid
      END
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey)) = NULL
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NOT NULL
         BEGIN
            SELECT @c_packkey = id.packkey,
            @c_uom= pack.packuom3
            FROM ID,PACK
            WHERE ID = @c_fromid
            AND   ID.PACKKEY = PACK.PACKKEY
         END
      ELSE
         BEGIN
            SELECT @c_packkey = sku.packkey,
            @c_uom= pack.packuom3
            FROM SKU,PACK
            WHERE STORERKEY = @c_storerkey
            AND   SKU = @c_sku
            AND   SKU.PACKKEY = PACK.PACKKEY
         END
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_requestedsku = SKU,
      @n_requestedqty = QTY,
      @c_requestedlot = LOT,
      @c_requestedfromid  = FROMID,
      @c_requestedfromloc = FROMLOC,
      @c_requestedtoid  = TOID,
      @c_requestedtoloc = LogicalToLoc, -- FBR028c, to handle the case where toloc <> logicalToloc, toloc = final destination
      @c_requestedwavekey = WAVEKEY,
      @c_currentstatus = status
      FROM TASKDETAIL
      WHERE TASKDETAILKEY = @c_taskdetailkey
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81601, @c_errmsg = "NSQL81601:Invalid TaskDetail Key"
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
      IF @c_sku <> @c_requestedsku
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81602, @c_errmsg = "NSQL81602:" + "Invalid Sku!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_fromid <> @c_requestedfromid
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81606, @c_errmsg = "NSQL81606:" + "Invalid From ID!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_fromloc <> @c_requestedfromloc
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81608, @c_errmsg = "NSQL81608:" + "Invalid From Loc!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_toid <> @c_requestedtoid
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81609, @c_errmsg = "NSQL81609:" + "Invalid To ID!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_toloc <> @c_requestedtoloc
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81610, @c_errmsg = "NSQL81610:" + "Invalid To Loc!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_lot <> @c_requestedlot
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81607, @c_errmsg = "NSQL81607:" + "Invalid Lot!"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_currentstatus = "9"
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81613, @c_errmsg = "NSQL81613:" + "Item Already Processed!"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      print "@c_uom = " + @c_uom
      EXECUTE nspUOMConv
      @n_fromqty = @n_qty,
      @c_fromuom = @c_uom,
      @c_touom   = NULL,
      @c_packkey = @c_packkey,
      @n_toqty   = @n_qty OUTPUT,
      @b_success = @b_success OUTPUT,
      @n_err     = @n_err OUTPUT,
      @c_errmsg  = @c_errmsg OUTPUT
      print "done"
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
            SELECT @n_err = 81603, @c_errmsg = "NSQL81603:" + "Invalid ReasonCode!"
         END
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      BEGIN TRAN
         IF 1=1  -- @n_qty > 0
         BEGIN
            UPDATE TASKDETAIL
            SET STATUS = "9" ,
            Qty = @n_qty ,
            --FromLoc = @c_fromloc,
            FromId = @c_fromid,
            --ToLoc = @c_toloc,
            Toid = @c_toid,
            Reasonkey = @c_reasoncode,
            UserPosition = "2", -- This task is being performed at the TOLOC
            EndTime = getdate()
            WHERE taskdetailkey = @c_taskdetailkey
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=81605   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TaskDetail. (nspRFTMV01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END
         IF @n_continue = 3
         BEGIN
            ROLLBACK TRAN
         END
      ELSE
         BEGIN
            COMMIT TRAN
         END
      END -- @n_continue = 1 or @n_continue = 2
      IF @n_continue=3
      BEGIN
         IF @c_retrec="01"
         BEGIN
            SELECT @c_retrec="09", @c_appflag = "TMV"
         END
      END
   ELSE
      BEGIN
         SELECT @c_retrec="01"
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
      /* #INCLUDE <SPTMV01_2.SQL> */
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
         execute nsp_logerror @n_err, @c_errmsg, "nspRFTMV01"
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