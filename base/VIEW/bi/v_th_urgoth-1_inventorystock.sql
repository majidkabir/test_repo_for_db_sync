SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_URGOTH-1_InventoryStock]
AS
SELECT
   AL1.StorerKey,
   AL3.Facility,
   AL1.Id AS 'PalletID',
   AL1.Loc,
   AL2.Lottable01 AS 'BatchNo.',
   AL1.Sku,
   AL4.DESCR AS 'Descr',
   AL1.Qty,
   AL5.PackUOM3 AS 'UOM',
   AL2.Lottable02 AS 'Serial',
   convert(varchar, AL2.Lottable04, 103) AS 'Expired Date',
   CASE WHEN AL1.Loc in ('A20240101','A20220102') THEN 'Damage'
   ELSE 'OK' End AS 'Stock Type'
   ,AL2.Lottable06
   ,AL2.Lottable07

FROM dbo.V_LOTxLOCxID AL1 WITH (NOLOCK)
JOIN dbo.V_LOTATTRIBUTE AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.Sku = AL2.Sku AND AL1.Lot = AL2.Lot
JOIN dbo.V_LOC AL3 WITH (NOLOCK) ON AL1.Loc = AL3.Loc
JOIN dbo.V_SKU AL4 WITH (NOLOCK) ON  AL1.Sku = AL4.Sku AND AL1.StorerKey = AL4.StorerKey
JOIN dbo.V_PACK AL5 WITH (NOLOCK) ON AL4.PACKKey = AL5.PackKey

WHERE AL1.Qty > 0
AND AL2.StorerKey = 'URGOTH'


GO