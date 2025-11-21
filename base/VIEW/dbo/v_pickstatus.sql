SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PickStatus]   
AS   
SELECT ORDERS.StorerKey,  
       ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.LoadKey,  
       ORDERS.UserDefine09 as WaveKey,  
       ORDERS.MBOLKey,  
   CASE WHEN PickingInfo.PickSlipNo IS NOT NULL THEN PickingInfo.PickSlipNo  
            ELSE PI.PickSlipNo  
       END As PickSlipNo,  
     CASE WHEN PickingInfo.ScanInDate IS NOT NULL THEN PickingInfo.ScanInDate   
          ELSE PI.ScanInDate   
       END As StartPicking,   
     CASE WHEN PickingInfo.ScanOutDate IS NOT NULL THEN PickingInfo.ScanOutDate  
        ELSE PI.ScanOutDate  
       END As EndPicking,   
     CASE WHEN PickingInfo.PickerID IS NOT NULL THEN PickingInfo.PickerID    
        ELSE PI.PickerID  
       END As PickerID   
FROM  ORDERS (NOLOCK)   
LEFT OUTER JOIN PICKHEADER DiscretePick (NOLOCK) ON (ORDERS.OrderKey = DiscretePick.OrderKey AND   
                                                    (DiscretePick.OrderKey <> '' AND DiscretePick.OrderKey IS NOT NULL)  
                                                     AND DiscretePick.Zone NOT IN ('LB','XD'))   
LEFT OUTER JOIN PickingInfo (NOLOCK) ON (PickingInfo.PickSlipNo = DiscretePick.PickHeaderKey)   
LEFT OUTER JOIN PICKHEADER BatchPick (NOLOCK) ON (ORDERS.LoadKey = BatchPick.ExternOrderkey AND    
                                                 (BatchPick.OrderKey = '' OR BatchPick.OrderKey IS NULL)  
                                              AND BatchPick.Zone NOT IN ('LB','XD'))   
LEFT OUTER JOIN PickingInfo PI (NOLOCK) ON (PI.PickSlipNo = BatchPick.PickHeaderKey)   
WHERE (PickingInfo.ScanInDate IS NOT NULL OR PI.ScanInDate IS NOT NULL)   
UNION   
SELECT ORDERS.StorerKey,  
       ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.LoadKey,  
       ORDERS.UserDefine09 as WaveKey,  
       ORDERS.MBOLKey,  
   MAX(PickingInfo.PickSlipNo)  as PickSlipNo,   
     MIN(PickingInfo.ScanInDate)  AS StartPicking,   
     MAX(PickingInfo.ScanOutDate) As EndPicking,   
     MAX(PickingInfo.PickerID) As PickerID   
FROM  ORDERS (NOLOCK)  
JOIN  RefKeyLookup Refkey (NOLOCK) ON (Refkey.Orderkey = ORDERS.Orderkey)  
JOIN  Pickinginfo (NOLOCK) ON (PickingInfo.pickslipno = Refkey.pickslipno )  
JOIN  PickHeader (NOLOCK) ON (PickingInfo.pickslipno = PickHeader.PickHeaderKey AND PickHeader.Zone In ('LB', 'XD') )  
GROUP BY ORDERS.StorerKey,  
       ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERS.LoadKey,  
       ORDERS.UserDefine09,  
       ORDERS.MBOLKey   
  
  
  
GO