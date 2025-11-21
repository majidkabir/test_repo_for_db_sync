SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_smr_by_year_pmtl_01                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/************************************************************************/

CREATE PROC [dbo].[nsp_smr_by_year_pmtl_01] (
@StorerKey      NVARCHAR(15),
@SkuMin    	 NVARCHAR(10),
@SkuMax    	 NVARCHAR(10),
@DateStringMin  NVARCHAR(10),
@DateStringMax  NVARCHAR(10),
@AutoPerson     NVARCHAR(40)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @DateMin datetime
   DECLARE @DateMax datetime
   DECLARE @b_debug int
   DECLARE @n_continue int        ,  /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @n_err int,
   @c_errmsg NVARCHAR(250)

   DECLARE @BFdate DATETIME
   DECLARE @d_end_date DATETIME
   DECLARE @d_begin_date datetime
   DECLARE @n_num_recs int
   DECLARE @n_num_recs_bb  int
   DECLARE @OpeningQty int

   SET NOCOUNT ON
   SELECT @b_debug = 0

   /* String to date convertion */
   SELECT @datemin = CAST (substring(@datestringmin, 4, 2) + "/"+           --month
   substring(@datestringmin, 1, 2) +"/"+            --day
   substring(@datestringmin, 7, 4) AS DATETIME) --year

   SELECT @datemax = CAST ( substring(@datestringmax, 4, 2) + "/"+        --month
   substring(@datestringmax, 1, 2) +"/"+    --day
   substring(@datestringmax, 7, 4) AS DATETIME) --year

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
   SELECT @d_begin_date = Convert( datetime, @DateMin )
   --  SELECT @BFdate = DATEADD(day, -1, convert(datetime, convert(char(10),@datemin,101)))
   --  SELECT @d_end_date =  DATEADD(day, 1, convert(datetime, convert(char(10),@datemax,101)))
   SELECT @BFdate = DATEADD(day, -1, @datemin)
   SELECT @d_end_date = DATEADD(day, 1, @datemax)

   IF @b_debug = 1
   BEGIN
      SELECT @StorerKey,
      @DateMin,
      @DateMax,
      @BFdate,
      @d_end_date
   END

   -- OB + Current Stock Movement from ITRN
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_num_recs = -100 /* initialize */

      SELECT
      a.StorerKey
      , a.sku
      , a.qty
      , a.TranType
      --    , a.EffectiveDate
      , convert(datetime, CONVERT(CHAR, CONVERT(DATETIME, a.Adddate , 101), 101), 101) As EffectiveDate
      , a.ItrnKey
      , sourcekey = CASE SUBSTRING(Sourcetype, 1, 16)
      WHEN 'ntrReceiptDetail' THEN SUBSTRING(a.Sourcekey, 1, 10)
      WHEN 'ntrPickDetailUpd'
      THEN (SELECT ORDERKEY FROM PICKDETAIL (NOLOCK) WHERE Pickdetailkey = a.sourcekey)
   ELSE Sourcekey
   END
   , a.SourceType
   , 0 as distinct_sku
   INTO #ITRN_CUT_BY_SKU_ITT
   FROM itrn a(nolock), sku b(nolock)
   WHERE a.Storerkey = b.Storerkey
   AND a.sku = b.sku
   AND a.StorerKey = @StorerKey
   AND b.sku between @SkuMin AND @SkuMax
   AND a.Adddate < @d_end_date
   AND a.TranType IN ("DP", "WD", "AJ")

   /* This section will eliminate those transaction that is found in ITRN but not found in Orders, Receipt, Adjustment or
   transfer - this code is introduced for integrity purpose between the historical transaction*/
   /*
   AND 1 in ( (SELECT 1 FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10)
   AND (a.sourcetype = 'ntrReceiptDetailUpdate' or
   a.sourcetype = 'ntrReceiptDetailAdd')),

   (SELECT 1 FROM ORDERS(NOLOCK) WHERE ORDERKEY =
   (SELECT orderkey FROM pickdetail WHERE pickdetailkey = SUBSTRING(a.SourceKey,1,10)
   AND a.SourceType = 'ntrPickDetailUpdate')),

   (SELECT 1 FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10)
   AND a.SourceType = 'ntrTransferDetailUpdate' ),

   (SELECT 1 FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10)
   AND a.SourceType = 'ntrAdjustmentDetailAdd'),
   (SELECT 1 WHERE a.sourcekey LIKE 'CC Deposit%'),
   (SELECT 1 WHERE a.sourcekey LIKE 'CC Withdrawal%'),
   (SELECT 1 where a.sourcekey = 'INTIALDP')

   )
   */

   /* This section is pertaining to transfer process, if the from sku and the to sku happen to be the same,
   exclude it out of the report. If the from sku and the to sku is different, include it in the report.
   */


   DECLARE @ikey NVARCHAR(10), @skey NVARCHAR(20), @dd_d int
   DECLARE itt_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
   select ItrnKey, Sourcekey from #ITRN_CUT_BY_SKU_ITT where sourcetype = 'ntrTransferDetailUpdate'

   OPEN itt_cursor
   FETCH NEXT FROM itt_cursor INTO @ikey, @skey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @dd_d = count(DISTINCT sku)
      FROM itrn (NOLOCK)
      WHERE sourcetype = 'ntrTransferDetailUpdate'
      AND substring(sourcekey, 1, 10) = substring(@skey, 1, 10)

      UPDATE #ITRN_CUT_BY_SKU_ITT
      set distinct_sku = @dd_d
      WHERE ITRNKEY = @ikey

      FETCH NEXT FROM itt_cursor INTO @ikey, @skey
   END
   CLOSE itt_cursor
   DEALLOCATE itt_cursor

   /* this is to remove the moving transaction within the same sku */
   DELETE FROM #ITRN_CUT_BY_SKU_ITT where distinct_sku = 1

   -- #15891 (Exclude Cycle Count trx)
   DELETE FROM #ITRN_CUT_BY_SKU_ITT where Sourcetype like 'CC%'

   SELECT storerkey,
   sku,
   qty,
   trantype,
   effectiveDate,
   ItrnKey,
   Sourcekey,
   SourceType
   INTO #ITRN_CUT_BY_SKU
   FROM #ITRN_CUT_BY_SKU_ITT

   SELECT @n_err = @@ERROR
   SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
   IF NOT @n_err = 0
   BEGIN
      SELECT @n_continue = 3
      /* Trap SQL Server Error */
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      /* End Trap SQL Server Error */
   END

   IF @b_debug = 1
   BEGIN
      SELECT '--- #ITRN_CUT_BY_SKU --- '
      SELECT 'OB', sku, sum(qty) FROM #ITRN_CUT_BY_SKU where effectivedate < @BFdate group by sku
      SELECT 'CURR', sku, sum(qty) FROM #ITRN_CUT_BY_SKU where effectivedate between @BFdate and @d_end_date group by sku
   END
END  /* continue and stuff */
-- End - Current Stock Movement by Trx Line


-- OB Archive Qty from SKU
IF @n_continue=1 or @n_continue=2
BEGIN
   IF ( @n_num_recs > 0)
   BEGIN
      INSERT #ITRN_CUT_BY_SKU
      SELECT
      a.StorerKey
      , a.Sku
      , a.ArchiveQty
      , TranType = "OB"
      , @BFDate,
      '',
      '',
      ''
      FROM sku a (nolock)
      WHERE a.archiveqty > 0
      AND EXISTS
      (SELECT * FROM #ITRN_CUT_BY_SKU B
      WHERE a.storerkey = b.storerkey
      AND a.sku = b.sku )

      IF @b_debug = 1
      select 'SKU Archive qty ', * from #itrn_cut_By_sku where trantype = 'OB'
   END
END

/* Calc the OB = ITrn OB + Archive Qty */
/* sum up everything before the @datemin including archive qtys */
SELECT
StorerKey
, SKU = SKU
, QTY = SUM(Qty)
, EffectiveDate = @BFDate
, Flag = "AA"
, TranType = "  "
, RunningTotal = sum(qty)
, Record_number = 0
, Sourcekey =  SPACE(20)
, SourceType = SPACE(30)
INTO   #BF
FROM   #ITRN_CUT_BY_SKU
WHERE  EffectiveDate < @d_begin_date
GROUP BY storerkey, sku /**/

SELECT @n_num_recs = @@rowcount

/* if this is a new product */
/* or the data does not exist for the lower part of the date range */
/* this is to set the opening balance to 0 */
IF @n_continue=1 or @n_continue=2
BEGIN
   IF (@n_num_recs = 0)
   BEGIN
      INSERT #BF
      SELECT
      StorerKey
      , SKU
      , QTY= 0
      , EffectiveDate = @BFDate
      , Flag = "AA"
      , TranType = "  "
      , RunningTotal = 0
      , record_number = 0
      , Sourcekey =  SPACE(20)
      , SourceType = SPACE(30)
      FROM #ITRN_CUT_BY_SKU
      GROUP by StorerKey, SKU
   END /* numrecs = 0 */
END /* for n_continue etc. */

IF @b_debug = 1
select 'BF - ', * from #BF

IF @n_continue=1 or @n_continue=2
BEGIN
   /* pick up the unique set of records which are in the in between period */
   IF (@n_num_recs > 0)
   BEGIN
      SELECT
      StorerKey
      , sku
      , qty = 0
      , EffectiveDate = @BFDate
      , flag="BB"
      , TranType
      , RunningTotal = 0
      , Sourcekey
      INTO #BF_TEMP3
      FROM #ITRN_CUT_BY_SKU
      WHERE (EffectiveDate >= @d_begin_date and EffectiveDate <= @d_end_date)
      GROUP BY StorerKey, sku, Trantype, Sourcekey
      SELECT @n_num_recs = @@rowcount

      SELECT @n_err = @@ERROR
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3 (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   END /* if @n_num_recs > 0 */
END /* continue and stuff */

/*
add only those storerkey, sku and lot combinations which  do not exist in #BF
i.e. there might be some new records after the begin period.
However do not add
storerkey, sku and lot combo which exist before and after the begin period
*/

IF @n_continue=1 or @n_continue=2
BEGIN
   /* pick up the unique set of records which are in the in between period
   which do not exist in the past period */

   /* BB means those unique lot records which fall in between begin_date and end_date
   which do not have history */

   IF (@n_num_recs > 0)
   BEGIN
      SELECT
      StorerKey
      , sku
      , qty = 0
      , EffectiveDate = @BFDate
      , flag="AA"    /* was BB */
      , TranType
      , RunningTotal = 0
      , Sourcekey
      INTO #BF_TEMP3a
      FROM #BF_TEMP3 a
      WHERE NOT exists
      (SELECT * from #BF b
      WHERE a.StorerKey = b.StorerKey
      AND  a.Sku = b.Sku
      )
      SELECT @n_err = @@ERROR
      SELECT @n_num_recs_bb = (SELECT COUNT(*) FROM #BF_TEMP3a)

      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END

      IF @b_debug = 1
      select 'BF_TEMP3A - ', * from #BF_TEMP3a
   END /* if @n_num_recs > 0 */
END /* continue and stuff */

IF @n_continue=1 or @n_continue=2
BEGIN
   IF ( @n_num_recs_bb > 0)
   BEGIN
      INSERT #BF
      SELECT
      StorerKey
      , SKU
      , qty
      , EffectiveDate
      , flag
      , TranType
      , RunningTotal
      , Record_number = 0
      , Sourcekey
      , SPACE(30)
      FROM #BF_TEMP3a

      SELECT @n_err = @@ERROR
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   END

   IF @b_debug = 1
   select 'BF - After INS BF_TEMP3a - ', * from #BF
END /* continue and stuff */

/* ...then add all the data between the requested dates. */
SELECT
StorerKey
, SKU
, Qty
, TrxDate = EffectiveDate
, Flag = "  "
, TranType
, RunningTotal = 0
, record_number = 0
, ISNULL(Sourcekey, "") As Sourcekey
, ISNULL(SourceType, "") As SourceType
INTO #BF2
FROM #ITRN_CUT_BY_SKU
WHERE EffectiveDate >= @d_begin_date

IF (@b_debug = 1)
BEGIN
   SELECT 'BF2 - ', *
   FROM #BF2
   ORDER BY StorerKey
END

INSERT #BF
SELECT
StorerKey
, SKU
, SUM(Qty)
, TrxDate
, flag
, TranType
, RunningTotal = 0
, Record_number = 0
, dbo.fnc_LTrim(dbo.fnc_RTrim(Sourcekey))
, dbo.fnc_LTrim(dbo.fnc_RTrim(Sourcetype))
FROM #BF2
GROUP BY
StorerKey
, TrxDate
, TranType
, SKU
, Sourcetype
, Sourcekey
, flag

IF (@b_debug = 1)
BEGIN
   SELECT	'BF - After Curr trx - ', *
   FROM #BF
   ORDER BY StorerKey
END


/* put the cursor in here for running totals */
/* declare cursor vars */
DECLARE @sku					 NVARCHAR(20)
DECLARE @sourcekey			 NVARCHAR(30)
DECLARE @sourceline			 NVARCHAR(5)
DECLARE @sourcetype			 NVARCHAR(30)
DECLARE @Qty						int
DECLARE @EffectiveDate			datetime
DECLARE @Flag					 NVARCHAR(2)
DECLARE @TranType			 NVARCHAR(10)
DECLARE @RunningTotal			int
DECLARE @prev_StorerKey	 NVARCHAR(15)
DECLARE @prev_sku			 NVARCHAR(10)
DECLARE @prev_Qty				int
DECLARE @prev_EffectiveDate	datetime
DECLARE @prev_Flag			 NVARCHAR(2)
DECLARE @prev_TranType		 NVARCHAR(10)
DECLARE @prev_RunningTotal	int
DECLARE @record_number			int
DECLARE @DocType				 NVARCHAR(12)
DECLARE @DocRef				 NVARCHAR(20)
DECLARE @Label               NVARCHAR(20) -- vicky
DECLARE @ProcessType         NVARCHAR(20) -- vicky
DECLARE @type                NVARCHAR(5)

SELECT @record_number = 1
SELECT @RunningTotal = 0

DELETE #BF2

EXECUTE('DECLARE cursor_for_running_total CURSOR FAST_FORWARD READ_ONLY
FOR  SELECT
StorerKey
, SKU
, Qty
, EffectiveDate
, Flag
, TranType
, Sourcekey
, SourceType
FROM #BF
ORDER BY StorerKey, SKU, EffectiveDate, Trantype')
OPEN cursor_for_running_total

FETCH NEXT FROM cursor_for_running_total
INTO  @StorerKey,
@sku,
@Qty,
@EffectiveDate,
@Flag,
@TranType,
@Sourcekey,
@Sourcetype

WHILE (@@fetch_status <> -1)
BEGIN
   IF (dbo.fnc_RTrim(@TranType) = 'DP' or dbo.fnc_RTrim(@TranType) = 'WD' or
   dbo.fnc_RTrim(@TranType) = 'AJ')
   BEGIN
      SELECT @RunningTotal = @RunningTotal + @qty
   END

   IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
   BEGIN
      /* first calculated  total */
      SELECT @RunningTotal = @qty
      SELECT @Trantype = 'OB'

   END

   IF (@b_debug = 1)
   BEGIN
      select @StorerKey,"|",
      @sku,"|",
      @Qty,"|",
      @EffectiveDate,"|",
      @Flag,"|",
      @TranType,"|",
      CONVERT(NCHAR(20), @Sourcekey), "|",
      @RunningTotal,"|",
      @record_number,"|"
   END

   IF @sourcekey IS NULL SELECT @sourcekey = ""

   INSERT #BF2
   values(
   @StorerKey,
   @sku,
   @Qty,
   @EffectiveDate,
   @Flag,
   @TranType,
   @RunningTotal,
   @record_number,
   @Sourcekey,
   @Sourcetype)

   SELECT @prev_StorerKey = @StorerKey
   select @prev_sku = @sku
   SELECT @prev_qty =  @Qty
   SELECT @prev_flag = @Flag
   SELECT @prev_EffectiveDate = @EffectiveDate
   SELECT @prev_TranType =  @TranType
   SELECT @prev_RunningTotal = @RunningTotal

   FETCH NEXT FROM cursor_for_running_total
   INTO
   @StorerKey,
   @sku,
   @Qty,
   @EffectiveDate,
   @Flag,
   @TranType,
   @Sourcekey,
   @Sourcetype

   SELECT @record_number = @record_number + 1
   IF (@storerkey <> @prev_storerkey)
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         select 'prev_storerkey', @prev_storerkey,
         'prev_sku', @prev_sku
      END

      select @runningtotal = 0
   END
END /* while loop */

close cursor_for_running_total
deallocate cursor_for_running_total

IF (@b_debug = 1)
BEGIN
   select 'B4 RESULT - ',
   StorerKey,
   sku,
   TrxDate,
   qty,
   Flag,
   TranType,
   RunningTotal,
   Record_number,
   sourcekey
   FROM #BF2
   order by storerkey, sku, TrxDate, trantype
END

/* Output the data collected. */
/* summarizing the qty into opening balance, in_qtym out_qty and ending_balance */

SELECT a.StorerKey
, a.sku
, c.RetailSKU  -- SOS15891
--		  , c.descr
, c.BUSR1
, a.TrxDate as TrxDate
, DATEPART(YEAR, a.TrxDate) as EFYear
, RIGHT('0' + dbo.fnc_RTrim(dbo.fnc_LTrim(DATEPART(MONTH, a.TrxDate))), 2) as EFMonth
--		  , CONVERT(CHAR, CONVERT(DATETIME, TrxDate , 101), 101) As TrxDate2
, 0 as o_qty
, 0 as in_qty
, 0 as out_qty
, 0 as bal_qty
, a.TranType
, a.Sourcekey
, a.Sourcetype
, SPACE(12) DocType
, SPACE(20) DocRef
, a.record_number
, SPACE(20) Label -- vicky
, SPACE(5) as type
, SUBSTRING(c.BUSR1,1,2) as sorting
INTO #RESULT
FROM #bf2 a, storer b, sku c (NOLOCK)
WHERE a.storerkey = b.storerkey
AND   a.Storerkey = c.Storerkey
AND	a.Sku = c.Sku
group by a.storerkey, a.SKU, a.TrxDate, a.TranType, a.Sourcetype, a.Sourcekey, c.BUSR1, record_number, c.RetailSKU

IF @b_debug = 1
select 'RESULT -', * from #result

DECLARE @company NVARCHAR(45)
DECLARE @acc_ob int, @in_qty int, @out_qty int, @bal_qty int, @o_qty int, @upd_ob int

SELECT @acc_ob = 0
SELECT @prev_storerkey = SPACE(15)
SELECT @prev_sku = SPACE(20)

DECLARE report_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
select b.Company,
a.StorerKey,
a.SKU,
a.qty,
a.flag,
a.trantype,
a.Sourcekey,
a.Sourcetype,
a.TrxDate
from #bf2 a, storer b (NOLOCK)
where a.storerkey = b.storerkey
ORDER BY a.Storerkey, a.SKU, a.TrxDate, a.Trantype

OPEN report_cursor

FETCH NEXT FROM report_cursor
INTO
@company,
@StorerKey,
@sku,
@Qty,
@Flag,
@TranType,
@Sourcekey,
@Sourcetype,
@EffectiveDate

WHILE (@@fetch_status <> -1)
BEGIN
   SELECT @in_qty = 0
   SELECT @out_qty = 0
   SELECT @o_qty = 0
   SELECT @upd_ob = 0

   if (dbo.fnc_RTrim(@trantype) = 'DP') or (dbo.fnc_RTrim(@Trantype) = 'AJ' and @qty > 0) -- deposit and positive adjustment
   SELECT @in_qty = @qty

   IF (dbo.fnc_RTrim(@TranType) = 'WD') or (dbo.fnc_RTrim(@Trantype) = 'AJ' and @qty < 0) -- withdrawal and negative adjustment
   SELECT @out_qty = @qty

   IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
   SELECT @o_qty = @qty

   IF @prev_storerkey <> @storerkey OR @prev_sku <> @sku
   BEGIN
      SELECT @acc_ob = @o_qty
      SELECT @upd_ob = @acc_ob
      SELECT @Prev_storerkey = @storerkey
      SELECT @prev_sku = @sku
   END
ELSE
   BEGIN
      SELECT @upd_ob = @acc_ob
      SELECT @acc_ob = @acc_ob + @qty
   END

   IF @b_debug = 1
   begin
      select @o_qty, @upd_ob, @in_qty, @out_qty, @acc_ob
   end

   update #RESULT
   set   o_qty = @upd_ob,
   in_qty = in_qty + @in_qty,
   out_qty = out_qty - ( @out_qty ),
   bal_qty = @acc_ob
   where storerkey = @storerkey
   and    sku = @sku
   and    sourcekey = @sourcekey
   and    sourcetype = @sourcetype
   and    trantype = @trantype

   FETCH NEXT FROM report_cursor
   INTO
   @company,
   @StorerKey,
   @sku,
   @Qty,
   @Flag,
   @TranType,
   @Sourcekey,
   @Sourcetype,
   @EffectiveDate
END /* while loop */

close report_cursor
deallocate report_cursor

/* updating balance quantity */
--	update #RESULT
-- set bal_qty = o_qty + in_qty - out_qty

DELETE #RESULT WHERE Trantype = 'OB'

/* output to user */
/*
select Storerkey = Convert(char(15), StorerKey),
Sku = Convert(char(10), sku),
TrxDate = Convert(char(20), TrxDate),
o_qty,
in_qty,
out_qty,
bal_qty,
TranType,
SUBSTRING(Sourcekey, 1, 10) As Sourcekey,
SUBSTRING(Sourcekey, 11, 15) As SourceLine,
DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
userid = Convert(char(20), user_name())
from #RESULT
order by storerkey, sku
*/

Declare Docref_cur CURSOR  FAST_FORWARD READ_ONLY FOR
SELECT   StorerKey,
sku,
TranType,
SUBSTRING(Sourcekey, 1, 10) As Sourcekey,
SUBSTRING(Sourcekey, 11, 15) As SourceLine,
SourceType,
record_number
from #RESULT
order by storerkey, sku, record_number

OPEN Docref_cur

FETCH NEXT FROM Docref_cur INTO
@StorerKey,
@sku,
@TranType,
@Sourcekey,
@sourceline,
@Sourcetype,
@record_number

WHILE (@@fetch_status <> -1)
BEGIN
   SELECT @DocType = '', @DocRef = '' , @Label = '', @type = ''

   IF @TranType = 'DP'
   BEGIN
      -- processing
      IF SUBSTRING(@Sourcetype,1,10) = 'ntrReceipt'
      BEGIN
         -- Modify by Vicky 30 June 2003
         SELECT @ProcessType = RECEIPT.ProcessType
         FROM RECEIPT (NOLOCK)
         WHERE Receiptkey = @Sourcekey

         IF @ProcessType = 'I'
         BEGIN
            SELECT @DocRef = REPLACE(dbo.fnc_LTrim(replace(RECEIPT.WarehouseReference,'0',' ')),' ', '0'), @DocType = ''
            FROM RECEIPT (NOLOCK)
            WHERE Receiptkey = @Sourcekey
         END
      ELSE
         BEGIN
            SELECT DISTINCT @DocType = PO.POType, @DocRef = REPLACE(dbo.fnc_LTrim(replace(PO.ExternPOKey,'0',' ')),' ', '0')
            FROM PO (NOLOCK)
            JOIN RECEIPTDETAIL (NOLOCK) ON (PO.POkey = RECEIPTDETAIL.POKey)
            WHERE Receiptkey = @Sourcekey
         END
      END
   ELSE
      BEGIN
         IF SUBSTRING(@Sourcetype,1,10) = 'CC Deposit'
         BEGIN
            SELECT @DocType = '', @DocRef = REPLACE(dbo.fnc_LTrim(replace(CCSheetNo,'0',' ')),' ', '0')
            FROM CCDETAIL (Nolock)
            WHERE CCDetailKey = @Sourcekey
         END
      ELSE
         BEGIN
            IF SUBSTRING(@Sourcetype,1,11) = 'ntrTransfer'
            BEGIN
               SELECT @DocType = TYPE, @DocRef = ''
               FROM TRANSFER (Nolock)
               WHERE TransferKey = @Sourcekey
            END
         END
      END
   END
ELSE
   BEGIN
      IF @TranType = 'WD'
      BEGIN
         -- processing
         IF SUBSTRING(@Sourcetype,1,7) = 'ntrPick'
         BEGIN
            SELECT @DocType = TYPE, @DocRef = REPLACE(dbo.fnc_LTrim(replace(EXTERNORDERKEY,'0',' ')),' ', '0')
            FROM ORDERS (Nolock)
            WHERE ORDERKEY = @Sourcekey
         END
      ELSE
         BEGIN
            IF SUBSTRING(@Sourcetype,1,13) = 'CC Withdrawal'
            BEGIN
               SELECT @DocType = '', @DocRef = REPLACE(dbo.fnc_LTrim(replace(CCSheetNo,'0',' ')),' ', '0')
               FROM CCDETAIL (Nolock)
               WHERE CCDetailKey = @Sourcekey
            END
         ELSE
            BEGIN
               IF SUBSTRING(@Sourcetype,1,11) = 'ntrTransfer'
               BEGIN
                  SELECT @DocType = TYPE, @DocRef = ''
                  FROM TRANSFER (Nolock)
                  WHERE TransferKey = @Sourcekey
               END
            END
         END
      END
   END

   IF @TranType = 'AJ'
   BEGIN
      SELECT @DocRef = REPLACE(dbo.fnc_LTrim(replace(ADJUSTMENT.CustomerRefNo,'0',' ')),' ', '0'),
      @DocType = AdjustmentType  -- SOS15891
      FROM ADJUSTMENT (NOLOCK)
      WHERE AdjustmentKey = @Sourcekey
   END

   -- Added By Vicky 30th June 2003
   IF @DocType like 'OR-92%'
   BEGIN
      SELECT @Label = 'Invoice #', @type = 'OR'
   END
ELSE
   IF @DocType like 'ZRQB-RQ%'
   BEGIN
      SELECT @Label = 'RQB #', @type = 'ZR'
   END
ELSE
   IF @DocType like 'RE-92%'
   BEGIN
      SELECT @Label = 'CN #', @Type = 'RE'
   END
ELSE
   IF @DocType like 'CR-RQ%' and @ProcessType <> 'I'
   BEGIN
      SELECT @Label = 'RQB #', @type = 'CR'
   END
   IF @TranType = 'AJ'
   BEGIN
      SELECT @Label = 'ADJ #', @type = 'AJ'
   END
   IF @ProcessType = 'I' and @TranType = 'DP'
   BEGIN
      SELECT @Label = 'RR #', @type = 'I'
   END

   -- END Add
   UPDATE #RESULT
   SET DocType = @DocType,
   DocRef =  @DocRef ,
   Label = ISNULL(@Label,''), -- vicky,
   Type = ISNULL(@type, '')
   WHERE Storerkey = @storerkey
   AND Sku = @sku
   AND Sourcekey = Substring(@sourcekey,1,10) + Substring(@sourceline,1,5)
   AND Sourcetype = @sourcetype
   AND Trantype = @trantype
   AND Record_number = @record_number

   FETCH NEXT FROM Docref_cur INTO
   @StorerKey,
   @sku,
   @TranType,
   @Sourcekey,
   @sourceline,
   @Sourcetype,
   @record_number

END -- While loop for searching Doctype, Docref

CLOSE Docref_cur
DEALLOCATE Docref_cur

DELETE FROM #RESULT WHERE Label = ''

-- SOS15891, do not show ADJ where doc type = '99'
DELETE FROM #RESULT WHERE Type = 'AJ' AND DocType = '99'

SELECT   StorerKey,
sku,
RetailSKU, -- SOS15891
EFYear,
EFMonth,
o_qty,
in_qty,
out_qty,
bal_qty,
DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
userid = Convert(NVARCHAR(20), Suser_Sname()),
SUBSTRING(BUSR1,4,30) as BUSR1 ,
0 as FwdInQty,
0 as FwdOutQty,
IDENTITY(int,1,1) as rowid,
record_number,
Label,
sorting
into #TEMPRESULT
FROM #RESULT
order by storerkey, sku, record_number

SELECT   StorerKey,
tr.sku,
tr.RetailSKU,  -- SOS15891
EFYear,
EFMonth,
o_qty,
0 as Inqty,
0 as OutQty,
0 as Balqty,
userid = Convert(NVARCHAR(20), Suser_Sname()),
BUSR1 ,
0 as FwdInQty,
0 as FwdOutQty,
tr.Label,
0 as rrqty,
SPACE(40) as AutoPerson ,
tr.sorting
INTO #RESULT1
from #TEMPRESULT tr
join (select sku, min(rowid) as rowid from #tempresult (nolock) group by sku) tempsku
on (tr.sku = tempsku.sku and tr.rowid = tempsku.rowid)
GROUP BY Storerkey, tr.Sku, o_qty, EFYear, EFMonth, BUSR1, tr.Label, tr.sorting, tr.RetailSKU
order BY Storerkey, tr.Sku, EFYear, EFMonth

SELECT   StorerKey,
tr.sku,
EFYear,
EFMonth,
bal_qty
INTO #RESULT2
from #TEMPRESULT tr
join (select sku, max(rowid) as rowid from #tempresult (nolock) group by sku) temp_sku
on (tr.sku = temp_sku.sku and tr.rowid = temp_sku.rowid)
GROUP BY Storerkey, tr.Sku, bal_qty, EFYear, EFMonth, BUSR1
order BY Storerkey, tr.Sku, EFYear, EFMonth


DECLARE @d_month NVARCHAR(2), @d_year NVARCHAR(4), @n_fwdinqty int, @n_fwdoutqty int, @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20)
DECLARE @suminqty int, @sumoutqty int, @sumbalqty int, @sumrrqty int


DECLARE result_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
SELECT StorerKey,
SKU,
EFYear,
EFMonth
FROM #RESULT1
ORDER BY Storerkey, SKU, EFYear, EFMonth

OPEN result_cursor

FETCH NEXT FROM result_cursor
INTO
@c_StorerKey,
@c_sku,
@d_year,
@d_month


WHILE (@@fetch_status <> -1)
BEGIN

   SELECT @n_fwdinqty = 0, @n_fwdoutqty = 0, @sumrrqty = 0


   IF @d_month = '01'
   BEGIN
      SELECT @n_fwdinqty = 0,
      @n_fwdoutqty = 0
   END
ELSE
   BEGIN
      SELECT @n_fwdinqty  = Convert(int, SKU.BUSR6)
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Sku = @c_sku

      SELECT @n_fwdoutqty  = Convert(int, SKU.BUSR7)
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Sku = @c_sku
   END

   SELECT @suminqty = SUM(in_qty),
   @sumoutqty = SUM(out_qty)
   From #TEMPRESULT (NOLOCK)
   WHERE Storerkey = @c_storerkey
   AND Sku = @c_sku
   AND EFYear = @d_year
   AND EFMonth = @d_month
   AND Label <> 'RR #'
   GROUP BY Storerkey, Sku
   Order BY Storerkey, Sku

   SELECT @sumrrqty = SUM(in_qty)
   From #TEMPRESULT (NOLOCK)
   WHERE Storerkey = @c_storerkey
   AND Sku = @c_sku
   AND EFYear = @d_year
   AND EFMonth = @d_month
   AND Label = 'RR #'
   GROUP BY Storerkey, Sku
   Order BY Storerkey, Sku

   UPDATE #RESULT1
   SET FwdInQty = @n_fwdinqty,
   FwdOutQty = @n_fwdoutqty,
   Inqty = @suminqty,
   Outqty = @sumoutqty,
   rrqty = @sumrrqty
   WHERE Storerkey = @c_StorerKey
   AND Sku = @c_sku
   AND EFYear = @d_year
   AND EFMonth = @d_month

   FETCH NEXT FROM result_cursor
   INTO
   @c_StorerKey,
   @c_sku,
   @d_year,
   @d_month

END /* while loop */

close result_cursor
deallocate result_cursor

UPDATE #RESULT1
SET a.Balqty = b.bal_qty
FROM #RESULT1 a , #RESULT2 b
WHERE a.storerkey = b.storerkey
AND a.sku = b.sku
AND a.EFYear = b.EFYear
AND a.EFMonth = b.EFMonth

Declare @c_nosku NVARCHAR(20), @n_cnt int , @c_nosku1 NVARCHAR(20), @n_archiveqty int, @d_date datetime, @date datetime
Declare @c_nosku2 NVARCHAR(20), @b_qty int, @trxdate datetime, @sdescr NVARCHAR(60), @sdescr2 NVARCHAR(60), @sbusr1 NVARCHAR(30)
Declare @sbusr6 NVARCHAR(30), @sbusr7 NVARCHAR(30), @prevmonth NVARCHAR(2), @prevyear NVARCHAR(4), @prevsku NVARCHAR(20)
Declare @trxyear NVARCHAR(4), @trxmonth NVARCHAR(2), @year NVARCHAR(4), @month NVARCHAR(2), @ncnt int
Declare @busr1 NVARCHAR(30), @busr6 NVARCHAR(30), @busr7 NVARCHAR(30), @sorting NVARCHAR(2), @c_RetailSKU NVARCHAR(20)


Create Table #TEMPSKU1 (
Storerkey NVARCHAR(15) NULL, Sku NVARCHAR(20) NULL,
BUSR1 char (30) NULL, BUSR6 NVARCHAR(30) NULL,
BUSR7 NVARCHAR(30) NULL, Cnt int)

Create Table #TEMPCNT1 (
Storerkey NVARCHAR(15) NULL, Sku NVARCHAR(20) NULL,
BUSR1 char (30) NULL, BUSR6 NVARCHAR(30) NULL,
BUSR7 NVARCHAR(30) NULL, Adddate datetime NULL, Cnt int)

Create Table #R1 (
StorerKey NVARCHAR(15) NULL,
sku NVARCHAR(20) NULL,
RetailSKU NVARCHAR(20) NULL,  -- SOS15891
EFYear NVARCHAR(4) NULL,
EFMonth NVARCHAR(2) NULL,
o_qty int,
Inqty int,
OutQty int,
Balqty int,
DateRange NVARCHAR(50) NULL,
userid NVARCHAR(10) NULL,
BUSR1 NVARCHAR(30) NULL,
FwdInQty int,
FwdOutQty int,
RRQty int,
AutoPerson NVARCHAR(40) NULL,
sorting NVARCHAR(2) NULL )

Create Table #R2 (
StorerKey NVARCHAR(15) NULL,
sku NVARCHAR(20) NULL,
balqty int,
EFYear NVARCHAR(4) NULL,
EFMonth NVARCHAR(2) NULL )

INSERT INTO #TEMPSKU1
SELECT Storerkey, Sku, BUSR1, BUSR6, BUSR7,0 as cnt
FROM SKU (NOLOCK)
WHERE StorerKey = @StorerKey
AND Sku between @SkuMin AND @SkuMax

SELECT @c_nosku = ''
WHILE(1=1)
BEGIN
   SELECT @c_nosku = Min(Sku)
   FROM #TEMPSKU1
   WHERE Sku > @c_nosku


   IF @c_nosku = '' or @c_nosku IS NULL BREAK

   SELECT @d_date = @d_begin_date

   SELECT @n_cnt = COUNT(*)
   FROM ITRN (NOLOCK)
   WHERE StorerKey = @StorerKey
   AND sku = @c_nosku
   AND Adddate >= @d_date and Adddate < @d_end_date
   AND TranType IN ("DP", "WD", "AJ")


   SELECT @sbusr1 = BUSR1, @sbusr6 = BUSR6, @sbusr7 = BUSR7
   FROM #TEMPSKU1
   Where Sku =  @c_nosku
   AND Storerkey = @StorerKey

   INSERT INTO #TEMPCNT1
   SELECT @StorerKey, @c_nosku , @sbusr1, @sbusr6, @sbusr7, @d_date , @n_cnt

   SELECT @d_date = DATEADD(day,1, @d_date)

END -- while


SELECT @prevmonth = '', @prevyear = '', @prevsku = ''

SELECT @c_nosku1 = ''
WHILE(1=1)
BEGIN
   SELECT @c_nosku1 = MIN(Sku)
   FROM #TEMPCNT1
   WHERE Sku > @c_nosku1
   AND Cnt = 0


   IF @c_nosku1 = '' or @c_nosku1 IS NULL BREAK


   SELECT @year = DATEPART(YEAR,Adddate),
   @month = RIGHT('0' + dbo.fnc_RTrim(dbo.fnc_LTrim(DATEPART(MONTH,Adddate))),2),
   @busr1 = BUSR1,
   @busr6 = BUSR6,
   @busr7 = BUSR7
   FROM #TEMPCNT1
   WHERE Sku = @c_nosku1
   AND Storerkey = @StorerKey

   SELECT @sorting = SUBSTRING(BUSR1,1,2),
   @c_retailsku = RetailSKU  -- SOS15891
   FROM 	SKU (NOLOCK)
   WHERE Sku = @c_nosku1
   AND Storerkey = @StorerKey


   IF (@prevsku <> @c_nosku1)
   BEGIN
      IF ( @prevmonth <> @month) or (@prevyear <> @year)
      BEGIN

         INSERT INTO #R1
         SELECT  @StorerKey, @c_nosku1 , @c_retailsku, @year , @month ,
         0 , 0 , 0 , 0 ,  "From " + @DateStringMin + " To "+ @DateStringMax,
         Convert(NVARCHAR(20), Suser_Sname()),@busr1 , @busr6 , @busr7, 0 , '', @sorting

         SELECT @prevmonth = @month, @prevyear = @year, @prevsku = @c_nosku1
      END
   ELSE
      IF ( @prevmonth = @month) or (@prevyear = @year)
      BEGIN

         INSERT INTO #R1
         SELECT  @StorerKey, @c_nosku1 , @c_retailsku, @year , @month ,
         0 , 0 , 0 , 0 ,  "From " + @DateStringMin + " To "+ @DateStringMax,
         Convert(NVARCHAR(20), Suser_Sname()),@busr1 , @busr6 , @busr7 , 0, '', @sorting

         SELECT @prevmonth = @month, @prevyear = @year, @prevsku = @c_nosku1
      END
   END
ELSE
   IF (@prevsku = @c_nosku1)
   BEGIN
      IF ( @prevmonth <> @month) or (@prevyear <> @year)
      BEGIN

         INSERT INTO #R1
         SELECT  @StorerKey, @c_nosku1 , @c_retailsku, @year , @month ,
         0 , 0 , 0 , 0 ,  "From " + @DateStringMin + " To "+ @DateStringMax,
         Convert(NVARCHAR(20), Suser_Sname()),@busr1 , @busr6 , @busr7 , 0, '', @sorting

         SELECT @prevmonth = @month, @prevyear = @year, @prevsku = @c_nosku1
      END
   END
END -- while


SELECT @c_nosku2 = ''
WHILE(1=1)
BEGIN
   SELECT @c_nosku2 = Min(Sku)
   FROM #R1
   WHERE Sku > @c_nosku2

   IF @c_nosku2 = '' or @c_nosku2 IS NULL BREAK

   SELECT @trxyear = EFYear, @trxmonth = EFMonth
   FROM #R1
   WHERE Sku =  @c_nosku2
   AND Storerkey = @storerkey

   SELECT @ncnt = COUNT(*)
   FROM #RESULT1
   WHERE Sku = @c_nosku2
   AND Storerkey = @StorerKey

   IF @ncnt > 0
   BEGIN
      INSERT INTO #R2
      SELECT  storerkey, tr.sku, (o_qty + Inqty - OutQty) , tr.EFYear, tr.EFMonth
      from #RESULT1 tr
      WHERE tr.Sku = @c_nosku2
      AND tr.Storerkey = @StorerKey
      AND tr.EFYear = @trxyear
      AND Convert(int,tr.EFMonth) = Convert(int,@trxmonth) - 1
      GROUP BY Storerkey, tr.Sku, (o_qty + Inqty - OutQty),tr.EFYear, Tr.EFMonth
      order BY Storerkey, tr.Sku, tr.EFYear, Tr.EFMonth
   END
ELSE
   BEGIN
      INSERT INTO #R2
      SELECT  @StorerKey, @c_nosku2, 0 , @trxyear, @trxmonth
   END
END -- sku2


UPDATE #R1
SET r1.O_qty = r2.balqty, r1.balqty = r2.balqty
FROM #R1 r1 , #R2 r2
WHERE r1.storerkey = r2.storerkey
AND r1.sku = r2.sku
AND r1.EFYear = r2.EFYear
AND r1.EFMonth = r2.EFMonth

UPDATE #RESULT1
SET AutoPerson = @AutoPerson

UPDATE #R1
SET AutoPerson = @AutoPerson

SET NOCOUNT OFF

SELECT   StorerKey,
sku,
RetailSKU,
EFYear,
EFMonth,
o_qty,
Inqty,
OutQty,
Balqty,
DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
userid = Convert(NVARCHAR(20), Suser_Sname()),
BUSR1 ,
FwdInQty,
FwdOutQty,
rrqty,
AutoPerson,
sorting
from #RESULT1
UNION ALL
SELECT   StorerKey,
sku,
RetailSKU,  -- SOS15891
EFYear,
EFMonth,
o_qty,
Inqty,
OutQty,
Balqty,
DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
userid ,
BUSR1 ,
FwdInQty,
FwdOutQty,
rrqty,
AutoPerson,
sorting
FROM #R1
ORDER BY Sorting

DROP TABLE #TEMPSKU1
DROP TABLE #TEMPCNT1
DROP TABLE #R1
DROP TABLE #R2

END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/

GO