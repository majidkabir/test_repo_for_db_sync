SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspSK_SMR_cost                                     */
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

/****** Object:  Stored Procedure dbo.nspSK_SMR_cost    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspSK_SMR_cost](
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

   DECLARE @d_date_start		datetime,
   @d_date_end		datetime,
   @c_sku		 NVARCHAR(20),
   @c_storerkey	 NVARCHAR(15),
   @c_company	 NVARCHAR(60),
   @c_descr	 NVARCHAR(60),
   @c_uom		 NVARCHAR(10),
   @c_mfglot	 NVARCHAR(18),
   @n_cost_rpo		money,
   @n_cost_rrb		money,
   @n_cost_iwt_in		money,
   @n_cost_iwt_out		money,
   @n_cost_inv		money,
   @n_cost_inv_free 	money,
   @n_cost_stp		money,
   @n_cost_swi		money,
   @n_costaj		money,
   @n_cost_ret		money,
   @n_cost_transfer	money,
   @n_costopen		money,
   @n_costclose		money,
   @n_cost			money
   SELECT @d_date_start = CONVERT(datetime, @d_datestart)
   SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))
   /*Create Temp Result table */
   SELECT ITRN.storerkey storerkey,
   company = space(60),
   ITRN.sku sku,
   descr = space(60),
   uom = space(2),
   qtyopen = CONVERT(money, ITRN.qty),
   qty_rpo = CONVERT(money, ITRN.qty),
   qty_rrb	= CONVERT(money, ITRN.qty),
   qty_adjusted = CONVERT(money, ITRN.qty),
   qty_ret = CONVERT(money, ITRN.qty),
   qty_transfer = CONVERT(money, ITRN.qty),
   qty_inv = CONVERT(money, ITRN.qty),
   qty_inv_free = CONVERT(money, ITRN.qty),
   qty_stp = CONVERT(money, ITRN.qty),
   qty_swi = CONVERT(money, ITRN.qty),
   qtyclose = CONVERT(money, ITRN.qty)
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
      SELECT @n_costopen = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE trantype IN ('DP','AJ','WD')
      AND ITRN.editdate < @d_date_start
      AND ITRN.sku = @c_sku
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      -- deposit by RPO
      SELECT @n_cost_rpo = SUM(qty)
      FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.lottable03 = @c_whse
      AND RECEIPT.receiptkey = LEFT(ITRN.sourcekey,10)
      AND RECEIPT.rectype = 'RPO'
      AND ITRN.sourcetype IN ('ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd')
      -- deposit by RRB and IWT
      SELECT @n_cost_rrb = SUM(qty)
      FROM ITRN (NOLOCK), RECEIPT (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.lottable03 = @c_whse
      AND RECEIPT.receiptkey = LEFT(ITRN.sourcekey,10)
      AND RECEIPT.rectype = 'RRB'
      IF ISNULL(@n_cost_rrb,0) = 0 SELECT @n_cost_rrb = 0
      SELECT @n_cost_iwt_in = ABS(SUM(qty))
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
      IF NOT ISNULL(@n_cost_iwt_in,0) = 0 SELECT @n_cost_rrb = @n_cost_rrb + @n_cost_iwt_in
      -- withdrawal by TO and IWT
      SELECT @n_cost_transfer = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'TOS'
      AND ORDERDETAIL.lottable03 = @c_whse
      IF ISNULL(@n_cost_transfer,0) = 0 SELECT @n_cost_transfer = 0
      SELECT @n_cost_iwt_out = ABS(SUM(qty))
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
      IF @n_cost_iwt_out IS NOT NULL SELECT @n_cost_transfer = @n_cost_transfer + @n_cost_iwt_out
      -- withdrawal by INV
      SELECT @n_cost_inv = SUM(PICKDETAIL.qty) - SUM(ORDERDETAIL.freegoodqty), @n_cost_inv_free = SUM(ORDERDETAIL.freegoodqty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'INV'
      AND ORDERDETAIL.lottable03 = @c_whse
      -- withdrawal by STP
      SELECT @n_cost_stp = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'STP'
      AND ORDERDETAIL.lottable03 = @c_whse
      -- withdrawal by SWI
      SELECT @n_cost_swi = SUM(PICKDETAIL.qty)
      FROM PICKDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK)
      WHERE PICKDETAIL.sku = @c_sku
      AND PICKDETAIL.editdate >= @d_date_start
      AND PICKDETAIL.editdate < @d_date_end
      AND PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.orderkey = ORDERS.orderkey
      AND ORDERS.type = 'SWI'
      AND ORDERDETAIL.lottable03 = @c_whse
      -- adjusment
      SELECT @n_costaj = SUM(qty)
      FROM ITRN (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE ITRN.sku = @c_sku
      AND ITRN.editdate >= @d_date_start
      AND ITRN.editdate < @d_date_end
      AND ITRN.trantype = 'AJ'
      AND ITRN.lot = LOTATTRIBUTE.lot
      AND LOTATTRIBUTE.lottable03 = @c_whse
      -- deposit by RET
      SELECT @n_cost_ret = SUM(qty)
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
      SELECT @c_uom = packuom3, @n_cost = cost
      FROM SKU (NOLOCK),PACK (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.packkey = PACK.packkey
      IF @n_costopen IS NULL SELECT @n_costopen = 0.0000
   ELSE SELECT @n_costopen = @n_costopen * @n_cost
      IF @n_cost_rpo IS NULL SELECT @n_cost_rpo = 0.0000
   ELSE SELECT @n_cost_rpo = @n_cost_rpo * @n_cost
      IF @n_cost_rrb IS NULL SELECT @n_cost_rrb = 0.0000
   ELSE SELECT @n_cost_rrb = @n_cost_rrb * @n_cost
      IF @n_cost_transfer IS NULL SELECT @n_cost_transfer = 0.0000
   ELSE SELECT @n_cost_transfer = @n_cost_transfer * @n_cost
      IF @n_cost_inv IS NULL SELECT @n_cost_inv = 0.0000
   ELSE SELECT @n_cost_inv = @n_cost_inv * @n_cost
      IF @n_cost_inv_free IS NULL SELECT @n_cost_inv_free = 0.0000
   ELSE SELECT @n_cost_inv_free = @n_cost_inv_free * @n_cost
      IF @n_cost_stp IS NULL SELECT @n_cost_stp = 0.0000
   ELSE SELECT @n_cost_stp = @n_cost_stp * @n_cost
      IF @n_cost_swi IS NULL SELECT @n_cost_swi = 0.0000
   ELSE SELECT @n_cost_swi = @n_cost_swi * @n_cost
      IF @n_costaj IS NULL SELECT @n_costaj = 0.0000
   ELSE SELECT @n_costaj = @n_costaj * @n_cost
      IF @n_cost_ret IS NULL SELECT @n_cost_ret = 0.0000
   ELSE SELECT @n_cost_ret = @n_cost_ret * @n_cost

      SELECT @n_costclose = @n_costopen + @n_cost_rpo + @n_cost_rrb + @n_cost_ret
      - @n_cost_transfer - @n_cost_inv - @n_cost_inv_free - @n_cost_stp - @n_cost_swi + @n_costaj
      SELECT @n_costclose = @n_costclose * @n_cost
      INSERT #RESULT
      VALUES (@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@n_costopen,@n_cost_rpo,@n_cost_rrb,@n_costaj,
      @n_cost_ret,@n_cost_transfer,@n_cost_inv,@n_cost_inv_free,@n_cost_stp,@n_cost_swi,@n_costclose)
      FETCH NEXT FROM cur_1 INTO @c_sku, @c_mfglot
   END
   CLOSE cur_1
   DEALLOCATE cur_1
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
   qtyclose
   FROM #RESULT
   ORDER BY sku
   DROP TABLE #RESULT
END	-- main procedure
--GRANT  EXECUTE  ON dbo.nspSK_SMR_cost TO NSQL
--GO

GO