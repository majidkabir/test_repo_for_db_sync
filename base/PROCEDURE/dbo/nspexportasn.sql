SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportASN                                       */
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

CREATE PROC [dbo].[nspExportASN]
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
       VALUES ( @c_hikey, ' -> nspExportASN -- The HI Run Identifer Is ' + @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
    END
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      -- Added By SHONG on 27-Feb-2007 (Start)
      IF OBJECT_ID('tempdb..#R') IS NOT NULL 
      BEGIN
         DROP TABLE #R 
      END 
      
      CREATE TABLE #R
         ( ReceiptKey NVARCHAR(10), ReceiptLineNumber NVARCHAR(5) )

      INSERT INTO #R ( ReceiptKey, ReceiptLineNumber)
      SELECT DISTINCT RECEIPT.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber  
       FROM     RECEIPT (nolock),
                RECEIPTDETAIL (nolock),
                TRANSMITLOG (nolock),
                LOC (NOLOCK)
       WHERE    RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
       AND      RECEIPT.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.ToLoc = LOC.LOC
       AND      RECEIPTDETAIL.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.Receiptlinenumber = TransmitLog.Key2
       AND      RECEIPTDETAIL.ToId NOT IN (SELECT ID FROM InventoryHold WHERE Hold = "1" AND ( dbo.fnc_RTrim(ID) <> '' AND ID IS NOT NULL) )
       AND      TransmitLog.Tablename = 'RECEIPT'
       AND      TransmitLog.TransmitFlag = '0' 
       UNION 
       SELECT DISTINCT RECEIPT.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber    
       FROM     RECEIPT (nolock),
                RECEIPTDETAIL (nolock),
                TRANSMITLOG (nolock),
                LOC (NOLOCK)
       WHERE    RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
       AND      RECEIPT.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.ToLoc = LOC.LOC
       AND      RECEIPTDETAIL.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.Receiptlinenumber = TransmitLog.Key2
       AND      RECEIPTDETAIL.ToId IN (SELECT ID FROM InventoryHold WHERE Hold = "1" AND dbo.fnc_RTrim(ID) <> '' AND ID IS NOT NULL )
       AND      TransmitLog.Tablename = 'RECEIPT'
       AND      TransmitLog.TransmitFlag = '0'
                
      DELETE WMSEXPASN 
      FROM   WMSEXPASN A
      JOIN   #R B ON A.ReceiptKey = B.ReceiptKey AND A.ReceiptLineNumber = B.ReceiptLineNumber 

      -- Added By SHONG on 27-Feb-2007 (End)

       -- select into a temp table.
       INSERT INTO WMSEXPASN
       SELECT  distinct RECEIPT.Receiptkey,
                RECEIPT.ExternReceiptkey, 
                RECEIPTDETAIL.ExternLineNo,
                RECEIPTDETAIL.ReceiptLineNumber,
                'WarehouseReference' = ISNULL(RECEIPT.WarehouseReference, ''),
                'ContainerKey' = ISNULL (Receipt.Containerkey, '' ),
                UPPER(RECEIPTDETAIL.SKU),
                RECEIPTDETAIL.QtyExpected,
                RECEIPTDETAIL.QtyAdjusted,
                RECEIPTDETAIL.QtyReceived,
                RECEIPTDETAIL.Lottable01,
                RECEIPTDETAIL.Lottable02,
                RECEIPTDETAIL.Lottable03,
                'Lottable04' = CASE RECEIPTDETAIL.Lottable04 WHEN NULL
                               THEN '0'
                               ELSE substring((convert(char(10),RECEIPTDETAIL.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),RECEIPTDETAIL.Lottable04,101) ), 1, 2)
                               + substring((convert(char(10),RECEIPTDETAIL.Lottable04,101) ), 4,2 )
                               END,
                'Lottable05' = CASE RECEIPTDETAIL.Lottable05 WHEN  NULL 
                               THEN '0'
                               ELSE substring((convert(char(10),RECEIPTDETAIL.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),RECEIPTDETAIL.Lottable05,101) ), 1, 2)
                                    + substring((convert(char(10),RECEIPTDETAIL.Lottable05,101) ), 4,2 ) 
                               END,
                RECEIPT.Rectype,
                LOC.HOSTWHCODE,
                RECEIPT.ASNREASON,
                RECEIPTDETAIL.SubReasonCode,
                'TRANSFLAG' = '0'
       FROM     RECEIPT (nolock),
                RECEIPTDETAIL (nolock),
                TRANSMITLOG (nolock),
                LOC (NOLOCK)
       WHERE    RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
       AND      RECEIPT.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.ToLoc = LOC.LOC
       AND      RECEIPTDETAIL.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.Receiptlinenumber = TransmitLog.Key2
       AND      RECEIPTDETAIL.ToId NOT IN (SELECT ID FROM InventoryHold WHERE Hold = "1" AND ( dbo.fnc_RTrim(ID) <> '' AND ID IS NOT NULL) )
       AND      TransmitLog.Tablename = 'RECEIPT'
       AND      TransmitLog.TransmitFlag = '0'
