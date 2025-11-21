SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_sales_invoice_ph_yleo_rdt                       */    
/* Creation Date: 03-MAY-2020                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-16914 - PH_YLEO_Sales_Invoice_Report                     */    
/*                                                                       */    
/* Called By: report dw = r_dw_sales_invoice_ph_yleo_rdt                 */    
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
CREATE PROC [dbo].[isp_sales_invoice_ph_yleo_rdt] (    
      @c_Orderkey      NVARCHAR(10)  
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @n_Continue            INT = 1
         , @n_VAT                 DECIMAL(30,2) = 0.00
         , @n_TotalUnitPrice      DECIMAL(30,2) = 0.00
         , @n_UnitPrice           DECIMAL(30,2) = 0.00

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      CREATE TABLE #TMP_Data (
           RowID            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , C_Addresses      NVARCHAR(255)
         , C_VAT            NVARCHAR(50)
         , C_Contact1       NVARCHAR(100)
         , TodayDate        NVARCHAR(30)
         , ExternOrderKey   NVARCHAR(50)
         , C_Company        NVARCHAR(100)
         , OriginalQty      INT
         , SKU              NVARCHAR(20)
         , DESCR            NVARCHAR(255)
         , UnitPrice        DECIMAL(30,2)
         , ExtendedPrice    DECIMAL(30,2)
         , CarrierCharges   DECIMAL(30,2)
         , VAT              DECIMAL(30,2)
         , OrderInfo03      DECIMAL(30,2)
         , UserDefine06     NVARCHAR(30)
         , ShipperKey       NVARCHAR(15)
         , PackEditDate     NVARCHAR(20)
      )
      
      INSERT INTO #TMP_Data (
           C_Addresses   
         , C_VAT         
         , C_Contact1    
         , TodayDate
         , ExternOrderKey
         , C_Company
         , OriginalQty
         , SKU
         , DESCR
         , UnitPrice
         , ExtendedPrice
         , CarrierCharges
         , VAT
         , OrderInfo03   
         , UserDefine06
         , ShipperKey   
         , PackEditDate  
      )
      
      SELECT LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + SPACE(1) + 
             LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_City,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_State,''))) + SPACE(1) +
             LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Addresses
           , OH.C_VAT
           , OH.C_Contact1
           , CONVERT(NVARCHAR(12), GETDATE(), 107)
           , OD.ExternOrderKey
           , OH.C_Company
           , OD.OriginalQty
           , OD.SKU
           , S.DESCR
           , OD.UnitPrice
           , ISNULL(OD.ExtendedPrice,0) AS ExtendedPrice
           , ISNULL(OIF.CarrierCharges,0) AS CarrierCharges
           , 0.00
           , CASE WHEN ISNUMERIC(OIF.OrderInfo03) = 1 THEN CAST(OIF.OrderInfo03 AS DECIMAL(30,2)) ELSE 0.00 END AS OrderInfo03
           , CONVERT(NVARCHAR(12), OH.UserDefine06, 107) AS UserDefine06
           , OH.ShipperKey
           , GETDATE()
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
      LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU
      WHERE OH.OrderKey = @c_Orderkey
      AND (OD.UserDefine02 IN ('S','K','B') OR ISNULL(S.BUSR5,'') = 'Y')
      AND (OD.Lottable01 = CASE WHEN (OD.UserDefine02 IN ('S','B') AND ISNULL(S.BUSR5,'') <> 'Y') THEN '' ELSE OD.Lottable01 END
           OR OD.Lottable01 = CASE WHEN (OD.UserDefine02 IN ('S','B') AND ISNULL(S.BUSR5,'') <> 'Y') THEN OD.SKU ELSE OD.Lottable01 END)
      ORDER BY OD.ExternLineNo, OD.Sku
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UnitPrice
      FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = @c_Orderkey AND UserDefine02 = 'N'
      AND SKU IN ('PHVT','SHIPTAX')
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @n_UnitPrice
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_TotalUnitPrice = @n_TotalUnitPrice + @n_UnitPrice
         
         FETCH NEXT FROM CUR_LOOP INTO @n_UnitPrice
      END
      
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      UPDATE #TMP_Data
      SET VAT = @n_TotalUnitPrice
   END

   SELECT   UserDefine06
          , C_Addresses   
          , C_VAT         
          , C_Contact1    
          , ExternOrderKey
          , OrderInfo03
          , TodayDate
          , C_Company
          , OriginalQty
          , SKU
          , DESCR
          , UnitPrice
          , ExtendedPrice
          , CarrierCharges
          , VAT
          , ShipperKey   
          , PackEditDate  
   FROM #TMP_Data 
   ORDER BY RowID ASC

   IF OBJECT_ID('tempdb..#TMP_Data') IS NOT NULL
      DROP TABLE #TMP_Data

END  

GO