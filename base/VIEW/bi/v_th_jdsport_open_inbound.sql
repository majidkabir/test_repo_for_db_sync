SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Open_Inbound] AS
SELECT
   Convert (Varchar(10), R.ReceiptDate, 120) AS 'ReceiptDate',
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Sku,
   sum(RD.QtyReceived) AS 'QtyReceived',
   R.RECType
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.StorerKey = RD.StorerKey
WHERE
   (
(R.StorerKey = 'JDSPORTS'
      AND Convert (Varchar(10), R.ReceiptDate, 120) >= Convert (Varchar(10), getdate() - 1, 120)
      and Convert (Varchar(10), R.ReceiptDate, 120) < Convert (Varchar(10), getdate(), 120)
      AND R.Status = '0')
   )
GROUP BY
   Convert (Varchar(10), R.ReceiptDate, 120),
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Sku,
   R.RECType

GO