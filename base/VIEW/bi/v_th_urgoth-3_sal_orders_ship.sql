SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_URGOTH-3_Sal_Orders_Ship]
AS
SELECT DISTINCT
   AL1.OrderKey,
   AL1.StorerKey,
   AL1.ExternOrderKey,
   AL1.OrderDate,
   AL1.DeliveryDate,
   AL1.ConsigneeKey,
   AL1.C_Company,
   AL2.Sku,
   AL3.DESCR,
   AL2.ShippedQty,
   AL1.Status,
   AL1.AddDate,
   AL1.EditDate,
   AL5.Lottable01,
   AL5.Lottable02,
   AL5.Lottable03,
   AL5.Lottable04,
   AL5.Lottable05,
   AL4.Loc,
   AL4.Qty,
   AL1.Notes

FROM dbo.V_PICKDETAIL AL4 WITH (NOLOCK)
LEFT OUTER JOIN   dbo.V_LOTATTRIBUTE AL5 WITH (NOLOCK) ON AL4.Storerkey = AL5.StorerKey  AND AL4.Sku = AL5.Sku   AND AL4.Lot = AL5.Lot
JOIN dbo.V_ORDERDETAIL AL2 WITH (NOLOCK) ON AL2.StorerKey = AL4.Storerkey  AND AL2.OrderKey = AL4.OrderKey AND AL2.Sku = AL4.Sku AND AL2.OrderLineNumber = AL4.OrderLineNumber
JOIN dbo.V_SKU AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.StorerKey and AL2.Sku = AL3.Sku
JOIN dbo.V_ORDERS AL1 WITH (NOLOCK) ON AL1.OrderKey = AL2.OrderKey AND AL1.StorerKey = AL2.StorerKey

WHERE AL1.StorerKey = 'URGOTH'
AND AL1.EditDate  >= convert(varchar, getdate() - 1, 112)
AND AL1.EditDate < convert(varchar, getdate(), 112)

GO