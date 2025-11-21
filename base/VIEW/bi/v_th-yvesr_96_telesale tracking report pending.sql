SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   VIEW [BI].[V_TH-YVESR_96_telesale Tracking Report Pending] as
SELECT
   O.ExternOrderKey,
   O.OrderKey,
   O.OrderDate,
   O.DeliveryDate,
   O.ConsigneeKey,
   O.C_Company,
   O.C_City,
   OD.OrderLineNumber,
   OD.Sku,
   S.DESCR,
   S.SUSR3,
   OD.OriginalQty,
   O.Status as 'status1',
   OD.QtyAllocated,
   OD.QtyPicked,
   OD.ShippedQty,
   '' as 'Blank',
   O.C_Zip,
   O.C_State,
   Case
      when
         O.Type = 'B2S' 
      then
         'B2S' 
      else
         'Retail' 
   end as 'TYPE'
, OD.UserDefine01, O.C_contact1, O.C_Address1, O.C_Address2, O.C_Address3, O.C_Address4, P.TrackCol01, O.Status  as 'STATUS'
FROM
   ORDERS O with (nolock)
   LEFT OUTER JOIN
      ORDERDETAIL OD with (nolock)
      ON (O.OrderKey = OD.OrderKey) 
   LEFT OUTER JOIN
      SKU S with (nolock)
      ON (OD.Sku = S.Sku AND OD.StorerKey = S.StorerKey) 
   LEFT OUTER JOIN
      POD P with (nolock)
      ON (O.OrderKey = P.OrderKey) 
WHERE
   (
(O.StorerKey = 'YVESR' 
      AND O.Status NOT IN 
      (
         '9', 'CANC'
      )
      AND O.AddDate >= {ts '2021-05-27 00:00:00.000'} 
      AND 
      (
         O.ExternOrderKey LIKE 'YTCC%' 
         OR O.ExternOrderKey LIKE 'YTTS%'
      )
      OR O.ConsigneeKey = 'YTELE' 
      AND O.Status IN 
      (
         '0', '1', '2', '3', '5'
      )
)
   )

GO