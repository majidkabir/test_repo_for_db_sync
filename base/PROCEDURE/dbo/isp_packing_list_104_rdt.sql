SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_104_rdt                                */  
/* Creation Date: 16-Jul-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle(copy from isp_Packing_List_90_rdt                 */  
/*                                                                      */  
/* Purpose: WMS-17505 - [CN] STICHDMAN Packing List label_New           */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_104_rdt                                 */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_104_rdt]  
            @c_Pickslipno    NVARCHAR(15),       -- Could be Storerkey/Pickslipno/Orderkey
            @c_Orderkey      NVARCHAR(10) = ''   -- Could be Orderkey
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

   IF ISNULL(@c_Orderkey,'') = '' SET @c_Orderkey = ''
   
   CREATE TABLE #TMP_Orders (
   	Orderkey   NVARCHAR(10)
   )
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT Orderkey 
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END   
   ELSE IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Pickslipno AND @c_Pickslipno <> '')
   BEGIN
      INSERT INTO #TMP_Orders (Orderkey)
      SELECT @c_Pickslipno
   END
   ELSE
   BEGIN
   	INSERT INTO #TMP_Orders (Orderkey)
      SELECT Orderkey
      FROM ORDERS (NOLOCK)
      WHERE Storerkey = @c_Pickslipno 
      AND OrderKey = @c_Orderkey
   END

   SELECT ORDERS.ExternOrderKey
        , ORDERS.C_Company
        , ''   --CASE ORDERS.Salesman WHEN Codelkup.Code THEN Codelkup.Description ELSE '' END AS OrderSource  
        , ORDERS.C_Contact1
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) + 
          LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone2,''))) AS C_Phone
        , CONVERT (NVARCHAR(20), ORDERS.OrderDate,11) AS OrderDate
        , 0   --ORDERS.OpenQty
        , CAST(REPLACE(LTRIM(REPLACE(ORDERDETAIL.OrderLineNumber, '0', ' ')), ' ', '0') AS INT) AS OrderLineNumber
        , ORDERDETAIL.SKU
        , SKU.DESCR
        , SKU.Style
        , SKU.Size
        , SUM(PICKDETAIL.Qty) AS OriginalQty
        , ISNULL(ORDERS.Salesman,'') AS Salesman
   FROM PACKHEADER (NOLOCK) 
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
   JOIN SKU (NOLOCK) ON SKU.SKU = ORDERDETAIL.SKU AND SKU.Storerkey = ORDERDETAIL.Storerkey
   JOIN PICKDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
                              AND ORDERDETAIL.SKU = PICKDETAIL.SKU
   JOIN #TMP_Orders t ON t.Orderkey = ORDERS.Orderkey   --WL01
   --LEFT JOIN Codelkup ON ORDERS.Storerkey = Codelkup.Storerkey and Codelkup.Listname = 'Platform'  
   --WHERE PACKHEADER.Pickslipno = CASE WHEN @c_Source = 'PACKING' THEN @c_Pickslipno ELSE PACKHEADER.Pickslipno END   
   --AND ORDERS.Orderkey = CASE WHEN @c_Source = 'ORDERS' THEN @c_Pickslipno ELSE ORDERS.Orderkey END                  
   GROUP BY ORDERS.ExternOrderKey
          , ORDERS.C_Company
          , ORDERS.C_Contact1
          , LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) + 
            LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,'')))
          , LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone2,'')))
          , CONVERT (NVARCHAR(20), ORDERS.OrderDate,11)
          , CAST(REPLACE(LTRIM(REPLACE(ORDERDETAIL.OrderLineNumber, '0', ' ')), ' ', '0') AS INT)
          , ORDERDETAIL.SKU
          , SKU.DESCR
          , SKU.Style
          , SKU.Size
          , ISNULL(ORDERS.Salesman,'')
   ORDER BY CAST(REPLACE(LTRIM(REPLACE(ORDERDETAIL.OrderLineNumber, '0', ' ')), ' ', '0') AS INT)

QUIT_SP:  

   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
      DROP TABLE #TMP_Orders

END -- procedure


GO