SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_015                          */  
/* Creation Date: 21-SEP-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: CHONGCS                                                  */  
/*                                                                      */  
/* Purpose: WMS-20694 - IDûPUMA-Wave Pick Slip (New Format )            */  
/*                                                                      */  
/* Called By: RPT_WV_PLIST_WAVE_015                                     */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/* 21-Sep-2022  CHONGCS  1.0  DevOps Combine Script                     */  
/************************************************************************/  
CREATE    PROC [dbo].[isp_RPT_WV_PLIST_WAVE_015]  
         @c_Wavekey        NVARCHAR(10)  
       , @c_PreGenRptData  NVARCHAR(10) = ''  
  
AS  
BEGIN  
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_StartTCnt       INT    
         , @n_Continue        INT    
         , @b_Success         INT    
         , @n_Err             INT    
         , @c_Errmsg          NVARCHAR(255)    
         , @n_Count           INT  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_pickheaderkey   NVARCHAR(10)  

DECLARE    @c_Type        NVARCHAR(1) = '1'                          
         , @c_DataWindow  NVARCHAR(60) = 'RPT_WV_PLIST_WAVE_015'      
         , @c_RetVal      NVARCHAR(255) 
         , @c_storerkey   NVARCHAR(20)  
  
SELECT TOP 1 @c_storerkey = ORD.StorerKey
 FROM WAVEDETAIL WVD WITH (NOLOCK)  
         JOIN PICKDETAIL PD WITH (NOLOCK) ON WVD.OrderKey = PD.OrderKey  
         join Loc loc WITH (NOLOCK) on PD.Loc = loc.Loc  
         join ORDERS ORD WITH (NOLOCK) on PD.OrderKey = ord.OrderKey  
         join SKU s WITH (NOLOCK) on PD.Storerkey = s.StorerKey and PD.Sku = s.Sku  
         left join REPLENISHMENT RP WITH (NOLOCK) on WVD.WaveKey = RP.Wavekey and PD.Storerkey = RP.Storerkey and PD.Sku = RP.Sku and PD.Loc = RP.ToLoc  
         where WVD.WaveKey = @c_Wavekey  

 IF ISNULL(@c_Storerkey,'') <> ''      
      BEGIN      
      
      EXEC [dbo].[isp_GetCompanyInfo]      
               @c_Storerkey  = @c_Storerkey      
            ,  @c_Type       = @c_Type      
            ,  @c_DataWindow = @c_DataWindow      
            ,  @c_RetVal     = @c_RetVal           OUTPUT      
       
      END 

   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue  = 1    
   SET @b_Success   = 1    
   SET @n_Err       = 0    
   SET @c_Errmsg    = ''    


   IF ISNULL(@c_PreGenRptData,'') IN ('','0') SET @c_PreGenRptData = ''  
  
   IF ISNULL(@c_PreGenRptData,'') = ''  
   BEGIN  
         SELECT    
          WVD.WaveKey  
          , loc.PickZone  
          , ord.ExternOrderKey  
          , PD.PickSlipNo  
          , PD.Loc  
          , PD.Sku  
          , s.Style  
          , s.Size  
          , s.DESCR  
          , PD.ID  
          , Sum(case when Len(Trim(PD.ID)) > 0 then 0 else PD.Qty end) [Qty]  
          , Sum(case when Len(Trim(PD.ID)) > 0 then 1 else 0 end) [CTNQty]  
          , case when IsNull(RP.Sku, '') = '' then 'N' else 'Y' end [RPL]  
          , ISNULL(@c_Retval,'')    AS Logo
         FROM WAVEDETAIL WVD WITH (NOLOCK)  
         JOIN PICKDETAIL PD WITH (NOLOCK) ON WVD.OrderKey = PD.OrderKey  
         join Loc loc WITH (NOLOCK) on PD.Loc = loc.Loc  
         join ORDERS ORD WITH (NOLOCK) on PD.OrderKey = ord.OrderKey  
         join SKU s WITH (NOLOCK) on PD.Storerkey = s.StorerKey and PD.Sku = s.Sku  
         left join REPLENISHMENT RP WITH (NOLOCK) on WVD.WaveKey = RP.Wavekey and PD.Storerkey = RP.Storerkey and PD.Sku = RP.Sku and PD.Loc = RP.ToLoc  
         where WVD.WaveKey = @c_Wavekey  
         group by  
          WVD.WaveKey  
          , loc.PickZone  
          , ord.ExternOrderKey  
          , PD.PickSlipNo  
          , PD.Loc  
          , PD.Sku  
          , case when IsNull(RP.Sku, '') = '' then 'N' else 'Y' end  
          , s.Style  
          , s.Size  
          , s.DESCR  
          , PD.ID  
         order by  
            loc.PickZone  
          , PD.Loc  
   END  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)  
   BEGIN  
      CLOSE CUR_LOOP  
      DEALLOCATE CUR_LOOP     
   END  
     
END -- procedure  

GO