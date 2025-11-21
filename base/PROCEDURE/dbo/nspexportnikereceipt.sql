SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportNIKEReceipt                               */
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

CREATE PROC [dbo].[nspExportNIKEReceipt] (   @c_recordtype NVARCHAR(1),
@c_processtype NVARCHAR(1))
AS
BEGIN -- Begin procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug int

   SELECT @b_debug = 0
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @n_err int,
   @c_errmsg NVARCHAR(250),
   @b_success int
   DECLARE @yymm_date NVARCHAR(4), @c_receiptkey NVARCHAR(10), @c_lottable02 NVARCHAR(10), @c_seqno NVARCHAR(3)
   /* #INCLUDE <SPBMLD1.SQL> */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
   SELECT @b_debug = 0
   CREATE TABLE #OUTPUT01 (RECEIPTkey NVARCHAR(10) NULL,
   RECEIPTLINENUMBER NVARCHAR(5) NULL,
   TransID NVARCHAR(11) NULL,
   IssueNo NVARCHAR(2) NULL,
   TransDate NVARCHAR(12) NULL,
   RefNo NVARCHAR(21) NULL,
   CustRef NVARCHAR(6) NULL,
   RefCode NVARCHAR(3) NULL,
   ReasonCode NVARCHAR(31) NULL,
   Container NVARCHAR(31) NULL,
   PONo NVARCHAR(21) NULL,
   POType NVARCHAR(4) NULL,
   GLAccount NVARCHAR(56) NULL,
   POID NVARCHAR(9) NULL ,
   GPC NVARCHAR(4) NULL,
   Style NVARCHAR(7) NULL,
   Color NVARCHAR(4) NULL,
   Dimension NVARCHAR(3) NULL,
   Quality NVARCHAR(3) NULL,
   UOM NVARCHAR(3) NULL,
   Sizes NVARCHAR(6) NULL,
   Subinvcode NVARCHAR(11) NULL,
   ReceivedQty NVARCHAR(11) NULL)
   Create table #Process01 ( SeqNo NVARCHAR(3) NULL,
   Receiptkey NVARCHAR(10) NULL,
   RECEIPTLineNumber NVARCHAR(5) NULL,
   Lottable02 NVARCHAR(8) NULL )
   /*
   CREATE TABLE #PROCESS02 (SeqNo int identity (1,1),
   Receiptkey NVARCHAR(10) NULL,
   Lottable02 NVARCHAR(8) NULL )
   */
   -- Select out the candidate records to be exported.
   SET ROWCOUNT 1
   SELECT @c_receiptkey = receipt.receiptkey
   FROM RECEIPTDETAIL (NOLOCK), TRANSMITLOG (NOLOCK), RECEIPT (NOLOCK)
   WHERE RECEIPTDETAIL.Receiptkey = TRANSMITLOG.Key1
   AND RECEIPTDETAIL.Receiptlinenumber = TRANSMITLOG.Key2
   AND TRANSMITLOG.Tablename = 'RECEIPT'
   AND RECEIPTDETAIL.Storerkey = 'NIKETH'
   AND Transmitlog.Transmitflag = '0'
   AND RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
   AND RECEIPT.Processtype = @c_processtype
   ORDER BY receipt.receiptkey
   SET ROWCOUNT 0
   INSERT INTO #PROCESS01 (Receiptkey,  RECEIPTLinenumber, Lottable02)
   SELECT RECEIPTDETAIL.Receiptkey , RECEIPTDETAIL.Receiptlinenumber, dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(8), RECEIPTDETAIL.Lottable02)))
   FROM RECEIPTDETAIL (NOLOCK)
   WHERE RECEIPTDETAIL.Receiptkey = @c_receiptkey
   --   WHERE RECEIPTDETAIL.receiptkey = '0000005021'
   SELECT @n_err = @@ERROR
   IF NOT @n_err = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #PROCESS01 (nspExportNIKEReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   --
   IF @b_debug = 1
   BEGIN
      SELECT * from #PROCESS01
   END
   --select @c_seqno = ''
   IF @c_recordtype = 'H'
   BEGIN
      DECLARE @c_key NVARCHAR(10),
      @c_maxdate datetime
      SELECT @c_key = 'TRANSID_' + @c_processtype -- to have a unique key per processtype
      SELECT @c_maxdate = MAX(t.editdate)
      FROM receipt r (NOLOCK), transmitlog t (NOLOCK)
      WHERE r.receiptkey = t.key1
      AND r.storerkey = 'NIKETH'
      AND t.transmitflag = '9'
      AND r.processtype = @c_processtype
      IF DATEDIFF(MONTH, @c_maxdate, GETDATE()) <> 0
      BEGIN
         DELETE ncounter WHERE keyname = @c_key	-- reinitialize counter every month
      END
      EXECUTE nspg_getkey
      @c_key
      ,3
      , @c_seqno OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      WHILE (1 = 1)
      BEGIN
         -- cannot use the identity data definition, coz we have to get the records unique based on Receiptkey & Lottable02
         SELECT @c_receiptkey = '', @c_lottable02 = ''
         SET ROWCOUNT 1
         SELECT distinct @c_receiptkey = RECEIPTKEY --, @c_lottable02 = LOTTABLE02
         FROM #PROCESS01 (NOLOCK)
         WHERE Seqno is NULL
         SET ROWCOUNT 0
         IF @c_receiptkey = '' BREAK
         IF @c_lottable02 is NOT NULL
         BEGIN
            UPDATE #PROCESS01
            SET SEQNo = @c_seqno
            WHERE RECEIPTKEY = @c_receiptkey --AND Lottable02 = @c_lottable02
         END
      ELSE
         BEGIN
            UPDATE #PROCESS01
            SET SeqNo = @c_seqno
            WHERE RECEIPTKEY = @c_receiptkey --AND Lottable02 IS NULL
         END
         UPDATE transmitlog
         SET transmitbatch = @c_seqno
         WHERE key1 = @c_receiptkey
      END -- while
   END
