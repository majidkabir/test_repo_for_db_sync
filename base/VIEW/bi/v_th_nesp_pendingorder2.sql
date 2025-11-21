SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_PendingOrder2]
AS
SELECT
   AL1.ExternOrderKey,
   AL1.Status,
   AL2.Sku,
   AL4.OrderDate,
   Sum (AL1.ShippedQty) AS 'TotalShippedQty',
   AL4.DeliveryDate,
   convert(varchar, AL1.EditDate, 103) AS 'Editdate',
   Month(AL1.EditDate) AS 'Month',
   AL1.StorerKey,
   AL1.Facility,
   AL3.CaseCnt,
   AL2.DESCR,
   AL4.ConsigneeKey,
   AL4.C_Company,
   AL1.OrderKey,
   AL1.OriginalQty,
   AL1.OpenQty,
   AL4.DocType,
   AL4.Type,
   AL4.UserDefine02

FROM dbo.ORDERDETAIL AL1 WITH (NOLOCK)
JOIN dbo.SKU AL2 WITH (NOLOCK)  ON AL1.Sku = AL2.Sku AND AL1.StorerKey = AL2.StorerKey
JOIN dbo.PACK AL3 WITH (NOLOCK) ON AL2.PACKKey = AL3.PackKey
JOIN dbo.ORDERS AL4  WITH (NOLOCK) ON  AL1.OrderKey = AL4.OrderKey

WHERE
AL1.StorerKey = 'NESP'
AND AL1.Status NOT IN ('9','CANC')
AND AL4.Facility = 'BDC01'

GROUP BY
   AL1.ExternOrderKey,
   AL1.Status,
   AL2.Sku,
   AL4.OrderDate,
   AL4.DeliveryDate,
   convert(varchar, AL1.EditDate, 103),
   Month(AL1.EditDate),
   AL1.StorerKey,
   AL1.Facility,
   AL3.CaseCnt,
   AL2.DESCR,
   AL4.ConsigneeKey,
   AL4.C_Company,
   AL1.OrderKey,
   AL1.OriginalQty,
   AL1.OpenQty,
   AL4.DocType,
   AL4.Type,
   AL4.UserDefine02

GO