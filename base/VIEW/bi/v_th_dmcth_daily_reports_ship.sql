SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DMCTH_Daily_Reports_Ship] AS
SELECT
   O.StorerKey,
   O.Facility,
   O.OrderKey,
   OD.Status,
   O.DeliveryDate,
   OD.EditDate,
   O.ExternOrderKey,
   O.ConsigneeKey,
   O.C_Company,
   S.Sku,
   S.DESCR,
   OD.Lottable01,
   OD.Lottable02,
   OD.Lottable04,
   OD.Lottable03,
   OD.Lottable05,
   P.PackUOM3,
   P.CaseCnt,
   OD.ShippedQty

FROM dbo.ORDERS O with (nolock)
LEFT OUTER JOIN dbo.ORDERDETAIL OD with (nolock) ON O.StorerKey = OD.StorerKey AND O.OrderKey = OD.OrderKey
LEFT OUTER JOIN dbo.SKU S with (nolock) ON OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku
LEFT OUTER JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey

WHERE O.StorerKey = 'DMCTH'
AND  O.EditDate = convert(date, getdate() - 1)

GO