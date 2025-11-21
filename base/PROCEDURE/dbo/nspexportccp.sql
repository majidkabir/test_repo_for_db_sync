SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportccp                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspExportccp]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt   int      , -- Holds the current transaction count
   @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int            ,  -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
   @b_success int         ,
   @n_err   int        ,
   @c_errmsg NVARCHAR(250),
   @errorcount int,
   @c_hikey NVARCHAR(10)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
   SELECT @b_debug = 0
   -- get the hikey,
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspg_GetKey
      "hirun",
      10,
      @c_hikey OUTPUT,
      @b_success   	 OUTPUT,
      @n_err       	 OUTPUT,
      @c_errmsg    	 OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportSOH -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportSOH)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Insert Unhold Quantity to ILS
      INSERT INTO idsccp
      SELECT ccdetail.cckey,
      UPPER(ccdetail.Sku),
      UPPER(ccdetail.LOC),
      'Qty' = (ccdetail.Qty),
      'Lottable04' = CASE ccdetail.Lottable04 WHEN NULL
      THEN '0'
   ELSE substring((convert(char(10),ccdetail.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),ccdetail.Lottable04,101) ), 1, 2)
      + substring((convert(char(10),ccdetail.Lottable04,101) ), 4,2 )
   END,
   LOC.HostWhCode
   FROM  ccdetail (nolock), LOC (nolock)
   WHERE ccdetail.cckey = 'NZM0312'
   AND ccdetail.loc = loc.loc
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Insert into WMSEXPADJ table (nspExportSOH)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END
/* temporary measure */
/* INSERT INTO WMSEXPSOHBK */
/* SELECT * FROM WMSEXPSOH */
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
   VALUES ( @c_hikey, ' -> nspExportSOH -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportSOH)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END
IF @n_continue = 3
BEGIN
   INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
   VALUES ( @c_hikey, ' -> nspExportSOH ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportSOH)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END
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
   execute nsp_logerror @n_err, @c_errmsg, "nspExportSOH"
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
END -- end of procedure


GO