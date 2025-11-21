SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE    VIEW [BI].[V_TH_DMCTH_Daily_Reports_SOH]
AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Id,
   X.Sku,
   S.DESCR,
   P.PackUOM3,
   P.CaseCnt,
   P.Pallet,
   X.QtyAllocated,
   X.QtyPicked,
   X.Qty,
   A.Lottable01,
   A.Lottable02,
   A.Lottable04,
   A.Lottable03,
   A.Lottable05

FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey AND X.Sku = A.Sku AND X.Lot = A.Lot
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE X.StorerKey = 'DMCTH'
AND X.Qty > 0

GO