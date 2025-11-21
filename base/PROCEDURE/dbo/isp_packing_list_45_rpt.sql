SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_45_rpt                                 */
/* Creation Date: 08-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4887 - [CN] J&J_DataWindow_PackingList_CR               */
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_packing_list_45_rpt]
           @c_Loadkey         NVARCHAR(10)
         , @c_OrderKey        NVARCHAR(10)
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

   SET @c_OrderKey = ISNULL(@c_OrderKey,'')

   SELECT  SortSeq= ROW_NUMBER() OVER ( ORDER BY LP.Loadkey
                                                ,OH.Orderkey
                                                ,OD.Storerkey
                                                ,RTRIM(OD.Sku)
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY 
                                                 LP.Loadkey
                                                ,OH.Orderkey
                                        ORDER BY LP.Loadkey
                                                ,OH.Orderkey
                                                ,OD.Storerkey
                                                ,RTRIM(OD.Sku)
                                     )
         , LP.Loadkey
         , OH.Orderkey
         , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'') 
         , OH.Consigneekey
         , C_Company = ISNULL(RTRIM(OH.C_Company),'') 
         , C_Address = ISNULL(RTRIM(OH.C_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address2),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address3),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address4),'') + ' '    
         , C_Contact1  = ISNULL(RTRIM(OH.C_Contact1),'') + ' '  
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'') + ' '  
         , OH.OrderDate  
         , OH.ShipperKey
         , Userdefine02 = ISNULL(RTRIM(OH.UserDefine02),'')
         , Userdefine06 = ISNULL(OH.UserDefine06,'1900-01-01')
         , OH.InvoiceAmount
         , OD.Storerkey
         , sKU = RTRIM(OD.Sku)
         , SkuDesr = ISNULL(RTRIM(SKU.Descr),'')
         , UOM = 'PK'
         , Qty = ISNULL(SUM(OD.OpenQty),0)
         , OD.UnitPrice
         , SKU.StdGrossWgt
         , SKU.[StdCube]
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERS   OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                     AND(OD.Sku = SKU.Sku)
   WHERE LP.Loadkey = @c_Loadkey -- '0001718666'
   AND   OH.Orderkey= CASE WHEN @c_Orderkey = '' THEN OH.Orderkey ELSE @c_Orderkey END
   GROUP BY  LP.Loadkey
         , OH.Orderkey
         , ISNULL(RTRIM(OH.ExternOrderkey),'') 
         , OH.Consigneekey
         , ISNULL(RTRIM(OH.C_Company),'') 
         , ISNULL(RTRIM(OH.C_Address1),'') 
         , ISNULL(RTRIM(OH.C_Address2),'') 
         , ISNULL(RTRIM(OH.C_Address3),'') 
         , ISNULL(RTRIM(OH.C_Address4),'') 
         , ISNULL(RTRIM(OH.C_Contact1),'') 
         , ISNULL(RTRIM(OH.C_Phone1),'') 
         , OH.OrderDate  
         , OH.ShipperKey
         , ISNULL(RTRIM(OH.UserDefine02),'')
         , ISNULL(OH.UserDefine06,'1900-01-01')
         , OH.InvoiceAmount
         , OD.Storerkey
         , RTRIM(OD.Sku)
         , ISNULL(RTRIM(SKU.Descr),'')
         , OD.UnitPrice
         , SKU.StdGrossWgt
         , SKU.[StdCube]

END -- procedure

GO