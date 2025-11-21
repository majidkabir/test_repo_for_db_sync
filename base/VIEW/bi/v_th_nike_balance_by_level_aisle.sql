SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_Balance_By_Level_Aisle]
AS
SELECT
  AL1.StorerKey,
  AL4.Facility,
  AL1.Loc,
  AL1.Lot,
  AL2.DESCR,
  AL1.Sku,
  SUM(AL1.Qty) as BOH,
  SUM(AL1.QtyAllocated) as QtyAllocated,
  SUM(AL1.QtyPicked) as QtyPicked,
  AL3.Lottable02,
  AL3.Lottable06,
  AL3.Lottable05 as [Receipt_D],
  AL3.Lottable01 as [Batch#],
  AL3.Lottable03 as [Production_D],
  AL3.Lottable04 as [Expiry_D],
  AL4.HOSTWHCODE,
  AL4.LocLevel,
  AL4.LocAisle,
  AL4.PutawayZone as [Zone],
  AL2.BUSR3 as IN_Close,
  AL2.BUSR4 as Season,
  AL2.SUSR4 as GPC,
  AL2.BUSR7 as Skugroup,
  CASE
    WHEN AL2.SUSR4 = '000013' THEN 'GOLF'
    ELSE 'NTL'
  END as [Type]

FROM dbo.LOTxLOCxID AS AL1 WITH (NOLOCK)
INNER JOIN dbo.SKU AS AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.Sku = AL2.Sku
INNER JOIN dbo.LOTATTRIBUTE AS AL3 WITH (NOLOCK) ON AL1.Lot = AL3.Lot  AND AL1.Sku = AL3.Sku AND AL1.StorerKey = AL3.StorerKey
INNER JOIN dbo.LOC AS AL4 WITH (NOLOCK) ON AL1.Loc = AL4.Loc

WHERE AL1.StorerKey = 'niketh'
AND AL1.Qty <> 0

GROUP BY AL1.StorerKey,
         AL4.Facility,
         AL4.HOSTWHCODE,
         AL4.LocLevel,
         AL4.LocAisle,
         AL1.Loc,
         AL1.Sku,
         AL2.DESCR,
         AL1.Lot,
         AL3.Lottable02,
		   AL3.Lottable06,
         AL3.Lottable01,
         AL3.Lottable03,
         AL3.Lottable05,
         AL3.Lottable04,
         AL4.PutawayZone,
         AL2.BUSR3,
         AL2.BUSR4,
         AL2.SUSR4,
         AL2.BUSR7,
         AL2.SUSR4

GO