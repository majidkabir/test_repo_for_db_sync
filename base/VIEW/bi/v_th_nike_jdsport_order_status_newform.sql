SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_JDsport_Order_Status_NewForm]
AS
SELECT DISTINCT
  CASE
    WHEN AL1.Status = '9' THEN '9-Shipped'
    WHEN AL1.Status = '5' THEN '5-Picked'
    WHEN AL1.Status = '3' THEN '3-In Process'
    WHEN AL1.Status = '2' THEN '2-Fully'
    WHEN AL1.Status = '1' THEN '1-Partial Allocated'
    WHEN AL1.Status = '0' THEN '0-Open'
    ELSE (AL1.Status)
  END as [OrderStatus],

  AL1.ExternOrderKey as [Nike DD No.],
  AL1.C_Company as Customer_Name,
  CONVERT(char(10), AL1.DeliveryDate, 120) as DeliveryDate,
  AL1.OrderKey as OrderNo,
  AL1.ExternPOKey as [Nike PO],
  AL3.SKUGROUP as Division,
  AL3.DESCR,
  LEFT(AL3.BUSR10, 10) as Material,
  --SUM(AL2.OriginalQty) as Unit,
  AL2.OriginalQty,
  AL2.ShippedQty,
  AL2.QtyPicked,
  AL4.CustomerGroupName

FROM dbo.ORDERS AS AL1 WITH (NOLOCK)
JOIN dbo.ORDERDETAIL AS AL2 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey AND AL1.StorerKey = AL2.StorerKey
JOIN dbo.SKU AS AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.StorerKey AND AL2.Sku = AL3.Sku
LEFT JOIN dbo.STORER AS AL4 WITH (NOLOCK) ON AL1.ConsigneeKey= AL4.StorerKey

WHERE AL1.StorerKey = 'NIKETH'
AND  AL1.DeliveryDate >= CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0))
AND AL1.DeliveryDate < CONVERT(date, DATEADD(D, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)))
AND AL1.Status <> 'CANC'

GROUP BY AL1.Status,
         AL1.ExternOrderKey,
         AL1.C_Company,
         AL1.DeliveryDate,
         AL1.OrderKey,
         AL1.ExternPOKey,
         AL3.SKUGROUP,
         AL3.DESCR,
         --AL1.ExternOrderKey,
         --AL2.Sku,
         AL3.BUSR10,
         AL2.OriginalQty,
         AL2.ShippedQty,
         AL2.QtyPicked,
         AL4.CustomerGroupName

GO