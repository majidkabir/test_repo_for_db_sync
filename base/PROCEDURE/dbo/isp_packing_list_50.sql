SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_50                                     */
/* Creation Date: 05-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-5771 - CN_Ganoherb Exceed Report PackList               */
/*        :                                                             */
/* Called By: r_dw_pacling_list_50                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_50]
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

   SELECT  SortBy = ROW_NUMBER() OVER ( ORDER BY OH.Loadkey
                                                ,OH.Orderkey
                                                ,PD.Storerkey
                                                ,RTRIM(PD.Sku)
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY 
                                                 OH.Loadkey
                                                ,OH.Orderkey
                                        ORDER BY OH.Loadkey
                                                ,OH.Orderkey
                                                ,PD.Storerkey
                                                ,RTRIM(PD.Sku)
                                     )
         , OH.Loadkey
         , OH.Orderkey
         , M_Contact = ISNULL(RTRIM(OH.M_Contact1),'') + ' '
                     + ISNULL(RTRIM(OH.M_Contact2),'')
         , M_Company = ISNULL(RTRIM(OH.M_Company),'') 
         , C_Address = ISNULL(RTRIM(OH.C_State),'') + ' '  
                     + ISNULL(RTRIM(OH.C_City),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address1),'') + ' '  
                     + ISNULL(RTRIM(OH.C_Address2),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address3),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address4),'')   
         , C_Contact1= ISNULL(RTRIM(OH.C_Contact1),'') + ' '  
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'') + ' '  
         , OH.OrderDate  
         , PD.Storerkey
         , Sku = RTRIM(PD.Sku)
         , AltSku  = ISNULL(RTRIM(SKU.AltSku),'')
         , SkuDesr = ISNULL(RTRIM(SKU.Descr),'')
         , Qty = ISNULL(SUM(PD.Qty),0)
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN SKU       SKU WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey)
                                    AND(PD.Sku = SKU.Sku)
   WHERE PH.PickSlipNo = @c_PickSlipNo
   GROUP BY  OH.Loadkey
         , OH.Orderkey
         , ISNULL(RTRIM(OH.M_Contact1),'')
         , ISNULL(RTRIM(OH.M_Contact2),'')
         , ISNULL(RTRIM(OH.M_Company),'') 
         , ISNULL(RTRIM(OH.C_State),'')
         , ISNULL(RTRIM(OH.C_City),'') 
         , ISNULL(RTRIM(OH.C_Address1),'') 
         , ISNULL(RTRIM(OH.C_Address2),'') 
         , ISNULL(RTRIM(OH.C_Address3),'') 
         , ISNULL(RTRIM(OH.C_Address4),'') 
         , ISNULL(RTRIM(OH.C_Contact1),'') 
         , ISNULL(RTRIM(OH.C_Phone1),'') 
         , OH.OrderDate  
         , PD.Storerkey
         , RTRIM(PD.Sku)
         , ISNULL(RTRIM(SKU.AltSku),'')
         , ISNULL(RTRIM(SKU.Descr),'')


END -- procedure

GO