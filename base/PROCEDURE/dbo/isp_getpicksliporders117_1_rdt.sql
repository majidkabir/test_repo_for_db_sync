SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetPickSlipOrders117_1_rdt                          */  
/* Creation Date: 04-Feb-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-16311 - HM India - Outbound Pick Slip Report            */  
/*        : Copy from isp_GetPickSlipWave24_1                           */  
/*                                                                      */
/* Called By: r_dw_print_pickorder117_1_rdt                             */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 04-Feb-2021 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/ 
CREATE PROC [dbo].[isp_GetPickSlipOrders117_1_rdt]    
            @c_Loadkey        NVARCHAR(10)    
         ,  @c_PickSlipNo     NVARCHAR(10)    
         ,  @c_Zone           NVARCHAR(10)    
         ,  @c_PrintedFlag    NCHAR(1)    
         ,  @n_NoOfSku        INT    
         ,  @n_NoOfPickLines  INT    
         ,  @c_ordselectkey   NVARCHAR(20)    
         ,  @c_colorcode      NVARCHAR(20)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT    
         , @n_Continue        INT    
    
         , @n_WaveSeqOfDay    INT    
         , @dt_Adddate        DATETIME    
         , @d_Adddate         DATETIME    
    
         , @c_Storerkey       NVARCHAR(15) 
         , @c_ordermode       NVARCHAR(30)
         , @n_TTLSeq          INT          
         , @n_SumQtyPerLoad   INT
         , @n_SumQtyPerZone   INT
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1    
    
   SELECT TOP 1 @dt_Adddate  = L.EditDate
               ,@c_Storerkey = OH.Storerkey                         
   FROM LOADPLAN         L WITH (NOLOCK)    
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (L.Loadkey = LPD.Loadkey)     
   JOIN ORDERS          OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)     
   WHERE L.Loadkey = @c_Loadkey
       
   SET @d_Adddate = CONVERT (DATETIME, CONVERT(NVARCHAR(10), @dt_Adddate, 112))    
         
   IF OBJECT_ID('tempdb..#TMP_LPORD','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TMP_LPORD;      
   END           
      
   CREATE TABLE #TMP_LPORD        
      (  Loadkey  NVARCHAR(10) NOT NULL   DEFAULT ('')        
      ,  Orderkey NVARCHAR(10) NOT NULL   DEFAULT ('')          
      ,  OpenQty  INT          NOT NULL   DEFAULT (0)        
      ,  EditDate DATETIME     NULL               
      )          
                 
   IF OBJECT_ID('tempdb..#TMP_ALLLoad','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TMP_ALLLoad;      
   END           
       
   CREATE TABLE #TMP_ALLLoad        
      (  Loadkey  NVARCHAR(10) NOT NULL   DEFAULT ('')        
      ,  AddDate  DATETIME     NULL               
      ,  EditDate DATETIME     NULL               
      )          
          
   CREATE INDEX IDX_Lkey     ON #TMP_ALLLoad (Loadkey)    
   CREATE INDEX IDX_LAdddate ON #TMP_ALLLoad (AddDate)    
             
   INSERT INTO #TMP_ALLLoad (Loadkey, AddDate, EditDate)    
   SELECT TOP 500 L.Loadkey, L.AddDate, L.EditDate    
   FROM LOADPLAN L (NOLOCK)    
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON L.Loadkey = LPD.Loadkey    
   JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey    
   WHERE O.Storerkey = @c_Storerkey    
   AND O.[Status] <> '9'  
   AND L.[Status] <> '9'            
   --AND   W.TMReleaseFlag = 'Y'  
   GROUP BY L.Loadkey, L.AddDate, L.EditDate  
   ORDER BY L.AddDate DESC, L.Loadkey DESC       
    
   INSERT INTO #TMP_LPORD        
      (  Loadkey        
      ,  Orderkey        
      ,  OpenQty        
      ,  EditDate        
      )        
   SELECT L.Loadkey        
         ,OD.Orderkey         
         ,OpenQty= ISNULL(SUM(OD.OpenQty),0)          
         ,L.EditDate          
   FROM #TMP_ALLLoad L     
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Loadkey  = L.Loadkey         
   JOIN ORDERDETAIL     OD WITH (NOLOCK) ON LPD.Orderkey = OD.Orderkey        
   WHERE L.AddDate BETWEEN @d_Adddate AND DATEADD(d, 1, @d_Adddate)          
   GROUP BY L.Loadkey, L.EditDate, OD.Orderkey       
   ORDER BY L.Loadkey, OD.Orderkey        
   
   SELECT MaxOrderQty= CASE WHEN MAX(L.OpenQty) = 1 THEN 'Single' ELSE 'Multi' END          
         ,L.Loadkey          
         ,ReleaseDate = L.EditDate       
   INTO #TMP_Load          
   FROM #TMP_LPORD L              
   GROUP BY L.Loadkey, L.EditDate, L.EditDate          
       
   SELECT LoadSeqOfDay  = ROW_NUMBER() OVER (PARTITION BY  L.MaxOrderQty ORDER BY L.Loadkey)    
         ,ordermode = L.MaxOrderQty                                 
         ,Loadkey = L.Loadkey    
         ,DateRelease = L.ReleaseDate    
   INTO   #TMP_LoadSeq         
   FROM #TMP_Load L                                                      
       
   SET @n_WaveSeqOfDay = 0    
   SET @c_ordermode = ''    
       
   SELECT @n_WaveSeqOfDay = L.LoadSeqOfDay    
        , @c_ordermode    = L.ordermode                               
   FROM #TMP_LoadSeq L       
   WHERE Loadkey = @c_Loadkey    
            
   SET @n_TTLSeq = 1    
       
   SELECT @n_TTLSeq = COUNT(1)   
   FROM #TMP_LoadSeq    
   WHERE DateRelease <= @dt_Adddate    

   SELECT @n_SumQtyPerLoad = SUM(PD.Qty)
   FROM PICKDETAIL PD   WITH (NOLOCK)        
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)     
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey) 
   WHERE PH.Loadkey = @c_Loadkey

   SELECT @n_SumQtyPerZone = SUM(PD.Qty)
   FROM PICKDETAIL PD   WITH (NOLOCK)        
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)     
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey) 
   WHERE PH.Loadkey = @c_Loadkey AND PH.Pickheaderkey = @c_PickSlipNo
   AND LOC.Putawayzone = @c_Zone

   SELECT PH.Loadkey    
         ,AddDate = @dt_Adddate     
         ,@c_ordermode AS ordermode 
         ,LoadSeqOfDay = CONVERT( NVARCHAR(10), @n_WaveSeqOfDay )    
         ,PH.PickHeaderkey    
         ,LOC.PutawayZone
         ,@c_Printedflag      
         ,PD.Storerkey    
         ,PD.Loc    
         ,PD.ID    
         ,Style   = SUBSTRING(SKU.Sku,3,6)     
         ,Color   = SUBSTRING(SKU.Sku,9,3)    
         ,Size    = LTRIM(SUBSTRING(SKU.Sku,12,5))    
         ,SkuDescr= ISNULL(MIN(SKU.Descr),0)    
         ,AltSku  = ISNULL(RTRIM(SKU.AltSku), '')    
         ,SKU.SkuGroup    
         ,Qty    = ISNULL(SUM(PD.Qty),0)    
         ,NoOfSku= @n_NoOfSku --COUNT(DISTINCT PD.Sku)    
         ,NoOfPickLines= @n_NoOfPickLines --COUNT(DISTINCT PD.Loc + PD.ID)    
         ,TTLSeq  = @n_TTLSeq                                        
         ,logicalloc = loc.logicallocation                          
         ,OrdSelectkey = @c_ordselectkey          
         ,Colorcode = @c_colorcode          
         ,SumQtyPerLoad = @n_SumQtyPerLoad
         ,SumQtyPerZone = @n_SumQtyPerZone
         ,PD.Sku
   FROM PICKDETAIL PD   WITH (NOLOCK)     
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)       
   JOIN SKU        SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)    
                                      AND(PD.Sku = SKU.Sku)    
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)    
   JOIN (SELECT OD.Orderkey, Openqty = SUM(OD.OpenQty) FROM ORDERS OH WITH (NOLOCK)    
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)     
         JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = OH.OrderKey)
         WHERE LPD.Loadkey = @c_Loadkey    
         GROUP BY OD.Orderkey) ODSUM ON (ODSUM.Orderkey = PD.Orderkey)    
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)    
   WHERE PH.PickHeaderKey = @c_PickSlipNo    
   AND   LOC.PutawayZone = @c_Zone                            
   AND   PD.Status < '5'    
   GROUP BY PH.Loadkey    
         ,  PH.PickHeaderkey    
         ,  LOC.PutawayZone                                    
         ,  PD.Storerkey    
         ,  PD.Loc    
         ,  PD.ID    
         ,  SUBSTRING(SKU.Sku,3,6)    
         ,  SUBSTRING(SKU.Sku,9,3)    
         ,  LTRIM(SUBSTRING(SKU.Sku,12,5))    
         ,  ISNULL(RTRIM(SKU.AltSku), '')    
         ,  SKU.SkuGroup    
         ,  loc.logicallocation       
         ,  PD.Sku           
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '')  
         ,  LOC.PutawayZone                      
         ,  loc.logicallocation                  
         ,  PD.Loc    
         ,  Style    
         ,  Color    
         ,  Size  
         ,  PD.Sku   
    
END -- procedure 

GO