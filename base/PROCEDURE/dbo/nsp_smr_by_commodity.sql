SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_smr_by_Commodity                               */
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

/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC [dbo].[nsp_smr_by_Commodity] (
@IN_StorerKey   NVARCHAR(15),
@ItemClassMin   NVARCHAR(10),
@ItemClassMax   NVARCHAR(10),
@SkuMin         NVARCHAR(20),
@SkuMax         NVARCHAR(20),
@LotMin         NVARCHAR(10),
@LotMax         NVARCHAR(10),
@DateStringMin  NVARCHAR(10),
@DateStringMax  NVARCHAR(10)

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
      SELECT @IN_StorerKey,
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

      SELECT
      Storerkey = UPPER(a.StorerKey)
      , IsNull(b.itemclass, '') as ItemClass
      , a.Sku
      , a.Lot
      , a.qty
      , a.TranType
      , ExceedNum = substring(a.sourcekey,1,10)
      , ExternNum = isnull(CASE
      /* Receipt */
      WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
      THEN (SELECT ISNULL(RECEIPT.ExternReceiptKey, '')
      FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10))
      /* Orders */
      WHEN a.SourceType = 'ntrPickDetailUpdate'
      THEN (select ISNULL(ORDERS.ExternOrderKey, '')
      from ORDERS(NOLOCK) WHERE orderkey = (select orderkey from pickdetail where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
      /* Transfer */
      WHEN a.SourceType = 'ntrTransferDetailUpdate'
      THEN (SELECT ISNULL(CustomerRefNo , '')
      FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10))
      /* Adjustment */
      WHEN a.SourceType = 'ntrAdjustmentDetailAdd'
      THEN (SELECT ISNULL(CustomerRefNo , '')
      FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10))
      /* Kitting */
      WHEN a.SourceType like 'ntrKitDetail%'
      THEN (SELECT Isnull(ExternKitKey, ' ')
      FROM KIT (NOLOCK) WHERE KIT.KitKey = SUBSTRING(a.SourceKey,1,10))

   ELSE " "
   END, "-")

   , BuyerPO = isnull(CASE
   WHEN a.SourceType = 'ntrPickDetailUpdate'
   THEN ( SELECT ORDERS.BuyerPO
   FROM ORDERS(NOLOCK) WHERE orderkey = (select orderkey from pickdetail (NOLOCK) where pickdetailkey = a.SourceKey))
ELSE " "
END, "-")

