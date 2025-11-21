SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillTaxCharge                                   */
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

CREATE PROCEDURE  [dbo].[nspBillTaxCharge] (
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
   IF CHARINDEX('DS_T', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_T', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
   ELSE
      BEGIN
         SELECT 'Generate Tax charges started ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE @c_accumulatedchargekey NVARCHAR(10), @n_accumulatedchargekey int
   IF @n_continue in (1,2)
   BEGIN
      SELECT tg.TaxGroupKey,
      tr.TaxRateKey,
      Description = 'Tax: ' + dbo.fnc_RTrim(tg.Descrip)+ ' (' + dbo.fnc_RTrim(tr.TaxAuthority) + ')',
      tr.Rate,
      tgd.GLDistributionKey
      INTO #TaxDetail
      FROM TAXGROUP tg, TAXGROUPDETAIL tgd, TAXRATE tr
      WHERE tg.TaxGroupKey <> 'XXXXXXXXXX'
      AND tgd.TaxGroupKey = tg.TaxGroupKey
      AND tgd.TaxRateKey = tr.TaxRateKey
      AND tr.Rate > 0
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting List of Tax Charges Failed! (nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Tax Charges Set to be processed! (nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @b_debug = 1
      BEGIN
         SELECT * FROM #TaxDetail
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      CREATE table #TAXES
      (
      Ident                int IDENTITY,
      InvoiceKey           NVARCHAR(10)       NOT NULL,
      StorerKey            NVARCHAR(15)       NOT NULL,
      TariffKey            NVARCHAR(10)       NULL,
      TariffDetailKey      NVARCHAR(10)       NULL,
      ChargeType           NVARCHAR(10)       NULL,
      AccessorialDetailKey NVARCHAR(10)       NULL,
      TaxGroupKey          NVARCHAR(10)       NOT NULL,
      TaxRateKey           NVARCHAR(10)       NOT NULL,
      Description          NVARCHAR(100)      NOT NULL,
      Rate                 decimal (28,6) NOT NULL,
      DebitTotal           decimal (28,6) NOT NULL,
      Charge               decimal (28,6) NOT NULL,
      GLDistributionKey    NVARCHAR(10)       NULL
      )
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Create temp Lot_Minimums table failed! (nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      INSERT INTO #TAXES
      (InvoiceKey, StorerKey, TariffKey, TariffDetailKey, ChargeType, AccessorialDetailKey,
      TaxGroupKey, TaxRateKey, Description, Rate, DebitTotal, Charge, GLDistributionKey )
      SELECT InvoiceKey,
      StorerKey,
      TariffKey,
      TariffDetailKey,
      ChargeType,
      AccessorialDetailKey,
      A.TaxGroupKey,
      A.TaxRateKey,
      A.Description,
      A.Rate,
      SUM(Debit - Credit),
      A.Rate * SUM(Debit - Credit),
      A.GLDistributionKey
      FROM  #TAXDETAIL A, BILL_ACCUMULATEDCHARGES B
      WHERE A.TaxGroupKey = B.TaxGroupKey
      AND B.InvoiceBatch = @c_InvoiceBatchKey
      AND (Debit > 0  OR Credit > 0)
      AND (B.TaxGroupKey < 'XXXXXXXXXX' OR B.TaxGroupKey > 'XXXXXXXXXX')
      GROUP BY  InvoiceKey, StorerKey, TariffKey, TariffDetailKey, ChargeType, AccessorialDetailKey,
      A.TaxGroupKey, A.GLDistributionKey, A.Description, A.TaxRateKey, A.Rate
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert #Lot_Minimums failed! (nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         SELECT  @n_newcharges =  @n_cnt
         IF @n_cnt = 0
         BEGIN
            SELECT @n_continue = 4
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No taxes to be calculated in current run ( nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Invoice Minimums #:', @n_cnt, 'Elapsed, s' = DateDiff(ss,@dt,getdate())
         SELECT @dt = getdate()
      END
   END -- get new charges
   IF @n_continue in (1,2)
   BEGIN
      SELECT @n_cnt = count(1) FROM #Taxes
      IF @n_cnt <>  @n_newcharges
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = 'Incorrect number of taxes being processed'
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
      SystemGeneratedCharge, Debit, Credit, BilledUnits, ChargeType, LineType,
      BillFromDate, BillThruDate,
      SourceKey, SourceType, AccessorialDetailKey, GLDistributionKey,
      InvoiceBatch, InvoiceKey, CostSystemGeneratedCharge, Cost,
      CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits)
      SELECT RIGHT(Replicate("0",10) + dbo.fnc_RTrim(dbo.fnc_LTrim(convert(char(10), (@n_accumulatedchargekey + Ident - 1 )))), 10),
      Description,'5',0,'XXXXXXXXXX', StorerKey, ' ', ' ', ' ', ' ',
      ' ', TariffKey, TariffDetailKey, TaxGroupKey, Rate, 'F', 1.0,
      Charge, Charge, 0.0, DebitTotal, ChargeType, 'T',
      GetDate(), GetDate(),
      ' ', ' ', AccessorialDetailKey, GLDistributionKey,
      @c_InvoiceBatchKey, InvoiceKey, 0.0, 0.0,
      0.0, 'F', 1.0, ' ', 0.0
      FROM #TAXES
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Bill_AccumulatedCharges Failed. (nspBillTaxCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         IF @n_cnt <>  @n_newcharges
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Number of Generated Tax Charges <> Inserted:" + convert(varchar(10),  @n_newcharges) + " / "+ convert(varchar(10), @n_cnt)
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
      SELECT 'Generate Tax Charges Completed, s ', DateDiff(ss, @dt, getdate()), 'Number of charges:',  @n_newcharges
   END
   RETURN
END


GO