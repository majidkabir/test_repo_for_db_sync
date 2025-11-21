SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Orders_Skechers                            */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Skechers Orders Transaction             */      
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

CREATE PROC [dbo].[isp_TPB_Orders_Skechers]
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
              @n_RecCNT    INT  = 0
   
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
   
   --Dynamic SQL
 -- Cancel Order
   SET @c_SQLStatement =
   N'SELECT @n_WMS_BatchNo ' +
   ',@n_TPB_Key '+
   ',''A'' ' +                -- A = ACTIVITIES
   ',''ORDER'' ' +
   ',@c_COUNTRYISO ' +
   ',UPPER(RTRIM(Orders.Facility)) ' +
   ',ORDERS.AddDate ' + 
   ',ORDERS.AddWho ' +
   ',ORDERS.EditDate ' +
   ',ORDERS.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(ORDERS.Status) ' +
   ',RTRIM(ORDERS.DocType) ' +
   ',RTRIM(ORDERS.Type) ' + 
   ',RTRIM(ORDERS.OrderKey) ' +
   ',RTRIM(OD.OrderLineNumber) ' + 
   ',RTRIM(OD.ExternOrderKey) ' +
   ',RTRIM(OD.ExternLineNo) ' +
   ',UPPER(RTRIM(ORDERS.StorerKey)) ' + 
   ',RTRIM(Orders.Facility) ' +
   ',RTRIM(ORDERS.ConsigneeKey) ' +  
   ',RTRIM(ORDERS.C_Company) ' +  
   ',RTRIM(ORDERS.C_Country) ' + 
   ',RTRIM(OD.LoadKey) ' +
   ',RTRIM(OD.MBOLKey) ' +
   ',RTRIM(ORDERS.BuyerPO) ' +
   ',RTRIM(ORDERS.Priority) ' +
   ',RTRIM(OD.POKey) ' +
   ',RTRIM(OD.ExternPOKey) ' +
   ',ORDERS.OrderDate ' +
   ',UPPER(RTRIM(OD.SKU)) ' +                  
   ',OD.OriginalQty ' +        			   
   ',RTRIM(OD.UOM) ' +                  
   ',RTRIM(ORDERS.ContainerType) ' +
   ',RTRIM(OD.Lottable01) ' +
   ',RTRIM(OD.Lottable02) ' +
   ',RTRIM(OD.Lottable03) ' +
   ',OD.Lottable04 ' +
   ',OD.Lottable05 ' +
   ',RTRIM(OD.Lottable06) ' +
   ',RTRIM(OD.Lottable07) ' +
   ',RTRIM(OD.Lottable08) ' +
   ',RTRIM(OD.Lottable09) ' +
   ',RTRIM(OD.Lottable10) ' +
   ',RTRIM(OD.Lottable11) ' +
   ',RTRIM(OD.Lottable12) ' +
   ',OD.Lottable13 ' +
   ',OD.Lottable14 ' +
   ',OD.Lottable15 ' +
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
   ',RTRIM(OD.UserDefine01) ' +
   ',RTRIM(OD.UserDefine02) ' +
   ',RTRIM(OD.UserDefine03) ' +
   ',RTRIM(OD.UserDefine04) ' +
   ',RTRIM(OD.UserDefine05) ' +
   ',RTRIM(OD.UserDefine06) ' + 
   ',RTRIM(OD.UserDefine07) ' +
   ',RTRIM(OD.UserDefine08) ' +
   ',RTRIM(OD.UserDefine09) ' +
   ',RTRIM(OD.UserDefine10) ' + 
   ',RTRIM(C.SUSR1) ' +
   ',(CASE WHEN ORDERS.doctype = ''E'' THEN ''PCS'' WHEN ORDERS.doctype = ''N'' THEN RTRIM(C.SUSR5) ELSE '''' END ) ' +    					--Remark:  having formula
   ',RTRIM(C.SUSR4) ' +
   ',RTRIM(C.SUSR5) ' +     
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
   ',RTRIM(F.UserDefine01) ' +
   ',RTRIM(ORDERS.C_City)' +
   ',RTRIM(ORDERS.C_State)' +
   ',ORDERS.EditDate ' +
   ',OD.OriginalQty '

   SET @c_SQLStatement =   @c_SQLStatement +
          N'FROM DBO.ORDERS (NOLOCK) ' +
          'JOIN DBO.ORDERDETAIL OD (nolock) ON ORDERS.Orderkey = OD.Orderkey ' +
          'LEFT JOIN DBO.Storer C (nolock) ON C.StorerKey = ORDERS.ConsigneeKey ' +
          'JOIN DBO.SKU (nolock) ON SKU.StorerKey = OD.StorerKey AND  SKU.SKU = OD.SKU ' + 
          'LEFT JOIN DBO.FACILITY F (nolock) ON F.Facility = ORDERS.Facility ' +
          'JOIN DBO.PACK (nolock) ON PACK.PACKKey = OD.PACKKey ' +
          'WHERE ORDERS.Status = ''CANC'' AND ORDERS.Doctype = ''E'' ' +
          'AND ORDERS.EditDate BETWEEN @d_Fromdate and @d_Todate ' +  
           @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'
      
      IF @n_debug = 1
      BEGIN
         PRINT 'COUNTRYISO - ' + @c_COUNTRYISO
         PRINT '@c_SQLCondition'
         PRINT @c_SQLCondition
         PRINT 'CANCEL Order'
         PRINT '@c_SQLStatement'
         PRINT @c_SQLStatement
         PRINT '@c_SQLParm'
         PRINT @c_SQLParm
      END


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
  ,CLIENT_REF_LINE_NO
  ,CLIENT_ID
  ,SHIP_FROM_ID
  ,SHIP_TO_ID
  ,SHIP_TO_COMPANY
  ,SHIP_TO_COUNTRY
  ,LOAD_PLAN_NO
  ,MBOL_NO
  ,OTHER_REFERENCE_1
  ,PRIORITY
  ,PO_NO
  ,CLIENT_PO_NO
  ,REFERENCE_DATE
  ,SKU_ID
  ,BILLABLE_QUANTITY
  ,QTY_UOM
  ,CONTAINER_TYPE
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
  ,STR_SUSR2
  ,STR_SUSR4
  ,STR_SUSR5
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
  ,FT_USD_19
  ,FT_USD_20  
  ,BILLABLE_DATE       --For generic, use MBOL.ShipDate
  ,R_CC_WMS_QTY
 )
 EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
   SET @n_RecCNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCNT AS NVARCHAR)
      PRINT ''
   END
   
   SET @n_RecCOUNT = @n_RecCOUNT + @n_RecCNT
   
   
   -- Normal Order
   
   SET @c_SQLStatement =
   N'SELECT @n_WMS_BatchNo ' +
   ',@n_TPB_Key '+
   ',''A'' ' +                -- A = ACTIVITIES
   ',''ORDER'' ' +
   ',@c_COUNTRYISO ' +
   ',RTRIM(Orders.Facility) ' +
   ',ORDERS.AddDate ' + 
   ',ORDERS.AddWho ' +
   ',MBOL.EditDate ' +
   ',ORDERS.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(ORDERS.Status) ' +
   ',RTRIM(ORDERS.DocType) ' +
   ',RTRIM(ORDERS.Type) ' + 
   ',RTRIM(ORDERS.OrderKey) ' +
   ',RTRIM(OD.OrderLineNumber) ' + 
   ',RTRIM(OD.ExternOrderKey) ' +
   ',RTRIM(OD.ExternLineNo) ' +
   ',RTRIM(ORDERS.StorerKey) ' + 
   ',RTRIM(Orders.Facility) ' +
   ',RTRIM(ORDERS.ConsigneeKey) ' +  
   ',RTRIM(ORDERS.C_Company) ' +  
   ',RTRIM(ORDERS.C_Country) ' + 
   ',RTRIM(OD.LoadKey) ' +
   ',RTRIM(OD.MBOLKey) ' +
   ',RTRIM(ORDERS.BuyerPO) ' +
   ',RTRIM(ORDERS.Priority) ' +
   ',RTRIM(OD.POKey) ' +
   ',RTRIM(OD.ExternPOKey) ' +
   ',ORDERS.OrderDate ' +
   ',RTRIM(PICKDETAIL.SKU) ' +                  
   ',RTRIM(LOC.LocationType) ' +     
   ',PICKDETAIL.Qty ' +        			   
   ',RTRIM(PICKDETAIL.UOM) ' +                  
   ',RTRIM(ORDERS.ContainerType) ' +
   ',RTRIM(OD.Lottable01) ' +
   ',RTRIM(OD.Lottable02) ' +
   ',RTRIM(OD.Lottable03) ' +
   ',OD.Lottable04 ' +
   ',OD.Lottable05 ' +
   ',RTRIM(OD.Lottable06) ' +
   ',RTRIM(OD.Lottable07) ' +
   ',RTRIM(OD.Lottable08) ' +
   ',RTRIM(OD.Lottable09) ' +
   ',RTRIM(OD.Lottable10) ' +
   ',RTRIM(OD.Lottable11) ' +
   ',RTRIM(OD.Lottable12) ' +
   ',OD.Lottable13 ' +
   ',OD.Lottable14 ' +
   ',OD.Lottable15 ' +
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
   ',RTRIM(OD.UserDefine01) ' +
   ',RTRIM(OD.UserDefine02) ' +
   ',RTRIM(OD.UserDefine03) ' +
   ',RTRIM(OD.UserDefine04) ' +
   ',RTRIM(OD.UserDefine05) ' +
   ',RTRIM(OD.UserDefine06) ' + 
   ',RTRIM(OD.UserDefine07) ' +
   ',RTRIM(OD.UserDefine08) ' +
   ',RTRIM(OD.UserDefine09) ' +
   ',RTRIM(OD.UserDefine10) ' + 
   ',RTRIM(PICKDETAIL.Lot) ' +
   ',RTRIM(C.SUSR1) ' +
   ',(CASE WHEN ORDERS.doctype = ''E'' THEN ''PCS'' WHEN ORDERS.doctype = ''N'' THEN RTRIM(C.SUSR5) ELSE '''' END ) ' +    					--Remark:  having formula
   ',RTRIM(C.SUSR4) ' +
   ',RTRIM(C.SUSR5) ' +     
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
   ',RTRIM(F.UserDefine01) ' +
   ',RTRIM(ORDERS.C_City)' +
   ',RTRIM(ORDERS.C_State)' +
   ',RTRIM(L.Lottable01) ' +   
   ',RTRIM(L.Lottable02) ' +
   ',RTRIM(L.Lottable03) ' +
   ',L.Lottable04 ' +
   ',L.Lottable05 ' +
   ',RTRIM(L.Lottable06) ' +
   ',RTRIM(L.Lottable07) ' +
   ',RTRIM(L.Lottable08) ' +
   ',RTRIM(L.Lottable09) ' +
   ',RTRIM(L.Lottable10) ' +
   ',RTRIM(L.Lottable11) ' +
   ',RTRIM(L.Lottable12) ' +
   ',L.Lottable13 ' + 
   ',L.Lottable14 ' +
   ',L.Lottable15 ' +
   ',MBOL.EditDate ' 


   SET @c_SQLStatement =   @c_SQLStatement +   
             N'FROM DBO.ORDERS (NOLOCK) ' +
             'JOIN DBO.ORDERDETAIL OD (nolock) ON ORDERS.Orderkey = OD.Orderkey ' +
             'JOIN DBO.PICKDETAIL (nolock) ON PICKDETAIL.Orderkey = OD.Orderkey AND PICKDETAIL.OrderlineNumber = OD.OrderlineNumber ' +
             'JOIN DBO.MBOLDETAIL (nolock) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey ' +
             'JOIN DBO.MBOL (nolock) ON  MBOL.MbolKey = MBOLDETAIL.MbolKey ' +
             'LEFT JOIN DBO.Storer C (nolock) ON C.StorerKey = ORDERS.ConsigneeKey ' +
             'JOIN DBO.SKU (nolock) ON SKU.StorerKey = OD.StorerKey AND  SKU.SKU = OD.SKU ' + 
             'LEFT JOIN DBO.FACILITY F (nolock) ON F.Facility = ORDERS.Facility ' +
             'JOIN DBO.PACK (nolock) ON PACK.PACKKey = PICKDETAIL.PACKKey ' +
             'JOIN DBO.LOTATTRIBUTE L (nolock) ON L.Lot = PICKDETAIL.Lot ' +
             'JOIN DBO.LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc ' +
             'WHERE ORDERS.Status =''9'' ' +
             'AND MBOL.EditDate BETWEEN @d_Fromdate and @d_Todate ' +  
              @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'
      
      IF @n_debug = 1
      BEGIN
         PRINT 'Normal Order'
         PRINT '@c_SQLStatement'
         PRINT @c_SQLStatement
         PRINT '@c_SQLParm'
         PRINT @c_SQLParm
      END


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
  ,CLIENT_REF_LINE_NO
  ,CLIENT_ID
  ,SHIP_FROM_ID
  ,SHIP_TO_ID
  ,SHIP_TO_COMPANY
  ,SHIP_TO_COUNTRY
  ,LOAD_PLAN_NO
  ,MBOL_NO
  ,OTHER_REFERENCE_1
  ,PRIORITY
  ,PO_NO
  ,CLIENT_PO_NO
  ,REFERENCE_DATE
  ,SKU_ID
  ,LOCATION_TYPE
  ,BILLABLE_QUANTITY
  ,QTY_UOM
  ,CONTAINER_TYPE
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
  ,LOT
  ,STR_SUSR1
  ,STR_SUSR2
  ,STR_SUSR4
  ,STR_SUSR5
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
  ,FT_USD_19
  ,FT_USD_20
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
  ,BILLABLE_DATE       --For generic, use MBOL.ShipDate

 )
 EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
   SET @n_RecCNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCNT AS NVARCHAR)
      PRINT ''
   END
   
   SET @n_RecCOUNT = @n_RecCOUNT + @n_RecCNT
      
END

GO