SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_PEPSI-01_Receipt] as
SELECT
   convert(varchar, RD.EditDate, 103) as 'Lastdate',
   R.StorerKey,
   R.RECType,
   R.ReceiptKey,
   R.ExternReceiptKey,
   R.WarehouseReference,
   R.CarrierName,
   R.CarrierKey,
   RD.Sku,
   S.DESCR,
   P.PackUOM1,
   R.Signatory,
   RD.QtyExpected / P.CaseCnt as 'QtyExpected',
   RD.QtyReceived / P.CaseCnt as 'QtyReceived',
   RD.EditDate,
   RD.Lottable01,
   RD.Lottable03,
   convert(varchar, RD.Lottable05, 103) as 'Lottable05',
   RD.ToId,
   RD.Lottable02,
   RD.ReceiptLineNumber
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.StorerKey = S.StorerKey
      AND RD.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(R.StorerKey = 'PEPSI'
      AND R.Status = '9'
      AND RD.QtyReceived > 0
      AND convert (nvarchar, R.Finalizedate, 102) > convert (nvarchar, getdate() - 2, 102)
      and convert (nvarchar, R.Finalizedate, 102) <= convert (nvarchar, getdate(), 102))
   )

GO