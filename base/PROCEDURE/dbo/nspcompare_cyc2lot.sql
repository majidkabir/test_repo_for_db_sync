SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCompare_cyc2lot                                 */
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

CREATE PROCEDURE [dbo].[nspCompare_cyc2lot] (
@c_SKUMin      NVARCHAR(20),
@c_SKUMax      NVARCHAR(20),
@c_ClassMin    NVARCHAR(10),
@c_ClassMax    NVARCHAR(10),
@c_StorerMin   NVARCHAR(10),
@c_StorerMax   NVARCHAR(10),
@c_LocationMin NVARCHAR(10),
@c_LocationMax NVARCHAR(10),
@c_ZoneMin     NVARCHAR(10),
@c_ZoneMax     NVARCHAR(10)
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
   @n_qtyonhand int
   SELECT CCDETAIL.StorerKey,
   CCDETAIL.Sku,
   CountQty = 0,
   QtyLOTxLOCxID = 0,
   DESCR,
   PackKey
   INTO #RESULT
   FROM CCDETAIL (NOLOCK), SKU  (NOLOCK)
   WHERE 1 = 2

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT StorerKey=UPPER(CCDETAIL.StorerKey), Sku=UPPER(CCDETAIL.Sku), SKU.DESCR, SKU.PackKey, CountQty=SUM(CCDETAIL.Qty)
   FROM CCDETAIL (NOLOCK), SKU (NOLOCK), LOC (NOLOCK)
   WHERE CCDETAIL.SKU = SKU.SKU
   AND CCDETAIL.Storerkey = SKU.Storerkey
   AND CCDETAIL.Loc = LOC.Loc
   AND CCDETAIL.StorerKey >= @c_StorerMin AND CCDETAIL.StorerKey <= @c_StorerMax
   AND CCDETAIL.Sku >= @c_SkuMin AND CCDETAIL.Sku <= @c_SkuMax
   AND SKU.ItemClass >= @c_ClassMin AND SKU.ItemClass <= @c_ClassMax
   AND CCDETAIL.Loc >= @c_LocationMin AND CCDETAIL.Loc <= @c_LocationMax
   AND LOC.PutawayZone >= @c_ZoneMin AND LOC.PutawayZone <= @c_ZoneMax
   GROUP BY CCDETAIL.StorerKey, CCDETAIL.Sku, SKU.DESCR, SKU.PackKey
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_descr, @c_packkey, @n_countqty
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_qtyonhand = COALESCE(SUM(qty),0)
      FROM LOTxLOCxID  (NOLOCK)
      WHERE storerkey = @c_storerkey
      AND sku = @c_sku
      INSERT #RESULT VALUES (@c_storerkey, @c_sku, @n_countqty, @n_qtyonhand, @c_descr, @c_packkey)
      FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_descr, @c_packkey, @n_countqty
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   SELECT * FROM #RESULT ORDER BY Sku
   DROP TABLE #RESULT
END


GO