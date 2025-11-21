SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/    
/* Stored Proc: isp_Delivery_Note51_RDT                                 */    
/* Creation Date: 23-Dec-2020                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-15940 - KR iiCombined_Packing List_DataWindow_New       */    
/*        : Copy from isp_Delivery_Note43_RDT                           */                                                             
/*        :                                                             */ 
/* Called By: r_dw_Delivery_Note51_RDT                                  */    
/*          :                                                           */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver  Purposes                                 */    
/* 2021-02-24   WLChooi   1.1  WMS-15940 - Sort by Qty DESC (WL01)      */
/* 2023-05-08   WZPang    1.2  WMS-22260 - Add columns (WZ01)           */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_Delivery_Note51_RDT]    
            @c_Orderkey       NVARCHAR(10) 
           ,@c_StartCartonNo  NVARCHAR(10) = '0'  
           ,@c_EndCartonNo    NVARCHAR(10) = '0'
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
         
         , @n_MaxLineno       INT  
         , @n_MaxRec          INT   
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue  = 1    
   SET @b_Success   = 1    
   SET @n_Err       = 0    
   SET @c_Errmsg    = ''   
   SET @n_MaxLineno = 30
   SET @n_MaxRec = 0
 
   CREATE TABLE #DELNOTE51RDT( 
      RowNo          INT NOT NULL IDENTITY(1,1) 
     ,Orderkey       NVARCHAR(20) 
     ,C_Company      NVARCHAR(45)   
     ,C_Addresses    NVARCHAR(255)  
     ,Contact1       NVARCHAR(60) 
     ,LabelNo        NVARCHAR(20)  
     ,C01            NVARCHAR(150)  
     ,C02            NVARCHAR(150)  
     ,C03            NVARCHAR(150) 
     ,SKU            NVARCHAR(20) 
     ,SDESCR         NVARCHAR(255)  
     ,C04            NVARCHAR(150)  
     ,C05            NVARCHAR(150) 
     ,Qty            INT  
     ,C06            NVARCHAR(150)  
     ,C07            NVARCHAR(150) 
     ,C08            NVARCHAR(150)  
     ,C09            NVARCHAR(150) 
     ,C10            NVARCHAR(150) 
     ,C11            NVARCHAR(150) 
	  ,C12            NVARCHAR(150)	--ML01
	  ,C13            NVARCHAR(150)	--ML01
	  ,ExternOrderKey NVARCHAR(45)
     ,AltSku         NVARCHAR(20)   --WZ01
     ,C14            NVARCHAR(150)  --WZ01
   )          

   INSERT INTO #DELNOTE51RDT (Orderkey,C_Company,C_Addresses,Contact1,LabelNo,C01,C02  
                             ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,C13,ExternOrderKey,AltSku,C14) --ML01 --WZ01  
   SELECT OH.Orderkey as Orderkey   
        , OH.C_Company AS C_Company    
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +  
          LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) AS C_Addresses    
        , LTRIM(RTRIM(ISNULL(OH.C_Contact1,''))) AS Contact1  
        , PAD.LabelNo AS LabelNo  
        , C01 = ISNULL(MAX(CASE WHEN CL.Code ='C01' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C02 = ISNULL(MAX(CASE WHEN CL.Code ='C02' THEN RTRIM(CL.Long) ELSE '' END),'')    
        , C03 = ISNULL(MAX(CASE WHEN CL.Code ='C03' THEN RTRIM(CL.Long) ELSE '' END),'')    
        , PAD.SKU    
        , ISNULL(S.descr,'') AS SDESCR    
        , C04 = ISNULL(MAX(CASE WHEN CL.Code ='C04' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C05 = ISNULL(MAX(CASE WHEN CL.Code ='C05' THEN RTRIM(CL.Long) ELSE '' END),'')    
        , PAD.Qty AS Qty    
        , C06 = ISNULL(MAX(CASE WHEN CL.Code ='C06' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C07 = ISNULL(MAX(CASE WHEN CL.Code ='C07' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C08 = ISNULL(MAX(CASE WHEN CL.Code ='C08' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C09 = ISNULL(MAX(CASE WHEN CL.Code ='C09' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C10 = ISNULL(MAX(CASE WHEN CL.Code ='C10' THEN RTRIM(CL.Long) ELSE '' END),'')  
        , C11 = ISNULL(MAX(CASE WHEN CL.Code ='C11' THEN RTRIM(CL.Long) ELSE '' END),'')  
    , C12 = ISNULL(MAX(CASE WHEN CL.Code ='C12' THEN RTRIM(CL.Long) ELSE '' END),'') --ML01  
    , C13 = ISNULL(MAX(CASE WHEN CL.Code ='C13' THEN RTRIM(CL.Long) ELSE '' END),'') --ML01  
    , OH.ExternOrderKey  
        , S.AltSku                                                                        --WZ01  
        , C14 = ISNULL(MAX(CASE WHEN CL.Code ='C14' THEN RTRIM(CL.Long) ELSE '' END),'')  --WZ01  
   FROM ORDERS OH (NOLOCK)    
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.orderkey = OH.Orderkey  
   JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.Pickslipno = PH.Pickslipno  
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PAD.Storerkey AND S.sku = PAD.sku  
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName= 'DNOTECONST' AND CL.Storerkey = OH.Storerkey --AND CL.Notes = 'B2B'  
   WHERE OH.OrderKey = @c_Orderkey    
   AND PAD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo          
   GROUP BY OH.Orderkey    
          , OH.C_Company  
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) +  
            LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address4,'')))   
          , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'')))   
          , PAD.SKU    
          , ISNULL(S.descr,'')  
          , PAD.LabelNo  
          , PAD.Qty  
      , OH.ExternOrderKey  
          , S.AltSku         --WZ01  
   --ORDER BY PAD.Qty DESC   --WL01  
   ORDER BY ISNULL(S.descr,'')   --ML01  
  
   SET @n_MaxRec = 0  
     
   SELECT @n_MaxRec = COUNT(1)   
   FROM  #DELNOTE51RDT  
   WHERE Orderkey = @c_Orderkey  
  
   WHILE @n_MaxRec > 0 AND @n_MaxRec< @n_MaxLineno  
   BEGIN  
      INSERT INTO #DELNOTE51RDT (Orderkey,C_Company,C_Addresses,Contact1,LabelNo,C01,C02  
                                ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,C13,ExternOrderKey,C14)  
      SELECT TOP 1 Orderkey,C_Company,C_Addresses,Contact1,LabelNo,C01,C02  
                ,C03,'','',C04,C05,'',C06,C07,C08,C09,C10,C11,C12,C13,ExternOrderKey,C14  
      FROM #DELNOTE51RDT  
      ORDER BY RowNo  
  
      SET @n_MaxLineno = @n_MaxLineno - 1   
   END  
  
   
   SELECT Orderkey,C_Company,C_Addresses,Contact1,LabelNo,C01,C02  
         ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,C13,ExternOrderKey,AltSku,C14  
   FROM #DELNOTE51RDT  
   ORDER BY RowNo  
   
QUIT_SP:    
   IF OBJECT_ID('tempdb..#DELNOTE51RDT') IS NOT NULL  
      DROP TABLE #DELNOTE51RDT  
  
   IF @n_Continue = 3      
   BEGIN      
      IF @@TRANCOUNT > 0      
      BEGIN      
         ROLLBACK TRAN      
      END      
   END      
   ELSE      
   BEGIN      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END      
      
   WHILE @@TRANCOUNT < @n_StartTCnt      
   BEGIN      
      BEGIN TRAN      
   END      
       
END -- procedure  

GO