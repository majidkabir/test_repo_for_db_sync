SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_FTP_Daily_Reports_SOH] AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Sku,
   S.DESCR,
   SUM ( X.Qty ) AS 'Qty',
   SUM ( X.QtyAllocated )AS 'QtyAllocated',
   SUM ( X.QtyPicked )AS 'QtyPicked',
   P.Pallet,
   A.Lottable02,
   A.Lottable03,
   A.Lottable04,
   A.Lottable05,
   S.ALTSKU,
   P.CaseCnt,
   P.PackUOM2,
   P.InnerPack
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Sku = A.Sku
      AND X.Lot = A.Lot
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(X.StorerKey = 'FTP'
      AND X.Qty > 0)
   )
GROUP BY
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Sku,
   S.DESCR,
   P.Pallet,
   A.Lottable02,
   A.Lottable03,
   A.Lottable04,
   A.Lottable05,
   S.ALTSKU,
   P.CaseCnt,
   P.PackUOM2,
   P.InnerPack

GO