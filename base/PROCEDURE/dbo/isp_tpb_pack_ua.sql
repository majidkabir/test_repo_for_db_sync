SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Pack_UA                                    */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for UA Pack Transaction                         */      
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
 


CREATE PROC [dbo].[isp_TPB_Pack_UA]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key BIGINT,
@d_BillDate Date,
@n_RecCOUNT INT = 0 OUTPUT,
@c_storerkey NVARCHAR(15) = '',
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
              @c_SQLParm         NVARCHAR(4000),
              @c_SQLCondition    NVARCHAR(4000),
              @c_SQLGroup        NVARCHAR(MAX)    
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
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

   SET @c_SQLGroup =' GROUP BY UPPER(RTRIM(Orders.Facility)) '+
            ',PH.AddDate '+
            ',PH.AddWho '+
            ',PH.EditDate '+
            ',PH.EditWho '+
            ',RTRIM(PH.Status) '+
            ',RTRIM(ORDERS.Type) '+
            ',RTRIM(ORDERS.OrderKey) '+
            ',RTRIM(PID.OrderLineNumber) '+    
            ',RTRIM(ORDERS.ExternOrderKey) '+  
            ',UPPER(RTRIM(ORDERS.StorerKey)) '+
            ',RTRIM(ORDERS.ConsigneeKey) '+
            ',RTRIM(ORDERS.C_Company) '+
            ',RTRIM(ORDERS.C_Country) '+
            ',RTRIM(ORDERS.LoadKey) '+
            ',RTRIM(ORDERS.MBOLKey) '+
            ',RTRIM(PD2.Labelno) '+
            ',RTRIM(ORDERS.Priority) '+
            ',UPPER(RTRIM(PID.SKU)) '+   
            ',RTRIM(ORDERS.UserDefine01) '+
            ',RTRIM(ORDERS.UserDefine02) '+
            ',RTRIM(ORDERS.UserDefine03) '+
            ',RTRIM(ORDERS.UserDefine04) '+
            ',RTRIM(ORDERS.UserDefine05) '+
            ',RTRIM(ORDERS.UserDefine06) '+
            ',RTRIM(ORDERS.UserDefine07) '+
            ',RTRIM(ORDERS.UserDefine08) '+
            ',RTRIM(ORDERS.UserDefine09) '+
            ',RTRIM(ORDERS.UserDefine10) '+
            ',RTRIM(PH.Pickslipno) '+
            ',RTRIM(PID.Pickmethod) '+
            ',RTRIM(S.DESCR) '+
            ',RTRIM(S.SUSR1) '+
            ',RTRIM(S.SUSR2) '+
            ',RTRIM(S.SUSR3) '+
            ',RTRIM(S.SUSR4) '+
            ',RTRIM(S.SUSR5) '+
            ',S.STDGROSSWGT '+
            ',S.STDNETWGT '+
            ',Convert(numeric(20, 6), S.STDCUBE) '+
            ',RTRIM(S.CLASS) '+
            ',RTRIM(S.SKUGROUP) '+
            ',RTRIM(S.ItemClass) '+
            ',RTRIM(S.Style)  '+
            ',RTRIM(S.Color) '+
            ',RTRIM(S.Size) '+
            ',RTRIM(S.Measurement) '+
            ',RTRIM(S.IVAS) '+
            ',RTRIM(S.OVAS) '+
            ',RTRIM(S.HazardousFlag)  '+
            ',RTRIM(S.TemperatureFlag) '+
            ',RTRIM(S.ProductModel) '+
            ',RTRIM(S.PrePackIndicator) '+
            ',RTRIM(S.BUSR1) '+
            ',RTRIM(S.BUSR2) '+
            ',RTRIM(S.BUSR3) '+
            ',RTRIM(S.BUSR4) '+
            ',RTRIM(S.BUSR5) '+
            ',RTRIM(S.BUSR6) '+
            ',RTRIM(S.BUSR7) '+
            ',RTRIM(S.BUSR8) '+
            ',RTRIM(S.BUSR9) '+
            ',RTRIM(S.BUSR10)'+ 
            ',RTRIM(L.Lottable01) '+ 
            ',RTRIM(L.Lottable02) '+
            ',RTRIM(L.Lottable03) '+
            ',L.Lottable04 '+
            ',L.Lottable05 '+
            ',RTRIM(L.Lottable06) '+
            ',RTRIM(L.Lottable07) '+
            ',RTRIM(L.Lottable08) '+
            ',RTRIM(L.Lottable09) '+
            ',RTRIM(L.Lottable10) '+
            ',RTRIM(L.Lottable11) '+
            ',RTRIM(L.Lottable12) '+
            ',L.Lottable13 '+
            ',L.Lottable14 '+
            ',L.Lottable15 '+
            ',PH.EditDate '

         SET @c_SQLStatement = 
            N'SELECT @n_WMS_BatchNo '+
            ',@n_TPB_Key '+
            ',''A'' '+                  -- A = ACTIVITIES
            ',''PACK'' '+
            ',@c_COUNTRYISO '+
            ',UPPER(RTRIM(Orders.Facility)) '+
            ',PH.AddDate '+
            ',PH.AddWho '+
            ',PH.EditDate '+
            ',PH.EditWho '+
            ',''WMS'' '+
            ',RTRIM(PH.Status) '+
            ',''P'' '+
            ',RTRIM(ORDERS.Type) '+
            ',RTRIM(ORDERS.OrderKey) '+
            ',RTRIM(PID.OrderLineNumber) '+   
            ',RTRIM(ORDERS.ExternOrderKey) '+  
            ',UPPER(RTRIM(ORDERS.StorerKey)) '+
            ',RTRIM(ORDERS.ConsigneeKey) '+
            ',RTRIM(ORDERS.C_Company) '+
            ',RTRIM(ORDERS.C_Country) '+
            ',RTRIM(ORDERS.LoadKey) '+
            ',RTRIM(ORDERS.MBOLKey) '+
            ',RTRIM(PD2.Labelno) '+
            ',RTRIM(ORDERS.Priority) '+
            ',UPPER(RTRIM(PID.SKU)) '+   
            ',SUM(PID.Qty) '+
            ',RTRIM(ORDERS.UserDefine01) '+
            ',RTRIM(ORDERS.UserDefine02) '+
            ',RTRIM(ORDERS.UserDefine03) '+
            ',RTRIM(ORDERS.UserDefine04) '+
            ',RTRIM(ORDERS.UserDefine05) '+
            ',RTRIM(ORDERS.UserDefine06) '+
            ',RTRIM(ORDERS.UserDefine07) '+
            ',RTRIM(ORDERS.UserDefine08) '+
            ',RTRIM(ORDERS.UserDefine09) '+
            ',RTRIM(ORDERS.UserDefine10) '+
            ',RTRIM(PH.Pickslipno) '+
            ',RTRIM(PID.Pickmethod) '+
            ',RTRIM(S.DESCR) '+
            ',RTRIM(S.SUSR1) '+
            ',RTRIM(S.SUSR2) '+
            ',RTRIM(S.SUSR3) '+
            ',RTRIM(S.SUSR4) '+
            ',RTRIM(S.SUSR5) '+
            ',S.STDGROSSWGT '+
            ',S.STDNETWGT '+
            ',Convert(numeric(20, 6), S.STDCUBE) '+
            ',RTRIM(S.CLASS) '+
            ',RTRIM(S.SKUGROUP) '+
            ',RTRIM(S.ItemClass) '+
            ',RTRIM(S.Style) '+
            ',RTRIM(S.Color) '+
            ',RTRIM(S.Size) '+
            ',RTRIM(S.Measurement) '+
            ',RTRIM(S.IVAS) '+
            ',RTRIM(S.OVAS) '+
            ',RTRIM(S.HazardousFlag) '+
            ',RTRIM(S.TemperatureFlag) '+
            ',RTRIM(S.ProductModel) '+
            ',RTRIM(S.PrePackIndicator) '+
            ',RTRIM(S.BUSR1) '+
            ',RTRIM(S.BUSR2) '+
            ',RTRIM(S.BUSR3) '+
            ',RTRIM(S.BUSR4) '+
            ',RTRIM(S.BUSR5) '+
            ',RTRIM(S.BUSR6) '+
            ',RTRIM(S.BUSR7) '+
            ',RTRIM(S.BUSR8) '+
            ',RTRIM(S.BUSR9) '+
            ',RTRIM(S.BUSR10)'+ 
            ',RTRIM(L.Lottable01) '+
            ',RTRIM(L.Lottable02) '+
            ',RTRIM(L.Lottable03) '+
            ',L.Lottable04 '+
            ',L.Lottable05 '+
            ',RTRIM(L.Lottable06) '+
            ',RTRIM(L.Lottable07) '+
            ',RTRIM(L.Lottable08) '+
            ',RTRIM(L.Lottable09) '+
            ',RTRIM(L.Lottable10) '+
            ',RTRIM(L.Lottable11) '+
            ',RTRIM(L.Lottable12) '+
            ',L.Lottable13 '+
            ',L.Lottable14 '+
            ',L.Lottable15 '+
            ',PH.EditDate '

      SET @c_SQLStatement = @c_SQLStatement +
               N'FROM dbo.PACKHEADER PH (NOLOCK) '+
               'JOIN dbo.Orders (NOLOCK) ON ORDERS.OrderKey = PH.OrderKey '+
               'JOIN dbo.OrderDetail OD (NOLOCK) ON OD.OrderKey = ORDERS.OrderKey '+
               'JOIN dbo.Pickdetail PID (NOLOCK) ON PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber '+
               'LEFT OUTER JOIN (SELECT PD.PickSlipNo, PD.StorerKey, PD.DropID, PD.LabelNo, SUM(PD.Qty) '+
                  'FROM dbo.PackDetail PD (NOLOCK) '+
                  'WHERE PD.StorerKey = @c_storerkey AND PD.AddDate >= (GetDate() - 60) '+
                  'GROUP BY PD.PickSlipNo, PD.StorerKey, PD.DropID, PD.LabelNo) PD2 (PickSlipNo, storerkey, dropid, Labelno, qty) '+ 
               'ON (PID.DropID=PD2.dropid AND PH.PickSlipNo=PD2.PickSlipNo) '+
               'JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = PID.StorerKey AND S.SKU = PID.SKU '+
               'JOIN dbo.PACK (NOLOCK) ON PACK.PackKey = PID.PACKKey '+
               'JOIN dbo.LOTATTRIBUTE L (NOLOCK) ON L.Lot = PID.Lot '+
               'WHERE PH.Status = ''9'' AND PID.PickMethod=''L'' '+
               'AND PH.EditDate BETWEEN @d_Fromdate AND @d_Todate ' 

      SET @c_SQLStatement = @c_SQLStatement +  @c_SQLCondition + @c_SQLGroup 

   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME ' +
                        ', @d_Todate DATETIME, @c_storerkey Nvarchar(15) '


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
        ,CONFIG_ID
        ,TRANSACTION_TYPE 
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
        ,SKU_ID 
        ,BILLABLE_QUANTITY 
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
        ,PICK_SLIP_NO 
        ,PICK_METHOD 
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
        ,LOT_LOTTABLE_01
        ,LOT_LOTTABLE_02
        ,LOT_LOTTABLE_03
        ,LOT_LOTTABLE_04
        ,LOT_LOTTABLE_05
        ,LOT_LOTTABLE_06
        ,LOT_LOTTABLE_07
        ,LOT_LOTTABLE_08
        ,LOT_LOTTABLE_09
        ,LOT_LOTTABLE_10
        ,LOT_LOTTABLE_11
        ,LOT_LOTTABLE_12
        ,LOT_LOTTABLE_13
        ,LOT_LOTTABLE_14
        ,LOT_LOTTABLE_15
        ,BILLABLE_DATE  )    
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate, @c_storerkey
    SET @n_RecCOUNT = @@ROWCOUNT

      IF @n_debug = 1
      BEGIN
         PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
         PRINT ''
      END 
 END

GO