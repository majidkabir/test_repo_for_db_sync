SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspBillingRun                                      */
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

CREATE PROCEDURE [dbo].[nspBillingRun] (
@c_BillingGroupMin     NVARCHAR(15) ,
@c_BillingGroupMax     NVARCHAR(15) ,
@c_chargetypes      NVARCHAR(250),
@dt_CutOffDate      datetime ,
@b_Success          int       OUTPUT,
@n_err              int       OUTPUT,
@c_errmsg           NVARCHAR(250) OUTPUT,
@n_totinvoices      int       OUTPUT,
@n_totcharges       int       OUTPUT
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
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0,@n_err2=0
   SELECT @n_totcharges = 0, @n_totinvoices = 0
   DECLARE @n_chargesretrieved int, @dt datetime, @b_lockset NVARCHAR(1), @c_message NVARCHAR(250), @n_newcharges int
   SELECT @n_chargesretrieved = 0, @n_newcharges = 0, @dt = getdate(), @c_message = @c_errmsg
   /* #INCLUDE <SPCRSC1.SQL> */
   SELECT @b_debug = 0
   IF CHARINDEX('DS_W', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_W', @c_errmsg) + 4, 1) )
      IF @b_debug not in (0,1,2,3)
      BEGIN
         SELECT @b_debug = 0
      END
   END
   IF @b_debug in (1,2)
   BEGIN
      PRINT ' '
      SELECT 'BillRun Started'=GetDate(), '@c_BillingGroupMin'=@c_BillingGroupMin,'@c_BillingGroupMax'=@c_BillingGroupMax,
      '@c_chargetypes'=@c_chargetypes,'@dt_CutOffDate'=@dt_CutOffDate
   END
   IF @n_continue in (1,2)
   BEGIN
      IF EXISTS (SELECT 1 FROM ACCUMULATEDCHARGES
      WHERE STATUS = '5' AND EditWho = sUser_sName())
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": User must post or cancel previous Billing Run before start next (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         DELETE BILL_ACCUMULATEDCHARGES WHERE AddWho = sUser_sName()
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete from Bill_AccumulatedCharges failed (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         IF @b_debug IN (1,2)
         BEGIN
            SELECT 'Deleted old records:        ', @n_cnt, 'Elapsed, s', DateDiff(ss,@dt,getdate())
            SELECT @dt = getdate()
         END
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      DECLARE @c_invoicebatchkey NVARCHAR(10)
      EXECUTE nspg_getkey
      'InvoiceBatch',
      10,
      @c_invoicebatchkey OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
      END
      IF @b_debug in (1,2)
      BEGIN
         SELECT 'InvoiceBatchKey', @c_invoicebatchkey
         SELECT @dt = getdate()
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      IF EXISTS (SELECT 1 FROM STORERBILLING
      WHERE BillingGroup BETWEEN @c_BillingGroupMin and @c_BillingGroupMax
      AND IsNull(dbo.fnc_RTrim(dbo.fnc_LTrim(LockBatch)),'') <> '')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": At least one Storer is being locked (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE
      BEGIN
         UPDATE STORERBILLING
         SET LockBatch = @c_invoicebatchkey,
         LockWho = sUser_sName()
         WHERE BillingGroup BETWEEN @c_BillingGroupMin and @c_BillingGroupMax
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Lock Storer failed (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE
         BEGIN
            SELECT @b_lockset = '1'
            IF @b_debug IN (1,2)
            BEGIN
               SELECT 'StorerBilling Updated:      ', @n_cnt, 'Elapsed', DateDiff(ss,@dt,getdate())
               SELECT @dt = getdate()
            END
         END
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      IF CHARINDEX('RS', @c_ChargeTypes) > 0
      BEGIN
         EXECUTE nspCalculateRSCharges
         @c_BillingGroupMin ,
         @c_BillingGroupMax ,
         @c_ChargeTypes  ,
         @dt_CutOffDate  ,
         @c_invoicebatchkey,
         @b_success         OUTPUT,
         @n_err             OUTPUT,
         @c_errmsg          OUTPUT,
         @n_totcharges      OUTPUT
         IF @b_success = 0
         BEGIN
            SELECT @n_continue = 3
         END
         IF @b_debug in (1,2)
         BEGIN
            SELECT 'Generated RS Charges:       ',@n_totcharges,'Total',@n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate()), '@b_success'=@b_success, '@c_errmsg'=@c_errmsg
            SELECT @dt = getdate()
         END
         IF @b_debug = 2
         BEGIN
            PRINT 'Bill_AccumulatedCharges After RS'
            SELECT * from Bill_Accumulatedcharges
         END
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillRetrievePendingCharge
      @c_InvoiceBatchKey
      ,              @c_BillingGroupMin
      ,              @c_BillingGroupMax
      ,              @c_chargetypes
      ,              @dt_CutOffDate
      ,              @n_chargesretrieved OUTPUT
      ,              @b_Success          OUTPUT
      ,              @n_err              OUTPUT
      ,              @c_errmsg           OUTPUT
      IF @b_Success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
         SELECT @n_totcharges = @n_totcharges + @n_chargesretrieved
      END
      IF @b_debug in (1,2)
      BEGIN
         SELECT 'Retrieved Pending Charges:  ', @n_chargesretrieved,'Total',@n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
      IF @b_debug = 2
      BEGIN
         PRINT 'Bill_AccumulatedCharges retrieved (except RS)'
         SELECT * from bill_accumulatedcharges where chargetype <> 'RS'
      END
   END
   IF @n_continue in (1,2)
   BEGIN
      IF @n_totcharges <= 0
      BEGIN
         SELECT @n_continue = 4
         SELECT @c_errmsg = " No charges to process. (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillLotMinimumCharge
      @c_InvoiceBatchKey
      ,              @n_newcharges       OUTPUT
      ,              @b_Success          OUTPUT
      ,              @n_err              OUTPUT
      ,              @c_errmsg           OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
         SELECT @n_totcharges = @n_totcharges + @n_newcharges
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Lot Minimum Charges:        ',@n_newcharges, 'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillDocumentMinimumCharge
      @c_InvoiceBatchKey
      ,              @n_newcharges       OUTPUT
      ,              @b_Success          OUTPUT
      ,              @n_err              OUTPUT
      ,              @c_errmsg           OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
         SELECT @n_totcharges = @n_totcharges + @n_newcharges
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Document Minimum Charges:   ',@n_newcharges, 'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillSetInvoiceNumbers
      @c_InvoiceBatchKey    ,
      @n_totinvoices OUTPUT ,
      @b_Success     OUTPUT ,
      @n_err         OUTPUT ,
      @c_errmsg      OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
      END
      IF @b_debug in (1,2)
      BEGIN
         SELECT 'Assigned Invoices:          ', @n_totinvoices, 'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillInvoiceMinimumCharge
      @c_InvoiceBatchKey
      ,              @n_newcharges       OUTPUT
      ,              @b_Success          OUTPUT
      ,              @n_err              OUTPUT
      ,              @c_errmsg        OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
         SELECT @n_totcharges = @n_totcharges + @n_newcharges
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Invoice Minimum Charges:    ',@n_newcharges, 'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      EXECUTE  nspBillTaxCharge
      @c_InvoiceBatchKey
      ,              @n_newcharges       OUTPUT
      ,              @b_Success          OUTPUT
      ,              @n_err              OUTPUT
      ,              @c_errmsg           OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
      END
   ELSE
      BEGIN
         SELECT @c_errmsg = @c_message
         SELECT @n_totcharges = @n_totcharges + @n_newcharges
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Tax Charges:                ',@n_newcharges, 'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate())
         SELECT @dt = GetDate()
      END
   END
   IF @n_continue in (1, 2)
   BEGIN
      BEGIN TRAN
         IF @n_chargesretrieved > 0
         BEGIN
            UPDATE ACCUMULATEDCHARGES
            SET Status = '5', InvoiceBatch = @c_InvoiceBatchKey,
            InvoiceKey = B.InvoiceKey, InvoiceDate = GetDate(),
            EditWho = sUser_sName(), EditDate = GetDate()
            FROM BILL_ACCUMULATEDCHARGES B
            WHERE B.AccumulatedChargesKey = ACCUMULATEDCHARGES.AccumulatedChargesKey
            AND B.InvoiceBatch = @c_InvoiceBatchKey
            AND B.TrafficCop = 'N'
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 OR @n_chargesretrieved <> @n_cnt
            BEGIN
               ROLLBACK TRANSACTION
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update back to AccumulatedCharges Failed (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         ELSE IF @b_debug = 1
            BEGIN
               SELECT 'Updated AccumulatedCharges: ', @n_cnt,'Total', @n_totcharges, 'Elapsed',DateDiff(ss,@dt,GetDate()), '@n_chargesretrieved',@n_chargesretrieved
               SELECT @dt = GetDate()
            END
         END
         IF @n_continue in (1,2)
         BEGIN
            INSERT INTO AccumulatedCharges
            (AccumulatedChargesKey, Descrip, Status, PrintCount, ServiceKey, StorerKey, Sku, Lot, UOMShow,
            TariffKey, TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits, SystemGeneratedCharge,
            Debit, Credit, BilledUnits, ChargeType, LineType, BillFromDate, BillThruDate, SourceKey,
            SourceType, AccessorialDetailKey, GLDistributionKey, InvoiceBatch, InvoiceKey, InvoiceDate,
            CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits, CostSystemGeneratedCharge, Cost,
            EditWho)
            SELECT AccumulatedChargesKey,
            Descrip, Status, PrintCount, ServiceKey, StorerKey, Sku, Lot, UOMShow,
            TariffKey, TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits, SystemGeneratedCharge,
            Debit, Credit, BilledUnits, ChargeType, LineType, BillFromDate, BillThruDate,
            SourceKey, SourceType, AccessorialDetailKey, GLDistributionKey, InvoiceBatch, InvoiceKey, GetDate(),
            CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits, CostSystemGeneratedCharge, Cost,
            sUser_sName()
            FROM Bill_AccumulatedCharges
            WHERE InvoiceBatch = @c_InvoiceBatchKey
            AND TrafficCop is NULL
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               ROLLBACK TRANSACTION
               SELECT @n_continue = 3
               SELECT @n_totcharges = 0, @n_totinvoices = 0
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ROLLBACK.Insert back to AccumulatedCharges Failed (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         ELSE
            BEGIN
               IF (Select count(1) FROM AccumulatedCharges
               WHERE InvoiceBatch = @c_InvoiceBatchKey) <> @n_totcharges
               BEGIN
                  ROLLBACK TRANSACTION
                  SELECT @n_continue = 3
                  SELECT @n_totcharges = 0, @n_totinvoices = 0
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ROLLBACK. Not all the charges saved. (nspBillingRun)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            ELSE
               BEGIN
                  COMMIT TRANSACTION
                  IF @b_debug in (1,2)
                  BEGIN
                     SELECT 'Inserted AccumulatedCharges:', @n_cnt, 'Total', @n_totcharges, 'Elapsed' ,DateDiff(ss,@dt,GetDate())
                     SELECT 'COMMITED at:',GetDate()
                     PRINT ' '
                  END
               END
            END
         END
      END
      IF @b_lockset = '1'
      BEGIN
         IF @n_totcharges <= 0 OR @b_success = 0 OR @n_continue in (3,4)
         BEGIN
            UPDATE STORERBILLING
            SET LockBatch = ' ', LockWho = ' '
            WHERE LockBatch = @c_invoicebatchkey
         END
      END
      IF @n_continue = 3
      BEGIN
         SELECT @b_success = 0
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspBillingRun"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      END
   ELSE
      BEGIN
         SELECT @b_success = 1
      END
   END


GO