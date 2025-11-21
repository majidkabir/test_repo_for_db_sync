SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
  
  
CREATE VIEW [dbo].[V_OrderStatus]  
AS  
SELECT ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.Adddate,   
       ORDERS.OrderDate as OW_OrderDate,  
       ORDERS.DeliveryDate as OW_DeliveryDate,  
       MIN(LOADPLAN.lpuserdefdate01) as ActualDeliveryDate,  
       CASE ORDERS.UserDefine08 WHEN 'N' Then NULL  
                         WHEN 'Y' Then MIN(WaveDetail.AddDate)  
       END as WavePlanDate,  
       MIN(LoadPlanDetail.AddDate) as LoadplanDate,  
       MIN(PickDetail.AddDate) as AllocationDate,  
       MIN(PickingInfo.ScanOutDate) as ScanOutDate,  
       MIN(MBOL.EditDate) as Shipdate  
FROM  ORDERS (NOLOCK)  
LEFT OUTER JOIN PickDetail (NOLOCK) ON (ORDERS.OrderKey = PickDetail.OrderKey)  
LEFT OUTER JOIN MBOL (NOLOCK) ON (ORDERS.MBOLKEY = MBOL.MBOLKey)  
LEFT OUTER JOIN LOADPLAN (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)  
LEFT OUTER JOIN LOADPLANDETAIL (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)  
LEFT OUTER JOIN WAVEDETAIL (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)  
LEFT OUTER JOIN PICKHEADER DiscretePick (NOLOCK) ON (ORDERS.OrderKey = DiscretePick.OrderKey and DiscretePick.Zone = '8')  
LEFT OUTER JOIN PickingInfo (NOLOCK) ON (PickingInfo.PickSlipNo = DiscretePick.PickHeaderKey)  
JOIN StorerConfig (NOLOCK) ON (ORDERS.StorerKey = StorerConfig.StorerKey and ConfigKey = 'OWITF' AND sValue = '1')  
WHERE ORDERS.AddDate > '01-May-2002'  
AND   ORDERS.UserDefine08 = 'Y'  
GROUP BY   
ORDERS.OrderKey,   
ORDERS.ExternOrderKey,   
ORDERS.Adddate,   
ORDERS.OrderDate,  
ORDERS.DeliveryDate,  
ORDERS.UserDefine08  
UNION ALL  
SELECT ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.Adddate,   
       ORDERS.OrderDate as OW_OrderDate,  
       ORDERS.DeliveryDate as OW_DeliveryDate,  
       MIN(LOADPLAN.lpuserdefdate01) as ActualDeliveryDate,  
       NULL as WavePlanDate,  
       MIN(LoadPlanDetail.AddDate) as LoadplanDate,  
       MIN(PickDetail.AddDate) as AllocationDate,  
       MIN(PickingInfo.ScanOutDate) as ScanOutDate,  
       MIN(MBOL.EditDate) as Shipdate  
FROM  ORDERS (NOLOCK)  
LEFT OUTER JOIN PickDetail (NOLOCK) ON (ORDERS.OrderKey = PickDetail.OrderKey)  
LEFT OUTER JOIN MBOL (NOLOCK) ON (ORDERS.MBOLKEY = MBOL.MBOLKey)  
LEFT OUTER JOIN LOADPLAN (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)  
LEFT OUTER JOIN LOADPLANDETAIL (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)  
LEFT OUTER JOIN PICKHEADER BatchPick (NOLOCK) ON (ORDERS.LoadKey = BatchPick.ExternOrderKey and BatchPick.Zone IN ('7','9'))  
LEFT OUTER JOIN PickingInfo (NOLOCK) ON (PickingInfo.PickSlipNo = BatchPick.PickHeaderKey)  
JOIN StorerConfig (NOLOCK) ON (ORDERS.StorerKey = StorerConfig.StorerKey and ConfigKey = 'OWITF' AND sValue = '1')  
WHERE ORDERS.AddDate > '01-May-2002'  
AND   ORDERS.UserDefine08 = 'N'  
GROUP BY   
ORDERS.OrderKey,   
ORDERS.ExternOrderKey,   
ORDERS.Adddate,   
ORDERS.OrderDate,  
ORDERS.DeliveryDate,  
ORDERS.UserDefine08  
--ORDER By ORDERS.AddDate, ORDERS.ExternOrderKey  
  
  
  
  
  
GO