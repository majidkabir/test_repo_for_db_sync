SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_WorkOrder_Generic                          */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for Generic WorkOrder Transaction               */      
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



CREATE PROC [dbo].[isp_TPB_WorkOrder_Generic]
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
      ',''A'' ' +          --  A = ACTIVITIES
      ',''WORKORDER'' ' +
      ',@c_COUNTRYISO ' +
      ',UPPER(RTRIM(WorkOrder.Facility)) ' +
      ',WorkOrder.AddDate ' +
      ',WorkOrder.AddWho ' +
      ',WorkOrder.EditDate ' +
      ',WorkOrder.EditWho ' +
      ',''WMS'' ' +
      ',RTRIM(WorkOrder.Status) ' +
      ',RTRIM(WorkOrder.Type) ' + 
      ',RTRIM(WorkOrderDetail.Reason) ' +
      ',RTRIM(WorkOrder.WorkOrderKey) ' +
      ',RTRIM(WorkOrderDetail.WorkOrderLineNumber) ' +
      ',RTRIM(WorkOrder.ExternWorkOrderKey) ' +     
      ',RTRIM(WorkOrderDetail.ExternLineNo) ' +
      ',UPPER(RTRIM(WorkOrder.Storerkey)) ' +
      ',ISNULL(RTRIM(CONVERT(NVARCHAR(100),WorkOrder.Remarks)),'''') ' +
      ',ISNULL(RTRIM(CONVERT(NVARCHAR(30),WorkOrderDetail.Remarks)),'''') ' +
      ',RTRIM(WorkOrder.WkOrdUdef6) ' +
      ',UPPER(RTRIM(WorkOrderDetail.SKU)) ' +
      ',WorkOrderDetail.QTY ' +
      ',WorkOrderDetail.Unit ' +
      ',RTRIM(WorkOrder.WkOrdUdef1) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef2) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef3) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef4) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef5) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef6) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef7) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef8) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef9) ' +  
      ',RTRIM(WorkOrder.WkOrdUdef10) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef1) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef2) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef3) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef4) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef5) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef6) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef7) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef8) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef9) ' +
      ',RTRIM(WorkOrderdetail.WkOrdUdef10) ' +
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
      ',RTRIM(SKU.Size)  ' +
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
      ',RTRIM(WorkOrder.WkOrdUdef6) ' +
      ',WorkOrderDetail.Price ' +
      ',WorkOrderDetail.LineValue '  

   SET @c_SQLStatement = @c_SQLStatement +
            N'FROM dbo.WorkOrder (NOLOCK) ' +
            'JOIN dbo.WorkOrderdetail (NOLOCK) ON WorkOrderdetail.WorkOrderKey = WorkOrder.WorkOrderKey ' +
            'LEFT JOIN dbo.SKU (NOLOCK) ON SKU.StorerKey = WorkOrderDetail.StorerKey AND SKU.SKU = WorkOrderdetail.Sku ' +
            'LEFT JOIN dbo.PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey ' +         -- Remarks: please check this joined table key because just simple joined  the key first due to needed link to PACK.CaseCnt
            'WHERE WorkOrder.Status = ''9''  ' +
            'AND WorkOrder.Editdate between @d_Fromdate and @d_Todate ' +
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
     ,DOC_REASON
     ,DOCUMENT_ID
     ,DOCUMENT_LINE_NO
     ,CLIENT_REF
     ,CLIENT_REF_LINE_NO
     ,CLIENT_ID
     ,OTHER_REFERENCE_1
     ,OTHER_REFERENCE_2
     ,REFERENCE_DATE
     ,SKU_ID
     ,BILLABLE_QUANTITY
     ,QTY_UOM
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
     ,R_LINE_PRICE
     ,R_LINE_TOTAL

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