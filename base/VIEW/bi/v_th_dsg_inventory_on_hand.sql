SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_Inventory_on_hand] AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Loc,
   X.Lot,
   A.Lottable01 AS 'MFG Date',
   A.Lottable02 AS 'Batch',
   A.Lottable04 AS 'Expiry Date',
   A.Lottable05 AS 'Receipt Date',
   X.Sku,
   S.DESCR,
   Sum ( X.Qty ) AS 'Sum(Qty)',
   Sum ( X.QtyAllocated )AS 'Sum(QtyAllocated )',
   Sum ( X.QtyPicked )AS 'Sum(QtyPicked)' ,
   P.Pallet AS 'Pallet',
   L.HOSTWHCODE AS 'JDE Location',
   C.Short,
   case
      when
         P.CaseCnt <> 0
      then
(Sum ( X.Qty )) / P.CaseCnt
      else
         0
   end 'QTYPerCase'
, P.CaseCnt, S.SUSR3, A.Lottable03, A.Lottable06, Right((A.Lottable01), 4) + '-' + substring((A.Lottable01), 3, 2) + '-' + left((A.Lottable01), 2) AS ' DateMFG'
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.CODELKUP C with (nolock) ON S.SKUGROUP = C.Code
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
      AND X.Sku = A.Sku
WHERE
X.StorerKey = 'DSGTH'
      AND L.Facility IN
      (
         '18120', '18130', '18140'
      )
GROUP BY
   X.StorerKey, L.Facility, X.Loc, X.Lot, A.Lottable01, A.Lottable02, A.Lottable04, A.Lottable05, X.Sku, S.DESCR, P.Pallet, L.HOSTWHCODE, C.Short, P.CaseCnt, S.SUSR3, A.Lottable03, A.Lottable06, Right((A.Lottable01), 4) + '-' + substring((A.Lottable01), 3, 2) + '-' + left((A.Lottable01), 2)

--ORDER BY
--   15 DESC, 2, 3, 9
--   JEDLocation,Facility,Loc,

GO