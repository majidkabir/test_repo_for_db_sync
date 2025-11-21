SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18818
/* Date         Author      Ver.  Purposes									                  */
/* 21-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_NIKE_PackingList_Valiram_SiamCenter_Summary]
AS
SELECT
  AL1.UserDefine06 as GIDate,
  MAX(AL3.CartonNo) as TotalCarton,
  AL1.ExternOrderKey as [DD No],
  SUM(AL3.Qty) as TotalQty,
  AL1.DeliveryDate

FROM dbo.PackDetail AS AL3 WITH (NOLOCK)
JOIN dbo.PackHeader AS AL2 WITH (NOLOCK) ON AL3.PickSlipNo = AL2.PickSlipNo
JOIN dbo.ORDERS AS AL1 WITH (NOLOCK) ON AL2.OrderKey = AL1.OrderKey


WHERE
 AL1.UserDefine06 = CONVERT(varchar, GETDATE(), 102)
AND AL1.Status IN ('5', '9')
AND AL2.ConsigneeKey = '0005091445'
AND AL3.StorerKey = 'NIKETH'
GROUP BY AL1.UserDefine06,
         AL3.CartonNo,
         AL1.ExternOrderKey,
         AL1.DeliveryDate

GO