ELSE -- record type is 'L'
   BEGIN
      UPDATE #process01
      SET seqno = transmitbatch
      FROM #process01 a INNER JOIN TRANSMITLOG
      ON (receiptkey = key1 AND receiptlinenumber = key2)
   END
   IF @b_debug = 1
   BEGIN
      SELECT 'Sequence No Assigned based on Receiptkey, Lottable02'
      SELECT * from #PROCESS01
   END
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   INSERT INTO #PROCESS02 (Receiptkey, Lottable02)
   SELECT DISTINCT Receiptkey, Lottable02
   FROM #Process01
   SELECT @n_err = @@ERROR
   IF NOT @n_err = 0
   BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #PROCESS02 (nspExportNIKEReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   IF @b_debug = 1
   BEGIN
   SELECT * from #PROCESS02
   END
   END
   */
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @yymm_date = Right(convert(NCHAR(10), getdate(), 101), 2) +  Left(convert(NCHAR(10), getdate(), 101) , 2)
      INSERT #OUTPUT01
      SELECT Distinct RECEIPT.Receiptkey,
      Receiptdetail.ReceiptLinenumber,
      --          dbo.fnc_LTrim(dbo.fnc_RTrim(convert(char(1),@c_processtype) + @yymm_date +   Right('000' + dbo.fnc_LTrim(dbo.fnc_RTrim(convert(char(3), #PROCESS01.SeqNo ))) , 3)))  + '|', --transid
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(1),@c_processtype))) + @yymm_date + #PROCESS01.SeqNo + '|', --transid
      '2|', --issueno
      REPLACE(dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(11), RECEIPT.ReceiptDate, 106))), ' ', '-') + '|',   --transdate
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(19), RECEIPT.CarrierReference ) ) ) + '|', -- refno
      'THL06|', --custref         '',
      'P|', --refcode
      '|' , --Reasoncode
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(30), Receipt.Containerkey)))  + '|' , -- container
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(20), PO.ExternPOKey)))  + '|', --PO#
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(2), PO.POtype )))  + '|', -- POType
      CASE @c_ProcessType WHEN 'R' THEN '' + '|'
   ELSE
      dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(55), '795-TH00-03-000-00-210-01-5510-000-000-000-00-00-000000'))) + '|' -- GLAccount
   END,
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(8), LEFT(RECEIPTDETAIL.Lottable02, Len(dbo.fnc_LTrim(dbo.fnc_RTrim(RECEIPTDETAIL.Lottable02))) - 3)))) + '|', -- POID
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(2), SKU.SUSR4 ))) + '|' ,   -- GPC
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(6), substring(RECEIPTDETAIL.SKU,1, 6) ))) + '|', -- Style
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(3), substring(RECEIPTDETAIL.SKU, 7, 3) )))  + '|', -- Color
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(3), substring(RECEIPTDETAIL.SKU, 10, 2) )))  + '|', -- Dimension
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(3), substring(RECEIPTDETAIL.SKU, 12, 2) )))  + '|', -- Quality
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(3), substring(RECEIPTDETAIL.SKU, 14,2) )))  + '|', -- UOM
   dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(5), substring(RECEIPTDETAIL.SKU, 16, 5) ))) + '|', --Size
   Subinvcode = CASE WHEN LOC.Locationtype = 'DAMAGE' THEN dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(10), 'DEFECTIVE'))) + '|'
