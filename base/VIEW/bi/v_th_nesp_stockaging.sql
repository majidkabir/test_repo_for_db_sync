SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_StockAging]
AS
SELECT
  AL1.Sku,
  AL3.DESCR,
  AL2.Lottable04 AS BBFDate,
  AL2.Lottable05 AS RECDate,
  AL2.Lottable01 AS ConsigneeCode,
  AL3.ShelfLife,
  AL2.Lottable02 AS BatchNo,
  GETDATE() AS Today,
  DATEDIFF(dy, (GETDATE()), (AL2.Lottable04)) AS RemainingLife_Days,
  CASE
    WHEN AL4.CaseCnt = '0' THEN '1'
    ELSE AL4.CaseCnt
  END AS [PCS/CA],
  CASE
    WHEN AL1.Loc IN ('FBTHOLD') THEN 'HOLD QC Check'
    WHEN AL1.Loc IN ('FBTDMG') THEN 'Damage Product'
    WHEN AL1.Loc LIKE 'THAW%' THEN 'Pending Thaw Process'
    ELSE ' '
  END AS HoldReason,
  AL1.Loc,
  AL2.Lottable03 AS MFGDate,
  CASE
    WHEN AL1.Loc IN ('FBTMOBILE') THEN 'MBL'
    ELSE ' '
  END AS Lottable09,
  AL1.Id,
  AL1.Qty AS [Qty (PCS)],
  AL1.QtyAllocated AS [Qtyallocated (PCS)],
  AL1.QtyPicked AS [Qtypicked (PCS)],
  (AL1.Qty) - ((AL1.QtyAllocated) + (AL1.QtyPicked)) AS [Remaining (PCS)],
  AL5.HOSTWHCODE,
  CASE
    WHEN AL5.HOSTWHCODE LIKE 'NESPD' THEN 'HOLD'
    ELSE 'GOOD'
  END AS [Status]

FROM dbo.LOTxLOCxID AL1 WITH (NOLOCK)
JOIN dbo.LOTATTRIBUTE AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.Lot = AL2.Lot AND AL1.Sku = AL2.Sku
JOIN dbo.SKU AL3  WITH (NOLOCK) ON AL1.StorerKey = AL3.StorerKey AND AL1.Sku = AL3.Sku
JOIN dbo.PACK AL4 WITH (NOLOCK) ON AL3.PACKKey = AL4.PackKey
JOIN dbo.LOC AL5  WITH (NOLOCK) ON AL1.Loc = AL5.Loc

WHERE
AL1.StorerKey = 'NESP'
AND AL1.Qty > 0
AND AL5.Facility = 'BDC01'
AND AL5.HOSTWHCODE = 'NESPD'

GO