SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_Unilivery_SHIP_MONTHLY]
AS
SELECT
  AL2.StorerKey,
  AL1.DeliveryDate,
  AL1.OrderKey,
  AL1.ExternOrderKey,
  AL2.OrderLineNumber,
  AL2.Sku,
  AL2.OriginalQty,
  AL2.QtyPicked,
  AL2.ShippedQty,
  AL1.Status

FROM dbo.ORDERS AL1 WITH (NOLOCK)
JOIN dbo.ORDERDETAIL AL2 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey --AND AL1.StorerKey =AL2.StorerKey

WHERE AL2.StorerKey = '06700'
AND AL1.DeliveryDate>= DATEADD(dd, 0, DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 1, 0))
AND AL1.DeliveryDate< DATEADD(dd, 0, DATEADD(mm, DATEDIFF(mm, 0, GETDATE()), 0))
AND AL1.Facility IN ('619', '619EP')


GO