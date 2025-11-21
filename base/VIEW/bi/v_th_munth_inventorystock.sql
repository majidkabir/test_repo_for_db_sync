SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MUNTH_InventoryStock] AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Id,
   X.Loc,
   A.Lottable01 AS 'Serial No.',
   X.Sku,
   S.DESCR,
   X.Qty,
   P.PackUOM3 AS 'UOM',
   A.Lottable02 AS 'Batch',
   convert(varchar, A.Lottable04, 103) AS 'Expried Date',
   Case
      When
         X.Loc in
         (
            'A20240101',
            'A20220102'
         )
      Then
         'Damage'
      Else
         'OK'
   End AS 'StockType'
, convert(varchar, A.Lottable03, 103) AS 'MFG Date'
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Sku = A.Sku
      AND X.Lot = A.Lot
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.SKU S with (nolock) ON X.Sku = S.Sku
      AND X.StorerKey = S.StorerKey
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(X.Qty > 0
      AND A.StorerKey = 'MUNTH'
      AND L.Facility = 'LKB01')
   )
--ORDER BY
--   6
--	--SKU

GO