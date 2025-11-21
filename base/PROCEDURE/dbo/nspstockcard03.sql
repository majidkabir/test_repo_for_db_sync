SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspStockCard03                                     */
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

CREATE PROC [dbo].[nspStockCard03](
@c_storerstart NVARCHAR(15),
@c_storerend NVARCHAR(15),
@c_skustart NVARCHAR(20),
@c_skuend NVARCHAR(20),
@d_datestart NVARCHAR(8),
@d_dateend NVARCHAR(8),
@c_whse	 NVARCHAR(6)
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   

   DECLARE @d_date_start	datetime,
   @d_date_end	datetime,
   @c_sku	 NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_storerkey NVARCHAR(15),
   @c_company NVARCHAR(60),
   @c_uom	 NVARCHAR(10),
   @c_trantype NVARCHAR(10),
   @c_doctype NVARCHAR(10),
   @c_docno NVARCHAR(10),
   @c_refno NVARCHAR(10),
   @c_mfglot NVARCHAR(18),
   @d_expiry	datetime,
   @n_qtyopen	int,
   @n_qty		int,
   @c_itrnkey NVARCHAR(10),
   @c_sourcetype NVARCHAR(30),
   @c_sourcekey NVARCHAR(10),
   @d_trandate NVARCHAR(10),
   @n_qtyclose	int,
   @n_qtyalloc	int
   SELECT @d_date_start = CONVERT(datetime, @d_datestart)
   SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))
   /*Create Temp Result table */
   SELECT trantype = ITRN.trantype,
   ITRN.storerkey storerkey,
   company = space(60),
   ITRN.sku sku,
   descr = space(60),
   uom = space(2),
   doctype = space(10),
   docno = space(10),
   refno = space(10),
   mfglot = space(18),
   expiry = ITRN.lottable04,
   qtyopen = ITRN.qty,
   qty = ITRN.qty,
   trandate = ITRN.editdate,
   qtyclose = ITRN.qty,
   logical = space(18)
   INTO #RESULT
   FROM ITRN (NOLOCK)
   WHERE 1 = 2
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT ITRN.itrnkey, ITRN.sku, ITRN.trantype, ITRN.sourcetype
   FROM ITRN (NOLOCK) INNER JOIN LOTATTRIBUTE (NOLOCK)
   ON ITRN.lot = LOTATTRIBUTE.lot
   AND ITRN.trantype <> 'MV'
   AND ITRN.storerkey BETWEEN @c_storerstart AND @c_storerend
   AND ITRN.sku BETWEEN @c_skustart AND @c_skuend
   AND LOTATTRIBUTE.lottable03 = @c_whse
   ORDER BY ITRN.sku
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_itrnkey, @c_sku, @c_trantype, @c_sourcetype
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- beginning balance
      SELECT @n_qtyopen = COALESCE(SUM(qty), 0)
      FROM ITRN (NOLOCK) INNER JOIN LOTATTRIBUTE (NOLOCK)
      ON ITRN.lot = LOTATTRIBUTE.lot
      AND trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_date_start
      AND ITRN.sku = @c_sku
      AND LOTATTRIBUTE.lottable03 = @c_whse
      SELECT @n_qtyalloc = COALESCE(SUM(qty), 0)
      FROM PICKDETAIL (NOLOCK) INNER JOIN LOTATTRIBUTE (NOLOCK)
      ON PICKDETAIL.lot = LOTATTRIBUTE.lot
      AND PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate < @d_date_start
      AND LOTATTRIBUTE.lottable03 = @c_whse
      AND PICKDETAIL.status <> '9'

      SELECT @n_qtyopen = @n_qtyopen - @n_qtyalloc
      SELECT @c_sourcekey = LEFT(sourcekey,10), @d_trandate = CONVERT(char(10),editdate,101)
      FROM ITRN (NOLOCK)
      WHERE itrnkey = @c_itrnkey
      SELECT @n_qty = 0
      -- deposit
      IF @c_trantype = 'DP' AND @c_sourcetype <> ''
      BEGIN
         -- deposit by receipt
         IF @c_trantype = 'DP' AND @c_sourcetype IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
         BEGIN
            SELECT @c_mfglot = ITRN.lottable02,
            @d_expiry = ITRN.lottable04,
            @n_qty = ITRN.qty,
            @c_refno = RECEIPT.warehousereference,
            @c_doctype = RECEIPT.rectype
            FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            AND RECEIPT.receiptkey = @c_sourcekey
            AND ITRN.editdate >= @d_date_start
            AND ITRN.editdate < @d_date_end
         END
      ELSE
         BEGIN
            -- deposit by transfer
            SELECT @c_mfglot = ITRN.lottable02,
            @d_expiry = ITRN.lottable04,
            @n_qty = ITRN.qty,
            @c_refno = TRANSFER.customerrefno,
            @c_doctype = 'IWT'
            FROM ITRN (NOLOCK), TRANSFER (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey
            AND ITRN.editdate >= @d_date_start
            AND ITRN.editdate < @d_date_end
            AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
         END
      END
   ELSE
      BEGIN
         SELECT @c_mfglot = ITRN.lottable02,
         @d_expiry = ITRN.lottable04,
         @n_qty = ITRN.qty,
         @c_doctype = 'PC'
         FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         AND ITRN.editdate >= @d_date_start
         AND ITRN.editdate < @d_date_end
         AND ITRN.trantype = 'DP'
      END

      -- withdrawal
      IF @c_trantype = 'WD' AND @c_sourcetype = 'ntrPickDetailUpdate'
      BEGIN
         -- withdrawal by shipment order
         SELECT @c_mfglot = ORDERDETAIL.lottable02,
         @d_expiry = ORDERDETAIL.lottable04,
         @n_qty = ITRN.qty,
         -- @n_qty = ORDERDETAIL.originalqty + ORDERDETAIL.freegoodqty,
         @c_docno = ORDERS.invoiceno,
         @c_refno = ORDERS.externorderkey,
         @c_doctype = ORDERS.type
         FROM ITRN (NOLOCK), ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         AND ITRN.sourcekey = PICKDETAIL.pickdetailkey
         AND PICKDETAIL.orderkey = ORDERS.orderkey
         AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
         AND ORDERS.orderkey = ORDERDETAIL.orderkey
         AND ORDERDETAIL.sku = @c_sku
         AND ITRN.lot = LOTATTRIBUTE.lot
         AND LOTATTRIBUTE.lottable03 = @c_whse
         --		  AND ORDERDETAIL.lottable03 = @c_whse
         AND ITRN.editdate >= @d_date_start
         AND ITRN.editdate < @d_date_end
      END
   ELSE
      BEGIN
         -- withdrawal by transfer
         SELECT @c_mfglot = TRANSFERDETAIL.lottable02,
         @d_expiry = TRANSFERDETAIL.lottable04,
         @n_qty = ITRN.qty,
         @c_refno = TRANSFER.customerrefno,
         @c_doctype = 'IWT'
         FROM ITRN (NOLOCK), TRANSFER (NOLOCK), TRANSFERDETAIL (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey
         AND TRANSFER.transferkey = TRANSFERDETAIL.transferkey
         AND ITRN.sourcekey = TRANSFERDETAIL.transferkey + TRANSFERDETAIL.transferlinenumber
         AND ITRN.editdate >= @d_date_start
         AND ITRN.editdate < @d_date_end
         AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
      END

      -- adjustment transactions
      IF @c_trantype = 'AJ'
      BEGIN
         -- adjustment records
         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sourcetype)) = 'ntrAdjustmentDetailAdd'
         BEGIN
            SELECT @c_mfglot = LOTATTRIBUTE.lottable02,
            @d_expiry = LOTATTRIBUTE.lottable04,
            @n_qty = ITRN.qty,
            @c_refno = ADJUSTMENT.customerrefno,
            @c_doctype = ADJUSTMENT.adjustmenttype
            FROM ITRN (NOLOCK), ADJUSTMENT (NOLOCK), ADJUSTMENTDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            AND ADJUSTMENT.adjustmentkey = @c_sourcekey
            AND ITRN.sourcekey = ADJUSTMENT.adjustmentkey + ADJUSTMENTDETAIL.adjustmentlinenumber
            AND ADJUSTMENTDETAIL.lot = LOTATTRIBUTE.lot
            AND ADJUSTMENTDETAIL.sku = @c_sku
            AND LOTATTRIBUTE.lottable03 = @c_whse
            AND ITRN.editdate >= @d_date_start
            AND ITRN.editdate < @d_date_end
         END
      ELSE -- cycle/physical count
         BEGIN
            SELECT @c_mfglot = LOTATTRIBUTE.lottable02,
            @d_expiry = LOTATTRIBUTE.lottable04,
            @n_qty = ITRN.qty,
            @c_refno = ITRN.sourcekey,
            @c_doctype = 'COUNT'
            FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            AND ITRN.lot = LOTATTRIBUTE.lot
            AND ITRN.sku = @c_sku
            AND LOTATTRIBUTE.lottable03 = @c_whse
            AND ITRN.editdate >= @d_date_start
            AND ITRN.editdate < @d_date_end
         END
      END
      -- get addtl data
      SELECT @c_storerkey = SKU.storerkey,
      @c_descr = SKU.descr,
      @c_uom = PACK.packuom3,
      @c_company = STORER.company
      FROM SKU (NOLOCK), PACK (NOLOCK), STORER (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.storerkey = STORER.storerkey
      AND SKU.packkey = PACK.packkey
      IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0
      SELECT @n_qtyclose = SUM(LOT.qty - LOT.qtyallocated)
      FROM LOT, LOTATTRIBUTE
      WHERE LOT.lot = LOTATTRIBUTE.lot
      AND LOT.sku = @c_sku
      AND LOTATTRIBUTE.lottable03 = @c_whse
      IF @c_sku NOT IN (SELECT sku FROM #RESULT)
      INSERT #RESULT
      VALUES (@c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
      CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose,@c_whse)
   ELSE IF @n_qty <> 0
      INSERT #RESULT
      VALUES (@c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
      CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose,@c_whse)

      FETCH NEXT FROM cur_1 INTO @c_itrnkey, @c_sku, @c_trantype, @c_sourcetype
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   -- check for qtyallocated but not yet shipped
   DECLARE cur_2 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT orderkey, sku, qtyallocated
   FROM ORDERDETAIL
   WHERE shippedqty = 0
   AND qtyallocated <> 0
   AND lottable03 = @c_whse
   AND storerkey BETWEEN @c_storerstart AND @c_storerend
   AND sku BETWEEN @c_skustart AND @c_skuend
   AND editdate BETWEEN @d_date_start AND @d_date_end
   DECLARE @c_orderkey NVARCHAR(10)
   OPEN cur_2
   FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- beginning balance
      SELECT @n_qtyopen = COALESCE(SUM(qty), 0)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_date_start
      AND ITRN.sku = @c_sku
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      SELECT @n_qtyalloc = COALESCE(SUM(qty), 0)
      FROM PICKDETAIL (NOLOCK) INNER JOIN LOTATTRIBUTE (NOLOCK)
      ON PICKDETAIL.lot = LOTATTRIBUTE.lot
      AND PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate < @d_date_start
      AND LOTATTRIBUTE.lottable03 = @c_whse
      AND PICKDETAIL.status <> '9'
      SELECT @n_qtyopen = @n_qtyopen - @n_qtyalloc
      SELECT @c_mfglot = ORDERDETAIL.lottable02,
      @d_expiry = ORDERDETAIL.lottable04,
      @c_docno = ORDERS.invoiceno,
      @c_refno = ORDERS.externorderkey,
      @c_doctype = ORDERS.type,
      @d_trandate = CONVERT(char(10),ORDERDETAIL.editdate,101)
      FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK)
      WHERE ORDERS.orderkey = @c_orderkey
      AND ORDERDETAIL.orderkey = @c_orderkey
      AND ORDERDETAIL.sku = @c_sku
      -- get addtl data
      SELECT @c_storerkey = SKU.storerkey,
      @c_descr = SKU.descr,
      @c_uom = PACK.packuom3,
      @c_company = STORER.company
      FROM SKU (NOLOCK), PACK (NOLOCK), STORER (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.storerkey = STORER.storerkey
      AND SKU.packkey = PACK.packkey
      SELECT @n_qtyclose = SUM(LOT.qty - LOT.qtyallocated)
      FROM LOT, LOTATTRIBUTE
      WHERE LOT.lot = LOTATTRIBUTE.lot
      AND LOT.sku = @c_sku
      AND LOTATTRIBUTE.lottable03 = @c_whse
      INSERT #RESULT
      VALUES ('WD',@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
      CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose,@c_whse)
      FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty
   END
   CLOSE cur_2
   DEALLOCATE cur_2
   DELETE #RESULT WHERE qtyopen = 0 AND qty = 0
   -- SELECT * FROM #RESULT
   SELECT trantype,
   storerkey,
   company,
   sku,
   descr,
   uom,
   doctype,
   docno,
   refno,
   mfglot,
   expiry,
   qtyopen,
   qty = sum(qty),
   trandate,
   qtyclose,
   logical
   FROM #RESULT
   GROUP BY trantype,
   storerkey,
   company,
   sku,
   descr,
   uom,
   doctype,
   docno,
   refno,
   mfglot,
   expiry,
   qtyopen,
   trandate,
   qtyclose,
   logical
   ORDER BY sku, trandate
   DROP TABLE #RESULT
END	-- main procedure

GO