SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham   1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NOBLETH_2_SOH_Report]
AS
SELECT DISTINCT
   AL4.StorerKey,
   AL5.HOSTWHCODE,
   AL4.Sku,
   AL1.DESCR,
   sum(AL4.Qty) as 'QTY',
   AL4.QtyAllocated,
   AL4.QtyPicked,
   UPPER(AL2.PackUOM3) as 'UOM',
   UPPER(AL3.Lottable01) as 'Stock Status',
   AL3.Lottable02 as 'PO',
   AL3.Lottable03 as 'Brand',
   AL3.Lottable05,
   AL2.Pallet,
   AL1.BUSR4,
   Upper(AL5.Loc) as 'LOC',
   AL3.Lottable06,
   AL3.Lottable04,
   AL1.ShelfLife,
   DATEDIFF ( Day, convert(varchar,
   (
      AL3.Lottable05
   )
, 23), convert(varchar, GETDATE(), 23 )) as 'Aging Date'
FROM
dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL1.PACKKey = AL2.PackKey
JOIN dbo.V_LOTxLOCxID AL4 WITH (NOLOCK) ON AL4.Sku = AL1.Sku AND AL4.StorerKey = AL1.StorerKey
JOIN dbo.V_LOTATTRIBUTE AL3 WITH (NOLOCK)ON AL4.StorerKey = AL3.StorerKey AND AL4.Sku = AL3.Sku AND AL4.Lot = AL3.Lot
JOIN dbo.V_LOC AL5 WITH (NOLOCK) ON AL4.Loc = AL5.Loc
WHERE
(AL4.StorerKey = 'NOBLETH'
      AND AL4.Qty > 0
      AND AL5.Facility = 'FC')

GROUP BY
   AL4.StorerKey,
   AL5.HOSTWHCODE,
   AL4.Sku,
   AL1.DESCR,
   AL4.QtyAllocated,
   AL4.QtyPicked,
   UPPER(AL2.PackUOM3),
   UPPER(AL3.Lottable01),
   AL3.Lottable02,
   AL3.Lottable03,
   AL3.Lottable05,
   AL2.Pallet,
   AL1.BUSR4,
   Upper(AL5.Loc),
   AL3.Lottable06,
   AL3.Lottable04,
   AL1.ShelfLife,
   DATEDIFF ( Day, convert(varchar,
   (
      AL3.Lottable05
   )
, 23), convert(varchar, GETDATE(), 23 ))

GO