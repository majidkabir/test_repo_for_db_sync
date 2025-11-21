SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_IQC_Skechers                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Skechers InventoryQC Transaction        */      
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


CREATE PROC [dbo].[isp_TPB_IQC_Skechers]
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
   
   -- Dynamic SQL
   SET @c_SQLStatement = 
      N'SELECT @n_WMS_BatchNo ' +
      ',@n_TPB_Key '+
      ',''A'' ' +             -- A = ACTIVITIES
      ',''IQC'' ' +
      ',@c_COUNTRYISO ' +
      ',UPPER(RTRIM(IQC.From_Facility)) ' +
      ',UPPER(RTRIM(IQC.To_Facility)) ' +
      ',IQC.AddDate ' +
      ',IQC.AddWho ' +
      ',IQC.EditDate ' +
      ',IQC.EditWho ' +
      ',''WMS'' ' +
      ',''9'' ' +
      ',''TT'' ' + 
      ',RTRIM(IQC.Reason) ' +
      ',RTRIM(IQC.QC_Key) ' +
      ',RTRIM(IQCD.QCLineNO) ' +     --invalid QCLineNo column name in IQC table, change to IQCD
      ',RTRIM(IQC.TradeReturnKey) ' +
      ',UPPER(RTRIM(IQC.Storerkey)) ' +
      ',UPPER(RTRIM(IQCD.SKU)) ' +
      ',IQCD.QTY ' +
      ',RTRIM(IQCD.UOM) ' +
      ',IQC.EditDate ' +

      'FROM dbo.InventoryQC IQC (NOLOCK) ' +
      'JOIN dbo.InventoryQCDETAIL IQCD (NOLOCK) ON IQCD.QC_Key = IQC.QC_Key ' +
      'JOIN dbo.Facility (NOLOCK) ON Facility.Facility = IQC.To_facility ' +  -- ??
      'JOIN dbo.LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.lot = IQCD.FromLot ' +
      'WHERE IQC.FinalizeFlag = ''Y'' ' +
      'AND IQC.EditDate between @d_Fromdate and @d_Todate ' +
      @c_SQLCondition
   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), ' +
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

       -- INSERT Data
      INSERT INTO [DBO].[WMS_TPB_BASE](
      BatchNo 
      , CONFIG_ID
     , TRANSACTION_TYPE 
     ,CODE 
     ,COUNTRY 
     ,SITE_ID
     ,TO_SITE_ID 
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
     ,CLIENT_ID
     ,SKU_ID
     ,BILLABLE_QUANTITY
     ,QTY_UOM
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