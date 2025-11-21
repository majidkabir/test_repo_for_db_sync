SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_OUTBOUND]
AS
SELECT
  CONVERT(date, AL1.AddDate) as AddDate,
  AL1.ExternOrderKey,
  AL2.Sku,
  AL3.DESCR,
  AL1.ConsigneeKey,
  AL1.C_Company,
  AL1.Status,
  totalQTY = SUM(AL2.OriginalQty),
  AL1.EditDate,
  AL1.DeliveryDate,
  AL2.OriginalQty,
  AL2.OpenQty,
  AL2.QtyPreAllocated,
  AL2.QtyAllocated,
  AL2.QtyPicked,
  AL2.ShippedQty,
  AL1.StorerKey

FROM dbo.ORDERS AL1 WITH (NOLOCK)
LEFT JOIN dbo.ORDERDETAIL AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.OrderKey = AL2.OrderKey
JOIN dbo.SKU AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.StorerKey AND AL2.Sku = AL3.Sku

WHERE AL1.StorerKey IN ('06700', '06701')
AND (NOT AL1.Status = 'CANC')
AND  AL1.AddDate >= CONVERT (DATE,DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))
AND  AL1.AddDate <= CONVERT (DATE,DATEADD (DD, 1,GETDATE()))

GROUP BY
CONVERT(date, AL1.AddDate),
 AL1.ExternOrderKey,
 AL2.Sku,
 AL3.DESCR,
 AL1.ConsigneeKey,
 AL1.C_Company,
 AL1.Status,
 AL1.EditDate,
 AL1.DeliveryDate,
 AL2.OriginalQty,
 AL2.OpenQty,
 AL2.QtyPreAllocated,
 AL2.QtyAllocated,
 AL2.QtyPicked,
 AL2.ShippedQty,
 AL1.StorerKey


GO