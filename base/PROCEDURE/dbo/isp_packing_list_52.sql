SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_packing_list_52                                     */  
/* Creation Date: 21-JUL-2018                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-5644 - [CN] AMER_Packing List_NEW                       */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_52                                      */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 24-JUL-2018 Wan01    1.1   Fixed-Change Size and descr position      */  
/* 04-OCT-2018 CSCHONG  1.2   WMS-6136 add new field  (CS01)            */  
/************************************************************************/  
CREATE PROC [dbo].[isp_packing_list_52]  
         @c_PickSlipNo     NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
  
         , @n_MaxCartonNo     INT  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   SET @n_MaxCartonNo = 0  
   SELECT TOP 1 @n_MaxCartonNo = PD.CartonNo  
   FROM PACKDETAIL PD WITH (NOLOCK)   
   WHERE PD.PickSlipNo = @c_PickSlipNo  
   ORDER BY PD.CartonNo DESC  
  
   SELECT  SortBy = ROW_NUMBER() OVER ( ORDER BY PH.PickSlipNo  
                                                ,PD.CartonNo  
                                                ,RTRIM(PD.Sku)  
                                     )  
         , PageGroup  = RANK() OVER ( ORDER BY PH.PickSlipNo  
                                          ,PD.CartonNo  
                                    )  
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo  
                                                   , PD.CartonNo  
                                        ORDER BY PH.PickSlipNo  
                                                ,PD.CartonNo  
                                                ,RTRIM(PD.Sku)  
  
                                      )  
         , OH.Storerkey  
         , PH.PickSlipNo  
         , OH.Loadkey  
         , OH.Orderkey  
         , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')  
         , ShipTo    = ISNULL(RTRIM(OH.ConsigneeKey),'')   
         , C_Company = ISNULL(RTRIM(OH.C_Company),'')    
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'')   
         , C_Address = ISNULL(RTRIM(OH.C_Address1),'')   
         , PD.CartonNo  
         , LabelNo   = ISNULL(RTRIM(PD.LabelNo),'')   
         , Sku       = RTRIM(PD.Sku)  
         , Size      = ISNULL(RTRIM(SKU.Size),'')     --(Wan01)  
         , SkuDesr   = ISNULL(RTRIM(SKU.Descr),'')  
         , Qty       = ISNULL(SUM(PD.Qty),0)  
         , TotalQty  = (SELECT ISNULL(SUM(PKD.Qty),0)  
                        FROM PACKDETAIL PKD WITH (NOLOCK)  
                        WHERE PKD.PickSlipNo = PH.PickSlipNo  
                        AND   PKD.CartonNo   = PD.CartonNo)  
         , MaxCartonNo = @n_MaxCartonNo  
   ,Style = ISNULL(RTRIM(SKU.Style),'')             --(CS01)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)  
   JOIN SKU       SKU WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey)  
                                    AND(PD.Sku = SKU.Sku)  
   WHERE PH.PickSlipNo = @c_PickSlipNo  
   GROUP BY OH.Storerkey  
         ,  PH.PickSlipNo  
         ,  OH.Loadkey  
         ,  OH.Orderkey  
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')  
         ,  ISNULL(RTRIM(OH.ConsigneeKey),'')   
         ,  ISNULL(RTRIM(OH.C_Company),'')    
         ,  ISNULL(RTRIM(OH.C_Phone1),'')   
         ,  ISNULL(RTRIM(OH.C_Address1),'')   
         ,  PD.CartonNo  
         ,  ISNULL(RTRIM(PD.LabelNo),'')   
         ,  RTRIM(PD.Sku)  
         ,  ISNULL(RTRIM(SKU.Descr),'')  
         ,  ISNULL(RTRIM(SKU.Size),'')  
   ,  ISNULL(RTRIM(SKU.Style),'')          --(CS01)  
  
  
END -- procedure  

GO