SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Receipt_PUMA                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for PUMA Receipt Transaction                    */      
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
/* 08-Jun-18    TLTING    1.1   pass in billdate                        */      
/************************************************************************/  

CREATE PROC [dbo].[isp_TPB_Receipt_PUMA]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key BIGINT,
@d_BillDate Date,
@n_RecCOUNT INT = 0 OUTPUT,
@n_debug INT = 0
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF    
   SET NOCOUNT ON    
       
   Declare @d_todate DATETIME
   Declare @d_Fromdate DATETIME
   Declare @c_COUNTRYISO nvarchar(5)
   
   DECLARE @c_SQLStatement       NVARCHAR(MAX),
           @c_SQLParm            NVARCHAR(4000),
           @c_SQLCondition       NVARCHAR(4000) 
   
   -- format date filter yesterday full day           
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0
   
   --   3 char CountryISO code
   SELECT @c_COUNTRYISO = UPPER(ISNULL(RTRIM(NSQLValue), '')) FROM dbo.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'CountryISO'
   
   -- filtering condition 
   SELECT @c_SQLCondition = ISNULL(RTRIM(SQLCondition),'') FROM TPB_Config WITH (NOLOCK) WHERE TPB_Key = @n_TPB_Key   
   
   -- format the filtering condition   
   IF ISNULL(RTRIM(@c_SQLCondition) ,'') <> ''
   BEGIN
      SET @c_SQLCondition = ' AND ' + @c_SQLCondition 
   END
   
   -- SQL
 
  SET @c_SQLStatement =  
      N'SELECT @n_WMS_BatchNo ' +
      ',@n_TPB_Key '+
      ',''A'' ' +                   -- A = ACTIVITIES
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
      ',RTRIM(RECEIPT.ReceiptGroup) ' +
      ',RTRIM(RECEIPT.ReceiptKey) ' +
      ',RTRIM(RD.ReceiptLineNumber) ' +
      ',RTRIM(RD.ExternReceiptKey) ' +
      ',RTRIM(RD.ExternLineNo) ' +
      ',UPPER(RTRIM(RECEIPT.StorerKey)) ' +
      ',UPPER(RTRIM(RECEIPT.Facility)) ' +
      ',RTRIM(RECEIPT.WarehouseReference) ' +
      ',RTRIM(RD.POKey) ' +
      ',RTRIM(RD.ExternPoKey) ' +
      ',RD.DateReceived ' +
      ',UPPER(RTRIM(RD.SKU)) ' +
      ',RD.QtyReceived '  +
      ',RTRIM(RD.UOM) ' +
      ',SKU.GrossWgt ' +
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
      ',RTRIM(SKU.DESCR) ' +
      ',RTRIM(SKU.SUSR1) ' +              
      ',RTRIM(SKU.SUSR2) ' +              
      ',RTRIM(SKU.SUSR3) ' +              
      ',RTRIM(SKU.SUSR4) ' +              
      ',RTRIM(SKU.SUSR5) ' +              
      ',SKU.STDGROSSWGT ' +
      ',SKU.STDNETWGT ' +
      ',SKU.STDCUBE ' +
      ',RTRIM(SKU.CLASS) ' +
      ',RTRIM(SKU.SKUGROUP) ' +
      ',RTRIM(SKU.ItemClass) ' +
      ',RTRIM(SKU.Style) ' +
      ',RTRIM(SKU.Color) ' +
      ',RTRIM(SKU.Size) ' +
      ',RTRIM(SKU.Measurement) ' +
      ',RTRIM(SKU.IVAS) ' +
      ',RTRIM(SKU.OVAS) ' +
      ',RTRIM(SKU.HazardousFlag) ' +
      ',RTRIM(SKU.TemperatureFlag) ' +
      ',RTRIM(SKU.ProductModel) ' +
      ',RTRIM(SKU.PrePackIndicator) ' +
      ',RTRIM(SKU.BUSR1) ' +
      ',RTRIM(SKU.BUSR2) ' +
      ',RTRIM(SKU.BUSR3) ' +
      ',RTRIM(SKU.BUSR4) ' +
      ',RTRIM(SKU.BUSR5) ' +
      ',RTRIM(SKU.BUSR6) ' +
      ',RTRIM(SKU.BUSR7) ' +
      ',RTRIM(SKU.BUSR8) ' +
      ',RTRIM(SKU.BUSR9) ' +
      ',RTRIM(SKU.BUSR10) ' +
      ',RTRIM(PACK.CaseCnt) ' +
      ',RD.DateReceived ' 

  SET @c_SQLStatement =  @c_SQLStatement +         
              N'FROM DBO.RECEIPT (NOLOCK) ' +
              'JOIN DBO.RECEIPTDETAIL RD (nolock) ON RD.RECEIPTKey = RECEIPT.RECEIPTKey ' +
              'LEFT JOIN DBO.PO (nolock) ON PO.POKey =RECEIPT.POKey ' +
              'JOIN DBO.PACK (nolock) ON PACK.PACKKey = RD.PACKKey ' +
              'LEFT JOIN DBO.Storer C with (nolock) ON C.StorerKey = RECEIPT.SellerName ' +
              'JOIN DBO.SKU sku with (nolock) ON SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU ' +
              'LEFT JOIN DBO.FACILITY F (nolock) ON F.Facility =RECEIPT.Facility ' +
              'JOIN DBO.ITRN with (nolock) ON ITRN.SourceKey = RD.Receiptkey + RD.ReceiptLineNumber ' +
              'AND ITRN.SourceType= ''ntrReceiptDetailUpdate'' AND ITRN.trantype =''DP'' ' +
              'JOIN DBO.LOTATTRIBUTE L (nolock) ON L.lot = ITRN.lot ' +
              'WHERE RECEIPT.ASNStatus =''9'' ' +
              'AND RD. QtyReceived > 0 ' +
              'AND RD.DateReceived between @d_Fromdate and @d_Todate ' +  
               @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'
      
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
       
   INSERT INTO [DBO].[WMS_TPB_BASE](
     BatchNo
     , Config_ID
     , TRANSACTION_TYPE
     ,CODE
     ,COUNTRY
     ,SITE_ID
     ,ADD_DATE
     ,ADD_WHO
     ,EDIT_DATE
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
     ,SHIP_TO_ID
     ,OTHER_REFERENCE_1
     ,PO_NO
     ,CLIENT_PO_NO
     ,REFERENCE_DATE
     ,SKU_ID
     ,BILLABLE_QUANTITY
     ,QTY_UOM
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
     ,BILLABLE_DATE
    )
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
    SET @n_RecCOUNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
      PRINT ''
   END
END

GO