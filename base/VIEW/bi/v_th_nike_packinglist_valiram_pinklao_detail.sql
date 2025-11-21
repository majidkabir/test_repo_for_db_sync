SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_PackingList_Valiram_Pinklao_Detail]
AS
SELECT DISTINCT
  CONVERT(varchar, AL1.ExternOrderKey, 102) AS DDNo,
  CONVERT(char(10), AL1.UserDefine06, 102) AS GIDate,
  CONVERT(char(10), AL1.DeliveryDate, 102) AS DeliveryDate,
  AL3.CartonNo,
  AL3.LabelNo,
  AL2.BUSR10 AS SKU,
  AL2.DESCR,
  --AL1.Status,
  SUM(AL3.Qty) AS QTY

FROM dbo.PackDetail AS AL3 WITH (NOLOCK)
JOIN dbo.SKU AS AL2 WITH (NOLOCK) ON AL3.SKU = AL2.Sku AND AL3.StorerKey = AL2.StorerKey
JOIN dbo.PackHeader AS AL4 WITH (NOLOCK) ON AL3.PickSlipNo = AL4.PickSlipNo
JOIN dbo.ORDERS AS AL1 WITH (NOLOCK) ON AL4.OrderKey = AL1.OrderKey

WHERE AL1.StorerKey = 'NIKETH'
AND AL1.Status IN ('5', '9')
AND  AL1.UserDefine06= CONVERT(varchar, GETDATE(), 102)
AND AL4.ConsigneeKey = '0005092745'

GROUP BY AL1.ExternOrderKey,
          AL1.UserDefine06,
          AL1.DeliveryDate,
         AL3.CartonNo,
         AL3.LabelNo,
         AL2.BUSR10,
         AL2.DESCR
         --AL1.Status

GO