--       INSERT INTO WMSEXPASN
		 UNION			-- ONG01 - to avoid insert duplicate records. 
       SELECT  distinct RECEIPT.Receiptkey,
                RECEIPT.ExternReceiptkey, 
                RECEIPTDETAIL.ExternLineNo,
                RECEIPTDETAIL.ReceiptLineNumber,
                'WarehouseReference' = ISNULL(RECEIPT.WarehouseReference, ''),
                'ContainerKey' = ISNULL (Receipt.Containerkey, '' ),
                UPPER(RECEIPTDETAIL.SKU),
                RECEIPTDETAIL.QtyExpected,
                RECEIPTDETAIL.QtyAdjusted,
                RECEIPTDETAIL.QtyReceived,
                RECEIPTDETAIL.Lottable01,
                RECEIPTDETAIL.Lottable02,
                RECEIPTDETAIL.Lottable03,
                'Lottable04' = CASE RECEIPTDETAIL.Lottable04 WHEN NULL
                               THEN '0'
                               ELSE substring((convert(char(10),RECEIPTDETAIL.Lottable04 ,101) ), 7, 4) + substring((convert(char(10),RECEIPTDETAIL.Lottable04,101) ), 1, 2)
                               + substring((convert(char(10),RECEIPTDETAIL.Lottable04,101) ), 4,2 )
                               END,
                'Lottable05' = CASE RECEIPTDETAIL.Lottable05 WHEN  NULL 
                               THEN '0'
                               ELSE substring((convert(char(10),RECEIPTDETAIL.Lottable05 ,101) ), 7, 4) + substring((convert(char(10),RECEIPTDETAIL.Lottable05,101) ), 1, 2)
                                    + substring((convert(char(10),RECEIPTDETAIL.Lottable05,101) ), 4,2 ) 
                               END,
                RECEIPT.Rectype,
                'H' + dbo.fnc_RTrim(LOC.Facility),
                RECEIPT.ASNREASON,
                RECEIPTDETAIL.SubReasonCode,
                'TRANSFLAG' = '0'
       FROM     RECEIPT (nolock),
                RECEIPTDETAIL (nolock),
                TRANSMITLOG (nolock),
                LOC (NOLOCK)
       WHERE    RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
       AND      RECEIPT.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.ToLoc = LOC.LOC
       AND      RECEIPTDETAIL.Receiptkey = TransmitLog.Key1
       AND      RECEIPTDETAIL.Receiptlinenumber = TransmitLog.Key2
       AND      RECEIPTDETAIL.ToId IN (SELECT ID FROM InventoryHold WHERE Hold = "1" AND dbo.fnc_RTrim(ID) <> '' AND ID IS NOT NULL )
       AND      TransmitLog.Tablename = 'RECEIPT'
       AND      TransmitLog.TransmitFlag = '0'
		 ORDER BY RECEIPT.Receiptkey,  RECEIPTDETAIL.ReceiptLineNumber		-- ONG01


       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Insert into WMSEXPASN Table(nspExportASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE TRANSMITLOG
      SET TRANSMITLOG.Transmitflag = '9'
      FROM Transmitlog, WMSEXPASN
      WHERE TRansmitlog.Key1 = WMSEXPASN.Receiptkey
      AND Transmitlog.Key2 = WMSEXPASN.Receiptlinenumber
      AND Transmitlog.Tablename = 'RECEIPT'
      AND TRANSMITLOG.Transmitflag = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Update TransmitLog Table(nspExportASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportASN -- Export Process For ' + @c_hikey + ' ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 3
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspExportASN ERROR -- Export Process for ' + @c_hikey + ' Ended at ' + convert (char(20), getdate()) , 'GENERAL', ' ')
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On HIERROR. (nspExportASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
      execute nsp_logerror @n_err, @c_errmsg, "nspExportASN"
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
    --
    /*
    drop table wmsexpasn
    - once inserted into wmsexpasn, update the transmitflag = '4' -- to indicate it has been exported to a temp table waiting
      for ILS to grab the data. 
    - Once ILS grab data, need to send back the confirmation (Receiptkey, Receiptlinenumber)
    - a separate procedure will run independantly to grab the receiptkey & receiptlinenumber where status <> '9' and update the tables transmitlog
      and transflag (temptable) to '9', indicating the records has been received by ILS
    create a table
    Confirmation.
    Trantype NVARCHAR(10),
    Key1 NVARCHAR(10),
    key2 NVARCHAR(5),
    key3 NVARCHAR(20),
    Status NVARCHAR(1)
    key1 - for keys like receiptkey, orderkey, etc
    key2 - for linenumbers like receiptlinenumber,
    key3 - can be used for keys like ITRNKEY,
    status is used to confirm that the keys have been updated in WMS
    this table is used by ILS to update WMS on the keys that has been updated in their system
    */
END -- end of procedure

GO