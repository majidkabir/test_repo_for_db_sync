SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Orders_Carters                             */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Carter Orders Transaction               */      
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
/* 17-Apr-18    TLTING    1.1   to avoid retrigger MBOL ship filtering  */   
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */
/* 07-Jul-18    TLTING    1.3   LOT_LOTTABLE_01, LOT_LOTTABLE_02        */
/************************************************************************/  

CREATE PROC [dbo].[isp_TPB_Orders_Carters]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key	BIGINT,
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
   
   CREATE TABLE #t_MBO
   ( RowRef    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      MBOLKey   NVARCHAR(50) )
       
   -- tlting01
    -- for performance concern, only 1 storer\ facility , will always do retrigger mbol
   INSERT INTO #t_MBO ( MBOLKey )
   SELECT DISTINCT  MBOL_NO 
   FROM WMS_TPB_BASE (nolock) 
   WHERE CLIENT_ID='CARTERSZ' AND SITE_ID='QHW01' AND CODE='ORDER' 
   AND BILLABLE_DATE>GETDATE()-14



   --Dynamic SQL
   --Cancel Order
   SET @c_SQLStatement =
   N' SELECT @n_WMS_BatchNo ' +
   ',@n_TPB_Key '+
   ',''A'' ' +          -- A = ACTIVITIES
   ',''ORDER'' ' +
   ',@c_COUNTRYISO ' +
   ',UPPER(RTRIM(ORDERS.Facility)) ' +
   ',ORDERS.AddDate ' + 
   ',ORDERS.AddWho ' +
   ',ORDERS.EditDate ' +
   ',ORDERS.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(ORDERS.Status) ' +
   ',ISNULL(( SELECT RTRIM(MAX(DT.DocStatus)) FROM dbo.DocStatusTrack DT (nolock) WHERE DT.DocumentNo=ORDERS.orderkey ' +
      'AND DT.TableName=''STSORDERS'' AND DT.DocStatus<>''CANC''), ''0'') ' +  --Doc_Pre_Status
   ',RTRIM(ORDERS.DocType) ' +
   ',RTRIM(ORDERS.Type) ' + 
   ',RTRIM(ORDERS.OrderKey) ' +
   ',RTRIM(OD.OrderLineNumber) ' + 
   ',RTRIM(OD.ExternOrderKey) ' +
   ',RTRIM(OD.ExternLineNo) ' +
   ',UPPER(RTRIM(ORDERS.StorerKey)) ' + 
   ',UPPER(RTRIM(ORDERS.Facility)) ' +
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
   ',RTRIM(P.CaseCnt) ' +
   ',ORDERS.EditDate ' +
   ',RTRIM(OD.Lottable01) ' +
   ',RTRIM(OD.Lottable02) ' +
   ',OD.OriginalQty '

   SET @c_SQLStatement =   @c_SQLStatement +
    N'FROM DBO.ORDERS (NOLOCK) ' +
    'JOIN DBO.ORDERDETAIL OD (NOLOCK) ON ORDERS.Orderkey = OD.Orderkey ' +
    'JOIN DBO.SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND  S.SKU = OD.SKU ' + 
    'LEFT JOIN DBO.FACILITY F (NOLOCK) ON F.Facility = ORDERS.Facility ' +
    'LEFT JOIN DBO.PACK P (NOLOCK) ON P.PACKKey = OD.PACKKey ' +
   'WHERE ORDERS.Status = ''CANC'' AND ORDERS.Doctype = ''E'' ' +
    'AND ORDERS.EditDate BETWEEN @d_Fromdate and @d_Todate ' +  
     @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key NVARCHAR(5), @c_COUNTRYISO Nvarchar(5), ' +
                        '@d_Fromdate DATETIME, @d_Todate DATETIME'
      
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
   , CONFIG_ID
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
  ,DOC_PRE_STATUS
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
                  -- cancel order no this column ,VOYAGE_ID
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
  ,LOT_LOTTABLE_01
  ,LOT_LOTTABLE_02
  ,BILLABLE_DATE       
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
   N' SELECT @n_WMS_BatchNo ' +
   ',@n_TPB_Key '+
   ',''A'' ' +          -- A = ACTIVITIES
   ',''ORDER'' ' +
   ',@c_COUNTRYISO ' +
   ',RTRIM(ORDERS.Facility) ' +
   ',ORDERS.AddDate ' + 
   ',ORDERS.AddWho ' +
   ',M.EditDate ' +
   ',ORDERS.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(ORDERS.Status) ' +
   ','''' ' +              --Doc_Pre_Status
   ',RTRIM(ORDERS.DocType) ' +
   ',RTRIM(ORDERS.Type) ' + 
   ',RTRIM(ORDERS.OrderKey) ' +
   ',RTRIM(OD.OrderLineNumber) ' + 
   ',RTRIM(OD.ExternOrderKey) ' +
   ',RTRIM(OD.ExternLineNo) ' +
   ',RTRIM(ORDERS.StorerKey) ' + 
   ',RTRIM(ORDERS.Facility) ' +
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
   ',RTRIM(PD.SKU) ' +                  	
   ',PD.Qty ' +        			  
   ',RTRIM(PD.UOM) ' +    
   ',RTRIM(M.VoyageNumber) ' +              	
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
   ',(SELECT MAX(RTRIM(w.DispatchPiecePickMethod)) FROM dbo.WAVE W (NOLOCK) ' +    --DispatchPiecePickMethod
   ' WHERE W.WaveKey = ORDERS.UserDefine09 AND W.DispatchPiecePickMethod IN (''H'',''I'',''T'')) ' +
   ',RTRIM(PD.Lot) ' +
   ',RTRIM(PD.DropID) ' +
   ',RTRIM(PD.CaseID) ' +
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
   ',RTRIM(P.CaseCnt) ' +
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
   ',M.EditDate ' 
   
   SET @c_SQLStatement = @c_SQLStatement +    
            N'FROM DBO.ORDERS (NOLOCK) ' +
          'JOIN DBO.ORDERDETAIL OD (nolock) ON ORDERS.Orderkey = OD.Orderkey ' +
          'JOIN DBO.PICKDETAIL PD (nolock) ON PD.Orderkey = OD.Orderkey AND PD.OrderlineNumber = OD.OrderlineNumber ' +
          'JOIN DBO.MBOLDETAIL MD (nolock) ON MD.OrderKey = ORDERS.OrderKey ' +
          'JOIN DBO.MBOL M (nolock) ON  M.MbolKey = MD.MbolKey ' +
          'JOIN DBO.SKU S (nolock) ON S.StorerKey = OD.StorerKey AND  S.SKU = OD.SKU ' + 
          'LEFT JOIN DBO.FACILITY F (nolock) ON F.Facility = ORDERS.Facility ' +
          'JOIN DBO.PACK P (nolock) ON P.PACKKey = PD.PACKKey ' +
          'JOIN DBO.LOTATTRIBUTE L (nolock) ON L.Lot = PD.Lot ' +
          'JOIN DBO.LOC (NOLOCK) ON LOC.LOC = PD.Loc ' +
          'WHERE ORDERS.Status = ''9''  ' +
          'AND M.EditDate BETWEEN @d_Fromdate and @d_Todate ' +  
          ' AND  NOT EXISTS (SELECT 1 FROM #t_MBO WHERE #t_MBO.MBOLKEY = ORDERS.MBOLKEY ) ' +  -- tlting01
           @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key NVARCHAR(5), @c_COUNTRYISO Nvarchar(5), ' +
                        '@d_Fromdate DATETIME, @d_Todate DATETIME'
      
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
   , CONFIG_ID
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
  ,DOC_PRE_STATUS
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
  ,VOYAGE_ID
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
  ,PCS_PICK_METHOD     --REMARK : Need link to 'WAVE' table
  ,LOT
  ,DROP_ID
  ,CASE_ID
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
   SET @n_RecCNT = @@ROWCOUNT
 
   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCNT AS NVARCHAR)
      PRINT ''
   END
   SET @n_RecCOUNT = @n_RecCOUNT + @n_RecCNT
   
END

GO