SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_smr_by_Commodity02                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Used by IDSMY                                               */
/*                                                                      */
/* Called By: IDSRPVU.PBL - r_smr_by_commodity02                        */
/*                                                                      */
/* PVCS Version: 1.10                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 30.JUN.06    June          Include ArchiveDB pass-in parameter &     */
/*                            Use dynamic SQL statement                 */
/* 20.DEC.06    Vicky         SOS#64387 - Fixes on                      */
/*                            "Subquery returned more than 1 value"     */
/* 22-Feb-2008  June          SOS99065 : OpenBal = SUM Of ITRN DP & WD  */
/*                            Qty in Archive Db + ArchiveOpenBal.OpenBal*/
/* 29-May-2013  Audrey        SOS# 279511 - Split SQL statement.        */
/************************************************************************/

CREATE PROC [dbo].[nsp_smr_by_Commodity02] (
     @IN_StorerKey   NVARCHAR(15),
     @ItemClassMin   NVARCHAR(10),
     @ItemClassMax   NVARCHAR(10),
     @SkuMin         NVARCHAR(20),
     @SkuMax         NVARCHAR(20),
     @LotMin         NVARCHAR(10),
     @LotMax         NVARCHAR(10),
     @DateStringMin  NVARCHAR(10),
     @DateStringMax  NVARCHAR(10),
     @AgencyStart    NVARCHAR(18), -- Added By Vicky 10 June 2003 SOS#11541
     @AgencyEnd      NVARCHAR(18), -- Added By Vicky 10 June 2003 SOS#11541
     @cArchiveDB     NVARCHAR(30)  -- Added by June 30.June.06
) AS
BEGIN

DECLARE @DateMin datetime
DECLARE @DateMax datetime
DECLARE @n_archiveqty int -- added by Jacob, date: 24-10-2001
DECLARE @BFdate DATETIME
DECLARE @d_end_date datetime
DECLARE @d_begin_date datetime
DECLARE @n_num_recs int
DECLARE @n_num_recs_bb  int
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
        @c_errmsg NVARCHAR(250),
        @c_sql NVARCHAR(MAX)
      , @c_sql2 NVARCHAR(MAX) -- SOS# 279511
      , @c_sql3 NVARCHAR(MAX) -- SOS# 279511
      , @c_sql4 NVARCHAR(MAX) -- SOS# 279511
SELECT @b_debug = 0

IF @b_debug = 1
BEGIN
    SELECT @IN_StorerKey,
           @SkuMin,
           @SkuMax,
           @LotMin,
           @LotMax,
           @DateMin,
           @DateMax,
           @AgencyStart, -- Added By Vicky 10 June 2003 SOS#11541
           @AgencyEnd    -- Added By Vicky 10 June 2003 SOS#11541
END

/* Execute Preprocess */
/* #INCLUDE <SPBMLD1.SQL> */
/* End Execute Preprocess */

/* String to date convertion */
-- SELECT @datemin = @DateStringMin
-- SELECT @datemax = @DateStringMax

/* Set default values for variables */
SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0

SELECT @d_begin_date = Convert(datetime, @DateStringMin )
SELECT @BFdate = DATEADD(day, -1, @DateStringMin)
SELECT @d_end_date =  DATEADD(day, 1, @DateStringMax)

IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @n_num_recs = -100 /* initialize */

