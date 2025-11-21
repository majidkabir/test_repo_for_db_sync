SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-95_Order Shipped Report] as 
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
   O.Status AS 'Status' ,
   OD.QtyAllocated,
   OD.QtyPicked,
   OD.ShippedQty + OD.QtyPicked As 'Qty Process',
   O.C_Zip,
   O.C_State,
   Case
      when
         O.Type = 'B2S' 
      then
         'B2S' 
      else
         'Retail' 
   end as 'Type'
,
   Case
      when
         SUBSTRING ( O.ExternOrderKey, 1, 4 ) = 'YTTS' 
         and O.Notes = '' 
      then
         OD.UserDefine01 
      else
         O.Notes 
   end as 'Notes'
, O.C_contact1, O.C_Address1, O.C_Address2, O.C_Address3, O.C_Address4, 
   Case
      when
         O.Type = 'B2S' 
      then
         O.TrackingNo 
      else
         P.TrackCol01 
   end as 'Tracking'
, 
   Case
      when
         SUBSTRING ( O.ExternOrderKey, 1, 4 ) = 'YTTS' 
      THEN
         'TELES' 
      when
         SUBSTRING ( O.ExternOrderKey, 1, 4 ) = 'YVES' 
      THEN
         'B2S' 
      else
         'RETAIL' 
   end as 'Order Type'
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
      AND O.Status = '9' 
      AND O.AddDate >= {ts '2021-05-27 17:00:00.000'} 
      AND O.EditDate >= convert(varchar(10), getdate() - 1, 120) 
      and O.EditDate < convert(varchar(10), getdate(), 120) 
      AND P.AddDate >= convert(varchar(10), getdate() - 1, 120) 
      and P.AddDate < convert(varchar(10), getdate(), 120))
   )

GO