SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Stored Procedure: isp_Packing_List_84_rdt                            */  
/* Creation Date: 24-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:WMS-15234 - AG Packing List                                  */  
/*                                                                      */  
/*                                                                      */  
/* Called By: report dw = r_dw_packing_list_84_rdt                      */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
CREATE PROC [dbo].[isp_Packing_List_84_rdt] (  
   @c_Pickslipno NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey      NVARCHAR(10)
         , @n_MaxLineno     INT = 9
         , @n_CurrentRec    INT    
         , @n_MaxRec        INT    
         , @n_cartonno      INT    
   
   SET @c_Orderkey = @c_Pickslipno
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey = OrderKey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END
   
   CREATE TABLE #TMP_PL84 (
   	RowID            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , C_contact1       NVARCHAR(45)
    , C_Phone1         NVARCHAR(45)
    , C_Addresses      NVARCHAR(250)
    , Orderkey         NVARCHAR(10)
    , OrderDate        DATETIME
    , Sku              NVARCHAR(20)  NULL
    , Descr            NVARCHAR(250) NULL
    , OriginalQty      INT           NULL
    , Logo             NVARCHAR(100)
    , t1               NVARCHAR(250)
    , t2               NVARCHAR(250)
    , t3               NVARCHAR(250)
    , t4               NVARCHAR(250)
    , t5               NVARCHAR(250)
    , t6               NVARCHAR(250)
    , t7               NVARCHAR(250)
    , t8               NVARCHAR(250)
    , t9               NVARCHAR(250)
    , Externorderkey   NVARCHAR(50)
    , t10              NVARCHAR(250)
    , TrackingNo       NVARCHAR(50)
    , RetailSKU        NVARCHAR(20) NULL
    , t11              NVARCHAR(250)
   )
   
   INSERT INTO #TMP_PL84
   SELECT OH.C_contact1 
        , OH.C_Phone1
        , LTRIM(RTRIM(ISNULL(OH.C_State,''))) + LTRIM(RTRIM(ISNULL(OH.C_City,''))) + 
          LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) AS C_Addresses
        , OH.OrderKey  
        , OH.OrderDate
        , OD.SKU
        , ISNULL(S.Descr,'') AS Descr
        , OD.OriginalQty
        , 'AG Logo.png' AS Logo
        , N'送货单' AS t1
        , N'客户详细信息:' AS t2
        , N'送货地址:' AS t3
        , N'订单号:' AS t4
        , N'订单日期:' AS t5
        , N'产品代码' AS t6
        , N'描述' AS t7
        , N'数量' AS t8
        , N'感谢您下订单!' AS t9
        , OH.Externorderkey AS Externorderkey
        , N'快递单号: ' AS t10
        , OH.TrackingNo
        , S.RetailSKU
        , N'UPC' AS t11
   FROM ORDERS OH (NOLOCK) 
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = OH.StorerKey AND S.Sku = OD.Sku
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'AGPACKLIST' AND CL.Storerkey = 'AG'
   WHERE OH.OrderKey = @c_Orderkey
   
   /*
   SELECT @n_MaxRec = COUNT(RowID)                 
   FROM #TMP_PL84                 
             
   SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                
                
   WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
   BEGIN                 
                
      INSERT INTO #TMP_PL84 (
            C_contact1 
          , C_Phone1   
          , C_Addresses
          , Orderkey   
          , OrderDate  
          , Sku        
          , Descr      
          , OriginalQty
          , Logo       
          , t1         
          , t2         
          , t3         
          , t4         
          , t5         
          , t6         
          , t7         
          , t8         
          , t9         
          , Externorderkey
          , t10
          , TrackingNo
          , RetailSKU
          , t11
      )            
      SELECT TOP 1
           C_contact1 
         , C_Phone1   
         , C_Addresses
         , Orderkey   
         , OrderDate  
         , NULL               
         , NULL
         , NULL
         , Logo       
         , t1         
         , t2         
         , t3         
         , t4         
         , t5         
         , t6         
         , t7         
         , t8         
         , t9 
         , Externorderkey
         , t10
         , TrackingNo
         , NULL
         , t11
      FROM #TMP_PL84                           
                
      SET @n_CurrentRec = @n_CurrentRec + 1                       
   END                 
                
   SET @n_MaxRec = 0                
   SET @n_CurrentRec = 0  */                       
                
   SELECT  C_Contact1 
         , C_Phone1   
         , C_Addresses
         , Orderkey   
         , OrderDate  
         , Sku        
         , Descr      
         , OriginalQty
         , Logo       
         , t1         
         , t2         
         , t3         
         , t4         
         , t5         
         , t6         
         , t7         
         , t8         
         , t9  
         , Externorderkey
         , t10
         , TrackingNo
         , RetailSKU
         , t11
   FROM #TMP_PL84                 
   ORDER BY Orderkey, CASE WHEN ISNULL(SKU,'') = '' THEN 1 ELSE 0 END            
   
   IF OBJECT_ID('tempdb..#TMP_PL84') IS NOT NULL
      DROP TABLE #TMP_PL84
END

GO