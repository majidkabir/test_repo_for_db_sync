SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JNJTRKIT_Inventory_Stock] AS
SELECT
   X.Loc,
   X.Sku,
   S.DESCR,
   X.Qty,
   X.QtyAllocated,
   X.QtyPicked,
   A.Lottable01 AS 'CartoNo.',
   A.Lottable02 AS 'BatchNo.',
   A.Lottable03 AS 'Prod_Date',
   A.Lottable04 AS 'Exp_Date',
   A.Lottable05 AS 'Rec_Date',
   X.StorerKey,
   S.CLASS,
   S.SKUGROUP,
   A.Lottable06,
   Case
      When
         A.Lottable07 = '1'
      Then
         'Good Received'
      When
         A.Lottable07 = '2'
      Then
         'Quarantined'
      When
         A.Lottable07 = '3'
      Then
         'Damaged'
      Else
         A.Lottable07
   End AS 'Stock Type'
, A.Lottable02
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Sku = A.Sku
      AND X.Lot = A.Lot
JOIN dbo.SKU S with (nolock) ON X.Sku = S.Sku
      AND X.StorerKey = S.StorerKey
WHERE
   (
(X.Qty > 0
      AND A.StorerKey = 'JNJTRKIT')
   )
--ORDER BY
--   2, 1
--   SKU,LOC

GO