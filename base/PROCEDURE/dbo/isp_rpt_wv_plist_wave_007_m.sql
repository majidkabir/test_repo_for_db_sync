SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_007_M                        */
/* Creation Date: 16-Jun-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19999 - Migrate WMS report to Logi Report               */
/*          r_dw_print_wave_pickslip_19 (KR)                            */
/*          Convert from isp_GetPickSlipWave19_M                        */
/*                                                                      */
/* Called By: RPT_WV_PLIST_WAVE_007_M                                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 16-Jun-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 11-JUL-2023  CSCHONG  1.1  WMS-22413 add new field (CS01)            */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_007_M]
              @c_Wavekey_type   NVARCHAR(10)          --CS01 S
         --,  @c_PickSlipNo     NVARCHAR(10)         
         --,  @c_Zone           NVARCHAR(10)  
         --,  @c_PrintedFlag    NCHAR(1)  
         --,  @n_NoOfSku        INT  
         --,  @n_NoOfPickLines  INT                    --CS01 E

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

        --CS01 S
         ,  @c_PickSlipNo     NVARCHAR(10)  
         ,  @c_Zone           NVARCHAR(10)  
         ,  @c_PrintedFlag    NCHAR(1)  
         ,  @n_NoOfSku        INT  
         ,  @n_NoOfPickLines  INT     
         ,  @c_Wavekey        NVARCHAR(10)       

        --CS01 E                        
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  

   SET @c_Wavekey = @c_Wavekey_type  --CS01 S


   CREATE TABLE #TMP_WV_PLIST_WAVE_007M (
                                                   RowNum            INT   IDENTITY(1,1)  NOT NULL PRIMARY KEY  
                                                ,  Storerkey         NVARCHAR(15)   NULL  
                                                ,  Wavekey           NVARCHAR(10)   NULL  
                                                ,  PickHeaderKey     NVARCHAR(10)   NULL  
                                                ,  PutawayZone       NVARCHAR(10)   NULL  
                                                ,  Printedflag       NCHAR(1)       NULL  
                                                ,  NoOfSku           INT            NULL  
                                                ,  NoOfPickLines     INT            NULL                                         
                                        )
   CREATE INDEX IX_TMP_WV_PLIST_WAVE_007M on #TMP_WV_PLIST_WAVE_007M ( PickHeaderKey )   

 INSERT INTO #TMP_WV_PLIST_WAVE_007M
 (
     Storerkey,
     Wavekey,
     PickHeaderKey,
     PutawayZone,
     Printedflag,
     NoOfSku,
     NoOfPickLines
 )
 SELECT   PD.Storerkey,
          WD.Wavekey,
          ISNULL(RTRIM(PH.PickHeaderkey), '')  
         ,''
         ,CASE WHEN ISNULL(RTRIM(PH.PickHeaderkey), '') =  '' THEN 'N' ELSE 'Y' END  
         ,COUNT(DISTINCT PD.Sku)  
         ,COUNT(DISTINCT PD.PickDetailkey)
   FROM WAVE WV   WITH (NOLOCK)    
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.WaveKey = WV.WaveKey
   JOIN PICKDETAIL PD   WITH (NOLOCK) ON (WD.Orderkey= PD.Orderkey)  
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)         
   LEFT JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)  
   LEFT JOIN PICKHEADER   PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)  
   LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'wavetype' AND C.code = WV.WaveType AND c.Storerkey =PD.Storerkey
   WHERE WD.Wavekey = @c_Wavekey  
   AND   PD.Status < '5'  
   GROUP BY PD.Storerkey  
         ,  WD.Wavekey  
         , ISNULL(RTRIM(PH.PickHeaderkey), '')
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '')  

   --CS01 E
   
   SELECT TOP 1 @dt_Adddate = CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000'   
                               THEN MIN(TD.AddDate) ELSE WH.EditDate END
               ,@c_Storerkey= OH.Storerkey                                       
   FROM WAVE WH  WITH (NOLOCK)  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)               
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)            
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey            
   WHERE WH.Wavekey = @c_Wavekey  
   GROUP BY OH.Storerkey,TD.AddDate ,WH.EditDate  
                      
   SELECT PH.Wavekey  
         ,PD.AddDate
         ,PH.PickHeaderkey 
         ,'' AS PutawayZone                            
         ,CASE WHEN T007M.Printedflag = 'Y' THEN 'REPRINT' ELSE '' END AS PrintedFlag     --CS01
         ,PD.Storerkey  
         ,PD.Loc  
         ,PD.ID  
         ,Style   = SKU.Style  
         ,Color   = SKU.Color + '(' + CASE WHEN ISNULL(SKU.AltSKU,'') <> '' AND LEN(LTRIM(RTRIM(SKU.AltSKU))) > 12
                                           THEN SUBSTRING(LTRIM(RTRIM(SKU.AltSKU)),12,3) ELSE '' END  + ')'
         ,Size    = SKU.Size  
         ,AltSku  = ISNULL(RTRIM(SKU.AltSku), '')  
         ,SKU.SkuGroup  
         ,Qty    = ISNULL(SUM(PD.Qty),0)  
         ,NoOfSku= T007M.NoOfSku--@n_NoOfSku   --CS01
         ,NoOfPickLines= T007M.NoOfPickLines--@n_NoOfPickLines          --CS01                                
         ,logicalloc = loc.logicallocation 
         ,TRIM(PD.SKU) AS SKU
         ,RptTitle = ISNULL(C.notes,'')   
         ,PD.OrderKey  
         ,OH.ExternOrderKey  
         ,ORDSEQ  = RIGHT('00' + CAST(DENSE_RANK() OVER (ORDER BY PD.OrderKey)  AS NVARCHAR(2)),2)       
         ,WaveType = WV.WaveType
         ,C_Company = OH.C_Company  
         ,shipperkey = case when isnull(OH.shipperkey,'') <> '' and OH.doctype IN ('N' ,'E')   --CS01 S
                           then N'롯데'
                           when isnull(OH.shipperkey,'') = '' and OH.doctype ='N' 
                           then N'스마트'
                           else '' END     
         ,WVDESCR = WV.Descr  
         ,Col01 = N'픽슬립 넘버:'    
         ,Col02 = N'웨이브키:' 
         ,Col03 = N'오더키:' 
         ,Col04 = N'매장명:'  
         ,Col05 = N'택배사:'                                                                      --CS01 E                                                              
   FROM PICKDETAIL PD   WITH (NOLOCK)   
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)   
   JOIN SKU        SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                      AND(PD.Sku = SKU.Sku)  
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)  
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)
   LEFT JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)    
   JOIN dbo.WAVE WV (NOLOCK) ON WV.WaveKey = WD.WaveKey                               --CS01
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SCPSCONST' AND C.Code = '001' AND C.Storerkey = @c_Storerkey 
   JOIN #TMP_WV_PLIST_WAVE_007M T007M ON T007m.PickHeaderKey = PH.PickHeaderKey
   --WHERE PH.PickHeaderKey =  @c_PickSlipNo                      
   WHERE   PD.Status < '5'  
   GROUP BY PH.Wavekey 
         ,  PD.AddDate 
         ,  PH.PickHeaderkey                                    
         ,  PD.Storerkey  
         ,  PD.Loc  
         ,  PD.ID  
         ,  SKU.Style  
         ,  SKU.Color + '(' + CASE WHEN ISNULL(SKU.AltSKU,'') <> '' AND LEN(LTRIM(RTRIM(SKU.AltSKU))) > 12
                                   THEN SUBSTRING(LTRIM(RTRIM(SKU.AltSKU)),12,3) ELSE '' END  + ')'
         ,  SKU.Size
         ,  ISNULL(RTRIM(SKU.AltSku), '')  
         ,  SKU.SkuGroup  
         ,  loc.logicallocation          
         ,  TRIM(PD.SKU)  
         ,  ISNULL(C.notes,'')                           
         ,PD.OrderKey               
         ,OH.ExternOrderKey
         ,WV.WaveType,OH.C_Company,case when isnull(OH.shipperkey,'') <> '' and OH.doctype IN ('N' ,'E')   --CS01 S
                           then N'롯데'
                           when isnull(OH.shipperkey,'') = '' and OH.doctype ='N' 
                           then N'스마트'
                           else '' END   ,WV.Descr 
         ,T007M.NoOfPickLines,T007M.NoOfSku,T007M.Printedflag                                                        --CS01 E
   ORDER BY PH.PickHeaderKey 
         ,  PD.OrderKey                                       
         ,  loc.logicallocation                                 
         ,  PD.Loc  
         ,  TRIM(PD.SKU)
         ,  Style  
         ,  Color  
         ,  Size  

   IF OBJECT_ID('tempdb..#TMP_WV_PLIST_WAVE_007M') IS NOT NULL   --CS01 
      DROP TABLE #TMP_WV_PLIST_WAVE_007M                         --CS01

END -- procedure

GO