--    SELECT  Storerkey = UPPER(a.StorerKey)
--          , b.itemclass
--          , a.Sku
--          , a.Lot
--          , a.qty
--          , a.TranType
--          , ExceedNum = substring(a.sourcekey,1,10)
--          , ExternNum = isnull(CASE
--          /* Receipt */
--                 WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
--                      THEN (SELECT RECEIPT.ExternReceiptKey
--                              FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10))
--          /* Orders */
--                 WHEN a.SourceType = 'ntrPickDetailUpdate'
--                      THEN (SELECT ORDERS.ExternOrderKey
--                            from ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
--          /* Transfer */
--                 WHEN a.SourceType = 'ntrTransferDetailUpdate'
--                      THEN (SELECT CustomerRefNo
--                              FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10))
--          /* Adjustment */
--                 WHEN a.SourceType = 'ntrAdjustmentDetailAdd'
--                      THEN (SELECT CustomerRefNo
--                              FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10))
--                 ELSE ' '
--                 END, '-')
--
--          , BuyerPO = isnull(CASE
--                 WHEN a.SourceType = 'ntrPickDetailUpdate'
--                      THEN ( SELECT ORDERS.BuyerPO
--                               FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
--                    ELSE ' '
--                    END, '-')
--          , AddDate = convert(datetime,convert(char(11), a.AddDate,106))
--          , a.itrnkey
--          , a.sourcekey
--          , a.sourcetype
--          , 0 as distinct_sku
--          , 0 as picked
--          , b.susr3 -- Added By Vicky 10 June 2003 SOS#11541
--          , InvoiceNo = isnull(CASE -- Added by Shong 28/11/03 SOS#17492
--                 WHEN a.SourceType = 'ntrPickDetailUpdate'
--                      THEN ( SELECT ORDERS.InvoiceNo
--                               FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
--                    ELSE ' '
--                    END, '-')
--    INTO #ITRN_CUT_BY_SKU_ITT
--    FROM itrn a(nolock), sku b(nolock)
--    WHERE a.StorerKey = @IN_StorerKey
--    AND a.storerkey = b.storerkey  --by steo, to eliminate 2 storers having 2 same skus, 12:20, 13-OCT-2000
--    AND a.sku = b.sku
--    AND b.itemclass BETWEEN @ItemClassMin AND @ItemClassMax
--    AND a.Sku BETWEEN @SkuMin AND @SkuMax
--    AND a.Lot BETWEEN @LotMin AND @LotMax
--    AND (ISNULL(b.Susr3,'') BETWEEN @AgencyStart AND @AgencyEnd ) -- Added By Vicky 10 June 2003 SOS#11541
--    AND a.AddDate < @d_end_date
--    AND a.TranType IN ('DP', 'WD', 'AJ')

   SELECT  Storerkey = UPPER(a.StorerKey)
         , b.itemclass
         , a.Sku
         , a.Lot
         , a.qty
         , a.TranType
         , ExceedNum = substring(a.sourcekey,1,10)
         , ExternNum = isnull(CASE
         /* Receipt */
                WHEN a.SourceType IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
                     THEN (SELECT RECEIPT.ExternReceiptKey
                             FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10))
         /* Orders */
                WHEN a.SourceType = 'ntrPickDetailUpdate'
                     THEN (SELECT ORDERS.ExternOrderKey
                           from ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
         /* Transfer */
                WHEN a.SourceType = 'ntrTransferDetailUpdate'
                     THEN (SELECT CustomerRefNo
                             FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10))
         /* Adjustment */
                WHEN a.SourceType = 'ntrAdjustmentDetailAdd'
                     THEN (SELECT CustomerRefNo
                             FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10))
                ELSE ' '
                END, '-')

         , BuyerPO = isnull(CASE
                WHEN a.SourceType = 'ntrPickDetailUpdate'
                     THEN ( SELECT ORDERS.BuyerPO
                              FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
                   ELSE ' '
                   END, '-')
         , AddDate = convert(datetime,convert(char(11), a.AddDate,106))
         , a.itrnkey
         , a.sourcekey
         , a.sourcetype
         , 0 as distinct_sku
         , 0 as picked
         , b.susr3 -- Added By Vicky 10 June 2003 SOS#11541
         , InvoiceNo = isnull(CASE -- Added by Shong 28/11/03 SOS#17492
                WHEN a.SourceType = 'ntrPickDetailUpdate'
                     THEN ( SELECT ORDERS.InvoiceNo
                              FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)))
                   ELSE ' '
                   END, '-')
   INTO #ITRN_CUT_BY_SKU_ITT
   FROM itrn a(nolock), sku b(nolock)
   WHERE 1=2

   SELECT @c_sql  = ''
   SELECT @c_sql2 = ''
   SELECT @c_sql3 = ''
   SELECT @c_sql4 = ''
   SELECT @c_sql = 'INSERT INTO #ITRN_CUT_BY_SKU_ITT ' -- SOS# 279511
                     + 'SELECT  Storerkey = UPPER(a.StorerKey) '
                     + ', b.itemclass '
                     + ', a.Sku '
                     + ', a.Lot '
                     + ', a.qty '
                     + ', a.TranType '
                     + ', ExceedNum = substring(a.sourcekey,1,10) '
                     + ', ExternNum = isnull(CASE '
                     + '/* Receipt */ '
                     + '       WHEN a.SourceType IN (''ntrReceiptDetailUpdate'',''ntrReceiptDetailAdd'') '
                     + '            THEN (SELECT DISTINCT RECEIPT.ExternReceiptKey ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '/* Orders */ '
                     + '       WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN (SELECT DISTINCT ORDERS.ExternOrderKey ' -- SOS#64387 - Add DISTINCT
                     + '                  from ORDERS(NOLOCK) WHERE orderkey = (SELECT distinct orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '/* Transfer */ '
                     + '       WHEN a.SourceType = ''ntrTransferDetailUpdate'' '
                     + '            THEN (SELECT DISTINCT CustomerRefNo ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '/* Adjustment */ '
                     + '       WHEN a.SourceType = ''ntrAdjustmentDetailAdd'' '
                     + '            THEN (SELECT DISTINCT CustomerRefNo ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '       ELSE '' '' '
                     + '       END, ''-'') '
                     + ', BuyerPO = isnull(CASE '
                     + '      WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN ( SELECT DISTINCT ORDERS.BuyerPO ' -- SOS#64387 - Add DISTINCT
                     + '                     FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT distinct orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '          ELSE '' '' '
                     + '          END, ''-'') '
      SELECT @c_sql2 = ', AddDate = convert(datetime,convert(char(11), a.AddDate,106)) '
                     + ', a.itrnkey '
                     + ', a.sourcekey '
                     + ', a.sourcetype '
                     + ', 0 as distinct_sku '
                     + ', 0 as picked '
                     + ', b.susr3 ' -- Added By Vicky 10 June 2003 SOS#11541
                     + ', InvoiceNo = isnull(CASE ' -- Added by Shong 28/11/03 SOS#17492
                     + '       WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN ( SELECT DISTINCT ORDERS.InvoiceNo ' -- SOS#64387 - Add DISTINCT
                     + '             FROM ORDERS(NOLOCK) WHERE orderkey = (SELECT distinct orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '          ELSE '' '' '
                     + '          END, ''-'') '
                     + 'FROM itrn a(nolock), sku b(nolock) '
                     + 'WHERE a.StorerKey = N''' + RTRIM(@IN_StorerKey) + ''' '
                     + 'AND a.storerkey = b.storerkey ' --by steo, to eliminate 2 storers having 2 same skus, 12:20, 13-OCT-2000
                     + 'AND a.sku = b.sku '
                     + 'AND b.itemclass BETWEEN N''' + RTRIM(@ItemClassMin) + ''' AND N''' + RTRIM(@ItemClassMax) + ''' '
                     + 'AND a.Sku BETWEEN N''' + RTRIM(@SkuMin) + ''' AND N''' + RTRIM(@SkuMax) + ''' '
                     + 'AND a.Lot BETWEEN N''' + RTRIM(@LotMin) + ''' AND N''' + RTRIM(@LotMax) + ''' '
                     + 'AND (ISNULL(b.Susr3,'''') BETWEEN N''' + RTRIM(@AgencyStart) + ''' AND N''' + RTRIM(@AgencyEnd) + ''' ) ' -- Added By Vicky 10 June 2003 SOS#11541
                     + 'AND a.AddDate < N''' + RTRIM(@d_end_date) + ''' '
                     + 'AND a.TranType IN (''DP'', ''WD'', ''AJ'') '
                     + 'UNION '
      SELECT @c_sql3 = 'SELECT  Storerkey = UPPER(a.StorerKey) '
                     + ', b.itemclass '
                     + ', a.Sku '
                     + ', a.Lot '
                     + ', a.qty '
                     + ', a.TranType '
                     + ', ExceedNum = substring(a.sourcekey,1,10) '
                     + ', ExternNum = isnull(CASE '
                     + '/* Receipt */ '
                     + '       WHEN a.SourceType IN (''ntrReceiptDetailUpdate'',''ntrReceiptDetailAdd'') '
                     + '            THEN (SELECT DISTINCT RECEIPT.ExternReceiptKey ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM ' + RTRIM(@cArchiveDB) + '..RECEIPT RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '/* Orders */ '
                     + '       WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN (SELECT DISTINCT ORDERS.ExternOrderKey ' -- SOS#64387 - Add DISTINCT
                     + '                  from ' + RTRIM(@cArchiveDB) + '..ORDERS ORDERS (NOLOCK) WHERE orderkey = (SELECT distinct orderkey from ' + RTRIM(@cArchiveDB) + '..pickdetail PICKDETAIL (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '/* Transfer */ '
                     + '       WHEN a.SourceType = ''ntrTransferDetailUpdate'' '
                     + '            THEN (SELECT DISTINCT CustomerRefNo ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM ' + RTRIM(@cArchiveDB) + '..TRANSFER TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '/* Adjustment */ '
                     + '       WHEN a.SourceType = ''ntrAdjustmentDetailAdd'' '
                     + '            THEN (SELECT DISTINCT CustomerRefNo ' -- SOS#64387 - Add DISTINCT
                     + '                    FROM ' + RTRIM(@cArchiveDB) + '..ADJUSTMENT ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10)) '
                     + '       ELSE '' '' '
                     + '       END, ''-'') '
                     + ', BuyerPO = isnull(CASE '
                     + '      WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN ( SELECT DISTINCT ORDERS.BuyerPO ' -- SOS#64387 - Add DISTINCT
                     + '                     FROM ' + RTRIM(@cArchiveDB) + '..ORDERS ORDERS (NOLOCK) WHERE orderkey = (SELECT distinct orderkey from ' + RTRIM(@cArchiveDB) + '..pickdetail PICKDETAIL (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '          ELSE '' '' '
                     + '          END, ''-'') '
      SELECT @c_sql4 = ', AddDate = convert(datetime,convert(char(11), a.AddDate,106)) '
                     + ', a.itrnkey '
                     + ', a.sourcekey '
                     + ', a.sourcetype '
                     + ', 0 as distinct_sku '
                     + ', 0 as picked '
                     + ', b.susr3 ' -- Added By Vicky 10 June 2003 SOS#11541
                     + ', InvoiceNo = isnull(CASE ' -- Added by Shong 28/11/03 SOS#17492
                     + '       WHEN a.SourceType = ''ntrPickDetailUpdate'' '
                     + '            THEN ( SELECT DISTINCT ORDERS.InvoiceNo ' -- SOS#64387 - Add DISTINCT
                     + '                     FROM ' + RTRIM(@cArchiveDB) + '..ORDERS ORDERS (NOLOCK) WHERE orderkey = (SELECT distinct orderkey from ' + RTRIM(@cArchiveDB) + '..pickdetail PICKDETAIL (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10))) '
                     + '          ELSE '' '' '
                     + '          END, ''-'') '
                     + 'FROM ' + RTRIM(@cArchiveDB) + '..itrn a(nolock), sku b(nolock) '
                     + 'WHERE a.StorerKey = N''' + RTRIM(@IN_StorerKey) + ''' '
                     + 'AND a.storerkey = b.storerkey ' --by steo, to eliminate 2 storers having 2 same skus, 12:20, 13-OCT-2000
                     + 'AND a.sku = b.sku '
                     + 'AND b.itemclass BETWEEN N''' + RTRIM(@ItemClassMin) + ''' AND N''' + RTRIM(@ItemClassMax) + ''' '
                     + 'AND a.Sku BETWEEN N''' + RTRIM(@SkuMin) + ''' AND N''' + RTRIM(@SkuMax) + ''' '
                     + 'AND a.Lot BETWEEN N''' + RTRIM(@LotMin) + ''' AND N''' + RTRIM(@LotMax) + ''' '
                     + 'AND (ISNULL(b.Susr3,'''') BETWEEN N''' + RTRIM(@AgencyStart) + ''' AND N''' + RTRIM(@AgencyEnd) + ''' ) ' -- Added By Vicky 10 June 2003 SOS#11541
                     + 'AND a.AddDate < N''' + RTRIM(@d_end_date) + ''' '
                     + 'AND a.TranType IN (''DP'', ''WD'', ''AJ'') '

      EXEC ( @c_sql + @c_sql2 + @c_sql3 + @c_sql4 )
      IF @b_debug = 1
      BEGIN
         SELECT @c_sql
      END

   /* This section will eliminate those transaction that is found in ITRN but not found in Orders, Receipt, Adjustment or
      transfer - this code is introduced for integrity purpose between the historical transaction*/
   /* AND 1 in ( (SELECT 1 FROM RECEIPT (NOLOCK) WHERE RECEIPT.ReceiptKey = SUBSTRING(a.SourceKey,1,10)
                                                AND (a.sourcetype = 'ntrReceiptDetailUpdate' or
                                                     a.sourcetype = 'ntrReceiptDetailAdd')),
               (SELECT 1 FROM ORDERS(NOLOCK) WHERE ORDERKEY =
                    (SELECT orderkey from pickdetail (NOLOCK) where pickdetailkey = SUBSTRING(a.SourceKey,1,10)
                                                       AND a.SourceType = 'ntrPickDetailUpdate')),
               (SELECT 1 FROM TRANSFER (NOLOCK) WHERE TRANSFER.TransferKey = SUBSTRING(a.SourceKey,1,10)
                                                       AND a.SourceType = 'ntrTransferDetailUpdate' ),
               (SELECT 1 FROM ADJUSTMENT (NOLOCK) WHERE ADJUSTMENT.AdjustmentKey = SUBSTRING(a.SourceKey,1,10)
                                                       AND a.SourceType = 'ntrAdjustmentDetailAdd'),
               (SELECT 1 where a.sourcekey = 'INTIALDP')
             )
   */

   /* New added 20/september/2000, include picked information as withdrawal transaction type Withdrawal(P)
      picked detail is not included in the itrn file when item was picked, IDS wants it to be in.
      This SELECTion will SELECT all the orders that is currently being picked. only picked orders will be
      SELECTed.
   */

   /* orderdetail c is being removed because it gives double figure, steo 13/10/2000 10:30 am */
--    INSERT INTO #ITRN_CUT_BY_SKU_ITT
--    SELECT Storerkey = a.storerkey,
--        b.itemclass,
--        a.sku,
--        a.lot,
--        (a.qty * -1),
--        'WD',
--        a.orderkey,
--        d.externorderkey,
--        isnull(d.buyerpo,'-'),
--        a.AddDate,
--        '',
--        '',
--        'ntrPickDetailUpdate',
--        0,
--        1,  -- 1 means picked record
--        b.susr3, -- Added By Vicky 10 June 2003 SOS#11541
--        isnull(d.InvoiceNo,'-') --Added by Shong 28/11/03 SOS#17492
--    FROM pickdetail a(nolock),
--         sku b(nolock),
--         --orderdetail c(nolock),
--         orders d(nolock)
--    WHERE a.StorerKey = @IN_StorerKey
--    AND a.storerkey = b.storerkey
--    AND a.sku = b.sku
--    --AND a.sku = c.sku     -- steo, admended as of 26/sep/2000 due to -250 qty appear in the report, reported by kenny
--    AND a.orderkey = d.orderkey
--    --AND a.orderkey = c.orderkey
--    AND b.itemclass BETWEEN @ItemClassMin AND @ItemClassMax
--    AND a.Sku BETWEEN @SkuMin AND @SkuMax
--    AND a.Lot BETWEEN @LotMin AND @LotMax
--    AND (ISNULL(b.Susr3,'') BETWEEN @AgencyStart AND @AgencyEnd) -- Added By Vicky 10 June 2003 SOS#11541
--    AND a.AddDate < @d_end_date
--    AND a.status = '5'  -- all the picked records

   SELECT @c_sql = ''
   SELECT @c_sql = 'INSERT INTO #ITRN_CUT_BY_SKU_ITT '
                  + 'SELECT Storerkey = a.storerkey, '
                  + ' b.itemclass, '
                  + ' a.sku, '
                  + ' a.lot, '
                  + ' (a.qty * -1), '
                  + ' ''WD'', '
                  + ' a.orderkey, '
                  + ' d.externorderkey, '
                  + ' isnull(d.buyerpo,''-''), '
                  + ' a.AddDate, '
                  + ' '''', '
                  + ' '''', '
                  + ' ''ntrPickDetailUpdate'', '
                  + ' 0, '
                  + ' 1, ' -- 1 means picked record
                  + ' b.susr3, ' -- Added By Vicky 10 June 2003 SOS#11541
                  + ' isnull(d.InvoiceNo,''-'') ' --Added by Shong 28/11/03 SOS#17492
                  + ' FROM pickdetail a(nolock), '
                  + '     sku b(nolock), '
                  --orderdetail c(nolock),
                  + '     orders d(nolock) '
                  + 'WHERE a.StorerKey = N''' + RTRIM(@IN_StorerKey) + ''' '
                  + 'AND a.storerkey = b.storerkey '
                  + 'AND a.sku = b.sku '
                  --AND a.sku = c.sku      -- steo, admended as of 26/sep/2000 due to -250 qty appear in the report, reported by kenny
                  + 'AND a.orderkey = d.orderkey '
                  --AND a.orderkey = c.orderkey
                  + 'AND b.itemclass BETWEEN N''' + RTRIM(@ItemClassMin) + ''' AND N''' + RTRIM(@ItemClassMax) + ''' '
                  + 'AND a.Sku BETWEEN N''' + RTRIM(@SkuMin) + ''' AND N''' + RTRIM(@SkuMax) + ''' '
                  + 'AND a.Lot BETWEEN N''' + RTRIM(@LotMin) + ''' AND N''' + RTRIM(@LotMax) + ''' '
                  + 'AND (ISNULL(b.Susr3,'''') BETWEEN N''' + RTRIM(@AgencyStart) + ''' AND N''' + RTRIM(@AgencyEnd) + ''') ' -- Added By Vicky 10 June 2003 SOS#11541
                  + 'AND a.AddDate < N''' + RTRIM(@d_end_date) + ''' '
                  + 'AND a.status = ''5'' ' -- all the picked records
                  + 'UNION '
                  + 'SELECT Storerkey = a.storerkey, '
                  + ' b.itemclass, '
                  + ' a.sku, '
                  + ' a.lot, '
                  + ' (a.qty * -1), '
                  + ' ''WD'', '
                  + ' a.orderkey, '
                  + ' d.externorderkey, '
                  + ' isnull(d.buyerpo,''-''), '
                  + ' a.AddDate, '
                  + ' '''', '
                  + ' '''', '
                  + ' ''ntrPickDetailUpdate'', '
                  + ' 0, '
                  + ' 1, ' -- 1 means picked record
                  + ' b.susr3, ' -- Added By Vicky 10 June 2003 SOS#11541
                  + ' isnull(d.InvoiceNo,''-'') ' --Added by Shong 28/11/03 SOS#17492
                  + ' FROM ' + RTRIM(@cArchiveDB) + '..pickdetail a(nolock), '
                  + '     sku b(nolock), '
                  --orderdetail c(nolock),
                  + '     ' + RTRIM(@cArchiveDB) + '..orders d(nolock) '
                  + 'WHERE a.StorerKey = N''' + RTRIM(@IN_StorerKey) + ''' '
                  + 'AND a.storerkey = b.storerkey '
                  + 'AND a.sku = b.sku '
                  --AND a.sku = c.sku      -- steo, admended as of 26/sep/2000 due to -250 qty appear in the report, reported by kenny
                  + 'AND a.orderkey = d.orderkey '
                  --AND a.orderkey = c.orderkey
                  + 'AND b.itemclass BETWEEN N''' + RTRIM(@ItemClassMin) + ''' AND N''' + RTRIM(@ItemClassMax) + ''' '
                  + 'AND a.Sku BETWEEN N''' + RTRIM(@SkuMin) + ''' AND N''' + RTRIM(@SkuMax) + ''' '
                  + 'AND a.Lot BETWEEN N''' + RTRIM(@LotMin) + ''' AND N''' + RTRIM(@LotMax) + ''' '
                  + 'AND (ISNULL(b.Susr3,'''') BETWEEN N''' + RTRIM(@AgencyStart) + ''' AND N''' + RTRIM(@AgencyEnd) + ''') ' -- Added By Vicky 10 June 2003 SOS#11541
                  + 'AND a.AddDate < N''' + RTRIM(@d_end_date) + ''' '
                  + 'AND a.status = ''5'' ' -- all the picked records
         EXEC ( @c_sql )
         IF @b_debug = 1
         BEGIN
            SELECT @c_sql
         END

   /*------------------------------------------------------------------------------------------------------
      This section is pertaining to transfer process, if the from sku and the to sku happen to be the same,
      exclude it out of the report. If the from sku and the to sku is different, include it in the report.
   --------------------------------------------------------------------------------------------------------*/
   --SELECT * from #ITRN_CUT_BY_SKU_ITT
/*
   DECLARE @ikey NVARCHAR(10), @skey NVARCHAR(20), @dd_d int

   DECLARE itt_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
     SELECT ItrnKey, Sourcekey from #ITRN_CUT_BY_SKU_ITT where sourcetype = 'ntrTransferDetailUpdate'

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
*/

   -- WALLY 18dec200
   -- modified to included all transfer transactions
   UPDATE #ITRN_CUT_BY_SKU_ITT
   SET trantype = LEFT(trantype,2) + '-TF'
   WHERE sourcetype = 'ntrTransferDetailUpdate'

   -- delete from #ITRN_CUT_BY_SKU_ITT where distinct_sku = 1

   SELECT Storerkey = UPPER(storerkey),
          itemclass,
          sku,
          lot,
          qty,
          trantype,
          exceednum,
          externnum,
          Buyerpo,
          AddDate,
          picked,
          Susr3, -- Added By Vicky 10 June 2003 SOS#11541
          InvoiceNo --Added by Shong 28/11/03 SOS#17492
   INTO #ITRN_CUT_BY_SKU
   FROM #ITRN_CUT_BY_SKU_ITT

   SELECT @n_err = @@ERROR
   SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
   IF NOT @n_err = 0
   BEGIN
        SELECT @n_continue = 3
        /* Trap SQL Server Error */
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_by_Commodity)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
        /* End Trap SQL Server Error */
   END
--SELECT * from #ITRN_CUT_BY_SKU
END  /* continue and stuff */


/* insert into INVENTORY_CUT1 all archive qty values with lots */
-- IF @n_continue=1 or @n_continue=2
-- BEGIN
--     IF ( @n_num_recs > 0)
--     BEGIN
--          INSERT #ITRN_CUT_BY_SKU
--          SELECT  Storerkey = UPPER(a.StorerKey)
--                , f.itemclass
--                , a.Sku
--                , a.Lot
--                , a.ArchiveQty
--                , TranType = 'DP'
--                , ExceedNum = '          '
--                , ExternNum = '                              '
--                , BuyerPO = '                    '
--                , convert(datetime,convert(char(10), a.ArchiveDate,101))
--                , picked = 0
--          FROM LOT a(nolock), sku f(nolock)
--            where a.sku = f.sku
--            and a.storerkey = f.storerkey
--            and EXISTS
--          (SELECT * FROM #ITRN_CUT_BY_SKU B
--          WHERE a.LOT = b.LOT and a.archivedate <= @d_begin_date)
--     END
-- END

-- Remark by June 21.Aug.06 - ArchiveQty should get from ITRN from live & archive db.
-- archive qty is now in sku.archiveqty field
-- if @n_continue < 3
-- begin
--    INSERT #ITRN_CUT_BY_SKU
--    SELECT
--       Storerkey = UPPER(s.StorerKey)
--       , s.itemclass
--       , s.Sku
--       , lot = ''
--       , convert(int, s.ArchiveQty)
--       , trantype = 'DP'
--       , ExceedNum = space(10)
--       , ExternNum = space(30)
--       , BuyerPO = space(20)
--       , archivedate = @BFDate
--       , picked = 0
-- --    , s.packkey
-- --    , p.packuom3
--       , s.susr3 -- Added By Vicky 10 June 2003 SOS#11541
--       , InvoiceNo = space(20)  --Added by Shong 28/11/03 SOS#17492
--    from sku s (nolock) join pack p (nolock)
--       on s.packkey = p.packkey
--    where s.archiveqty > 0
--     AND s.itemclass BETWEEN @ItemClassMin AND @ItemClassMax
--     AND s.Sku BETWEEN @SkuMin AND @SkuMax
--     and s.storerkey = @in_storerkey
--     AND (ISNULL(s.Susr3,'') BETWEEN @AgencyStart AND @AgencyEnd) -- Added By Vicky 10 June 2003 SOS#11541
-- end

-- Start : SOS99065
SELECT @c_sql = 'INSERT INTO #ITRN_CUT_BY_SKU ' +
         'SELECT  StorerKey = UPPER(ARC.StorerKey) ' +
         '  , itemclass = SMR.ItemClass ' +
         '  , ARC.Sku ' +
         '  , lot = SPACE(10) ' +
         '  , QTY = ISNULL(OpenBal, 0) ' +
         '  , TranType = SPACE(5) ' +
         '  , ExceedNum = ''          '' ' +
         '  , ExternNum =''                              '' ' +
         '  , BuyerPO = ''                    '' ' +
         '  , AddDate = N''' + CONVERT(CHAR(12), RTRIM(@BFDate)) + ''' ' +
         '  , picked = 0 ' +
         '  , susr3 = SMR.SUSR3 ' +
         '  , InvoiceNo = ''          ''  ' +
         'FROM ' + RTRIM(@cArchiveDB) + '..ARCHIVEOpenBal ARC WITH (NOLOCK) ' +
         'JOIN (SELECT Storerkey, SKU, SUSR3, ItemClass ' +
         '      FROM #ITRN_CUT_BY_SKU ' +
         '      GROUP BY Storerkey, SKU, SUSR3, ItemClass) As SMR ON SMR.Storerkey = ARC.Storerkey AND SMR.SKU = ARC.SKU '
EXEC (@c_sql)
-- End : SOS99065

/* sum up everything before the @datemin including archive qtys */
SELECT  StorerKey = UPPER(StorerKey)
     , itemclass
     , Sku
     , QTY = SUM(Qty)
     , AddDate = @BFDate
     , Flag = 'AA'
     , TranType = '     '
     , ExceedNum = '          '
     , ExternNum ='                              '
     , BuyerPO = '                    '
     , RunningTotal = sum(qty)
     , Record_number = 0
     , picked = 0
     , susr3 -- Added By Vicky 10 June 2003 SOS#11541
     , InvoiceNo = '          '  --Added by Shong 28/11/03 SOS#17492
INTO  #BF
FROM  #ITRN_CUT_BY_SKU
WHERE AddDate < @d_begin_date
GROUP BY StorerKey, itemclass, Sku, susr3
SELECT @n_num_recs = @@rowcount

/* if this is a new product */
/* or the data does not exist for the lower part of the  date range */

IF @n_continue=1 or @n_continue=2
BEGIN
 IF (@n_num_recs = 0)
 BEGIN
   INSERT #BF
   SELECT  StorerKey = UPPER(StorerKey)
         , itemclass
         , Sku
         , QTY= 0
         , AddDate = @bfDate
         , Flag = 'AA'
         , TranType = '          '
         , ExceedNum = '          '
         , ExternNum = '                              '
         , BuyerPO = '                    '
         , RunningTotal = 0
         , record_number = 0
         , picked = 0
         , susr3 -- Added By Vicky 10 June 2003 SOS#11541
         , InvoiceNo = '          ' -- Added by Shong 28/11/03 SOS#17492
   FROM #ITRN_CUT_BY_SKU
   GROUP by StorerKey, itemclass, Sku, susr3
 END /* numrecs = 0 */
END /* for n_continue etc. */

IF @n_continue=1 or @n_continue=2
BEGIN
   /* pick up the unique set of records which are in the in between period */
   IF (@n_num_recs > 0)
   BEGIN
      SELECT  StorerKey = UPPER(StorerKey)
           , itemclass
           , Sku
           , qty = 0
           , AddDate = @bfDate
           , flag='AA'
           , TranType = '          '
           , ExceedNum = '          '
           , ExternNum = '                              '
           , BuyerPO = '                    '
           , RunningTotal = 0
           , picked = 0
           , susr3 -- Added By Vicky 10 June 2003 SOS#11541
           , InvoiceNo = '          ' -- Added by Shong 28/11/03 SOS#17492
      INTO #BF_TEMP3
      FROM #ITRN_CUT_BY_SKU
      WHERE (AddDate > @d_begin_date and AddDate <= @d_end_date)
      GROUP BY StorerKey, itemclass, Sku, susr3

      SELECT @n_num_recs = @@rowcount
      SELECT @n_err = @@ERROR
      IF NOT @n_err = 0
      BEGIN
        SELECT @n_continue = 3
        /* Trap SQL Server Error */
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Summary Insert Failed On #BF_TEMP (nsp_smr_by_Commodity)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
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
     SELECT StorerKey = UPPER(a.storerkey),
            a.itemclass,
            a.sku,
            0 as qty,
            @bfDate as AddDate,
            'AA' as flag,
            TranType = '          ',
            ExceedNum = '          ',
            ExternNum = '                              ',
            BuyerPO = '                    ',
            RunningTotal = 0,
            picked = 0,
            a.susr3, -- Added By Vicky 10 June 2003 SOS#11541
            InvoiceNo = '          ' -- Added by Shong 28/11/03 SOS#17492
      into #BF_TEMP3a
      from #bf_temp3 a
      WHERE not exists
      (SELECT * from #BF b
       WHERE a.StorerKey = b.StorerKey
       AND   a.Sku = b.Sku)

      SELECT @n_err = @@ERROR
      SELECT @n_num_recs_bb = (SELECT COUNT(*) FROM #BF_TEMP3a)

      IF NOT @n_err = 0
      BEGIN
        SELECT @n_continue = 3
         /* Trap SQL Server Error */
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Summary Insert Failed On #BF_TEMP (nsp_smr_by_Commodity)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
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
               , AddDate
               , flag
               , TranType
               , ExceedNum
               , ExternNum
               , BuyerPO
               , RunningTotal
               , 0
               , picked
               , susr3 -- Added By Vicky 10 June 2003 SOS#11541
               , InvoiceNo -- Added by Shong 28/11/03 SOS#17492
         FROM #BF_TEMP3a

         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
           SELECT @n_continue = 3
           /* Trap SQL Server Error */
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Summary Insert Failed On #BF_TEMP3a (nsp_smr_by_Commodity)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
           /* End Trap SQL Server Error */
         END
       END
   END /* continue and stuff */

   /* ...then add all the data between the requested dates. */

   SELECT  StorerKey
        , itemclass
        , Sku
        , Qty
        , AddDate = convert(datetime,CONVERT(char(11), AddDate,106))
        , Flag = '  '
        , TranType
        --, ExceedNum
        , ExceedNum = Case WHEN #ITRN_CUT_BY_SKU.ExceedNum is NULL THEN ' ' -- Modify by Vicky 23 Dec 2002 SOS#9077
                      ELSE #ITRN_CUT_BY_SKU.Exceednum
                      END
        , ExternNum
        , BuyerPO
        , RunningTotal = 0
        , record_number = 0
        , picked
        , susr3 -- Added By Vicky 10 June 2003 SOS#11541
        , InvoiceNo -- Added by Shon 28/11/03 SOS#17492
   INTO #BF2
   FROM #ITRN_CUT_BY_SKU
   WHERE AddDate >= @d_begin_date

   INSERT #BF
   SELECT  StorerKey
        , itemclass
        , Sku
        , SUM(Qty)
        , AddDate
        ,  '  '
        , TranType
        , ExceedNum
        , ExternNum
        , BuyerPO
        , 0
        , 0
        , picked
        , susr3 -- Added By Vicky 10 June 2003 SOS#11541
        , InvoiceNo -- Added by Shong 28/11/03 SOS#17492
   FROM #BF2
   GROUP BY
          StorerKey
        , itemclass
        , Sku
        , AddDate
        , TranType
        , ExceedNum
        , ExternNum
        , BuyerPO
        , picked
        , susr3 -- Added By Vicky 10 June 2003 SOS#11541
        , InvoiceNo -- Added by Shong 28/11/03 SOS#17492

   IF (@b_debug = 1)
   BEGIN
      SELECT
           StorerKey
         , itemclass
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
         , susr3 -- Added By Vicky 10 June 2003 SOS#11541
         , Invoiceno -- Added by Shong 28/11/03 SOS#17492
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
   DECLARE @AddDate datetime
   DECLARE @Flag  NVARCHAR(2)
   DECLARE @TranType NVARCHAR(20) -- Changed By Vicky 10 June 2003 SOS#11541
   DECLARE @ExceedNum NVARCHAR(10)
   DECLARE @ExternNum NVARCHAR(30)
   DECLARE @BuyerPO NVARCHAR(20)
   DECLARE @RunningTotal int
   declare @picked int
   DECLARE @susr3 NVARCHAR(18) -- Added By Vicky 10 June 2003 SOS#11541
   DECLARE @InvoiceNo NVARCHAR(20) -- Added by Shong 28/11/03 SOS#17492
   DECLARE @prev_StorerKey NVARCHAR(15)
   declare @prev_itemclass NVARCHAR(10)
   DECLARE @prev_Sku NVARCHAR(20)
   DECLARE @prev_Lot NVARCHAR(10)
   DECLARE @prev_Qty int
   DECLARE @prev_AddDate datetime
   DECLARE @prev_Flag  NVARCHAR(2)
   DECLARE @prev_TranType NVARCHAR(20) --Changed By Vicky 10 June 2003 SOS#11541
   DECLARE @prev_ExceedNum NVARCHAR(10)
   DECLARE @prev_ExternNum NVARCHAR(30)
   DECLARE @prev_BuyerPO NVARCHAR(20)
   DECLARE @prev_RunningTotal int
   declare @prev_picked int
   DECLARE @record_number int
   DECLARE @prev_susr3 NVARCHAR(18)
   DECLARE @prev_InvoiceNo NVARCHAR(20) -- Added by Shong 28/11/03 SOS#17492

   SELECT @record_number = 1

   DELETE #BF2

   SELECT @RunningTotal = 0

   execute('DECLARE cursor_for_running_total CURSOR  FAST_FORWARD READ_ONLY
      FOR  SELECT
        StorerKey
      , itemclass
      , Sku
      , Qty
      , AddDate
      , Flag
      , TranType
      , ExceedNum
      , ExternNum
      , BuyerPO
      , picked
      , susr3
      , InvoiceNo
      FROM #BF
      ORDER BY StorerKey, itemclass, sku, flag desc, AddDate')

   OPEN cursor_for_running_total

   FETCH NEXT FROM cursor_for_running_total
   INTO  @StorerKey,
         @itemclass,
         @Sku,
         @Qty,
         @AddDate,
         @Flag,
         @TranType,
         @ExceedNum,
         @ExternNum,
         @BuyerPO,
         @picked,
         @susr3, -- Added By Vicky 10 June 2003 SOS#11541
         @InvoiceNo -- Added by Shong 28/11/03 SOS#17492

   WHILE (@@fetch_status <> -1)
   BEGIN
      IF (@b_debug = 1)
      BEGIN
         SELECT @StorerKey,'|',
           @itemclass,'|',
           @Sku,'|',
           @Qty,'|',
           @AddDate,'|',
           @Flag,'|',
           @TranType,'|',
           @ExceedNum,'|',
           @ExternNum,'|',
           @BuyerPO,'|',
           @RunningTotal,'|',
           @record_number'|',
           @picked'|',
           @susr3, -- Added By Vicky 10 June 2003 SOS#11541
           @InvoiceNo,'|' -- Added by Shong 28/11/03 SOS#17492
      END

      IF (rtrim(@TranType) = 'DP' or rtrim(@TranType) = 'WD' or
          rtrim(@TranType) = 'AJ')
      BEGIN
           SELECT @RunningTotal = @RunningTotal + @qty
      END

      IF (rtrim(@Flag) = 'AA' or rtrim(@Flag) = 'BB')
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
                 @AddDate,
                 @Flag,
                 @TranType,
                 @ExceedNum,
                 @ExternNum,
                 @BuyerPO,
                 @RunningTotal,
                 @record_number,
                 @picked,
                 @susr3,-- Added By Vicky 10 June 2003 SOS#11541
                 @InvoiceNo) --Added by Shong 28/11/03 SOS#17492

      SELECT @prev_StorerKey = @StorerKey
      SELECT @prev_itemclass = @itemclass
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
      SELECT @prev_susr3 = @susr3 -- Added By Vicky 10 June 2003 SOS#11541
      SELECT @prev_InvoiceNo = @InvoiceNo -- Added by Shong 28/11/03 SOS#17492

      FETCH NEXT FROM cursor_for_running_total
      INTO  @StorerKey,
            @itemclass,
            @Sku,
            @Qty,
            @AddDate,
            @Flag,
            @TranType,
            @ExceedNum,
            @ExternNum,
            @BuyerPO,
            @picked,
            @susr3, -- Added By Vicky 10 June 2003 SOS#11541
            @InvoiceNo -- Added by Shong 28/11/03 SOS#17492

      SELECT @record_number = @record_number + 1
      IF (@storerkey <> @prev_storerkey AND @itemclass <> @prev_itemclass AND @sku <> @prev_sku)
      BEGIN
        IF (@b_debug = 1)
        BEGIN
             SELECT 'prev_storerkey', @prev_storerkey, 'itemclass', @prev_itemclass, 'sku', @sku
        END

        SELECT @runningtotal = 0
      END
   END /* while loop */

   close cursor_for_running_total
   deallocate cursor_for_running_total

   --SELECT * from #BF2
   --return

   /* Output the data collected. */
   IF @b_debug = 0
   BEGIN
      SELECT
         UPPER(#BF2.StorerKey)
         , STORER.Company
         , UPPER(#BF2.itemclass)
         , UPPER(#BF2.Sku)
         , SKU.Descr
         , #BF2.Qty
         , AddDate =
            CASE WHEN #BF2.AddDate < @d_begin_date THEN null
                 ELSE #BF2.AddDate
                 END
         , #BF2.Flag
         , TranType =
            CASE
                  WHEN #BF2.Flag = 'AA' THEN 'Beginning Balance'
                  WHEN #BF2.TranType = 'DP' THEN 'Deposit'
                  WHEN #BF2.TranType = 'WD' and #BF2.picked = 1 THEN 'Withdrawal(P)'
                  WHEN #BF2.TranType = 'WD' THEN 'Withdrawal'
                  WHEN #BF2.TranType = 'WD-TF' THEN 'Withdrawal(TF)'
                  WHEN #BF2.TranType = 'DP-TF' THEN 'Deposit(TF)'
            END
         , #BF2.ExceedNum
         , #BF2.ExternNum
         , #BF2.BuyerPO
         , #BF2.RunningTotal
         , #BF2.picked
         , #BF2.susr3 -- Added By Vicky 10 June 2003 SOS#11541
         , 'INV94' -- report id
         , 'From ' + @DateStringMin + ' To '+ @DateStringMax
         , #BF2.InvoiceNo -- Added by Shong 28/11/03 SOS#17492
      FROM #BF2,
      STORER (NOLOCK),
      SKU (NOLOCK)
      WHERE #BF2.StorerKey = STORER.StorerKey
      AND #BF2.StorerKey = SKU.StorerKey
      AND #BF2.Sku = SKU.Sku
      ORDER BY
      #BF2.record_number
   END

   IF @b_debug = 1
   BEGIN
      SELECT
      UPPER(#BF2.StorerKey)
      , UPPER(#BF2.itemclass)
      , UPPER(#BF2.Sku)
      , #BF2.Qty
      , EffDate = convert(char(11),#BF2.AddDate,106)
      , #BF2.Flag
      , #BF2.TranType
      , #BF2.ExceedNum
      , #BF2.ExternNum
      , #BF2.BuyerPO
      , #BF2.RunningTotal
      , #BF2.InvoiceNo -- Added by Shong 28/11/03 SOS#17492
      FROM #BF2
      ORDER BY
      #BF2.record_number
   END
END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/

GO