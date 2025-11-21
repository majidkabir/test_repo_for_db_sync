SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_ELCTH-01_BOH_Storer_ELCCS] as
SELECT
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.DESCR,
   X.Loc,
   SUM ( X.Qty ) as 'Qty',
   A.Lottable01,
   A.Lottable02,
   A.Lottable03,
   convert(varchar, A.Lottable04, 103) as 'Exp Date',
   convert(varchar, A.Lottable05, 103) as 'Rec Date'
FROM dbo.LOTxLOCxID X with (nolock)
LEFT OUTER JOIN dbo.LOTATTRIBUTE A with (nolock)
      ON (X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
      AND X.Sku = A.Sku)
LEFT OUTER JOIN dbo.SKU S with (nolock)
      ON (X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku)
LEFT OUTER JOIN dbo.LOC L with (nolock)
      ON (X.Loc = L.Loc)
WHERE X.StorerKey = 'ELCCS'
      AND L.Facility = '3101E'
GROUP BY
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.DESCR,
   X.Loc,
   A.Lottable01,
   A.Lottable02,
   A.Lottable03,
   convert(varchar, A.Lottable04, 103),
   convert(varchar, A.Lottable05, 103)

GO