SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspStockAgingByExpiry                              */
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

CREATE PROC [dbo].[nspStockAgingByExpiry] (
@c_storerkey NVARCHAR(15),
@c_from_skugroup NVARCHAR(10),
@c_to_skugroup NVARCHAR(10),
@c_from_sku NVARCHAR(20),
@c_to_sku NVARCHAR(20)
)
AS
BEGIN -- main proc
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   

   DECLARE @c_company NVARCHAR(60),
   @c_skugroup NVARCHAR(10),
   @c_sku	 NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_uom	 NVARCHAR(10),
   @c_batchno NVARCHAR(18),
   @d_lottable04	datetime,
   @n_totalqty	int,
   @n_expiry	int,
   @d_editdate datetime
   -- Modify By Vicky 20 Feb 2002 SOS 3455
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
   Lasteditdate datetime NULL DEFAULT (GetDate())
   )
   -- END SOS 3455
   -- create a temporary result table
   -- 	SELECT l.storerkey,
   -- 		company = space(60),
   -- 		skugroup = space(10),
   -- 		l.sku,
   -- 		descr = space(60),
   -- 		uom = space(10),
   -- 		batchno = space(18),
   -- 		lottable04,
   -- 		totalqty = 0,
   -- 		expiredqty = 0,
   -- 		moretwelve = 0,
   -- 		morenine = 0,
   -- 		moresix = 0,
   -- 		fivemonths = 0,
   -- 		fourmonths = 0,
   -- 		threemonths = 0,
   -- 		twomonths = 0,
   -- 		lesstwo = 0,
   --       lasteditdate =  (GetDate())
   --    INTO #RESULT
   -- 	FROM LOTATTRIBUTE l (NOLOCK)
   -- 	WHERE 1 = 2
   DECLARE cur_1 SCROLL CURSOR FOR
   SELECT LOTATTRIBUTE.lottable02, LOTxLOCxID.sku, LOTATTRIBUTE.lottable04, totalqty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked),
   expiry = DATEDIFF(DAY, GETDATE(), LOTATTRIBUTE.lottable04), SKU.skugroup --,  MAX(PICKDETAIL.EditDate)
   FROM LOTxLOCxID (NOLOCK)
   INNER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.lot = LOTATTRIBUTE.lot)
   INNER JOIN SKU (NOLOCK) ON (LOTxLOCxID.storerkey = SKU.StorerKey AND LOTxLOCxID.sku = SKU.sku)
   --       LEFT OUTER JOIN PICKDETAIL (NOLOCK) ON  ((LOTxLOCxID.Lot = PICKDETAIL.Lot )
   --                                           AND (PickDetail.Status = '5' OR PickDetail.Status = '9'))
   WHERE LOTxLOCxID.sku BETWEEN @c_from_sku AND @c_to_sku
   AND SKU.skugroup BETWEEN @c_from_skugroup AND @c_to_skugroup
   AND LOTxLOCxID.storerkey = @c_storerkey
   AND LOTATTRIBUTE.lottable04 IS NOT NULL
   AND LOTxLOCxID.loc <> 'DAMAGE'
   GROUP BY LOTATTRIBUTE.lottable02, LOTxLOCxID.sku, LOTATTRIBUTE.lottable04, DATEDIFF(DAY, GETDATE(), LOTATTRIBUTE.lottable04), SKU.skugroup
   HAVING SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) <> 0
   OPEN cur_1
   FETCH FIRST FROM cur_1 INTO @c_batchno, @c_sku, @d_lottable04, @n_totalqty, @n_expiry, @c_skugroup--, @d_editdate
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- fetch additional data
      SELECT @c_descr = SKU.descr, @c_uom = PACK.packuom3, @c_company = STORER.company
      FROM SKU (NOLOCK) INNER JOIN PACK (NOLOCK)
      ON SKU.packkey = PACK.packkey
      INNER JOIN STORER (NOLOCK)
      ON SKU.storerkey = STORER.storerkey
      WHERE SKU.sku = @c_sku
      -- Added By Vicky 20 Feb 2002 SOS 3455
      SELECT @d_editdate = MAX(pickdetail.editdate)
      FROM Pickdetail (NOLOCK)
      WHERE sku = @c_sku
      AND storerkey = @c_storerkey
      AND status >= '5'
      -- END SOS 3455
      -- choose the column for the month to expiry date
      -- expired items
      IF @n_expiry <= 0
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, 0, @d_editdate)

      -- expiring in 12 months or more
      IF @n_expiry >= 365
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, @n_totalqty, 0, 0, 0, 0, 0, 0, 0,@d_editdate)
      -- expiring in 9 months or more but less than 12 months
      IF @n_expiry >= 270 AND @n_expiry < 365
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, @n_totalqty, 0, 0, 0, 0, 0, 0,@d_editdate)
      -- expiring in 6 months or more but less than 9 months
      IF @n_expiry >= 180 AND @n_expiry < 270
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, @n_totalqty, 0, 0, 0, 0, 0,@d_editdate)
      -- expiring in 5 months
      IF @n_expiry >= 150 and @n_expiry < 180
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, 0, @n_totalqty, 0, 0, 0, 0,@d_editdate)
      -- expiring in 4 months
      IF @n_expiry >= 120 AND @n_expiry < 150
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, @n_totalqty, 0, 0, 0,@d_editdate)
      -- expiring in 3 months
      IF @n_expiry >= 90 AND @n_expiry < 120
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, @n_totalqty, 0, 0,@d_editdate)
      -- expiring in 2 months
      IF @n_expiry >= 60 AND @n_expiry < 90
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, @n_totalqty, 0,@d_editdate)

      -- expiring in less than 2 months
      IF @n_expiry < 60 AND @n_expiry > 0
      INSERT #RESULT VALUES(@c_storerkey, @c_company, @c_skugroup, @c_sku, @c_descr, @c_uom, @c_batchno,
      @d_lottable04, @n_totalqty, 0, 0, 0, 0, 0, 0, 0, 0, @n_totalqty,@d_editdate)

      FETCH NEXT FROM cur_1 INTO @c_batchno, @c_sku, @d_lottable04, @n_totalqty, @n_expiry, @c_skugroup--, @d_editdate
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   SELECT * FROM #RESULT
   DROP TABLE #RESULT
END -- main proc

GO