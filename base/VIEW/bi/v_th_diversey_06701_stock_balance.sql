SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_06701_STOCK_BALANCE]
AS
 SELECT
  AL4.Loc,
  AL4.Facility,
  AL3.ALTSKU,
  AL1.Sku,
  AL1.StorerKey,
  AL3.DESCR,
  AL1.Qty,
  AL1.QtyAllocated,
  AL1.QtyPicked,
  AL2.Lottable01,
  AL2.Lottable02,
  AL2.Lottable03,
  AL2.Lottable04,
  AL2.Lottable05,
  AL2.Lottable06,
  AL2.Lottable07,
  AL2.Lottable08

FROM dbo.LOTxLOCxID AL1 WITH (NOLOCK)
JOIN dbo.LOTATTRIBUTE AL2 WITH (NOLOCK) ON AL1.Lot = AL2.Lot AND AL1.Sku = AL2.Sku AND AL1.StorerKey = AL2.StorerKey
JOIN dbo.SKU AL3 WITH (NOLOCK) ON AL1.StorerKey = AL3.StorerKey AND AL1.Sku = AL3.Sku
JOIN dbo.LOC AL4 WITH (NOLOCK) ON AL1.Loc = AL4.Loc

WHERE AL1.StorerKey = '06701'
AND AL4.Facility = '619'
AND AL1.Qty > 0


GO