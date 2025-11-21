SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_cas_Collection_Receipt_YLEO_rdt                 */    
/* Creation Date: 06-JAN-2022                                            */    
/* Copyright: LFL                                                        */    
/* Written by: CHONGCS                                                   */    
/*                                                                       */    
/* Purpose: WMS-18700 - WMS PH YLEO COLLECTION RECEIPT REPORT            */    
/*                                                                       */    
/* Called By: report dw = r_dw_cas_collection_receipt_YLEO_rdt           */    
/*                                                                       */    
/* GitLab Version: 1.2                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author     Ver. Purposes                                 */  
/* 06-JAN-2022  CSCHONG    1.0  Devops Scripts Combine                   */   
/* 07-FEB-2022  CSCHONG    1.1  WMS-18700 revised field logic (CS01)     */
/* 03-Mar-2022  WLChooi    1.2  WMS-18984 Revised Address (WL01)         */
/* 25-May-2022  Mingle     1.3  WMS-19729 Add logic (ML01)               */
/*************************************************************************/    
CREATE PROC [dbo].[isp_cas_Collection_Receipt_YLEO_rdt] (    
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


   DECLARE   @c_moneysymbol      NVARCHAR(20) =  N'₱'
           , @n_balance          DECIMAL(10,2) = 0.00
           , @n_TTLUnitPrice     DECIMAL(10,2)
           , @n_OIF03            DECIMAL(10,2) = 0.00
           , @c_OIF03            NVARCHAR(30) = ''
           , @c_Clkudf01         NVARCHAR(150) = ''
           , @c_Clkudf02         NVARCHAR(150) = ''
           , @c_Clkudf03         NVARCHAR(150) = ''
           , @c_Clkudf04         NVARCHAR(150) = ''
           , @c_Clkudf05         NVARCHAR(150) = ''
           , @c_Clknotes2        NVARCHAR(150) = ''
           , @c_storerkey        NVARCHAR(20) = ''   
           , @c_Reprint          NVARCHAR(1) = 'N'   
           , @c_OHIssue          NVARCHAR(5) = ''  
   
   DECLARE @b_COD INT = 0
   
   --IF EXISTS (SELECT TOP 1 1 FROM ORDERDETAIL (NOLOCK)
   --           WHERE OrderKey = @c_Orderkey AND SKU = @c_CODSKU
   --           AND UserDefine02 = 'PN')
   --BEGIN
   --   SET @b_COD = 1 
   --END

    SELECT @c_storerkey = OH.storerkey,@c_OHIssue = oh.Issued
    FROM ORDERS OH WITH (NOLOCK)
    WHERE OH.orderkey = @c_orderkey 


   IF @c_OHIssue = 'Y'
   BEGIN
         SET @c_Reprint = 'Y'
   END
   
   CREATE TABLE #TMP_ODSKUData (
        Orderkey         NVARCHAR(30)
      , Storerkey        NVARCHAR(255)
      , SKU              NVARCHAR(50)
      , UnitPrice        DECIMAL(10,2)
      , MSUnitprice      NVARCHAR(50)
      , RecNo            INT
 
   )


      INSERT INTO #TMP_ODSKUData
      (
          Orderkey,
          Storerkey,
          SKU,
          UnitPrice,
          MSUnitprice, RecNo
      )
      SELECT OD.OrderKey,OD.StorerKey,OD.sku,CAST(ABS(OD.UnitPrice) AS DECIMAL(10,2)), 
            @c_moneysymbol + SPACE(2) + CAST(FORMAT(ABS(OD.UnitPrice), 'N', 'en-us') AS NVARCHAR(30)),CAST(od.externlineno AS INT)
      FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
      WHERE OD.OrderKey = @c_Orderkey
      AND OD.Userdefine02 in ('PN') 
      ORDER BY Od.OrderKey,OD.sku

      SELECT @c_OIF03 = OIF.orderinfo03
      FROM dbo.OrderInfo OIF WITH (NOLOCK)
      WHERE OIF.OrderKey = @c_Orderkey

      SELECT @n_TTLUnitPrice = SUM(UnitPrice)
      FROM #TMP_ODSKUData  
      WHERE orderkey = @c_Orderkey

     IF ISNUMERIC(@c_OIF03) = 1
     BEGIN
        SET @n_OIF03 = CAST(@c_OIF03 AS DECIMAL(10,2))
     END

     SET @n_balance = @n_OIF03 - @n_TTLUnitPrice

     SELECT @c_Clkudf01 = ISNULL(clk.UDF01,'')
           ,@c_Clkudf02 = ISNULL(clk.UDF02,'')
           ,@c_Clkudf03 = ISNULL(clk.UDF03,'')
           ,@c_Clkudf04 = ISNULL(clk.UDF04,'')
           ,@c_Clkudf05 = ISNULL(clk.UDF05,'')
           ,@c_Clknotes2 = ISNULL(clk.Notes2,'')
     FROM dbo.CODELKUP clk WITH (NOLOCK)
     WHERE clk.LISTNAME='YLDEFVAL' AND clk.Short = 'CR'
     AND Clk.Storerkey = @c_storerkey
   

   
   SELECT            OH.ConsigneeKey
                   , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''))) + SPACE(1) + 
                      LTRIM(RTRIM(ISNULL(OH.C_Address4,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_City,''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_State,''))) + SPACE(1) +
                      LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) AS C_Addresses
                   , OH.C_VAT  
                   , OH.InvoiceNo
                   , OH.ExternOrderKey
                   , CASE WHEN ISNUMERIC(OIF.OrderInfo03) = 1 THEN  @c_moneysymbol + SPACE(2) + CAST(FORMAT(CAST(OIF.OrderInfo03 AS DECIMAL(10,2)), 'N', 'en-us') AS NVARCHAR(20)) 
                        ELSE @c_moneysymbol + SPACE(2) + '0.00)' END AS OrderInfo03              --CS01
                   , OSD.SKU AS sku 
                   , '****' + (dbo.fnc_NumberToWords(OIF.OrderInfo03,'','Pesos','Centavos','')) + '****' AS AmtInWord   
                   ,RptHeaer = 'COLLECTION RECEIPT' 
                   ,RptCompany = 'YOUNG LIVING PHILIPPINES LLC'
                   ,RptConsignee = 'YOUNG LIVING PHILIPPINES LLC - PHILIPPINES BRANCH'
                   ,RptCompanyAddL1 = 'Unit G07, G08 & G09, 12th Floor,'                            --CS01
                   ,RptCompanyAddL2 = 'Twenty-Five Seven McKinley Building, '
                   ,RptCompanyAddL3 = '25th Street corner 7th Avenue, Bonifacio Global City, '
                   ,RptCompanyAddL4 = 'Fort Bonifacio, Taguig City'                                    --CS01   --WL01
                   ,RptCompanyRegCode = 'VAT REG TIN: 009-915-795-000'
                   ,RptBusinessname = 'Other WholeSaling'   
                   , 'No.' + SPACE(2) + OH.UserDefine02 AS OHUDF02
                   , OrdDate = RIGHT('00' + CAST(DAY(OH.OrderDate) AS NVARCHAR(2)),2) +'-' +LEFT(DATENAME(MONTH,OH.OrderDate),3) + '-' + CAST(YEAR(OH.OrderDate) AS NVARCHAR(5))                  
                   , OSD.MSUnitprice AS MSUnitPrice 
                   , @c_moneysymbol + SPACE(1) + CAST(FORMAT(@n_balance, 'N', 'en-us')  AS NVARCHAR(10)) AS Balance         --CS01
                   , 'Accreditation No.'  + SPACE(1) + @c_Clkudf01 AS Remarks1
                   , 'Date of Accreditation:' + SPACE(1) + @c_Clkudf02 AS Remarks2
                   , 'Acknowledgement Certificate No.:' + SPACE(1) + @c_Clkudf03 AS Remarks3           --CS01
                   , 'Date Issued: ' + SPACE(1) + @c_Clkudf04 AS Remarks4
                   , 'Valid Until: ' + SPACE(1) + @c_Clkudf05 AS Remarks4a
                   , 'Approved Series No.:' + SPACE(1) + @c_Clknotes2 AS Remarks5
                   , 'THIS DOCUMENT IS NOT VALID FOR CLAIM OF INPUT TAX' AS RptFooter1
                   , 'THIS INVOICE/RECEIPT SHALL BE VALID FOR FIVE (5) YEARS FROM THE DATE OF THE'  AS RptFooter2
                   , 'ACKNOWLEDGEMENT CERTIFICATE.'  AS Rptfooter2a
                   , CASE WHEN @c_Reprint = 'Y' THEN '** REPRINT **'  ELSE '' END AS Reprint 
                   , OH.C_contact1 AS c_contact1 
                   , 'The Sum of:' AS AmtInWordtitle
				   , ISNULL(C.LONG,'')	--ML01
   FROM ORDERS OH (NOLOCK)
   --JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey
   JOIN #TMP_ODSKUData OSD ON OSD.Storerkey=OH.StorerKey AND OSD.Orderkey=OH.OrderKey
   LEFT JOIN CODELKUP C(NOLOCK) ON C.LISTNAME = 'ylcasinvqr' AND C.Storerkey = OH.StorerKey	--ML01
   WHERE OH.OrderKey = @c_Orderkey
   ORDER BY  OSD.Orderkey, OSD.RecNo
   
IF @c_Reprint = 'N'
BEGIN
    UPDATE [dbo].[ORDERS] WITH (ROWLOCK)        
            SET [Issued] = 'Y',        
                TrafficCop = NULL,        
                EditDate = GETDATE(),        
                EditWho = SUSER_SNAME()        
            WHERE [OrderKey] = @c_OrderKey              
 
END
  
   IF OBJECT_ID('tempdb..#TMP_ODSKUData') IS NOT NULL
      DROP TABLE #TMP_ODSKUData

END  

GO