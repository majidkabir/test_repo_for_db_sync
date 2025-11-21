SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspStockAgingByExpiry_Gillete_uom] (
	@c_storerkey NVARCHAR(15),
	@c_from_skugroup NVARCHAR(10),
	@c_to_skugroup NVARCHAR(10),   
	@c_from_sku NVARCHAR(20),
	@c_to_sku NVARCHAR(20),
	@c_packuom NVARCHAR(10)
)

/* 
** Added by YokeBeen on 25-Jun-2002 (Ticket # 6073)  
** New Report INV25C - Parameter, UOM on selection of Eaches/Cases for report generation 
** System to capture only first character of UOM parameter, 'E' or 'C'. 
*/ 

AS
BEGIN -- main proc
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	
	DECLARE @c_company NVARCHAR(60),
		@c_skugroup		 NVARCHAR(10),
		@c_sku			 NVARCHAR(20),
		@c_descr			 NVARCHAR(60),
		@c_uom			 NVARCHAR(10),
		@c_batchno		 NVARCHAR(18),
		@d_lottable04		datetime,
		@n_totalqty			int,
		@n_expiry			int,
      @d_editdate 		datetime,
		@c_uom_descr	 NVARCHAR(50)
  

     CREATE TABLE #Result (
      StorerKey NVARCHAR(15),
      Company NVARCHAR(60),
      Skugroup NVARCHAR(10),
      Sku NVARCHAR(20),
      Descr NVARCHAR(60),
      UOM NVARCHAR(10),
      Batchno NVARCHAR(18),
      Lottable04 datetime,
      Totalqty int NOT NULL DEFAULT (0) ,
      Expiredqty int NOT NULL DEFAULT (0),
		Moretwelve int NOT NULL DEFAULT (0),
		Morenine int NOT NULL DEFAULT (0),
		Moresix int NOT NULL DEFAULT (0),
		Fivemonths int NOT NULL DEFAULT (0),
		Fourmonths int NOT NULL DEFAULT (0),
		Threemonths int NOT NULL DEFAULT (0),
		Twomonths int NOT NULL DEFAULT (0),
		Lesstwo int NOT NULL DEFAULT (0),  
      Lasteditdate datetime NULL DEFAULT (GetDate()),
		UOMDescr NVARCHAR(50) NULL 
      )


	DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY FOR
	SELECT	LOTATTRIBUTE.lottable02, 
				LOTxLOCxID.sku, 
				LOTATTRIBUTE.lottable04, 
				totalqty = CASE SubString(dbo.fnc_LTrim(UPPER(@c_packuom)), 1, 1) 
							  WHEN 'E' THEN  SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) 
							  WHEN 'C' THEN (SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) / PACK.CaseCnt) 
							  END,
				expiry = DATEDIFF(DAY, GETDATE(), LOTATTRIBUTE.lottable04), 
				SKU.skugroup,
				UOMDescr = CASE SubString(dbo.fnc_LTrim(UPPER(@c_packuom)), 1, 1) 
							  WHEN 'E' THEN '*** Quantities Expressed in Smallest Unit ***' 
							  WHEN 'C' THEN '*** Quantities Expressed in Case/Carton ***' 
							  END 
	FROM LOTxLOCxID (NOLOCK)
   INNER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.lot = LOTATTRIBUTE.lot)
	INNER JOIN SKU (NOLOCK) ON (LOTxLOCxID.storerkey = SKU.StorerKey AND LOTxLOCxID.sku = SKU.sku)
	INNER JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
	WHERE LOTxLOCxID.sku BETWEEN @c_from_sku AND @c_to_sku
	  AND SKU.skugroup BETWEEN @c_from_skugroup AND @c_to_skugroup
	  AND LOTxLOCxID.storerkey = @c_storerkey
	  AND LOTATTRIBUTE.lottable04 IS NOT NULL
	  AND LOTxLOCxID.loc <> 'DAMAGE'
	GROUP BY LOTATTRIBUTE.lottable02, 
				LOTxLOCxID.sku, 
				LOTATTRIBUTE.lottable04, 
				DATEDIFF(DAY, GETDATE(), LOTATTRIBUTE.lottable04), 
				SKU.skugroup, 
				PACK.CaseCnt 
	HAVING  SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) <> 0
		 OR (SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) / PACK.CaseCnt) <> 0

	OPEN cur_1
	FETCH NEXT FROM cur_1 INTO @c_batchno, @c_sku, @d_lottable04, @n_totalqty, @n_expiry, @c_skugroup, @c_uom_descr
	WHILE (@@fetch_status <> -1)
	BEGIN
		-- fetch additional data
		SELECT 	@c_descr = SKU.descr, 
					@c_uom = PACK.packuom3,
					@c_company = STORER.company
		FROM SKU (NOLOCK) INNER JOIN PACK (NOLOCK)
		ON SKU.packkey = PACK.packkey
		INNER JOIN STORER (NOLOCK)
		ON SKU.storerkey = STORER.storerkey
		WHERE SKU.sku = @c_sku

      SELECT @d_editdate = MAX(editdate)
      FROM PICKDETAIL (NOLOCK)
      WHERE Storerkey = @c_storerkey
      AND   Sku = @c_sku
      AND   Status >= '5' 

		-- choose the column for the month to expiry date
		-- expired items	
		IF @n_expiry <= 0
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, 0, @d_editdate, @c_uom_descr)
		
		-- expiring in 36 months
		IF @n_expiry >= 1080
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, @n_totalqty, 0, 0, 0, 0, 0, 0, 0,@d_editdate, @c_uom_descr)

		-- expiring in 30 months
		IF @n_expiry >= 900 AND @n_expiry < 1080
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, @n_totalqty, 0, 0, 0, 0, 0, 0, @d_editdate, @c_uom_descr)

		-- expiring in 24 months
		IF @n_expiry >= 720 AND @n_expiry < 900
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, @n_totalqty, 0, 0, 0, 0, 0, @d_editdate, @c_uom_descr)

		-- expiring in 12 months
		IF @n_expiry >= 360 and @n_expiry < 720
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, 0, @n_totalqty, 0, 0, 0, 0, @d_editdate, @c_uom_descr)

		-- expiring in 9 months
		IF @n_expiry >= 270 AND @n_expiry < 360
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, @n_totalqty, 0, 0, 0, @d_editdate, @c_uom_descr)

		-- expiring in 6 months
		IF @n_expiry >= 180 AND @n_expiry < 270
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, @n_totalqty, 0, 0, @d_editdate, @c_uom_descr)

		-- expiring in 3 months
		IF @n_expiry >= 90 AND @n_expiry < 180
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, @n_totalqty, 0, @d_editdate, @c_uom_descr)
		
		-- expiring in less than 3 months
		IF @n_expiry < 90 AND @n_expiry > 0
			INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno, 
				@d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, 0, @n_totalqty, @d_editdate, @c_uom_descr)
				
		FETCH NEXT FROM cur_1 INTO @c_batchno, @c_sku, @d_lottable04, @n_totalqty, @n_expiry, @c_skugroup, @c_uom_descr	
	END
	CLOSE cur_1
	DEALLOCATE cur_1

	SELECT * FROM #RESULT
	DROP TABLE #RESULT
END -- main proc


GO