SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Receipt_Skechers                           */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Skechers Receipt Transaction            */      
/*                                                                      */      
/* Called By:  isp_TPBExtract                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */ 
/* 3-Apr-2018   TLTING    1.1   Revise externreceiptkey logic           */  
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */       
/************************************************************************/  

CREATE PROC [dbo].[isp_TPB_Receipt_Skechers]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key BIGINT,
@d_BillDate Date,
@n_RecCOUNT INT = 0 OUTPUT,
@c_storerkey NVARCHAR(15)  = '',
@n_debug INT = 0
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF    
   SET NOCOUNT ON    
       
   Declare @d_Todate DATETIME
   Declare @d_Fromdate DATETIME
   Declare @c_COUNTRYISO nvarchar(5)
   
   DECLARE @c_SQLStatement       NVARCHAR(MAX),
              @c_SQLParm            NVARCHAR(4000),
              @c_SQLCondition       NVARCHAR(4000)  
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_Todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0

    IF ISNULL(OBJECT_ID('tempdb..#ReturnEcom'), '') <> ''
        BEGIN
            DROP TABLE #ReturnEcom
        END
           
   --   3 char CountryISO code
   SELECT @c_COUNTRYISO = UPPER(ISNULL(RTRIM(NSQLValue), '')) FROM dbo.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'CountryISO'
   
   -- filtering condition 
   SELECT @c_SQLCondition = ISNULL(SQLCondition,'') FROM TPB_Config WITH (NOLOCK) WHERE TPB_Key = @n_TPB_Key   
   
   -- format the filtering condition   
   IF ISNULL(RTRIM(@c_SQLCondition) ,'') <> ''
   BEGIN
      SET @c_SQLCondition = ' AND ' + @c_SQLCondition 
   END
   
   --Dynamic SQL     

   CREATE TABLE #ReturnEcom
   ( Rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Receiptkey     NVARCHAR( 10) NOT NULL,
      ReceiptDate    DATETIME NULL, 
      Signatory      NVARCHAR(18) NULL,
      UserDefine09   NVARCHAR(30) NULL,
      DateReceived   Datetime NULL
   )

   -- Get ExternReceiptkey
   CREATE TABLE #ExternReceipt
   ( Rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Receiptkey     NVARCHAR( 10) NOT NULL,
      ReceiptLineNumber NVARCHAR(5) NOT NULL,
      ExternReceiptKey	NVARCHAR (20)  NULL ,
      ExternLineNo NVARCHAR(20) NULL
   )

   -- same receipt filter as main SELECT
   INSERT INTO #ExternReceipt (Receiptkey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo)
   SELECT R.ReceiptKey, RD.ReceiptLineNumber, RD.ExternReceiptKey, RD.ExternLineNo
   FROM dbo.Receipt R (NOLOCK) 
   JOIN  dbo.Receiptdetail RD (NOLOCK) ON RD.receiptkey = R.ReceiptKey       
   WHERE R.storerkey = @c_storerkey 
   AND R.ASNStatus = '9'       
   AND RD.DateReceived between @d_Fromdate and @d_Todate 
   ORDER BY R.ReceiptKey, RD.ReceiptLineNumber
   
   -- If is NULL, replace with 1st externreceiptkey (not null)    
   UPDATE #ExternReceipt
   SET ExternReceiptKey = ( SELECT TOP 1 R2.ExternReceiptKey FROM #ExternReceipt R2 
                     WHERE R2.Receiptkey = #ExternReceipt.Receiptkey 
                     AND R2.ExternReceiptKey is NOT NULL AND R2.ExternReceiptKey <> ''
                     ORDER BY R2.ReceiptLineNumber ),
         ExternLineNo = ( SELECT TOP 1 R2.ExternLineNo FROM #ExternReceipt R2 
                     WHERE R2.Receiptkey = #ExternReceipt.Receiptkey 
                     AND R2.ExternReceiptKey is NOT NULL AND R2.ExternReceiptKey <> ''
                     ORDER BY R2.ReceiptLineNumber ) 
    FROM #ExternReceipt      
    WHERE ExternReceiptKey IS NULL OR ExternReceiptKey = ''       

   INSERT INTO #ReturnEcom (Receiptkey, ReceiptDate, Signatory, UserDefine09, DateReceived )
   SELECT ReceiptKey, ReceiptDate, Signatory, UserDefine09, 
      DateReceived = ( SELECT min(DC.AddDate) FROM RDT.rdtDataCapture DC (NOLOCK) where  receipt.VehicleNumber=DC.SerialNo 
      AND DC.storerkey = receipt.storerkey ) 
   FROM receipt (NOLOCK) 
   WHERE doctype='R' AND ReceiptGroup='ECOM'  
   AND storerkey = @c_storerkey AND ASNStatus = '9' AND Editdate > @d_Fromdate 
   
   UPDATE #ReturnEcom
   SET DateReceived =  ( SELECT min(DC.AddDate) FROM RDT.rdtDataCapture DC (NOLOCK) where  R.Signatory=DC.SerialNo 
   AND DC.storerkey = @c_storerkey )
   FROM #ReturnEcom R
   WHERE R.DateReceived IS NULL 


   UPDATE #ReturnEcom
   SET DateReceived = ( SELECT min(DC.AddDate) FROM RDT.rdtDataCapture DC (NOLOCK) where  R.UserDefine09=DC.SerialNo 
                  AND DC.storerkey = @c_storerkey )
   FROM #ReturnEcom R
   WHERE R.DateReceived IS NULL

   UPDATE #ReturnEcom
   SET DateReceived   = ReceiptDate
   FROM #ReturnEcom 
   WHERE DateReceived IS NULL 


   SET @c_SQLStatement =
   N'SELECT @n_WMS_BatchNo' +
   ',@n_TPB_Key '+
   ',''A'' ' +          -- A = ACTIVITIES
   ',''RECEIPT'' ' +
   ',@c_COUNTRYISO ' +
   ',UPPER(RTRIM(RECEIPT.Facility)) ' +
   ',RECEIPT.AddDate ' +
   ',RECEIPT.AddWho ' +
   ',RECEIPT.EditDate ' +
   ',RECEIPT.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(RECEIPT.ASNStatus) ' +
   ',RTRIM(RECEIPT.DocType) ' +
   ',RTRIM(RECEIPT.RECType) ' +
   ',RECEIPT.ReceiptGroup ' +
   ',RTRIM(RECEIPT.ReceiptKey) ' +
   ',RTRIM(RD.ReceiptLineNumber) ' +
   ',RTRIM(TRD.ExternReceiptKey) ' +
   ',RTRIM(TRD.ExternLineNo) ' +
   ',UPPER(RTRIM(RECEIPT.StorerKey)) ' +
   ',RTRIM(PO.SellerName) ' +         
   ',RTRIM(PO.SellerCompany) ' +
   ',RTRIM(PO.SellerCountry) ' +
   ',UPPER(RTRIM(RECEIPT.Facility)) ' +
   ',RTRIM(RECEIPT.WarehouseReference) ' +
   ',RTRIM(RD.POKey) ' +
   ',RTRIM(RD.ExternPoKey) ' +
   ',CASE WHEN RECEIPT.DocType = ''A'' THEN RECEIPT.ReceiptDate ' +             -- REMARKS : The formulation is still not completed
          'WHEN RECEIPT.DocType = ''R'' and RECEIPT.ReceiptGroup <>''ECOM'' THEN RECEIPT.ReceiptDate ' + 
          'WHEN RECEIPT.DocType = ''R'' and RECEIPT.ReceiptGroup = ''ECOM'' THEN ' + 
          '   ( SELECT T.DateReceived FROM #ReturnEcom T (NOLOCK) WHERE T.RECEIPTKey = RECEIPT.RECEIPTKey) ' +
          'END ' +   -- REFERENCE_DATE
   ',UPPER(RTRIM(RD.SKU)) ' +
   ',RD.QtyReceived '  +
   ',RTRIM(RD.UOM) ' +
   ',(CASE WHEN PACK.CASECNT = 0 THEN 0 ELSE (RD.QtyReceived/Pack.Casecnt) END ) ' +
   ',S.GrossWgt ' +
   ',RECEIPT.ContainerQty ' +
   ',RTRIM(RD.VesselKey) ' +
   ',RTRIM(RD.VoyageKey) ' +
   ',RTRIM(RECEIPT.VehicleNumber) ' +
   ',RECEIPT.VehicleDate ' +
   ',RTRIM(RECEIPT.ContainerType) ' +
   ',RTRIM(RECEIPT.ContainerKey) ' +
   ',RTRIM(RD.Lottable01) ' +
   ',RTRIM(RD.Lottable02) ' +                
   ',RTRIM(RD.Lottable03) ' +                 
   ',RD.Lottable04 ' +                 
   ',RD.Lottable05 ' +                 
   ',RTRIM(RD.Lottable06) ' +                 
   ',RTRIM(RD.Lottable07) ' +                 
   ',RTRIM(RD.Lottable08) ' +                 
   ',RTRIM(RD.Lottable09) ' +                 
   ',RTRIM(RD.Lottable10) ' +                 
   ',RTRIM(RD.Lottable11) ' +                 
   ',RTRIM(RD.Lottable12) ' +                 
   ',RD.Lottable13 ' +                 
   ',RD.Lottable14 ' +                 
   ',RD.Lottable15 ' +                 
   ',RTRIM(RECEIPT.UserDefine01) ' +
   ',RTRIM(RECEIPT.UserDefine02) ' +
   ',RTRIM(RECEIPT.UserDefine03) ' +
   ',RTRIM(RECEIPT.UserDefine04) ' +
   ',RTRIM(RECEIPT.UserDefine05) ' +
   ',RTRIM(RECEIPT.UserDefine06) ' +
   ',RTRIM(RECEIPT.UserDefine07) ' +
   ',RTRIM(RECEIPT.UserDefine08) ' +
   ',RTRIM(RECEIPT.UserDefine09) ' +
   ',RTRIM(RECEIPT.UserDefine10) ' +
   ',RTRIM(RD.UserDefine01) ' +
   ',RTRIM(RD.UserDefine02) ' +
   ',RTRIM(RD.UserDefine03) ' +
   ',RTRIM(RD.UserDefine04) ' +
   ',RTRIM(RD.UserDefine05) ' +
   ',RTRIM(RD.UserDefine06) ' +
   ',RTRIM(RD.UserDefine07) ' +
   ',RTRIM(RD.UserDefine08) ' +
   ',RTRIM(RD.UserDefine09) ' +
   ',RTRIM(RD.UserDefine10) ' +
   ',ISNULL(RTRIM(PS.SUSR1),'''')' +
   ',RTRIM(S.DESCR) ' +
   ',RTRIM(S.SUSR1) ' +              
   ',RTRIM(S.SUSR2) ' +              
   ',RTRIM(S.SUSR3) ' +              
   ',RTRIM(S.SUSR4) ' +              
   ',RTRIM(S.SUSR5) ' +              
   ',S.STDGROSSWGT ' +
   ',S.STDNETWGT ' +
   ',S.STDCUBE ' +
   ',RTRIM(S.CLASS) ' +
   ',RTRIM(S.SKUGROUP) ' +
   ',RTRIM(S.ItemClass) ' +
   ',RTRIM(S.Style) ' +
   ',RTRIM(S.Color) ' +
   ',RTRIM(S.Size) ' +
   ',RTRIM(S.Measurement) ' +
   ',RTRIM(S.IVAS) ' +
   ',RTRIM(S.OVAS) ' +
   ',RTRIM(S.HazardousFlag) ' +
   ',RTRIM(S.TemperatureFlag) ' +
   ',RTRIM(S.ProductModel) ' +
   ',RTRIM(S.PrePackIndicator) ' +
   ',RTRIM(S.BUSR1) ' +
   ',RTRIM(S.BUSR2) ' +
   ',RTRIM(S.BUSR3) ' +
   ',RTRIM(S.BUSR4) ' +
   ',RTRIM(S.BUSR5) ' +
   ',RTRIM(S.BUSR6) ' +
   ',RTRIM(S.BUSR7) ' +
   ',RTRIM(S.BUSR8) ' +
   ',RTRIM(S.BUSR9) ' +
   ',RTRIM(S.BUSR10) ' +
   ',PACK.CaseCnt ' +
   ',RTRIM(F.UserDefine01) ' +
   ',ISNULL(RTRIM(PO.SellerAddress1),'''' ) ' +
   ',RECEIPT.EDITDATE '  
 

   SET @c_SQLStatement = @c_SQLStatement +
            N'FROM DBO.RECEIPT (NOLOCK) ' +
           'JOIN DBO.RECEIPTDETAIL RD (nolock) ON RD.RECEIPTKey = RECEIPT.RECEIPTKey ' +
           'JOIN DBO.PACK (nolock) ON PACK.PACKKey = RD.PACKKey ' +
           'JOIN DBO.SKU S with (nolock) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.SKU ' +
           'LEFT JOIN DBO.FACILITY F (nolock) ON F.Facility =RECEIPT.Facility ' +
           'JOIN DBO.ITRN with (nolock) ON ITRN.SourceKey = RD.Receiptkey + RD.ReceiptLineNumber ' +
           'AND ITRN.SourceType= ''ntrReceiptDetailUpdate'' AND ITRN.trantype =''DP'' ' +
           'JOIN DBO.LOTATTRIBUTE L (nolock) ON L.lot = ITRN.lot ' +
           'LEFT JOIN #ExternReceipt AS TRD ON TRD.ReceiptKey = RECEIPT.ReceiptKey AND TRD.ReceiptLineNumber = RD.ReceiptLineNumber ' +
           'LEFT JOIN PO (NOLOCK) ON PO.ExternPOKey = TRD.ExternReceiptKey AND PO.StorerKey = RECEIPT.StorerKey ' + 
           'LEFT JOIN Storer PS (NOLOCK) ON PS.storerkey = ''SK''+PO.SellerName ' +
           'WHERE RECEIPT.ASNStatus =''9'' ' +    
           'AND RD.QtyReceived > 0 ' +
           'AND RD.DateReceived between @d_Fromdate and @d_Todate ' +  
            @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME' +
                        ', @c_Storerkey Nvarchar(15) '
      
      IF @n_debug = 1
      BEGIN
         PRINT 'COUNTRYISO - ' + @c_COUNTRYISO
         PRINT '@c_SQLCondition'
         PRINT @c_SQLCondition
         PRINT '@c_SQLStatement'
         PRINT @c_SQLStatement
         PRINT '@c_SQLParm'
         PRINT @c_SQLParm
      END
   
   INSERT INTO [dbo].[WMS_TPB_BASE](
    BatchNo
    , CONFIG_ID
   ,TRANSACTION_TYPE
   ,CODE
   ,COUNTRY      
   ,SITE_ID
   ,ADD_DATE
   ,ADD_WHO
   ,EDIT_DATE                    --TPB Date diff: RECEIPT.EditDate - RECEIPT.ReceiptDate
   ,EDIT_WHO
   ,DOC_SOURCE
   ,DOC_STATUS
   ,DOC_TYPE
   ,DOC_SUB_TYPE  
   ,DOC_GROUPING_1 
   ,DOCUMENT_ID
   ,DOCUMENT_LINE_NO
   ,CLIENT_REF 
   ,CLIENT_REF_LINE_NO
   ,CLIENT_ID
   ,SHIP_FROM_ID               
   ,SHIP_FROM_COMPANY
   ,SHIP_FROM_COUNTRY
   ,SHIP_TO_ID
   ,OTHER_REFERENCE_1
   ,PO_NO
   ,CLIENT_PO_NO
   ,REFERENCE_DATE
   ,SKU_ID
   ,BILLABLE_QUANTITY                         
   ,QTY_UOM
   ,BILLABLE_CARTON                          
   ,BILLABLE_WEIGHT
   ,BILLABLE_CONTAINER
   ,VESSEL_ID
   ,VOYAGE_ID
   ,VEHICLE_NO
   ,VEHICLE_DATE
   ,CONTAINER_TYPE
   ,CONTAINER_ID
   ,LOTTABLE_01
   ,LOTTABLE_02
   ,LOTTABLE_03
   ,LOTTABLE_04
   ,LOTTABLE_05
   ,LOTTABLE_06
   ,LOTTABLE_07
   ,LOTTABLE_08
   ,LOTTABLE_09
   ,LOTTABLE_10
   ,LOTTABLE_11
   ,LOTTABLE_12
   ,LOTTABLE_13
   ,LOTTABLE_14
   ,LOTTABLE_15
   ,H_USD_01
   ,H_USD_02
   ,H_USD_03
   ,H_USD_04
   ,H_USD_05
   ,H_USD_06
   ,H_USD_07
   ,H_USD_08
   ,H_USD_09
   ,H_USD_10
   ,D_USD_01
   ,D_USD_02
   ,D_USD_03
   ,D_USD_04
   ,D_USD_05
   ,D_USD_06
   ,D_USD_07
   ,D_USD_08
   ,D_USD_09
   ,D_USD_10
   ,STR_SUSR1
   ,SKU_DESCRIPTION
   ,SKU_SUSR1
   ,SKU_SUSR2
   ,SKU_SUSR3
   ,SKU_SUSR4
   ,SKU_SUSR5
   ,SKU_STDGROSSWGT
   ,SKU_STDNETWGT
   ,SKU_STDCUBE
   ,SKU_CLASS
   ,SKU_GROUP
   ,SKU_ITEM_CLASS
   ,SKU_STYLE
   ,SKU_COLOR
   ,SKU_SIZE
   ,SKU_MEASUREMENT
   ,SKU_VAS
   ,SKU_OVAS
   ,SKU_HAZARDOUSFLAG
   ,SKU_TEMPERATUREFLAG
   ,SKU_PRODUCTMODEL
   ,SKU_PREPACKINDICATOR
   ,SKU_BUSR1
   ,SKU_BUSR2
   ,SKU_BUSR3
   ,SKU_BUSR4
   ,SKU_BUSR5
   ,SKU_BUSR6
   ,SKU_BUSR7
   ,SKU_BUSR8
   ,SKU_BUSR9
   ,SKU_BUSR10
   ,SKU_CASECNT
   ,FT_USD_01
   ,FT_USD_20
   ,BILLABLE_DATE
   )
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate, @c_storerkey
    SET @n_RecCOUNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
      PRINT ''
   END
END

GO