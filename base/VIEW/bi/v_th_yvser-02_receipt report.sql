SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-02_Receipt Report] as
SELECT DISTINCT
   R.Facility,
   RD.Sku,
   S.MANUFACTURERSKU,
   S.RETAILSKU,
   S.ALTSKU,
   S.DESCR,
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Lottable05,
   RD.Lottable02,
   RD.Lottable03,
   RD.Lottable04,
   RD.UOM,
   sum(RD.QtyExpected) as 'QtyExpected',
   sum(RD.QtyReceived) as 'QtyReceived'
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey 
      AND R.StorerKey = RD.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku 
      AND RD.StorerKey = S.StorerKey 
WHERE
   (
(R.StorerKey = 'YVESR' 
      AND R.Status = '9' 
      AND R.ASNStatus = '9' 
      AND convert(varchar, R.ReceiptDate, 112) >= convert(varchar, getdate() - 10, 112) )
   )
GROUP BY
   R.Facility,
   RD.Sku,
   S.MANUFACTURERSKU,
   S.RETAILSKU,
   S.ALTSKU,
   S.DESCR,
   R.ReceiptKey,
   R.ExternReceiptKey,
   RD.Lottable05,
   RD.Lottable02,
   RD.Lottable03,
   RD.Lottable04,
   RD.UOM 

GO