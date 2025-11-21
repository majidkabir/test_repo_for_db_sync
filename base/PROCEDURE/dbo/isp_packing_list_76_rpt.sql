SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_76_rpt                                 */  
/* Creation Date: 18-May-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-13394 - [CN] Erno Laszlo_B2C_Packing_List               */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_76_rpt                                  */  
/*          : View Report                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_76_rpt]  
            @c_Orderkey     NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
  
         , @c_ExternOrderKey  NVARCHAR(50)  
         , @c_Storerkey       NVARCHAR(15)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   SELECT N'装 箱 清 单' AS RptTitle
         , ISNULL(OH.M_Contact1,'') AS M_Contact1
         , OH.C_Contact1
         , OH.C_Address1
         , OH.C_Phone1
         , OH.Externorderkey
         , CONVERT(NVARCHAR(10), OH.OrderDate, 101) AS OrderDate
         , OH.Orderkey
         , OD.SKU
         , SKU.Altsku
         , SKU.DESCR
         , SUM(OD.QtyAllocated) AS QtyAllocated
         , ISNULL(CL.Notes,'') AS Remark
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.Orderkey = OH.Orderkey
   JOIN SKU SKU (NOLOCK) ON SKU.SKU = OD.SKU AND SKU.Storerkey = OD.Storerkey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowRemark' AND CL.Short = 'Y'
                                 AND CL.Long = 'r_dw_packing_list_76_rpt' AND CL.Storerkey = OH.Storerkey
   WHERE OH.Orderkey = @c_Orderkey
   GROUP BY ISNULL(OH.M_Contact1,'')
          , OH.C_Contact1
          , OH.C_Address1
          , OH.C_Phone1
          , OH.Externorderkey
          , CONVERT(NVARCHAR(10), OH.OrderDate, 101)
          , OH.Orderkey
          , OD.SKU
          , SKU.Altsku
          , SKU.DESCR
          , ISNULL(CL.Notes,'')
   HAVING SUM(OD.QtyAllocated) > 0
   ORDER BY OD.SKU

END -- procedure


GO