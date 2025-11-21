SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   VIEW [BI].[V_TH_FBT_PendingOrder(Less than 15Days)] AS 
SELECT
   O.Facility,
   convert(datetime, convert(char(25), O.AddDate, 120)) AS 'Interface to EXE',
   O.ExternOrderKey,
   CONVERT(VARCHAR(10), O.OrderDate, 120) AS 'OrderDate',
   convert(char(10), O.DeliveryDate, 120) AS 'DeliveryDate',
   O.C_Company,
   O.ConsigneeKey,
   case
      when
         O.Status = '9' 
      then
         Sum(OD.ShippedQty / 
         case
            when
               P.CaseCnt = 0 
            then
               1 
            else
               P.CaseCnt 
         end
) 
         else
            Sum(OD.OriginalQty / 
            case
               when
                  P.CaseCnt = 0 
               then
                  1 
               else
                  P.CaseCnt 
            end
) 
   end AS 'CaseQty'
, C.Description AS 'Brand', 
   case
      when
         O.Status = '9' 
      then
         Sum(OD.ShippedQty) 
      else
         Sum(OD.OriginalQty) 
   end AS 'BGQty'
, O.Status, OD.Sku, S.DESCR, O.AddDate, DATEDIFF ( dy, O.AddDate, getdate() ) AS 'PendingDay'
FROM dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
		AND O.StorerKey = OD.StorerKey
JOIN dbo.SKU S with (nolock) ON OD.Sku = S.Sku
		AND OD.StorerKey = S.StorerKey 
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey 
JOIN dbo.CODELKUP C with (nolock) ON S.SKUGROUP = C.Code 
WHERE O.Facility = 'BDC02' 
AND O.StorerKey = 'FBT' 
AND O.Status < '9'
GROUP BY
   O.Facility, convert(datetime, convert(char(25), O.AddDate, 120)), O.ExternOrderKey, CONVERT(VARCHAR(10), O.OrderDate, 120), convert(char(10), O.DeliveryDate, 120), O.C_Company, O.ConsigneeKey, C.Description, O.Status, OD.Sku, S.DESCR, O.AddDate, DATEDIFF ( dy, O.AddDate, getdate() ) 
--ORDER BY
--   14, 11
--   AddDate,Status

GO