SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillRetrievePendingCharge                       */
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
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/************************************************************************/

CREATE PROCEDURE  [dbo].[nspBillRetrievePendingCharge] (
@c_InvoiceBatchKey  NVARCHAR(10)
,              @c_BillingGroupMin  NVARCHAR(15)
,              @c_BillingGroupMax  NVARCHAR(15)
,              @c_chargetypes      NVARCHAR(250)
,              @dt_CutOffDate      datetime
,              @n_chargesretrieved int        OUTPUT
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
   DECLARE @dt datetime
   SELECT @n_chargesretrieved = 0
   SELECT @b_debug = 0
   IF CHARINDEX('DS_RP', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_RP', @c_errmsg) + 5, 1) )
      IF @b_debug not in (1,2)
      BEGIN
         SELECT @b_debug = 0
      END
   ELSE
      BEGIN
         SELECT 'Retrieve pending charges started ', GetDate()
         SELECT @dt = getdate()
      END
   END
   /* #INCLUDE <SPCRSC1.SQL> */
   IF @n_continue in (1, 2)
   BEGIN
      DECLARE @c_datetext NVARCHAR(20)
      SELECT @c_datetext = Convert(varchar(20), @dt_CutOffDate, 100)
      EXECUTE ( 'INSERT BILL_ACCUMULATEDCHARGES ( '
      + 'AccumulatedChargesKey, AddWho, '
      + 'Descrip,Status, PrintCount,  ServiceKey, StorerKey, Sku, Lot, ID, UOMShow, TariffKey, '
      + 'TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits, SystemGeneratedCharge, Debit, '
      + 'Credit, BilledUnits,ChargeType, LineType, BillFromDate, BillThruDate, SourceKey, SourceType, '
      + 'AccessorialDetailKey, GLDistributionKey, InvoiceBatch, InvoiceKey, CostRate, CostBase, '
      + 'CostMasterUnits,  CostUOMShow, CostSystemGeneratedCharge, Cost, CostUnits, TrafficCop, ReferenceKey) '
      + 'SELECT AccumulatedChargesKey, sUser_sName(), '
      + 'Descrip,"5", PrintCount,  ServiceKey, ACCUMULATEDCHARGES.StorerKey, Sku, Lot, ID, UOMShow, TariffKey,'
      + 'TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits, SystemGeneratedCharge, Debit,'
      + 'Credit, BilledUnits,ChargeType, LineType, BillFromDate, BillThruDate, SourceKey, SourceType,'
      + 'AccessorialDetailKey, GLDistributionKey, N''' + @c_invoicebatchkey
      + ''', InvoiceKey, CostRate, CostBase,'
      + 'CostMasterUnits,  CostUOMShow, CostSystemGeneratedCharge, Cost, CostUnits, "N", ReferenceKey '
      + 'FROM ACCUMULATEDCHARGES, STORERBILLING WHERE Status = "0"'
      + ' and LockBatch = N''' + @c_invoicebatchkey + ''''
      + ' and ACCUMULATEDCHARGES.StorerKey = STORERBILLING.StorerKey'
      + ' and BillingGroup BETWEEN N''' +@c_BillingGroupMin+''' and N''' + @c_BillingGroupMax +''''
      + ' and ChargeType in (' + @c_ChargeTypes +')'
      + ' and BillFromDate <= Convert(datetime, "' + @c_datetext + '")' )
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Retrieving Pending Charges (nspBillRetrievePendingCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (1,2)
      BEGIN
         SELECT 'Retrieved Pending Charges', @n_cnt, 'Elapsed' = DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
      IF @b_debug = 2
      BEGIN
         PRINT 'Bill_AccumulatedCharges retrieved (except RS)'
         SELECT * from bill_accumulatedcharges where chargetype <> 'RS'
      END
      SELECT @n_chargesretrieved = @n_cnt
   END
   IF @n_continue in (1,2)
   BEGIN
      IF @n_chargesretrieved <= 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = " No charges to process. (nspBillRetrievePendingCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      UPDATE BILL_ACCUMULATEDCHARGES
      SET ITRNSourceType = (CASE Upper(Substring(ITRN.SourceType, 4,4))
      WHEN 'RECE' THEN 'ASN/RECEIPT'
      WHEN 'PICK' THEN 'PICK'
      WHEN 'CASE' THEN 'CASEMANIFEST'
      WHEN 'PALL' THEN 'PALLETMANIFEST'
      WHEN 'TRAN' THEN ' '
   ELSE ITRN.SourceType END ),
      ITRNSourceKey = (CASE Upper(Substring(ITRN.SourceType, 4,4))
      WHEN 'TRAN' THEN ' '
   ELSE Substring(ITRN.SourceKey, 1,10) END )
      FROM ITRN (nolock)
      WHERE BILL_ACCUMULATEDCHARGES.SourceType = 'ITRN'
      AND BILL_ACCUMULATEDCHARGES.SourceKey = ITRN.ITRNKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating ITRN references (nspBillRetrievePendingCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @b_debug in (1,2)
      BEGIN
         SELECT 'Updated ITRN References', @n_cnt, 'Elapsed' = DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      UPDATE BILL_ACCUMULATEDCHARGES
      SET ITRNSourceType = 'SHIPMENTORDER',
      ITRNSourceKey = PICKDETAIL.OrderKey
      FROM PICKDETAIL (nolock)
      WHERE BILL_ACCUMULATEDCHARGES.ITRNSourceType = 'PICK'
      AND BILL_ACCUMULATEDCHARGES.ITRNSourceKey = PICKDETAIL.PickDetailKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating PickDetail references (nspBillRetrievePendingCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF @b_debug in (1,2)
      BEGIN
         SELECT 'Updated PickDetail References', @n_cnt, 'Elapsed' = DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      IF CHARINDEX('CI', @c_ChargeTypes) > 0 OR CHARINDEX('CO', @c_ChargeTypes) > 0
      BEGIN
         UPDATE BILL_ACCUMULATEDCHARGES
         SET ITRNSourceType = Upper(SourceType),
         ITRNSourceKey = SourceKey
         WHERE ChargeType IN ('CI','CO')
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating CI/CO references (nspBillRetrievePendingCharge)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE IF @b_debug in (1,2)
         BEGIN
            SELECT 'Updated CI/CO References', @n_cnt, 'Elapsed' = DateDiff(ss,@dt,GetDate())
            SELECT @dt = GetDate()
         END
      END
   END
   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      SELECT @n_chargesretrieved = 0
   END
ELSE
   BEGIN
      SELECT @b_success = 1
   END
   IF @b_debug <> 0
   BEGIN
      SELECT 'Retrieve Pending Charges Completed, s ', DateDiff(ss, @dt, getdate()), 'Number of charges:', @n_chargesretrieved
   END
   RETURN
END


GO