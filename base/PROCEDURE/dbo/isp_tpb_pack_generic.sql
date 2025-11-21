SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Pack_Generic                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for Generic Pack Transaction                    */      
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

CREATE PROC [dbo].[isp_TPB_Pack_Generic]
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
              @c_SQLCondition       NVARCHAR(4000),
              @c_SQLGroup        NVARCHAR(4000)     
   
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


   SET @c_SQLGroup =      ' GROUP BY UPPER(RTRIM(O.Facility)) ' +
                  ',PH.AddDate ' +
                  ',PH.AddWho ' +
                  ',PH.EditDate ' +
                  ',PH.EditWho ' +
                  ',RTRIM(PH.Status) ' +
                  ',RTRIM(O.Type) ' +
                  ',RTRIM(OD.OrderKey) ' +
                  ',RTRIM(OD.OrderLineNumber) ' +
                  ',RTRIM(O.ExternOrderKey) ' +  
                  ',UPPER(RTRIM(O.StorerKey)) ' +
                  ',RTRIM(O.ConsigneeKey) ' +
                  ',RTRIM(O.C_Company) ' +
                  ',RTRIM(O.C_Country) ' +
                  ',RTRIM(PH.LoadKey) ' +
                  ',RTRIM(O.MBOLKey) ' +
                  ',RTRIM(O.Priority) ' +
                  ',UPPER(RTRIM(PD.SKU)) ' +
                  ',RTRIM(OD.UOM) ' +
                  ',RTRIM(OD.Lottable01)' +
                  ',RTRIM(OD.Lottable02)' +
                  ',RTRIM(OD.Lottable03)' +
                  ',OD.Lottable04' +
                  ',OD.Lottable05' +
                  ',RTRIM(OD.Lottable06)' +
                  ',RTRIM(OD.Lottable07)' +
                  ',RTRIM(OD.Lottable08)' +
                  ',RTRIM(OD.Lottable09)' +
                  ',RTRIM(OD.Lottable10)' +
                  ',RTRIM(OD.Lottable11)' +
                  ',RTRIM(OD.Lottable12)' +
                  ',OD.Lottable13' +
                  ',OD.Lottable14' +
                  ',OD.Lottable15' +
                  ',RTRIM(O.UserDefine01)' +
                  ',RTRIM(O.UserDefine02)' +
                  ',RTRIM(O.UserDefine03)' +
                  ',RTRIM(O.UserDefine04)' +
                  ',RTRIM(O.UserDefine05)' +
                  ',RTRIM(O.UserDefine06)' +
                  ',RTRIM(O.UserDefine07)' +
                  ',RTRIM(O.UserDefine08)' +
                  ',RTRIM(O.UserDefine09)' +
                  ',RTRIM(O.UserDefine10)' +
                  ',RTRIM(O.UserDefine01)' +
                  ',RTRIM(O.UserDefine02)' +
                  ',RTRIM(O.UserDefine03)' +
                  ',RTRIM(O.UserDefine04)' +
                  ',RTRIM(O.UserDefine05)' +
                  ',RTRIM(O.UserDefine06)' +
                  ',RTRIM(O.UserDefine07)' +
                  ',RTRIM(O.UserDefine08)' +
                  ',RTRIM(O.UserDefine09)' +
                  ',RTRIM(O.UserDefine10)' +      
                  ',RTRIM(PH.PickSlipNo) ' +
                  ',RTRIM(C.SUSR1)' +
                  ',RTRIM(C.SUSR2)' +
                  ',RTRIM(C.SUSR3)' +
                  ',RTRIM(C.SUSR4)' +
                  ',RTRIM(C.SUSR5)' +
                  ',RTRIM(C.CustomerGroupCode) ' +
                  ',RTRIM(C.MarketSegment) ' +      
                  ',RTRIM(S.DESCR)' +
                  ',RTRIM(S.SUSR1)' +
                  ',RTRIM(S.SUSR2)' +
                  ',RTRIM(S.SUSR3)' +
                  ',RTRIM(S.SUSR4)' +
                  ',RTRIM(S.SUSR5)' +
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
                  ',RTRIM(S.BUSR1)' +
                  ',RTRIM(S.BUSR2)' +
                  ',RTRIM(S.BUSR3)' +
                  ',RTRIM(S.BUSR4)' +
                  ',RTRIM(S.BUSR5)' +
                  ',RTRIM(S.BUSR6)' +
                  ',RTRIM(S.BUSR7)' +
                  ',RTRIM(S.BUSR8)' +
                  ',RTRIM(S.BUSR9)' +
                  ',RTRIM(S.BUSR10)' +
                  ',RTRIM(PACK.CaseCnt) ' +
                  ',PH.EditDate '

   SET @c_SQLStatement = 
               N'SELECT @n_WMS_BatchNo ' +
                  ',@n_TPB_Key '+
                  ',''A'' ' +                  -- A = ACTIVITIES
                  ',''PACK'' ' +
                  ',@c_COUNTRYISO ' +
                  ',UPPER(RTRIM(O.Facility)) ' +
                  ',PH.AddDate ' +
                  ',PH.AddWho ' +
                  ',PH.EditDate ' +
                  ',PH.EditWho ' +
                  ',''WMS'' ' +
                  ',RTRIM(PH.Status) ' +
                  ',''P'' ' +
                  ',RTRIM(O.Type) ' +
                  ',RTRIM(OD.OrderKey) ' +
                  ',RTRIM(OD.OrderLineNumber) ' +
                  ',RTRIM(O.ExternOrderKey) ' +  
                  ',UPPER(RTRIM(O.StorerKey)) ' +
                  ',RTRIM(O.ConsigneeKey) ' +
                  ',RTRIM(O.C_Company) ' +
                  ',RTRIM(O.C_Country) ' +
                  ',RTRIM(PH.LoadKey) ' +
                  ',RTRIM(O.MBOLKey) ' +
                  ',RTRIM(O.Priority) ' +
                  ',UPPER(RTRIM(PD.SKU)) ' +
                  ',SUM(PD.QTY) ' +
                  ',RTRIM(OD.UOM) ' +
                  ',RTRIM(OD.Lottable01)' +
                  ',RTRIM(OD.Lottable02)' +
                  ',RTRIM(OD.Lottable03)' +
                  ',OD.Lottable04' +
                  ',OD.Lottable05' +
                  ',RTRIM(OD.Lottable06)' +
                  ',RTRIM(OD.Lottable07)' +
                  ',RTRIM(OD.Lottable08)' +
                  ',RTRIM(OD.Lottable09)' +
                  ',RTRIM(OD.Lottable10)' +
                  ',RTRIM(OD.Lottable11)' +
                  ',RTRIM(OD.Lottable12)' +
                  ',OD.Lottable13' +
                  ',OD.Lottable14' +
                  ',OD.Lottable15' +
                  ',RTRIM(O.UserDefine01)' +
                  ',RTRIM(O.UserDefine02)' +
                  ',RTRIM(O.UserDefine03)' +
                  ',RTRIM(O.UserDefine04)' +
                  ',RTRIM(O.UserDefine05)' +
                  ',RTRIM(O.UserDefine06)' +
                  ',RTRIM(O.UserDefine07)' +
                  ',RTRIM(O.UserDefine08)' +
                  ',RTRIM(O.UserDefine09)' +
                  ',RTRIM(O.UserDefine10)' +
                  ',RTRIM(O.UserDefine01)' +
                  ',RTRIM(O.UserDefine02)' +
                  ',RTRIM(O.UserDefine03)' +
                  ',RTRIM(O.UserDefine04)' +
                  ',RTRIM(O.UserDefine05)' +
                  ',RTRIM(O.UserDefine06)' +
                  ',RTRIM(O.UserDefine07)' +
                  ',RTRIM(O.UserDefine08)' +
                  ',RTRIM(O.UserDefine09)' +
                  ',RTRIM(O.UserDefine10)' +      
                  ',RTRIM(PH.PickSlipNo) ' +
                  ',RTRIM(C.SUSR1)' +
                  ',RTRIM(C.SUSR2)' +
                  ',RTRIM(C.SUSR3)' +
                  ',RTRIM(C.SUSR4)' +
                  ',RTRIM(C.SUSR5)' +
                  ',RTRIM(C.CustomerGroupCode) ' +
                  ',RTRIM(C.MarketSegment) ' +      
                  ',RTRIM(S.DESCR)' +
                  ',RTRIM(S.SUSR1)' +
                  ',RTRIM(S.SUSR2)' +
                  ',RTRIM(S.SUSR3)' +
                  ',RTRIM(S.SUSR4)' +
                  ',RTRIM(S.SUSR5)' +
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
                  ',RTRIM(S.BUSR1)' +
                  ',RTRIM(S.BUSR2)' +
                  ',RTRIM(S.BUSR3)' +
                  ',RTRIM(S.BUSR4)' +
                  ',RTRIM(S.BUSR5)' +
                  ',RTRIM(S.BUSR6)' +
                  ',RTRIM(S.BUSR7)' +
                  ',RTRIM(S.BUSR8)' +
                  ',RTRIM(S.BUSR9)' +
                  ',RTRIM(S.BUSR10)' +
                  ',RTRIM(PACK.CaseCnt) ' +
                  ',PH.EditDate ' 

      SET @c_SQLStatement =  @c_SQLStatement +                               
                  N'FROM dbo.PACKHEADER PH (NOLOCK) ' +
                  'JOIN dbo.PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo ' +
                  'JOIN dbo.Orders O (NOLOCK) ON O.OrderKey=PH.OrderKey ' +
                  'JOIN dbo.Orderdetail OD (NOLOCK) ON OD.OrderKey=O.Orderkey ' +
                  ' AND OD.StorerKey=PD.StorerKey AND OD.SKU=PD.SKU ' +
                  'JOIN dbo.SKU S (NOLOCK) ON S.StorerKey=OD.StorerKey AND S.SKU=OD.SKU ' +
                  'JOIN dbo.PACK (NOLOCK) ON PACK.PackKey=S.PACKKey ' +
                  'JOIN DBO.Facility F (NOLOCK) ON F.Facility=O.Facility ' +
                  'LEFT JOIN DBO.Storer C (NOLOCK) ON C.StorerKey=O.ConsigneeKey ' +
                  'WHERE PH.Status = ''9'' ' +
                  'AND PH.EditDate between @d_Fromdate and @d_Todate ' +
                  @c_SQLCondition + @c_SQLGroup 
   
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
     ,PRIORITY 
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
     ,PICK_SLIP_NO
     ,STR_SUSR1
     ,STR_SUSR2
     ,STR_SUSR3
     ,STR_SUSR4
     ,STR_SUSR5
     ,STR_CLIENT_GROUP
     ,STR_SEGMENT     
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
     --,FT_USD_01
     --,FT_USD_02
     --,FT_USD_03
     --,FT_USD_04
     --,FT_USD_05
     --,FT_USD_06
     --,FT_USD_07
     --,FT_USD_08
     --,FT_USD_09
     --,FT_USD_10
     --,FT_USD_11
     --,FT_USD_12
     --,FT_USD_13
     --,FT_USD_14
     --,FT_USD_15
     --,FT_USD_16
     --,FT_USD_17
     --,FT_USD_18
     --,FT_USD_19 
     --,FT_USD_20
     ,BILLABLE_DATE  )    
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
    SET @n_RecCOUNT = @@ROWCOUNT

      IF @n_debug = 1
      BEGIN
         PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
         PRINT ''
      END 
 END

GO