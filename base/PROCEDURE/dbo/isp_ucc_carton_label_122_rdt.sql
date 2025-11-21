SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_UCC_Carton_Label_122_rdt                            */  
/* Creation Date: 20-Jul-2023                                           */  
/* Copyright: MAERSK                                                    */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-23097 - HK - Tory Burch CR - Carton Label VAS           */  
/*          Modification                                                */  
/*        :                                                             */  
/* Called By: r_dw_ucc_carton_label_122_rdt                             */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 20-Jul-2023  WLChooi   1.0 DevOps Combine Script                     */
/************************************************************************/  
CREATE   PROC [dbo].[isp_UCC_Carton_Label_122_rdt]
            @c_PickSlipNo     NVARCHAR(40)   
         ,  @c_CartonNoStart  NVARCHAR(4)       
         ,  @c_CartonNoEnd    NVARCHAR(4)       
         ,  @c_LabelNoStart   NVARCHAR(20)   
         ,  @c_LabelNoEnd     NVARCHAR(20)   
         ,  @b_Debug          INT = 0  
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
  
         , @c_SQL             NVARCHAR(4000)  
         , @c_Conditions      NVARCHAR(4000)  
  
         --RCMREPORT   
         , @n_ShowPackRefNo   INT  
         , @c_BrandCode      NVARCHAR(80)
         , @c_busr5          NVARCHAR(50)
         , @c_CDLong         NVARCHAR(50)
           
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END   
  
   SET @c_Storerkey = ''  
  
   SELECT @c_Storerkey = StorerKey  
         ,@c_Orderkey = OrderKey  
   FROM PACKHEADER WITH (NOLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
  
   SET @n_ShowPackRefNo = 0  
   SELECT @n_ShowPackRefNo = ISNULL(MAX(CASE WHEN Code = 'ShowPackRefNo' THEN 1 ELSE 0 END),0)  
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'REPORTCFG'  
   AND Storerkey = @c_Storerkey  
   AND Long = 'r_dw_ucc_carton_label_122_rdt'  
   AND ISNULL(Short,'') <> 'N'  
     
   SET @c_busr5 = ''  
   SET @c_BrandCode = ''  
   SET @c_CDLong = ''  
     
   SELECT TOP 1 @c_busr5 = s.busr5  
   FROM PACKHEADER PH WITH (NOLOCK)   
   JOIN PICKDETAIL PDET WITH (NOLOCK) ON PDET.OrderKey=PH.OrderKey
   JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PDET.StorerKey AND s.Sku = PDET.SKU  
   WHERE PH.PickSlipNo = @c_PickSlipNo  
     
   SELECT @c_CDLong = C.long  
   FROM CODELKUP C WITH (NOLOCK)  
   WHERE Listname = 'ToryBrand'  
   AND code = @c_busr5  
      
   IF @c_Storerkey <> '11338' AND ISNULL(@c_CDLong,'') <> ''   
   BEGIN  
    SET @c_BrandCode = 'Brand: ' + @c_CDLong  
   END  
   ELSE  
   BEGIN  
    SET @c_BrandCode = 'Brand: ' + @c_busr5  
   END  

   SET @c_CVRRoute = ''  
   DECLARE CUR_CLKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT ISNULL(RTRIM(Notes), '')  
         ,UDF01 = ISNULL(RTRIM(UDF01),'')  
   FROM   CODELKUP WITH (NOLOCK)  
   WHERE  ListName = 'CVRRoute'  
   AND    Storerkey= @c_Storerkey  
   AND    Short    = 'ORDERS'  
   ORDER BY Code  
     
   OPEN CUR_CLKUP  
     
   FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_RS = 0  
      SET @c_SQL = N'SELECT @n_RS = 1'  
                 + ' FROM ORDERS WITH (NOLOCK)'  
                 + ' WHERE Orderkey = ''' + @c_Orderkey + ''''  
  
      IF @c_Conditions <> ''  
      BEGIN  
         SET @c_SQL = @c_SQL + ' AND ' + @c_Conditions  
      END  
  
      EXECUTE sp_ExecuteSql @c_SQL, N'@n_RS INT OUTPUT', @n_RS OUTPUT  
  
      SET @c_CVRRoute = @c_UDF01  
  
      IF @n_RS > 0   
      BEGIN  
         BREAK     
      END  
  
      FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01  
   END  
   CLOSE CUR_CLKUP  
   DEALLOCATE CUR_CLKUP   
     
   SELECT DISTINCT   
          PH.PickSlipNo   
         ,PD.LabelNo  
         ,PD.CartonNo  
         ,PD.Storerkey  
         ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')  
         ,OH.Orderkey  
         ,OH.Type  
         ,Consigneekey  = ISNULL(RTRIM(OH.Consigneekey),'')  
         ,C_Company     = ISNULL(RTRIM(OH.C_Company),'')  
         ,C_Address1    = ISNULL(RTRIM(OH.C_Address1),'')  
         ,C_Address2    = ISNULL(RTRIM(OH.C_Address2),'')  
         ,C_Address3    = ISNULL(RTRIM(OH.C_Address3),'')  
         ,C_Address4    = ISNULL(RTRIM(OH.C_Address4),'')  
         ,C_City        = ISNULL(RTRIM(OH.C_City),'')  
         ,C_State       = ISNULL(RTRIM(OH.C_State),'')  
         ,C_Zip         = ISNULL(RTRIM(OH.C_Zip),'')  
         ,C_Country     = ISNULL(RTRIM(OH.C_Country),'')  
         ,Route         = ISNULL(RTRIM(OH.Route),'')  
         ,DischargePlace= ISNULL(RTRIM(OH.DischargePlace),'')
         ,CVRRoute      = @c_CVRRoute
         ,RefNo         = CASE WHEN @n_ShowPackRefNo = 1 THEN ISNULL(RTRIM(PD.RefNo),'') + IIF(U1.CountSKU > 1, 'M', '') ELSE '' END 
         ,PrintDateTime = CONVERT(NVARCHAR(20), GETDATE(), 120)  
         ,BrandCode     = @c_BrandCode
         ,ShowVAS       = IIF(ISNULL(ST.SUSR1,'') = 'V', 'V', '')
         ,LabelNo_L     = CASE WHEN LEN(PD.LabelNo) > 5 THEN SUBSTRING(PD.LabelNo, 1, LEN(PD.LabelNo) - 5) ELSE '' END
         ,LabelNo_R     = CASE WHEN LEN(PD.LabelNo) > 5 THEN RIGHT(PD.LabelNo, 5) ELSE PD.LabelNo END
         ,RefNo_L       = CASE WHEN LEN(PD.RefNo) > 5 THEN SUBSTRING(PD.RefNo, 1, LEN(PD.RefNo) - 5) ELSE '' END
         ,RefNo_R       = CASE WHEN LEN(PD.RefNo) > 5 THEN RIGHT(ISNULL(RTRIM(PD.RefNo),'') + 
                                                           IIF(U1.CountSKU > 1, 'M', ''), 5) 
                                                      ELSE PD.RefNo END
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)  
   LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = OH.Consigneekey AND ST.ConsigneeFor = OH.Storerkey)
   LEFT JOIN UCC U WITH (NOLOCK) ON (U.UCCNo = PD.RefNo AND U.Storerkey = PD.Storerkey)
   OUTER APPLY ( SELECT COUNT(DISTINCT UCC.SKU) AS CountSKU
                 FROM UCC (NOLOCK)
                 WHERE UCC.UCCNo = U.UCCNo
                 AND UCC.Storerkey = U.Storerkey
                 AND UCC.ExternKey = U.ExternKey
                 AND EXISTS ( SELECT 1 
                              FROM REPLENISHMENT (NOLOCK)
                              WHERE REPLENISHMENT.RefNo = UCC.UCCNo 
                              AND REPLENISHMENT.Storerkey = UCC.Storerkey ) ) AS U1
   WHERE PH.PickSlipNo = @c_PickSlipNo  
   AND  PD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd  
   AND  PD.LabelNo  BETWEEN @c_LabelNoStart AND @c_LabelNoEnd  
   ORDER BY PD.CartonNo  
           ,PD.LabelNo  
  
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