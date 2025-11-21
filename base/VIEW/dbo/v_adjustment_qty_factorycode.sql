SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Adjustment_Qty_FactoryCode]
AS
SELECT DISTINCT  a1.*, p.pokey, p.userdefine03 as Factorycode
FROM V_Adjustment_Qty a1
JOIN ITRN I WITH (NOLOCK) ON A1.LOT = I.LOT
JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON SUBSTRING(i.SourceKey, 1, 10) = rd.ReceiptKey AND SUBSTRING(i.SourceKey, 11, 15) = rd.ReceiptLineNumber
JOIN RECEIPT R WITH (NOLOCK) ON RD.receiptkey = R.receiptkey  
LEFT OUTER JOIN PO P WITH (NOLOCK) ON rd.POKey = p.POKey 
WHERE i.SourceType like 'ntrReceiptDetail%'

GO