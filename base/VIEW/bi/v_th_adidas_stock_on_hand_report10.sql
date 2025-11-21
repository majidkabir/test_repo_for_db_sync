SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_Stock_On_Hand_Report10]
AS
SELECT
   AL1.Loc,
   AL2.Sku,
   AL2.DESCR,
   AL2.PACKKey,
   AL1.Id,
   AL2.Price,
   AL1.Qty as QTY_ON_HAND_PC,
   AL1.QtyAllocated,
   AL1.QtyPicked,
   AL3.Lottable01,
   Substring(AL4.HOSTWHCODE, 1, 2)as ZONE,
   substring(AL4.HOSTWHCODE, 3, 10) as SLOC,
   AL2.Style,
   AL2.Size,
   AL2.Color,
   AL2.SKUGROUP,
   (
      AL1.Qty
   )
   - ((AL1.QtyAllocated) + (AL1.QtyPicked)) as AvilableQtyPC,
   AL1.StorerKey,
   AL4.Facility,
   AL2.SkuStatus,
   AL1.Lot,
   AL3.Lottable05,
   AL4.LocationType,
   ''as QTY_ON_HAND_CS,
   ''as QTY_PICKED_CS,
   '' as QTY_ALLOCATED_CS,
   ''as QTY_AVAILABLE_CS,
   AL4.HOSTWHCODE
FROM dbo.V_LOTATTRIBUTE AL3 WITH (NOLOCK)
JOIN dbo.V_LOTxLOCxID AL1 WITH (NOLOCK) ON AL1.StorerKey = AL3.StorerKey AND AL1.Lot = AL3.Lot  AND AL1.Sku = AL3.Sku
JOIN dbo.V_LOC AL4 WITH (NOLOCK) ON AL4.Loc = AL1.Loc
RIGHT OUTER JOIN
      dbo.V_SKU AL2 WITH (NOLOCK)
      ON AL1.Sku = AL2.Sku AND AL1.StorerKey = AL2.StorerKey
WHERE
   AL2.StorerKey = 'ADIDAS'
   AND AL1.Qty > 0


GO