SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_FG_SOH_Reports_SIL2-1] AS
SELECT
   L.Facility,
   X.StorerKey,
   X.Sku,
   X.Loc,
   X.Lot,
   X.Id,
   sum(X.Qty) AS 'Qty',
   S.PACKKey,
   P.PackUOM3,
   A.Lottable01,
   A.Lottable02,
   A.Lottable03,
   CONVERT(VARCHAR(19), A.Lottable04, 120) AS 'Lottable04',
   CONVERT(VARCHAR(19), A.Lottable05, 120) AS 'Lottable05',
   CONVERT(VARCHAR(19), A.AddDate, 120) AS 'AddDate',
   L.HOSTWHCODE,
   X.QtyAllocated,
   X.QtyPicked,
   LOT.QtyOnHold,
   LOT.QtyPicked AS 'Qtypicked2'
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.SKU S with (nolock) ON X.Sku = S.Sku
      AND X.StorerKey = S.StorerKey
JOIN dbo.PACK P with (nolock) ON P.PackKey = S.PACKKey
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.Lot = A.Lot
JOIN dbo.LOT LOT with (nolock) ON X.Lot = LOT.Lot
      AND X.StorerKey = LOT.StorerKey
      AND X.Sku = LOT.Sku
WHERE X.StorerKey = 'DSGTH'
AND X.Qty > 0
AND A.Lottable03 LIKE 'FG%'
GROUP BY
   L.Facility,
   X.StorerKey,
   X.Sku,
   X.Loc,
   X.Lot,
   X.Id,
   S.PACKKey,
   P.PackUOM3,
   A.Lottable01,
   A.Lottable02,
   A.Lottable03,
   CONVERT(VARCHAR(19), A.Lottable04, 120),
   CONVERT(VARCHAR(19), A.Lottable05, 120),
   CONVERT(VARCHAR(19), A.AddDate, 120),
   L.HOSTWHCODE,
   X.QtyAllocated,
   X.QtyPicked,
   LOT.QtyOnHold,
   LOT.QtyPicked

GO