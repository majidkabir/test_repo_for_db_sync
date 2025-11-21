SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCalculateRSCharges                              */
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

CREATE PROCEDURE [dbo].[nspCalculateRSCharges] (
@c_BillingGroupMin     NVARCHAR(15) ,
@c_BillingGroupMax     NVARCHAR(15) ,
@c_chargetypes      NVARCHAR(250),
@dt_CutOffDate      datetime ,
@c_InvoiceBatchKey  NVARCHAR(10) ,
@b_Success          int       OUTPUT,
@n_err              int       OUTPUT,
@c_errmsg           NVARCHAR(250) OUTPUT,
@n_totcharges       int       OUTPUT
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_cnt int              ,    /* variable to hold @@ROWCOUNT */
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug mode
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_err2=0
   /* #INCLUDE <SPCRSC1.SQL> */
   DECLARE   @b_pendingcharges   int,
   @n_rsperiod              int,
   @n_nocurrentcharges      int,
   @n_nobilllots            int,
   @n_invnumcount           int,
   @n_nonewcharges          int,
   @n_accumulatedchargekey  int,
   @n_num_recs              int,
   @d_taxrate          decimal(8,7),
   @c_cutoffdate       NVARCHAR(20),
   @c_storerkey        NVARCHAR(15),
   @c_laststorerkey    NVARCHAR(15),
   @c_tariffkey        NVARCHAR(10),
   @c_lasttariffkey    NVARCHAR(10),
   @c_periodtype       NVARCHAR(10),
   @c_invnumstrategy   NVARCHAR(10),
   @c_invoicekey       NVARCHAR(10),
   @c_invoicebatch          NVARCHAR(10),
   @c_taxgroupkey           NVARCHAR(10),
   @c_taxdescrip            NVARCHAR(30),
   @c_taxgldistkey          NVARCHAR(10),
   @c_accumulatedchargekey  NVARCHAR(10),
   @c_curaccumchargekey     NVARCHAR(10),
   @dt_rs_billdate          datetime,
   @dt_anniversarystartdate datetime,
   @dt_lotbillthrudate datetime,
   @dt_minbillthrudate datetime,
   @dt_DateMin         datetime,
   @dt_DateMax         datetime,
   @dt_bfdate          datetime,
   @dt_curbillthrudate datetime,
   @dt_billfrom        datetime,
   @dt_billthru        datetime,
   @dt_lastbillfrom    datetime,
   @c_loopnumber       NVARCHAR(10),
   @c_SplitMonthused   NVARCHAR(1),
   @n_x                int,
   @c_captureendofmonth NVARCHAR(1)
   DECLARE @dt_starttime datetime, @dt_elapsed datetime, @c_user NVARCHAR(60)
   SELECT @dt_starttime = getdate(), @b_debug = 0, @c_user = sUser_sName()
   IF CHARINDEX('DS_RS', @c_errmsg) > 0
   BEGIN
      SELECT @b_debug = Convert(int, Substring(@c_errmsg, CHARINDEX('DS_RS', @c_errmsg) + 5, 1) )
      IF @b_debug not in (0,1,2,3)
      BEGIN
         SELECT @b_debug = 0
      END
   END
   IF dbo.fnc_RTrim(@c_chargetypes) <> 'RS'
   BEGIN
      SELECT @c_chargetypes = 'RS'
   END
   SELECT @c_chargetypes = "(N'" + dbo.fnc_RTrim(@c_chargetypes) + "')"
   IF @b_debug in (1, 2, 3)
   BEGIN
      SELECT 'Started' = @dt_starttime, 'ChargeType'=convert(char(20), dbo.fnc_RTrim(@c_chargetypes)),
      '@c_BillingGroupMin'=@c_BillingGroupMin, '@c_BillingGroupMax'=@c_BillingGroupMax , '@dt_CutOffDate'=@dt_CutOffDate
   END
   SELECT    @dt_CutOffDate =
   Convert(Datetime, Convert(char(10), DateAdd(dd, 1, @dt_CutOffDate), 101)),
   @b_pendingcharges = 0,
   @n_totcharges = -1
   IF @c_BillingGroupMin = @c_BillingGroupMax
   SELECT @c_StorerKey = @c_BillingGroupMin
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug in (1, 2)
      BEGIN
         SELECT 'Select Billable RS Lots',
         'Time from Start' = DateDiff(ss, @dt_starttime, getdate())
      END
      SELECT    A.storerkey, A.sku, B.stdgrosswgt, B.stdcube, C.lot, C.tariffkey, C.lotbillthrudate,
      C.anniversarystartdate, D.captureendofmonth,
      D.rsperiodtype, D.recurringstorageperiod, E.descrip, E.taxgroupkey, E.gldistributionkey,
      E.rate, E.base, E.masterunits, E.uomshow, E.tariffdetailkey, E.roundmasterunits,
      E.costrate, E.costbase, E.costmasterunits, E.costuomshow
      INTO      #BillRSLots
      FROM      lot A, sku B, lotxbilldate C, tariff D, tariffdetail E, StorerBilling F
      WHERE     (A.sku = B.sku) and
      (A.storerkey = B.storerkey) and
      (A.lot = C.lot) and
      (C.tariffkey = D.tariffkey) and
      (D.tariffkey = E.tariffkey) and
      (dbo.fnc_RTrim(E.chargetype) = 'RS') and
      (A.storerkey = F.StorerKey) and
      (F.BillingGroup >= @c_BillingGroupMin) and
      (F.BillingGroup <= @c_BillingGroupMax) and
      (C.LotBillThruDate < DateAdd(mi, -1, @dt_cutoffdate))
      SELECT @n_err = @@ERROR, @n_nobilllots = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86803
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Getting Billable RS Lots. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (1,2,3)
      BEGIN
         SELECT '#BillRsLots - Rows' = @n_nobilllots, 'Time from Start' = DateDiff(ss, @dt_starttime, getdate())
         IF @b_debug = 2 and @n_nobilllots > 0
         BEGIN
            PRINT ' '
            PRINT '   >>> #BillRsLots '
            SELECT * from #BillRsLots
         END
      END
      IF @n_nobilllots = 0
      BEGIN
         SELECT @n_nonewcharges = 0
         SELECT @n_continue = 4 -- No Billable RS Lots
         SELECT @c_errmsg="No Billable RS Lots Found. (nspCalculateRSCharges)"
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug in (1, 2, 3)
      BEGIN
         SELECT 'Running Bill_StockMovement', 'Time from Start' = DateDiff(ss, @dt_starttime, getdate())
         SELECT @dt_elapsed = getdate()
      END
      SELECT @dt_DateMax = DateAdd(mi, -1, @dt_cutoffdate)
      SELECT @dt_elapsed = getdate()
      SELECT    BillFrom=LotBillThruDate, Lot
      INTO      #StockMoveDates
      FROM      #BillRSLots
      WHERE 1=2
      INSERT #StockMoveDates (BillFrom, Lot)
      SELECT DISTINCT DateAdd(mi, 1, LotBillThruDate), Lot
      FROM #BillRSLots
      SELECT DateMin = BillFrom, BFdate = DateAdd(dd, -1, BillFrom), Lot = Lot
      INTO   #BillMinDatesByLot
      FROM   #StockMoveDates
      DECLARE @dt datetime
      SELECT @dt = DateAdd(dd,1,@dt_DateMax), @dt_elapsed = getdate()
      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1
         SELECT @dt = BillFrom, @dt_rs_billdate = BillFrom
         FROM #StockMoveDates
         WHERE BillFrom < @dt
         and BillFrom <= @dt_DateMax
         ORDER BY BillFrom desc
         SELECT @n_cnt = @@ROWCOUNT
         SET ROWCOUNT 0
         IF @n_cnt = 0 BREAK
         WHILE (@dt_rs_billdate < DateAdd(dd, -1, @dt_DateMax) )
         BEGIN
            INSERT INTO #StockMoveDates (BillFrom, Lot)
            SELECT DateAdd(dd, 1, @dt_rs_billdate), Lot
            FROM #StockMoveDates
            WHERE BillFrom = @dt
            SELECT @dt_rs_billdate = DateAdd(dd, 1, @dt_rs_billdate)
         END
      END
      IF @b_debug in (1, 2)
      BEGIN
         print ' '
         SELECT '@dt_DateMax' = @dt_DateMax
         SELECT 'Rows in #BillMinDatesByLot' = count(*) From #BillMinDatesByLot
         SELECT 'Rows in #StockMoveDates' = count(*) From #StockMoveDates
      END
      IF @b_debug = 2
      BEGIN
         print ' '
         print '>>> #BillMinDatesByLot'
         SELECT * from #BillMinDatesByLot ORDER BY Lot
         print ' '
         print '>>> #StockMoveDates'
         SELECT * from #StockMoveDates ORDER BY Lot, BillFrom
      END
      IF @b_debug in (3)
      BEGIN
         SELECT '4', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF @b_debug in (3)
         BEGIN
            SELECT 'Get Inventory Cut', 'Time from Start' = DateDiff(ss, @dt_starttime, getdate())
            SELECT @dt_elapsed = getdate()
         END
         SELECT StorerKey, Sku, A.Lot, Qty, TranType,
         EffectiveDate = (CASE WHEN Qty > 0
         THEN convert(datetime,convert(char(10),EffectiveDate,101) )
      ELSE DateAdd(dd,1,convert(datetime,convert(char(10),EffectiveDate,101) ))
      END )
      INTO   #INVENTORY_CUT1
      FROM   ITRN A, #BillMinDatesByLot B
      WHERE  A.Lot = B.Lot
      AND  A.EffectiveDate <= @dt_DateMax
      AND  A.TranType IN ("DP", "WD", "AJ")
      SELECT @n_err = @@ERROR, @n_num_recs = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86806
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Getting Inventory Cut. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 1', DateDiff(ss, @dt_elapsed, getdate()), '#Lot'=count(distinct lot) from #INVENTORY_CUT1
         SELECT @dt_elapsed = getdate()
      END
   END
   IF (@n_continue=1 or @n_continue=2) and @n_num_recs > 0
   BEGIN
      INSERT    #INVENTORY_CUT1
      SELECT    StorerKey, Sku, a.Lot, ArchiveQty, TranType = "DP",
      convert(datetime,convert(char(10),ArchiveDate,101) )
      FROM      LOT A, #BillMinDatesByLot B
      WHERE     A.ArchiveQty > 0
      AND     A.Lot = B.Lot
      AND EXISTS (SELECT 1 FROM #INVENTORY_CUT1 C
      WHERE c.LOT = a.LOT and a.ArchiveDate < b.DateMin)
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 2', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86807
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Truncating Billing_Summary_Cut.. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         SELECT    StorerKey, Sku, A.Lot, Qty=SUM(Qty), EffectiveDate=b.BFdate,
         flag="AA", TranType ="          ", RunningTotal=SUM(Qty)
         INTO #BILLING_SUMMARY_CUT
         FROM #INVENTORY_CUT1 A, #BillMinDatesByLot B
         WHERE A.Lot = B.Lot
         AND A.EffectiveDate < B.DateMin
         GROUP BY StorerKey, Sku, A.Lot, b.BFdate
         SELECT @n_err = @@ERROR, @n_num_recs = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86810
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Selecting OpenBal (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 3', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF (@n_continue=1 or @n_continue=2) and @n_num_recs=0
   BEGIN
      INSERT    #BILLING_SUMMARY_CUT
      SELECT    StorerKey, Sku, A.Lot, QTY= 0, EffectiveDate = B.BFdate,
      Flag="BB", TranType="          ", RunningTotal=0 --, @c_user
      FROM      #INVENTORY_CUT1 A, #BillMinDatesByLot B
      WHERE     A.Lot = B.Lot
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86811
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting Billing Cut 1 (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 4', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF (@n_continue=1 or @n_continue=2) and @n_num_recs > 0
   BEGIN
      SELECT    StorerKey, Sku, A.Lot --, qty=0, EffectiveDate = B.BFdate,
      INTO      #ListBetweenDates
      FROM      #INVENTORY_CUT1 A, #BillMinDatesByLot B
      WHERE A.Lot = B.Lot
      and (EffectiveDate BETWEEN B.DateMin and @dt_DateMax)
      GROUP BY StorerKey, Sku, A.Lot
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86812
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting #BF_TEMP3 (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 5', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF (@n_continue=1 or @n_continue=2) and @n_num_recs > 0
   BEGIN
      SELECT    StorerKey, Sku, Lot --, qty=0, EffectiveDate = @dt_bfDate,
      INTO      #ListNoBefore
      FROM      #ListBetweenDates a
      WHERE NOT EXISTS
      (SELECT 1 from #BILLING_SUMMARY_CUT b
      WHERE     a.StorerKey = b.StorerKey and
      a.Sku = b.Sku and
      a.Lot = b.Lot)
      SELECT @n_err = @@ERROR, @n_num_recs = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86813
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting #ListNoBefore (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 6', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF (@n_continue=1 or @n_continue=2) and @n_num_recs > 0
   BEGIN
      INSERT    #BILLING_SUMMARY_CUT
      SELECT    StorerKey, Sku, A.Lot, Qty = 0, EffectiveDate = B.BFdate, flag="BB",
      TranType = "          ", RunningTotal = 0 --, @c_user
      FROM      #ListNoBefore A, #BillMinDatesByLot B
      WHERE A.Lot = B.Lot
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86814
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting Billing Cut 2 (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 7', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      INSERT    #BILLING_SUMMARY_CUT
      SELECT    StorerKey, Sku, a.Lot, Qty = sum(Qty), EffectiveDate,
      "  ",  TranType = 'XX', 0 --, @c_user
      FROM      #INVENTORY_CUT1 A, #BillMinDatesByLot B
      WHERE  A.Lot = B.Lot
      and EffectiveDate BETWEEN B.DateMin AND @dt_DateMax
      GROUP BY StorerKey, Sku, a.Lot, EffectiveDate
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86815
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting Billing Cut 3 (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 8', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DELETE Bill_StockMovement WHERE AddWho = @c_user
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86816
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Truncating Bill_StockMovement (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      CREATE INDEX ind_#StockMoveDates_Lot
      ON #StockMoveDates (Lot)
      INSERT  Bill_StockMovement (StorerKey, Sku, Lot, EffectiveDate,AddWho, Qty)
      SELECT  A.StorerKey, A.Sku, A.Lot, EffectiveDate=B.BillFrom, @c_user,
      Qty = (SELECT sum(qty) FROM #Billing_Summary_Cut
      WHERE  StorerKey = A.StorerKey and
      Sku = A.Sku and
      Lot = A.Lot and
      EffectiveDate <= B.BillFrom)
      FROM      #BillRSLots A, #StockMoveDates B
      WHERE     A.Lot = B.Lot
      GROUP BY A.Storerkey, A.Sku, A.Lot, B.BillFrom
      ORDER BY A.Lot, B.BillFrom
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86817
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Creating Bill_StockMovement (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @b_debug in (3)
      BEGIN
         SELECT 'Block 9a', DateDiff(ss, @dt_elapsed, getdate())
         SELECT @dt_elapsed = getdate()
      END
   END
   IF @b_debug in (1,2,3)
   BEGIN
      SELECT 'Ran Bill_StockMovement for ' = @c_storerkey,
      'Time from Start' = DateDiff(ss, @dt_starttime, getdate()),
      'Bill_StockMovement - Rows ' = @n_cnt
   END
   IF @b_debug = 2
   BEGIN
      PRINT ' '
      PRINT ' >>> Bill_StockMovement '
      SELECT * from Bill_StockMovement
   END
END -- Get Bill_StockMovement
DECLARE_RS_CURSOR:
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @dt_elapsed = getdate()
   EXECUTE ("DECLARE Cursor_BillableRS CURSOR FOR
   SELECT    StorerKey, TariffKey, LotBillThruDate, AnniversaryStartDate,
   RSPeriodType, RecurringStoragePeriod, CaptureEndOfMonth
   FROM      #BillRSLots
   GROUP BY StorerKey, TariffKey, LotBillThruDate, AnniversaryStartDate,
   RSPeriodType, RecurringStoragePeriod, CaptureEndOfMonth
   ORDER BY StorerKey, TariffKey, LotBillThruDate, AnniversaryStartDate")
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err = 16915 /* Cursor Already Exists So Close, Deallocate And Try Again! */
   BEGIN
      CLOSE Cursor_BillableRS
      DEALLOCATE Cursor_BillableRS
      GOTO DECLARE_RS_CURSOR
   END
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86804
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Declaring Cursor for Billable RS Lots. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   IF @b_debug in (3)
   BEGIN
      SELECT 'Declare cursor', DateDiff(ss, @dt_elapsed, getdate())
      SELECT @dt_elapsed = getdate()
   END
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   OPEN Cursor_BillableRS
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err = 16905 /* Cursor Already Opened! */
   BEGIN
      CLOSE Cursor_BillableRS
      DEALLOCATE Cursor_BillableRS
      GOTO DECLARE_RS_CURSOR
   END
   IF @@Cursor_Rows = 0 or @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86804
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Opening Cursor BillableRS.. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      DEALLOCATE Cursor_BillableRS
   END
   IF @b_debug in (3)
   BEGIN
      SELECT 'Open cursor', DateDiff(ss, @dt_elapsed, getdate())
      SELECT @dt_elapsed = getdate()
   END
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   FETCH NEXT FROM Cursor_BillableRS INTO
   @c_storerkey,
   @c_tariffkey,
   @dt_lotbillthrudate,
   @dt_anniversarystartdate,
   @c_periodtype,
   @n_rsperiod,
   @c_captureendofmonth
   SELECT @n_err = @@ERROR
   IF @n_err <> 0 or @@FETCH_STATUS = -2
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86805
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Fetching First Row from Cursor BillableRS. (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      CLOSE Cursor_BillableRS
      DEALLOCATE Cursor_BillableRS
   END
   IF @b_debug in (3)
   BEGIN
      SELECT 'Fetch first', DateDiff(ss, @dt_elapsed, getdate())
      SELECT @dt_elapsed = getdate()
   END
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   SELECT @c_laststorerkey = '', @c_lasttariffkey = '', @c_loopnumber = '0'
   DELETE Bill_AccumulatedCharges WHERE AddWho = @c_user
   SELECT    StorerKey, TariffKey,
   BillFrom=LotBillThruDate, BillThru=LotBillThruDate,
   LotBillThruDate=LotBillThruDate, AnniversaryStartDate = AnniversaryStartDate
   INTO      #RSBillDates
   FROM      #BillRSLots
   WHERE     (1=0)
   WHILE (@@Fetch_status <> -1)
   BEGIN
      SELECT @c_loopnumber = Convert(char(9), Convert(int, @c_loopnumber) + 1)
      SELECT @c_periodtype = dbo.fnc_RTrim(@c_periodtype), @c_tariffkey = dbo.fnc_RTrim(@c_tariffkey), @c_storerkey = dbo.fnc_RTrim(@c_storerkey)
      IF @b_debug in (1,2)
      BEGIN
         PRINT ' '
         SELECT 'Starting Bill Loop #' = @c_loopnumber,
         'Time from Start' = DateDiff(ss, @dt_starttime, getdate()),
         'StorerKey' = @c_storerkey, '@c_tariffkey'=@c_tariffkey,
         '@dt_lotbillthrudate'=@dt_lotbillthrudate, 'AnnivStartDate' = @dt_anniversarystartdate,
         '@c_periodtype'=@c_periodtype,
         '@n_rsperiod'=@n_rsperiod, '@c_laststorerkey'=@c_laststorerkey
      END
      IF @c_periodtype in ( 'A', 'F', 'C', 'S') and (@n_continue=1 or @n_continue=2)
      BEGIN
         SELECT @dt_rs_billdate = DateAdd(mi, 1, @dt_lotbillthrudate),
         @n_x = 0, @dt_curbillthrudate = @dt_rs_billdate
         WHILE (@dt_rs_billdate < @dt_cutoffdate)
         BEGIN
            IF @c_periodtype = 'A'
            BEGIN
               WHILE @dt_curbillthrudate <= @dt_rs_billdate
               BEGIN
                  SELECT @n_x = @n_x + 1
                  IF @c_captureendofmonth = '0'
                  SELECT @dt_curbillthrudate = DateAdd(mi,1,DateAdd(mm, @n_x, DateAdd(mi,-1,@dt_anniversarystartdate)))
               ELSE
                  SELECT @dt_curbillthrudate = DateAdd(dd,-1,DateAdd(mm, @n_x, DateAdd(dd,1,@dt_anniversarystartdate)))
               END
            END
            IF @c_periodtype = 'F'
            BEGIN
               SELECT @dt_curbillthrudate = DateAdd(dd, @n_rsperiod, @dt_rs_billdate)
            END
            IF @c_periodtype = 'S'
            BEGIN
               SELECT @dt_curbillthrudate = Convert(datetime,
               convert(varchar, Datepart(mm,DateAdd(mm, 1, @dt_rs_billdate)))
               + '/1/' +
               convert(varchar, Datepart(yy,DateAdd(mm, 1, @dt_rs_billdate))))
            END
            IF @c_periodtype = 'C'
            BEGIN
               SELECT @dt_curbillthrudate = Min( DateAdd(dd, 1, C.PeriodEnd) )
               FROM  CalendarDetail C, Tariff T
               Where T.TariffKey = @c_tariffkey and
               T.CalendarGroup = C.CalendarGroup and
               C.Periodend >= @dt_rs_billdate
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0 -- or @n_cnt <> 1 or @dt_curbillthrudate is null
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86820
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error getting Calendar dates for tariff "+ @c_tariffkey + " (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END
            ELSE IF @n_cnt <> 1 or @dt_curbillthrudate is null
               BEGIN
                  SELECT @dt_curbillthrudate = Convert(datetime,
                  convert(varchar, Datepart(mm,DateAdd(mm, 1, @dt_rs_billdate)))
                  + '/1/' +
                  convert(varchar, Datepart(yy,DateAdd(mm, 1, @dt_rs_billdate))))
                  IF @c_SplitMonthUsed <> '1' SELECT @c_SplitMonthUsed = '1'
               END
            END
            INSERT INTO #RSBillDates (StorerKey, TariffKey, BillFrom, BillThru, LotBillThruDate, AnniversaryStartDate)
            VALUES (@c_storerkey, @c_tariffkey,
            @dt_rs_billdate, DateAdd(mi, -1, @dt_curbillthrudate),
            @dt_lotbillthrudate, @dt_anniversarystartdate)
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 or @n_cnt <> 1 or @dt_curbillthrudate is null
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86821
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting #RSBillDates (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               BREAK
            END
            SELECT @dt_rs_billdate = @dt_curbillthrudate
         END -- while dates loop
         IF @c_SplitMonthUsed = '1'
         BEGIN
            UPDATE #BillRSLots
            SET Descrip = dbo.fnc_RTrim(Descrip) + ' by Split Month Period Type'
            WHERE StorerKey = @c_storerkey
            and TariffKey = @c_tariffkey
            and LotBillthruDate = @dt_lotbillthrudate
         END
         IF @b_debug = 2
         BEGIN
            print ' >> #RSBillDates '
            SELECT * from #RSBillDates
            print ' '
            print ' >> #BillRSLots by current StorerKey/Tariff/LotBillThruDate'
            SELECT count(*) from #BillRSLots
            where StorerKey = @c_storerkey and TariffKey = @c_tariffkey
            and LotBillThruDate = @dt_lotbillthrudate
         END
      END -- Calculate Billing Dates
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT    @c_laststorerkey = @c_storerkey
         SELECT    @c_lasttariffkey = @c_tariffkey
         FETCH NEXT FROM Cursor_BillableRS INTO
         @c_storerkey,
         @c_tariffkey,
         @dt_lotbillthrudate,
         @dt_anniversarystartdate,
         @c_periodtype,
         @n_rsperiod,
         @c_captureendofmonth
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 or @@FETCH_STATUS = -2
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86823
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Fetching Row from Cursor BillableRS (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            CLOSE Cursor_BillableRS
            DEALLOCATE Cursor_BillableRS
         END
      END
      IF @n_continue = 3 BREAK
   END -- Billing Cursor Fetch Loop
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF @b_debug in (1,2,3)
   BEGIN
      SELECT ' Dates Generated,s ',DateDiff(ss,@dt_elapsed,getdate()), 'Time from Start', DateDiff(ss, @dt_starttime, getdate())
      SELECT @dt_elapsed = getdate()
   END
   CLOSE Cursor_BillableRS
   DEALLOCATE Cursor_BillableRS
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   INSERT INTO Bill_AccumulatedCharges
   (AccumulatedChargesKey, Descrip, Status, PrintCount, ServiceKey, StorerKey, Sku, Lot,
   UOMShow, TariffKey, TariffDetailKey, TaxGroupKey, Rate, Base, MasterUnits,
   SystemGeneratedCharge, Debit, Credit, BilledUnits, ChargeType, LineType, BillFromDate,
   BillThruDate, SourceKey, SourceType, AccessorialDetailKey, GLDistributionKey,
   InvoiceBatch, InvoiceKey,
   CostRate, CostBase, CostMasterUnits, CostUOMShow, CostUnits)
   SELECT ('R' + @c_loopnumber),
   (CASE WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt > A.stdcube)
   THEN (dbo.fnc_RTrim(A.Descrip) + ' by Weight')
   WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt <= A.stdcube and A.stdcube > 0.0)
   THEN (dbo.fnc_RTrim(A.Descrip) + ' by Cube')
ELSE A.Descrip END ),
   '5', 0, 'XXXXXXXXXX', A.StorerKey, A.Sku, A.Lot, A.UOMShow, A.TariffKey,
   A.TariffDetailKey, A.TaxGroupKey, A.Rate, A.Base, A.MasterUnits,
   1.1,                                                        -- SystemGeneratedCharge
   1.1,                                                        -- Debit
   0.0,                                                        -- Credit
   (CASE                                                       -- BilledUnits and modified by Ken on 4/2/1999
   WHEN (dbo.fnc_RTrim(A.Base) = 'Q') and
   (A.Roundmasterunits IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(Ceiling(C.Qty * 1 / A.MasterUnits)))
   WHEN (dbo.fnc_RTrim(A.Base) = 'Q') and
   (A.Roundmasterunits NOT IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * 1 / A.MasterUnits))
   WHEN (dbo.fnc_RTrim(A.Base) = 'G') and
   (A.Roundmasterunits IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Ceiling(Convert(dec(12,6), A.stdgrosswgt) / A.MasterUnits)))
   WHEN (dbo.fnc_RTrim(A.Base) = 'G') and
   (A.Roundmasterunits NOT IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Convert(dec(12,6), A.stdgrosswgt) / A.MasterUnits))
   WHEN (dbo.fnc_RTrim(A.Base) = 'C') and
   (A.Roundmasterunits IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Ceiling(Convert(dec(12,6), A.stdcube) / A.MasterUnits)))
   WHEN (dbo.fnc_RTrim(A.Base) = 'C') and
   (A.Roundmasterunits NOT IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Convert(dec(12,6), A.stdcube) / A.MasterUnits))
   WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt > A.stdcube) and
   (A.Roundmasterunits IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Ceiling(Convert(dec(12,6), A.stdgrosswgt) / A.MasterUnits)))
   WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt > A.stdcube) and
   (A.Roundmasterunits NOT IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Convert(dec(12,6), A.stdgrosswgt) / A.MasterUnits))
   WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt <= A.stdcube) and
   (A.Roundmasterunits IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Ceiling(Convert(dec(12,6), A.stdcube) / A.MasterUnits)))
   WHEN (dbo.fnc_RTrim(A.Base) = 'R' and A.stdgrosswgt <= A.stdcube) and
   (A.Roundmasterunits NOT IN ('TRUE', 'T', '1', 'Y', 'YES'))
   THEN convert(dec(12,6),(C.Qty * Convert(dec(12,6), A.stdcube) / A.MasterUnits))
   WHEN (dbo.fnc_RTrim(A.Base) = 'P')
   THEN convert(dec(12,6),(SELECT Count(1)
   FROM LOTxLOCxID D (nolock)
   WHERE D.StorerKey = A.StorerKey
   and D.Sku = A.Sku
   and D.Lot = A.Lot
   and D.ID <> ""
   and ( D.Qty > 0 or D.QtyExpected > 0 or D.PendingMoveIn > 0) ))
   WHEN (dbo.fnc_RTrim(A.Base) = 'F')
