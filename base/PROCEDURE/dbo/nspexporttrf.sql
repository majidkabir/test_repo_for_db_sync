SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspExportTrf                                       */
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
/* Date         Author    Ver   Purposes                                */
/* 02-Jun-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROC [dbo].[nspExportTrf]
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue    int,
            @n_starttcnt   int,              -- Holds the current transaction count
            @n_cnt         int,              -- Holds @@ROWCOUNT after certain operations
            @c_preprocess  NVARCHAR(250) ,   -- preprocess
            @c_pstprocess  NVARCHAR(250) ,   -- post process
            @n_err2        int,              -- For Additional Error Detection
            @b_debug       int,              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
            @b_success     int,
            @n_err         int,
            @c_errmsg      NVARCHAR(250),
            @errorcount    int,
            @c_hikey       NVARCHAR(10)

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
      VALUES ( @c_hikey, ' -> nspExportTrf -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportTrf)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO WMSEXPTRF
      SELECT distinct Transfer.Transferkey,
            Transfer.ReasonCode,
            'CustomerRefNo' = ISNULL (Transfer.CustomerRefNo, ' ' ),
            TransferDETAIL.TransferLineNumber,
            'FROMSKU' = TransferDETAIL.FROMSKU,
            'FROMQty' = TransferDETAIL.FromQty,
            'FROMWHCODE' = LF.HostWhCode,
            'FROMLottable01' = Transferdetail.Lottable01,
            'FROMLottable02' = TransferDetail.Lottable02,
            'FromLottable03' = TransferDetail.Lottable03,
            'FROMLottable04' =   CASE Transferdetail.Lottable04 WHEN NULL
                                    THEN '0'
                                 ELSE substring((convert(char(10),Transferdetail.Lottable04,101) ), 7, 4) + substring((convert(char(10),Transferdetail.Lottable04,101) ), 1, 2)
                                    + substring((convert(char(10),Transferdetail.Lottable04,101) ), 4,2 )
                                 END,
            'FromLottable05' =   CASE Transferdetail.Lottable05 WHEN  NULL
                                    THEN '0'
                                 ELSE substring((convert(char(10),Transferdetail.Lottable05,101) ), 7, 4) + substring((convert(char(10),Transferdetail.Lottable05,101) ), 1, 2)
                                    + substring((convert(char(10),Transferdetail.Lottable05,101) ), 4,2 )
                                 END,
            'FROMLottable06' = Transferdetail.Lottable06,
            'FROMLottable07' = TransferDetail.Lottable07,
            'FromLottable08' = TransferDetail.Lottable08,
            'FROMLottable09' = Transferdetail.Lottable09,
            'FROMLottable10' = TransferDetail.Lottable10,
            'FromLottable11' = TransferDetail.Lottable11,
            'FROMLottable12' = Transferdetail.Lottable12,
            'FROMLottable13' =   CASE Transferdetail.Lottable13 WHEN NULL
                                    THEN '0'
                                 ELSE substring((convert(char(10),Transferdetail.Lottable13,101) ), 7, 4) + substring((convert(char(10),Transferdetail.Lottable13,101) ), 1, 2)
                                    + substring((convert(char(10),Transferdetail.Lottable13,101) ), 4,2 )
                                 END,
            'FROMLottable14' =   CASE Transferdetail.Lottable14 WHEN NULL
                                    THEN '0'
                                 ELSE substring((convert(char(10),Transferdetail.Lottable14,101) ), 7, 4) + substring((convert(char(10),Transferdetail.Lottable14,101) ), 1, 2)
                                    + substring((convert(char(10),Transferdetail.Lottable14,101) ), 4,2 )
                                 END,
            'FromLottable15' =   CASE Transferdetail.Lottable15 WHEN  NULL
                                    THEN '0'
                                 ELSE substring((convert(char(10),Transferdetail.Lottable15,101) ), 7, 4) + substring((convert(char(10),Transferdetail.Lottable15,101) ), 1, 2)
                                    + substring((convert(char(10),Transferdetail.Lottable15,101) ), 4,2 )
                                 END,
            'TOSKU' = TransferDetail.ToSKU,
            'TOQty' = TransferDetail.ToQty,
            'TOWHCODE' = LT.HostWhCode,
            'ToLottable01' = TransferDetail.ToLottable01,
            'ToLottable02' = TransferDetail.ToLottable02,
            'ToLottable03' = TransferDetail.ToLottable03,
            'ToLottable04' =  CASE Transferdetail.ToLottable04 WHEN NULL
                                 THEN '0'
                              ELSE substring((convert(char(10),Transferdetail.ToLottable04 ,101) ), 7, 4) + substring((convert(char(10),Transferdetail.ToLottable04,101) ), 1, 2)
                                 + substring((convert(char(10),Transferdetail.ToLottable04,101) ), 4,2 )
                              END,
            'ToLottable05' =  CASE Transferdetail.ToLottable05 WHEN NULL
                                 THEN '0'
                              ELSE substring((convert(char(10),Transferdetail.ToLottable05,101) ), 7, 4) + substring((convert(char(10),Transferdetail.ToLottable05,101) ), 1, 2)
                                 + substring((convert(char(10),Transferdetail.ToLottable05,101) ), 4,2 )
                              END,

            'ToLottable06' = Transferdetail.ToLottable06,
            'ToLottable07' = TransferDetail.ToLottable07,
            'ToLottable08' = TransferDetail.ToLottable08,
            'ToLottable09' = Transferdetail.ToLottable09,
            'ToLottable10' = TransferDetail.ToLottable10,
            'ToLottable11' = TransferDetail.ToLottable11,
            'ToLottable12' = Transferdetail.ToLottable12,
            'ToLottable13' =  CASE Transferdetail.ToLottable13 WHEN NULL
                                 THEN '0'
                              ELSE substring((convert(char(10),Transferdetail.ToLottable13,101) ), 7, 4) + substring((convert(char(10),Transferdetail.ToLottable13,101) ), 1, 2)
                                 + substring((convert(char(10),Transferdetail.ToLottable13,101) ), 4,2 )
                              END,
            'ToLottable14' =  CASE Transferdetail.Lottable14 WHEN NULL
                                 THEN '0'
                              ELSE substring((convert(char(10),Transferdetail.ToLottable14,101) ), 7, 4) + substring((convert(char(10),Transferdetail.ToLottable14,101) ), 1, 2)
                                 + substring((convert(char(10),Transferdetail.ToLottable14,101) ), 4,2 )
                              END,
            'ToLottable15' =  CASE Transferdetail.Lottable15 WHEN  NULL
                                 THEN '0'
                              ELSE substring((convert(char(10),Transferdetail.ToLottable15,101) ), 7, 4) + substring((convert(char(10),Transferdetail.ToLottable15,101) ), 1, 2)
                                 + substring((convert(char(10),Transferdetail.ToLottable15,101) ), 4,2 )
                              END,
            'TRANSFLAG' = '0'
      --  INTO WMSEXPTRF
      FROM     TRANSFER (nolock),
      TransferDETAIL (nolock),
      TRANSMITLOG (nolock),
      LOC LT(NOLOCK),
      LOC LF (Nolock)
      WHERE    Transfer.Transferkey = TransferDETAIL.Transferkey
      AND      Transfer.Transferkey = TransmitLog.Key1
      AND      TransferDETAIL.Transferkey = TransmitLog.Key1
      AND      TransferDETAIL.Transferlinenumber = TransmitLog.Key2
      AND      TransmitLog.Tablename = 'Trf'
      AND      TransmitLog.TransmitFlag = '0'
      AND      LF.Loc = TransferDetail.FromLoc
      AND      LT.Loc = TransferDetail.ToLoc
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPTrf
      WHERE TRansmitlog.Key1 = WMSEXPTrf.Transferkey
      AND Transmitlog.Key2 = WMSEXPTrf.Transferlinenumber
      AND Transmitlog.Tablename = 'Trf'
      AND TRANSMITLOG.Transmitflag = '0'

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update TransmitLog Table(nspExportTrf)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportTrf -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportTrf)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportTrf ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportTrf)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportTrf"
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