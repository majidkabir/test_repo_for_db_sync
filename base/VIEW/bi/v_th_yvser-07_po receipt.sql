SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-07_PO receipt] as
SELECT
   Convert(varchar, RD.Lottable05, 103) as 'Rec Date',
   convert(varchar, PO.PODate, 103) as 'POD Date',
   convert(varchar, PO.EffectiveDate, 103) as 'Effective Date',
   PO.ExternPOKey,
   PO.SellersReference,
   PO.SellerName,
   (
      Case
         When
            R.Facility = 'KT01' 
         then
            'KTWH' 
         when
            R.Facility = 'BDC01' 
         then
            'BNWH' 
         when
            R.Facility = 'LKDC' 
         then
            'LKWH' 
         else
            'UNKNOW' 
      end 
   )as 'Facility'
FROM
   dbo.PO PO with (nolock)
JOIN dbo.RECEIPT R with (nolock) ON PO.StorerKey = R.StorerKey 
      AND PO.ExternPOKey = R.ExternReceiptKey 
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey 
      AND R.ExternReceiptKey = RD.ExternReceiptKey 
      AND R.StorerKey = RD.StorerKey
WHERE
   (
(R.StorerKey = 'YVESR' 
      AND R.RECType <> 'GRN' 
      AND R.Status = '9' 
      AND R.ASNStatus = '9' 
      AND convert(varchar, RD.Lottable05, 112) = convert(varchar, GetDate() - 1, 112))
   )

GO