SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc: isp_UCC_Carton_Label_62_rdt                             */    
/* Creation Date: 01-JUNE-2017                                          */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS-1987 - CN_DYSON_Report_B2B Shipping Label               */    
/*        :                                                             */    
/* Called By: r_dw_ucc_carton_label_57_rdt                              */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */    
/* 24/08/2017   NJOW01    1.0 Fix - remove qty in grouping              */  
/* 26/04/2022   Pakyuen   1.1 insert traceinfo (PY01)                   */    
/************************************************************************/    
CREATE PROC [dbo].[isp_UCC_Carton_Label_62_rdt]     
            @c_PickSlipNo     NVARCHAR(40)     
         ,  @c_dropid         NVARCHAR(20)         
        -- ,  @c_CartonNoEnd    NVARCHAR(4)         
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT    
         , @n_Continue        INT     
         , @n_RS              INT    
    
         , @c_Storerkey       NVARCHAR(15)    
         , @c_Orderkey        NVARCHAR(10)    
         , @c_CVRRoute        NVARCHAR(10)    
         , @c_UDF01           NVARCHAR(60)    
    
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1    
    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END     
    
   SET @c_Storerkey = ''    
    
   --SELECT @c_Storerkey = StorerKey    
   --      ,@c_Orderkey = OrderKey    
   --FROM PACKHEADER WITH (NOLOCK)    
   --WHERE PickSlipNo = @c_PickSlipNo    
    
         
   SELECT DISTINCT     
          PAD.PickSlipNo     
         ,PAD.dropid    
         ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,OH.Loadkey    
         ,Consigneekey  = ISNULL(RTRIM(OH.Consigneekey),'')    
         ,C_Company     = ISNULL(RTRIM(OH.C_Company),'')    
         ,C_City        = ISNULL(RTRIM(OH.C_City),'')    
         ,LPLD_LOC      = ISNULL(lpld.loc,'')    
         ,PQTY          = sum(PAD.qty) --over (partition by PAD.dropid order by PAD.dropid) --SUM(PD.qty)     
  -- FROM PACKHEADER PH WITH (NOLOCK)     
   FROM PICKDETAIL PAD WITH (NOLOCK) --ON PAD.pickslipno=PH.pickslipno --AND pad.DropID=pd.DropID    
   JOIN ORDERS     OH WITH (NOLOCK) ON (PAD.Orderkey = OH.Orderkey)    
   LEFT JOIN LoadPlanLaneDetail AS lpld WITH (NOLOCK) ON lpld.loadkey=OH.loadkey     
                                    -- AND lpld.externorderkey = OH.externorderkey    
                                     AND lpld.locationcategory = 'STAGING'    
   WHERE PAD.PickSlipNo = @c_PickSlipNo    
  -- AND  PAD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd    
  AND PAD.dropid=@c_dropid    
   GROUP BY PAD.PickSlipNo     
         ,PAD.dropid    
         ,ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,OH.Loadkey    
         ,ISNULL(RTRIM(OH.Consigneekey),'')    
         ,ISNULL(RTRIM(OH.C_City),'')    
         ,ISNULL(RTRIM(OH.C_Company),'')    
         ,ISNULL(lpld.loc,'')    
         --,PAD.qty  --NJOW01    
   ORDER BY PAD.dropid    
    
  --insert trace info (PY01) begin  
    
    insert into traceinfo (tracename,timein,step1,step2,step3,step4,step5,col1,col2,col3,col4)  
 SELECT DISTINCT   'DYSONTrace',getdate(),  
          PAD.PickSlipNo     
         ,PAD.dropid    
         ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,OH.Loadkey    
         ,Consigneekey  = ISNULL(RTRIM(OH.Consigneekey),'')    
         ,C_Company     = ISNULL(RTRIM(OH.C_Company),'')    
         ,C_City        = ISNULL(RTRIM(OH.C_City),'')    
         ,LPLD_LOC      = ISNULL(lpld.loc,'')    
         ,PQTY          = sum(PAD.qty) --over (partition by PAD.dropid order by PAD.dropid) --SUM(PD.qty)     
  -- FROM PACKHEADER PH WITH (NOLOCK)     
   FROM PICKDETAIL PAD WITH (NOLOCK) --ON PAD.pickslipno=PH.pickslipno --AND pad.DropID=pd.DropID    
   JOIN ORDERS     OH WITH (NOLOCK) ON (PAD.Orderkey = OH.Orderkey)    
   LEFT JOIN LoadPlanLaneDetail AS lpld WITH (NOLOCK) ON lpld.loadkey=OH.loadkey     
                                    -- AND lpld.externorderkey = OH.externorderkey    
                                     AND lpld.locationcategory = 'STAGING'    
   WHERE PAD.PickSlipNo = @c_PickSlipNo    
  -- AND  PAD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd    
  AND PAD.dropid=@c_dropid    
   GROUP BY PAD.PickSlipNo     
         ,PAD.dropid    
         ,ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,OH.Loadkey    
         ,ISNULL(RTRIM(OH.Consigneekey),'')    
         ,ISNULL(RTRIM(OH.C_City),'')    
         ,ISNULL(RTRIM(OH.C_Company),'')    
         ,ISNULL(lpld.loc,'')    
         --,PAD.qty  --NJOW01    
   ORDER BY PAD.dropid    
     
  --insert trace info (PY01) end  
    
    
QUIT_SP:    
    
   IF CURSOR_STATUS( 'LOCAL', 'CUR_CLKUP') in (0 , 1)      
   BEGIN    
      CLOSE CUR_CLKUP    
      DEALLOCATE CUR_CLKUP    
   END    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END     
END -- procedure 

GO