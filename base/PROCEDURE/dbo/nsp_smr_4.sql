SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nsp_smr_4                                          */
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
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/************************************************************************/

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC [dbo].[nsp_smr_4] (
@StorerKeyMin   NVARCHAR(15),
@StorerKeyMax   NVARCHAR(15),
@ItemClassMin   NVARCHAR(10),
@ItemClassMax   NVARCHAR(10),
@SkuGroupMin    NVARCHAR(10),
@SkuGroupMax    NVARCHAR(10),
@lottable02Min  NVARCHAR(18),     -- WHSE CODE
@lottable02Max  NVARCHAR(18),     -- WHSE CODE
@DateStringMin  NVARCHAR(10),
@DateStringMax  NVARCHAR(10)

/*  toshiba report
group by itemclass, sku description
---------------------------------------------------------------------
Count the number of skugroup for toshiba

select itemclass, skugroup, count(*)
from sku(nolock)
where storerkey = 'toshiba'
group by itemclass, skugroup
order by count(*)
---------------------------------------------------------------------

list out a list of itemclass, skugroup for toshiba

select itemclass, skugroup
from sku
where skugroup = 'A'
and storerkey = 'toshiba'
order by itemclass, skugroup
---------------------------------------------------------------------

return a list of skugroup for toshiba

select distinct skugroup from sku where storerkey = 'toshiba' order by skugroup
---------------------------------------------------------------------

exec nsp_smr_4
'toshiba',    --Start storerkey
'toshiba',    --end storerkey
'main' ,      --Start itemclass
'main' ,      --end itemclass
'A',          --Start skugroup
'A',          --end skugroup
'0',        --start whse code
'ZZZZZZZZZZZZZZZ',        --end whse code
'23/08/2000', --start date
'24/08/2000'  --end date

*/
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @DateMin datetime
   DECLARE @DateMax datetime
   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @StorerKeyMin,
      @StorerKeyMax,
      @ItemClassMin,
      @ItemClassMax,
      @DateMin,
      @DateMax
   END

   DECLARE       @n_continue int        ,  /* continuation flag
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


   /* Execute Preprocess */
   /* #INCLUDE <SPBMLD1.SQL> */
   /* End Execute Preprocess */

   /* String to date convertion */
   SELECT @datemin = CAST(substring(@datestringmin, 4, 2) + "/"+           --month
   substring(@datestringmin, 1, 2) +"/"+            --day
   substring(@datestringmin, 7, 4) as datetime)     --year

   SELECT @datemax = CAST(substring(@datestringmax, 4, 2) + "/"+           --month
   substring(@datestringmax, 1, 2) +"/"+            --day
   substring(@datestringmax, 7, 4) as datetime)     --year

   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0


   DECLARE @BFdate DATETIME
   DECLARE @d_end_date DATETIME
   DECLARE @d_begin_date datetime

   SELECT @d_begin_date = Convert( datetime, @DateMin )

   SELECT @BFdate = DATEADD(day, -1, convert(datetime,convert(char(10),@datemin,101)))

   SELECT @d_end_date =  DATEADD(day, 1, convert(datetime,convert(char(10),@datemax,101)))
   DECLARE @n_num_recs int
   DECLARE @n_num_recs_bb  int


   IF @n_continue=1 or @n_continue=2
   BEGIN

      SELECT @n_num_recs = -100 /* initialize */

      SELECT  a.StorerKey
      , b.itemclass
      , a.lot
      , a.lottable02
      , b.skugroup
      , a.sku
      , a.qty
      , volume = convert(float,(a.qty * b.stdcube))
      , a.TranType
      , EffectiveDate = convert(datetime,convert(char(10),a.EffectiveDate,101))
      , a.ItrnKey
      , a.Sourcekey
      , a.SourceType
      , 0 as distinct_sku
      -- INTO #ITRN_CUT_BY_SKU
      INTO #ITRN_CUT_BY_SKU_ITT
      FROM itrn a(nolock), sku b(nolock)
      WHERE a.sku = b.sku
      AND a.StorerKey BETWEEN @StorerKeyMin AND @StorerKeyMax
      AND b.itemclass between @ItemClassMin AND @ItemClassMax
      AND a.lottable02 between @lottable02min and @lottable02max
      AND b.skugroup between @SkuGroupMin AND @SkuGroupMax
      AND a.EffectiveDate < @d_end_date
      AND a.TranType IN ("DP", "WD", "AJ")

      /* This section will eliminate those transaction that is found in ITRN but not found in Orders, Receipt, Adjustment or
      transfer - this code is introduced for integrity purpose between the historical transaction*/

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

      (SELECT 1 where a.sourcekey = 'INTIALDP')

      )

      /* This section is pertaining to transfer process, if the from sku and the to sku happen to be the same,
      exclude it out of the report. If the from sku and the to sku is different, include it in the report.
      */

      DECLARE @ikey NVARCHAR(10), @skey NVARCHAR(20), @dd_d int

      DECLARE itt_cursor CURSOR FAST_FORWARD READ_ONLY FOR
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
      delete from #ITRN_CUT_BY_SKU_ITT where distinct_sku = 1

      SELECT storerkey,
      itemclass,
      lot,
      lottable02,
      skugroup,
      sku,
      qty,
      volume,
      trantype,
      effectivedate
      INTO #ITRN_CUT_BY_SKU
      FROM #ITRN_CUT_BY_SKU_ITT


      SELECT @n_err = @@ERROR
      SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_4)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END

      -- 	select * from       #ITRN_CUT_BY_SKU

   END  /* continue and stuff */


   /* insert into INVENTORY_CUT1 all archive qty values with lots */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ( @n_num_recs > 0)
      BEGIN
         INSERT #ITRN_CUT_BY_SKU
         SELECT
         a.StorerKey
         , c.itemclass
         , a.lot
         , d.lottable02
         , c.skugroup
         , a.Sku
         , a.ArchiveQty
         , a.archiveqty * c.stdcube
         , TranType = "DP"
         , convert(datetime,convert(char(10),ArchiveDate,101))
         FROM lot a(nolock), sku c(nolock), lotattribute d(nolock)
         WHERE a.sku = c.sku
         and a.lot = d.lot
         AND a.archiveqty > 0
         AND EXISTS
         (SELECT * FROM #ITRN_CUT_BY_SKU B
         WHERE c.storerkey = b.storerkey
         and c.itemclass = b.itemclass
         and a.lot = b.lot
         and c.skugroup = b.skugroup
         and a.archivedate <= @d_begin_date )
      END
   END

   /* sum up everything before the @datemin including archive qtys */

   SELECT  StorerKey
   , itemclass
   , lottable02
   , skugroup
   , sku
   , QTY = SUM(Qty)
   , volume = sum(volume)
   , EffectiveDate = @BFDate
   , Flag = "AA"
   , TranType = "  "
   , RunningTotal = sum(qty)
   , Record_number = 0
   INTO #BF
   FROM #ITRN_CUT_BY_SKU
   WHERE  EffectiveDate < @DateMin
   GROUP BY storerkey, itemclass, lottable02, skugroup, sku  /**/

   SELECT @n_num_recs = @@rowcount

   /* if this is a new product */
   /* or the data does not exist for the lower part of the date range */
   /* this is to set the opening balance to 0 */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_num_recs = 0)
      BEGIN
         INSERT #BF
         SELECT  StorerKey
         , itemclass
         , lottable02
         , skugroup
         , sku
         , QTY= 0
         , volume = 0
         , EffectiveDate = @bfDate
         , Flag = "AA"
         , TranType = "  "
         , RunningTotal = 0
         , record_number = 0
         FROM #ITRN_CUT_BY_SKU
         GROUP by StorerKey, itemclass, lottable02, skugroup, sku
      END /* numrecs = 0 */
   END /* for n_continue etc. */


   IF @n_continue=1 or @n_continue=2
   BEGIN
      /* pick up the unique set of records which are in the in between period */

      IF (@n_num_recs > 0)
      BEGIN
         SELECT  StorerKey
         , itemclass
         , lottable02
         , skugroup
	                    , sku
         , qty = 0
         , volume = 0
         , EffectiveDate = @bfDate
         , flag="AA"
         , TranType = "          "
         , RunningTotal = 0
         INTO #BF_TEMP3
         FROM #ITRN_CUT_BY_SKU
         WHERE
         (EffectiveDate > @d_begin_date and EffectiveDate <= @d_end_date)
         GROUP BY StorerKey, itemclass, lottable02, skugroup, sku
         SELECT @n_num_recs = @@rowcount

         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_4)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
         SELECT  StorerKey
         , itemclass
         , lottable02
         , skugroup
         , sku
         , qty = 0
         , volume = 0
         , EffectiveDate = @bfDate
         , flag="AA"    /* was BB */
         , TranType = "          "
         , RunningTotal = 0
         INTO #BF_TEMP3a
         FROM #BF_TEMP3 a
         WHERE NOT exists
         (SELECT * from #BF b
         WHERE a.StorerKey = b.StorerKey
         AND   a.itemclass = b.itemclass
         AND   a.lottable02 = b.lottable02
         AND   a.skugroup = b.skugroup
         AND   a.sku = b.sku

         )
         SELECT @n_err = @@ERROR
         SELECT @n_num_recs_bb = (SELECT COUNT(*) FROM #BF_TEMP3a)

         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_4)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END /* if @n_num_recs > 0 */

   END /* continue and stuff */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ( @n_num_recs_bb > 0)
      BEGIN
         INSERT #BF
         SELECT
         StorerKey
         , itemclass
         , lottable02
         , skugroup
         , sku
         , qty
         , volume
         , EffectiveDate
         , flag
         , TranType
         , RunningTotal
         , 0
         FROM #BF_TEMP3a

         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nsp_smr_4)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END
      END

   END /* continue and stuff */

   /* ...then add all the data between the requested dates. */

   SELECT  StorerKey
   , itemclass
   , lottable02
   , skugroup
   , sku
   , Qty
   , volume
   , EffectiveDate = convert(datetime,CONVERT(char(10), EffectiveDate,101))
   , Flag = "  "
   , TranType
   , RunningTotal = 0
   , record_number = 0
   INTO #BF2
   FROM #ITRN_CUT_BY_SKU
   WHERE EffectiveDate >= @DateMin


   INSERT #BF
   SELECT  StorerKey
   , itemclass
   , lottable02
   , skugroup
   , sku
   , SUM(Qty)
   , sum(volume)
   , EffectiveDate
   ,  "  "
   , TranType
   , 0
   , 0
   FROM #BF2
   GROUP BY
   StorerKey
   , itemclass
   , lottable02
   , skugroup
   , sku
   , EffectiveDate
   , TranType

   IF (@b_debug = 1)
   BEGIN
      SELECT
      StorerKey
      , itemclass
      , lottable02
      , skugroup
      , sku
      , Qty
      , volume
      , EffectiveDate
      , Flag
      , TranType
      , RunningTotal
      FROM #BF
      ORDER BY StorerKey, itemclass, lottable02, skugroup, sku
   END


   /* put the cursor in here for running totals */
   /* declare cursor vars */
   DECLARE @StorerKey NVARCHAR(15)
   DECLARE @itemclass NVARCHAR(10)
   declare @lottable02 NVARCHAR(18)
   DECLARE @skugroup NVARCHAR(10)
   declare @sku NVARCHAR(20)

   DECLARE @Qty int
   DECLARE @volume float
   DECLARE @EffectiveDate datetime
   DECLARE @Flag  NVARCHAR(2)
   DECLARE @TranType NVARCHAR(10)
   DECLARE @RunningTotal int

   DECLARE @prev_StorerKey NVARCHAR(15)
   DECLARE @prev_itemclass NVARCHAR(10)
   declare @prev_lottable02 NVARCHAR(18)

   DECLARE @prev_skugroup NVARCHAR(10)
   declare @prev_sku NVARCHAR(20)

   DECLARE @prev_Qty int
   declare @prev_volume float
   DECLARE @prev_EffectiveDate datetime
   DECLARE @prev_Flag  NVARCHAR(2)
   DECLARE @prev_TranType NVARCHAR(10)
   DECLARE @prev_RunningTotal int
   DECLARE @record_number int

   SELECT @record_number = 1

   DELETE #BF2

   SELECT @RunningTotal = 0

   execute('DECLARE cursor_for_running_total CURSOR  FAST_FORWARD READ_ONLY
   FOR  SELECT
   StorerKey
   , itemclass
   , lottable02
   , skugroup
   , sku
   , Qty
   , volume
   , EffectiveDate
   , Flag
   , TranType
   FROM #BF
   ORDER BY StorerKey, itemclass, lottable02, skugroup, sku, EffectiveDate')

   OPEN cursor_for_running_total

   FETCH NEXT FROM cursor_for_running_total
   INTO
   @StorerKey,
   @itemclass,
   @lottable02,
   @skugroup,
   @sku,
   @Qty,
   @volume,
   @EffectiveDate,
   @Flag,
   @TranType

   WHILE (@@fetch_status <> -1)
   BEGIN

      IF (@b_debug = 1)
      BEGIN
         select @StorerKey,"|",
         @itemclass,"|",
         @lottable02, "|",
         @skugroup,"|",
         @sku, "|",
         @Qty,"|",
         @volume, "|",
         @EffectiveDate,"|",
         @Flag,"|",
         @TranType,"|",
         @RunningTotal,"|",
         @record_number"|"
      END

      IF (dbo.fnc_RTrim(@TranType) = 'DP' or dbo.fnc_RTrim(@TranType) = 'WD' or
      dbo.fnc_RTrim(@TranType) = 'AJ')
      BEGIN
         SELECT @RunningTotal = @RunningTotal + @qty
      END

      IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
      BEGIN
         /* first calculated  total */
         SELECT @RunningTotal = @qty
      END

      INSERT #BF2
      values(
      @StorerKey,
      @itemclass,
      @lottable02,
      @skugroup,
      @sku,
      @Qty,
      @volume,
      @EffectiveDate,
      @Flag,
      @TranType,
      @RunningTotal,
      @record_number)

      SELECT @prev_StorerKey = @StorerKey
      SELECT @prev_itemclass = @itemclass
      select @prev_lottable02 = @lottable02
      select @prev_skugroup = @skugroup
      select @prev_sku = @sku

      SELECT @prev_qty =  @Qty
      select @prev_volume = @volume
      SELECT @prev_flag = @Flag
      SELECT @prev_EffectiveDate = @EffectiveDate
      SELECT @prev_TranType =  @TranType
      SELECT @prev_RunningTotal = @RunningTotal

      FETCH NEXT FROM cursor_for_running_total
      INTO
      @StorerKey,
      @itemclass,
      @lottable02,
      @skugroup,
      @sku,
      @Qty,
      @volume,
      @EffectiveDate,
      @Flag,
      @TranType

      SELECT @record_number = @record_number + 1
      IF (@storerkey <> @prev_storerkey AND @itemclass <> @prev_itemclass)
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            select 'prev_storerkey',  @prev_storerkey,
            'prev_itemclass',  @prev_itemclass,
            'prev_lottable02', @prev_lottable02,
            'prev_skugroup',   @prev_skugroup,
            'prev_sku',        @prev_sku
         END

         select @runningtotal = 0
      END

   END /* while loop */

   close cursor_for_running_total
   deallocate cursor_for_running_total


   /* Output the data collected. */
   /* summarizing the qty into opening balance, in_qtym out_qty and ending_balance */

   SELECT b.Company
   , a.StorerKey
   , a.itemclass
   , a.lottable02
   , a.skugroup
   , a.sku
   , 0 as o_qty
   , convert(float, 0) as o_volume
   , 0 as in_qty
   , convert(float, 0) as in_volume
   , 0 as out_qty
   , convert(float, 0) as out_volume
   , 0 as bal_qty
   , convert(float, 0) as bal_volume
   INTO #bb2
   FROM #bf2 a, storer b (NOLOCK)
   WHERE a.storerkey = b.storerkey
   group by b.company, a.storerkey, a.itemclass, a.lottable02, a.skugroup, a.sku


   DECLARE @company NVARCHAR(45)

   DECLARE report_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
   select b.Company,
   a.StorerKey,
   a.itemclass,
   a.lottable02,
   a.skugroup,
   a.sku,
   a.qty,
   a.volume,
   a.flag,
   a.trantype
   from #bf2 a, storer b (NOLOCK)
   where a.storerkey = b.storerkey

   OPEN report_cursor

   FETCH NEXT FROM report_cursor
   INTO
   @company,
   @StorerKey,
   @itemclass,
   @lottable02,
   @skugroup,
   @sku,
   @Qty,
   @volume,
   @Flag,
   @TranType

   WHILE (@@fetch_status <> -1)
   BEGIN
      if (dbo.fnc_RTrim(@trantype) = 'DP') or (dbo.fnc_RTrim(@Trantype) = 'AJ' and @qty > 0) -- deposit and positive adjustment
      begin
         update #bb2
         set in_qty = in_qty + @qty,
         in_volume = in_volume + @volume
         where company = @company
         and   storerkey = @storerkey
         and   itemclass = @itemclass
         and   lottable02 = @lottable02
         and   skugroup = @skugroup
         and   sku = @sku
      end

      IF (dbo.fnc_RTrim(@TranType) = 'WD') or (dbo.fnc_RTrim(@Trantype) = 'AJ' and @qty < 0) -- withdrawal and negative adjustment
      begin
         update #bb2
         set out_qty = out_qty - ( @qty ),
         out_volume = out_volume - ( @volume )

         where company = @company
         and   storerkey = @storerkey
         and   itemclass = @itemclass
         and   lottable02 = @lottable02
         and   skugroup = @skugroup
         and   sku = @sku
      end

      IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
      BEGIN
         /* opening balances */
         update #bb2
         set o_qty = o_qty + @qty,
         o_volume = o_volume + @volume

         where company = @company
         and   storerkey = @storerkey
         and   itemclass = @itemclass
         and   lottable02 = @lottable02
         and   skugroup = @skugroup
         and   sku = @sku
      END


      FETCH NEXT FROM report_cursor
      INTO
      @company,
      @StorerKey,
      @itemclass,
      @lottable02,
      @skugroup,
      @sku,
      @Qty,
      @volume,
      @Flag,
      @TranType

   END /* while loop */

   close report_cursor
   deallocate report_cursor


   /* updating balance quantity */
   update #bb2
   set bal_qty = o_qty + in_qty - out_qty,
   bal_volume = o_volume + in_volume - out_volume

   /* output to user */
   select Company,
   StorerKey,
                 itemclass,
   lottable02,
   skugroup,
   sku,
   o_qty,
   convert(decimal(10,3), o_volume) as o_volume,
   in_qty,
   convert(decimal(10,3), in_volume) as in_volume,
   out_qty,
   convert(decimal(10,3), out_volume) as out_volume,
   bal_qty,
   convert(decimal(10,3), bal_volume) as bal_volume,
   Suser_Sname(), -- prepared_by
   "INV90", -- report id
   "From " + @DateStringMin + " To "+ @DateStringMax
   from #bb2
   order by company, storerkey, itemclass, lottable02, skugroup, sku


END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/

GO