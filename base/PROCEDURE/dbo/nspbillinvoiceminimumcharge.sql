SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillInvoiceMinimumCharge                        */
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

CREATE PROCEDURE   [dbo].[nspBillInvoiceMinimumCharge] (
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
   @n_cnt int              ,    /* variable to hold @@ROWCOUNT */
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug mode
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_err2=0
   SELECT  @n_newcharges = 0
   DECLARE @dt datetime
   SELECT @b_debug = 0
   IF CHARINDEX('DS_IM', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_IM', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
   ELSE
      BEGIN
         SELECT 'Generate Invoice Minimum charges started ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE @c_accumulatedchargekey NVARCHAR(10), @n_accumulatedchargekey int
   IF @n_continue in (1,2)
   BEGIN
      SELECT StorerKey,
      RSMinimumInvoiceCharge,
      RSMinimumInvoiceTaxGroup,
      RSMinimumInvoiceGLDist,
      ISMinimumInvoiceCharge,
      ISMinimumInvoiceTaxGroup,
      ISMinimumInvoiceGLDist,
      HIMinimumInvoiceCharge,
      HIMinimumInvoiceTaxGroup,
      HIMinimumInvoiceGLDist
      INTO #Storer_Detail
      FROM STORERBILLING
      WHERE  LockBatch = @c_InvoiceBatchKey
      AND (RSMinimumInvoiceCharge > 0
      OR ISMinimumInvoiceCharge > 0
      OR HIMinimumInvoiceCharge > 0 )
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting List of Storer Invoice Minimums Failed! ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Invoice Minimum Charges Set to be processed! ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug = 1
      BEGIN
         SELECT * FROM #Storer_Detail
         SELECT @dt = getdate()
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      CREATE table #INVOICE_MINIMUMS
      (
      Ident int IDENTITY,
      StorerKey           NVARCHAR(15)    NULL,
      InvoiceKey          NVARCHAR(10)    NULL,
      Descrip             NVARCHAR(100)   NULL,
      DebitTotal          decimal(28,6)  NULL,
      InvoiceMinimum      decimal(28,6)  NULL,
      ChargeType          NVARCHAR(10)    NULL,
      Charge              decimal(28,6)  NULL,
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
   IF @n_continue in (1,2)
   BEGIN
      INSERT #INVOICE_MINIMUMS
      (StorerKey,InvoiceKey,Descrip,DebitTotal,InvoiceMinimum,ChargeType,Charge,
      TaxGroupKey,GLDistributionKey,BillDate)
      SELECT BILL_ACCUMULATEDCHARGES.StorerKey,
      InvoiceKey,
      'Invoice Minimum RS Charge Adjustment',
      SUM(Debit - Credit),
      RSMinimumInvoiceCharge,
      'RS',
      0.0,
      RSMinimumInvoiceTaxGroup,
      RSMinimumInvoiceGLDist,
      Convert(datetime, Convert(varchar(20), GetDate(), 101))
      -- INTO #INVOICE_MINIMUMS
      FROM BILL_ACCUMULATEDCHARGES, #STORER_DETAIL
      WHERE BILL_ACCUMULATEDCHARGES.InvoiceBatch = @c_InvoiceBatchKey
      AND BILL_ACCUMULATEDCHARGES.Storerkey = #STORER_DETAIL.StorerKey
      AND #STORER_DETAIL.RSMinimumInvoiceCharge > 0
      AND (Debit > 0  OR Credit > 0)
      AND ChargeType = 'RS'
      GROUP BY  BILL_ACCUMULATEDCHARGES.StorerKey,
      RSMinimumInvoiceCharge, RSMinimumInvoiceTaxGroup, RSMinimumInvoiceGLDist,
      InvoiceKey
      HAVING SUM(Debit - Credit) < RSMinimumInvoiceCharge  AND SUM(Debit - Credit) > 0
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert RS #Invoice_Minimums failed! ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Invoice RS Minimums #:', @n_cnt, 'Elapsed, s',DateDiff(ss,@dt,getdate())
         SELECT @dt = getdate()
      END
   END -- get RS charges
   IF @n_continue in (1,2)
   BEGIN
      INSERT #INVOICE_MINIMUMS
      (StorerKey,InvoiceKey,Descrip,DebitTotal,InvoiceMinimum,ChargeType,Charge,
      TaxGroupKey,GLDistributionKey,BillDate)
      SELECT BILL_ACCUMULATEDCHARGES.StorerKey,
      InvoiceKey,
      'Invoice Minimum IS Charge Adjustment',
      SUM(Debit - Credit),
      ISMinimumInvoiceCharge,
      'IS',
      0.0,
      ISMinimumInvoiceTaxGroup,
      ISMinimumInvoiceGLDist,
      Convert(datetime, Convert(varchar(20), GetDate(), 101))
      -- INTO #INVOICE_MINIMUMS
      FROM BILL_ACCUMULATEDCHARGES, #STORER_DETAIL
      WHERE BILL_ACCUMULATEDCHARGES.InvoiceBatch = @c_InvoiceBatchKey
      AND BILL_ACCUMULATEDCHARGES.Storerkey = #STORER_DETAIL.StorerKey
      AND #STORER_DETAIL.ISMinimumInvoiceCharge > 0
      AND (Debit > 0  OR Credit > 0)
      AND ChargeType = 'IS'
      GROUP BY  BILL_ACCUMULATEDCHARGES.StorerKey,
      ISMinimumInvoiceCharge, ISMinimumInvoiceTaxGroup, ISMinimumInvoiceGLDist,
      InvoiceKey
      HAVING SUM(Debit - Credit) < ISMinimumInvoiceCharge  AND SUM(Debit - Credit) > 0
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert IS #Invoice_Minimums failed! ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Invoice IS Minimums #:', @n_cnt, 'Elapsed, s',DateDiff(ss,@dt,getdate())
         SELECT @dt = getdate()
      END
   END -- get IS charges
   IF @n_continue in (1,2)
   BEGIN
      INSERT #INVOICE_MINIMUMS
      (StorerKey,InvoiceKey,Descrip,DebitTotal,InvoiceMinimum,ChargeType,Charge,
      TaxGroupKey,GLDistributionKey,BillDate)
      SELECT BILL_ACCUMULATEDCHARGES.StorerKey,
      InvoiceKey,
      'Invoice Minimum HI Charge Adjustment',
      SUM(Debit - Credit),
      HIMinimumInvoiceCharge,
      'HI',
      0.0,
      HIMinimumInvoiceTaxGroup,
      HIMinimumInvoiceGLDist,
      Convert(datetime, Convert(varchar(20), GetDate(), 101))
      -- INTO #INVOICE_MINIMUMS
      FROM BILL_ACCUMULATEDCHARGES, #STORER_DETAIL
      WHERE BILL_ACCUMULATEDCHARGES.InvoiceBatch = @c_InvoiceBatchKey
      AND BILL_ACCUMULATEDCHARGES.Storerkey = #STORER_DETAIL.StorerKey
      AND #STORER_DETAIL.HIMinimumInvoiceCharge > 0
      AND (Debit > 0  OR Credit > 0)
      AND ChargeType = 'HI'
      GROUP BY  BILL_ACCUMULATEDCHARGES.StorerKey,
      HIMinimumInvoiceCharge, HIMinimumInvoiceTaxGroup, HIMinimumInvoiceGLDist,
      InvoiceKey
      HAVING SUM(Debit - Credit) < HIMinimumInvoiceCharge  AND SUM(Debit - Credit) > 0
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert HI #Invoice_Minimums failed! ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Invoice HI Minimums #:', @n_cnt, 'Elapsed, s',DateDiff(ss,@dt,getdate())
         SELECT @dt = getdate()
      END
   END -- get HI charges
   IF @n_continue in (1,2)
   BEGIN
      SELECT @n_newcharges = count(1) FROM #INVOICE_MINIMUMS
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
      SystemGeneratedCharge, Debit, Credit, BilledUnits, ChargeType, LineType,
      BillFromDate, BillThruDate,
      SourceKey, SourceType, AccessorialDetailKey, GLDistributionKey,
      InvoiceBatch, InvoiceKey, CostSystemGeneratedCharge, Cost,
      CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits)
      SELECT RIGHT(Replicate("0",10) + dbo.fnc_RTrim(dbo.fnc_LTrim(convert(char(10), (@n_accumulatedchargekey + Ident - 1 )))), 10),
      Descrip,
      '5',0,'XXXXXXXXXX', StorerKey, ' ', ' ', ' ', ' ',
      ' ', 'XXXXXXXXXX', ' ', TaxGroupKey, InvoiceMinimum, 'F', 1.0,
      InvoiceMinimum - DebitTotal, InvoiceMinimum - DebitTotal, 0.0, 1.0, 'MT', 'N',
      BillDate, DateAdd(mi, -1, DateAdd(dd, 1, BillDate)),
      ' ', ' ', 'XXXXXXXXXX', GLDistributionKey,
      @c_InvoiceBatchKey, InvoiceKey, 0.0, 0.0,
      0.0, 'F', 1.0, ' ', 0.0
      FROM #INVOICE_MINIMUMS
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Bill_AccumulatedCharges Failed. ( nspBillInvoiceMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         IF @n_cnt <>  @n_newcharges
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Number of Generated Invoice Minimum Charges <> Inserted:" + convert(varchar(10),  @n_newcharges) + " / "+ convert(varchar(10), @n_cnt)
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
      SELECT 'Generate Invoice Minimum Charges Completed at ', getdate(), 'Number of charges:',  @n_newcharges, 'Elapsed, s:', DateDiff(ss,@dt,getdate())
   END
   RETURN
END


GO