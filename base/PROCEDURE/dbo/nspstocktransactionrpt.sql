SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspStockTransactionRpt                             */
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

CREATE PROC [dbo].[nspStockTransactionRpt](
@c_facilitystart NVARCHAR(5),
@c_facilityend NVARCHAR(5),
@c_storerstart NVARCHAR(15),
@c_storerend NVARCHAR(15),
@c_skustart NVARCHAR(20),
@c_skuend NVARCHAR(20),
@d_datestart	datetime,
@d_dateend	datetime
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
   @c_company NVARCHAR(45),
   @c_uom	 NVARCHAR(10),
   @c_trantype NVARCHAR(10),
   @c_doctype NVARCHAR(10), -- ??
   @c_docno NVARCHAR(10),
   @c_refno NVARCHAR(10),
   @c_lottable02 NVARCHAR(18),
   @d_lottable04 datetime,
   @n_qtyopen	int,
   @n_qty		int,
   @c_itrnkey NVARCHAR(10),
   @c_sourcetype NVARCHAR(30),
   @c_sourcekey NVARCHAR(20),
   --@d_trandate NVARCHAR(10),
   @d_trandate datetime,
   --@n_qtyclose	int,
   @c_facility NVARCHAR(5),
   @c_lottable02label NVARCHAR(20),
   @c_lottable04label NVARCHAR(20)
   --
   -- SELECT @d_date_start = CONVERT(datetime, @d_datestart)
   -- SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))

   /*Create Temp Result table */
   SELECT trantype = ITRN.trantype,
   ITRN.storerkey storerkey,
   company = space(60),
   ITRN.sku sku,
   descr = space(60),
   uom = space(2),
   doctype = space(10), --trantype
   sourcekey = space(10), --sourcekey
   refno = space(10), --from other tables
   facility = space(5),
   ITRN.lottable02 lottable02,
   ITRN.lottable04 lottable04,
   qtyopen = ITRN.qty,
   qty = ITRN.qty,
   trandate = ITRN.editdate,
   --qtyclose = ITRN.qty,
   lottable02label = space(20),
   lottable04label = space(20)
   INTO #RESULT
   FROM ITRN (NOLOCK)
   WHERE 1 = 2

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT ITRN.itrnkey, ITRN.sku, ITRN.trantype, ITRN.sourcetype
   FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
   WHERE ITRN.lot = LOTATTRIBUTE.lot
   AND ITRN.trantype <> 'MV'
   AND ITRN.storerkey >= @c_storerstart
   AND ITRN.storerkey <= @c_storerend
   AND ITRN.sku >= @c_skustart
   AND ITRN.sku <= @c_skuend
   AND ITRN.EditDate >= @d_datestart
   AND ITRN.EditDate <= @d_dateend
   -- GROUP BY sku,
   ORDER BY ITRN.sku

   If @d_trandate = null
   select @d_trandate = getdate()

   IF @c_lottable02 = null
   select @c_lottable02 = ' '

   IF @d_lottable04 = null
   select @d_lottable04 = ' '

   --select 'openqty', @n_qtyopen

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_itrnkey, @c_sku, @c_trantype, @c_sourcetype
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- beginning balance
      SELECT @n_qtyopen = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_datestart
      --AND ITRN.sku = @c_sku
      --AND ITRN.storerkey = @c_storerkey
      AND ITRN.storerkey >= @c_storerstart
      AND ITRN.storerkey <= @c_storerend
      AND ITRN.sku >= @c_skustart
      AND ITRN.sku <= @c_skuend
      AND ITRN.lot = LOTATTRIBUTE.lot
      --    AND ITRN.lottable02 = Lotattribute.lottable02
      --    AND ITRN.lottable04 = Lotattribute.lottable04

      --select 'openqty', @n_qtyopen

      SELECT @c_sourcekey = LEFT(sourcekey,10)--, @d_trandate = CONVERT(char(10),editdate,101)
      FROM ITRN (NOLOCK)
      WHERE itrnkey = @c_itrnkey

      SELECT @n_qty = 0

      -- deposit
      IF @c_trantype = 'DP' AND @c_sourcetype <> ''
      BEGIN
         -- deposit by receipt
         IF @c_trantype = 'DP' AND @c_sourcetype IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
         BEGIN
            SELECT @c_lottable02 = ITRN.lottable02,
            @d_lottable04 = ITRN.lottable04,
            @n_qty =  ITRN.qty,
            @c_refno = RECEIPT.Externreceiptkey,
            @c_doctype = 'DP',
            --  @c_doctype = ITRN.Trantype,
            -- @c_sourcekey = ITRN.Sourcekey,
            @c_sourcekey = LEFT(ITRN.sourcekey,10),
            @c_facility = RECEIPT.Facility,
            @d_trandate = ITRN.editdate
            FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            AND RECEIPT.Storerkey = ITRN.Storerkey
            AND RECEIPT.receiptkey = @c_sourcekey
            AND ITRN.editdate >= @d_datestart
            AND ITRN.editdate <= @d_dateend
            AND RECEIPT.Facility >= @c_facilitystart
            AND RECEIPT.Facility <= @c_facilityend
            AND ITRN.storerkey >= @c_storerstart
            AND ITRN.storerkey <= @c_storerend
         END

      ELSE
         BEGIN
            -- deposit by transfer
            SELECT @c_lottable02 = ITRN.lottable02,
            @d_lottable04 = ITRN.lottable04,
            @n_qty = ITRN.qty,
            @c_refno = TRANSFER.customerrefno,
            @c_doctype = 'TR+',
            @c_sourcekey = ITRN.Sourcekey,
            @c_facility = TRANSFER.Facility ,
            @d_trandate = ITRN.editdate
            FROM ITRN (NOLOCK), TRANSFER (NOLOCK)
            WHERE ITRN.itrnkey = @c_itrnkey
            -- AND ITRN.Storerkey = Transfer.storerkey
            AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey
            --  AND ITRn.Sourcekey = TRANSFER.transferkey
            AND ITRN.editdate >= @d_datestart
            AND ITRN.editdate <= @d_dateend
            AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
            -- AND TRANSFER.Facility >= @c_facilitystart
            -- AND TRANSFER.Facility <= @c_facilityend
            AND ITRN.storerkey >= @c_storerstart
            AND ITRN.storerkey <= @c_storerend
         END
      END
   ELSE
      BEGIN
         SELECT @c_lottable02 = ITRN.lottable02,
         @d_lottable04 = ITRN.lottable04,
         @n_qty = ITRN.qty,
         @c_doctype = 'DP',
         --@c_sourcekey = ITRN.Sourcekey,
         @c_sourcekey = LEFT(ITRN.sourcekey,10),
         @c_facility = RECEIPT.Facility,
         @d_trandate = ITRN.editdate
         FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         AND RECEIPT.Receiptkey = @c_sourcekey
         AND ITRN.Storerkey = RECEIPT.Storerkey
         AND ITRN.editdate >= @d_datestart
         AND ITRN.editdate <= @d_dateend
         AND ITRN.trantype = 'DP'
         AND RECEIPT.Facility >= @c_facilitystart
         AND RECEIPT.Facility <= @c_facilityend
         AND ITRN.storerkey >= @c_storerstart
         AND ITRN.storerkey <= @c_storerend
      END

      --select 'dp qty', @n_qty

      -- withdrawal
      --IF @c_trantype = 'WD' AND @c_sourcetype <> ''
      --BEGIN

      IF @c_trantype = 'WD' AND @c_sourcetype = 'ntrPickDetailUpdate'
      BEGIN
         -- withdrawal by shipment order
         SELECT @c_lottable02 = ORDERDETAIL.lottable02,
         @d_lottable04 = ORDERDETAIL.lottable04,
         @n_qty = ITRN.qty,
         --@n_qty = ORDERDETAIL.originalqty + ORDERDETAIL.freegoodqty,
         --@c_docno = ORDERS.invoiceno, --??
         @c_refno = ORDERS.externorderkey,
         --@c_doctype = ITRN.trantype,
         @c_doctype = 'WD',
         --@c_sourcekey = ITRN.Sourcekey,
         @c_sourcekey = LEFT(ITRN.sourcekey,10),
         @c_facility = ORDERS.Facility,
         @d_trandate = ITRN.editdate
         FROM ITRN (NOLOCK), ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         --  AND ITRN.sourcekey = PICKDETAIL.pickdetailkey
         AND PICKDETAIL.pickdetailkey = @c_sourcekey
         --  AND PICKDETAIL.Orderkey = @c_sourcekey
         AND PICKDETAIL.orderkey = ORDERS.orderkey
         AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
         AND ORDERS.orderkey = ORDERDETAIL.orderkey
         AND ORDERDETAIL.sku = ITRN.sku
         AND ORDERDETAIl.Storerkey = ITRN.Storerkey
         AND ITRN.sku >= @c_skustart
         AND ITRN.sku <= @c_skuend
         --  AND ORDERDETAIL.lottable02 = @c_lottable02
         -- AND ORDERDETAIL.lottable04 = @d_lottable04
         AND ITRN.editdate >= @d_datestart
         AND ITRN.editdate <= @d_dateend
         AND ORDERS.Facility >= @c_facilitystart
         AND ORDERS.Facility <= @c_facilityend
         AND ITRN.storerkey >= @c_storerstart
         AND ITRN.storerkey <= @c_storerend

      END
   ELSE
      BEGIN
         -- withdrawal by transfer
         SELECT @c_lottable02 = TRANSFERDETAIL.lottable02,
         @d_lottable04 = TRANSFERDETAIL.lottable04,
         @n_qty = ITRN.qty,
         @c_refno = TRANSFER.customerrefno,
         @c_doctype = 'TR-',
         @c_sourcekey = ITRN.Sourcekey,
         @c_facility  = TRANSFER.Facility,
         @d_trandate = ITRN.editdate
         FROM ITRN (NOLOCK), TRANSFER (NOLOCK), TRANSFERDETAIL (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         --AND ITRN.Storerkey = Transfer.Storerkey
         AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey
         AND TRANSFER.transferkey = TRANSFERDETAIL.transferkey
         AND ITRN.sourcekey = TRANSFERDETAIL.transferkey + TRANSFERDETAIL.transferlinenumber
         AND ITRN.editdate >= @d_datestart
         AND ITRN.editdate <= @d_dateend
         AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
         --      AND TRANSFER.Facility >= @c_facilitystart
         --      AND TRANSFER.Facility <= @c_facilityend
         AND ITRN.storerkey >= @c_storerstart
         AND ITRN.storerkey <= @c_storerend
         AND ITRN.Trantype = 'WD'
      END
      --END
      --END
      -- adjustment transactions
      IF @c_trantype = 'AJ'
      BEGIN
         SELECT @c_lottable02 = LOTATTRIBUTE.lottable02,
         @d_lottable04 = LOTATTRIBUTE.lottable04,
         @n_qty = ITRN.qty,
         @c_refno = ADJUSTMENT.customerrefno,
         --@c_doctype = ADJUSTMENT.adjustmenttype
         @c_doctype = 'AJ',
         @c_sourcekey = ITRN.Sourcekey,
         @c_facility = ADJUSTMENT.Facility,
         @d_trandate = ITRN.editdate
         FROM ITRN (NOLOCK), ADJUSTMENT (NOLOCK), ADJUSTMENTDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK)
         WHERE ITRN.itrnkey = @c_itrnkey
         AND ITRN.Storerkey = ADJUSTMENT.Storerkey
         AND ADJUSTMENT.adjustmentkey = @c_sourcekey
         AND ITRN.sourcekey = ADJUSTMENT.adjustmentkey + ADJUSTMENTDETAIL.adjustmentlinenumber
         AND ADJUSTMENTDETAIL.lot = LOTATTRIBUTE.lot
         AND ADJUSTMENTDETAIL.sku = Lotattribute.sku
         AND LOTATTRIBUTE.Sku = ITRN.Sku
         AND ITRN.storerkey >= @c_storerstart
         AND ITRN.storerkey <= @c_storerend
         AND ITRN.sku >= @c_skustart
         AND ITRN.sku <= @c_skuend
         AND ITRN.editdate >= @d_datestart
         AND ITRN.editdate <= @d_dateend
         AND ADJUSTMENT.Facility >= @c_facilitystart
         AND ADJUSTMENT.Facility <= @c_facilityend
      END

      -- get addtl data
      SELECT @c_storerkey = SKU.storerkey,
      @c_descr = SKU.descr,
      @c_uom = PACK.packuom3,
      @c_company = STORER.company
      FROM SKU (NOLOCK), PACK (NOLOCK), STORER (NOLOCK)
      WHERE SKU.sku >= @c_skustart
      AND Sku.sku <= @c_skuend
      AND Sku.storerkey >= @c_storerstart
      AND Sku.storerkey <= @c_storerend
      AND SKU.storerkey = STORER.storerkey
      AND SKU.packkey = PACK.packkey

      SELECT @c_lottable02label = SKU.lottable02label,
      @c_lottable04Label = SKU.lottable04label
      FROM SKU (NOLOCK)
      WHERE SKU.sku >= @c_skustart
      AND   Sku.sku <= @c_skuend
      AND   SKU.storerkey >= @c_storerstart
      AND   Sku.storerkey <= @c_storerend

      IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0
      --
      -- 	SELECT @n_qtyclose = SUM(LOT.qty - LOT.qtyallocated)
      -- 	FROM LOT, LOTATTRIBUTE
      -- 	WHERE LOT.lot = LOTATTRIBUTE.lot
      -- 	  AND LOT.sku = @c_sku
      -- 	  AND LOTATTRIBUTE.lottable02 = @c_lottable02
      --      AND LOTATTRIBUTE.lottable04 = @d_lottable04

      --select 'trantype', @c_trantype, 'storer', @c_storerkey, 'company', @c_company, 'sku',@c_sku, 'descr', @c_descr,'oum', @c_uom,
      -- 'doctype', @c_doctype,'sourcekey', @c_sourcekey, 'refno', @c_refno, 'facility', @c_facility, 'lottable02', @c_lottable02,
      --		     'lot04', @d_lottable04, 'openqty' ,@n_qtyopen,' qty', @n_qty, 'trandate', @d_trandate,
      --'lotlabel02', @c_lottable02label, 'lotlabel04', @c_lottable04label

      IF @c_sku NOT IN (SELECT sku FROM #RESULT)
      INSERT #RESULT
      VALUES (@c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_sourcekey,@c_refno,@c_facility,@c_lottable02,
      @d_lottable04,@n_qtyopen,@n_qty,@d_trandate,@c_lottable02label,@c_lottable04label)
   ELSE IF @n_qty <> 0
      INSERT #RESULT
      VALUES (@c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_sourcekey,@c_refno,@c_facility,@c_lottable02,
      @d_lottable04, @n_qtyopen,@n_qty,@d_trandate,@c_lottable02label,@c_lottable04label)


      FETCH NEXT FROM cur_1 INTO @c_itrnkey, @c_sku, @c_trantype, @c_sourcetype
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   -- check for qtyallocated but not yet shipped
   DECLARE cur_2  CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT orderkey, sku, qtyallocated
   FROM ORDERDETAIL
   WHERE shippedqty = 0
   AND qtyallocated <> 0
   -- AND lottable02 = @c_lottable02
   -- AND lottable04 = @d_lottable04
   AND storerkey >= @c_storerstart
   AND storerkey <= @c_storerend
   AND sku >= @c_skustart
   AND sku <= @c_skuend

   DECLARE @c_orderkey NVARCHAR(10)

   OPEN cur_2
   FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- beginning balance
      SELECT @n_qtyopen = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_datestart
      AND ITRN.sku = @c_sku
      --  AND ITRN.storerkey >= @c_storerstart
      --   AND ITRN.storerkey <= @c_storerend
      --   AND ITRN.sku >= @c_skustart
      --   AND ITRN.sku <= @c_skuend
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND ITRN.Sku = Lotattribute.sku
      AND ITRN.Storerkey = Lotattribute.storerkey
      --  AND LOTATTRIBUTE.lottable02 = @c_lottable02
      --AND LOTATTRIBUTE.lottable04 = @d_lottable04

      IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0

      SELECT @c_lottable02 = ORDERDETAIL.lottable02,
      @d_lottable04 = ORDERDETAIL.lottable04,
      --@c_docno = ORDERS.invoiceno,
      @c_refno = ORDERS.externorderkey,
      --@c_doctype = ORDERS.type,
      --		@d_trandate = CONVERT(char(10),ORDERDETAIL.editdate,101),
      @d_trandate = ORDERDETAIL.editdate,
      @c_facility = ORDERS.Facility,
      @c_sourcekey = orders.orderkey
      FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK)
      WHERE ORDERS.orderkey = @c_orderkey
      AND ORDERDETAIL.orderkey = Orders.Orderkey
      AND ORDERDETAIL.sku = @c_sku
      --          AND ORDERDETAIL.sku <= @c_skuend
      -- get addtl data
      SELECT @c_storerkey = SKU.storerkey,
      @c_descr = SKU.descr,
      @c_uom = PACK.packuom3,
      @c_company = STORER.company
      FROM SKU (NOLOCK), PACK (NOLOCK), STORER (NOLOCK)
      WHERE SKU.sku = @c_sku
      -- AND SKU.sku <= @c_skuend
      AND SKU.storerkey = STORER.storerkey
      AND SKU.packkey = PACK.packkey

      SELECT @c_lottable02label = SKU.lottable02label,
      @c_lottable04Label = SKU.lottable04label
      FROM SKU (NOLOCK)
      WHERE SKU.sku >= @c_skustart
      AND  SKU.sku <= @c_skuend
      AND  SKU.storerkey >= @c_storerstart
      AND  SKU.storerkey <= @c_storerend

      -- 	SELECT @n_qtyclose = SUM(LOT.qty - LOT.qtyallocated)
      -- 	FROM LOT, LOTATTRIBUTE
      -- 	WHERE LOT.lot = LOTATTRIBUTE.lot
      -- 	  AND LOT.sku = @c_sku
      -- 	--  AND LOTATTRIBUTE.lottable03 = @c_whse
      --      AND LOTATTRIBUTE.lottable02 = @c_lottable02
      --      AND LOTATTRIBUTE.lottable04 = @d_lottable04

      INSERT #RESULT
      VALUES ('WD',@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,'WD',@c_sourcekey, @c_refno,@c_facility,@c_lottable02,
      @d_lottable04,@n_qtyopen,@n_qty,@d_trandate,@c_lottable02label,@c_lottable04label)

      FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty
   END
   CLOSE cur_2
   DEALLOCATE cur_2

   DELETE #RESULT WHERE qtyopen = 0 AND qty = 0

   --SELECT * FROM #RESULT

   SELECT trantype,
   storerkey,
   company,
   sku,
   descr,
   uom,
   doctype,
   sourcekey,
   refno,
   facility,
   lottable02,
   lottable04,
   qtyopen,
   qty = sum(qty),
   trandate,
   --qtyclose,
   lottable02label,
   lottable04label
   FROM #RESULT
   GROUP BY trantype,
   storerkey,
   company,
   sku,
   descr,
   uom,
   doctype,
   sourcekey,
   refno,
   facility,
   lottable02,
   lottable04,
   qtyopen,
   trandate,
   --qtyclose,
   lottable02label,
   lottable04label
   ORDER BY facility, storerkey, sku, trandate, doctype

   DROP TABLE #RESULT

END	-- main procedure

-- GRANT  EXECUTE  ON dbo.nspStockTransactionRpt TO NSQL
-- GO

GO