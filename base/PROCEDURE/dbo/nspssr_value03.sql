SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****** Object:  Stored Procedure dbo.nspSSR_value    Script Date: 3/11/99 6:24:26 PM ******/
 CREATE PROC [dbo].[nspSSR_value03](
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
 	  @c_group NVARCHAR(10),
 	  @c_storerkey NVARCHAR(18),
 	  @c_lottable03 NVARCHAR(18),
 	  @d_date_start	datetime,
 	  @d_date_end	datetime,
 	  @n_begbal	int,
 	  @n_alloc	int,
 	  @n_rpo	int,
 	  @n_rrb	int,
 	  @n_adj	int,
 	  @n_iwt	int,
 	  @n_stp	int,
 	  @n_to		int,
 	  @n_swi	int,
 	  @n_returns	int,
 	  @n_inv	int,
 	  @n_invfree	int,
 	  @n_endbal	int,
 	  @n_upload	int,
 	  @c_company NVARCHAR(60),
 	  @c_descr NVARCHAR(60),
 	  @m_price	money,
 	  @m_cost	money,
 	  @m_totprice	money,
 	  @m_totcost	money
   -- create temp result table
   SELECT storerkey = space(18),
 	 company = space(60),
 	 sku = space(20),
 	 packuom3 = space(10),
 	 descr = space(60),
 	 skugroup = space(10),
 	 qty = 0,
 	 price = CONVERT(money, 0),
 	 total_price = CONVERT(money, 0),
 	 total_cost = CONVERT(money, 0),
 	 whse = space(18)
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
     -- beginning balance
     SELECT @n_begbal = COALESCE(SUM(qty), 0)
     FROM ITRN (NOLOCK)
     WHERE trantype in ('DP','WD','AJ')
       AND lot = @c_lot
       AND editdate < @d_date_start
     SELECT @n_alloc = COALESCE(SUM(qty), 0)
     FROM PICKDETAIL (NOLOCK)
     WHERE lot = @c_lot
       AND editdate < @d_date_start
       AND status <> '9'
     SELECT @n_begbal = @n_begbal - @n_alloc
     -- deposits thru EC
     SELECT @n_upload = COALESCE(SUM(qty), 0)
     FROM ITRN (NOLOCK)
     WHERE ITRN.lot = @c_lot
       AND ITRN.sourcekey = 'HostInterface'
       AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
     -- receipts (RPO)
     SELECT @n_rpo = COALESCE(SUM(qty), 0) + @n_upload
     FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
     ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
       AND ITRN.lot = @c_lot
       AND ITRN.trantype = 'DP'
       AND ITRN.sourcetype LIKE '%Receipt%'
       AND RECEIPT.rectype = 'RPO'
       AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
     -- receipts (RRB)	
     SELECT @n_rrb = COALESCE(SUM(qty), 0)
     FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
     ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
       AND ITRN.lot = @c_lot
       AND ITRN.trantype = 'DP'
       AND ITRN.sourcetype LIKE '%Receipt%'
       AND RECEIPT.rectype = 'RRB'
       AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end    
     -- adjustments
     SELECT @n_adj = COALESCE(SUM(qty), 0)
     FROM ITRN (NOLOCK)
     WHERE lot = @c_lot
       AND trantype = 'AJ'
       AND editdate BETWEEN @d_date_start AND @d_date_end
     -- receipts (RET)
     SELECT @n_returns = COALESCE(SUM(qty), 0)
     FROM ITRN (NOLOCK) INNER JOIN RECEIPT (NOLOCK)
     ON LEFT(ITRN.sourcekey, 10) = RECEIPT.receiptkey
       AND ITRN.lot = @c_lot
       AND ITRN.trantype = 'DP'
       AND ITRN.sourcetype LIKE '%Receipt%'
       AND RECEIPT.rectype = 'RET'
       AND ITRN.editdate BETWEEN @d_date_start AND @d_date_end
     -- transfers (IWT)    
     SELECT @n_iwt = ABS(COALESCE(SUM(qty), 0))
     FROM ITRN (NOLOCK)
     WHERE lot = @c_lot
       AND sourcetype LIKE '%Transfer%'
       AND editdate BETWEEN @d_date_start AND @d_date_end
     -- withdrawal (INV)
     SELECT @n_inv = COALESCE(SUM(qty) - SUM(freegoodqty), 0), @n_invfree = COALESCE(SUM(freegoodqty), 0)
     FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
     ON PICKDETAIL.orderkey = ORDERS.orderkey
     INNER JOIN ORDERDETAIL (NOLOCK)
     ON PICKDETAIL.orderkey + PICKDETAIL.orderlinenumber = ORDERDETAIL.orderkey + ORDERDETAIL.orderlinenumber
       AND PICKDETAIL.lot = @c_lot
       AND ORDERS.type = 'INV'
       AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
     -- withdrawal (STP)
     SELECT @n_stp = COALESCE(SUM(qty), 0)
     FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
     ON PICKDETAIL.orderkey = ORDERS.orderkey
       AND PICKDETAIL.lot = @c_lot
       AND ORDERS.type = 'STP'
       AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
     -- withdrawal (TOS)
     SELECT @n_to = COALESCE(SUM(qty), 0)
     FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
     ON PICKDETAIL.orderkey = ORDERS.orderkey
       AND PICKDETAIL.lot = @c_lot
       AND ORDERS.type = 'TOS'
       AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
     -- withdrawal (SWI)
     SELECT @n_swi = COALESCE(SUM(qty), 0)
     FROM PICKDETAIL (NOLOCK) INNER JOIN ORDERS (NOLOCK)
     ON PICKDETAIL.orderkey = ORDERS.orderkey
       AND PICKDETAIL.lot = @c_lot
       AND ORDERS.type = 'SWI'
       AND PICKDETAIL.editdate BETWEEN @d_date_start AND @d_date_end
     -- get addtl data for storerkey, sku and uom
     SELECT @c_company = company FROM STORER WHERE storerkey = @c_storerkey
     SELECT @c_descr = descr, @m_price = price, @m_cost = cost, @c_group = skugroup FROM SKU WHERE sku = @c_sku
     SELECT @c_uom = packuom3
     FROM SKU (NOLOCK),PACK (NOLOCK) 
     WHERE SKU.sku = @c_sku
       AND SKU.packkey = PACK.packkey
     -- current balance
     SELECT @n_endbal = @n_begbal + @n_rpo + @n_rrb + @n_returns - @n_iwt - @n_inv - @n_invfree - @n_stp - @n_to - @n_swi
 				+ @n_adj
     SELECT @m_totprice = @n_endbal * @m_price
     SELECT @m_totcost = @n_endbal * @m_cost
     -- populate result table
     INSERT INTO #RESULT VALUES(@c_storerkey, @c_company, @c_sku, @c_uom, @c_descr, @c_group, @n_endbal, @m_price,
 	@m_totprice, @m_totcost, @c_lottable03)
     FETCH NEXT FROM cur_1 INTO @c_lot, @c_storerkey, @c_sku, @c_lottable03
   END	-- cur_1
   CLOSE cur_1
   DEALLOCATE cur_1
 END	-- main procedure
 SELECT storerkey,
 	company,
 	sku,
 	descr,
 	packuom3,
 	skugroup,
 	qty = SUM(qty),
 	price = SUM(price),
 	total_price = SUM(total_price),
 	total_cost = SUM(total_cost),
 	whse
 FROM #RESULT (NOLOCK)
 GROUP BY storerkey, company, sku, descr, packuom3, skugroup, whse
 DROP TABLE #RESULT

GO