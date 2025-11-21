SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspExportKit                                       */
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
/* Date         Author  Ver   Purposes                                  */
/* 03-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nspExportKit]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int,
            @n_starttcnt      int,              -- Holds the current transaction count
            @n_cnt            int,              -- Holds @@ROWCOUNT after certain operations
            @c_preprocess     NVARCHAR(250) ,   -- preprocess
            @c_pstprocess     NVARCHAR(250) ,   -- post process
            @n_err2           int,              -- For Additional Error Detection
            @b_debug          int,              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
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
      VALUES ( @c_hikey, ' -> nspExportKit -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPKIT
      WHERE Transmitlog.Key1 = WMSEXPKIT.KitKey
      AND Transmitlog.Key2   = WMSEXPKIT.KitLineNumber
      AND Transmitlog.Key3   = WMSEXPKIT.Type
      AND Transmitlog.Tablename = 'Kitting'
      AND TRANSMITLOG.Transmitflag = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update TransmitLog Table(nspExportKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO WMSEXPKIT
      SELECT DISTINCT KIT.Kitkey,
            KitDetail.KitLineNumber,
            KitDetail.Type,
            ISNULL (KIT.CustomerRefNo, ' ' ),
            ISNULL (KIT.ReasonCode, ' '),
            UPPER(KitDetail.SKU),
            ISNULL (KitDetail.Lottable01, ' '),
            ISNULL (KitDetail.Lottable02, ' '),
            ISNULL (KitDetail.Lottable03, ' '),
            CASE KitDetail.Lottable04 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable04,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable04,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable05 WHEN  NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable05,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable05,101) ), 4,2 )
            END,
            ISNULL (KitDetail.Lottable06, ' '),
            ISNULL (KitDetail.Lottable07, ' '),
            ISNULL (KitDetail.Lottable08, ' '),
            ISNULL (KitDetail.Lottable09, ' '),
            ISNULL (KitDetail.Lottable10, ' '),
            ISNULL (KitDetail.Lottable11, ' '),
            ISNULL (KitDetail.Lottable12, ' '),
            CASE KitDetail.Lottable13 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable13,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable13,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable14 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable14,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable14,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable15 WHEN  NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable15,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable15,101) ), 4,2 )
            END,
            KitDetail.Qty,
            LF.HostWhCode,
            'TRANSFLAG' = '0'
      FROM     KIT (nolock),
      KitDetail (nolock),
      TRANSMITLOG (nolock),
      LOC LF(NOLOCK)
      WHERE    KIT.KitKey = KitDetail.KitKey
      AND      KIT.KitKey = TransmitLog.Key1
      AND      KIT.KitKey = KitDetail.KitKey
      AND      KitDetail.KitLineNumber = TransmitLog.Key2
      AND      KitDetail.Type = Transmitlog.Key3
      AND      TransmitLog.Tablename = 'Kitting'
      AND      TransmitLog.TransmitFlag = '0'
      AND      LF.Loc = KitDetail.Loc
      AND      KITDetail.ID NOT IN ( SELECT ID FROM INVENTORYHOLD (NOLOCK) WHERE HOLD='1' AND ID IS NOT NULL AND dbo.fnc_RTrim(ID) <> '')


      INSERT INTO WMSEXPKIT
      SELECT DISTINCT KIT.Kitkey,
            KitDetail.KitLineNumber,
            KitDetail.Type,
            ISNULL (KIT.CustomerRefNo, ' ' ),
            ISNULL (KIT.ReasonCode, ' '),
            UPPER(KitDetail.SKU),
            ISNULL (KitDetail.Lottable01, ' '),
            ISNULL (KitDetail.Lottable02, ' '),
            ISNULL (KitDetail.Lottable03, ' '),
            CASE KitDetail.Lottable04 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable04,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable04,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable05 WHEN  NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable05,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable05,101) ), 4,2 )
            END,
            ISNULL (KitDetail.Lottable06, ' '),
            ISNULL (KitDetail.Lottable07, ' '),
            ISNULL (KitDetail.Lottable08, ' '),
            ISNULL (KitDetail.Lottable09, ' '),
            ISNULL (KitDetail.Lottable10, ' '),
            ISNULL (KitDetail.Lottable11, ' '),
            ISNULL (KitDetail.Lottable12, ' '),
            CASE KitDetail.Lottable13 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable13,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable13,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable14 WHEN NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable14,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable14,101) ), 4,2 )
            END,
            CASE KitDetail.Lottable15 WHEN  NULL
               THEN '0'
            ELSE substring((convert(char(10),KitDetail.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),KitDetail.Lottable15,101) ), 1, 2)
               + substring((convert(char(10),KitDetail.Lottable15,101) ), 4,2 )
            END,
            KitDetail.Qty,
            'H' + dbo.fnc_RTrim(LF.Facility),
            'TRANSFLAG' = '0'
      FROM     KIT (nolock),
      KitDetail (nolock),
      TRANSMITLOG (nolock),
      LOC LF(NOLOCK)
      WHERE    KIT.KitKey = KitDetail.KitKey
      AND      KIT.KitKey = TransmitLog.Key1
      AND      KIT.KitKey = KitDetail.KitKey
      AND      KitDetail.KitLineNumber = TransmitLog.Key2
      AND      KitDetail.Type = Transmitlog.Key3
      AND      TransmitLog.Tablename = 'Kitting'
      AND      TransmitLog.TransmitFlag = '0'
      AND      LF.Loc = KitDetail.Loc
      AND      KITDetail.ID IN ( SELECT ID FROM INVENTORYHOLD (NOLOCK) WHERE HOLD='1' AND ID IS NOT NULL AND dbo.fnc_RTrim(ID) <> '')
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPKIT
      WHERE Transmitlog.Key1 = WMSEXPKIT.KitKey
      AND Transmitlog.Key2   = WMSEXPKIT.KitLineNumber
      AND Transmitlog.Key3   = WMSEXPKIT.Type
      AND Transmitlog.Tablename = 'Kitting'
      AND TRANSMITLOG.Transmitflag = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update TransmitLog Table(nspExportKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportKit -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportKit ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportKit)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportKit"
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