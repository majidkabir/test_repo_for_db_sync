SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspVarianceReport                                  */
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

CREATE PROCEDURE [dbo].[nspVarianceReport] (
@c_SKUMin      NVARCHAR(20),
@c_SKUMax      NVARCHAR(20),
@c_ClassMin    NVARCHAR(10),
@c_ClassMax    NVARCHAR(10),
@c_StorerMin   NVARCHAR(10),
@c_StorerMax   NVARCHAR(10),
@c_LocationMin NVARCHAR(10),
@c_LocationMax NVARCHAR(10),
@c_ZoneMin     NVARCHAR(10),
@c_ZoneMax     NVARCHAR(10),
@c_Facility    NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_storerkey NVARCHAR(18),
   @c_sku NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_packkey NVARCHAR(10),
   @n_countqty int,
   @n_qtyonhand int,
   @c_sheetno NVARCHAR(10),
   @c_loc NVARCHAR(10),
   @c_lottable01 NVARCHAR(18),		  --Start Add by DLIM for IDS FBR10 2001-Jun-12
   @c_lottable02 NVARCHAR(18),
   @c_lottable03 NVARCHAR(18),
   @c_lottable04 datetime,
   @c_lottable05 datetime,
   @c_lottable01Label NVARCHAR(20),
   @c_lottable02Label NVARCHAR(20),
   @c_lottable03Label NVARCHAR(20),
   @c_lottable04Label NVARCHAR(20),
   @c_lottable05Label NVARCHAR(20)	 --End Add by DLIM for IDS FBR10 2001-Jun-12
   SELECT CCDETAIL.StorerKey,
   CCDETAIL.Sku,
   CountQty = 0,
   QtyLOTxLOCxID = 0,
   DESCR,
   PackKey,
   CCSheetNo,
   Loc,
   Lottable01,  --Start Add by DLIM for IDS FBR10 2001-Jun-12
   Lottable02,
   Lottable03,
   Lottable04,
   Lottable05,
   Lottable01Label,
   Lottable02Label,
   Lottable03Label,
   Lottable04Label,
   Lottable05Label   --End Add by DLIM for IDS FBR10 2001-Jun-12
   INTO #RESULT
   FROM CCDETAIL, SKU
   WHERE 1 = 2

   DECLARE cur_1 SCROLL CURSOR FOR
   SELECT StorerKey=UPPER(CCDETAIL.StorerKey), Sku=UPPER(CCDETAIL.Sku), SKU.DESCR, SKU.PackKey, CountQty=SUM(CCDETAIL.Qty),
   '', CCDETAIL.Loc,
   CCDETAIL.Lottable01, CCDETAIL.Lottable02, CCDETAIL.Lottable03, CCDETAIL.Lottable04, CCDETAIL.Lottable05, --Add by DLIM for IDS FBR10 2001-Jun-12
   Lottable01Label, Lottable02Label, Lottable03Label, Lottable04Label, Lottable05Label  --Add by DLIM for IDS FBR10 2001-Jun-12
   FROM CCDETAIL, SKU, LOC
   WHERE CCDETAIL.SKU = SKU.SKU
   AND CCDETAIL.Loc = LOC.Loc
   AND CCDETAIL.StorerKey >= @c_StorerMin AND CCDETAIL.StorerKey <= @c_StorerMax
   AND CCDETAIL.Sku >= @c_SkuMin AND CCDETAIL.Sku <= @c_SkuMax
   AND SKU.ItemClass >= @c_ClassMin AND SKU.ItemClass <= @c_ClassMax
   AND CCDETAIL.Loc >= @c_LocationMin AND CCDETAIL.Loc <= @c_LocationMax
   AND LOC.PutawayZone >= @c_ZoneMin AND LOC.PutawayZone <= @c_ZoneMax
   AND ( (LOC.Facility = @c_Facility) OR (@c_Facility = '') )--CCLAW20001110
   GROUP BY CCDETAIL.StorerKey, CCDETAIL.Sku, SKU.DESCR, SKU.PackKey, CCDETAIL.Loc,
   CCDETAIL.Lottable01, CCDETAIL.Lottable02, CCDETAIL.Lottable03, CCDETAIL.Lottable04, CCDETAIL.Lottable05, --Add by DLIM for IDS FBR10 2001-Jun-12
   Lottable01Label, Lottable02Label, Lottable03Label, Lottable04Label, Lottable05Label  --Add by DLIM for IDS FBR10 2001-Jun-12
   UNION
   SELECT StorerKey=UPPER(LOTxLOCxID.StorerKey), Sku=UPPER(LOTxLOCxID.Sku), SKU.DESCR, SKU.PackKey, CountQty=0,
   '', LOTxLOCxID.Loc,
   a.Lottable01, a.Lottable02, a.Lottable03, a.Lottable04, a.Lottable05,  --Add by DLIM for IDS FBR10 2001-Jun-12
   Lottable01Label, Lottable02Label, Lottable03Label, Lottable04Label, Lottable05Label  --Add by DLIM for IDS FBR10 2001-Jun-12
   FROM LOTxLOCxID, SKU, LOC,
   LOTATTRIBUTE a  --Add by DLIM for IDS FBR10 2001-Jun-12
   WHERE LOTxLOCxID.SKU = SKU.SKU
   AND LOTxLOCxID.Lot = a.Lot
   AND LOTxLOCxID.Loc = LOC.Loc
   AND LOTxLOCxID.StorerKey >= @c_StorerMin AND LOTxLOCxID.StorerKey <= @c_StorerMax
   AND LOTxLOCxID.Sku >= @c_SkuMin AND LOTxLOCxID.Sku <= @c_SkuMax
   AND SKU.ItemClass >= @c_ClassMin AND SKU.ItemClass <= @c_ClassMax
   AND LOTxLOCxID.Loc >= @c_LocationMin AND LOTxLOCxID.Loc <= @c_LocationMax
   AND LOC.PutawayZone >= @c_ZoneMin AND LOC.PutawayZone <= @c_ZoneMax
   AND ( (LOC.Facility = @c_Facility) OR (@c_Facility = '') )--CCLAW20001110
   AND LOTxLOCxID.QTY > 0
   AND LOTxLOCxID.LOC NOT IN ( SELECT DISTINCT CCDETAIL.LOC FROM CCDETAIL CCDETAIL, SKU, LOC
   WHERE CCDETAIL.SKU = SKU.SKU
   AND CCDETAIL.Loc = LOC.Loc
   AND CCDETAIL.StorerKey >= @c_StorerMin AND CCDETAIL.StorerKey <= @c_StorerMax
   AND CCDETAIL.Sku >= @c_SkuMin AND CCDETAIL.Sku <= @c_SkuMax
   AND SKU.ItemClass >= @c_ClassMin AND SKU.ItemClass <= @c_ClassMax
   AND CCDETAIL.Loc >= @c_LocationMin AND CCDETAIL.Loc <= @c_LocationMax
   AND LOC.PutawayZone >= @c_ZoneMin AND LOC.PutawayZone <= @c_ZoneMax
   AND ( (LOC.Facility = @c_Facility) OR (@c_Facility = '') ) )--CCLAW20001110
   GROUP BY LOTxLOCxID.StorerKey, LOTxLOCxID.Sku, SKU.DESCR, SKU.PackKey, LOTxLOCxID.Loc,
   a.Lottable01, a.Lottable02, a.Lottable03, a.Lottable04, a.Lottable05, --Add by DLIM for IDS FBR10 2001-Jun-12
   Lottable01Label, Lottable02Label, Lottable03Label, Lottable04Label, Lottable05Label  --Add by DLIM for IDS FBR10 2001-Jun-12
   OPEN cur_1
   FETCH FIRST FROM cur_1 INTO @c_storerkey, @c_sku, @c_descr, @c_packkey, @n_countqty, @c_sheetno, @c_loc,
   @c_lottable01,  @c_lottable02,  @c_lottable03,  @c_lottable04,  @c_lottable05, --Add by DLIM for IDS FBR10 2001-Jun-12
   @c_lottable01Label,  @c_lottable02Label,  @c_lottable03Label,  @c_lottable04Label,  @c_lottable05Label --Add by DLIM for IDS FBR10 2001-Jun-12
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_qtyonhand = COALESCE(SUM(qty),0)
      FROM LOTxLOCxID
      WHERE storerkey = @c_storerkey
      AND sku = @c_sku
      AND loc = @c_loc
      INSERT #RESULT VALUES (@c_storerkey, @c_sku, @n_countqty, @n_qtyonhand, @c_descr, @c_packkey, @c_sheetno, @c_loc,
      @c_lottable01,  @c_lottable02,  @c_lottable03,  @c_lottable04,  @c_lottable05,  --Add by DLIM for IDS FBR10 2001-Jun-12
      @c_lottable01Label,  @c_lottable02Label,  @c_lottable03Label,  @c_lottable04Label,  @c_lottable05Label) --Add by DLIM for IDS FBR10 2001-Jun-12
      FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_descr, @c_packkey, @n_countqty, @c_sheetno, @c_loc,
      @c_lottable01,  @c_lottable02,  @c_lottable03,  @c_lottable04,  @c_lottable05, --Add by DLIM for IDS FBR10 2001-Jun-12
      @c_lottable01Label,  @c_lottable02Label,  @c_lottable03Label,  @c_lottable04Label,  @c_lottable05Label --Add by DLIM for IDS FBR10 2001-Jun-12
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   SELECT storerkey, sku
   INTO #temp
   FROM #RESULT
   GROUP BY storerkey, sku
   HAVING (sum(countqty) - sum(qtylotxlocxid)) = 0
   --SELECT * FROM #temp
   DELETE #RESULT WHERE storerkey + sku IN (SELECT storerkey + sku FROM #temp)
   --CCLAW20001110
   IF NOT EXISTS(SELECT 1 FROM #RESULT)
   BEGIN
      INSERT INTO #RESULT VALUES('','',0,0,'','','','',
      '','','','','','','','','','')   --Add by DLIM for IDS FBR10 2001-Jun-12
   END
   SELECT 	*,
   a_SKUMin = @c_SKUMin,
   a_SKUMax = @c_SKUMax,
   a_ClassMin = @c_ClassMin,
   a_ClassMax = @c_ClassMax,
   a_StorerMin = @c_StorerMin,
   a_StorerMax = @c_StorerMax,
   a_LocationMin = @c_LocationMin,
   a_LocationMax = @c_LocationMax,
   a_ZoneMin = @c_ZoneMin,
   a_ZoneMax = @c_ZoneMax,
   a_Facility = @c_Facility
   FROM 	#RESULT
   ORDER BY Sku
   DROP TABLE #temp
   DROP TABLE #RESULT
END

GO