ELSE dbo.fnc_LTrim(dbo.fnc_RTrim(Convert(NCHAR(10), 'NTL') )) + '|'
END,
dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NCHAR(10), RECEIPTDETAIL.QtyReceived) )) + '|' -- QtyReceived
FROM RECEIPT (NOLOCK), RECEIPTDETAIL (NOLOCK), #PROCESS01 (NOLOCK), PO (NOLOCK), SKU (NOLOCK), LOC (nolock), PODETAIL (nolock)
WHERE RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
AND RECEIPT.Receiptkey = #PROCESS01.Receiptkey
--   AND RECEIPT.Receiptkey = #PROCESS02.Receiptkey
--   AND #PROCESS01.Receiptkey = #PROCESS02.Receiptkey
AND RECEIPTDETAIL.Receiptlinenumber = #PROCESS01.Receiptlinenumber
AND RECEIPTDETAIL.Receiptkey = #PROCESS01.Receiptkey
AND RECEIPTDETAIL.POKey = PO.POKey
AND PO.POKey = PODETAIL.POKEY
AND RECEIPTDETAIL.POKey = PODETAIL.POKey
AND RECEIPTDETAIL.POLinenumber = PODETAIL.POLinenumber
AND RECEIPT.Storerkey = 'NIKETH'
AND RECEIPTDETAIL.SKU = SKU.SKU
AND RECEIPTDETAIL.Storerkey = SKU.Storerkey
AND RECEIPTDETAIL.Toloc = LOC.LOC
SELECT @n_err = @@ERROR
IF NOT @n_err = 0
BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #OUTPUT01 (nspExportNIKEReceipt)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
IF @b_debug = 1
BEGIN
   SELECT 'Output from #OUTPUT01 table'
   select * from #OUTPUT01
END
END
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   -- select output records
   IF @c_recordtype = 'H' -- header records,
   BEGIN
      SELECT DISTINCT   @c_recordtype + '|',
      TransID,
      IssueNo,
      TransDate,
      RefNo,
      CustRef,
      RefCode,
      ReasonCode,
      Container,
      PONo ,
      POType ,
      POID,
      GLAccount
      FROM #OUTPUT01
   END
   IF @c_recordtype = 'L'
   BEGIN -- select detail records
      SELECT            @c_recordtype + '|',
      TransId,
      GPC,
      Style,
      Color,
      Dimension,
      Quality,
      UOM,
      Sizes,
      Subinvcode,
      ReceivedQty,
      Receiptkey + Receiptlinenumber
      FROM #OUTPUT01
   END
END
END -- end of procedure


GO