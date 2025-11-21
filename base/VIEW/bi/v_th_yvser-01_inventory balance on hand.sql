SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-01_Inventory Balance on hand] as
SELECT DISTINCT
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.DESCR,
   P.Pallet,
   X.Loc,
   X.Id,
   Sum ( X.Qty ) as 'QTY',
   Sum ( X.QtyAllocated ) as 'QtyAllocated',
   Sum ( X.QtyPicked ) as 'QtyPicked',
   A.Lottable05,
   A.Lottable02,
   A.Lottable03,
   A.Lottable04 
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey 
      AND X.Sku = A.Sku 
      AND X.Lot = A.Lot
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey 
      AND X.Sku = S.Sku 
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
LEFT OUTER JOIN dbo.LOC L ON (X.Loc = L.Loc) 
WHERE
   (
(X.StorerKey = 'YVESR' 
      AND L.Facility IN 
      (
         'BDC02',
         'KT01'
      )
)
   )
GROUP BY
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.DESCR,
   P.Pallet,
   X.Loc,
   X.Id,
   A.Lottable05,
   A.Lottable02,
   A.Lottable03,
   A.Lottable04 

GO