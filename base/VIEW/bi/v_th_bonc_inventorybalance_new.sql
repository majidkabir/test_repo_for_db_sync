SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_BONC_InventoryBalance_New] AS
SELECT
   X.StorerKey,
   X.Sku,
   S.DESCR,
   X.Qty,
   X.QtyAllocated,
   X.QtyPicked,
   X.Id,
   case
      when
         A.Lottable01 = 'UR'
      then
         'Saleable'
      else
         A.Lottable01
   end AS 'Status'
, A.Lottable02 AS 'Batch', A.Lottable04 AS 'Expiry Date', A.Lottable03 AS 'MFGDate', A.Lottable05  AS 'Receiving Date',
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
   end AS ' InvoiceNo'
, X.Loc,
   (
      X.Qty
   )
    - (X.QtyAllocated) - (X.QtyPicked) AS 'Total available(carton)', S.ShelfLife, GETDATE() AS 'Today', DATEDIFF ( dy,
   (
      GETDATE()
   )
,
   (
      A.Lottable04
   ))AS 'Remaining Shelf Life (Day)'
, S.ShelfLife - (DATEDIFF ( dy,
   (
      GETDATE()
   )
,
   (
      A.Lottable04
   )
)) AS 'Present Accumulate Shelf life(Days)'
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
      AND X.Sku = A.Sku
JOIN dbo.SKU S ON X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
WHERE X.StorerKey = 'BONC'
      AND
      (
         NOT X.Qty = 0
      )
--ORDER BY
--   12, 14 DESC, 13
--Receiving Date,Invoice No.DESC,Catainer No.

GO