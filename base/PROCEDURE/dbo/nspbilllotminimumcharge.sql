SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillLotMinimumCharge                            */
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

CREATE PROCEDURE  [dbo].[nspBillLotMinimumCharge] (
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
   IF CHARINDEX('DS_LM', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_LM', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
   ELSE
      BEGIN
         SELECT 'Generate Lot Minimum charges started ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE @c_curTariffDetailKey NVARCHAR(10), @c_curChargeType NVARCHAR(10), @c_curTariffKey NVARCHAR(10),
   @c_curGLDistributionKey NVARCHAR(10), @c_curTaxGroupKey NVARCHAR(10),
   @d_curMinimumCharge decimal(28,6), @c_accumulatedchargekey NVARCHAR(10), @n_accumulatedchargekey int
   SELECT TariffKey, TariffDetailKey,
   MinimumGroup, MinimumCharge, TaxGroupKey, GLDistributionKey,
   ChargeType = (CASE Upper(ChargeType)
   WHEN 'IS' THEN 'MI'
   WHEN 'RS' THEN 'MR'
   WHEN 'HI' THEN 'MH'
WHEN 'HO' THEN 'MO' END)
INTO #TariffDetail
FROM TARIFFDETAIL
WHERE Upper(IsNull(dbo.fnc_RTrim(MinimumGroup),' ')) = 'LOT'
AND MinimumCharge > 0
AND ChargeType IN ('IS','RS','HI','HO')
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Getting List of Lot Minimum Charges Failed! (nspBillLotMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 4
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Lot Minimum Charges to be processed! (nspBillLotMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
ELSE IF @b_debug = 1
   BEGIN
      SELECT * FROM #TariffDetail
   END
   IF @n_continue in (1,2)
   BEGIN
      CREATE table #LOT_MINIMUMS
      (
      Ident int IDENTITY,
      StorerKey           NVARCHAR(15) NOT NULL,
      Sku                 NVARCHAR(20) NOT NULL,
      Lot                 NVARCHAR(10) NOT NULL,
      ID                  NVARCHAR(18) NOT NULL,
      BillDate            datetime NOT NULL,
      TariffKey           NVARCHAR(10) NOT NULL,
      TariffDetailKey     NVARCHAR(10) NOT NULL,
      TaxGroupKey         NVARCHAR(10) NOT NULL,
      MinCharge           decimal (28,6) NOT NULL,
      Charge              decimal (28,6) NOT NULL,
      ChargeType          NVARCHAR(10) NOT NULL,
      GLDistributionKey   NVARCHAR(10) NOT NULL
      )
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Create temp Lot_Minimums table failed! (nspBillLotMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   SELECT @c_curTariffDetailKey = master.dbo.fnc_GetCharASCII(14)
   WHILE @n_continue in (1,2)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_curTariffKey = TariffKey,
      @c_curTariffDetailKey = TariffDetailKey,
      @c_curChargeType = ChargeType,
      @d_curMinimumCharge = MinimumCharge,
      @c_curTaxGroupKey = TaxGroupKey,
      @c_curGLDistributionKey = GLDistributionKey
      FROM #TariffDetail
      WHERE TariffDetailKey > @c_curTariffDetailKey
      ORDER BY TariffDetailKey
      SELECT @n_cnt = @@ROWCOUNT
      SET ROWCOUNT 0
      IF @n_cnt = 0 BREAK
      IF @b_debug <> 0
      BEGIN
         SELECT '@c_curTariffDetailKey', @c_curTariffDetailKey, '@d_curMinimumCharge', @d_curMinimumCharge, 'curTime', getdate()
      END
      INSERT INTO #LOT_MINIMUMS
      (Lot, StorerKey, Sku, Id, BillDate, TariffKey, TariffDetailKey,
      TaxGroupKey, MinCharge, Charge, ChargeType, GLDistributionKey )
      SELECT Lot,
      StorerKey,
      Sku,
      ' ',
      Convert(char(10), BillFromDate, 101),
      @c_curTariffKey,
      @c_curTariffDetailKey,
      @c_curTaxGroupKey,
      @d_curMinimumCharge,
      @d_curMinimumCharge - SUM(Debit - Credit),
      @c_curChargeType,
      @c_curGLDistributionKey
      FROM BILL_ACCUMULATEDCHARGES
      WHERE InvoiceBatch = @c_InvoiceBatchKey
      AND Lot > ' '
      AND TariffDetailKey = @c_curTariffDetailKey
      AND (Debit > 0  OR Credit > 0)
      GROUP BY  Lot, StorerKey, Sku, Convert(char(10), BillFromDate, 101)
      HAVING SUM(Debit - Credit) < @d_curMinimumCharge
      AND SUM(Debit - Credit) > 0
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert #Lot_Minimums failed! (nspBillLotMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         SELECT  @n_newcharges =  @n_newcharges + @n_cnt
         IF @b_debug = 1
         BEGIN
            SELECT 'Inserted #:', @n_cnt, 'Total #:, ',  @n_newcharges
         END
      END
   END -- while tariffdetail key
   IF @n_continue in (1,2)
   BEGIN
      SELECT @n_cnt = count(1) FROM #LOT_MINIMUMS
      IF @n_cnt <>  @n_newcharges
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = 'Incorrect number of charges being processed'
      END
   ELSE IF @n_newcharges = 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = 'All Lot  Minimums are satisfied'
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
      'Lot Minimum Charge Adjustment','5',0,'XXXXXXXXXX', StorerKey, Sku, Lot, Id, ' ',
      ' ', TariffKey, TariffDetailKey, TaxGroupKey, MinCharge, 'F', 1.0,
      Charge, Charge, 0.0, 1.0, ChargeType, 'N', BillDate,
      DateAdd(mi, -1, DateAdd(dd, 1, BillDate)),
      ' ', ' ', 'XXXXXXXXXX', GLDistributionKey,
      @c_InvoiceBatchKey, ' ', 0.0, 0.0,
      0.0, 'F', 1.0, ' ', 0.0
      FROM #LOT_MINIMUMS
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Bill_AccumulatedCharges Failed. (nspBillLotMinimumCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         IF @n_cnt <>  @n_newcharges
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Number of Generated Lot Minimum Charges <> Inserted:" + convert(varchar(10),  @n_newcharges) + " / "+ convert(varchar(10), @n_cnt)
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
      SELECT 'Generate Lot Minimum Charges Completed, s ', DateDiff(ss, @dt, getdate()), 'Number of charges:',  @n_newcharges
   END
   RETURN
END


GO