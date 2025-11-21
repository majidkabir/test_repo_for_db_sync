SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspExportInvHold                                   */
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
/* Date         Author  Ver   Purposes                                  */
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nspExportInvHold]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int,
            @n_starttcnt      int,                 -- Holds the current transaction count
            @n_cnt            int,                 -- Holds @@ROWCOUNT after certain operations
            @c_preprocess     NVARCHAR(250) ,      -- preprocess
            @c_pstprocess     NVARCHAR(250) ,      -- post process
            @n_err2           int,                 -- For Additional Error Detection
            @b_debug          int,                 -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
            @b_success        int,
            @n_err            int,
            @c_errmsg         NVARCHAR(250),
            @errorcount       int,
            @c_hikey          NVARCHAR(10)

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
            @b_success       OUTPUT,
            @n_err           OUTPUT,
            @c_errmsg        OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportINVHOLD -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportINVHOLD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_Continue = 2
   BEGIN
      -- start exporting the records here, into a temp table so that AS/400 can pick it up via DTS
      -- check against the transmitlog table.
      INSERT INTO WMSEXPINVHOLD
      SELECT DISTINCT T1.Transmitlogkey,
            A1.ID,
            L1.Loc,
            'FromWhCode' = L1.HOSTWHCODE,
            'TOWhCode' = 'H'+ L1.Facility,
            B2.Lottable01,
            B2.Lottable02,
            B2.Lottable03,
            'Lottable04' = CASE B2.Lottable04 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable04,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable04,101) ), 4,2 )
                           END,
            'Lottable05' = CASE B2.Lottable05 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable05,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable05,101) ), 4,2 )
                           END,
            B2.Lottable06,
            B2.Lottable07,
            B2.Lottable08,
            B2.Lottable09,
            B2.Lottable10,
            B2.Lottable11,
            B2.Lottable12,
            'Lottable13' = CASE B2.Lottable13 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable13,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable13,101) ), 4,2 )
                           END,
            'Lottable14' = CASE B2.Lottable14 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable14,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable14,101) ), 4,2 )
                           END,
            'Lottable15' = CASE B2.Lottable15 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable15,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable15,101) ), 4,2 )
                           END,
            UPPER(B1.Sku),
            B1.Qty,
            'Transflag' = '0'
      FROM transmitlog T1, ID A1, Loc L1, LOTXLOCXID B1, LOTATTRIBUTE B2
      WHERE T1.Key1 = A1.ID
      AND A1.ID = B1.ID
      AND B1.Loc = L1.Loc
      AND B2.Lot = B1.Lot
      and B1.qty > 0
      AND T1.Key3 = 'HOLD'
      AND T1.Transmitflag = '0'
      AND T1.Tablename = 'InventoryHold'

      UNION

      SELECT DISTINCT T1.Transmitlogkey,
            A1.ID,
            L1.Loc,
            'FromWhCode' = 'H' + L1.Facility,
            'TOWhCode' = L1.HOSTWHCODE,
            B2.Lottable01,
            B2.Lottable02,
            B2.Lottable03,
            'Lottable04' = CASE B2.Lottable04 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable04,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable04,101) ), 4,2 )
                           END,
            'Lottable05' = CASE B2.Lottable05 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable05,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable05,101) ), 4,2 )
                           END,
            B2.Lottable06,
            B2.Lottable07,
            B2.Lottable08,
            B2.Lottable09,
            B2.Lottable10,
            B2.Lottable11,
            B2.Lottable12,
            'Lottable13' = CASE B2.Lottable13 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable13,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable13,101) ), 4,2 )
                           END,
            'Lottable14' = CASE B2.Lottable14 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable14,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable14,101) ), 4,2 )
                           END,
            'Lottable15' = CASE B2.Lottable15 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),B2.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),B2.Lottable15,101) ), 1, 2)
                              + substring((convert(char(10),B2.Lottable15,101) ), 4,2 )
                           END,
            UPPER(B1.Sku),
            B1.Qty,
            'Transflag' = '0'
      FROM transmitlog T1, ID A1, Loc L1, LOTXLOCXID B1, LOTATTRIBUTE B2
      WHERE T1.Key1 = A1.ID
      AND A1.ID = B1.ID
      AND B1.Loc = L1.Loc
      AND B2.Lot = B1.Lot
      and B1.qty > 0
      AND T1.Key3 = 'RELEASE'
      AND T1.Transmitflag = '0'
      AND T1.Tablename = 'InventoryHold'
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPINVHOLD
      WHERE TRansmitlog.Key1 = WMSEXPINVHOLD.InventoryHoldkey
      AND TransmitLog.Transmitlogkey = WMSEXPINVHOLD.Transmitlogkey
      AND Transmitlog.Tablename = 'InventoryHold'
      AND TRANSMITLOG.Transmitflag = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update Transmitlog table (nspExportINVHOLD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportINVHOLD -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportINVHOLD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportINVHOLD ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportINVHOLD)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportINVHOLD"
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
END -- End of Procedure


GO