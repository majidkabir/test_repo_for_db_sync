SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-12_Order intransit] as 
SELECT
   convert(date, GetDate(), 103) as 'Date Now',
   S.BUSR1,
   S.BUSR3,
   S.BUSR4,
   S.BUSR5,
   PD.Sku,
   S.MANUFACTURERSKU,
   S.DESCR,
   PD.QtyOrdered,
   P.SellersReference,
   P.SellerName,
   P.ExternPOKey,
   Convert(date, P.PODate, 103) as 'POD Date',
   Convert(date, P.EffectiveDate, 103) as 'Effective Date',
   Convert(date, P.EffectiveDate + 13, 103) as 'Effective Date+13',
   P.UserDefine02,
   P.Notes,
   P.UserDefine03,
   P.AddDate,
   P.Status,
   P.ExternPOKey as 'ExtPO2'
FROM
   dbo.PO P with (nolock)
JOIN dbo.PODetail PD with (nolock) ON P.StorerKey = PD.StorerKey 
      AND P.POKey = PD.POKey 
      AND P.ExternPOKey = PD.ExternPOKey 
JOIN dbo.SKU S with (nolock) ON PD.StorerKey = S.StorerKey 
      AND PD.Sku = S.Sku
WHERE
   (
(P.StorerKey = 'YVESR' 
      AND P.Status NOT IN 
      (
         '9',
         'CANC'
      )
      AND Convert(date, P.EffectiveDate, 112) <= Convert(date, GetDate() - 1, 112) 
      AND len(S.MANUFACTURERSKU) > 2 
      AND P.ExternPOKey not in 
      (
         select
            Receipt.ExternReceiptKey 
         from
            Receipt with (nolock)
         where
            Receipt.StorerKey = 'YVESR' 
            and Receipt.ASNStatus = '9'
      )
      AND 
      (
         NOT P.ExternStatus = 'CANC'
      )
)
   )

GO