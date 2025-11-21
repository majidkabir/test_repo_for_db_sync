SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Pack_Carters                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Carter Pack Transaction                 */      
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


CREATE PROC [dbo].[isp_TPB_Pack_Carters]
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
       
   Declare @d_Todate DATETIME
   Declare @d_Fromdate DATETIME
   Declare @c_COUNTRYISO nvarchar(5)
   
   DECLARE @c_SQLStatement       NVARCHAR(MAX),
              @c_SQLParm            NVARCHAR(4000),
              @c_SQLCondition       NVARCHAR(4000)  
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate --CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_Todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0
   
   --   3 char CountryISO code
   SELECT @c_COUNTRYISO = UPPER(ISNULL(RTRIM(NSQLValue), '')) FROM dbo.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'CountryISO'
   
   -- filtering condition 
   SELECT @c_SQLCondition = ISNULL(SQLCondition,'') FROM TPB_Config WITH (NOLOCK) WHERE TPB_Key = @n_TPB_Key   
   
   -- format the filtering condition   
   IF ISNULL(RTRIM(@c_SQLCondition) ,'') <> ''
   BEGIN
      SET @c_SQLCondition = ' AND ' + @c_SQLCondition 
   END
   
   -- Dynamic SQL
   SET @c_SQLStatement = 
      N'SELECT @n_WMS_BatchNo ' +
      ',@n_TPB_Key '+
      ',''A'' ' +          -- A = ACTIVITIES
      ',''PACK'' ' +
      ',@c_COUNTRYISO ' +
      ',UPPER(RTRIM(Orders.Facility)) ' +
      ',PACKHEADER.AddDate ' +
      ',PACKHEADER.AddWho ' +
      ',PACKHEADER.EditDate ' +
      ',PACKHEADER.EditWho ' +
      ',''WMS'' ' +
      ',RTRIM(PACKHEADER.[Status]) ' +
      ',''P'' ' +
      ',RTRIM(ORDERS.[Type]) ' +
      ',RTRIM(Orderdetail.OrderKey) ' +
      ',RTRIM(Orderdetail.OrderLineNumber) ' +
      ',RTRIM(ORDERS.ExternOrderKey) ' +  
      ',UPPER(RTRIM(ORDERS.StorerKey)) ' +
      ',RTRIM(ORDERS.ConsigneeKey) ' +
      ',RTRIM(ORDERS.C_Company) ' +
      ',RTRIM(ORDERS.C_Country) ' +
      ',RTRIM(PACKHEADER.LoadKey) ' +
      ',RTRIM(ORDERS.MBOLKey) ' +
      ',RTRIM(Orders.BuyerPO) ' +
      ',RTRIM(ORDERS.[Priority]) ' +
      ',ORDERS.DELIVERYDATE ' +
      ',UPPER(RTRIM(PACKDETAIL.SKU)) ' +
      ',PACKDETAIL.QTY ' +
      ',RTRIM(ORDERDETAIL.UOM) ' +
      ',RTRIM(ORDERDETAIL.Lottable01) ' +
      ',RTRIM(ORDERDETAIL.Lottable02) ' +
      ',RTRIM(ORDERDETAIL.Lottable03) ' +
      ',ORDERDETAIL.Lottable04 ' +
      ',ORDERDETAIL.Lottable05 ' +
      ',RTRIM(ORDERDETAIL.Lottable06) ' +
      ',RTRIM(ORDERDETAIL.Lottable07) ' +
      ',RTRIM(ORDERDETAIL.Lottable08) ' +
      ',RTRIM(ORDERDETAIL.Lottable09) ' +
      ',RTRIM(ORDERDETAIL.Lottable10) ' +
      ',RTRIM(ORDERDETAIL.Lottable11) ' +
      ',RTRIM(ORDERDETAIL.Lottable12) ' +
      ',ORDERDETAIL.Lottable13 ' +
      ',ORDERDETAIL.Lottable14 ' +
      ',ORDERDETAIL.Lottable15 ' +
      ',RTRIM(ORDERS.UserDefine01) ' +
      ',RTRIM(ORDERS.UserDefine02) ' +
      ',RTRIM(ORDERS.UserDefine03) ' +
      ',RTRIM(ORDERS.UserDefine04) ' +
      ',RTRIM(ORDERS.UserDefine05) ' +
      ',RTRIM(ORDERS.UserDefine06) ' +
      ',RTRIM(ORDERS.UserDefine07) ' +
      ',RTRIM(ORDERS.UserDefine08) ' +
      ',RTRIM(ORDERS.UserDefine09) ' +
      ',RTRIM(ORDERS.UserDefine10) ' +
      ',RTRIM(ORDERS.UserDefine01) ' +
      ',RTRIM(ORDERS.UserDefine02) ' +
      ',RTRIM(ORDERS.UserDefine03) ' +
      ',RTRIM(ORDERS.UserDefine04) ' +
      ',RTRIM(ORDERS.UserDefine05) ' +
      ',RTRIM(ORDERS.UserDefine06) ' +
      ',RTRIM(ORDERS.UserDefine07) ' +
      ',RTRIM(ORDERS.UserDefine08) ' +
      ',RTRIM(ORDERS.UserDefine09) ' +
      ',RTRIM(ORDERS.UserDefine10) ' +
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
      ',RTRIM(PACK.CaseCnt) ' 

   SET @c_SQLStatement = @c_SQLStatement +
            N'FROM PACKHEADER (NOLOCK) ' +
            'JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PackHeader.PickSlipNo ' +
            'JOIN Orders (NOLOCK) ON ORDERS.OrderKey = PackHeader.OrderKey ' +
            'JOIN Orderdetail (NOLOCK) ON Orderdetail.OrderKey = PackHeader.OrderKey ' +
            ' AND Orderdetail.StorerKey =  PACKDETAIL.StorerKey AND Orderdetail.SKU =  PACKDETAIL.SKU ' +
            'JOIN SKU (NOLOCK) ON SKU.StorerKey = PackDetail.StorerKey AND SKU.SKU = PackDetail.SKU ' +
            'JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey ' +
            'WHERE PACKHEADER.Status = ''9'' ' +
            'AND PACKHEADER.EditDate between @d_Fromdate and @d_Todate ' +
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
          
      -- INSERT Data
      INSERT INTO [DBO].[WMS_TPB_BASE](
      BatchNo 
      , CONFIG_ID
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
     ,DOCUMENT_ID 
     ,DOCUMENT_LINE_NO 
     ,CLIENT_REF 
     ,CLIENT_ID 
     ,SHIP_TO_ID 
     ,SHIP_TO_COMPANY 
     ,SHIP_TO_COUNTRY 
     ,LOAD_PLAN_NO 
     ,MBOL_NO 
     ,OTHER_REFERENCE_1 
     ,[PRIORITY]
     ,REFERENCE_DATE 
     ,SKU_ID 
     ,BILLABLE_QUANTITY 
     ,QTY_UOM 
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
     ,SKU_CASECNT )    
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
    SET @n_RecCOUNT = @@ROWCOUNT

      IF @n_debug = 1
      BEGIN
         PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
         PRINT ''
      END 
 END

GO