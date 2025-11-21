SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JNJTRKIT_SummaryReceipt] AS
SELECT
   R.CarrierKey,
   R.ExternReceiptKey,
   R.ReceiptKey,
   R.RECType,
   R.CarrierName,
   R.CarrierReference,
   R.POKey,
   R.ReceiptDate,
   R.StorerKey,
   R.WarehouseReference,
   RD.QtyExpected,
   sum(RD.QtyReceived) AS 'QtyReceived',
   RD.Sku,
   RD.UOM,
   S.DESCR,
   R.Notes,
   RD.Lottable02
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
      AND RD.StorerKey = S.StorerKey
WHERE
   (
(R.StorerKey = 'JNJTRKIT'
      AND convert(varchar, R.ReceiptDate, 112) > convert(varchar, getdate() - 31, 112)
      and convert(varchar, R.ReceiptDate, 112) <= convert(varchar, getdate(), 112))
   )
GROUP BY
   R.CarrierKey,
   R.ExternReceiptKey,
   R.ReceiptKey,
   R.RECType,
   R.CarrierName,
   R.CarrierReference,
   R.POKey,
   R.ReceiptDate,
   R.StorerKey,
   R.WarehouseReference,
   RD.QtyExpected,
   RD.Sku,
   RD.UOM,
   S.DESCR,
   R.Notes,
   RD.Lottable02
--ORDER BY
--   13,SKU

GO