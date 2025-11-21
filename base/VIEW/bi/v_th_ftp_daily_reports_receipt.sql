SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_FTP_Daily_Reports_Receipt] AS
SELECT
   R.StorerKey,
   R.ExternReceiptKey,
   R.ReceiptDate,
   RD.ExternLineNo,
   RD.Sku,
   --S.ALTSKU,
   S.DESCR,
   Sum(RD.QtyReceived) AS 'QtyReceived',
   P.InnerPack,
   P.CaseCnt
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
		AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.StorerKey = S.StorerKey
		AND RD.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(R.StorerKey = 'FTP'
      AND convert(date, R.ReceiptDate) = convert(date, getdate() - 1)
      AND R.ASNStatus = '9')
   )
GROUP BY
   R.StorerKey,
   R.ExternReceiptKey,
   R.ReceiptDate,
   RD.ExternLineNo,
   RD.Sku,
   S.ALTSKU,
   S.DESCR,
   P.InnerPack,
   P.CaseCnt

GO