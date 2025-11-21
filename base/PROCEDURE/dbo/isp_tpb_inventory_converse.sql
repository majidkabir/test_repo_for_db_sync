SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_TPB_Inventory_Converse                          */        
/* Creation Date:                                                       */        
/* Copyright: IDS                                                       */        
/* Written by:                                                          */        
/*                                                                      */        
/* Purpose: TPB billing for Converse DailyInventory Transaction         */        
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
  
  
CREATE PROC [dbo].[isp_TPB_Inventory_Converse]  
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
  
   SET @c_SQLGroup =   
      'GROUP BY UPPER(RTRIM(DI.Facility)) ' +  
      ',UPPER(RTRIM(DI.StorerKey)) ' +  
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +  
      ',RTRIM(DI.Lottable01) ' +
      ',DI.Facility ' +
      ',DI.Storerkey '
  
  
   SET @c_SQLStatement =   
      'SELECT @n_WMS_BatchNo '+  
      ',@n_TPB_Key '+  
      ',''S'' '+             -- S = STORAGE  
      ',''INVENTORY'' '+  
      ',''HKG'' '+  
      ',(Select TOP 1 CD.Notes from CODELKUP CD (NOLOCK) 
      JOIN DailyInventory DailyInventory1 (NOLOCK) ON DailyInventory1.Facility=CD.Code 
      where CD.Listname = ''TPBFAC'' AND DailyInventory1.Facility = DI.Facility) ' +
      ',UPPER(RTRIM(DI.Facility)) ' +  
      ',''WMS'' ' +   
      ',''I'' ' +  
      ',(Select TOP 1 CD.Code from CODELKUP CD (NOLOCK) 
      JOIN DailyInventory DailyInventory1 (NOLOCK) ON DailyInventory1.Storerkey=CD.Storerkey 
      where CD.Listname = ''TPBCLIENT'' AND DailyInventory1.Storerkey = DI.Storerkey) ' +
      ',UPPER(RTRIM(DI.StorerKey)) '  +  
      --',MAX(S.Company) as Company ' +    --invalid column 'C_Company' in daily inventory table  
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +  
      ',COUNT(DI.Lottable01)'+
      --',UPPER(RTRIM(DI.SKU)) ' +  
      ',SUM(DI.Qty) ' + 
      ',SUM(DI.Qty * SKU.STDCUBE)'+ 
      ',RTRIM(DI.Lottable01)'+
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +
      'FROM dbo.DailyInventory DI (NOLOCK) ' +  
      'JOIN dbo.SKU (NOLOCK) ON SKU.StorerKey = DI.StorerKey AND SKU.SKU = DI.SKU ' +        
      'JOIN dbo.STORER S (NOLOCK) ON S.StorerKey = DI.StorerKey ' +  
      'WHERE DI.InventoryDate between @d_Fromdate and @d_Todate ' +     
      @c_SQLCondition + @c_SQLGroup  
  
       SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5),@c_COUNTRYISO nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'  
          
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
        ,Config_id  
        ,TRANSACTION_TYPE   
        ,CODE   
        ,COUNTRY   
        ,SITE_ID
        ,TO_SITE_ID   
        ,DOC_SOURCE   
        ,DOC_TYPE  
        ,CLIENT_ID  
        ,TO_CLIENT_ID
        ,REFERENCE_DATE  
        ,BILLABLE_NO_OF_LOC  
        ,BILLABLE_QUANTITY  
        ,BILLABLE_CBM
        ,LOTTABLE_01  
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