SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CITYFR_4_CTX_Holding_Report]
AS
SELECT DISTINCT
   case
      when
         AL5.Lottable06 = 'CTX'
      then
         'CTX Holding'
      when
         AL5.Lottable06 <> 'CTX'
      then
         'CITYFR'
   end as 'Principal'
, AL3.StorerKey, AL4.HOSTWHCODE, AL3.Sku, AL1.DESCR, SUM ( AL3.Qty ) as 'QTY', SUM ( AL3.QtyAllocated ) as 'QtyAllocated',
 SUM ( AL3.QtyPicked ) as 'QtyPicked', UPPER(AL2.PackUOM3) as 'UOM', UPPER(AL5.Lottable01) as'Lottable01', AL5.Lottable02 as 'PO#',
 AL5.Lottable03, AL5.Lottable05, AL5.Lottable13, AL5.Lottable02 as 'CD', AL1.ShelfLife, DATEDIFF ( Day, convert(varchar,
   (
      AL5.Lottable05
   )
, 23), convert(varchar, GETDATE(), 23 )) as 'Aging day', getdate() as 'getdate',
DATEDIFF ( Day,convert (varchar,AL5.Lottable05),convert(varchar, getdate()) ) as 'Residency'
FROM
   dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON  AL1.PACKKey = AL2.PackKey
JOIN dbo.V_LOTxLOCxID AL3 WITH (NOLOCK) ON AL3.Sku = AL1.Sku AND AL3.StorerKey = AL1.StorerKey
JOIN dbo.V_LOC AL4 WITH (NOLOCK) ON AL3.Loc = AL4.Loc
JOIN dbo.V_LOTATTRIBUTE AL5 WITH (NOLOCK) ON AL3.StorerKey = AL5.StorerKey AND AL3.Sku = AL5.Sku AND AL3.Lot = AL5.Lot
WHERE
(AL3.StorerKey = 'CITYFR'
      AND AL3.Qty > 0
      AND AL5.Lottable06 = 'CTX')
GROUP BY
   case
      when
         AL5.Lottable06 = 'CTX'
      then
         'CTX Holding'
      when
         AL5.Lottable06 <> 'CTX'
      then
         'CITYFR'
   end
, AL3.StorerKey, AL4.HOSTWHCODE, AL3.Sku, AL1.DESCR, UPPER(AL2.PackUOM3), UPPER(AL5.Lottable01), AL5.Lottable02, AL5.Lottable03, AL5.Lottable05, AL5.Lottable13, AL5.Lottable02, AL1.ShelfLife, DATEDIFF ( Day, convert(varchar,
   (
      AL5.Lottable05
   )
, 23), convert(varchar, GETDATE(), 23 ))

GO