, EffectiveDate = convert(datetime,convert(char(10), a.EffectiveDate,101))
, a.itrnkey
, a.sourcekey
, a.sourcetype
, 0 as distinct_sku
, 0 as picked
, ShipToCompany = isnull(CASE  ---difff-----
WHEN a.SourceType = 'ntrPickDetailUpdate'
THEN ( SELECT ORDERS.C_COMPANY
FROM ORDERS(NOLOCK) WHERE orderkey = (select orderkey from pickdetail (nolock) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
THEN ( SELECT RECEIPT.CarrierName
FROM RECEIPT (NOLOCK) WHERE ReceiptKey =  SUBSTRING(a.SourceKey,1,10))
ELSE SPACE(45)
END, '-')
INTO #ITRN_CUT_BY_SKU_ITT
FROM itrn a(nolock), sku b(nolock)
WHERE
a.StorerKey = @IN_StorerKey
AND a.storerkey = b.storerkey  --by steo, to eliminate 2 storers having 2 same skus, 12:20, 13-OCT-2000
AND a.sku = b.sku
AND b.itemclass BETWEEN @ItemClassMin AND @ItemClassMax
AND a.Sku BETWEEN @SkuMin AND @SkuMax
AND a.Lot BETWEEN @LotMin AND @LotMax
AND a.EffectiveDate < @d_end_date
AND a.TranType IN ("DP", "WD", "AJ")

/* This section will eliminate those transaction that is found in ITRN but not found in Orders, Receipt, Adjustment or
transfer - this code is introduced for integrity purpose between the historical transaction*/

/* New added 20/september/2000, include picked information as withdrawal transaction type Withdrawal(P)
picked detail is not included in the itrn file when item was picked, IDS wants it to be in.
This selection will select all the orders that is currently being picked. only picked orders will be
selected.
*/

/* orderdetail c is being removed because it gives double figure, steo 13/10/2000 10:30 am
*/
INSERT INTO #ITRN_CUT_BY_SKU_ITT
SELECT Storerkey = a.storerkey,
ISNULL(b.itemclass, '') as ItemClass,
a.sku,
a.lot,
(a.qty * -1),
'WD',
a.orderkey,
IsNull(d.externorderkey, '') as ExternOrderKey,
isnull(d.buyerpo,"-"),
a.effectivedate,
'',
'',
'ntrPickDetailUpdate',
0,
1,  -- 1 means picked record
ISNULL(d.C_Company, '-' )
FROM pickdetail a(nolock),
sku b(nolock),
orders d(nolock)
WHERE a.StorerKey = @IN_StorerKey
AND a.storerkey = b.storerkey
AND a.sku = b.sku
AND a.orderkey = d.orderkey
AND b.itemclass BETWEEN @ItemClassMin AND @ItemClassMax
AND a.Sku BETWEEN @SkuMin AND @SkuMax
AND a.Lot BETWEEN @LotMin AND @LotMax
AND a.EffectiveDate < @d_end_date
AND a.status = '5'  -- all the picked records

/*------------------------------------------------------------------------------------------------------
This section is pertaining to transfer process, if the from sku and the to sku happen to be the same,
exclude it out of the report. If the from sku and the to sku is different, include it in the report.
--------------------------------------------------------------------------------------------------------*/

DECLARE @ikey NVARCHAR(10), @skey NVARCHAR(20), @dd_d int

DECLARE itt_cursor CURSOR FOR
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


SELECT Storerkey = UPPER(storerkey),
ISNULL(itemclass, '') as ItemClass,
ISNULL(sku,'') as SKU,
lot,
qty,
trantype,
exceednum,
externnum,
Buyerpo,
effectivedate,
picked,
ShipToCompany
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

-- 	select * from       #ITRN_CUT_BY_SKU


END  /* continue and stuff */


/* insert into INVENTORY_CUT1 all archive qty values with lots */

IF @n_continue=1 or @n_continue=2
BEGIN
   IF ( @n_num_recs > 0)
   BEGIN
      INSERT #ITRN_CUT_BY_SKU
      SELECT
      Storerkey = UPPER(a.StorerKey)
      , IsNull(f.itemclass, '') as ItemClass
      , a.Sku
      , a.Lot
      , a.ArchiveQty
      , TranType = "DP"
      , ExceedNum = "          "
      , ExternNum = "                              "
      , BuyerPO = "                    "
      , convert(datetime,convert(char(10), a.ArchiveDate,101))
      , picked = 0,
      ShipToCompany = SPACE(45)
      FROM LOT a(nolock), sku f(nolock)
      where a.sku = f.sku
      and a.storerkey = f.storerkey
      and EXISTS
      (SELECT * FROM #ITRN_CUT_BY_SKU B
      WHERE a.LOT = b.LOT and a.archivedate <= @d_begin_date)
   END

END

/* sum up everything before the @datemin including archive qtys */

SELECT
StorerKey = UPPER(StorerKey)
, IsNULL(itemclass, '') as ItemClass
, Sku
, QTY = SUM(Qty)
, EffectiveDate = @BFDate
, Flag = "AA"
, TranType = "  "
, ExceedNum = "          "
, ExternNum ="                              "
, BuyerPO = "                    "
, RunningTotal = sum(qty)
, Record_number = 0
, picked = 0
, ShipToCompany = Space(45)
INTO #BF
FROM #ITRN_CUT_BY_SKU
WHERE  EffectiveDate < @DateMin
GROUP BY StorerKey, itemclass, Sku
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
      , IsNULL(itemclass, '') as ItemClass
      , Sku
      , QTY= 0
      , EffectiveDate = @bfDate
      , Flag = "AA"
      , TranType = "          "
      , ExceedNum = "          "
      , ExternNum = "                              "
      , BuyerPO = "                    "
      , RunningTotal = 0
      , record_number = 0
      , picked = 0
      , ShipToCompany = SPACE(45)
      FROM #ITRN_CUT_BY_SKU
      GROUP by StorerKey, itemclass, Sku
   END /* numrecs = 0 */
END /* for n_continue etc. */


IF @n_continue=1 or @n_continue=2
BEGIN
   /* pick up the unique set of records which are in the in between period */

   IF (@n_num_recs > 0)
   BEGIN

      SELECT
      StorerKey = UPPER(StorerKey)
      , ISNULL(itemclass,'') as ItemClass
      , Sku
      , qty = 0
      , EffectiveDate = @bfDate
      , flag="AA"
      , TranType = "          "
      , ExceedNum = "          "
      , ExternNum = "                              "
      , BuyerPO = "                    "
      , RunningTotal = 0
      , picked = 0
      , ShipToCompany = Space(45)
      INTO #BF_TEMP3
      FROM #ITRN_CUT_BY_SKU
      WHERE
      (EffectiveDate > @d_begin_date and EffectiveDate <= @d_end_date)
      GROUP BY StorerKey, itemclass, Sku
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

      select StorerKey = UPPER(a.storerkey),
      ISNULL(a.itemclass, '') as itemclass,
      a.sku,
      0 as qty,
      @bfDate as EffectiveDate,
      "AA" as flag,
      CAST(null as NVARCHAR(10)) as TranType,
      CAST(null as NVARCHAR(10)) as ExceedNum,
      CAST(null as NVARCHAR(30)) as ExternNum,
      CAST(null as NVARCHAR(20)) as BuyerPO,
      CAST(0 as int) as RunningTotal,
      CAST(0 as int) as picked,
      ShipToCompany
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
      SELECT
      StorerKey
      , itemclass
      , Sku
      , qty
      , EffectiveDate
      , flag
      , TranType
      , ExceedNum
      , ExternNum
      , BuyerPO
      , RunningTotal
      , 0
      , picked
      , ShipToCompany
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

SELECT
StorerKey
, itemclass
, Sku
, Qty
, EffectiveDate = convert(datetime,CONVERT(char(10), EffectiveDate,101))
, Flag = "  "
, TranType
, ExceedNum
, ExternNum
, BuyerPO
, RunningTotal = 0
, record_number = 0
, picked
, ShipToCompany
INTO #BF2
FROM #ITRN_CUT_BY_SKU
WHERE EffectiveDate >= @DateMin

INSERT #BF
SELECT
StorerKey
, itemclass
, Sku
, SUM(Qty)
, EffectiveDate
,  "  "
, TranType
, isnull(ExceedNum, '')
, ISNULL(ExternNum, '')
, BuyerPO
, 0
, 0
, picked
, ShipToCompany
FROM #BF2
GROUP BY
StorerKey
, itemclass
, Sku
, EffectiveDate
, TranType
, ExceedNum
, ExternNum
, BuyerPO
, picked
, ShipToCompany

IF (@b_debug = 1)
BEGIN
   SELECT
   StorerKey
   , itemclass
   , Sku
   , Qty
   , EffectiveDate
   , Flag
   , TranType
   , ExceedNum
   , ExternNum
   , BuyerPO
   , RunningTotal
   , picked
   , ShipToCompany
   FROM #BF
   ORDER BY StorerKey, itemclass, Sku
END


/* put the cursor in here for running totals */
/* declare cursor vars */
DECLARE @StorerKey NVARCHAR(15)
declare @itemclass NVARCHAR(10)
DECLARE @Sku NVARCHAR(20)
DECLARE @Lot NVARCHAR(10)
DECLARE @Qty int
DECLARE @EffectiveDate datetime
DECLARE @Flag  NVARCHAR(2)
DECLARE @TranType NVARCHAR(10)
DECLARE @ExceedNum NVARCHAR(10)
DECLARE @ExternNum NVARCHAR(30)
DECLARE @BuyerPO NVARCHAR(20)
DECLARE @RunningTotal int
declare @picked int

DECLARE @prev_StorerKey NVARCHAR(15)
declare @prev_itemclass NVARCHAR(10)
DECLARE @prev_Sku NVARCHAR(20)
DECLARE @prev_Lot NVARCHAR(10)
DECLARE @prev_Qty int
DECLARE @prev_EffectiveDate datetime
DECLARE @prev_Flag  NVARCHAR(2)
DECLARE @prev_TranType NVARCHAR(10)
DECLARE @prev_ExceedNum NVARCHAR(10)
DECLARE @prev_ExternNum NVARCHAR(30)
DECLARE @prev_BuyerPO NVARCHAR(20)
DECLARE @prev_RunningTotal int
declare @prev_picked int
DECLARE @record_number int,
@ShipToCompany NVARCHAR(45),
@prev_ShipToCompany NVARCHAR(45)

SELECT @record_number = 1

DELETE #BF2

SELECT @RunningTotal = 0


execute('DECLARE cursor_for_running_total CURSOR
FOR  SELECT
StorerKey
, itemclass
, Sku
, Qty
, EffectiveDate
, Flag
, TranType
, ExceedNum
, ExternNum
, BuyerPO
, picked
, ShipToCompany
FROM #BF
ORDER BY StorerKey, itemclass, sku, EffectiveDate')

OPEN cursor_for_running_total

FETCH NEXT FROM cursor_for_running_total
INTO
@StorerKey,
@itemclass,
@Sku,
@Qty,
@EffectiveDate,
@Flag,
@TranType,
@ExceedNum,
@ExternNum,
@BuyerPO,
@picked,
@ShipToCompany


WHILE (@@fetch_status <> -1)
BEGIN

   IF (@b_debug = 1)
   BEGIN
      select @StorerKey,"|",
      @itemclass,"|",
      @Sku,"|",
      @Qty,"|",
      @EffectiveDate,"|",
      @Flag,"|",
      @TranType,"|",
      @ExceedNum,"|",
      @ExternNum,"|",
      @BuyerPO,"|",
      @RunningTotal,"|",
      @record_number"|",
      @picked
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
   @Sku,
   @Qty,
   @EffectiveDate,
   @Flag,
   @TranType,
   @ExceedNum,
   @ExternNum,
   @BuyerPO,
   @RunningTotal,
   @record_number,
   @picked,
   @ShipToCompany)


   SELECT @prev_StorerKey = @StorerKey
   select @prev_itemclass = @itemclass
   SELECT @prev_Sku =  @Sku

   SELECT @prev_qty =  @Qty
   SELECT @prev_flag = @Flag
   SELECT @prev_EffectiveDate = @EffectiveDate
   SELECT @prev_TranType =  @TranType
   SELECT @prev_ExceedNum = @ExceedNum
   SELECT @prev_ExternNum = @ExternNum
   SELECT @prev_BuyerPO = @BuyerPO
   SELECT @prev_RunningTotal = @RunningTotal
   select @prev_picked = @picked
   SELECT @prev_ShipToCompany = @ShipToCompany

   FETCH NEXT FROM cursor_for_running_total
   INTO
   @StorerKey,
   @itemclass,
   @Sku,
   @Qty,
   @EffectiveDate,
   @Flag,
   @TranType,
   @ExceedNum,
   @ExternNum,
   @BuyerPO,
   @picked,
   @ShipToCompany


   SELECT @record_number = @record_number + 1
   IF (@storerkey <> @prev_storerkey AND @itemclass <> @prev_itemclass AND @sku <> @prev_sku)
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         select 'prev_storerkey', @prev_storerkey, 'itemclass', @prev_itemclass, 'sku', @sku
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
   CAST(UPPER(#BF2.StorerKey) as NVARCHAR(15)) as StorerKey
   , CAST(STORER.Company as NVARCHAR(45)) as Company
   , CAST(#BF2.itemclass as NVARCHAR(10)) as ItemClass
   , CAST(#BF2.Sku as NVARCHAR(20)) as SKU
   , CAST(SKU.Descr as NVARCHAR(60)) as Descr
   , CAST(#BF2.Qty as int) as Qty
   , EffectiveDate =
   CASE
   WHEN #BF2.EffectiveDate < @datemin THEN null
ELSE #BF2.EffectiveDate
END
, CAST(#BF2.Flag as NVARCHAR(2)) as Flag
, TranType =
CAST(CASE
WHEN #BF2.Flag = "AA" THEN "Beginning Balance"
WHEN #BF2.TranType = "DP" THEN "Deposit"
WHEN #BF2.TranType = "WD" and #BF2.picked = 1 THEN "Withdrawal(P)"
WHEN #BF2.TranType = "WD" THEN "Withdrawal"
END as NVARCHAR(20))
, CAST(#BF2.ExceedNum as NVARCHAR(20)) as EXceedNum
, CAST(#BF2.ExternNum as NVARCHAR(30)) as ExternNum
, CAST(#BF2.BuyerPO as NVARCHAR(20)) as BuyerPO
, CAST(#BF2.RunningTotal as int ) RunningTotal
, CAST(#BF2.picked as int) Picked
, CAST("INV94" AS NVARCHAR(5)) as ReportId -- report id
, CAST("From " + @DateStringMin + " To "+ @DateStringMax as NVARCHAR(50)) as ReportRange
, #BF2.ShipToCompany
FROM #BF2,
STORER (NOLOCK),
SKU  (NOLOCK)
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
   , #BF2.itemclass
   , #BF2.Sku
   , #BF2.Qty
   , EffDate = convert(char(10),#BF2.EffectiveDate,101)
   , #BF2.Flag
   , #BF2.TranType
   , #BF2.ExceedNum
   , #BF2.ExternNum
   , #BF2.BuyerPO
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