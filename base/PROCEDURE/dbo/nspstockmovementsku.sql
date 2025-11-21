SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspStockMovementSku                                */
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

CREATE PROC [dbo].[nspStockMovementSku] (
@StorerKeyMin   NVARCHAR(15),
@StorerKeyMax   NVARCHAR(15),
@SkuMin         NVARCHAR(20),
@SkuMax         NVARCHAR(20),
@LotMin         NVARCHAR(10),
@LotMax         NVARCHAR(10),
@DateMin        datetime,
@DateMax        datetime
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
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @n_err int,
   @c_errmsg NVARCHAR(250)
   /* #INCLUDE <SPBMLD1.SQL> */
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
      SELECT @n_num_recs = -100
      SELECT
      StorerKey
      , Sku
      , Lot
      , qty
      , TranType
      , EffectiveDate = convert(datetime,convert(char(10),EffectiveDate,101))
      INTO #ITRN_CUT_BY_SKU
      FROM itrn
      WHERE
      StorerKey BETWEEN @StorerKeyMin AND @StorerKeyMax
      AND Sku BETWEEN @SkuMin AND @SkuMax
      AND Lot BETWEEN @LotMin AND @LotMax
      AND EffectiveDate < @d_end_date
      AND TranType IN ("DP", "WD", "AJ")
      SELECT @n_err = @@ERROR
      SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nspStockMovementSku)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
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
         , convert(datetime,convert(char(10),ArchiveDate,101))
         FROM LOT A
         WHERE EXISTS
         (SELECT * FROM #ITRN_CUT_BY_SKU B
         WHERE a.LOT = b.LOT and a.archivedate <= @d_begin_date)
      END
   END
   SELECT
   StorerKey
   , Sku
   , QTY = SUM(Qty)
   , EffectiveDate = @BFDate
   , Flag = "AA"
   , TranType = "  "
   , RunningTotal = sum(qty)
   , Record_number = 0
   INTO #BF
   FROM #ITRN_CUT_BY_SKU
   WHERE  EffectiveDate < @DateMin
   GROUP BY StorerKey, Sku
   SELECT @n_num_recs = @@rowcount
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
         , RunningTotal = 0
         , record_number = 0
         FROM #ITRN_CUT_BY_SKU
         GROUP by StorerKey, Sku
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_num_recs > 0)
      BEGIN
         SELECT
         StorerKey
         , Sku
         , qty = 0
         , EffectiveDate = @bfDate
         , flag="AA"
         , TranType = "          "
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
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nspStockMovementSku)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_num_recs > 0)
      BEGIN
         SELECT
         StorerKey
         , Sku
         , qty = 0
         , EffectiveDate = @bfDate
         , flag="AA"
         , TranType = "          "
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
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nspStockMovementSku)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
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
         , RunningTotal
         , 0
         FROM #BF_TEMP3a
         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nspStockMovementSku)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   SELECT
   StorerKey
   , Sku
   , Qty
   , EffectiveDate = convert(datetime,CONVERT(char(10), EffectiveDate,101))
   , Flag = "  "
   , TranType
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
   , 0
   , 0
   FROM #BF2
   GROUP BY
   StorerKey
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
      , RunningTotal
      FROM #BF
      ORDER BY StorerKey,Sku
   END
   DECLARE @StorerKey NVARCHAR(15)
   DECLARE @Sku NVARCHAR(20)
   DECLARE @Lot NVARCHAR(10)
   DECLARE @Qty int
   DECLARE @EffectiveDate datetime
   DECLARE @Flag  NVARCHAR(2)
   DECLARE @TranType NVARCHAR(10)
   DECLARE @RunningTotal int
   DECLARE @prev_StorerKey NVARCHAR(15)
   DECLARE @prev_Sku NVARCHAR(20)
   DECLARE @prev_Lot NVARCHAR(10)
   DECLARE @prev_Qty int
   DECLARE @prev_EffectiveDate datetime
   DECLARE @prev_Flag  NVARCHAR(2)
   DECLARE @prev_TranType NVARCHAR(10)
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
   @TranType
   WHILE (@@fetch_status <> -1)
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         select @StorerKey,
         @Sku,
         @Qty,
         @EffectiveDate,
         @Flag,
         @TranType,
         @RunningTotal,
         @record_number
      END
      IF (dbo.fnc_RTrim(@TranType) = 'DP' or dbo.fnc_RTrim(@TranType) = 'WD' or
      dbo.fnc_RTrim(@TranType) = 'AJ')
      BEGIN
         SELECT @RunningTotal = @RunningTotal + @qty
      END
      IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
      BEGIN
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
      @RunningTotal,
      @record_number)
      SELECT @prev_StorerKey = @StorerKey
      SELECT @prev_Sku =  @Sku
      SELECT @prev_qty =  @Qty
      SELECT @prev_flag = @Flag
      SELECT @prev_EffectiveDate = @EffectiveDate
      SELECT @prev_TranType =  @TranType
      SELECT @prev_RunningTotal = @RunningTotal
      FETCH NEXT FROM cursor_for_running_total
      INTO
      @StorerKey,
      @Sku,
      @Qty,
      @EffectiveDate,
      @Flag,
      @TranType
      SELECT @record_number = @record_number + 1
      IF (@storerkey <> @prev_storerkey AND @sku <> @prev_sku)
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            select 'prev_storerkey', @prev_storerkey, 'sku', @sku
         END
         select @runningtotal = 0
      END
   END
   close cursor_for_running_total
   deallocate cursor_for_running_total
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
      , #BF2.RunningTotal
      FROM #BF2
      ORDER BY
      #BF2.record_number
   END
END

GO