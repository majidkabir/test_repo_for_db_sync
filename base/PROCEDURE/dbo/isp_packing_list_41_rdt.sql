SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_packing_list_41_rdt                                 */  
/* Creation Date: 03-AUG-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-2585 - cteate new data window for macy china            */  
/*        : packing list                                                */  
/* Called By: Exceed ECOM PACKING ue_print_packlist - arg: Pickslipno   */  
/*          : RDT Print Label Report (593)- arg: Orderkey, Tracking#    */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 23-MAR-2018 CSCHONG  1.0   WMS-4289 - revised field mapping (CS01)   */  
/* 09-Apr-2021 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS02)*/  
/************************************************************************/  
CREATE PROC [dbo].[isp_packing_list_41_rdt]  
           @c_PickSlipNo   NVARCHAR(10)   
         , @c_TrackingNo   NVARCHAR(20) = ''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt    INT  
         , @n_Continue     INT   
     
         --, @c_PickSlipNo   NVARCHAR(10)  
         , @c_Orderkey     NVARCHAR(10)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN   
      COMMIT TRAN  
   END  
  
   SET @c_PickSlipNo = ISNULL(RTRIM(@c_PickSlipNo),'')  
   SET @c_TrackingNo = ISNULL(RTRIM(@c_TrackingNo),'')  
  
   SET @c_Orderkey   = ''  
  
   IF @c_Orderkey = '' AND @c_PickSlipNo <> ''  
   BEGIN  
      SELECT @c_PickSlipNo = PH.PickSlipNo  
            ,@c_Orderkey = PH.Orderkey  
      FROM PACKHEADER PH WITH (NOLOCK)  
      WHERE PH.PickSlipNo = @c_PickSlipNo  
   END  
  
   IF @c_Orderkey = '' AND @c_TrackingNo <> ''  
   BEGIN  
      SELECT @c_PickSlipNo = PH.PickSlipNo  
            ,@c_Orderkey   = PH.Orderkey  
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)  
      --WHERE OH.UserDefine04 = @c_TrackingNo   --CS01  
      WHERE OH.TrackingNo = @c_TrackingNo     --CS01  
   END  
  
   IF @c_Orderkey = '' AND @c_PickSlipNo <> ''  
   BEGIN  
      SELECT @c_PickSlipNo = PH.PickSlipNo  
            ,@c_Orderkey = PH.Orderkey  
      FROM PACKHEADER PH WITH (NOLOCK)  
      WHERE PH.Orderkey = @c_PickSlipNo  
   END  
  
   SELECT RowNo = ROW_NUMBER() OVER (ORDER BY OH.Orderkey, ISNULL(RTRIM(SKU.AltSku),''))  
         ,DataGroupInPage = CEILING(ROW_NUMBER() OVER (ORDER BY OH.Orderkey, ISNULL(RTRIM(SKU.AltSku),''))/30.0)  
         ,PickSlipNo = @c_PickSlipNo  
         ,Orderkey   = OH.Orderkey  
         ,Facility   = OH.Facility  
         ,Storerkey  = OH.Storerkey  
         ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')   
         ,ExternOrderkey_BC = UPPER(ISNULL(RTRIM(OH.ExternOrderkey),''))  
         ,OrderDate  = OH.OrderDate  
         ,C_Company  = ISNULL(RTRIM(OH.C_Contact1),'')--ISNULL(RTRIM(OH.C_Company),'')          --CS01  
         ,C_Address1 = ISNULL(RTRIM(OH.C_Address1),'')   
         ,C_Address2 = ISNULL(RTRIM(OH.C_Address2),'')   
         ,C_Address3 = ISNULL(RTRIM(OH.C_Address3),'')   
         ,AltSku     = ISNULL(RTRIM(SKU.AltSku),'')  
         ,Descr  = ISNULL(RTRIM(SKU.Notes1),SKU.Descr)  
         ,Qty        = ISNULL(SUM(PD.Qty),0)  
   FROM ORDERS     OH  WITH (NOLOCK)    
   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)  
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                     AND(PD.Sku = SKU.Sku)  
   --LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)  
   WHERE  OH.Orderkey = @c_Orderkey --'P000018842'   
   GROUP BY OH.Orderkey  
         ,  OH.Facility  
         ,  OH.Storerkey   
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')  
         ,  OH.OrderDate  
         --,  ISNULL(RTRIM(OH.C_Company),'')   
         , ISNULL(RTRIM(OH.C_Contact1),'')  
         ,  ISNULL(RTRIM(OH.C_Address1),'')   
         ,  ISNULL(RTRIM(OH.C_Address2),'')  
         ,  ISNULL(RTRIM(OH.C_Address3),'')  
         ,  ISNULL(RTRIM(SKU.AltSku),'')  
         ,  ISNULL(RTRIM(SKU.Notes1),SKU.Descr)  
  
QUIT_SP:  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END -- procedure  

GO