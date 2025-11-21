SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFOP01                                          */
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

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFOP01]
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
,              @c_fromid           NVARCHAR(18)
,              @c_fromloc          NVARCHAR(18)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_shiplabel        NVARCHAR(10)
,              @c_dropid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(10)
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
   DECLARE        @n_continue int        ,  /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @n_cnt int                -- Holds @@ROWCOUNT
   /* Declare RF Specific Variables */
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   /* RC01 Specific Variables */
   DECLARE @c_itrnkey NVARCHAR(10)
   /* Start Main Processing */
   /* Validate Storer */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF NOT EXISTS (SELECT * FROM STORER (NOLOCK) WHERE StorerKey = @c_storerkey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Storer (nspRFOP01)"
      END
   END
   /* End Validate Store */
   DECLARE @c_dummy1 	 NVARCHAR(10),
   @c_dummy2 	 NVARCHAR(10),
   @n_qtytopick	int
   /* Calculate Sku Supercession */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GETSKU1
         @c_StorerKey   = @c_StorerKey,
         @c_sku     = @c_sku     OUTPUT,
         @b_success = @b_success OUTPUT,
         @n_err     = @n_err     OUTPUT,
         @c_errmsg  = @c_errmsg  OUTPUT,
         @c_packkey = @c_dummy1  OUTPUT,
         @c_uom     = @c_dummy2  OUTPUT
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
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   /* End Calculate Next Task ID */
   /* Validate Pick# */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ISNULL(@c_lot,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Pick# Required (nspRFOP01)"
      END
   ELSE
      BEGIN
         IF NOT EXISTS (SELECT * FROM WAVE (NOLOCK) WHERE WaveKey = @c_lot)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 65601
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Pick# (nspRFOP01)"
         END
      END
   END
   /* End Validate Pick# */
   /* Validate Order# */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ISNULL(@c_shiplabel,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT * FROM ORDERS (NOLOCK) WHERE OrderKey = @c_shiplabel)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 65601
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Order# (nspRFOP01)"
         END
      END
   END
   /* End Validate Order# */
   /* Validate Pick# & Order# */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ISNULL(@c_shiplabel,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT * FROM WAVEDETAIL (NOLOCK)
         WHERE WaveKey = @c_lot AND OrderKey = @c_shiplabel)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 65601
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Order# not in this Pick# (nspRFOP01)"
         END
      END
   END
   /* End Validate Order# */
   /* Validate Loc */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF NOT EXISTS (SELECT * FROM LOC (NOLOCK) WHERE Loc = @c_fromloc)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Loc. (nspRFOP01)"
      END
   END
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF NOT EXISTS (SELECT * FROM WAVEDETAIL WD (NOLOCK), PICKDETAIL PD (NOLOCK)
      WHERE WD.OrderKey = PD.OrderKey
      AND WD.WaveKey = @c_lot
      AND (PD.OrderKey = @c_shiplabel OR ISNULL(@c_shiplabel,'') = '')
      AND PD.Loc = @c_fromloc)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Loc nothing to Pick (nspRFOP01)"
      END
   END
   /* End Validate ToLoc */
   /* Validate Sku */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF NOT EXISTS (SELECT * FROM WAVEDETAIL WD (NOLOCK), PICKDETAIL PD (NOLOCK)
      WHERE WD.OrderKey = PD.OrderKey
      AND WD.WaveKey = @c_lot
      AND (PD.OrderKey = @c_shiplabel OR ISNULL(@c_shiplabel,'') = '')
      AND PD.Loc = @c_fromloc
      AND PD.Sku = @c_sku AND PD.StorerKey = @c_storerkey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Nothing to Pick for this SKU (nspRFOP01)"
      END
   END
   /* End Validate SKU */
   /* Validate Qty */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @n_qtytopick = SUM(PD.Qty)
      FROM WAVEDETAIL WD (NOLOCK), PICKDETAIL PD (NOLOCK)
      WHERE WD.OrderKey = PD.OrderKey
      AND WD.WaveKey = @c_lot
      AND (PD.OrderKey = @c_shiplabel OR ISNULL(@c_shiplabel,'') = '')
      AND PD.Loc = @c_fromloc
      AND PD.Sku = @c_sku AND PD.StorerKey = @c_storerkey
      AND PD.Status = '0'

      IF @n_qtytopick <> @n_qty
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65601
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Qty (nspRFOP01)"
      END
   END
   /* End Validate Qty */
   /* Below Codes Commented by CY */
   /*
   /* Ensure that the location the user picked from is the one that we said to pick from!*/
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) is not null
      BEGIN
         DECLARE @c_checkfromloc NVARCHAR(10)
         SELECT @c_checkfromloc = loc FROM PICKDETAIL (NOLOCK)
         WHERE caseid = @c_shiplabel
         IF @c_checkfromloc <> @c_fromloc
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65602   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": LOC NOT MATCH. (nspRFOP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END
   END
   /* End ensure that the location the user picked from is the one that we said to pick from!*/
   /* Ensure that the sku the user picked is the one that we said to pick!*/
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) is not null and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) is not null
      BEGIN
         DECLARE @c_checksku NVARCHAR(20), @c_checkstorerkey NVARCHAR(15)
         SELECT @c_checksku = sku, @c_checkstorerkey = storerkey
         FROM PICKDETAIL (NOLOCK)
         WHERE caseid = @c_shiplabel
         IF @c_checksku <> @c_sku or @c_checkstorerkey <> @c_storerkey
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65603   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": SKU DOES NOT MATCH. (nspRFOP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END
   END
   /* Ensure that the sku the user picked is the one that we said to pick!*/
   /* Ensure that the qty the user picked is the one that we said to pick!*/
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @n_qty > 0
      BEGIN
         DECLARE @n_checkqty int
         SELECT @n_checkqty = qty
         FROM PICKDETAIL (NOLOCK)
         WHERE caseid = @c_shiplabel
         IF @n_checkqty <> @n_qty
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65606   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": QTY DOES NOT MATCH. (nspRFOP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF @n_qty = 0
         BEGIN
            SELECT @n_qty = @n_checkqty
         END
      END
   END
   /* Ensure that the qty the user picked is the one that we said to pick!*/
   */
   /* Above Codes Commented by CY */
   /* If background processing is turned on Place in the POLL_PICK table */
   DECLARE @c_background NVARCHAR(1)
   SELECT @c_background = "0"
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_background = ( SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
      FROM NSQLCONFIG (NOLOCK)
      WHERE NSQLCONFIG.ConfigKey = "RFFULLCSPICKBKGROUND")
   END
   IF (@n_continue = 1 or @n_continue = 2) and @c_background = "1"
   BEGIN
      INSERT POLL_UPDATE (updatestring) SELECT "update pickdetail set status = '5' where caseid = " + "N'" + @c_shiplabel + "'"
      /* INSERT POLL_PICK (caseid) values (@c_shiplabel) */
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update to POLL_PICK failed. (nspRFOP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   END
   /* End If background processing is turned on Place in the POLL_PICK table */
   /* Update table "PickDetail" */
   IF (@n_continue=1 OR @n_continue=2) and (@c_background = "0" or @c_background = "" or @c_background is null)
   BEGIN
      UPDATE PICKDETAIL
      SET Status = '5'
      FROM WAVEDETAIL WD, PICKDETAIL PD
      WHERE WD.OrderKey = PD.OrderKey
      AND WD.WaveKey = @c_lot
      AND (PD.OrderKey = @c_shiplabel OR ISNULL(@c_shiplabel,'') = '')
      AND PD.Loc = @c_fromloc
      AND PD.Sku = @c_sku AND PD.StorerKey = @c_storerkey
      AND PD.Status = '0'
      /* Below Codes Commented by CY */
      /*  UPDATE PICKDETAIL
      SET Status = "5",
      DropId = @c_dropid,
      ToLoc = @c_toloc
      WHERE CaseId = @c_shiplabel
      AND Loc = @c_fromloc
      AND Id = @c_fromid */
      /* Above Codes Commented by CY */
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update PICKDETAIL Failed. (nspRFOP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 65605
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Pick Done (nspRFOP01)"
      END
      /* Below Codes Commented by CY */
      /*
      ELSE IF @n_cnt > 1
      BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 65606
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Duplicate ShipLabel. (nspRFOP01)"
      END
      */
      /* Above Codes Commented by CY */
   END
   /* End Update table "PickDetail" */
   /* Set RF Return Record */
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
   /* End Set RF Return Record */
   /* Construct RF Return String */
   IF @n_continue=1 OR @n_continue=4
   BEGIN
      /* Construct A Reply 'OK' */
      SELECT @c_outstring =
      dbo.fnc_RTrim(@c_ptcid)     + @c_senddelimiter
      + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
      + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
      + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_errmsg)
      SELECT dbo.fnc_RTrim(@c_outstring)
   END
ELSE
   BEGIN
      /* Construct A Reply 'Err' */
      SELECT @c_outstring =
      dbo.fnc_RTrim(@c_ptcid)     + @c_senddelimiter
      + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
      + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
      + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
      + dbo.fnc_RTrim(@c_errmsg)
      SELECT dbo.fnc_RTrim(@c_outstring)
   END
   /* End Construct RF Return String */
   /* End Main Processing */
   /* Post Process Starts */
   /* #INCLUDE <SPRFOP01_2.SQL> */
   /* Post Process Ends */
   /* Return Statement */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFOP01"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END

GO