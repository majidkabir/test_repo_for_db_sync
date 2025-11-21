SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MUNTH_Receive] AS
SELECT
   R.StorerKey,
   convert(varchar, RD.EditDate, 103) AS 'ReceiptDate',
   R.RECType AS 'RecType',
   R.CarrierKey AS 'Carrier Code',
   RD.Sku,
   S.DESCR,
   RD.UOM,
   R.ExternReceiptKey AS 'PO Number#',
   R.Signatory AS 'Shipment No.',
   RD.QtyExpected,
   RD.QtyReceived,
   RD.EditDate,
   RD.Lottable02 AS 'Lot no.',
   convert(varchar, RD.Lottable03, 103) AS 'MFG Date',
   convert(varchar, RD.Lottable04, 103) AS 'Expiry Date',
   convert(varchar, RD.Lottable05, 103) AS 'Rec. Date',
   R.UserDefine01 AS 'Supplier Invoice No.',
   ST.Company,
   RD.ToId  AS 'ID Pallet'
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.StorerKey = S.StorerKey
      AND RD.Sku = S.Sku
   LEFT OUTER JOIN
      dbo.STORER ST with (nolock)
      ON (R.CarrierKey = ST.StorerKey)
WHERE
   (
(R.StorerKey = 'MUNTH'
      AND RD.QtyReceived > 0
      AND convert(varchar, R.EditDate, 112) >= convert(varchar, getdate() - 1, 112)
      and convert(varchar, R.EditDate, 112) < convert(varchar, getdate(), 112)
      AND R.ASNStatus = '9'
      AND R.Facility = 'LKB01')
   )
--ORDER BY
--   8
--   PO Number#

GO