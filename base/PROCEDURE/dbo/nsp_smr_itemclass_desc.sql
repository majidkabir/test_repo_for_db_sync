SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_smr_itemclass_desc                             */
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

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC [dbo].[nsp_smr_itemclass_desc] (
@StorerKeyMin   NVARCHAR(15),
@StorerKeyMax   NVARCHAR(15),
@ItemClassMin   NVARCHAR(10),
@ItemClassMax   NVARCHAR(10),
@SkuMin         NVARCHAR(20),
@SkuMax         NVARCHAR(20),
@LotMin         NVARCHAR(10),
@LotMax         NVARCHAR(10),
@DateMin        datetime,
@DateMax        datetime
/*
@StorerKeyMin   NVARCHAR(15) = "STORER01",
@StorerKeyMax   NVARCHAR(15) = "STORER04",
@SkuMin         NVARCHAR(20) = "SKU01",
@SkuMax         NVARCHAR(20) = "SKU04",
@LotMin         NVARCHAR(10) = "0000000002",
@LotMax         NVARCHAR(10) = "0000000006",
@DateMin        datetime = "08/15/95",
@DateMax        datetime = "08/31/95"
*/
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @StorerKeyMin,
      @StorerKeyMax,
      @SkuMin,
      @SkuMax,
      @LotMin,
      @LotMax,
      @DateMin,
      @DateMax
   END

   DECLARE        @n_continue int        ,  /* continuation flag
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

      SELECT
      a.StorerKey
      , a.Sku
      , a.Lot
      , a.qty
      , a.TranType
      , ItemClass = b.itemclass --steo
      , descr = b.descr --steo
      , EffectiveDate = convert(datetime,convert(char(10),EffectiveDate,101))

      , a.itrnkey
      , a.sourcekey
      , a.sourcetype
      ,0 as distinct_sku
      -- INTO #ITRN_CUT_BY_SKU
      INTO #ITRN_CUT_BY_SKU_ITT
      FROM itrn a(nolock), sku b(nolock)
      WHERE
      a.StorerKey BETWEEN @StorerKeyMin AND @StorerKeyMax
      AND a.sku = b.sku
      AND a.Sku BETWEEN @SkuMin AND @SkuMax
      AND a.Lot BETWEEN @LotMin AND @LotMax
      AND b.ItemClass BETWEEN @ItemClassMin AND @ItemClassMax
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

      DECLARE itt_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
      select ItrnKey, Sourcekey from #ITRN_CUT_BY_SKU_ITT where sourcetype = 'ntrTransferDetailUpdate'

      OPEN itt_cursor
      FETCH NEXT FROM itt_cursor INTO @ikey, @skey

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @dd_d = count(DISTINCT sku)
         FROM itrn
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

      --select * from #ITRN_CUT_BY_SKU_ITT

      SELECT storerkey,
      sku,
      lot,
      qty,
      trantype,
      convert(NVARCHAR(10), itemclass) as itemclass,
      convert(NVARCHAR(60), descr) as descr,
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
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_itemclass_desc)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END




   END  /* continue and stuff */

   /* insert into INVENTORY_CUT1 all archive qty values with lots */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ( @n_num_recs > 0)
      BEGIN

         INSERT #ITRN_CUT_BY_SKU
         SELECT
         StorerKey
         , Sku
         , Lot
         , ArchiveQty
         , TranType = "DP"
         , "" -- itemclass
         , "" -- descr
         , convert(datetime,convert(NVARCHAR(10),ArchiveDate,101))
         FROM LOT A
         WHERE EXISTS
         (SELECT * FROM #ITRN_CUT_BY_SKU B
         WHERE a.LOT = b.LOT and a.archivedate <= @d_begin_date)
      END

   END

   select "sengtuan"
   /* sum up everything before the @datemin including archive qtys */

   SELECT
   StorerKey
   , Sku
   , QTY = SUM(Qty)
   --, EffectiveDate = NULL
   , EffectiveDate = @BFDate
   , Flag = "AA"
   , TranType = "  "
   , itemclass = "          "  -- itemclass
   , descr = "                                                            " -- descr
   , RunningTotal = sum(qty)
   , Record_number = 0
   INTO #BF
   FROM #ITRN_CUT_BY_SKU
   WHERE  EffectiveDate < @DateMin
   GROUP BY StorerKey, Sku
   SELECT @n_num_recs = @@rowcount

   /* if this is a new product */
   /* or the data does not exist for the lower part of the  date range */

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_num_recs = 0)
      BEGIN
         INSERT #BF
         SELECT
         StorerKey
         , Sku
         , QTY= 0
         , EffectiveDate = @bfDate
         , Flag = "AA"
         , TranType = "          "
         , itemclass = "          "  -- itemclass
         , descr = "                                                            " -- descr
         , RunningTotal = 0
         , record_number = 0
         FROM #ITRN_CUT_BY_SKU
         GROUP by StorerKey, Sku
      END /* numrecs = 0 */
   END /* for n_continue etc. */





   IF @n_continue=1 or @n_continue=2
   BEGIN
      /* pick up the unique set of records which are in the in between period */

      IF (@n_num_recs > 0)
      BEGIN

         SELECT
         StorerKey
         , Sku
         , qty = 0
         , EffectiveDate = @bfDate
         , flag="AA"
         , TranType = "          "
         , itemclass
         , descr
         , RunningTotal = 0
         INTO #BF_TEMP3
         FROM #ITRN_CUT_BY_SKU
         WHERE
         (EffectiveDate > @d_begin_date and EffectiveDate <= @d_end_date)
         GROUP BY StorerKey, Sku
         SELECT @n_num_recs = @@rowcount



         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_itemclass_desc)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
         , Sku
         , qty = 0
         , EffectiveDate = @bfDate
         , flag="AA"    /* was BB */
         , TranType = "          "
         , itemclass
         , descr
         , RunningTotal = 0
         INTO #BF_TEMP3a
         FROM #BF_TEMP3 a
         WHERE NOT exists
         (SELECT * from #BF b
         WHERE a.StorerKey = b.StorerKey
         AND   a.Sku = b.Sku
         )
         SELECT @n_err = @@ERROR
         SELECT @n_num_recs_bb = (SELECT COUNT(*) FROM #BF_TEMP3a)

         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_itemclass_desc)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
         , Sku
         , qty
         , EffectiveDate
         , flag
         , TranType
         , itemclass
         , descr
         , RunningTotal
         , 0
         FROM #BF_TEMP3a

         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nsp_smr_itemclass_desc)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* End Trap SQL Server Error */
         END

      END


   END /* continue and stuff */

   /* ...then add all the data between the requested dates. */

   SELECT
   StorerKey
   , Sku
   , Qty
   , EffectiveDate = convert(datetime,CONVERT(char(10), EffectiveDate,101))
   , Flag = "  "
   , TranType
   , itemclass
   , descr = isnull(descr, "")
   , RunningTotal = 0
   , record_number = 0
   INTO #BF2
   FROM #ITRN_CUT_BY_SKU
   WHERE EffectiveDate >= @DateMin



   INSERT #BF
   SELECT
   StorerKey
   , Sku
   , SUM(Qty)
   , EffectiveDate
   ,  "  "
   , TranType
   , ItemClass
   , descr
   , 0
   , 0
   FROM #BF2
   GROUP BY
   StorerKey
   , itemclass
   , descr
   , Sku
   , EffectiveDate
   , TranType

   IF (@b_debug = 1)
   BEGIN
      SELECT
      StorerKey
      , Sku
      , Qty
      , EffectiveDate
      , Flag
      , TranType
      , itemclass
      , descr
      , RunningTotal
      FROM #BF
      ORDER BY StorerKey,Sku
   END


   /* put the cursor in here for running totals */
   /* declare cursor vars */
   DECLARE @StorerKey NVARCHAR(15)
   DECLARE @Sku NVARCHAR(20)
   DECLARE @Lot NVARCHAR(10)
   DECLARE @Qty int
   DECLARE @EffectiveDate datetime
   DECLARE @Flag  NVARCHAR(2)
   DECLARE @TranType NVARCHAR(10)
   DECLARE @ItemClass NVARCHAR(10)
   DECLARE @descr NVARCHAR(60)
   DECLARE @RunningTotal int

   DECLARE @prev_StorerKey NVARCHAR(15)
   DECLARE @prev_Sku NVARCHAR(20)
   DECLARE @prev_Lot NVARCHAR(10)
   DECLARE @prev_Qty int
   DECLARE @prev_EffectiveDate datetime
   DECLARE @prev_Flag  NVARCHAR(2)
   DECLARE @prev_TranType NVARCHAR(10)
   DECLARE @prev_ItemClass NVARCHAR(10)
   DECLARE @prev_Descr NVARCHAR(60)
   DECLARE @prev_RunningTotal int
   DECLARE @record_number int

   SELECT @record_number = 1

   DELETE #BF2

   SELECT @RunningTotal = 0


   execute('DECLARE cursor_for_running_total CURSOR FAST_FORWARD READ_ONLY
   FOR  SELECT
   StorerKey
   , Sku
   , Qty
   , EffectiveDate
   , Flag
   , TranType
   , itemclass
   , descr
   FROM #BF
   ORDER BY StorerKey, sku, EffectiveDate')

   OPEN cursor_for_running_total

   FETCH NEXT FROM cursor_for_running_total
   INTO
   @StorerKey,
   @Sku,
   @Qty,
   @EffectiveDate,
   @Flag,
   @TranType,
   @itemclass,
   @descr

   WHILE (@@fetch_status <> -1)
   BEGIN

      IF (@b_debug = 1)
      BEGIN
         select @StorerKey,"|",
         @Sku,"|",
         @Qty,"|",
         @EffectiveDate,"|",
         @Flag,"|",
         @TranType,"|",
         @Itemclass, "|",
         @descr, "|",
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
      @Sku,
      @Qty,
      @EffectiveDate,
      @Flag,
      @TranType,
      @itemclass,
      @descr,
      @RunningTotal,
      @record_number)


      SELECT @prev_StorerKey = @StorerKey
      SELECT @prev_Sku =  @Sku

      SELECT @prev_qty =  @Qty
      SELECT @prev_flag = @Flag
      SELECT @prev_EffectiveDate = @EffectiveDate
      SELECT @prev_TranType =  @TranType
      SELECT @prev_itemclass = @itemclass
      SELECT @prev_descr = @descr
      SELECT @prev_RunningTotal = @RunningTotal

      FETCH NEXT FROM cursor_for_running_total
      INTO
      @StorerKey,
      @Sku,
      @Qty,
      @EffectiveDate,
      @Flag,
      @TranType,
      @itemclass,
      @descr

      SELECT @record_number = @record_number + 1
      IF (@storerkey <> @prev_storerkey AND @sku <> @prev_sku)
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            select 'prev_storerkey', @prev_storerkey, 'sku', @sku
         END

         select @runningtotal = 0
      END


   END /* while loop */

   close cursor_for_running_total
   deallocate cursor_for_running_total


   /* Output the data collected. */
   IF @b_debug = 0
   BEGIN
      SELECT
      #BF2.StorerKey
      , STORER.Company
      , #BF2.Sku
      , SKU.Descr
      , #BF2.Qty
      , #BF2.EffectiveDate
      , #BF2.Flag
      , #BF2.TranType
      , #BF2.itemclass
      , #BF2.descr
      , #BF2.RunningTotal
      FROM #BF2,
      STORER,
      SKU
      WHERE #BF2.StorerKey = STORER.StorerKey
      AND #BF2.StorerKey = SKU.StorerKey
      AND #BF2.Sku = SKU.Sku
      ORDER BY
      #BF2.record_number
   END

   IF @b_debug = 1
   BEGIN
      SELECT
      #BF2.StorerKey
      , #BF2.Sku
      , #BF2.Qty
      , EffDate = convert(char(10),#BF2.EffectiveDate,101)
      , #BF2.Flag
      , #BF2.TranType
      , #bf2.itemclass
      , #bf2.descr
      , #BF2.RunningTotal
      FROM #BF2
      ORDER BY
      #BF2.record_number
   END

END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/

GO