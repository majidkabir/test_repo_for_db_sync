SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspBillDocumentMinimumCharge                       */
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
/* 22-Jun-2007  SHONG         Bug Fixing (Wrong Column Name)            */ 
/************************************************************************/

CREATE PROCEDURE  [dbo].[nspBillDocumentMinimumCharge] (
@c_InvoiceBatchKey  NVARCHAR(10)
,              @n_newcharges       int        OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_cnt        int       , -- variable to hold @@ROWCOUNT 
   @n_err2       int       , -- For Additional Error Detection
   @b_debug      int         -- Debug mode
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_err2=0
   SELECT  @n_newcharges = 0
   DECLARE @dt datetime
   SELECT @b_debug = 0
   IF CHARINDEX('DS_DM', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_DM', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
      ELSE
      BEGIN
         SELECT 'Generate Document Minimum charges started ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE @c_curStorerKey NVARCHAR(15), @c_curChargeType NVARCHAR(10),
   @c_curHICharge decimal(28,6), @c_curHITaxGroup NVARCHAR(10), @c_curHIGLDist NVARCHAR(10),
   @c_curHOCharge decimal(28,6), @c_curHOTaxGroup NVARCHAR(10), @c_curHOGLDist NVARCHAR(10),
   @c_curISCharge decimal(28,6), @c_curISTaxGroup NVARCHAR(10), @c_curISGLDist NVARCHAR(10),
   @c_accumulatedchargekey NVARCHAR(10), @n_accumulatedchargekey int
   SELECT StorerKey,
          HOMinimumShipmentCharge,
          HOMinimumShipmentTaxGroup,
          HOMinimumShipmentGLDist,
          HIMinimumReceiptCharge,
          HIMinimumReceiptTaxGroup,
          HIMinimumReceiptGLDist,
          ISMinimumReceiptCharge,
          ISMinimumReceiptTaxGroup,
          ISMinimumReceiptGLDist
   INTO #StorerDetail
   FROM STORERBILLING WITH (NOLOCK) 
   WHERE  LockBatch = @c_InvoiceBatchKey
   AND ( HOMinimumShipmentCharge > 0
   OR ISMinimumReceiptCharge > 0
   OR HIMinimumReceiptCharge > 0 )
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting List of Storer Document Minimums Failed! (nspBillDocumentMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 4
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Document Minimum Charges to be processed! (nspBillDocumentMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   IF @b_debug = 1
   BEGIN
      SELECT * FROM #StorerDetail
      SELECT @dt = getdate()
   END
   IF @n_continue in (1,2)
   BEGIN
      CREATE table #DOCUMENT_MINIMUMS
      (
      Ident int IDENTITY,
      StorerKey           NVARCHAR(15)    NULL,
      Descr               NVARCHAR(100)   NULL,
      SourceType          NVARCHAR(30)    NULL,
      SourceKey           NVARCHAR(20)    NULL,
      ChargeType          NVARCHAR(10)    NULL,
      MinCharge           decimal (28,6) NULL,
      Charge              decimal (28,6) NULL,
      TaxGroupKey         NVARCHAR(10)    NULL,
      GLDistributionKey   NVARCHAR(10)    NULL,
      BillDate            datetime       NULL
      )
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Create temp Document_Minimums table failed! (nspBillDocumentMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   SELECT @c_curStorerKey = master.dbo.fnc_GetCharASCII(14)
   WHILE @n_continue in (1,2)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_curStorerKey = StorerKey,
             @c_curHOCharge = HOMinimumShipmentCharge,
             @c_curHOTaxGroup = HOMinimumShipmentTaxGroup,
             @c_curHOGLDist = HOMinimumShipmentGLDist,
             @c_curHICharge = HIMinimumReceiptCharge,
             @c_curHITaxGroup = HIMinimumReceiptTaxGroup,
             @c_curHIGLDist = HIMinimumReceiptGLDist,
             @c_curISCharge = ISMinimumReceiptCharge,
             @c_curISTaxGroup = ISMinimumReceiptTaxGroup,
             @c_curISGLDist = ISMinimumReceiptGLDist
      FROM #StorerDetail
      WHERE StorerKey > @c_curStorerKey
      ORDER BY StorerKey
      SELECT @n_cnt = @@ROWCOUNT
      SET ROWCOUNT 0
      IF @n_cnt = 0 BREAK
      IF @b_debug <> 0
      BEGIN
         SELECT '@c_curStorerKey', @c_curStorerKey, 'curTime', getdate()
      END
      INSERT INTO #DOCUMENT_MINIMUMS
         (StorerKey, Descr,     SourceType,  SourceKey,         ChargeType, 
          MinCharge, Charge,    TaxGroupKey, GLDistributionKey, BillDate )
      SELECT StorerKey,
         (CASE ChargeType
               WHEN 'HI' THEN 'Document HI Minimum Charge Adjustment'
               WHEN 'HO' THEN 'Document HO Minimum Charge Adjustment'
               WHEN 'IS' THEN 'Document IS Minimum Charge Adjustment' 
          END),
          ITRNSourceType,
          ITRNSourceKey,
         (CASE ChargeType
             WHEN 'HI' THEN 'MH'
             WHEN 'HO' THEN 'MO'
             WHEN 'IS' THEN 'MI' 
          END),
         (CASE ChargeType
             WHEN 'HI' THEN @c_curHICharge
             WHEN 'HO' THEN @c_curHOCharge
             WHEN 'IS' THEN @c_curISCharge 
          END),
         (CASE ChargeType
            WHEN 'HI' THEN @c_curHICharge - SUM(Debit - Credit)
            WHEN 'HO' THEN @c_curHOCharge - SUM(Debit - Credit)
            WHEN 'IS' THEN @c_curISCharge - SUM(Debit - Credit) 
          END),
         (CASE ChargeType
            WHEN 'HI' THEN @c_curHITaxGroup
            WHEN 'HO' THEN @c_curHOTaxGroup
            WHEN 'IS' THEN @c_curISTaxGroup 
          END),
         (CASE ChargeType
            WHEN 'HI' THEN @c_curHIGLDist
            WHEN 'HO' THEN @c_curHOGLDist
            WHEN 'IS' THEN @c_curISGLDist 
          END),
         Convert(datetime, Convert(varchar(20), GetDate(), 101))
      FROM BILL_ACCUMULATEDCHARGES WITH (NOLOCK) 
      WHERE InvoiceBatch = @c_InvoiceBatchKey
        AND ITRNSourceType > ' '
        AND ChargeType IN ('HI','HO','IS')
        AND (Debit > 0  OR Credit > 0)
      GROUP BY  StorerKey, ITRNSourceType, ITRNSourceKey, ChargeType
      HAVING SUM(Debit - Credit) > 0
         AND SUM(Debit - Credit) < (
                    CASE ChargeType
                       WHEN 'HI' THEN @c_curHICharge
                       WHEN 'HO' THEN @c_curHOCharge
                       WHEN 'IS' THEN @c_curISCharge 
                    END)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert #Document_Minimums failed! (nspBillDocumentMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE
      BEGIN
         SELECT  @n_newcharges =  @n_newcharges + @n_cnt
         IF @b_debug = 1
         BEGIN
            SELECT 'Inserted #:', @n_cnt, 'Total #:, ',  @n_newcharges, 'Elapsed, s' = DateDiff(ss,@dt,getdate())
            SELECT @dt = getdate()
         END
      END
   END -- while storer key
   IF @n_continue in (1,2)
   BEGIN
      SELECT @n_cnt = count(1) FROM #DOCUMENT_MINIMUMS
      IF @n_cnt <>  @n_newcharges
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = 'Incorrect number of charges being processed'
      END
      ELSE IF @n_newcharges = 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = 'All Document Minimums are satisfied'
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      EXECUTE nspg_getkey 'AccumulatedChargesKey',
      10,
      @c_accumulatedchargekey OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT,
      0,
      @n_newcharges
      IF @b_success = 1
      BEGIN
         SELECT @n_accumulatedchargekey = Convert(int, @c_accumulatedchargekey)
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      INSERT INTO Bill_AccumulatedCharges
         (AccumulatedChargesKey,
         Descrip, Status, PrintCount, ServiceKey, StorerKey, Sku, Lot, Id, ReferenceKey,
         UOMShow, TariffKey, TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits,
         SystemGeneratedCharge, Debit, Credit, BilledUnits, ChargeType, LineType, BillFromDate,
         BillThruDate, SourceKey, SourceType, AccessorialDetailKey, GLDistributionKey,
         InvoiceBatch, InvoiceKey, CostSystemGeneratedCharge, Cost,
         CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits)
      SELECT RIGHT(Replicate("0",10) + dbo.fnc_RTrim(dbo.fnc_LTrim(convert(char(10), (@n_accumulatedchargekey + Ident - 1 )))), 10),
         Descr,'5',0,'XXXXXXXXXX', StorerKey, ' ', ' ', ' ', ' ',
         ' ', 'XXXXXXXXXX', ' ', TaxGroupKey, MinCharge, 'F', 1.0,
         Charge, Charge, 0.0, 1.0, ChargeType, 'N', BillDate,
         DateAdd(mi, -1, DateAdd(dd, 1, BillDate)),
         SourceKey, SourceType, 'XXXXXXXXXX', GLDistributionKey,
         @c_InvoiceBatchKey, ' ', 0.0, 0.0,
         0.0, 'F', 1.0, ' ', 0.0
      FROM #DOCUMENT_MINIMUMS
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Bill_AccumulatedCharges Failed. (nspBillDocumentMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE
      BEGIN
         IF @n_cnt <>  @n_newcharges
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Number of Generated Document Minimum Charges <> Inserted:" + convert(varchar(10),  @n_newcharges) + " / "+ convert(varchar(10), @n_cnt)
         END
      END
   END -- Insert Bill_AccumulatedCharges
   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      SELECT  @n_newcharges = 0
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
   END
   IF @b_debug <> 0
   BEGIN
      SELECT 'Generate Lot Minimum Charges Completed, s ', DateDiff(ss, @dt, getdate()), 'Number of charges:',  @n_newcharges, 'Elapsed, s:', DateDiff(ss,@dt,getdate())
   END
   RETURN
END


GO