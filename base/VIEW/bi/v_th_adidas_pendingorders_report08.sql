SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_PendingOrders_Report08]
AS
SELECT
  AL1.StorerKey,
  AL1.Facility,
  OrderDate = CONVERT(date, AL1.OrderDate),
  AL2.OrderKey,
  AL1.ExternOrderKey,
  Consignee = AL1.ConsigneeKey + ' ' + AL1.C_contact1,
  AL1.C_Company,
  OriginalQty = SUM(AL2.OriginalQty),
  QtyAllocated = SUM(AL2.QtyAllocated),
  QtyPicked = SUM(AL2.QtyPicked),
  ShippedQty = SUM(AL2.ShippedQty),
  CASE
    WHEN AL1.Status = '2' THEN '2-Allocated'
    WHEN AL1.Status = '0' THEN '0-Open'
    WHEN AL1.Status = '3' THEN '3-Picking in Process'
    WHEN AL1.Status = '5' THEN '5-Picked'
    WHEN AL1.Status = '9' THEN '9-Shipped'
    WHEN AL1.Status = 'CANC' THEN 'Cancelled'
    ELSE AL1.Status
  END AS Status,
  ISNULL((SELECT
    MAX(v_packheader.status)
  FROM v_packheader
  WHERE v_packheader.orderkey =
  (AL2.OrderKey)), 0)as statusOrder,
  AL1.Notes2,
  AL1.TrackingNo,
  AL1.UserDefine09,
  AL1.UserDefine05,
  AL4.ShipDate,
  AL1.AddDate,
  AL3.SKUGROUP,
  AL3.CLASS,
  AL3.Style,
  AL3.Size,
  AL1.C_Address1,
  CASE
    WHEN AL1.ExternOrderKey LIKE '%ATH%' THEN 'E-Com'
    ELSE 'STO'
  END AS Orders
FROM dbo.V_ORDERDETAIL AL2  WITH (NOLOCK)
JOIN dbo.V_SKU AL3 WITH (NOLOCK) ON AL3.StorerKey = AL2.StorerKey AND AL3.Sku = AL2.Sku
JOIN dbo.V_ORDERS AL1 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey AND AL1.StorerKey = AL2.StorerKey
LEFT OUTER JOIN dbo.V_MBOL AL4
       ON AL4.MbolKey = AL1.MBOLKey
WHERE
	AL1.StorerKey = 'ADIDAS'

GROUP BY AL1.StorerKey,
         AL1.Facility,
         CONVERT(date, AL1.OrderDate),
         AL2.OrderKey,
         AL1.ExternOrderKey,
         AL1.ConsigneeKey + ' ' + AL1.C_contact1,
         AL1.C_Company,
         CASE
           WHEN AL1.Status = '2' THEN '2-Allocated'
           WHEN AL1.Status = '0' THEN '0-Open'
           WHEN AL1.Status = '3' THEN '3-Picking in Process'
           WHEN AL1.Status = '5' THEN '5-Picked'
           WHEN AL1.Status = '9' THEN '9-Shipped'
           WHEN AL1.Status = 'CANC' THEN 'Cancelled'
           ELSE AL1.Status
         END ,
         AL1.Notes2,
         AL1.TrackingNo,
         AL1.UserDefine09,
         AL1.UserDefine05,
         AL4.ShipDate,
         AL1.AddDate,
         AL3.SKUGROUP,
         AL3.CLASS,
         AL3.Style,
         AL3.Size,
         AL1.C_Address1,
         CASE
           WHEN AL1.ExternOrderKey LIKE '%ATH%' THEN 'E-Com'
           ELSE 'STO'
         END

GO