SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspStockCard](
 @c_facility NVARCHAR(5),
 @c_storerstart NVARCHAR(15),
 @c_storerend NVARCHAR(15),
 @c_principalstart NVARCHAR(18),
 @c_principalend NVARCHAR(18),
 @c_skustart NVARCHAR(20),
 @c_skuend NVARCHAR(20),
 @d_datestart	datetime, 
 @d_dateend	datetime
-- SOS13301
-- @c_whse	 NVARCHAR(6) 
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
-- SOS13301
--	@c_itrnkey NVARCHAR(10),
 	@c_sourcetype NVARCHAR(30),
 	@c_sourcekey NVARCHAR(10),
 	@d_trandate NVARCHAR(10),
 	@n_qtyclose	int,
-- SOS13301
	@c_susr3 NVARCHAR(18), 
	@c_principal NVARCHAR(60),
 	@n_totqty	 int


 SELECT @d_date_start = CONVERT(datetime, @d_datestart)
 SELECT @d_date_end = DATEADD(day, 1, CONVERT(datetime, @d_dateend))

 /*Create Temp #RESULT table */
 SELECT Facility = space(5), 
	trantype = ITRN.trantype,
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
 	qtyclose = 0,
	susr3 = space(18),
	principal = space(60),
	sourcetype = space(30)
 INTO #RESULT 
 FROM ITRN (NOLOCK) 
 WHERE 1 = 2

 DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY 
 FOR
 SELECT -- ITRN.itrnkey, SOS13301
		ITRN.sku, ITRN.trantype, ITRN.sourcetype, SKU.SUSR3, CODELKUP.Description
 FROM ITRN (NOLOCK), 
	-- SOS13301
	-- LOTATTRIBUTE (NOLOCK)
	   LOC (NOLOCK), 
		SKU (NOLOCK),
		CODELKUP (NOLOCK)
 WHERE 
   -- SOS13301  
	-- ITRN.lot = LOTATTRIBUTE.lot   AND 
	ITRN.trantype <> 'MV'
   AND ITRN.storerkey >= @c_storerstart
   AND ITRN.storerkey <= @c_storerend
   AND ITRN.sku >= @c_skustart
   AND ITRN.sku <= @c_skuend
	-- SOS13301
	-- AND LOTATTRIBUTE.lottable03 = @c_whse
	AND ITRN.Storerkey = SKU.Storerkey
	AND ITRN.SKU = SKU.Sku
	AND SKU.SUSR3 BETWEEN @c_principalstart AND @c_principalend
	AND SKU.SUSR3 = CODELKUP.Code
	AND CODELKUP.Listname = 'PRINCIPAL'
	AND ITRN.ToLoc = LOC.Loc
	AND LOC.Facility = @c_facility
 -- GROUP BY sku, lottable03
 GROUP BY ITRN.sku, ITRN.trantype, ITRN.sourcetype, SKU.SUSR3, CODELKUP.Description
 ORDER BY ITRN.sku, ITRN.Trantype

 OPEN cur_1
 FETCH NEXT FROM cur_1 INTO -- @c_itrnkey, SOS13301
						@c_sku, @c_trantype, @c_sourcetype, @c_susr3, @c_principal
 WHILE (@@fetch_status <> -1)
 BEGIN
	-- SOS13301
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

 	-- beginning balance
 	SELECT @n_qtyopen = ISNULL(SUM(qty), 0)
 	FROM  ITRN (NOLOCK), 
		-- SOS13301		
		--	LOTATTRIBUTE (NOLOCK), 
			LOC (NOLOCK)
 	WHERE trantype IN ('DP','AJ','WD')
 	  AND ITRN.editdate < @d_date_start
 	  AND ITRN.sku = @c_sku
	 -- SOS13301
	 --  AND ITRN.lot = LOTATTRIBUTE.lot
	 --  AND LOTATTRIBUTE.lottable03 = @c_whse
	 AND ITRN.ToLoc = LOC.Loc
	 AND LOC.Facility = @c_facility


  -- SOS13301
/*
 	SELECT @c_sourcekey = LEFT(sourcekey,10), @d_trandate = CONVERT(char(10),editdate,101)
 	FROM ITRN (NOLOCK)
 	WHERE itrnkey = @c_itrnkey
*/

 	SELECT @n_qty = 0
 	-- deposit
 	IF @c_trantype = 'DP' AND @c_sourcetype <> ''
 	BEGIN
 		-- deposit by receipt
 		IF @c_trantype = 'DP' AND @c_sourcetype IN ('ntrReceiptDetailUpdate','ntrReceiptDetailAdd')
 		BEGIN
 		   INSERT #RESULT
 			SELECT LOC.Facility,
				ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
 				RECEIPT.rectype,
				RECEIPT.Receiptkey, 
 				RECEIPT.warehousereference, 
				ITRN.lottable02, 
 				ITRN.lottable04, 
				@n_qtyopen, 
 				SUM(ITRN.qty),
		 		CONVERT(char(10), MAX(ITRN.adddate),101),
				qtyclose = 0,
				@c_susr3, @c_principal,
				ITRN.Sourcetype
 			FROM ITRN (NOLOCK), RECEIPT (NOLOCK), 
				  RECEIPTDETAIL, LOC (NOLOCK)  -- SOS13301
 			WHERE -- ITRN.itrnkey = @c_itrnkey   SOS13301
 			  -- AND RECEIPT.receiptkey = @c_sourcekey SOS13301
 			  ITRN.editdate >= @d_date_start
			  -- SOS13301
			  AND ITRN.editdate < @d_date_end
			  AND LEFT(dbo.fnc_RTrim(ITRN.Sourcekey), 10) = RECEIPT.Receiptkey
			  AND RIGHT(dbo.fnc_RTrim(ITRN.Sourcekey), 5) = RECEIPTDETAIL.ReceiptLineNumber
			  AND RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
			  AND ITRN.ToLoc = LOC.Loc
			  AND ITRN.Storerkey = @c_storerkey
			  AND ITRN.SKU = @c_SKU
			  AND LOC.Facility = @c_facility
			  AND ITRN.Trantype = @c_trantype
			  GROUP BY LOC.Facility, ITRN.Trantype, ITRN.lottable02, ITRN.lottable04, RECEIPT.warehousereference, RECEIPT.rectype, RECEIPT.Receiptkey, ITRN.Sourcetype
 		END
 		ELSE
 		BEGIN
 			-- deposit by transfer
	 		INSERT #RESULT
 			SELECT LOC.Facility,
				ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
 				'IWT',
				TRANSFER.Transferkey, 
 				TRANSFER.customerrefno,
				ITRN.lottable02, 
 				ITRN.lottable04, 
				@n_qtyopen, 
 				SUM(ITRN.qty),
		 		CONVERT(char(10), MAX(ITRN.adddate),101),
				qtyclose = 0,
				@c_susr3, @c_principal,
				ITRN.Sourcetype
 			FROM ITRN (NOLOCK), TRANSFER (NOLOCK),
				  LOC (NOLOCK), TRANSFERDETAIL -- SOS13301
 			WHERE -- ITRN.itrnkey = @c_itrnkey 	-- SOS13301
 			  -- AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey -- SOS13301
 			  ITRN.editdate >= @d_date_start	
 			  AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
			  -- SOS13301
			  AND ITRN.editdate < @d_date_end
	 		  AND ITRN.sourcekey = dbo.fnc_RTrim(TRANSFERDETAIL.transferkey) + dbo.fnc_RTrim(TRANSFERDETAIL.transferlinenumber)
			  AND TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey 
			  AND ITRN.ToLoc = LOC.Loc
			  AND ITRN.Storerkey = @c_storerkey
			  AND ITRN.SKU = @c_SKU
			  AND LOC.Facility = @c_facility			 
			  AND ITRN.Trantype = @c_trantype
			  GROUP BY LOC.Facility, ITRN.Trantype, ITRN.lottable02, ITRN.lottable04, TRANSFER.customerrefno, TRANSFER.Transferkey, ITRN.Sourcetype
 		END
 	END
 	ELSE
 	BEGIN
 		INSERT #RESULT
		SELECT LOC.Facility,
			ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
			RECEIPT.rectype,
			RECEIPT.Receiptkey, 
			RECEIPT.warehousereference, 
			ITRN.lottable02, 
			ITRN.lottable04, 
			@n_qtyopen, 
			SUM(ITRN.qty),
			CONVERT(char(10), MAX(ITRN.adddate),101),
			qtyclose = 0,
			@c_susr3, @c_principal,
			ITRN.Sourcetype
 		FROM ITRN (NOLOCK), RECEIPT (NOLOCK),
			  LOC (NOLOCK) -- SOS13301
 		WHERE -- ITRN.itrnkey = @c_itrnkey -- SOS13301
		  ITRN.editdate >= @d_date_start
 		  AND ITRN.trantype = 'DP'
		  -- SOS13301
		  AND ITRN.editdate < @d_date_end
		  AND LEFT(dbo.fnc_RTrim(ITRN.Sourcekey), 10) = RECEIPT.Receiptkey
		  AND ITRN.ToLoc = LOC.Loc
		  AND ITRN.Storerkey = @c_storerkey
		  AND ITRN.SKU = @c_SKU
		  AND LOC.Facility = @c_facility			 
		  AND ITRN.Trantype = @c_trantype
		  GROUP BY LOC.Facility, ITRN.Trantype, RECEIPT.rectype, ITRN.lottable02, ITRN.lottable04, ITRN.qty, RECEIPT.Receiptkey, RECEIPT.warehousereference, ITRN.Sourcetype
 	END
 	
 	-- withdrawal
 	IF @c_trantype = 'WD' AND @c_sourcetype = 'ntrPickDetailUpdate'
 	BEGIN
 		-- withdrawal by shipment order
 		INSERT #RESULT
 		SELECT LOC.Facility,
			ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
			ORDERS.type,
			ORDERS.Orderkey, 
			ORDERS.externorderkey, 
			ORDERDETAIL.lottable02, 
 			ORDERDETAIL.lottable04, 
			@n_qtyopen,
 			-- @n_qty = ABS(ITRN.qty),
 			-- SUM(ORDERDETAIL.originalqty + ORDERDETAIL.freegoodqty), SOS13301
			SUM(PICKDETAIL.Qty) * -1,
		 	CONVERT(char(10), MAX(ITRN.adddate) ,101),
			qtyclose = 0,
			@c_susr3, @c_principal,
			ITRN.Sourcetype
 		FROM ITRN (NOLOCK), ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK)
			  , LOC (NOLOCK) -- SOS13301
 		WHERE -- ITRN.itrnkey = @c_itrnkey  -- SOS13301
 		  ITRN.sourcekey = PICKDETAIL.pickdetailkey
 		  AND PICKDETAIL.orderkey = ORDERS.orderkey
 		  AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
 		  AND ORDERS.orderkey = ORDERDETAIL.orderkey
 		  AND ORDERDETAIL.sku = @c_sku
		  -- SOS13301
	 	  -- AND ORDERDETAIL.lottable03 = @c_whse
		  AND PICKDETAIL.Loc = LOC.Loc
		  AND ITRN.Storerkey = @c_storerkey
		  AND ORDERS.Facility = @c_facility
 		  AND ITRN.editdate >= @d_date_start
		  AND ITRN.editdate < @d_date_end
		  AND ITRN.Trantype = @c_trantype
		  GROUP BY LOC.Facility, ITRN.Trantype, ORDERS.type, ORDERS.Orderkey, ORDERDETAIL.lottable02, ORDERDETAIL.lottable04, ORDERS.invoiceno, ORDERS.externorderkey, ORDERS.type, ITRN.Sourcetype
 	END
 	ELSE
 	BEGIN
 		-- withdrawal by transfer
 		INSERT #RESULT
 		SELECT LOC.Facility,
			ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
			TRANSFER.Type,
			TRANSFER.Transferkey, 
			TRANSFER.customerrefno, 
			TRANSFERDETAIL.lottable02, 
 			TRANSFERDETAIL.lottable04, 
			@n_qtyopen,
			SUM(ITRN.qty) * -1,
		 	CONVERT(char(10), MAX(ITRN.adddate) ,101),
			qtyclose = 0,
			@c_susr3, @c_principal,
			ITRN.Sourcetype
 		FROM ITRN (NOLOCK), TRANSFER (NOLOCK), TRANSFERDETAIL (NOLOCK), 
			  LOC (NOLOCK) -- SOS13301
 		WHERE -- ITRN.itrnkey = @c_itrnkey -- SOS13301
 		  -- AND LEFT(ITRN.sourcekey,10) = TRANSFER.transferkey -- SOS13301
 		  TRANSFER.transferkey = TRANSFERDETAIL.transferkey
 		  AND ITRN.sourcekey = TRANSFERDETAIL.transferkey + TRANSFERDETAIL.transferlinenumber
 		  AND ITRN.editdate >= @d_date_start
 	  	  AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
		  -- SOS13301
		  AND ITRN.editdate < @d_date_start
		  AND ITRN.ToLoc = LOC.Loc
		  AND ITRN.Storerkey = @c_storerkey
		  AND ITRN.SKU = @c_SKU
		  AND LOC.Facility = @c_facility			 
		  AND ITRN.Trantype = @c_trantype
		  GROUP BY LOC.Facility, ITRN.Trantype, TRANSFER.Type,TRANSFER.Transferkey, TRANSFER.customerrefno, TRANSFERDETAIL.lottable02, TRANSFERDETAIL.lottable04, ITRN.Sourcetype
 	END
 		
 	-- adjustment transactions
 	IF @c_trantype = 'AJ'
 	BEGIN
		INSERT #RESULT
 		SELECT LOC.Facility,
			ITRN.Trantype, @c_storerkey, @c_company, @c_sku, @c_descr, @c_uom, 
			ADJUSTMENT.adjustmenttype,
			ADJUSTMENT.AdjustmentKey, 
			ADJUSTMENT.customerrefno, 
			LOTATTRIBUTE.lottable02, 
 			LOTATTRIBUTE.lottable04, 
			@n_qtyopen,
			ABS(SUM(ITRN.qty)),
		 	CONVERT(char(10), MAX(ITRN.adddate) ,101),
			qtyclose = 0,
			@c_susr3, @c_principal,
			ITRN.Sourcetype
 		FROM ITRN (NOLOCK), ADJUSTMENT (NOLOCK), ADJUSTMENTDETAIL (NOLOCK), LOTATTRIBUTE (NOLOCK), LOC (NOLOCK)
 		WHERE -- ITRN.itrnkey = @c_itrnkey - SOS13301
 		  -- AND ADJUSTMENT.adjustmentkey = @c_sourcekey - SOS13301
 		  ITRN.sourcekey = ADJUSTMENT.adjustmentkey + ADJUSTMENTDETAIL.adjustmentlinenumber
 		  AND ADJUSTMENTDETAIL.lot = LOTATTRIBUTE.lot
 		  AND ADJUSTMENTDETAIL.sku = @c_sku
		  -- SOS13301		
   	  -- AND LOTATTRIBUTE.lottable03 = @c_whse
		  AND ITRN.ToLoc = LOC.Loc
		  AND ITRN.Storerkey = @c_storerkey
		  AND ITRN.SKU = @c_SKU	
		  AND LOC.Facility = @c_Facility
 		  AND ITRN.editdate >= @d_date_start
		  AND ITRN.editdate < @d_date_end
		  AND ITRN.Trantype = @c_trantype
		  GROUP BY LOC.Facility, ITRN.Trantype, ADJUSTMENT.adjustmenttype,ADJUSTMENT.AdjustmentKey, ADJUSTMENT.customerrefno, LOTATTRIBUTE.lottable02, LOTATTRIBUTE.lottable04, ITRN.Sourcetype
 	END
 	
	/*
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
	*/

	-- Start - SOS13301
	/*
 	SELECT @n_qtyclose = SUM(LOT.qty - LOT.qtyallocated)
 	FROM LOT, LOTATTRIBUTE
 	WHERE LOT.lot = LOTATTRIBUTE.lot
 	  AND LOT.sku = @c_sku
 	  AND LOTATTRIBUTE.lottable03 = @c_whse

	IF @d_trandate IS NULL SELECT @d_trandate = ''
 	IF @c_sku NOT IN (SELECT sku FROM #RESULT) 		
 		INSERT #RESULT
 		VALUES (@c_facility, @c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
 			CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose, @c_susr3, @c_principal, '')
 	ELSE IF @n_qty <> 0
 		INSERT #RESULT
 		VALUES (@c_facility, @c_trantype,@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
 			CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose, @c_susr3, @c_principal, '')

	*/

	SELECT @n_qtyopen = MAX(QtyOpen),
			 @n_totqty = SUM(QTY)
	FROM   #RESULT
	WHERE  Storerkey = @c_storerkey
	AND    Sku = @c_sku

	UPDATE #RESULT SET QtyClose = @n_qtyopen + @n_totqty
	WHERE  Storerkey  = @c_storerkey
	AND    Sku = @c_sku
 	
 	FETCH NEXT FROM cur_1 INTO -- @c_itrnkey, - SOS13301
								 @c_sku, @c_trantype, @c_sourcetype, @c_susr3, @c_principal
 END
 CLOSE cur_1
 DEALLOCATE cur_1

