SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_4CARE_InventoryBalance] AS
SELECT
   X.StorerKey,
   X.Sku,
   S.DESCR,
   sum(X.Qty) AS 'QTY(carton)',
   X.Id,
   case
      when
         A.Lottable01 = 'UR'
      then
         'Saleable'
      else
         A.Lottable01
   end AS 'Status'
, A.Lottable02, A.Lottable04, A.Lottable03, A.Lottable05,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, CHARINDEX('-', A.Lottable06) + 1, Len(A.Lottable06))
   end AS 'Container No.'
,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, 1, CHARINDEX('-', A.Lottable06))
   end AS 'Invoice No.'
, X.Loc, S.ShelfLife
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) on X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
      AND X.Sku = A.Sku
JOIN dbo.SKU S with (nolock) on X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
WHERE X.StorerKey = '4CARE'
      AND
      (
         NOT X.Qty = 0
      )
GROUP BY
   X.StorerKey, X.Sku, S.DESCR, X.Id,
   case
      when
         A.Lottable01 = 'UR'
      then
         'Saleable'
      else
         A.Lottable01
   end
, A.Lottable02, A.Lottable04, A.Lottable03, A.Lottable05,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, CHARINDEX('-', A.Lottable06) + 1, Len(A.Lottable06))
   end
,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, 1, CHARINDEX('-', A.Lottable06))
   end
, X.Loc, S.ShelfLife
--ORDER BY
-- 10, 12, 11
 --'Lottable05','Container No.','Invoice No.'

GO