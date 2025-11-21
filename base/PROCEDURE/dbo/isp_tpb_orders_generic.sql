SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Orders_Generic                             */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for Generic Orders Transaction                  */      
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


CREATE PROC [dbo].[isp_TPB_Orders_Generic]
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
   ',''HostWHCode'' ' +
   ',ORDERS.AddDate ' + 
   ',ORDERS.AddWho ' +
   ',M.EditDate ' +
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
   ',RTRIM(LOC.LocationType) ' +
   ','''' ' +                             --BillableNoOfLoc
   ',OD.ShippedQty ' +        	   
   ',RTRIM(OD.UOM) ' +                  	
   ',S.GrossWgt ' +                             
   ',RTRIM(ORDERS.ContainerType) ' +
   --  ',OD.PalletKey ' +        -- invalid 'PalletKey' column name in 'ORDERDETAIL' table
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
   --','''' ' +                        -- DispatchPiecePickMethod
   ',PD.Lot ' +
   ',RTRIM(PD.DropID) ' +
   ',RTRIM(PD.CaseID) ' +
   ',RTRIM(C.SUSR1) ' +
   ',RTRIM(C.SUSR2) ' +
   ',RTRIM(C.SUSR3) ' +    					
   ',RTRIM(C.SUSR4) ' +
   ',RTRIM(C.SUSR5) ' +
   ',RTRIM(C.CustomerGroupCode) ' +
   ',RTRIM(C.MarketSegment) ' +    
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
   ',RTRIM(PACK.CaseCnt) ' +
   ',RTRIM(F.UserDefine01) ' +
   ',RTRIM(F.UserDefine02) ' +
   ',RTRIM(F.UserDefine03) ' +
   ',RTRIM(F.UserDefine04) ' +
   ',RTRIM(F.UserDefine05) ' +
   ',RTRIM(F.UserDefine06) ' +
   ',RTRIM(F.UserDefine07) ' +
   ',RTRIM(F.UserDefine08) ' +
   ',RTRIM(F.UserDefine09) ' +
   ',RTRIM(F.UserDefine10) ' +
   ',RTRIM(F.UserDefine11) ' +
   ',RTRIM(F.UserDefine12) ' +
   ',RTRIM(F.UserDefine13) ' +
   ',RTRIM(F.UserDefine14) ' +
   ',RTRIM(F.UserDefine15) ' +
   ',RTRIM(F.UserDefine16) ' +
   ',RTRIM(F.UserDefine17) ' +
   ',RTRIM(F.UserDefine18) ' +
   ',RTRIM(F.UserDefine19) ' +
   ',RTRIM(F.UserDefine20) ' +
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
   ',M.ShipDate '          

   SET @c_SQLStatement = @c_SQLStatement +  N'FROM dbo.ORDERS (NOLOCK) ' +
          'JOIN dbo.ORDERDETAIL OD (nolock) ON ORDERS.Orderkey = OD.Orderkey ' +
          'JOIN dbo.PICKDETAIL PD (nolock) ON PD.Orderkey = OD.Orderkey AND PD.OrderlineNumber = OD.OrderlineNumber ' +
          'JOIN dbo.MBOLDETAIL MD (nolock) ON MD.OrderKey = ORDERS.OrderKey ' +
          'JOIN dbo.MBOL M (nolock) ON M.MbolKey = MD.MbolKey ' +
          'LEFT JOIN dbo.Storer C (nolock) ON C.StorerKey = ORDERS.ConsigneeKey ' +
          'JOIN dbo.SKU S (nolock) ON S.StorerKey = OD.StorerKey AND  S.SKU = OD.SKU ' + 
          'LEFT JOIN dbo.FACILITY F (nolock) ON F.Facility = ORDERS.Facility ' +
          'JOIN dbo.PACK (nolock) ON PACK.PACKKey = PD.PACKKey ' +
          'JOIN dbo.LOTATTRIBUTE L (nolock) ON L.Lot = PD.Lot ' +
          'JOIN dbo.LOC (NOLOCK) ON LOC.LOC = PD.Loc ' +
          'WHERE ORDERS.Status = ''9'' ' +
          'AND M.ShipDate BETWEEN @d_Fromdate and @d_Todate ' +  
           @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key Nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'
      
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
   ,Config_ID
  ,TRANSACTION_TYPE
  ,CODE
  ,COUNTRY
  ,SITE_ID
  ,CLIENT_SITE_ID
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
  ,BILLABLE_NO_OF_LOC
  ,BILLABLE_QUANTITY
  ,QTY_UOM
  ,BILLABLE_WEIGHT
  ,CONTAINER_TYPE
--  ,PALLET_ID
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
--  ,PCS_PICK_METHOD
  ,LOT
  ,DROP_ID
  ,CASE_ID
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
  ,FT_USD_01
  ,FT_USD_02
  ,FT_USD_03
  ,FT_USD_04
  ,FT_USD_05
  ,FT_USD_06
  ,FT_USD_07
  ,FT_USD_08
  ,FT_USD_09
  ,FT_USD_10
  ,FT_USD_11
  ,FT_USD_12
  ,FT_USD_13
  ,FT_USD_14
  ,FT_USD_15
  ,FT_USD_16
  ,FT_USD_17
  ,FT_USD_18
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