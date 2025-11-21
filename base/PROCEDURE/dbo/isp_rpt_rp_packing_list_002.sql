SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/***************************************************************************/      
/* Stored Procedure: Isp_RPT_RP_PACKING_LIST_002                           */      
/* Creation Date: 27-JUL-2023                                              */      
/* Copyright: Maersk                                                       */      
/* Written by: CSCHONG                                                     */      
/*                                                                         */      
/* Purpose: WMS-23213 Packing List - migrate to LOGI report                */      
/*                                                                         */      
/* Called By: RPT_RP_PACKING_LIST_002                                      */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date            Author        Ver     Purposes                          */
/* 10-Sep-2024     XLL           1.1     UWP-24051-Global Timezone(XLL01)  */  
/***************************************************************************/   
  
CREATE    PROC Isp_RPT_RP_PACKING_LIST_002  
     @c_Loadkey                  NVARCHAR(20),  
     @c_wavekey                  NVARCHAR(20),     
     @c_externorderkey_start     NVARCHAR(50),  
     @c_externorderkey_End       NVARCHAR(50)  
AS    
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
  
   DECLARE  @c_Storerkey   NVARCHAR(15)                           
         ,  @c_Type        NVARCHAR(1) = '1'                      
         ,  @c_DataWindow  NVARCHAR(60) = 'RPT_RP_PACKING_LIST_002'  
         ,  @c_RetVal      NVARCHAR(255)         
  
  
IF ISNULL(@c_Loadkey,'') <> ''  
BEGIN  
    SELECT TOP 1 @c_Storerkey = OH.storerkey  
    FROM dbo.ORDERS OH WITH (NOLOCK)   
    WHERE OH.LoadKey = @c_Loadkey  
END  
ELSE IF ISNULL(@c_wavekey,'') <> ''  
BEGIN  
   SELECT TOP 1 @c_Storerkey = OH.storerkey  
    FROM dbo.ORDERS OH WITH (NOLOCK)   
    WHERE OH.UserDefine09 = @c_wavekey  
END   
  
SET @c_RetVal = ''  
  
IF ISNULL(@c_Storerkey,'') <> ''  
BEGIN  
  
EXEC [dbo].[isp_GetCompanyInfo]  
         @c_Storerkey  = @c_Storerkey  
      ,  @c_Type       = @c_Type  
      ,  @c_DataWindow = @c_DataWindow  
      ,  @c_RetVal     = @c_RetVal           OUTPUT  
   
END   
  
  
 	SELECT OH.Orderkey
     , OH.Storerkey
     , S_Company      = ISNULL(RTRIM(ST.Company),'')
     , ExternOrderkey = RTRIM(OH.ExternOrderkey) + '(' + RTRIM(OH.Type) + ')'
     , Loadkey        = CASE WHEN ISNULL(RTRIM(OH.UserDefine08),'') = 'Y'
                             THEN 'W' + ISNULL(RTRIM(OH.UserDefine09),'')
                             ELSE 'L' + ISNULL(RTRIM(OH.Loadkey),'')
                        END
     , DeliveryDate   = [dbo].[fnc_ConvSFTimeZone](OH.StorerKey, OH.Facility, OH.DeliveryDate)  --XLL01
     , Consigneekey   = ISNULL(RTRIM(OH.Consigneekey),'')
     , C_Company      = ISNULL(RTRIM(OH.C_Company),'')
     , C_Address1     = ISNULL(RTRIM(OH.C_Address1),'')
     , C_Address2     = ISNULL(RTRIM(OH.C_Address2),'')
     , C_Address3     = ISNULL(RTRIM(OH.C_Address3),'')
     , C_Address4     = ISNULL(RTRIM(OH.C_Address4),'')
     , C_City         = ISNULL(RTRIM(OH.C_City),'')
     , C_Phone1       = ISNULL(RTRIM(OH.C_Phone1),'')
     , B_Company      = ISNULL(RTRIM(OH.B_Company),'')
     , B_Address1     = ISNULL(RTRIM(OH.B_Address1),'')
     , B_Address2     = ISNULL(RTRIM(OH.B_Address2),'')
     , B_Address3     = ISNULL(RTRIM(OH.B_Address3),'')
     , B_Address4     = ISNULL(RTRIM(OH.B_Address4),'')
     , B_City         = ISNULL(RTRIM(OH.B_City),'')
     , B_Phone1       = ISNULL(RTRIM(OH.B_Phone1),'')
     , ContainerQty   = ISNULL(OH.ContainerQty,0)
     , NOTES          = ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES),'')
     , NOTES2         = ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES2),'')
     , UOM            = PK.PackUOM3
     , UserDefine06   = ISNULL(RTRIM(MIN(OD.UserDefine06)),'')
     , UserDefine09   = ISNULL(RTRIM(MIN(OD.UserDefine09)),'')
     , CartonNo       = PD.CartonNo
     , LabelNo        = ISNULL(RTRIM(PD.LabelNo),'')
     , SKU            = ISNULL(RTRIM(PD.Sku),'')
     , Qty            = (SELECT ISNULL(SUM(Qty),0) FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = ISNULL(RTRIM(PH.PickSlipNo),'') AND CartonNo = PD.CartonNo
                         AND Storerkey = OH.Storerkey AND Sku = ISNULL(RTRIM(PD.Sku),''))
     , AltSku         = ISNULL(RTRIM(SKU.AltSku),'')
     , Descr          = ISNULL(RTRIM(SKU.Descr),'')
     , PickSlipNo     = ISNULL(RTRIM(PH.PickSlipNo),'')
     , Logo           =  ISNULL(@c_Retval,'')
     , [dbo].[fnc_ConvSFTimeZone](OH.StorerKey, OH.Facility, GETDATE()) AS CurrentDateTime  --XLL01
