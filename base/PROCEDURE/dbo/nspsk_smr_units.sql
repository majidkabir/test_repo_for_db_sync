SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspSK_SMR_units                                    */
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

/****** Object:  Stored Procedure dbo.nspSK_SMR_units    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspSK_SMR_units](
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
   @c_storerkey NVARCHAR(15),
   @c_contact NVARCHAR(30),
   @c_descr NVARCHAR(60),
   @c_uom	 NVARCHAR(10),
   @n_qty_rpo	int,
   @n_qty_rrb	int,
   @n_qty_iwt_in	int,
   @n_qty_iwt_out	int,
   @n_qty_inv	int,
   @n_qty_inv_free int,
   @n_qty_stp	int,
   @n_qty_swi	int,
   @n_qtyaj	int,
   @n_qty_ret	int,
   @n_qty_transfer	int,
   @n_qtyopen	int,
   @n_qtyclose	int,
   @c_logical NVARCHAR(6),
   @c_mfglot NVARCHAR(18),
   @d_expiry	datetime,
   @c_company NVARCHAR(60)
   SELECT @d_date_start = CONVERT(datetime, @d_datestart)
   SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))
   /*Create Temp Result table */
   SELECT ITRN.storerkey storerkey,
   company = space(60),
   ITRN.sku sku,
   descr = space(60),
   uom = space(2),
   qtyopen = ITRN.qty,
   qty_rpo = ITRN.qty,
   qty_rrb	= ITRN.qty,
   qty_adjusted = ITRN.qty,
   qty_ret = ITRN.qty,
   qty_transfer = ITRN.qty,
   qty_inv = ITRN.qty,
   qty_inv_free = ITRN.qty,
   qty_stp = ITRN.qty,
   qty_swi = ITRN.qty,
   qtyclose = ITRN.qty,
   logical = space(6)
   INTO #RESULT
   FROM ITRN (NOLOCK)
   WHERE 1 = 2
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT ITRN.sku, LOTATTRIBUTE.lottable03
   FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
   WHERE ITRN.lot = LOTATTRIBUTE.lot
   AND ITRN.trantype <> 'MV'
   AND ITRN.storerkey >= @c_storerstart
   AND ITRN.storerkey <= @c_storerend
   AND ITRN.sku >= @c_skustart
   AND ITRN.sku <= @c_skuend
   AND LOTATTRIBUTE.lottable03 = @c_whse
   GROUP BY ITRN.sku, LOTATTRIBUTE.lottable03
   ORDER BY ITRN.sku
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_sku, @c_mfglot
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- beginning balance
      SELECT @n_qtyopen = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_date_start
      AND ITRN.sku = @c_sku
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      -- deposit by RPO
      SELECT @n_qty_rpo = SUM(qty)
      FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.lottable03 = @c_whse
      AND RECEIPT.receiptkey = LEFT(ITRN.sourcekey,10)
      AND RECEIPT.rectype = 'RPO'
      AND ITRN.sourcetype IN ('ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd')
      -- deposit by RRB and IWT
      SELECT @n_qty_rrb = SUM(qty)
      FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.lottable03 = @c_whse
      AND RECEIPT.receiptkey = LEFT(ITRN.sourcekey,10)
      AND RECEIPT.rectype = 'RRB'
      IF ISNULL(@n_qty_rrb,0) = 0 SELECT @n_qty_rrb = 0
      SELECT @n_qty_iwt_in = ABS(SUM(qty))
      FROM ITRN (NOLOCK), TRANSMITLOG (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.trantype = 'DP'
      AND ITRN.sourcekey = TRANSMITLOG.key1 + TRANSMITLOG.key2
      AND TRANSMITLOG.transmitbatch = 'TRANSFER'
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
      IF NOT ISNULL(@n_qty_iwt_in,0) = 0 SELECT @n_qty_rrb = @n_qty_rrb + @n_qty_iwt_in
      -- withdrawal by TO and IWT
      SELECT @n_qty_transfer = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'TOS'
      AND ORDERDETAIL.lottable03 = @c_whse
      IF ISNULL(@n_qty_transfer,0) = 0 SELECT @n_qty_transfer = 0
      SELECT @n_qty_iwt_out = ABS(SUM(qty))
      FROM ITRN (NOLOCK), TRANSMITLOG (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.trantype = 'WD'
      AND ITRN.sourcekey = TRANSMITLOG.key1 + TRANSMITLOG.key2
      AND TRANSMITLOG.transmitbatch = 'TRANSFER'
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
      IF NOT ISNULL(@n_qty_iwt_out,0) = 0 SELECT @n_qty_transfer = @n_qty_transfer + @n_qty_iwt_out
      -- withdrawal by INV
      SELECT @n_qty_inv = SUM(PICKDETAIL.qty) - SUM(ORDERDETAIL.freegoodqty), @n_qty_inv_free = SUM(ORDERDETAIL.freegoodqty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'INV'
      AND ORDERDETAIL.lottable03 = @c_whse
      /*
      SELECT @n_qty_inv = SUM(ORDERDETAIL.originalqty), @n_qty_inv_free = SUM(ORDERDETAIL.freegoodqty)
      FROM ORDERDETAIL (NOLOCK), ORDERS(NOLOCK)
      WHERE ORDERS.type = 'INV'
      AND ORDERS.orderkey = ORDERDETAIL.orderkey
      AND ORDERDETAIL.sku = @c_sku
      AND ORDERDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
      AND ORDERDETAIL.lottable03 = @c_whse
      */
      -- withdrawal by STP
      SELECT @n_qty_stp = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'STP'
      AND ORDERDETAIL.lottable03 = @c_whse
      -- withdrawal by SWI
      SELECT @n_qty_swi = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'SWI'
      AND ORDERDETAIL.lottable03 = @c_whse
      -- adjusment
      SELECT @n_qtyaj = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.trantype = 'AJ'
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      -- deposit by RET
      SELECT @n_qty_ret = SUM(qty)
      FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.lottable03 = @c_whse
      AND RECEIPT.receiptkey = LEFT(ITRN.sourcekey,10)
      AND RECEIPT.rectype = 'RET'
      AND ITRN.sourcetype = 'ntrReceiptDetailUpdate'
      SELECT @c_storerkey = SKU.storerkey,
      @c_company = STORER.company,
      @c_descr = SKU.descr
      FROM SKU (NOLOCK), STORER (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.storerkey = STORER.storerkey
      SELECT @c_mfglot = lottable02,
      @d_expiry = lottable04
      FROM LOTATTRIBUTE (NOLOCK)
      SELECT @c_uom = packuom3
      FROM SKU (NOLOCK),PACK (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.packkey = PACK.packkey
      IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0
      IF @n_qty_rpo IS NULL SELECT @n_qty_rpo = 0
      IF @n_qty_rrb IS NULL SELECT @n_qty_rrb = 0
      IF @n_qty_transfer IS NULL SELECT @n_qty_transfer = 0
      IF @n_qty_inv IS NULL SELECT @n_qty_inv = 0
      IF @n_qty_inv_free IS NULL SELECT @n_qty_inv_free = 0
      IF @n_qty_stp IS NULL SELECT @n_qty_stp = 0
      IF @n_qty_swi IS NULL SELECT @n_qty_swi = 0
      IF @n_qtyaj IS NULL SELECT @n_qtyaj = 0
      IF @n_qty_ret IS NULL SELECT @n_qty_ret = 0

      SELECT @n_qtyclose = @n_qtyopen + @n_qty_rpo + @n_qty_rrb + @n_qty_ret
      - @n_qty_transfer - @n_qty_inv - @n_qty_inv_free - @n_qty_stp - @n_qty_swi + @n_qtyaj
      INSERT #RESULT
      VALUES (@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@n_qtyopen,@n_qty_rpo,@n_qty_rrb,@n_qtyaj,
      @n_qty_ret,@n_qty_transfer,@n_qty_inv,@n_qty_inv_free,@n_qty_stp,@n_qty_swi,@n_qtyclose,@c_whse)
      FETCH NEXT FROM cur_1 INTO @c_sku, @c_mfglot
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   -- DELETE #RESULT where qtyclose >= 0
   SELECT storerkey,
   company,
   sku,
   descr,
   uom,
   qtyopen,
   qty_rpo,
   qty_rrb,
   qty_adjusted,
   qty_ret,
   qty_transfer,
   qty_inv,
   qty_inv_free,
   qty_stp,
   qty_swi,
   qtyclose,
   logical
   FROM #RESULT
   ORDER BY sku
   DROP TABLE #RESULT
END	-- main procedure
-- GRANT  EXECUTE  ON dbo.nspSK_SMR_units TO NSQL
-- GO

GO