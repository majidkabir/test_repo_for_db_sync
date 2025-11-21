SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Inbound_Dashboard] AS
SELECT
   R.ReceiptKey,
   R.ExternReceiptKey,
   R.Status AS 'FullReceiveStatus',
   CASE (R.ASNStatus)
   WHEN '0'
   THEN 'OPEN'
   WHEN '9'
   THEN 'CLOSE'
   WHEN 'CANC'
   THEN 'CANC'
   END AS 'CloseAsnstatus',
   R.FinalizeDate,
   R.AddDate,
   R.AddWho,
   R.EditDate,
   R.EditWho,
   sum(RD.QtyExpected) AS 'QtyExpected',
   sum(RD.QtyReceived) AS 'QtyReceived',
   R.RECType,
   Convert(Date, R.AddDate) AS 'Adddate2',
   R.Facility,
   R.ReceiptGroup,
   S.SKUGROUP AS 'Skugroup'
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
WHERE
   (
(R.StorerKey = 'JDSPORTS'
      AND
      (
         R.AddDate >= Convert(VarChar(10), GetDate() - 32, 121)
         and R. Adddate < Convert(VarChar(10), GetDate(), 121)
      )
)
   )
GROUP BY
   R.ReceiptKey,
   R.ExternReceiptKey,
   R.Status,
   R.ASNStatus,
   R.FinalizeDate,
   R.AddDate,
   R.AddWho,
   R.EditDate,
   R.EditWho,
   R.RECType,
   Convert(Date, R.AddDate),
   R.Facility,
   R.ReceiptGroup,
   S.SKUGROUP

GO