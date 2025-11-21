SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Inventory_Skechers                         */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Skechers DailyInventory Transaction     */      
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
/* 2018Jan29    TLTING    1.1   Inv datetime -1 Mi - Oracle issue on 00 */   
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */    
/************************************************************************/  


CREATE PROC [dbo].[isp_TPB_Inventory_Skechers]
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
              @c_SQLParm         NVARCHAR(4000),
              @c_SQLCondition    NVARCHAR(4000),
              @c_SQLGroup        NVARCHAR(4000)    
   
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
   
    SET @c_SQLGroup = 
      ' GROUP BY UPPER(RTRIM(DI.Facility)) ' +
      ',UPPER(RTRIM(DI.StorerKey)) ' +
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +
      ',RTRIM(SKU.ItemClass) '

   SET @c_SQLStatement = 
      N'SELECT @n_WMS_BatchNo '+
      ',@n_TPB_Key '+
      ',''S'' '+              --  S = STORAGE
      ',''INVENTORY'' '+
      ',@c_COUNTRYISO '+
      ',UPPER(RTRIM(DI.Facility)) ' +
      ',''WMS'' ' + 
      ',''I'' ' +
      ',UPPER(RTRIM(DI.StorerKey)) '  +
      ',MAX(RTRIM(S.Company)) as Company ' +    --invalid column 'C_Company' in daily inventory table
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +
    --  ',RTRIM(DI.SKU) ' +
      ',Sum(DI.Qty) ' +             -- BILLABLE_QUANTITY
      ',RTRIM(SKU.ItemClass) ' +
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +
      'FROM DailyInventory DI (NOLOCK) ' +
      'JOIN SKU (NOLOCK) ON SKU.StorerKey = DI.StorerKey AND SKU.SKU = DI.SKU ' +      --Remarks: please check this joined table key correct not due to just simply joined the key first to link the SKU.ItemClass
      'JOIN STORER S (NOLOCK) ON S.StorerKey = DI.StorerKey ' +
      'WHERE DI.InventoryDate between @d_Fromdate and @d_Todate ' +
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
        ,TRANSACTION_TYPE 
        ,CODE 
        ,COUNTRY 
        ,SITE_ID 
        ,DOC_SOURCE 
        ,DOC_TYPE
        ,CLIENT_ID
        ,SHIP_TO_COMPANY
        ,REFERENCE_DATE
  --      ,SKU_ID
        ,BILLABLE_QUANTITY
        ,SKU_ITEM_CLASS
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