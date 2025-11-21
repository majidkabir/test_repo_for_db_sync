SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Orders_PUMA                                */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for PUMA Orders Transaction                     */      
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
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */      
/************************************************************************/  


CREATE PROC [dbo].[isp_TPB_Orders_PUMA]
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
              @c_SQLParm            NVARCHAR(4000),
              @c_SQLCondition       NVARCHAR(4000)  
   
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
   
   --Dynamic SQL

   SET @c_SQLStatement =
   N'SELECT @n_WMS_BatchNo ' +
   ',@n_TPB_Key '+
   ',''A'' ' +                  -- A = ACTIVITIES
   ',''ORDER'' ' +
   ',@c_COUNTRYISO ' +
   ',UPPER(RTRIM(Orders.Facility)) ' +
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
   ',UPPER(RTRIM(ORDERS.StorerKey)) ' + 
   ',UPPER(RTRIM(Orders.Facility)) ' +
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
   ',OD.ShippedQty ' +        	   
   ',RTRIM(OD.UOM) ' + 
   ',ISNULL(PD.Billable_Carton, 0) ' +              	                       
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
   ',RTRIM(CONSIGNEE.SUSR2) ' +           -- SUSR2
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
   ',MBOL.ShipDate ' 

   SET @c_SQLStatement =  @c_SQLStatement +  
             N'FROM DBO.ORDERS (NOLOCK) ' +
             'JOIN DBO.ORDERDETAIL OD (nolock) ON ORDERS.Orderkey = OD.Orderkey ' +
             'JOIN DBO.MBOLDETAIL (nolock) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey ' +
             'JOIN DBO.MBOL (nolock) ON  MBOL.MbolKey = MBOLDETAIL.MbolKey ' +
             'LEFT JOIN DBO.Storer CONSIGNEE (nolock) ON CONSIGNEE.StorerKey = ORDERS.ConsigneeKey ' +
             'JOIN DBO.SKU (nolock) ON SKU.StorerKey = OD.StorerKey AND  SKU.SKU = OD.SKU ' + 
             'LEFT JOIN DBO.FACILITY (nolock) ON FACILITY.Facility = ORDERS.Facility ' +
             'JOIN DBO.PACK (nolock) ON PACK.PACKKey = OD.PACKKey ' +
             'LEFT JOIN dbo.PACKHEADER PH (NOLOCK) ON PH.orderkey = ORDERS.Orderkey ' +
             'LEFT JOIN (select pickslipno, COUNT(distinct labelno) AS Billable_Carton from dbo.packdetail (NOLOCK) 
              WHERE storerkey=@c_storerkey AND editdate > DATEADD (MONTH, -8, GETDATE() ) GROUP by pickslipno) PD on PH.Pickslipno=PD.Pickslipno ' +
             'WHERE ORDERS.Status = ''9'' ' +
             'AND MBOL.ShipDate BETWEEN @d_Fromdate and @d_Todate ' +  
              @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), ' +
                        '@d_Fromdate DATETIME, @d_Todate DATETIME, @c_storerkey Nvarchar(15) '
      
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
  ,BILLABLE_CARTON
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
  ,STR_SUSR2
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
 EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate, @c_storerkey
   SET @n_RecCOUNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
      PRINT ''
   END
END

GO