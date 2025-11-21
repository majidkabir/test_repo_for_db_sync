SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_Canceled_Order]
AS
SELECT
  AL1.EditDate as Deleted_Date,
  AL1.UserDefine06 as [GI Date],
  AL1.DeliveryDate,
  AL1.OrderKey,
  AL1.ExternOrderKey,
  AL1.ConsigneeKey,
  AL1.C_Company,
  AL2.Sku,
  AL3.DESCR,
  SUM(AL2.OriginalQty) as OrderQty,
  SUM(AL2.FreeGoodQty) as RTV_Allocate

FROM dbo.ORDERS AS AL1 WITH (NOLOCK)
INNER JOIN dbo.ORDERDETAIL AS AL2 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey AND AL1.StorerKey = AL2.StorerKey
INNER JOIN dbo.SKU AS AL3 WITH (NOLOCK) ON AL2.Sku = AL3.Sku AND AL2.StorerKey = AL3.StorerKey

WHERE AL1.StorerKey = 'NIKETH'
AND AL1.Status = 'CANC'
AND AL1.EditDate = CONVERT(date, GETDATE() - 1)
AND AL2.FreeGoodQty <> 0

GROUP BY AL1.EditDate,
         AL1.UserDefine06,
         AL1.DeliveryDate,
         AL1.OrderKey,
         AL1.ExternOrderKey,
         AL1.ConsigneeKey,
         AL1.C_Company,
         AL2.Sku,
         AL3.DESCR


GO