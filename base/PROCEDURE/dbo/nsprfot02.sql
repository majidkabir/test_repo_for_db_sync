SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFOT02                                          */
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

CREATE PROC    [dbo].[nspRFOT02]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_storerkey        NVARCHAR(15)
,              @c_prokey           NVARCHAR(10)
,              @c_sku              NVARCHAR(30)
,              @c_lottable01       NVARCHAR(18)
,              @c_lottable02       NVARCHAR(18)
,              @c_lottable03       NVARCHAR(18)
,              @d_lottable04       NVARCHAR(30)
,              @d_lottable05       NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_pokey            NVARCHAR(10)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_loc              NVARCHAR(10)
,              @c_id               NVARCHAR(18)
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
   DECLARE  @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   DECLARE @c_ioflag NVARCHAR(1), @c_iddetreq NVARCHAR(1),
   @c_LotxIdDetailOtherlabel1 NVARCHAR(10),
   @c_LotxIdDetailOtherlabel2 NVARCHAR(10),
   @c_LotxIdDetailOtherlabel3 NVARCHAR(10)
   SELECT @c_iddetreq = "0"
   /* #INCLUDE <SPRFOT02_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_catchweight NVARCHAR(1) -- Flag to see if catch weight processing is on
      SELECT @c_catchweight = IsNull(NSQLValue, "0")
      FROM NSQLCONFIG (NOLOCK)
      WHERE CONFIGKEY = "CATCHWEIGHT"
   END
   IF ( @n_continue=1 OR @n_continue=2 ) AND @c_catchweight = "1"
   BEGIN
      SELECT @c_ioflag =IOFLAG,
      @c_LotxIdDetailOtherlabel1 = LotxIdDetailOtherlabel1,
      @c_LotxIdDetailOtherlabel2 = LotxIdDetailOtherlabel2,
      @c_LotxIdDetailOtherlabel3 = LotxIdDetailOtherlabel3
      FROM SKU
      WHERE STORERKEY = @c_storerkey
      AND SKU = @c_sku
      IF @c_ioflag = "I" or @c_ioflag = "B"
      BEGIN
         SELECT @c_iddetreq = "1",
         @c_retrec = "01"
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lotxidDetailotherLabel1)) IS NULL
         BEGIN
            SELECT @c_lotxidDetailotherLabel1 = "Ser#"
         END
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lotxidDetailotherLabel2)) IS NULL
         BEGIN
            SELECT @c_lotxidDetailotherLabel2 = "CSID"
         END
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lotxidDetailotherLabel3)) IS NULL
         BEGIN
            SELECT @c_lotxidDetailotherLabel3 = "OTHER"
         END
         SELECT @c_errmsg = "Receipt Ok.  Please press ENTER and fill out the Serial#/Weight Information for this receipt.."
      END
   ELSE
      BEGIN
         SELECT @c_retrec = "02"
         SELECT @c_errmsg = "Receipt Ok.  Please press ENTER and fill out the additional information about this receipt."
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
      IF @c_retrec = "" or @c_retrec = "09"
      BEGIN
         SELECT @c_retrec="01"
      END
   END
   /* #INCLUDE <SPRFOT02_2.SQL> */
   SELECT @c_outstring =   @c_ptcid                  + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)                     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)                     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename)               + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)                    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)                     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)                     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_storerkey)                  + @c_senddelimiter
   + dbo.fnc_RTrim(@c_sku)                        + @c_senddelimiter
   + dbo.fnc_RTrim(@c_iddetreq)                   + @c_senddelimiter
   + dbo.fnc_RTrim(@c_LotxIdDetailOtherlabel1)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_LotxIdDetailOtherlabel2)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_LotxIdDetailOtherlabel3)    + @c_senddelimiter
   + dbo.fnc_RTrim("Weight")                      + @c_senddelimiter
   + dbo.fnc_RTrim(CONVERT(char(10),@n_qty))
   SELECT dbo.fnc_RTrim(@c_outstring)
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFOT02"
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