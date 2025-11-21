SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC [dbo].[nsp_smr_by_Commodity05] (
   @StorerMin   NVARCHAR(15),
   @StorerMax   NVARCHAR(15),
   @SkuGroupMin NVARCHAR(10),
   @SkuGroupMax NVARCHAR(10),
   @SkuMin      NVARCHAR(20),
   @SkuMax      NVARCHAR(20),
   @LotMin      NVARCHAR(10),
   @LotMax      NVARCHAR(10),
   @DateMin     datetime,
   @DateMax     datetime,
   @c_facility	 NVARCHAR(5)   -- SOS14801
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   --T  19/12/2000     No need datetime convertion
   --    DECLARE @DateMin datetime
   --    DECLARE @DateMax datetime
   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @StorerMin,
      @StorerMax,
      @SkugroupMin,
      @SkugroupMax,
      @SkuMin,
      @SkuMax,
      @LotMin,
      @LotMax,
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
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
   DECLARE @BFdate DATETIME
   DECLARE @d_end_date DATETIME
   DECLARE @d_begin_date datetime
   SELECT @d_begin_date = @DateMin
   SELECT @BFdate = DATEADD(day, -1, @DateMin)
   SELECT @d_end_date =  DATEADD(day, 1, @DateMax)
   DECLARE @n_num_recs int
   DECLARE @n_num_recs_bb  int
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_num_recs = -100 /* initialize */
      SELECT
      Storerkey = UPPER(a.StorerKey)
      , b.skugroup
      , a.Sku
      , a.Lot
      , a.qty
      , a.TranType
      , ExceedNum = CASE WHEN a.SourceType like 'CC Deposit (%'
                         THEN SubString(a.SourceType, 13,10)
                         WHEN a.SourceType like 'CC Withdrawal (%'
                         THEN SubString(a.SourceType, 16,10)
                         ELSE substring(a.sourcekey,1,10) 
                    END
      --T change for require document reference no. for External No.
      , ExternNum = isnull(CASE
      /* Receipt */
      WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
      THEN (SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(RECEIPT.externreceiptKey))
            FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10))
      /* Orders */
      WHEN a.SourceType = 'ntrPickDetailUpdate'
      THEN (SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(ORDERS.ExternOrderKey))
            FROM ORDERS(NOLOCK) WHERE orderkey = (select orderkey from pickdetail where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
      /* Transfer */
      WHEN a.SourceType = 'ntrTransferDetailUpdate'
      THEN (SELECT CustomerRefNo
           FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10))
      /* Adjustment */
      WHEN a.SourceType = 'ntrAdjustmentDetailAdd'
      THEN (SELECT CustomerRefNo
            FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10))
      /* Cycle Count */
      WHEN a.SourceType like 'CC Deposit (%' OR a.SourceType like 'CC Withdrawal (%'
       THEN (SELECT ISNULL(CCSheetNo,'')
            FROM CCDETAIL (NOLOCK) WHERE CCDETAIL.CCDETAILKEY = SUBSTRING(a.SourceKey,1,10))
      END, CASE
            /* Receipt */
            WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
            THEN isnull((SELECT RECEIPT.POKey
                         FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10)),"-")
            /* Orders */
            WHEN a.SourceType = 'ntrPickDetailUpdate'
            THEN isnull((SELECT ORDERS.BuyerPO
            FROM ORDERS(NOLOCK) WHERE orderkey = (select orderkey from pickdetail where pickdetailkey = SUBSTRING(a.SourceKey,1,10))),'-')
            ELSE "-"
         END) 
      --T change for require document reference no. for BuyerPO No.
      , BuyerPO = isnull(CASE
      /* Receipt */
      WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
      THEN (SELECT RECEIPT.CarrierReference
      FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10))
      ELSE "-"
      END, "-")
      , a.AddDate
      , a.itrnkey
      , a.sourcekey
      , a.sourcetype
      , 0 as distinct_sku
      , 0 as picked
      , a.packkey
      , a.uom
      INTO #ITRN_CUT_BY_SKU_ITT
      FROM itrn a(nolock), sku b(nolock),
      	  LOC (nolock) -- SOS14801
      WHERE a.StorerKey BETWEEN @StorerMin AND @StorerMax
      AND a.storerkey = b.storerkey  --by steo, to eliminate 2 storers having 2 same skus, 12:20, 13-OCT-2000
      AND a.sku = b.sku
      AND b.skugroup BETWEEN @SkuGroupMin AND @SkuGroupMax
      AND a.Sku BETWEEN @SkuMin AND @SkuMax
      AND a.Lot BETWEEN @LotMin AND @LotMax
      AND a.AddDate < @d_end_date
      AND a.TranType IN ("DP", "WD", "AJ")
      AND a.ToLoc = LOC.Loc  				-- SOS14801
      AND LOC.Facility = @c_facility	-- SOS14801

      /* This is to exclude the calculation of the Loading of the V5 Upgrade, as this will cause double calculation */
      DELETE FROM #ITRN_CUT_BY_SKU_ITT WHERE SOURCETYPE = "V5_LOADING"
      
      INSERT INTO #ITRN_CUT_BY_SKU_ITT
      SELECT Storerkey = a.storerkey,
      b.skugroup,
      a.sku,
      a.lot,
      (a.qty * -1),
      'WD',
      a.orderkey,
      isnull(d.externorderkey,"-"),
      isnull(d.buyerpo,"-"),
      a.AddDate,
      '',
      '',
      'ntrPickDetailUpdate',
      0,
      1,  -- 1 means picked record
      a.packkey,
      (select packuom3 from pack (nolock) where pack.packkey = a.packkey)
      FROM pickdetail a(nolock),
      sku b(nolock),
      orders d(nolock),
      LOC (nolock) -- SOS14801
      WHERE a.StorerKey BETWEEN @StorerMin AND @StorerMax
      AND a.storerkey = b.storerkey
      AND a.sku = b.sku
      AND a.orderkey = d.orderkey
      AND b.skugroup BETWEEN @SkuGroupMin AND @SkuGroupMax
      AND a.Sku BETWEEN @SkuMin AND @SkuMax
      AND a.Lot BETWEEN @LotMin AND @LotMax
      AND a.AddDate < @d_end_date
      AND a.status = '5'  -- all the picked records
      AND a.Loc =  LOC.Loc					-- SOS14801
      AND LOC.Facility = @c_facility   -- SOS14801
            
      /* this is to remove the moving transaction within the same sku */
      -- WALLY 18dec200
      -- modified to included all transfer transactions
      UPDATE #ITRN_CUT_BY_SKU_ITT
      SET trantype = LEFT(trantype,2) + '-TF'
      WHERE sourcetype = 'ntrTransferDetailUpdate'
      
      SELECT Storerkey = UPPER(storerkey),
      skugroup,
      sku,
      lot,
      qty,
      trantype,
      exceednum,
      externnum,
      Buyerpo,
      AddDate,
      picked,
      packkey,
      uom
      INTO #ITRN_CUT_BY_SKU
      FROM #ITRN_CUT_BY_SKU_ITT
      SELECT @n_err = @@ERROR
      SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
      IF NOT @n_err = 0
      BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_by_Commodity)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* End Trap SQL Server Error */
      END
   END  /* continue and stuff */
   
   -- SOS 6569
   -- archive qty is now in sku.archiveqty field
   if @n_continue < 3
   begin
      INSERT #ITRN_CUT_BY_SKU
      SELECT
      Storerkey = UPPER(s.StorerKey)
      , s.skugroup
      , s.Sku
      , lot = ''
      , convert(int, s.ArchiveQty)
      , trantype = 'DP'
      , ExceedNum = space(10)
      , ExternNum = space(30)
      , BuyerPO = space(20)
      , archivedate = @BFDate
      , picked = 0
      , s.packkey
      , p.packuom3
      from sku s (nolock) join pack p (nolock)
      on s.packkey = p.packkey
      where s.archiveqty > 0
      and s.skugroup BETWEEN @SkuGroupMin AND @SkuGroupMax
      and s.Sku BETWEEN @SkuMin AND @SkuMax
      and s.StorerKey BETWEEN @StorerMin AND @StorerMax
   end
   
   /* sum up everything before the @datemin including archive qtys */
   SELECT
   StorerKey = UPPER(StorerKey)
   , skugroup
   , Sku
   , QTY = SUM(Qty)
   , AddDate = @BFDate
   , Flag = "AA"
   , TranType = "     "
   , ExceedNum = "          "
   , ExternNum ="                              "
   , BuyerPO = "                    "
   , RunningTotal = sum(qty)
   , Record_number = 0
   , picked = 0
   , packkey = "          "
   , uom = "          "
   INTO #BF
   FROM #ITRN_CUT_BY_SKU
   WHERE  AddDate < @DateMin
   GROUP BY StorerKey, skugroup, Sku
   SELECT @n_num_recs = @@rowcount
   /* if this is a new product */
   /* or the data does not exist for the lower part of the  date range */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_num_recs = 0)
      BEGIN
         INSERT #BF
         SELECT
         StorerKey = UPPER(StorerKey)
         , skugroup
         , Sku
         , QTY= 0
         , AddDate = @bfDate
         , Flag = "AA"
         , TranType = "          "
         , ExceedNum = "          "
         , ExternNum = "                              "
         , BuyerPO = "                    "
         , RunningTotal = 0
         , record_number = 0
         , picked = 0
         , packkey = "          "
         , uom = "          "
         FROM #ITRN_CUT_BY_SKU
         GROUP by StorerKey, skugroup, Sku
      END /* numrecs = 0 */
   END /* for n_continue etc. */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      /* pick up the unique set of records which are in the in between period */
      IF (@n_num_recs > 0)
      BEGIN
         SELECT  StorerKey = UPPER(StorerKey)
         , skugroup
         , Sku
         , qty = 0
         , AddDate = @bfDate
         , flag="AA"
         , TranType = "          "
         , ExceedNum = "          "
         , ExternNum = "                              "
         , BuyerPO = "                    "
         , RunningTotal = 0
         , picked = 0
         , packkey = "          "
         , uom = "          "
         INTO #BF_TEMP3
         FROM #ITRN_CUT_BY_SKU
         WHERE (AddDate > @d_begin_date and AddDate <= @d_end_date)
            GROUP BY StorerKey, skugroup, Sku
            SELECT @n_num_recs = @@rowcount
            SELECT @n_err = @@ERROR
            IF NOT @n_err = 0
            BEGIN
               SELECT @n_continue = 3
               /* Trap SQL Server Error */
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_by_Commodity)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               /* End Trap SQL Server Error */
            END
         END /* if @n_num_recs > 0 */
      END /* continue and stuff */
      /* add only those storerkey, sku and lot combinations which  do not exist in #BF
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
               select StorerKey = UPPER(a.storerkey),
               a.skugroup,
               a.sku,
               0 as qty,
               @bfDate as AddDate,
               "AA" as flag,
               TranType = "     ",
               ExceedNum = "          ",
               ExternNum ="                              ",
               BuyerPO = "                    ",
               CAST(0 as int) as RunningTotal,
               CAST(0 as int) as picked,
               a.packkey,
               a.uom
               into #BF_TEMP3a
               from #bf_temp3 a
               WHERE not exists
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
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_by_Commodity)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  /* End Trap SQL Server Error */
               END
            END /* if @n_num_recs > 0 */
         END /* continue and stuff */
         IF @n_continue=1 or @n_continue=2
         BEGIN
            IF ( @n_num_recs_bb > 0)
            BEGIN
               INSERT #BF
               SELECT  StorerKey
               , skugroup
               , Sku
               , qty
               , AddDate
               , flag
               , TranType
               , ExceedNum
               , ExternNum
               , BuyerPO
               , RunningTotal
               , 0
               , picked
               , packkey
               , uom
               FROM #BF_TEMP3a
               SELECT @n_err = @@ERROR
               IF NOT @n_err = 0
               BEGIN
                  SELECT @n_continue = 3
                  /* Trap SQL Server Error */
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nsp_smr_by_Commodity)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  /* End Trap SQL Server Error */
               END
            END
         END /* continue and stuff */
         /* ...then add all the data between the requested dates. */
         SELECT  StorerKey
         , skugroup
         , Sku
         , Qty
         , AddDate
         , Flag = "  "
         , TranType
         , ExceedNum
         , ExternNum
         , BuyerPO
         , RunningTotal = 0
         , record_number = 0
         , picked
         , packkey
         , uom
         INTO #BF2
         FROM #ITRN_CUT_BY_SKU
         WHERE AddDate >= @DateMin
         
         INSERT #BF
         SELECT  StorerKey
         , skugroup
         , Sku
         , SUM(Qty)
         , AddDate
         ,  "  "
         , TranType
         , ExceedNum
         , ExternNum
         , BuyerPO
         , 0
         , 0
         , picked
         , packkey
         , uom
         FROM #BF2
         GROUP BY
         StorerKey
         , skugroup
         , Sku
         , AddDate
         , TranType
         , ExceedNum
         , ExternNum
         , BuyerPO
         , picked
         , packkey
         , uom
         
         IF (@b_debug = 1)
         BEGIN
            SELECT StorerKey
            , skugroup
            , Sku
            , Qty
            , AddDate
            , Flag
            , TranType
            , ExceedNum
            , ExternNum
            , BuyerPO
            , RunningTotal
            , picked
            , packkey
            , uom
            FROM #BF
            ORDER BY StorerKey, skugroup, Sku
         END
         /* put the cursor in here for running totals */
         /* declare cursor vars */
         DECLARE @StorerKey NVARCHAR(15)
         declare @skugroup NVARCHAR(10)
         DECLARE @Sku NVARCHAR(20)
         DECLARE @Lot NVARCHAR(10)
         DECLARE @Qty int
         DECLARE @AddDate datetime
         DECLARE @Flag  NVARCHAR(2)
         DECLARE @TranType NVARCHAR(10)
         DECLARE @ExceedNum NVARCHAR(10)
         DECLARE @ExternNum NVARCHAR(30)
         DECLARE @BuyerPO NVARCHAR(20)
         DECLARE @RunningTotal int
         declare @picked int
         DECLARE @packkey NVARCHAR(10)
         DECLARE @uom NVARCHAR(10)
         DECLARE @prev_StorerKey NVARCHAR(15)
         declare @prev_skugroup NVARCHAR(10)
         DECLARE @prev_Sku NVARCHAR(20)
         DECLARE @prev_Lot NVARCHAR(10)
         DECLARE @prev_Qty int
         DECLARE @prev_AddDate datetime
         DECLARE @prev_Flag  NVARCHAR(2)
         DECLARE @prev_TranType NVARCHAR(10)
         DECLARE @prev_ExceedNum NVARCHAR(10)
         DECLARE @prev_ExternNum NVARCHAR(30)
         DECLARE @prev_BuyerPO NVARCHAR(20)
         DECLARE @prev_RunningTotal int
         declare @prev_picked int
         DECLARE @prev_packkey NVARCHAR(10)
         DECLARE @prev_uom NVARCHAR(10)
         DECLARE @record_number int
         SELECT @record_number = 1
         DELETE #BF2
         SELECT @RunningTotal = 0
         execute('DECLARE cursor_for_running_total CURSOR  FAST_FORWARD READ_ONLY 
                     FOR  SELECT
                     StorerKey
                     , skugroup
                     , Sku
                     , Qty
                     , AddDate
                     , Flag
                     , TranType
                     , ExceedNum
                     , ExternNum
                     , BuyerPO
                     , picked
                     , packkey
                     , uom
                     FROM #BF
                     ORDER BY StorerKey, skugroup, sku, AddDate')
         OPEN cursor_for_running_total
         FETCH NEXT FROM cursor_for_running_total
         INTO
         @StorerKey,
         @skugroup,
         @Sku,
         @Qty,
         @AddDate,
         @Flag,
         @TranType,
         @ExceedNum,
         @ExternNum,
         @BuyerPO,
         @picked,
         @packkey,
         @uom
         WHILE (@@fetch_status <> -1)
         BEGIN
            IF (@b_debug = 1)
            BEGIN
               select @StorerKey,"|",
               @skugroup,"|",
               @Sku,"|",
               @Qty,"|",
               @AddDate,"|",
               @Flag,"|",
               @TranType,"|",
               @ExceedNum,"|",
               @ExternNum,"|",
               @BuyerPO,"|",
               @RunningTotal,"|",
               @record_number,"|",
               @picked,"|",
               @packkey,"|",
               @uom
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
            @skugroup,
            @Sku,
            @Qty,
            @AddDate,
            @Flag,
            @TranType,
            @ExceedNum,
            @ExternNum,
            @BuyerPO,
            @RunningTotal,
            @record_number,
            @picked,
            @packkey,
            @uom)
            SELECT @prev_StorerKey = @StorerKey
            SELECT @prev_skugroup = @skugroup
            SELECT @prev_Sku =  @Sku
            SELECT @prev_qty =  @Qty
            SELECT @prev_flag = @Flag
            SELECT @prev_AddDate = @AddDate
            SELECT @prev_TranType =  @TranType
            SELECT @prev_ExceedNum = @ExceedNum
            SELECT @prev_ExternNum = @ExternNum
            SELECT @prev_BuyerPO = @BuyerPO
            SELECT @prev_RunningTotal = @RunningTotal
            SELECT @prev_picked = @picked
            SELECT @prev_packkey = @packkey
            SELECT @prev_uom = @uom
            FETCH NEXT FROM cursor_for_running_total
            INTO
            @StorerKey,
            @skugroup,
            @Sku,
            @Qty,
            @AddDate,
            @Flag,
            @TranType,
            @ExceedNum,
            @ExternNum,
            @BuyerPO,
            @picked,
            @packkey,
            @uom
            SELECT @record_number = @record_number + 1
            IF (@storerkey <> @prev_storerkey AND @skugroup <> @prev_skugroup AND @sku <> @prev_sku)
            BEGIN
               IF (@b_debug = 1)
               BEGIN
                  select 'prev_storerkey', @prev_storerkey, 'skugroup', @prev_skugroup, 'sku', @sku
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
            UPPER(#BF2.StorerKey)
            , STORER.Company
            , #BF2.skugroup
            , #BF2.Sku
            , SKU.Descr
            , #BF2.Qty
            , AddDate =
            CASE
            WHEN #BF2.AddDate < @datemin THEN null
            ELSE #BF2.AddDate
         END
         , #BF2.Flag
         , TranType =
         CASE
         WHEN #BF2.Flag = "AA" THEN "Beginning Balance"
            WHEN #BF2.TranType = "DP" THEN "Deposit"
            WHEN #BF2.TranType = "WD" and #BF2.picked = 1 THEN "Withdrawal(P)"
            WHEN #BF2.TranType = "WD" THEN "Withdrawal"
            WHEN #BF2.TranType = "WD-TF" THEN "Withdrawal(TF)"
            WHEN #BF2.TranType = "DP-TF" THEN "Deposit(TF)"
            /* T */            WHEN #BF2.TranType = "AJ"  and #BF2.qty < 0 THEN "Withdrawal(AJ)"
            /* T */            WHEN #BF2.TranType = "AJ"  and #BF2.qty > 0 THEN "Deposit(AJ)"
         END
         , ExceedNum = Case When #BF2.TranType = 'WD' and #BF2.picked = 1 THEN #BF2.ExceedNum
         When #BF2.TranType = 'WD' THEN isnull((select orderkey from pickdetail where pickdetailkey = #BF2.ExceedNum),#BF2.ExceedNum)
         ELSE #BF2.ExceedNum
         END
         , #BF2.ExternNum
         , #BF2.BuyerPO
         , #BF2.RunningTotal
         , #BF2.picked
         , #BF2.packkey
         , UOM = Case When len(#BF2.uom) = 1 then (select packuom3 from pack (nolock) where pack.packkey = #BF2.packkey)
         Else #BF2.uom
         End
         FROM #BF2,
         STORER (nolock),
         SKU (nolock)
         WHERE #BF2.StorerKey = STORER.StorerKey
         AND #BF2.StorerKey = SKU.StorerKey
         AND #BF2.Sku = SKU.Sku
         ORDER BY  #BF2.record_number
      END
      IF @b_debug = 1
      BEGIN
         SELECT
         #BF2.StorerKey
         , #BF2.skugroup
         , #BF2.Sku
         , #BF2.Qty
         , EffDate = #BF2.AddDate
         , #BF2.Flag
         , #BF2.TranType
         , #BF2.ExceedNum
         , #BF2.ExternNum
         , #BF2.BuyerPO
         , #BF2.RunningTotal
         FROM #BF2
         ORDER BY  #BF2.record_number
      END
		SET NOCOUNT OFF
   END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/

GO