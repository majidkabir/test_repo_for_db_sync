SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PICKSLIP]   
AS   
SELECT ORDERS.StorerKey,  
       CASE WHEN ORDERS.UserDefine08 = 'Y' THEN 'Discrete' ELSE 'Batch' End as TYPE,  
       ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.LoadKey,  
       ORDERS.UserDefine09 as WaveKey,  
       ORDERS.MBOLKey,  
       ISNULL(PickingInfo.PickSlipNo, PI.PickSlipNo) as PickSlipNo,    
     ISNULL(PickingInfo.ScanOutDate,PI.ScanOutDate) as ScanOutDate,   
     ISNULL(PickingInfo.ScanInDate, PI.ScanInDate) as ScanInDate,   
   ISNULL(PickingInfo.PickerID, PI.PickerID) as PickerID,   
   CASE WHEN PickingInfo.PickSlipNo IS NULL THEN 'Normal'   
    ELSE 'Consolidated'  
   END as PickSlipType,    
       ORDERS.DeliveryDate   
FROM  ORDERS (NOLOCK)   
LEFT OUTER JOIN PICKHEADER DiscretePick (NOLOCK) ON (ORDERS.OrderKey = DiscretePick.OrderKey AND   
                                                     DiscretePick.OrderKey <> '' AND   
                                                     DiscretePick.Zone NOT IN ('XD','LB'))   
LEFT OUTER JOIN PickingInfo (NOLOCK) ON (PickingInfo.PickSlipNo = DiscretePick.PickHeaderKey)   
LEFT OUTER JOIN PICKHEADER BatchPick (NOLOCK) ON (ORDERS.LoadKey = BatchPick.ExternOrderkey and   
                                                  BatchPick.OrderKey = '' AND   
                                                  BatchPick.Zone NOT IN ('XD','LB'))  
LEFT OUTER JOIN PickingInfo PI (NOLOCK) ON (PI.PickSlipNo = BatchPick.PickHeaderKey)  
WHERE ISNULL(PickingInfo.PickSlipNo, PI.PickSlipNo) IS NOT NULL   
  
  
  
GO