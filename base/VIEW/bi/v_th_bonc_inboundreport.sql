SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_BONC_Inboundreport] AS
SELECT
   R.StorerKey,
   R.POKey,
   R.ExternReceiptKey,
   RD.Sku,
   S.DESCR,
   RD.QtyExpected,
   RD.QtyReceived,
   RD.ToId,
   case
      when
         RD.Lottable01 = 'UR'
      then
         'Saleable'
      else
         RD.Lottable01
   end AS 'Status'
, RD.Lottable02, RD.Lottable03, RD.Lottable04, RD.Lottable05
FROM dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
      AND RD.StorerKey = S.StorerKey
WHERE R.StorerKey = 'BONC'
AND convert(varchar, R.EditDate, 112) >= convert(varchar, getdate() - 1, 112)
AND R.ASNStatus = '9'

GO