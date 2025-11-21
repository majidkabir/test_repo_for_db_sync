SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_94                                     */
/* Creation Date: 09-FEB-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: mingle                                                   */
/*                                                                      */
/* Purpose: WMS-15983 - [CN] Converse_Packing List_CR                   */
/*        :                                                             */
/* Called By: r_dw_packing_list_94                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-Apr-09 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_94]
           @c_PickSlipNo      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

   SELECT  SortBy = ROW_NUMBER() OVER ( ORDER BY PH.PickSlipNo
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                ,ISNULL(RTRIM(SKU.Manufacturersku),'')
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo
                                        ORDER BY PH.PickSlipNo
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                ,ISNULL(RTRIM(SKU.Manufacturersku),'')
                                      )
         , PrintTime      = GETDATE()
         , OH.Storerkey
         , PH.PickSlipNo
         , OH.Loadkey
         , OH.Orderkey
         , PickSlip_Title = ISNULL(RTRIM(OH.UserDefine03),'') + N'送货单'
         , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')
         , Shipperkey= ISNULL(RTRIM(OH.Shipperkey),'') --+ N'??'  --WL02
         , C_Contact1= ISNULL(RTRIM(OH.C_Contact1),'') + ' '  
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'') + ' '  
         --, C_Address = ISNULL(RTRIM(OH.C_State),'') + ' '  
         --            + ISNULL(RTRIM(OH.C_City),'') + ' '
         --            + ISNULL(RTRIM(OH.C_Address1),'')  
         , C_Address = ISNULL(RTRIM(OH.C_Address2),'')   --WL02
         , Manufacturersku  = ISNULL(RTRIM(SKU.Manufacturersku),'') 
         , Style = ISNULL(RTRIM(SKU.Style),'')
         , ColorSize = ISNULL(RTRIM(SKU.Color),'') + ' ' + ISNULL(RTRIM(SKU.Size),'')
         , SkuDesr = ISNULL(RTRIM(SKU.Descr),'')
         , Qty = ISNULL(SUM(PD.Qty),0)
         , Loc = PD.Loc
         , TrackingNo = OH.TrackingNo --OH.UserDefine04    --WL01  --CS01
         , AddDate = CONVERT(NVARCHAR(10),OH.AddDate,120)   --WL02
         , SKUSize = CASE WHEN ISNULL(RTRIM(SKU.BUSR8),'') = '10' THEN ISNULL(RTRIM(SKU.Measurement),'')   --WL02
                                                                  ELSE ISNULL(RTRIM(SKU.Size),'') END      --WL02
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN SKU       SKU WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey)
                                    AND(PD.Sku = SKU.Sku)
   WHERE PH.PickSlipNo = @c_PickSlipNo
   GROUP BY PH.PickSlipNo
         ,  OH.Storerkey
         ,  OH.Loadkey
         ,  OH.Orderkey
         ,  ISNULL(RTRIM(OH.UserDefine03),'')  
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(OH.Shipperkey),'') 
         ,  ISNULL(RTRIM(OH.C_Contact1),'') + ' '  
         ,  ISNULL(RTRIM(OH.C_Phone1),'')   
         --,  ISNULL(RTRIM(OH.C_State),'')  
         --,  ISNULL(RTRIM(OH.C_City),'') 
         --,  ISNULL(RTRIM(OH.C_Address1),'')   
         ,  ISNULL(RTRIM(OH.C_Address2),'')   --WL02
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
         ,  ISNULL(RTRIM(SKU.Size),'')
         ,  ISNULL(RTRIM(SKU.Manufacturersku),'')
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  PD.Loc
         --,  OH.UserDefine04      --WL01   --CS01
         ,  OH.TrackingNo          --CS01
         ,  CONVERT(NVARCHAR(10),OH.AddDate,120)   --WL02
         ,  CASE WHEN ISNULL(RTRIM(SKU.BUSR8),'') = '10' THEN ISNULL(RTRIM(SKU.Measurement),'')   --WL02
                                                         ELSE ISNULL(RTRIM(SKU.Size),'') END      --WL02


END -- procedure

GO