SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Inventory_Carters                          */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for CHN Carter DailyInventory Transaction       */      
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
/* 07-Jul-18    TLTING    1.3   LOT_LOTTABLE_01, LOT_LOTTABLE_02        */  
/************************************************************************/  


CREATE PROC [dbo].[isp_TPB_Inventory_Carters]
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
              @c_SQLGroup        NVARCHAR(4000),
              @d_inventorydate   Datetime    
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_Todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0


  -- SET @d_inventorydate = Convert(datetime, Convert(char(11), GETDATE() - 1, 120) + ' 23:59:00' ) 

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
      ' GROUP BY UPPER(ISNULL(RTRIM(LOC.Facility),''''))  ' +
      ',UPPER(RTRIM(DI.StorerKey)) ' + 
      ',UPPER(RTRIM(DI.SKU)) ' +
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
      ',DI.ID ' +
      ',DI.Lot ' +
      ',RTRIM(L.Lottable01) ' +
      ',RTRIM(L.Lottable02) ' +      
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' )  '

   SET @c_SQLStatement = 
      N'SELECT @n_WMS_BatchNo '+
      ',@n_TPB_Key '+
      ',''S'' '+             -- S = STORAGE
      ',''INVENTORY'' '+
      ',@c_COUNTRYISO '+
      ',UPPER(ISNULL(RTRIM(LOC.Facility),'''')) ' +
      ',''WMS'' ' + 
      ',''I'' ' +
      ',UPPER(RTRIM(DI.StorerKey)) '  +
      ',MAX(RTRIM(S.Company)) as Company ' +     
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' )  ' +
      ',UPPER(RTRIM(DI.SKU)) ' +
      ',SUM(DI.Qty) ' +  
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
      ',DI.ID ' +      
      ',(SELECT ISNULL(MAX(RTRIM(UCC.UCCNo)),'''') FROM UCC (NOLOCK) WHERE UCC.LOT = DI.LOT AND ' + 
         'UCC.Storerkey = UPPER(RTRIM(DI.StorerKey)) AND UCC.Qty>0) as UCCNo ' +    
      ',RTRIM(L.Lottable01) ' +
      ',RTRIM(L.Lottable02) ' +               
      ',Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' )  ' +

      'FROM DailyInventory DI (NOLOCK) ' +
      'JOIN SKU (NOLOCK) ON SKU.StorerKey = DI.StorerKey AND SKU.SKU = DI.SKU ' +       
      'JOIN STORER S (NOLOCK) ON S.StorerKey = DI.StorerKey ' +
      'JOIN Lotattribute L (NOLOCK) ON L.LOT = DI.LOT ' +
      'JOIN LOC (NOLOCK) ON LOC.LOC = DI.LOC ' +
      'WHERE DI.qty  > 0 ' +      
      'AND DI.InventoryDate between @d_Fromdate and @d_Todate ' +
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
        ,SKU_ID
        ,BILLABLE_QUANTITY
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
        ,ID
        ,CASE_ID
        ,LOT_LOTTABLE_01
        ,LOT_LOTTABLE_02
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