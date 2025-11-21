SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_FG_Inventory_Balances] AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Lot,
   X.Sku,
   S.DESCR,
   Sum ( X.Qty ) AS 'Qty',
   Sum ( X.QtyAllocated ) AS 'QtyAllocated',
   Sum ( X.QtyPicked ) AS 'QtyPicked',
   P.Pallet,
   A.Lottable02 AS 'Batch',
   A.Lottable01  AS 'MFG Date',
   A.Lottable05 AS 'Receipt Date',
   A.Lottable04 AS 'Expiry Date',
   L.HOSTWHCODE AS 'JDE Location',
   A.Lottable03
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey
	AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.Lot = A.Lot
	AND X.StorerKey = A.StorerKey
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
WHERE X.StorerKey = 'DSGTH'
AND L.HOSTWHCODE LIKE '%FGSL%'
AND X.Qty > 0
GROUP BY
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Lot,
   X.Sku,
   S.DESCR,
   P.Pallet,
   A.Lottable02,
   A.Lottable01,
   A.Lottable05,
   A.Lottable04,
   L.HOSTWHCODE,
   A.Lottable03
--ORDER BY
--   15,
--   2,
--   3,
--   5,
--   12

   --Facility
   --Loc
   --Sku
   --MFG Date
   --JDE Location

GO