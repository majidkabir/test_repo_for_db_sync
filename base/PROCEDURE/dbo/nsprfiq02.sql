SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFIQ02                                          */
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

CREATE PROC    [dbo].[nspRFIQ02]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(5)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @n_action           int
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
   @b_debug int              -- Debug Flag
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   SELECT @b_debug = 0
   DECLARE @c_itrnkey NVARCHAR(10)
   /* #INCLUDE <SPRFIQ02_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
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
      IF @n_action = -1
      BEGIN
         FETCH PRIOR FROM CURSOR_INQUIRY
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
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFIQ02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            SELECT @n_err = @@FETCH_STATUS
            IF @n_err = -1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_retrec="02"
               SELECT @n_err = 66002
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFIQ02)"
            END
         ELSE IF @n_err = -2
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66003
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFIQ02)"
            END
         ELSE IF NOT @n_err = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66004
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFIQ02)"
            END
         END
      END
   ELSE IF @n_action = 0
      BEGIN
         FETCH RELATIVE 0 FROM CURSOR_INQUIRY
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
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFIQ02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            SELECT @n_err = @@FETCH_STATUS
            IF @n_err = -1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_retrec="02"
               SELECT @n_err = 66012
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFIQ02)"
            END
         ELSE IF @n_err = -2
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66013
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFIQ02)"
            END
         ELSE IF NOT @n_err = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66014
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFIQ02)"
            END
         END
      END
   ELSE IF @n_action = 1
      BEGIN
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
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66021   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspRFIQ02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            SELECT @n_err = @@FETCH_STATUS
            IF @n_err = -1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_retrec="02"
               SELECT @n_err = 66022
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": EOF. (nspRFIQ02)"
            END
         ELSE IF @n_err = -2
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66023
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Row Deleted By Other User. (nspRFIQ02)"
            END
         ELSE IF NOT @n_err = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 66024
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad @@FETCH_STATUS. (nspRFIQ02)"
            END
         END
      END
   ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 66000
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Action. (nspRFIQ02)"
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
   -- added by wally 16.oct.2001
   -- IDSHK sos 1967 : to fix blank UOM on RF inquiry screen
   select @inquiry_uom = (select packuom3
   from sku (nolock) join pack (nolock)
   on sku.packkey = pack.packkey
   where sku = @inquiry_sku)
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)  + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_StorerKey) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Lot) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Sku) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Id) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Loc) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_CaseId) + @c_senddelimiter
   + dbo.fnc_RTrim(CONVERT(char(10), @INQUIRY_Qty)) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_UOM) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_PackKey) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Lottable01) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Lottable02) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Lottable03) + @c_senddelimiter
   + dbo.fnc_RTrim(@CONVERT_Lottable04) + @c_senddelimiter
   + dbo.fnc_RTrim(@CONVERT_Lottable05) + @c_senddelimiter
   + dbo.fnc_RTrim(@INQUIRY_Status)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* #INCLUDE <SPRFIQ02_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFIQ02"
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