FROM PACKHEADER    PH  WITH (NOLOCK)
JOIN PACKDETAIL    PD  WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
JOIN ORDERS        OH  WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
JOIN ORDERDETAIL   OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
                               AND(PD.Storerkey= OD.Storerkey) AND (PD.Sku = OD.Sku)
JOIN STORER        ST  WITH (NOLOCK) ON (OH.Storerkey= ST.Storerkey)
JOIN SKU           SKU WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey) AND (OD.Sku = SKU.Sku)
JOIN PACK          PK  WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)
WHERE (OH.Loadkey = @c_loadkey OR @c_loadkey = ' ')
AND   (OH.UserDefine09  = @c_wavekey OR @c_wavekey = ' ')
AND   (OH.ExternOrderkey BETWEEN @c_externorderkey_start AND @c_externorderkey_end)
AND   (OH.Status >= '5')
AND   (OH.Status <> 'CANC')
GROUP BY OH.Orderkey
       , OH.Storerkey
       , ISNULL(RTRIM(ST.Company),'')
       , RTRIM(OH.ExternOrderkey)
       , RTRIM(OH.Type)
       , ISNULL(RTRIM(OH.UserDefine08),'')
       , ISNULL(RTRIM(OH.UserDefine09),'')
       , ISNULL(RTRIM(OH.Loadkey),'')
       , OH.DeliveryDate
       , ISNULL(RTRIM(OH.Consigneekey),'')
       , ISNULL(RTRIM(OH.C_Company),'')
       , ISNULL(RTRIM(OH.C_Address1),'')
       , ISNULL(RTRIM(OH.C_Address2),'')
       , ISNULL(RTRIM(OH.C_Address3),'')
       , ISNULL(RTRIM(OH.C_Address4),'')
       , ISNULL(RTRIM(OH.C_City),'')
       , ISNULL(RTRIM(OH.C_Phone1),'')
       , ISNULL(RTRIM(OH.B_Company),'')
       , ISNULL(RTRIM(OH.B_Address1),'')
       , ISNULL(RTRIM(OH.B_Address2),'')
       , ISNULL(RTRIM(OH.B_Address3),'')
       , ISNULL(RTRIM(OH.B_Address4),'')
       , ISNULL(RTRIM(OH.B_City),'')
       , ISNULL(RTRIM(OH.B_Phone1),'')
       , ISNULL(OH.ContainerQty,0)
       , ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES),'')
       , ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES2),'')
       , PK.PackUOM3
       , PD.CartonNo
       , ISNULL(RTRIM(PD.LabelNo),'')
       , ISNULL(RTRIM(PD.Sku),'')
       , ISNULL(RTRIM(SKU.AltSku),'')
       , ISNULL(RTRIM(SKU.Descr),'')
       , ISNULL(RTRIM(PH.PickSlipNo),'')
       , OH.NOTES
       , OH.NOTES2
       , OH.FACILITY  --XLL01
ORDER BY RTRIM(OH.ExternOrderkey)
       , PD.CartonNo
       , ISNULL(RTRIM(PD.LabelNo),'')
       , ISNULL(RTRIM(PD.Sku),'')
END
GO