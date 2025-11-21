SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspSMR_cost                                        */
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

/****** Object:  Stored Procedure dbo.nspSMR_cost    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspSMR_cost](
@c_storerstart NVARCHAR(15),
@c_storerend NVARCHAR(15),
@c_skustart NVARCHAR(20),
@c_skuend NVARCHAR(20),
@d_datestart NVARCHAR(8),
@d_dateend NVARCHAR(8),
@c_whse	 NVARCHAR(6)
)
AS
BEGIN	-- main procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_lot NVARCHAR(10),
   @c_sku NVARCHAR(20),
   @c_uom NVARCHAR(10),
   @c_storerkey NVARCHAR(18),
   @c_lottable03 NVARCHAR(18),
   @d_date_start	datetime,
   @d_date_end	datetime,
   @n_begbal	money,
   @n_alloc	money,
   @n_rpo	money,
   @n_rrb	money,
   @n_adj	money,
   @n_iwt	money,
   @n_stp	money,
   @n_to		money,
   @n_swi	money,
   @n_returns	money,
   @n_inv	money,
   @n_invfree	money,
   @n_endbal	money,
   @n_upload	money,
   @c_company NVARCHAR(60),
   @c_descr NVARCHAR(60),
   @n_cost	money
   -- create temp result table
   SELECT storerkey = space(18),
   company = space(60),
   sku = space(20),
   uom = space(10),
   descr = space(60),
   whse = space(18),
   cost_open = CONVERT(money, 0),
   cost_rpo = CONVERT(money, 0),
   cost_ret = CONVERT(money, 0),
   cost_rrb = CONVERT(money, 0),
   cost_adjusted = CONVERT(money, 0),
   cost_inv = CONVERT(money, 0),
   cost_inv_free = CONVERT(money, 0),
   cost_stp = CONVERT(money, 0),
   cost_transfer = CONVERT(money, 0),
   cost_swi = CONVERT(money, 0),
   cost_close = CONVERT(money, 0)
   INTO #RESULT
   FROM LOT
   WHERE 1 = 2

   SELECT @d_date_start = CONVERT(datetime, @d_datestart)
   SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT LOT.lot, LOT.storerkey, LOT.sku, LOTATTRIBUTE.lottable03
   FROM LOT (NOLOCK) INNER JOIN LOTATTRIBUTE (NOLOCK)
   ON LOT.lot = LOTATTRIBUTE.lot
   AND LOT.storerkey BETWEEN @c_storerstart AND @c_storerend
   AND LOT.sku BETWEEN @c_skustart AND @c_skuend
   AND LOTATTRIBUTE.lottable03 = @c_whse
   ORDER BY LOT.lot
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_lot, @c_storerkey, @c_sku, @c_lottable03
   WHILE (@@fetch_status <> -1)
   BEGIN	-- cur_1
      -- get sku's cost
      SELECT @n_cost = cost FROM SKU (NOLOCK) WHERE sku = @c_sku
      -- beginning balance
      SELECT @n_begbal = COALESCE(SUM(qty), 0) * @n_cost
      FROM ITRN (NOLOCK)
      WHERE trantype in ('DP','WD','AJ')
      AND lot = @c_lot
      AND editdate < @d_date_start
      SELECT @n_alloc = COALESCE(SUM(qty), 0) * @n_cost
      FROM PICKDETAIL (NOLOCK)
      WHERE lot = @c_lot
      AND editdate < @d_date_start
      AND status <> '9'
      SELECT @n_begbal = @n_begbal - @n_alloc
      -- deposits thru EC
      SELECT @n_upload = COALESCE(SUM(qty), 0) * @n_cost
      FROM ITRN (NOLOCK)
      WHERE ITRN.lot = @c_lot
      AND ITRN.sourcekey = 'HostInterface'
      AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
      -- receipts (RPO)
      SELECT @n_rpo = (COALESCE(SUM(qty), 0) * @n_cost) + @n_upload
      FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
      ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
      AND ITRN.lot = @c_lot
      AND ITRN.trantype = 'DP'
      AND ITRN.sourcetype LIKE '%Receipt%'
      AND RECEIPT.rectype = 'RPO'
      AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
      -- receipts (RRB)
      SELECT @n_rrb = COALESCE(SUM(qty), 0) * @n_cost
      FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
      ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
      AND ITRN.lot = @c_lot
      AND ITRN.trantype = 'DP'
      AND ITRN.sourcetype LIKE '%Receipt%'
      AND RECEIPT.rectype = 'RRB'
      AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
      -- adjustments
      SELECT @n_adj = COALESCE(SUM(qty), 0) * @n_cost
      FROM ITRN (NOLOCK)
      WHERE lot = @c_lot
      AND trantype = 'AJ'
      AND editdate BETWEEN @d_date_start AND @d_date_end
      -- receipts (RET)
      SELECT @n_returns = COALESCE(SUM(qty), 0) * @n_cost
      FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
      ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
      AND ITRN.lot = @c_lot
      AND ITRN.trantype = 'DP'
      AND ITRN.sourcetype LIKE '%Receipt%'
      AND RECEIPT.rectype = 'RET'
      AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
      -- transfers (IWT)
      SELECT @n_iwt = ABS(COALESCE(SUM(qty), 0)) * @n_cost
      FROM ITRN (NOLOCK)
      WHERE lot = @c_lot
      AND sourcetype LIKE '%Transfer%'
      AND editdate BETWEEN @d_date_start AND @d_date_end
      -- withdrawal (INV)
      SELECT @n_inv = COALESCE(SUM(qty) - SUM(freegoodqty), 0) * @n_cost, @n_invfree = COALESCE(SUM(freegoodqty), 0) * @n_cost
      FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERS.orderkey
      INNER JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.lot = @c_lot
      AND ORDERS.type = 'INV'
      AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
      -- withdrawal (STP)
      SELECT @n_stp = COALESCE(SUM(qty), 0) * @n_cost
      FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERS.orderkey
      AND PICKDETAIL.lot = @c_lot
      AND ORDERS.type = 'STP'
      AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
      -- withdrawal (TOS)
      SELECT @n_to = COALESCE(SUM(qty), 0) * @n_cost
      FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERS.orderkey
      AND PICKDETAIL.lot = @c_lot
      AND ORDERS.type = 'TOS'
      AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
      -- withdrawal (SWI)
      SELECT @n_swi = COALESCE(SUM(qty), 0) * @n_cost
      FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERS.orderkey
      AND PICKDETAIL.lot = @c_lot
      AND ORDERS.type = 'SWI'
      AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
      -- current balance
      SELECT @n_endbal = @n_begbal + @n_rpo + @n_rrb + @n_returns - @n_iwt - @n_inv - @n_invfree - @n_stp - @n_to - @n_swi
      + @n_adj
      -- get addtl data for storerkey, sku and uom
      SELECT @c_company = company FROM STORER WHERE storerkey = @c_storerkey
      SELECT @c_descr = descr FROM SKU WHERE sku = @c_sku
      SELECT @c_uom = packuom3
      FROM SKU (NOLOCK),PACK (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.packkey = PACK.packkey
      -- populate result table
      INSERT INTO #RESULT VALUES(@c_storerkey, @c_company, @c_sku, @c_uom, @c_descr, @c_lottable03, @n_begbal, @n_rpo,
      @n_returns, @n_rrb, @n_adj, @n_inv, @n_invfree, @n_stp, @n_to, @n_swi, @n_endbal)
      FETCH NEXT FROM cur_1 INTO @c_lot, @c_storerkey, @c_sku, @c_lottable03
   END	-- cur_1
   CLOSE cur_1
   DEALLOCATE cur_1
END	-- main procedure
SELECT storerkey,
company,
sku,
descr,
uom,
whse,
cost_open = SUM(cost_open),
cost_rpo = SUM(cost_rpo),
cost_ret = SUM(cost_ret),
cost_rrb = SUM(cost_rrb),
cost_adjusted = SUM(cost_adjusted),
cost_inv = SUM(cost_inv),
cost_inv_free = SUM(cost_inv_free),
cost_stp = SUM(cost_stp),
cost_transfer = SUM(cost_transfer),
cost_swi = SUM(cost_swi),
cost_close = SUM(cost_close)
FROM #RESULT (NOLOCK)
GROUP BY storerkey, company, sku, descr, uom, whse
DROP TABLE #RESULT

GO