-- SOS13301 Remark this, if this is IN, close qty <> open qty + movement
/*
 -- check for qtyallocated but not yet shipped
 DECLARE cur_2 CURSOR FAST_FORWARD READ_ONLY
 FOR
 SELECT orderkey, ORDERDETAIL.sku, qtyallocated = SUM(qtyallocated), SKU.SUSR3, CODELKUP.Description
 FROM ORDERDETAIL (NOLOCK), SKU (NOLOCK)
-- SOS13301
 , CODELKUP (NOLOCK)
 WHERE shippedqty = 0
   AND qtyallocated <> 0
-- SOS13301
--   AND lottable03 = @c_whse
	AND ORDERDETAIL.Facility = @c_facility
	AND ORDERDETAIL.Storerkey = SKU.Storerkey
	AND ORDERDETAIL.Sku = SKU.SKU
	AND SKU.SUSR3 BETWEEN @c_principalStart AND @c_principalEnd
	AND SKU.SUSR3 = CODELKUP.CODE
	AND CODELKUP.Listname = 'PRINCIPAL'
   AND ORDERDETAIL.storerkey >= @c_storerstart
   AND ORDERDETAIL. storerkey <= @c_storerend
   AND ORDERDETAIL.sku >= @c_skustart
   AND ORDERDETAIL.sku <= @c_skuend
	GROUP BY orderkey, ORDERDETAIL.sku, SKU.SUSR3, CODELKUP.Description

 DECLARE @c_orderkey NVARCHAR(10)
 OPEN cur_2
 FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty, @c_susr3, @c_principal
 WHILE (@@fetch_status <> -1)
 BEGIN
 	-- beginning balance
 	SELECT @n_qtyopen = SUM(qty)
 	FROM ITRN (NOLOCK), 
	-- SOS13301
	--	LOTATTRIBUTE (NOLOCK)
		LOC (NOLOCK)
 	WHERE trantype IN ('DP','AJ','WD')
 	  AND ITRN.editdate < @d_date_start
 	  AND ITRN.sku = @c_sku
	-- SOS13301
	--   AND ITRN.lot = LOTATTRIBUTE.lot
	--   AND LOTATTRIBUTE.lottable03 = @c_whse
	  AND ITRN.ToLoc = LOC.Loc
	  AND LOC.Facility = @c_facility

 	IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0

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

	IF @d_trandate IS NULL SELECT @d_trandate = ''
 	INSERT #RESULT
 	VALUES (@c_facility, 'WD',@c_storerkey,@c_company,@c_sku,@c_descr,@c_uom,@c_doctype,@c_docno,@c_refno,@c_mfglot,
 		CONVERT(char(8),@d_expiry),@n_qtyopen,@n_qty,@d_trandate,@n_qtyclose, @c_susr3, @c_principal, '')

 	FETCH NEXT FROM cur_2 INTO @c_orderkey, @c_sku, @n_qty, @c_susr3, @c_principal
 END
 CLOSE cur_2
 DEALLOCATE cur_2
*/

 DELETE #RESULT WHERE qtyopen = 0 AND qty = 0


 SELECT facility, 
	trantype,
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
 	qty = ABS(sum(qty)),
 	trandate,
 	qtyclose,
-- SOS13301
	@c_susr3, @c_principal
 FROM #RESULT
 GROUP BY facility, 
	trantype,
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
 	qtyclose
 ORDER BY sku, trandate

 DROP TABLE #RESULT
 END	-- main procedure

GO