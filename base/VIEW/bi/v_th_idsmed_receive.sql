SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_IDSMED_Receive] AS
SELECT
   R.StorerKey,
   convert(varchar, RD.EditDate, 103) AS 'ReceiptDate',
   R.RECType,
   R.CarrierKey,
   RD.Sku,
   S.DESCR,
   RD.UOM,
   R.ExternReceiptKey AS 'PO Number#',
   R.Signatory,
   RD.QtyExpected,
   RD.QtyReceived,
   RD.EditDate,
   RD.Lottable01,
   RD.Lottable02 AS 'Batch No.',
   convert(varchar, RD.Lottable04, 103) AS 'Expire Date',
   convert(varchar, RD.Lottable05, 103) AS 'Rec. Date',
   R.UserDefine01 AS 'Supplier Invoice No.',
   ST.Company
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.StorerKey = S.StorerKey
      AND RD.Sku = S.Sku
LEFT OUTER JOIN dbo.STORER ST with (nolock) ON R.CarrierKey = ST.StorerKey
WHERE
   (
(R.StorerKey = 'IDSMED'
      AND RD.QtyReceived > 0
      AND convert(varchar, R.EditDate, 112) >= convert(varchar, getdate() - 1, 112)
      and convert(varchar, R.EditDate, 112) < convert(varchar, getdate(), 112)
      AND R.ASNStatus = '9')
   )
--ORDER BY
--   8
--

GO