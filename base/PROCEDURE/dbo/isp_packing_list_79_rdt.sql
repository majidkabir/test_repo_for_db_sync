SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_79_rdt                                 */  
/* Creation Date: 10-Aug-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14659 - [CN]STICHD PackList label NEW                   */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_79_rdt                                  */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_79_rdt]  
            @c_Pickslipno    NVARCHAR(10)
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

         , @c_RptLogo         NVARCHAR(255)  
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT
         , @c_Source          NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
   BEGIN
      SET @c_Source = 'PACKING'
   END
   ELSE
   BEGIN
      SET @c_Source = 'ORDERS'
   END

   SELECT ORDERS.ExternOrderKey
        , ORDERS.C_Company
        , CASE ORDERS.Salesman WHEN Codelkup.Code THEN Codelkup.Description ELSE '' END AS OrderSource  
        , ORDERS.C_Contact1
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) + 
          LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone2,''))) AS C_Phone
        , CONVERT (NVARCHAR(20), ORDERS.OrderDate,11) AS OrderDate
        , ORDERS.OpenQty
        , CAST(REPLACE(LTRIM(REPLACE(ORDERDETAIL.OrderLineNumber, '0', ' ')), ' ', '0') AS INT) AS OrderLineNumber
        , ORDERDETAIL.SKU
        , SKU.DESCR
        , SKU.Style
        , SKU.Size
        , ORDERDETAIL.OriginalQty
   FROM PACKHEADER (NOLOCK) 
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
   JOIN SKU (NOLOCK) ON SKU.SKU = ORDERDETAIL.SKU AND SKU.Storerkey = ORDERDETAIL.Storerkey
   LEFT JOIN Codelkup ON ORDERS.Storerkey = Codelkup.Storerkey and Codelkup.Listname = 'Platform'  
   WHERE PACKHEADER.Pickslipno = CASE WHEN @c_Source = 'PACKING' THEN @c_Pickslipno ELSE PACKHEADER.Pickslipno END
   AND ORDERS.Orderkey = CASE WHEN @c_Source = 'ORDERS' THEN @c_Pickslipno ELSE ORDERS.Orderkey END
   ORDER BY CAST(REPLACE(LTRIM(REPLACE(ORDERDETAIL.OrderLineNumber, '0', ' ')), ' ', '0') AS INT)

QUIT_SP:  
END -- procedure


GO