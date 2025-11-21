SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_BBD_SURAT]
AS
SELECT
  AL1.Sku,
  AL3.DESCR,
  AL2.Lottable04 AS BBFDate,
  AL2.Lottable05 AS RECDate,
  AL2.Lottable01 AS ConsigneeCode,
  AL3.ALTSKU,
  AL3.ShelfLife,
  AL3.BUSR1 AS ProductCategory,
  AL2.Lottable02 AS BatchNo,
  GETDATE() AS Today,
  DATEDIFF(dy, (GETDATE()), (AL2.Lottable04)) AS RemainingLife_Days,
  CASE
    WHEN AL4.CaseCnt = '0' THEN '1'
    ELSE AL4.CaseCnt
  END AS [PCS/CA],
  AL3.Price AS Currency,
  AL1.Loc,
  AL2.Lottable03 AS MFGDate,
  AL4.PackKey,
  CASE
    WHEN AL1.Loc IN ('FBTMOBILE') THEN 'MBL'
    ELSE ' '
  END AS Lottable09,
  AL1.Id,
  AL1.Qty AS QTYtotal,
  AL1.QtyAllocated,
  AL1.QtyPicked,
  (AL1.Qty) - ((AL1.QtyAllocated) + (AL1.QtyPicked)) AS QtyAvailable,
  AL2.Lottable06 AS PO,
  AL5.HOSTWHCODE,
  CASE
    WHEN AL5.HOSTWHCODE LIKE 'NESPD' THEN 'HOLD'
    WHEN AL1.Loc IN ('NESPIRA') THEN 'HOLD'
    ELSE 'GOOD'
  END AS [Status],
  CASE
    WHEN AL5.HOSTWHCODE LIKE 'NESPD' THEN 'BL2'
    WHEN (AL1.Loc) LIKE 'NESPIRA' THEN 'BL2'
    ELSE 'BL1'
  END AS Sloc,
  AL3.SUSR1 AS InSL,
  AL3.SUSR2 AS OutSL,
  CASE
    WHEN AL3.SKUGROUP LIKE ('NESCOFEE') THEN 'BBD'
    WHEN AL3.SKUGROUP LIKE 'NESCOFEEB' THEN 'BBD'
    ELSE ' '
  END AS [Group],
  CASE
    WHEN AL1.Loc IN ('NESPIRA') THEN 'Loss'
    WHEN AL5.HOSTWHCODE LIKE 'NESPD' THEN 'Hold and Damaged'
    ELSE ' '
  END AS HoldReason,
  AL3.SKUGROUP

FROM dbo.LOTxLOCxID AL1 WITH (NOLOCK)
JOIN dbo.LOTATTRIBUTE AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.Lot = AL2.Lot AND AL1.Sku = AL2.Sku
JOIN dbo.SKU AL3  WITH (NOLOCK) ON AL1.StorerKey = AL3.StorerKey AND AL1.Sku = AL3.Sku
JOIN dbo.PACK AL4 WITH (NOLOCK) ON AL3.PACKKey = AL4.PackKey
JOIN dbo.LOC AL5  WITH (NOLOCK) ON AL1.Loc = AL5.Loc

WHERE
AL1.StorerKey = 'NESP'
AND AL1.Qty > 0
AND AL5.Facility = 'SNIDC'


GO