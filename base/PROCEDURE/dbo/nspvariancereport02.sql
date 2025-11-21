SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspVarianceReport02                                */
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

CREATE PROCEDURE [dbo].[nspVarianceReport02] (
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
@c_loc NVARCHAR(10)

SELECT UPPER(CCDETAIL.StorerKey) AS StorerKey,
UPPER(CCDETAIL.Sku) AS SKU,
SUM(CCDETAIL.Qty) AS CountQty,
-- ISNULL(SUM(L.Qty),0) AS SystemQty,
0  AS SystemQty,
SKU.DESCR,
SKU.PackKey,
'' AS CCSheetNo,
CCDETAIL.Loc
INTO #RESULT
FROM CCDETAIL (NOLOCK)
JOIN SKU (NOLOCK) ON ( CCDETAIL.Storerkey = SKU.Storerkey AND CCDETAIL.SKU = SKU.SKU )
JOIN LOC (NOLOCK) ON ( CCDETAIL.Loc = LOC.Loc )
-- RIGHT OUTER JOIN SKUxLOC AS L (NOLOCK) ON (L.LOT = CCDETAIL.LOT AND L.LOC = CCDETAIL.LOC AND L.ID = CCDETAIL.ID )
WHERE CCDETAIL.StorerKey >= @c_StorerMin AND CCDETAIL.StorerKey <= @c_StorerMax
AND CCDETAIL.Sku >= @c_SkuMin          AND CCDETAIL.Sku <= @c_SkuMax
AND SKU.ItemClass >= @c_ClassMin       AND SKU.ItemClass <= @c_ClassMax
AND CCDETAIL.Loc >= @c_LocationMin     AND CCDETAIL.Loc <= @c_LocationMax
AND LOC.PutawayZone >= @c_ZoneMin      AND LOC.PutawayZone <= @c_ZoneMax
GROUP BY CCDETAIL.StorerKey, CCDETAIL.Sku, SKU.DESCR, SKU.PackKey, CCDETAIL.Loc

CREATE CLUSTERED INDEX Result_idx
ON #RESULT (StorerKey, SKU, LOC)
WITH FILLFACTOR = 100

UPDATE #RESULT
SET SystemQty = SKUxLOC.Qty
FROM #RESULT
JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = #RESULT.StorerKey
AND SKUxLOC.SKU = #RESULT.SKU
AND SKUxLOC.LOC = #RESULT.LOC )

INSERT INTO #RESULT
SELECT UPPER(SKUxLOC.StorerKey) AS StorerKey,
UPPER(SKUxLOC.Sku) AS SKU,
ISNULL(#RESULT.CountQty, 0) AS CountQty,
ISNULL( SUM(SKUxLOC.Qty),0 ) AS SystemQty,
SKU.DESCR,
SKU.PackKey,
'' AS CCSheetNo,
SKUxLOC.Loc
FROM  SKUxLOC (NOLOCK)
JOIN  SKU (NOLOCK) ON ( SKUxLOC.StorerKey = SKU.StorerKey AND SKUxLOC.SKU = SKU.SKU )
JOIN  LOC (NOLOCK) ON ( SKUxLOC.Loc = LOC.Loc )
LEFT OUTER JOIN #RESULT ON (SKUxLOC.StorerKey = #RESULT.StorerKey
AND SKUxLOC.SKU = #RESULT.SKU
AND SKUxLOC.LOC = #RESULT.LOC)
WHERE SKUxLOC.StorerKey >= @c_StorerMin
AND SKUxLOC.StorerKey <= @c_StorerMax
AND SKUxLOC.Sku  >= @c_SkuMin AND SKUxLOC.Sku <= @c_SkuMax
AND SKU.ItemClass   >= @c_ClassMin AND SKU.ItemClass <= @c_ClassMax
AND SKUxLOC.Loc  >= @c_LocationMin AND SKUxLOC.Loc <= @c_LocationMax
AND LOC.PutawayZone >= @c_ZoneMin AND LOC.PutawayZone <= @c_ZoneMax
AND SKUxLOC.QTY  >  0
AND #RESULT.CountQty IS NULL
GROUP BY SKUxLOC.StorerKey, SKUxLOC.Sku, SKU.DESCR, SKU.PackKey, SKUxLOC.Loc, #RESULT.CountQty
ORDER BY SKUxLOC.StorerKey, SKUxLOC.Sku, SKUxLOC.Loc

SELECT StorerKey, SKU
INTO   #FILTER
FROM   #RESULT
GROUP  BY StorerKey, SKU
HAVING SUM(CountQty) = SUM(SystemQty)

DELETE #RESULT
FROM   #FILTER
WHERE  #RESULT.StorerKey = #FILTER.StorerKey
AND    #RESULT.SKU = #FILTER.SKU

SELECT * FROM #RESULT ORDER BY STORERKEY, SKU, LOC
DROP TABLE #RESULT

SET QUOTED_IDENTIFIER OFF

GO