THEN convert(dec(12,6),(1 / A.MasterUnits)) END),
'RS', 'N', B.BillFrom, B.BillThru, '', '', 'XXXXXXXXXX', A.GlDistributionKey,
@c_InvoiceBatchKey, '',
A.CostRate, A.CostBase, A.CostMasterUnits, A.CostUOMShow,
(CASE                                                 -- CostUnits
WHEN (dbo.fnc_RTrim(A.CostBase) = 'F')
THEN 1.0
WHEN (dbo.fnc_RTrim(A.CostBase) = 'Q')
THEN (C.Qty * 1 / A.CostMasterUnits)
WHEN (dbo.fnc_RTrim(A.CostBase) = 'C')
THEN (C.Qty * A.stdcube / A.CostMasterUnits)
WHEN (dbo.fnc_RTrim(A.CostBase) = 'G')
THEN (C.Qty / A.CostMasterUnits) * convert(dec(21,6), A.stdgrosswgt)
WHEN (dbo.fnc_RTrim(A.CostBase) = 'R' and A.stdgrosswgt > A.stdcube)
THEN (C.Qty / A.CostMasterUnits) * convert(dec(21,6), A.stdgrosswgt)
WHEN (dbo.fnc_RTrim(A.CostBase) = 'R' and A.stdgrosswgt <= A.stdcube)
THEN (C.Qty / A.CostMasterUnits) * convert(dec(21,6), A.stdcube)
WHEN (dbo.fnc_RTrim(A.CostBase) = 'P')
THEN 1.0    END)
FROM      #BillRSLots A, #RSBillDates B, Bill_StockMovement C
WHERE     (A.StorerKey = B.StorerKey) and
(A.TariffKey = B.TariffKey) and
(A.LotBillthruDate = B.LotBillthruDate) and
(A.AnniversaryStartDate = B.AnniversaryStartDate) and
(A.Lot = C.Lot) and
(B.BillFrom = C.EffectiveDate) and
(C.AddWho = @c_user)
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86822
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting New Accumulated Charges into Bill_AccumulatedCharges (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
IF @b_debug in (3)
BEGIN
   SELECT 'Inserted #',@n_cnt, 'Elapsed,s ',DateDiff(ss, @dt_elapsed, getdate()),'Time from start ',DateDiff(ss, @dt_starttime, getdate())
   SELECT @dt_elapsed = getdate()
END
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
   SELECT @n_nonewcharges = (SELECT count(1) FROM Bill_AccumulatedCharges
   WHERE AccumulatedChargesKey LIKE 'R%'
   AND InvoiceBatch = @c_InvoiceBatchKey)
   EXECUTE nspg_getkey
   'AccumulatedCharges',
   10,
   @c_accumulatedchargekey OUTPUT,
   @b_success OUTPUT,
   @n_err OUTPUT,
   @c_errmsg OUTPUT,
   0,
   @n_nonewcharges
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg="Error Generating AccumulatedChargesKey (nspCalculateRSCharges)"
   END
   IF @b_debug in (1,2) SELECT 'AccumulatedChargesKey' = @c_accumulatedchargekey, '@n_nonewcharges'=@n_nonewcharges
END
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @n_accumulatedchargekey = convert(int, @c_accumulatedchargekey)
   IF @b_debug in (1,2)
   BEGIN
      SELECT 'Updating New Charges', 'Time from Start', DateDiff(ss, @dt_starttime, getdate())
   END
   DECLARE @x int SELECT @x = 0
   UPDATE BILL_ACCUMULATEDCHARGES
   SET AccumulatedChargesKey = RIGHT(Replicate("0",10) + Convert(varchar(10),
   (@n_accumulatedchargekey + @x )), 10),  @x = @x + 1,
   SystemGeneratedCharge = BilledUnits * Rate,
   Debit = BilledUnits * Rate,
   CostSystemGeneratedCharge =  CostUnits*CostRate,
   Cost = CostUnits*CostRate
   WHERE AccumulatedChargesKey LIKE 'R%'
   AND InvoiceBatch = @c_InvoiceBatchKey
   SELECT @n_err = @@ERROR , @n_cnt = @@ROWCOUNT
   IF @n_err <> 0 OR @n_cnt <> @n_nonewcharges
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=86827
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating AccumulatedCharges (nspCalculateRSCharges)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   IF @b_debug in (1,2,3)
   BEGIN
      SELECT 'FINAL UPDATE: #',@n_cnt,'Elapsed,s',DateDiff(ss,@dt_elapsed,getdate()), 'Time from Start,s', DateDiff(ss, @dt_starttime, getdate())
   END
END
/* #INCLUDE <SPCRSC2.SQL> */
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
   execute nsp_logerror @n_err, @c_errmsg, "nspCalculateRSCharges"
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
   BEGIN
      SELECT @b_success = 1
      SELECT @n_totcharges = @n_nonewcharges
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO