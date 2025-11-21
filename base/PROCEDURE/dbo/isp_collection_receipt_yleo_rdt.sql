SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_Collection_Receipt_YLEO_rdt                     */    
/* Creation Date: 03-MAY-2020                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-16913 - PH_YLEO_COLLECTION_RECEIPT_REPORT                */    
/*                                                                       */    
/* Called By: report dw = r_dw_collection_receipt_YLEO_rdt               */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author     Ver. Purposes                                 */     
/*************************************************************************/    
CREATE PROC [dbo].[isp_Collection_Receipt_YLEO_rdt] (    
      @c_Orderkey      NVARCHAR(10)  
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @c_CODSKU           NVARCHAR(20) = 'COD'
         , @c_ExternOrderkey   NVARCHAR(50) = ''
         , @n_OrderInfo03      DECIMAL(30,2) = 0.00
   
   DECLARE @b_COD INT = 0
   
   IF EXISTS (SELECT TOP 1 1 FROM ORDERDETAIL (NOLOCK)
              WHERE OrderKey = @c_Orderkey AND SKU = @c_CODSKU
              AND UserDefine02 = 'PN')
   BEGIN
      SET @b_COD = 1 
   END
   
   CREATE TABLE #TMP_Data (
        UserDefine06     NVARCHAR(30)
      , C_Addresses      NVARCHAR(255)
      , C_VAT            NVARCHAR(50)
      , C_Contact1       NVARCHAR(100)
      , ExternOrderKey   NVARCHAR(50)
      , OrderInfo03      DECIMAL(30,2)
      , CODStatus        NVARCHAR(10)
   )
   
   INSERT INTO #TMP_Data (
        UserDefine06  
      , C_Addresses   
      , C_VAT         
      , C_Contact1    
      , ExternOrderKey
      , OrderInfo03   
      , CODStatus     
   )
   
   SELECT DISTINCT
          CONVERT(NVARCHAR(12), OH.UserDefine06, 107) AS UserDefine06
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + SPACE(1) + 
          LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_City,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_State,''))) + SPACE(1) +
          LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Addresses
        , OH.C_VAT
        , OH.C_Contact1
        , OD.ExternOrderKey
        , CASE WHEN ISNUMERIC(OIF.OrderInfo03) = 1 THEN CAST(OIF.OrderInfo03 AS DECIMAL(30,2)) ELSE 0.00 END AS OrderInfo03
        , CASE WHEN @b_COD = 1 THEN 'COD' ELSE 'Non-COD' END AS CODStatus
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey
   WHERE OH.OrderKey = @c_Orderkey
   AND OD.SKU NOT IN ('CASH','COD') AND OD.UserDefine02 NOT IN ('PN')
   
   SELECT UserDefine06  
        , C_Addresses   
        , C_VAT         
        , C_Contact1    
        , ExternOrderKey
        , OrderInfo03   
        , CODStatus     
        , UPPER(dbo.fnc_NumberToWords(OrderInfo03,'','PESOS','centavos only','')) AS AmtInWord	
   FROM #TMP_Data 
   
   IF OBJECT_ID('tempdb..#TMP_Data') IS NOT NULL
      DROP TABLE #TMP_Data

END  

GO