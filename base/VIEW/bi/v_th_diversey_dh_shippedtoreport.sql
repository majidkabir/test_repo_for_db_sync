SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_DH_ShippedToReport]
AS
SELECT
  AL1.ExternOrderKey,
  AL2.OrderLineNumber,
  AL2.Sku,
  AL3.DESCR,
  ShippedQty = SUM(AL2.ShippedQty),
  AL1.C_Company,
  AL2.UOM,
  AL1.ConsigneeKey,
  AL2.ExternLineNo,
  AL1.Status,
  AL1.C_Address1,
  AL1.C_Address2,
  AL1.Route,
  AL1.C_City,
  AL1.C_Address3,
  AL1.EditDate,
  AL1.DeliveryDate,
  AL2.OriginalQty,
  AL2.AdjustedQty,
  AL2.QtyPreAllocated,
  AL2.QtyAllocated,
  AL2.QtyPicked,
  AL3.STDGROSSWGT

FROM dbo.ORDERS AL1 WITH (NOLOCK)
JOIN dbo.ORDERDETAIL AL2 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey
JOIN dbo.SKU AL3 WITH (NOLOCK) ON  AL2.StorerKey = AL3.StorerKey AND AL2.Sku = AL3.Sku

WHERE AL1.StorerKey IN ('06700', '06700N', '06701')
AND AL1.Status IN ('1', '2', '3', '5', '9')
AND AL1.DeliveryDate > GETDATE()

GROUP BY AL1.ExternOrderKey,
         AL2.OrderLineNumber,
         AL2.Sku,
         AL3.DESCR,
         AL1.C_Company,
         AL2.UOM,
         AL1.ConsigneeKey,
         AL2.ExternLineNo,
         AL1.Status,
         AL1.C_Address1,
         AL1.C_Address2,
         AL1.Route,
         AL1.C_City,
         AL1.C_Address3,
         AL1.EditDate,
         AL1.DeliveryDate,
         AL2.OriginalQty,
         AL2.AdjustedQty,
         AL2.QtyPreAllocated,
         AL2.QtyAllocated,
         AL2.QtyPicked,
         AL3.STDGROSSWGT


GO