SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFQC01                                          */
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
/* 16-Dec-2018  TLTING01  1.1 Missing NOLOCK                            */
/************************************************************************/

CREATE PROC    [dbo].[nspRFQC01]
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
 ,              @c_fromloc          NVARCHAR(18)
 ,              @c_toloc            NVARCHAR(18)
 ,              @c_status           NVARCHAR(10)
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
    SET ANSI_NULLS OFF
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
      /* #INCLUDE <SPRFQC01_1.SQL> */     
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL -- A blank sku is legal for moves since it could be a full pallet move.
 BEGIN
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
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NOT NULL
 BEGIN
 IF NOT EXISTS(SELECT loc FROM LOC (NOLOCK) WHERE
 Loc = @c_fromloc)
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=65501
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad From Location (nspRFQC01)"
 END
 END
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toloc)) IS NOT NULL
 BEGIN
 IF NOT EXISTS(SELECT loc FROM LOC WHERE
 Loc = @c_toloc)
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=65502
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad To Location (nspRFQC01)"
 END
 END
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
 BEGIN
 IF NOT EXISTS(SELECT lot FROM LOT (NOLOCK) WHERE
 Lot = @c_lot)
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=65503
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Lot (nspRFQC01)"
 END
 END
 END
 IF @n_continue=1 OR @n_continue=2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_status)) IS NOT NULL
 BEGIN
 IF NOT EXISTS(SELECT code FROM codelkup (NOLOCK) WHERE
 LISTNAME="INVHOLD" and code = @c_status)
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=65504
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Status (nspRFQC01)"
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
 BEGIN TRAN
 EXECUTE nspItrnAddMove
 @n_ItrnSysId    = NULL,
 @c_itrnkey      = NULL,
 @c_StorerKey    = @c_storerkey,
 @c_Sku          = @c_sku,
 @c_Lot          = @c_lot,
 @c_FromLoc      = @c_fromloc,
 @c_FromID       = @c_id,
 @c_ToLoc        = @c_toloc,
 @c_ToID         = @c_id,
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
 @c_SourceKey    = @c_taskid,
 @c_SourceType   = "nspRFQC01",
 @c_PackKey      = @c_packkey,
 @c_UOM          = @c_uom,
 @b_UOMCalc      = 1,
 @d_EffectiveDate = NULL,
 @b_Success      = @b_Success  OUTPUT,
 @n_err          = @n_err      OUTPUT,
 @c_errmsg       = @c_errmsg   OUTPUT
 IF NOT @b_success=1
 BEGIN
 SELECT @n_continue = 3
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_status)) IS NOT NULL
 AND @c_status <> "OK"
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NOT NULL
 BEGIN
 EXECUTE nspInventoryHold
 ""
 , ""
 , @c_id
 , @c_status
 , "1"
 , @b_Success OUTPUT
 , @n_err OUTPUT
 , @c_errmsg OUTPUT
 IF @b_success <> 1
 BEGIN
 SELECT @n_continue=3
 END
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_status)) IS NOT NULL
 AND @c_status <> "OK"
 BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
 BEGIN
 EXECUTE nspInventoryHold
 @c_lot
 , ""
 , ""
 , @c_status
 , "1"
 , @b_Success OUTPUT
 , @n_err OUTPUT
 , @c_errmsg OUTPUT
 IF @b_success <> 1
 BEGIN
 SELECT @n_continue=3
 END
 END
 END
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 COMMIT TRAN
 END
 ELSE
 BEGIN
 ROLLBACK TRAN
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
 IF @n_continue=1 OR @n_continue=4
 BEGIN
 SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
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
 SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
 + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
 + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
 + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_errmsg)
 SELECT dbo.fnc_RTrim(@c_outstring)
 END
      /* #INCLUDE <SPRFQC01_2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "nspRFQC01"
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