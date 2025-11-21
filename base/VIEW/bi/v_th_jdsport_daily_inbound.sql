SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Daily_Inbound] AS
SELECT
   R.StorerKey,
   Convert ( Varchar(10), R.ReceiptDate, 120) AS 'ReceiptDate',
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Sku,
   Sum(RD.QtyReceived) AS 'QtyReceived',
   R.RECType
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
WHERE
   (
(R.StorerKey = 'JDSPORTS'
      AND R.Status = '9'
      AND R.ASNStatus = '9')
   )
GROUP BY
   R.StorerKey,
   Convert ( Varchar(10), R.ReceiptDate, 120),
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Sku,
   R.RECType

GO