SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
CREATE VIEW [dbo].[V_PSLIP]   
AS   
SELECT PICKHEADER.PickHeaderKey  
      ,PICKHEADER.Orderkey  
      ,PICKHEADER.ExternOrderkey  
      ,PICKHEADER.Wavekey  
      ,PICKHEADER.Loadkey  
      ,PICKHEADER.ConsoOrderkey  
FROM PICKHEADER WITH (NOLOCK)   
WHERE RTRIM(PICKHEADER.Orderkey) <> ''  
UNION  
SELECT DISTINCT  
       PICKHEADER.PickHeaderKey  
      ,ORDERS.Orderkey  
      ,PICKHEADER.ExternOrderkey  
      ,PICKHEADER.Wavekey  
      ,PICKHEADER.Loadkey  
      ,PICKHEADER.ConsoOrderkey  
FROM PICKHEADER WITH (NOLOCK)   
JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.ExternOrderkey = ORDERS.Loadkey)   
WHERE RTRIM(PICKHEADER.Orderkey) = ''  
AND  NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)  
                 WHERE REFKEYLOOKUP.PickSlipNo = PickHeaderKey AND REFKEYLOOKUP.Loadkey = PICKHEADER.ExternORderkey)   
  
UNION  
SELECT DISTINCT   
       PICKHEADER.PickHeaderKey  
      ,REFKEYLOOKUP.Orderkey  
      ,PICKHEADER.ExternOrderkey  
      ,PICKHEADER.Wavekey  
      ,PICKHEADER.Loadkey  
      ,PICKHEADER.ConsoOrderkey  
FROM PICKHEADER   WITH (NOLOCK)   
JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKHEADER.PickHeaderKey = REFKEYLOOKUP.PickSlipNo)   
                                AND(PICKHEADER.ExternOrderkey = REFKEYLOOKUP.Loadkey)  
JOIN PICKDETAIL   WITH (NOLOCK) ON (REFKEYLOOKUP.PickdetailKey = PICKDETAIL.PickDetailKey)  
WHERE RTRIM(PICKHEADER.Orderkey) = ''  
GO