SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_JDsport_Order_Status_Daily]
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
  --SUM(AL2.OriginalQty) as Unit,
  AL2.OriginalQty,
  AL3.DESCR,
  AL2.ShippedQty,
  AL2.QtyPicked,
  AL1.OrderKey as OrderNo,
  AL1.ExternPOKey as [Nike PO],
  AL3.SKUGROUP as Division,
  MAX(AL4.CartonNo) as Carton,
  AL2.Sku,
  LEFT(AL3.BUSR10, 10) as Material,
  SUBSTRING(AL3.BUSR10, 12, 200) as SIZE,
  AL3.ALTSKU as [SKU Barcode]
  --MAX(CONVERT(char(100), AL1.Notes))as ORDNote,
  --AL1.LoadKey,
  --AL1.InvoiceNo,
  --AL1.ExternOrderKey,
  --AL2.UserDefine04 as SalesOrderNo
 FROM dbo.ORDERDETAIL AS AL2 WITH (NOLOCK)
JOIN dbo.ORDERS AS AL1  WITH (NOLOCK) ON AL2.OrderKey = AL1.OrderKey AND AL2.StorerKey = AL1.StorerKey
JOIN dbo.SKU AS AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.StorerKey AND AL2.Sku = AL3.Sku
FULL OUTER JOIN dbo.PackHeader AS AL5 WITH (NOLOCK) ON AL5.StorerKey = AL1.StorerKey AND AL5.OrderKey = AL1.OrderKey
FULL OUTER JOIN dbo.PackDetail AS AL4 WITH (NOLOCK) ON AL5.PickSlipNo = AL4.PickSlipNo

WHERE
AL1.StorerKey = 'NIKETH'
AND  AL1.DeliveryDate >= CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0))
AND AL1.DeliveryDate < CONVERT(date, DATEADD(D, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)))
AND AL1.ConsigneeKey IN ('0005085214', '0005086004', '0005086041', '0005086150', '0005089459', '0005089460', '0005091865', '0005093450', '0005093451')
AND AL1.Status <> 'CANC'

GROUP BY
         AL1.Status,
         --AL2.UserDefine04,
         AL1.ExternOrderKey,
         AL1.C_Company,
         AL1.DeliveryDate,
         --AL1.LoadKey,
         --AL1.InvoiceNo,
         AL2.OriginalQty,
         AL3.DESCR,
         AL2.ShippedQty,
         AL2.QtyPicked,
         AL1.OrderKey,
         AL1.ExternPOKey,
         AL3.SKUGROUP,
         AL4.CartonNo,
         --AL1.ExternOrderKey,
         AL2.Sku,
         AL3.BUSR10,
         AL3.ALTSKU
         --AL1.ExternPOKey

GO