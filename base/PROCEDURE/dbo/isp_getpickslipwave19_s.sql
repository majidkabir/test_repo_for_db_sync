SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetPickSlipWave19_s                                 */  
/* Creation Date: 12-MAY-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CHONGCS                                                  */  
/*                                                                      */
/* Purpose: WMS-16974 - [KR] SouthCape_PickSlip_DataWindow_CR           */  
/*        :                                                             */  
/* Called By: r_dw_print_wave_pickslip_19_s                             */ 
/*          : Copy From isp_GetPickSlipWave19_1                         */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */  
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipWave19_S]  
            @c_Wavekey        NVARCHAR(10)  
         ,  @c_PickSlipNo     NVARCHAR(10)  
         ,  @c_Zone           NVARCHAR(10)  
         ,  @c_PrintedFlag    NCHAR(1)  
         ,  @n_NoOfSku        INT  
         ,  @n_NoOfPickLines  INT  

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
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   
   SELECT TOP 1 @dt_Adddate = CASE WHEN ISNULL(TD.AddDate,'')  <>'1900-01-01 00:00:00.000'   
                               THEN MIN(TD.AddDate) ELSE WH.EditDate END--WH.AddDate  
               ,@c_Storerkey= OH.Storerkey                                       
   FROM WAVE WH  WITH (NOLOCK)  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)              --(Wan02)  
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)             --(Wan02)  
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.wavekey=WH.wavekey             --(CS01)  
   WHERE WH.Wavekey = @c_Wavekey  
   GROUP BY OH.Storerkey,TD.AddDate ,WH.EditDate  
                      
   SELECT PH.Wavekey  
         ,PD.AddDate
         ,PH.PickHeaderkey  
         ,LOC.PutawayZone                                  
         ,@c_Printedflag    
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
         ,NoOfSku= @n_NoOfSku 
         ,NoOfPickLines= @n_NoOfPickLines                                          
         ,logicalloc = loc.logicallocation 
         ,PD.SKU  
         ,RptTitle = ISNULL(C.notes,'')                                --CS01                   
   FROM PICKDETAIL PD   WITH (NOLOCK)   
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)   
   JOIN SKU        SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                      AND(PD.Sku = SKU.Sku)  
   JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)  
   JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SCPSCONST' AND C.Code = '001' AND C.Storerkey = @c_Storerkey   --CS01
   WHERE PH.PickHeaderKey = @c_PickSlipNo  
  -- AND   LOC.PutawayZone = @c_Zone                            
   AND   PD.Status < '5'  
   GROUP BY PH.Wavekey 
         ,  PD.AddDate 
         ,  PH.PickHeaderkey  
         ,  LOC.PutawayZone                                   
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
         ,  PD.SKU      
         ,  ISNULL(C.notes,'')                            --CS01              
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), '')   
         ,  LOC.PutawayZone                                       
         ,  loc.logicallocation                                 
         ,  PD.Loc  
         ,  PD.SKU 
         ,  Style  
         ,  Color  
         ,  Size  
  
END -- procedure  

GO