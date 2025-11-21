SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspExportAdj                                       */
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
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nspExportAdj]
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
      VALUES ( @c_hikey, ' -> nspExportAdj -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   -- Update TransmitFlag to 9 in case previous task was failed because of DeadLock
   -- Added By June
   -- Date: 14th Dec 2001
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPADJ
      WHERE TRansmitlog.Key1 = WMSEXPADJ.Adjustmentkey
      AND Transmitlog.Key2 = WMSEXPADJ.Adjustmentlinenumber
      AND Transmitlog.Tablename = 'ADJ'
      AND TRANSMITLOG.Transmitflag = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update Transmitlog table (nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END -- End

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO WMSEXPADJ
      SELECT  distinct Adjustment.Adjustmentkey,
            'CustomerRefNo' = ISNULL(Adjustment.CustomerRefNo,''),
            Adjustment.AdjustmentType,
            AdjustmentDETAIL.AdjustmentLineNumber,
            UPPER(AdjustmentDETAIL.SKU),
            L1.Lottable01,
            L1.Lottable02,
            L1.Lottable03,
            'Lottable04' = CASE L1.Lottable04 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable04,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable04,101) ), 4,2 )
                           END,
            'Lottable05' = CASE L1.Lottable05 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable05,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable05,101) ), 4,2 )
                           END,
            L1.Lottable06,
            L1.Lottable07,
            L1.Lottable08,
            L1.Lottable09,
            L1.Lottable10,
            L1.Lottable11,
            L1.Lottable12,
            'Lottable13' = CASE L1.Lottable13 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable13,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable13,101) ), 4,2 )
                           END,
            'Lottable14' = CASE L1.Lottable14 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable14,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable14,101) ), 4,2 )
                           END,
            'Lottable15' = CASE L1.Lottable15 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable15,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable15,101) ), 4,2 )
                           END,
            AdjustmentDETAIL.Qty,
            AdjustmentDETAIL.ReasonCode,
            LOC.HOSTWHCODE,
            'TRANSFLAG' = '0'
      FROM     Adjustment (nolock),
      AdjustmentDETAIL (nolock),
      TRANSMITLOG (nolock),
      LOC (NOLOCK),
      LOTATTRIBUTE L1 (nolock)
      WHERE    Adjustment.Adjustmentkey = AdjustmentDETAIL.Adjustmentkey
      AND      Adjustment.Adjustmentkey = TransmitLog.Key1
      AND      AdjustmentDETAIL.Loc = LOC.LOC
      AND      AdjustmentDETAIL.Adjustmentkey = TransmitLog.Key1
      AND      AdjustmentDETAIL.Adjustmentlinenumber = TransmitLog.Key2
      AND      L1.Lot = AdjustmentDetail.Lot
      AND      TransmitLog.Tablename = 'ADJ'
      AND      TransmitLog.TransmitFlag = '0'
      AND      ADJUSTMENTDETAIL.ID NOT IN ( SELECT ID FROM INVENTORYHOLD WHERE HOLD = "1" AND ID IS NOT NULL AND dbo.fnc_RTrim(ID) <> '')

      INSERT INTO WMSEXPADJ
      SELECT  distinct Adjustment.Adjustmentkey,
            'CustomerRefNo' = ISNULL(Adjustment.CustomerRefNo,''),
            Adjustment.AdjustmentType,
            AdjustmentDETAIL.AdjustmentLineNumber,
            UPPER(AdjustmentDETAIL.SKU),
            L1.Lottable01,
            L1.Lottable02,
            L1.Lottable03,
            'Lottable04' = CASE L1.Lottable04 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable04,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable04,101) ), 4,2 )
                           END,
            'Lottable05' = CASE L1.Lottable05 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable05,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable05,101) ), 4,2 )
                           END,
            L1.Lottable06,
            L1.Lottable07,
            L1.Lottable08,
            L1.Lottable09,
            L1.Lottable10,
            L1.Lottable11,
            L1.Lottable12,
            'Lottable13' = CASE L1.Lottable13 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable13 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable13,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable13,101) ), 4,2 )
                           END,
            'Lottable14' = CASE L1.Lottable14 WHEN NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable14 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable14,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable14,101) ), 4,2 )
                           END,
            'Lottable15' = CASE L1.Lottable15 WHEN  NULL
                              THEN '0'
                           ELSE substring((convert(char(10),L1.Lottable15 ,101) ), 7, 4) + substring((convert(char(10),L1.Lottable15,101) ), 1, 2)
                              + substring((convert(char(10),L1.Lottable15,101) ), 4,2 )
                           END,
            AdjustmentDETAIL.Qty,
            AdjustmentDETAIL.ReasonCode,
            'H' + dbo.fnc_RTrim(LOC.FACILITY),
            'TRANSFLAG' = '0'
      FROM  Adjustment (nolock),
      AdjustmentDETAIL (nolock),
      TRANSMITLOG (nolock),
      LOC (NOLOCK),
      LOTATTRIBUTE L1 (nolock)
      WHERE    Adjustment.Adjustmentkey = AdjustmentDETAIL.Adjustmentkey
      AND      Adjustment.Adjustmentkey = TransmitLog.Key1
      AND      AdjustmentDETAIL.Loc = LOC.LOC
      AND      AdjustmentDETAIL.Adjustmentkey = TransmitLog.Key1
      AND      AdjustmentDETAIL.Adjustmentlinenumber = TransmitLog.Key2
      AND      L1.Lot = AdjustmentDetail.Lot
      AND      TransmitLog.Tablename = 'ADJ'
      AND      TransmitLog.TransmitFlag = '0'
      AND      ADJUSTMENTDETAIL.ID IN ( SELECT ID FROM INVENTORYHOLD WHERE HOLD = "1" AND ID IS NOT NULL AND dbo.fnc_RTrim(ID) <> '' )

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Insert into WMSEXPADJ table (nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPADJ
      WHERE TRansmitlog.Key1 = WMSEXPADJ.Adjustmentkey
      AND Transmitlog.Key2 = WMSEXPADJ.Adjustmentlinenumber
      AND Transmitlog.Tablename = 'ADJ'
      AND TRANSMITLOG.Transmitflag = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update TransmitLog Table(nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportAdj -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportAdj ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportAdj)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportAdj"
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